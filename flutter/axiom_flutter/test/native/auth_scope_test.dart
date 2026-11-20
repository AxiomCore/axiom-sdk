// Clean-state auth scope (fix3): a namespace that is not bound (what
// AxiomAuthBinding.attach(namespaces: [...]) does: namespace token + a provider
// that answers only for its namespaces) never gets an Authorization header.
// Native path: a real runtime against a local capture server. The header rule
// itself (internal/auth_headers.dart) is shared with web and is checked in
// test/auth_headers_test.dart.
//
//   AXIOM_RUNTIME_LIB=/abs/libaxiom_runtime.so flutter test test/native/auth_scope_test.dart
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

final _lib = Platform.environment['AXIOM_RUNTIME_LIB'];
const _assets = '../integration_app/assets/axiom';
const _epEcho = 1421147111;

void main() {
  if ((_lib ?? '').isEmpty) {
    test('auth scope tests', () {}, skip: 'AXIOM_RUNTIME_LIB not set');
    return;
  }
  late HttpServer server;
  final seen = <String, String?>{}; // path -> Authorization header
  late AxiomRuntime rt;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      seen[r.uri.path] = r.headers.value('authorization');
      r.response
        ..headers.contentType = ContentType.json
        ..write('{"path":"x","q":"x"}');
      await r.response.close();
    });
    rt = AxiomRuntime();
    final base = 'http://127.0.0.1:${server.port}';
    final r = await rt.initialize(
      AxiomConfig(contracts: {
        'bound': AxiomContractConfig(
            baseUrl: base, assetPath: '$_assets/fixture.axiom'),
        'other': AxiomContractConfig(
            baseUrl: base, assetPath: '$_assets/fixture.axiom'),
      }),
      assetLoader: (p) async => Uint8List.fromList(await File(p).readAsBytes()),
    );
    expect(r.ok, isTrue, reason: '$r');
  });

  tearDownAll(() async {
    rt.setAuthProvider(null);
    rt.clearNamespaceAuthToken(namespace: 'bound');
    await rt.shutdown();
    await server.close(force: true);
  });

  Future<String?> authOf(String ns) async {
    final path = '/echo/$ns-${DateTime.now().microsecondsSinceEpoch}';
    final s = rt.callStream(
      namespace: ns,
      endpointId: _epEcho,
      method: 'GET',
      path: path,
      requestBytes: Uint8List(0),
    );
    await s.stream
        .firstWhere((x) => x.isSuccess || x.hasError)
        .timeout(const Duration(seconds: 10));
    expect(seen.containsKey(path), isTrue, reason: 'request not seen');
    return seen[path];
  }

  test('unbound namespace gets no token; bound one does', () async {
    const token = 'scope-token';
    // Clean state first: nothing is sent anywhere.
    expect(await authOf('other'), isNull);
    expect(await authOf('bound'), isNull);

    rt.setNamespaceAuthToken(namespace: 'bound', token: token);
    rt.setAuthProvider(
        (ns, method) async => ns == 'bound' ? token : null);
    expect(await authOf('bound'), 'Bearer $token');
    expect(await authOf('other'), isNull,
        reason: 'a namespace token or bound provider leaked to "other"');

    // Provider only (token cleared): still scoped.
    rt.clearNamespaceAuthToken(namespace: 'bound');
    expect(await authOf('bound'), 'Bearer $token');
    expect(await authOf('other'), isNull);

    // Fully cleared: nothing is sent.
    rt.setAuthProvider(null);
    expect(await authOf('bound'), isNull);
  });
}
