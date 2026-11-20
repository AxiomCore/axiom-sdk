import 'ctx.dart';

final authChecks = <CheckDef>[
  CheckDef('auth.bearer_missing_is_401', 'auth', (c) async {
    c.api.axiom.clearAuthToken('authBearer');
    final e = await failure(c.api.authBearer());
    expectEq(httpStatusOf(e), 401, 'status (error: $e)');
  }),
  CheckDef('auth.bearer_token', 'auth', (c) async {
    c.api.axiom.setAuthToken('authBearer', fixtureBearerToken);
    try {
      final r = await data(c.api.authBearer());
      expectEq(r.method, 'bearer', 'method');
    } finally {
      c.api.axiom.clearAuthToken('authBearer');
    }
  }),
  CheckDef('auth.api_key_header', 'auth', (c) async {
    final r = await data(c.api.authApiKeyHeader(xApiKey: fixtureApiKey));
    expectEq(r.ok, true, 'ok');
  }),
  CheckDef('auth.api_key_header_wrong_is_401', 'auth', (c) async {
    final e = await failure(c.api.authApiKeyHeader(xApiKey: 'nope'));
    expectEq(httpStatusOf(e), 401, 'status (error: $e)');
  }),
  CheckDef('auth.api_key_query', 'auth', (c) async {
    final r = await data(c.api.authApiKeyQuery(apiKey: fixtureApiKey));
    expectEq(r.ok, true, 'ok');
  }),
  CheckDef('auth.namespace_global_token', 'auth', (c) async {
    skip('pending: f1 (namespace-wide and global token setters)');
  }),
  CheckDef('auth.provider_refresh', 'auth', (c) async {
    skip('pending: f1 (setAuthProvider -> axiom_register_auth_provider)');
  }),
  CheckDef('auth.cookie_session', 'auth', (c) async {
    skip('pending: fixture uses JWT; deployment allows one auth provider');
  }),
];
