// Runs against `axiom auth emulate` (tool/emulator.sh sets AXIOM_AUTH_ISSUER).
// Skipped when the variable is absent.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_flutter_auth/axiom_flutter_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

final String? issuer = Platform.environment['AXIOM_AUTH_ISSUER'];
const callback = 'http://127.0.0.1:5173/auth/callback';
final _rnd = Random();
String email() =>
    'u${DateTime.now().microsecondsSinceEpoch}${_rnd.nextInt(1 << 20)}@example.com';
const password = 'correct horse battery';

Uri get _origin => Uri.parse(issuer!).replace(path: '');

/// Latest 6-digit code mailed to [to].
Future<String> mailedCode(String to, {String subject = 'Confirm'}) async {
  for (var i = 0; i < 20; i++) {
    final r = await http.get(_origin.replace(path: '/local/mail.json'));
    final text = r.body;
    final mails = (jsonDecode(text)['mail'] as List).cast<Map>();
    for (final m in mails.reversed) {
      final s = jsonEncode(m);
      if (!s.contains(to) || !s.contains(subject)) continue;
      final match = RegExp(r'Your code is (\d{6})').firstMatch(s);
      if (match != null) return match.group(1)!;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('no mail for $to');
}

/// Follows the issuer's redirects in process: the browser stand-in.
class FollowLauncher implements AuthRedirectLauncher {
  int calls = 0;
  @override
  Future<Uri?> authenticate(
    Uri url, {
    required String callbackUrlScheme,
  }) async {
    calls++;
    final client = HttpClient();
    try {
      var next = url;
      for (var i = 0; i < 10; i++) {
        if (next.toString().startsWith(callback)) return next;
        final req = await client.getUrl(next);
        req.followRedirects = false;
        final res = await req.close();
        await res.drain<void>();
        final loc = res.headers.value('location');
        if (loc == null)
          throw StateError('no redirect from $next (${res.statusCode})');
        next = next.resolve(loc);
      }
      throw StateError('too many redirects');
    } finally {
      client.close();
    }
  }
}

Future<void> signUpVerified(AxiomAuth auth, String e) async {
  final r = await auth.signUp(e, password);
  expect(r.status, 'verification_sent');
  await auth.verifySignUp(r.challenge!, await mailedCode(e));
}

class FakeRuntime implements AxiomRuntime {
  FakeRuntime({this.globalSupported = true});
  final bool globalSupported;
  String? global;
  final Map<String, String> ns = {};

  @override
  void setNamespaceAuthToken({
    required String namespace,
    required String token,
  }) {
    if (!globalSupported) throw UnimplementedError('setNamespaceAuthToken');
    ns[namespace] = token;
  }

  @override
  void clearNamespaceAuthToken({required String namespace}) {
    if (!globalSupported) throw UnimplementedError('clearNamespaceAuthToken');
    ns.remove(namespace);
  }

  final Map<String, String> perMethod = {};
  AxiomAuthProvider? provider;
  int resets = 0;

  @override
  void setGlobalAuthToken(String token) {
    if (!globalSupported) throw UnimplementedError('setGlobalAuthToken');
    global = token;
  }

  @override
  void clearGlobalAuthToken() {
    if (!globalSupported) throw UnimplementedError('clearGlobalAuthToken');
    global = null;
  }

  @override
  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  }) => perMethod['$namespace.$methodName'] = token;

  @override
  void clearAuthToken({
    required String namespace,
    required String methodName,
  }) => perMethod.remove('$namespace.$methodName');

  @override
  void setAuthProvider(AxiomAuthProvider? p) => provider = p;

  @override
  Future<void> resetSession() async {
    resets++;
    provider = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final skip = issuer == null
      ? 'AXIOM_AUTH_ISSUER not set (run tool/emulator.sh)'
      : null;

  group('emulator', skip: skip, () {
    test('sign-up with email verification, user, sign-out revokes', () async {
      final auth = AxiomAuth(AxiomAuthOptions(issuer: issuer!));
      final statuses = <AuthStatus>[];
      auth.subscribe((s) => statuses.add(s.status));
      final e = email();
      await signUpVerified(auth, e);
      expect(auth.session().status, AuthStatus.authenticated);
      expect(auth.session().principal, isNotNull);
      final user = await auth.user();
      expect(user!.email, e);
      expect(user.hasPassword, isTrue);
      final token = await auth.accessToken();
      expect(token, isNotNull);
      // Never a token in toJson / toString.
      expect(jsonEncode(auth.toJson()).contains(token!), isFalse);

      await auth.signOut();
      expect(auth.session().status, AuthStatus.anonymous);
      expect(await auth.accessToken(), isNull);
      expect(
        statuses,
        containsAllInOrder([AuthStatus.authenticated, AuthStatus.anonymous]),
      );
      auth.dispose();
    });

    test(
      'password sign-in, wrong password, refresh rotates, reuse ends session',
      () async {
        final storage = memoryStorage();
        final auth = AxiomAuth(
          AxiomAuthOptions(issuer: issuer!, storage: storage),
        );
        final e = email();
        await signUpVerified(auth, e);
        await auth.signOut();

        await expectLater(
          auth.signInWithPassword(e, 'wrong password!'),
          throwsA(
            isA<AxiomAuthError>().having(
              (x) => x.code,
              'code',
              'invalid_credentials',
            ),
          ),
        );
        expect(auth.session().status, AuthStatus.anonymous);

        await auth.signInWithPassword(e, password);
        expect(auth.session().status, AuthStatus.authenticated);
        final key = 'axiom-auth:refresh:$issuer';
        final rec1 = (await storage.get(key))!;
        final at1 = await auth.accessToken();
        final sessionId = auth.session().id;

        await Future<void>.delayed(
          const Duration(milliseconds: 1100),
        ); // new iat
        await auth.refresh();
        final rec2 = (await storage.get(key))!;
        expect(
          rec2.refreshToken,
          isNot(rec1.refreshToken),
          reason: 'refresh token rotates',
        );
        expect(await auth.accessToken(), isNot(at1));
        expect(auth.session().id, sessionId);

        // Concurrent refreshes share one request (no reuse detection triggered).
        await Future.wait([auth.refresh(), auth.refresh(), auth.refresh()]);
        expect(auth.session().status, AuthStatus.authenticated);

        // Presenting the rotated-out token ends the family on the issuer.
        final r = await http.post(
          Uri.parse('$issuer/v1/token/refresh'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'refresh_token': rec1.refreshToken}),
        );
        expect(r.statusCode, 401);
        await expectLater(
          auth.refresh(),
          throwsA(
            isA<AxiomAuthError>().having(
              (x) => x.code,
              'code',
              'invalid_refresh',
            ),
          ),
        );
        expect(auth.session().status, AuthStatus.expired);
        expect(await storage.get(key), isNull);
        auth.dispose();
      },
    );

    test(
      'restore from storage in a new client; sign-out revokes the stored record',
      () async {
        final storage = memoryStorage();
        final a = AxiomAuth(
          AxiomAuthOptions(issuer: issuer!, storage: storage),
        );
        final e = email();
        await signUpVerified(a, e);
        a.dispose();

        final b = AxiomAuth(
          AxiomAuthOptions(issuer: issuer!, storage: storage),
        );
        final s = await b.restore();
        expect(s.status, AuthStatus.authenticated);
        expect((await b.user())!.email, e);
        final stored = (await storage.get('axiom-auth:refresh:$issuer'))!;
        await b.signOut();
        final r = await http.post(
          Uri.parse('$issuer/v1/token/refresh'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'refresh_token': stored.refreshToken}),
        );
        expect(r.statusCode, 401, reason: 'revoked on the issuer');

        final c = AxiomAuth(
          AxiomAuthOptions(issuer: issuer!, storage: storage),
        );
        expect((await c.restore()).status, AuthStatus.anonymous);
      },
    );

    test('email code sign-in', () async {
      final auth = AxiomAuth(AxiomAuthOptions(issuer: issuer!));
      final e = email();
      await signUpVerified(auth, e);
      await auth.signOut();
      final ch = await auth.requestEmailCode(e);
      await auth.verifyEmailCode(
        ch.challenge,
        await mailedCode(e, subject: 'sign-in code'),
      );
      expect(auth.session().status, AuthStatus.authenticated);
    });

    test('provider redirect with PKCE (mock OIDC identity)', () async {
      final launcher = FollowLauncher();
      final auth = AxiomAuth(
        AxiomAuthOptions(
          issuer: issuer!,
          redirectUri: callback,
          launcher: launcher,
        ),
      );
      final s = await auth.signInWithProvider(
        'local',
        loginHint: 'alice@example.com',
        returnTo: '/home',
      );
      expect(launcher.calls, 1);
      expect(s.status, AuthStatus.authenticated);
      expect((await auth.user())!.email, 'alice@example.com');
    });

    test('callback with a foreign state is refused', () async {
      final auth = AxiomAuth(
        AxiomAuthOptions(issuer: issuer!, redirectUri: callback),
      );
      await expectLater(
        auth.handleRedirect(
          Uri.parse('$callback?code=x&state=nope&iss=$issuer'),
        ),
        throwsA(
          isA<AxiomAuthError>().having((x) => x.code, 'code', 'state_mismatch'),
        ),
      );
      expect(
        (await auth.handleRedirect(
          Uri.parse('http://127.0.0.1:5173/other?code=x'),
        )).handled,
        isFalse,
      );
    });

    test(
      'binding pushes tokens into the runtime and resets on sign-out',
      () async {
        final rt = FakeRuntime();
        final auth = AxiomAuth(AxiomAuthOptions(issuer: issuer!));
        final binding = AxiomAuthBinding.attach(
          auth,
          runtime: rt,
          namespaces: const ['fixture'],
        );
        expect(rt.provider, isNotNull);
        await signUpVerified(auth, email());
        final t = await auth.accessToken();
        expect(
          rt.global,
          isNull,
          reason: 'the binding is scoped, never global',
        );
        expect(rt.ns['fixture'], t);
        expect(await rt.provider!('fixture', 'authBearer'), t);
        expect(await rt.provider!('other', 'authBearer'), isNull);
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await auth.refresh();
        expect(rt.ns['fixture'], await auth.accessToken());
        expect(rt.ns['fixture'], isNot(t));
        await auth.signOut();
        await Future<void>.delayed(Duration.zero);
        expect(rt.ns, isEmpty);
        expect(rt.resets, 1);
        expect(
          rt.provider,
          isNotNull,
          reason: 're-registered after resetSession',
        );
        binding.detach();
        expect(rt.provider, isNull);
      },
    );

    test('binding falls back to per-method tokens', () async {
      final rt = FakeRuntime(globalSupported: false);
      final auth = AxiomAuth(AxiomAuthOptions(issuer: issuer!));
      AxiomAuthBinding.attach(
        auth,
        runtime: rt,
        namespaces: const ['fixture'],
        authMethods: {
          'fixture': ['authBearer'],
        },
      );
      await signUpVerified(auth, email());
      expect(rt.perMethod['fixture.authBearer'], await auth.accessToken());
      await auth.signOut();
      expect(rt.perMethod, isEmpty);
    });

    test('authorizedClient sends the bearer to apiOrigins only', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seen = <String?>[];
      server.listen((req) {
        seen.add(req.headers.value('authorization'));
        req.response
          ..statusCode = 200
          ..close();
      });
      final origin = 'http://127.0.0.1:${server.port}';
      final auth = AxiomAuth(
        AxiomAuthOptions(issuer: issuer!, apiOrigins: [origin]),
      );
      await signUpVerified(auth, email());
      final client = auth.authorizedClient();
      await client.get(Uri.parse('$origin/x'));
      await client.get(
        Uri.parse('http://localhost:${server.port}/y'),
      ); // other origin
      expect(seen[0], 'Bearer ${await auth.accessToken()}');
      expect(seen[1], isNull);
      await server.close(force: true);
    });
  });
}
