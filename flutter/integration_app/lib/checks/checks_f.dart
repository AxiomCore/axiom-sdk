// Unit f: axiom_flutter_auth (managed auth) on device.
//
// auth_f.binding_* drive the real runtime against the fixture backend: a
// scripted issuer (in-process MockClient) hands out the fixture's bearer token
// as the access token, the binding pushes it into the runtime, and the
// fixture's bearer-protected endpoint must answer; after sign-out it must
// refuse. auth_f.platform_storage uses the real Keychain / Keystore /
// sessionStorage. auth_f.emulator_sign_in needs
// --dart-define=AXIOM_AUTH_ISSUER=... --dart-define=AXIOM_AUTH_EMAIL=...
// --dart-define=AXIOM_AUTH_PASSWORD=... (a verified user on `axiom auth emulate`).
import 'dart:convert';

import 'package:axiom_flutter_auth/axiom_flutter_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'ctx.dart';

const _issuer = 'https://auth.fixture.invalid/local/fixture';
const _emuIssuer = String.fromEnvironment('AXIOM_AUTH_ISSUER');
const _emuEmail = String.fromEnvironment('AXIOM_AUTH_EMAIL');
const _emuPassword = String.fromEnvironment('AXIOM_AUTH_PASSWORD');

MockClient _scriptedIssuer() {
  var n = 0;
  return MockClient((req) async {
    final path = req.url.path.replaceFirst('/local/fixture', '');
    if (path == '/v1/sign-in/password' || path == '/v1/token/refresh') {
      n++;
      return http.Response(
          jsonEncode({
            'access_token': fixtureBearerToken,
            'refresh_token': 'fx.r$n',
            'refresh_expires_at': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
            'session': {'id': 'fx'},
          }),
          200,
          headers: {'content-type': 'application/json'});
    }
    if (path == '/v1/logout') return http.Response('{}', 200);
    return http.Response('{"error":{"code":"AXAUTH_NOT_FOUND"}}', 404);
  });
}

final checksF = <CheckDef>[
  CheckDef('auth_f.binding_authorizes_calls', 'auth_f', (c) async {
    final auth = AxiomAuth(AxiomAuthOptions(issuer: _issuer, httpClient: _scriptedIssuer()));
    final binding = AxiomAuthBinding.attach(auth,
        runtime: c.sdk.runtime, namespaces: const ['fixture'], authMethods: const {'fixture': ['authBearer']}, resetSessionOnSignOut: false);
    try {
      c.api.axiom.clearAuthToken('authBearer');
      await auth.signInWithPassword('fixture@example.com', 'irrelevant');
      expectEq(binding.lastPushedToken, fixtureBearerToken, 'pushed token');
      final r = await data(c.api.authBearer());
      expectEq(r.method, 'bearer', 'method');
      await auth.signOut();
      final e = await failure(c.api.authBearer());
      expectEq(httpStatusOf(e), 401, 'status after sign-out (error: $e)');
    } finally {
      binding.detach();
      auth.dispose();
      resetAuthState(c); // detach() keeps pushed tokens
    }
  }),
  CheckDef('auth_f.provider_answers_runtime', 'auth_f', (c) async {
    final auth = AxiomAuth(AxiomAuthOptions(issuer: _issuer, httpClient: _scriptedIssuer()));
    final binding = AxiomAuthBinding.attach(auth,
        runtime: c.sdk.runtime, namespaces: const ['fixture'], resetSessionOnSignOut: false);
    try {
      if (!binding.providerRegistered) skip('runtime has no setAuthProvider yet (f1)');
      await auth.signInWithPassword('fixture@example.com', 'irrelevant');
      expectEq(await auth.accessToken(), fixtureBearerToken, 'token');
    } finally {
      binding.detach();
      auth.dispose();
      // detach() keeps the namespace token pushed at sign-in; without this
      // `fixture` keeps a bearer token for every later check.
      resetAuthState(c);
    }
  }),
  CheckDef('auth_f.platform_storage', 'auth_f', (c) async {
    final s = platformStorage();
    const key = 'axiom-auth:refresh:check';
    const rec = RefreshRecord(
        refreshToken: 'fx.r1', refreshExpiresAt: '2030-01-01T00:00:00.000Z', issuer: _issuer, audience: 'api', sessionId: 'fx');
    await s.set(key, rec);
    final back = await s.get(key);
    expectEq(back?.refreshToken, 'fx.r1', 'stored refresh token');
    await s.remove(key);
    expectEq(await s.get(key), null, 'after remove');
  }),
  CheckDef('auth_f.restore_from_platform_storage', 'auth_f', (c) async {
    final storage = platformStorage();
    final a = AxiomAuth(AxiomAuthOptions(issuer: _issuer, httpClient: _scriptedIssuer(), storage: storage));
    await a.signInWithPassword('fixture@example.com', 'irrelevant');
    a.dispose();
    final b = AxiomAuth(AxiomAuthOptions(issuer: _issuer, httpClient: _scriptedIssuer(), storage: storage));
    final s = await b.restore();
    expectEq(s.status, AuthStatus.authenticated, 'restored status');
    await b.signOut();
    expectEq((await storage.get('axiom-auth:refresh:$_issuer')), null, 'record removed on sign-out');
  }),
  CheckDef('auth_f.emulator_sign_in', 'auth_f', (c) async {
    if (_emuIssuer.isEmpty || _emuEmail.isEmpty) skip('set AXIOM_AUTH_ISSUER, AXIOM_AUTH_EMAIL, AXIOM_AUTH_PASSWORD');
    final auth = AxiomAuth(const AxiomAuthOptions(issuer: _emuIssuer));
    try {
      await auth.signInWithPassword(_emuEmail, _emuPassword);
      expectEq(auth.session().status, AuthStatus.authenticated, 'status');
      final before = await auth.accessToken();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await auth.refresh();
      expectThat(await auth.accessToken() != before, 'access token rotated');
      expectEq((await auth.user())?.email, _emuEmail, 'user email');
      await auth.signOut();
      expectEq(auth.session().status, AuthStatus.anonymous, 'after sign-out');
    } finally {
      auth.dispose();
    }
  }),
];
