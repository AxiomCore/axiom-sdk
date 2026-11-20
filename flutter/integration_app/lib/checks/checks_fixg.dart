// Unit fixg: review fixes F6 (scoped auth binding) and F14 (unknown enum
// values keep their wire value), against the fixture backend.
import 'dart:convert';

import 'package:axiom_flutter_auth/axiom_flutter_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../axiom_generated/models.dart';
import 'ctx.dart';

const _issuer = 'https://auth.fixture.invalid/local/fixg';

/// Issuer stand-in handing out the fixture's bearer token.
MockClient _issuerClient() => MockClient((req) async {
  final path = req.url.path.replaceFirst('/local/fixg', '');
  if (path == '/v1/sign-in/password' || path == '/v1/token/refresh') {
    return http.Response(
        jsonEncode({
          'access_token': fixtureBearerToken,
          'refresh_token': 'fixg.r',
          'refresh_expires_at': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
          'session': {'id': 'fixg'},
        }),
        200,
        headers: {'content-type': 'application/json'});
  }
  if (path == '/v1/logout') return http.Response('{}', 200);
  return http.Response('{"error":{"code":"AXAUTH_NOT_FOUND"}}', 404);
});

final checksFixg = <CheckDef>[
  CheckDef('fixg.binding_other_namespace_gets_no_token', 'auth_f', (c) async {
    final auth = AxiomAuth(AxiomAuthOptions(issuer: _issuer, httpClient: _issuerClient()));
    final binding = AxiomAuthBinding.attach(auth,
        runtime: c.sdk.runtime, namespaces: const ['fixg_vendor'], resetSessionOnSignOut: false);
    try {
      resetAuthState(c); // clean state: no token or provider from earlier checks
      await auth.signInWithPassword('fixture@example.com', 'irrelevant');
      expectEq(binding.lastPushedToken, fixtureBearerToken, 'token pushed for the bound namespace');
      final e = await failure(c.api.authBearer());
      expectEq(httpStatusOf(e), 401, 'fixture (not bound) must not receive the token (error: $e)');
    } finally {
      binding.detach();
      auth.dispose();
      resetAuthState(c);
    }
  }),
  CheckDef('fixg.unknown_enum_round_trips', 'types', (c) async {
    final r = await data(c.api.everything());
    final wire = r.toJson();
    final future = {...wire, 'color': 'ultraviolet'};
    final e = Everything.fromJson(future);
    expectThat(e.color.isUnknown, 'decoded as unknown');
    expectEq(e.toJson()['color'], 'ultraviolet', 'wire value sent back');
    expectEq(e.copyWith(note: 'x').toJson()['color'], 'ultraviolet', 'kept through copyWith');
    expectEq(e.copyWith(color: EverythingColor.red).toJson()['color'], 'red', 'replaced value');
    var threw = false;
    try {
      EverythingColor.unknown.toJson();
    } on StateError {
      threw = true;
    }
    expectThat(threw, 'bare unknown has no wire value');
  }),
];
