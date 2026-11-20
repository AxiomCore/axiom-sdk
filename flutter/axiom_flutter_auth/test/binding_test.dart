// AxiomAuthBinding scoping (review F6): the access token reaches only the
// namespaces the binding was attached for. Runs without the emulator: a
// scripted issuer (MockClient) hands out a fixed JWT.
import 'dart:convert';

import 'package:axiom_flutter/axiom_flutter.dart';
// ignore: implementation_imports
import 'package:axiom_flutter/src/internal/auth_headers.dart';
import 'package:axiom_flutter_auth/axiom_flutter_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _issuer = 'https://auth.test.invalid/local/p';

String _jwt(int n) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'none'})}.${b64({'sub': 'u', 'iat': 1763640000, 'exp': 4102444800, 'n': n})}.sig';
}

MockClient _scriptedIssuer() {
  var n = 0;
  return MockClient((req) async {
    final path = req.url.path.replaceFirst('/local/p', '');
    if (path == '/v1/sign-in/password' || path == '/v1/token/refresh') {
      n++;
      return http.Response(
        jsonEncode({
          'access_token': _jwt(n),
          'refresh_token': 'r$n',
          'refresh_expires_at': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
          'session': {'id': 's'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/v1/logout') return http.Response('{}', 200);
    return http.Response('{"error":{"code":"AXAUTH_NOT_FOUND"}}', 404);
  });
}

class _Rt implements AxiomRuntime {
  _Rt({this.namespaceSupported = true});
  final bool namespaceSupported;
  String? global;
  final Map<String, String> ns = {};
  final Map<String, String> perMethod = {};
  AxiomAuthProvider? provider;
  int resets = 0;

  @override
  void setGlobalAuthToken(String token) => global = token;
  @override
  void clearGlobalAuthToken() => global = null;
  @override
  void setNamespaceAuthToken({required String namespace, required String token}) {
    if (!namespaceSupported) throw UnimplementedError('setNamespaceAuthToken');
    ns[namespace] = token;
  }

  @override
  void clearNamespaceAuthToken({required String namespace}) {
    if (!namespaceSupported) throw UnimplementedError('clearNamespaceAuthToken');
    ns.remove(namespace);
  }

  @override
  void setAuthToken({required String namespace, required String methodName, required String token}) =>
      perMethod['$namespace.$methodName'] = token;
  @override
  void clearAuthToken({required String namespace, required String methodName}) =>
      perMethod.remove('$namespace.$methodName');
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
  test('token goes to the bound namespaces only, never global', () async {
    final rt = _Rt();
    rt.ns['cms'] = 'app-set-vendor-key';
    final auth = AxiomAuth(AxiomAuthOptions(issuer: _issuer, httpClient: _scriptedIssuer()));
    final binding = AxiomAuthBinding.attach(auth, runtime: rt, namespaces: const ['api', 'billing']);
    await auth.signInWithPassword('a@example.com', 'pw');
    final t = await auth.accessToken();
    expect(rt.global, isNull, reason: 'binding must never set a global token');
    expect(rt.ns, {'api': t, 'billing': t, 'cms': 'app-set-vendor-key'});
    expect(await rt.provider!('api', 'm'), t);
    expect(await rt.provider!('cms', 'm'), isNull, reason: 'third-party namespace gets no user token');
    expect(await rt.provider!('', ''), isNull);
    await auth.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(rt.ns, {'cms': 'app-set-vendor-key'}, reason: 'sign-out clears exactly the bound namespaces');
    expect(rt.resets, 1);
    expect(await rt.provider!('cms', 'm'), isNull, reason: 're-registered provider stays scoped');
    binding.detach();
    expect(rt.provider, isNull);
    auth.dispose();
  });

  test('namespaces is required and non-empty; authMethods must be in scope', () {
    final auth = AxiomAuth(AxiomAuthOptions(issuer: _issuer, httpClient: _scriptedIssuer()));
    expect(() => AxiomAuthBinding.attach(auth, runtime: _Rt(), namespaces: const []), throwsArgumentError);
    expect(
      () => AxiomAuthBinding.attach(
        auth,
        runtime: _Rt(),
        namespaces: const ['api'],
        authMethods: const {
          'cms': ['bearer'],
        },
      ),
      throwsArgumentError,
    );
    auth.dispose();
  });

  test('old runtime: per-method fallback for bound namespaces only', () async {
    final rt = _Rt(namespaceSupported: false);
    final auth = AxiomAuth(AxiomAuthOptions(issuer: _issuer, httpClient: _scriptedIssuer()));
    AxiomAuthBinding.attach(
      auth,
      runtime: rt,
      namespaces: const ['api'],
      authMethods: const {
        'api': ['bearer'],
      },
    );
    await auth.signInWithPassword('a@example.com', 'pw');
    expect(rt.perMethod, {'api.bearer': await auth.accessToken()});
    expect(rt.global, isNull);
    await auth.signOut();
    expect(rt.perMethod, isEmpty);
    auth.dispose();
  });

  test('explicit token rule: never another namespace\'s token', () {
    const tokens = {'api': 'A'};
    expect(AxiomAuthHeaders.explicitTokenFor('api', tokens, null), 'A');
    expect(AxiomAuthHeaders.explicitTokenFor('cms', tokens, null), isNull);
    expect(AxiomAuthHeaders.explicitTokenFor('', tokens, null), isNull);
    expect(AxiomAuthHeaders.explicitTokenFor('cms', tokens, 'G'), 'G');
    expect(AxiomAuthHeaders.explicitTokenFor('api', tokens, 'G'), 'A');
    expect(AxiomAuthHeaders.explicitTokenFor('cms', const {'cms': ''}, null), isNull);
  });
}
