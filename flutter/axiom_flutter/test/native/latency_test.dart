// Sequential call latency through the native binding (callStream -> first
// data). Skipped unless AXIOM_RUNTIME_LIB is set; prints p50/p90.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lib = Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
  test('p50 call latency', () async {
    final rt = AxiomRuntime();
    final contract = Platform.environment['AXIOM_FIXTURE_CONTRACT'] ??
        '../integration_app/assets/axiom/fixture.axiom';
    final url = Platform.environment['AXIOM_FIXTURE_URL'] ?? 'http://127.0.0.1:8791';
    // Legacy start-up API so the same test also runs on older bindings.
    await rt.init();
    rt.loadContract(
      namespace: 'fixture',
      baseUrl: url,
      contractBytes: await File(contract).readAsBytes(),
    );
    final samples = <int>[];
    for (var i = 0; i < 120; i++) {
      final sw = Stopwatch()..start();
      final r = rt.callStream(
        namespace: 'fixture',
        endpointId: 1643923642,
        method: 'GET',
        path: '/types/everything',
        requestBytes: Uint8List(0),
      );
      await r.stream.firstWhere((s) => s.hasData || s.hasError);
      samples.add(sw.elapsedMicroseconds);
      // Idle gap like a UI between calls.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    samples.removeRange(0, 20); // warm-up
    samples.sort();
    final p50 = samples[samples.length ~/ 2] / 1000;
    final p90 = samples[(samples.length * 9) ~/ 10] / 1000;
    // ignore: avoid_print
    print('AXIOM_LATENCY p50=${p50.toStringAsFixed(2)}ms p90=${p90.toStringAsFixed(2)}ms n=${samples.length}');
  }, skip: lib.isEmpty ? 'AXIOM_RUNTIME_LIB not set' : null);
}
