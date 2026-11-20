// F3: the response pump tracks in-flight request ids. With a runtime that
// cannot drain on resetSession (axiom_reset_session hidden here), a request
// started after the reset must still complete when an older request's
// Complete arrives first. Needs AXIOM_RUNTIME_LIB (skipped otherwise).
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_flutter/src/runtime_io.dart' show AxiomRuntimeIo;
import 'package:flutter_test/flutter_test.dart';

const epEverything = 1643923642;

void main() {
  final lib = Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
  if (lib.isEmpty) {
    test('fixn pump tests', () {}, skip: 'AXIOM_RUNTIME_LIB not set');
    return;
  }
  late HttpServer server;
  late AxiomRuntime rt;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      final ms = int.tryParse(r.uri.queryParameters['ms'] ?? '') ?? 0;
      await Future<void>.delayed(Duration(milliseconds: ms));
      r.response
        ..headers.contentType = ContentType.json
        ..write('{"ms":$ms}');
      await r.response.close();
    });
    AxiomRuntimeIo.debugHiddenSymbols = {
      'axiom_reset_session',
      'axiom_clear_auth_provider',
    };
    rt = AxiomRuntime();
    // Fixture contract with response validation off (any JSON body).
    final j = jsonDecode(File('../integration_app/assets/axiom/fixture.axiom')
        .readAsStringSync()) as Map<String, dynamic>;
    for (final e in (j['endpoints'] as List)) {
      (e as Map)['validation_enabled'] = false;
    }
    final res = await rt.initialize(
      AxiomConfig(contracts: {
        'fx': AxiomContractConfig(
          baseUrl: 'http://127.0.0.1:${server.port}',
          assetPath: 'fx',
        ),
      }),
      assetLoader: (_) async => Uint8List.fromList(utf8.encode(jsonEncode(j))),
    );
    expect(res.ok, isTrue, reason: '$res');
  });

  tearDownAll(() async {
    await rt.shutdown();
    await server.close(force: true);
  });

  AxiomStreamResponse call(int ms) => rt.callStream(
        namespace: 'fx',
        endpointId: epEverything,
        method: 'GET',
        path: '/types/everything',
        queryParams: {'ms': ms},
        requestBytes: Uint8List(0),
      );

  test('F3 request after resetSession completes when an old Complete arrives first',
      () async {
    final a = call(300);
    a.stream.listen((_) {}, onError: (_) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await rt.resetSession();
    final b = call(800);
    final states = <AxiomState<Uint8List>>[];
    final done = Completer<void>();
    b.stream.listen(states.add, onDone: done.complete);
    await done.future.timeout(const Duration(seconds: 5),
        onTimeout: () => fail('request after reset hung: $states'));
    expect(states.any((s) => s.hasData), isTrue, reason: '${states.map((s) => '${s.status} ${s.error}')}');
  });

  test('F13 without axiom_clear_auth_provider a fresh v1 auth callable is '
      'registered at start', () {
    expect((rt as AxiomRuntimeIo).debugV1AuthCallableRegistered, isTrue);
  });
}
