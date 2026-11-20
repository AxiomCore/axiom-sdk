import 'package:axiom_flutter_auth/axiom_flutter_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const rec = RefreshRecord(
  refreshToken: 's.r1',
  refreshExpiresAt: '2026-12-01T00:00:00.000Z',
  issuer: 'https://auth.test/p',
  audience: 'api',
  sessionId: 's',
);

Future<void> roundTrip(AuthStorageAdapter s) async {
  const key = 'axiom-auth:refresh:https://auth.test/p';
  expect(await s.get(key), isNull);
  await s.set(key, rec);
  final back = (await s.get(key))!;
  expect(back.refreshToken, 's.r1');
  expect(back.sessionId, 's');
  expect(back.toString().contains('s.r1'), isFalse, reason: 'no token in toString');
  await s.remove(key);
  expect(await s.get(key), isNull);
  expect(s.shared, isFalse);
}

void main() {
  test('memoryStorage round trip', () => roundTrip(memoryStorage()));

  test('secureStorage round trip (platform mock)', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await roundTrip(secureStorage());
  });

  test('secureStorage ignores a corrupt entry', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const fss = FlutterSecureStorage();
    final s = secureStorage(storage: fss);
    await s.set('k', rec);
    final all = await fss.readAll();
    await fss.write(key: all.keys.single, value: '{not json');
    expect(await s.get('k'), isNull);
  });

  test('sessionStorageAdapter is unavailable off the web', () async {
    await expectLater(sessionStorageAdapter().get('k'), throwsA(isA<AxiomAuthError>()));
  });

  testWidgets('AxiomAuthBuilder follows the session', (tester) async {
    final auth = AxiomAuth(const AxiomAuthOptions(issuer: 'https://auth.test/p'));
    await tester.pumpWidget(MaterialApp(
      home: AxiomAuthBuilder(
        auth: auth,
        loading: (_, __) => const Text('loading'),
        signedIn: (_, s) => Text('in ${s.principal!.subject}'),
        signedOut: (_, __) => const Text('out'),
      ),
    ));
    expect(find.text('loading'), findsOneWidget);
    await tester.runAsync(() => auth.restore()); // memory storage: anonymous
    await tester.pump();
    expect(find.text('out'), findsOneWidget);
    expect(auth.sessionListenable.value.status, AuthStatus.anonymous);
  });
}
