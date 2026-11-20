// F15: a failed initialize() is not cached; a retry can succeed.
// F4: re-initialisation after shutdown works (runtime reset first).
// Needs AXIOM_RUNTIME_LIB (skipped otherwise).
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lib = Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
  if (lib.isEmpty) {
    test('fixn init tests', () {}, skip: 'AXIOM_RUNTIME_LIB not set');
    return;
  }
  const contract = '../integration_app/assets/axiom/fixture.axiom';
  final config = AxiomConfig(contracts: {
    'fx': AxiomContractConfig(baseUrl: 'http://127.0.0.1:9', assetPath: contract),
  });

  test('F15 failed initialize can be retried', () async {
    final rt = AxiomRuntime();
    var calls = 0;
    Future<Uint8List> flaky(String p) async {
      if (++calls == 1) throw const SocketException('offline');
      return File(p).readAsBytes();
    }

    final first = await rt.initialize(config, assetLoader: flaky);
    expect(first.ok, isFalse);
    final second = await rt.initialize(config, assetLoader: flaky);
    expect(second.ok, isTrue, reason: '${second.error}');
    expect(second.alreadyInitialized, isFalse);
    final third = await rt.initialize(config, assetLoader: flaky);
    expect(third.ok, isTrue);
    expect(third.alreadyInitialized, isTrue);
  });

  test('F4 shutdown then initialize again', () async {
    final rt = AxiomRuntime();
    await rt.shutdown();
    expect(rt.isInitialized, isFalse);
    final r = await rt.initialize(config,
        assetLoader: (p) => File(p).readAsBytes());
    expect(r.ok, isTrue, reason: '${r.error}');
    expect(rt.isInitialized, isTrue);
    await rt.shutdown();
  });
}
