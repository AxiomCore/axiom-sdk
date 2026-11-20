// MFA, step-up and enrollment against a scripted issuer (the emulator does not
// implement auth-advanced/v1). Wire shapes follow auth-web's tests.
import 'dart:async';
import 'dart:convert';

import 'package:axiom_flutter_auth/axiom_flutter_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const iss = 'https://auth.test/p';
String _b64(Object o) =>
    base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');

class FakeIssuer {
  int now = DateTime.utc(2026, 11, 20, 12).millisecondsSinceEpoch;
  int counter = 0;
  final calls = <String>[];
  final bodies = <String, Map<String, dynamic>>{};
  int refreshStatus = 200;
  String currentRefresh = '';

  String jwt({String acr = 'aal1', int ttl = 900}) {
    final iat = now ~/ 1000;
    return '${_b64({'alg': 'none'})}.${_b64({
      'sub': 'user-1',
      'aud': 'api',
      'iat': iat,
      'exp': iat + ttl,
      'acr': acr,
      'auth_time': iat,
      'roles': ['member'],
    })}.sig';
  }

  Map<String, dynamic> tokens({String acr = 'aal1'}) {
    counter++;
    currentRefresh = 'sess1.r$counter';
    return {
      'access_token': jwt(acr: acr),
      'refresh_token': currentRefresh,
      'refresh_expires_at': DateTime.fromMillisecondsSinceEpoch(
        now + 86400000,
        isUtc: true,
      ).toIso8601String(),
      'session': {'id': 'sess1'},
    };
  }

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  http.Response err(
    int status,
    String code, [
    Map<String, dynamic> extra = const {},
  ]) => json(status, {
    'error': {'code': code, 'message': code, ...extra},
  });

  late final MockClient client = MockClient((req) async {
    final path = req.url.path.replaceFirst('/p', '');
    calls.add('${req.method} $path');
    final body = req.body.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(req.body) as Map).cast<String, dynamic>();
    bodies[path] = body;
    switch (path) {
      case '/v1/sign-in/password':
        if (body['email'] == 'enroll@example.com') {
          return err(403, 'AXAUTH_MFA_ENROLLMENT_REQUIRED', {
            'mfa_enrollment': {
              'ticket': 'axs1.ENROLL',
              'types': ['totp', 'bogus'],
            },
          });
        }
        if (body['email'] == 'plain@example.com') return json(200, tokens());
        return err(401, 'AXAUTH_MFA_REQUIRED', {
          'mfa': {
            'ticket': 'axs1.SECRET',
            'factors': [
              {'id': 'f-totp', 'type': 'totp', 'label': 'Phone app'},
              {'id': 'f-off', 'type': 'sms', 'label': 'Old', 'usable': false},
            ],
            'recovery_codes': true,
            'expires_in': 300,
          },
        });
      case '/v1/mfa/verify':
        if (body['ticket'] != 'axs1.SECRET')
          return err(400, 'AXAUTH_INVALID_REQUEST');
        if (body['code'] == '123456' || body['recovery_code'] == 'rc-1')
          return json(200, tokens(acr: 'aal2'));
        return err(400, 'AXAUTH_INVALID_CODE');
      case '/v1/token/refresh':
        if (refreshStatus != 200)
          return http.Response(
            'busy',
            refreshStatus,
            headers: {'retry-after': '7'},
          );
        if (body['refresh_token'] != currentRefresh)
          return err(401, 'AXAUTH_INVALID_REFRESH');
        return json(200, tokens());
      case '/v1/factors':
        return json(200, {
          'factors': [
            {
              'id': '11111111-1111-1111-1111-111111111111',
              'type': 'totp',
              'label': 'Phone app',
              'status': 'active',
              'created_at': '2026-11-01',
            },
          ],
          'recovery_codes_remaining': 9,
        });
      case '/v1/reauthenticate':
        if (req.headers['Authorization'] == null)
          return err(401, 'AXAUTH_INVALID_TOKEN');
        if (body['refresh_token'] != currentRefresh)
          return err(401, 'AXAUTH_INVALID_REFRESH');
        if (body['method'] == 'password' && body['password'] != 'pw')
          return err(401, 'AXAUTH_INVALID_CREDENTIALS');
        if (body['method'] == 'totp' && body['code'] != '654321')
          return err(400, 'AXAUTH_INVALID_CODE');
        return json(200, tokens(acr: 'aal2'));
      case '/v1/factors/totp':
        return json(200, {
          'factor_id': '22222222-2222-2222-2222-222222222222',
          'secret': 'JBSWY3DP',
          'otpauth_uri': 'otpauth://totp/x?secret=JBSWY3DP',
        });
      case '/v1/factors/totp/22222222-2222-2222-2222-222222222222/confirm':
        if (body['ticket'] != 'axs1.ENROLL' || body['code'] != '111111')
          return err(400, 'AXAUTH_INVALID_CODE');
        return json(200, {
          'factor': {
            'id': '22222222-2222-2222-2222-222222222222',
            'type': 'totp',
            'label': 'Phone',
            'status': 'active',
            'created_at': '2026-11-20',
          },
          'recovery_codes': ['rc-a', 'rc-b'],
          'tokens': tokens(acr: 'aal2'),
        });
      case '/v1/logout':
        return json(200, {});
    }
    return err(404, 'AXAUTH_NOT_FOUND');
  });
}

class Timers {
  final scheduled = <Duration>[];
  final callbacks = <void Function()>[];
  Timer call(Duration d, void Function() cb) {
    scheduled.add(d);
    callbacks.add(cb);
    return Timer(const Duration(days: 1), () {});
  }
}

AxiomAuth make(FakeIssuer f, {Timers? timers}) => AxiomAuth(
  AxiomAuthOptions(
    issuer: iss,
    httpClient: f.client,
    clock: () => f.now,
    timerFactory: (timers ?? Timers()).call,
  ),
);

void main() {
  test(
    'mfa_required keeps the ticket private and verifyMfa completes',
    () async {
      final f = FakeIssuer();
      final auth = make(f);
      Object? caught;
      try {
        await auth.signInWithPassword('a@example.com', 'pw');
      } catch (e) {
        caught = e;
      }
      expect(
        caught,
        isA<AxiomAuthError>().having((e) => e.code, 'code', 'mfa_required'),
      );
      expect(caught.toString().contains('axs1'), isFalse);
      expect(jsonEncode(auth.toJson()).contains('axs1'), isFalse);
      final ch = auth.mfaChallenge()!;
      expect(ch.factors.map((x) => x.id), [
        'f-totp',
      ], reason: 'unusable factors dropped');
      expect(ch.recoveryCodes, isTrue);
      expect(auth.session().status, isNot(AuthStatus.authenticated));

      await expectLater(
        auth.verifyMfa('f-totp', '000000'),
        throwsA(
          isA<AxiomAuthError>().having((e) => e.code, 'code', 'invalid_code'),
        ),
      );
      final s = await auth.verifyMfa('f-totp', '123456');
      expect(f.bodies['/v1/mfa/verify']!['ticket'], 'axs1.SECRET');
      expect(s.status, AuthStatus.authenticated);
      expect(s.acr, Acr.aal2);
      expect(auth.mfaChallenge(), isNull, reason: 'cleared by the session');
    },
  );

  test('recovery code and challenge expiry', () async {
    final f = FakeIssuer();
    final auth = make(f);
    await expectLater(
      auth.signInWithPassword('a@example.com', 'pw'),
      throwsA(isA<AxiomAuthError>()),
    );
    f.now += 301 * 1000;
    expect(auth.mfaChallenge(), isNull);
    await expectLater(
      auth.verifyRecoveryCode('rc-1'),
      throwsA(
        isA<AxiomAuthError>().having((e) => e.code, 'code', 'mfa_required'),
      ),
    );
    await expectLater(
      auth.signInWithPassword('a@example.com', 'pw'),
      throwsA(isA<AxiomAuthError>()),
    );
    expect(
      (await auth.verifyRecoveryCode('rc-1')).status,
      AuthStatus.authenticated,
    );
  });

  test(
    'enrollment-required sign-in: enrollTotp + confirmTotp with the enroll ticket',
    () async {
      final f = FakeIssuer();
      final auth = make(f);
      await expectLater(
        auth.signInWithPassword('enroll@example.com', 'pw'),
        throwsA(
          isA<AxiomAuthError>().having(
            (e) => e.code,
            'code',
            'mfa_enrollment_required',
          ),
        ),
      );
      expect(auth.mfaChallenge()!.enrollmentTypes, ['totp']);
      final e = await auth.enrollTotp('Phone');
      expect(f.bodies['/v1/factors/totp']!['ticket'], 'axs1.ENROLL');
      expect(e.secret, 'JBSWY3DP');
      final codes = await auth.confirmTotp(e.factorId, '111111');
      expect(codes, ['rc-a', 'rc-b']);
      expect(auth.session().status, AuthStatus.authenticated);
    },
  );

  test(
    'stepUp with password and totp rotates tokens; a refused step-up changes nothing',
    () async {
      final f = FakeIssuer();
      final auth = make(f);
      await auth.signInWithPassword('plain@example.com', 'pw');
      expect(auth.session().acr, Acr.aal1);
      final before = auth.session();
      await expectLater(
        auth.stepUp(method: StepUpMethod.password, password: 'nope'),
        throwsA(
          isA<AxiomAuthError>().having(
            (e) => e.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
      expect(auth.session().status, AuthStatus.authenticated);
      expect(auth.session().acr, before.acr);

      final s = await auth.stepUp(
        method: StepUpMethod.password,
        password: 'pw',
        acr: Acr.aal2,
      );
      expect(s.acr, Acr.aal2);
      expect(f.bodies['/v1/reauthenticate']!['acr'], 'aal2');

      // totp without factorId: the one active totp factor is looked up.
      await auth.stepUp(method: StepUpMethod.totp, code: '654321');
      expect(
        f.bodies['/v1/reauthenticate']!['factor_id'],
        '11111111-1111-1111-1111-111111111111',
      );
      final list = await auth.listFactors();
      expect(list.recoveryCodesRemaining, 9);
    },
  );

  test('step-up and refresh never run side by side', () async {
    final f = FakeIssuer();
    final auth = make(f);
    await auth.signInWithPassword('plain@example.com', 'pw');
    final results = await Future.wait([
      auth.refresh(),
      auth.stepUp(method: StepUpMethod.password, password: 'pw'),
      auth.refresh(),
    ]);
    expect(results.last.status, AuthStatus.authenticated);
    // Every presented refresh token was the current one (no invalid_refresh).
    expect(auth.session().status, AuthStatus.authenticated);
  });

  test(
    'proactive refresh is scheduled before expiry; 503 keeps the session and backs off',
    () async {
      final f = FakeIssuer();
      final timers = Timers();
      final auth = make(f, timers: timers);
      await auth.signInWithPassword('plain@example.com', 'pw');
      final d = timers.scheduled.last;
      // exp 900 s, rotation interval 900-120 = 780 s, plus up to 10 s jitter.
      expect(d.inSeconds, inInclusiveRange(780, 790));

      f.refreshStatus = 503;
      await expectLater(
        auth.refresh(),
        throwsA(
          isA<AxiomAuthError>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
      expect(
        auth.session().status,
        AuthStatus.authenticated,
        reason: 'token still valid',
      );
      expect(
        timers.scheduled.last.inSeconds,
        7,
        reason: 'Retry-After honoured',
      );
      await expectLater(
        auth.refresh(),
        throwsA(
          isA<AxiomAuthError>().having(
            (e) => e.retryAfterSeconds,
            'retryAfter',
            7,
          ),
        ),
      );

      // Background: no timer; foreground after expiry refreshes at once.
      auth.setForeground(false);
      f.refreshStatus = 200;
      f.now += 1000 * 1000;
      final n = f.calls.length;
      auth.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(f.calls.length, n + 1);
    },
  );

  test('runtimeAuthRefusal and parseStepUpChallenge', () {
    final r = runtimeAuthRefusal(
      '{"error":{"code":"step_up_required","message":"x acr_values=aal2, max_age=600"}}',
    )!;
    expect(r.code, 'step_up_required');
    expect(r.acr, Acr.aal2);
    expect(r.maxAge, 600);
    expect(
      runtimeAuthRefusal({
        'error': {'code': 'authorization_changed'},
      })!.code,
      'authorization_changed',
    );
    expect(runtimeAuthRefusal('not json'), isNull);
    final c = parseStepUpChallenge(
      http.Response(
        '',
        401,
        headers: {
          'www-authenticate':
              'Bearer error="insufficient_user_authentication", acr_values="aal2", max_age=60',
        },
      ),
    )!;
    expect(c.acr, Acr.aal2);
    expect(c.maxAge, 60);
  });

  test('validReturnTo', () {
    expect(validReturnTo('/home?x=1'), isTrue);
    expect(validReturnTo('//evil.com'), isFalse);
    expect(validReturnTo(r'/\evil'), isFalse);
    expect(validReturnTo('https://evil.com'), isFalse);
    expect(validReturnTo('/a\nb'), isFalse);
  });
}
