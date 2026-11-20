// Native Dart VM harness ("native (Linux VM)" column; not a phone). Runs the same BenchRunner
// scenarios as the app, in the flutter_tester process (Dart VM, JIT; axiom_flutter needs the
// Flutter SDK, so plain `dart run` / `dart compile exe` cannot load it), against the host runtime
// library given by AXIOM_RUNTIME_LIB. No widget binding is initialised, so dart:io HTTP is real.
//
//   AXIOM_RUNTIME_LIB=/abs/libaxiom_runtime.so VM_BENCH=latency,parallel flutter test \
//     test/vm_bench_test.dart --dart-define=BENCH_BASE_URL=http://127.0.0.1:8771 [--dart-define=BENCH_PROTO=h2]
//
// Driver with 3 runs and JSONL output: tool/vm_bench.dart.
@TestOn('vm')
@Timeout(Duration(minutes: 30))
library;

import 'dart:io';

import 'package:axiom_bench_app/bench.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lib = Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
  test('vm bench', () async {
    final sel = Platform.environment['VM_BENCH'];
    if (sel != null && sel.isNotEmpty) benchSelectionOverride = sel;
    benchAssetLoader = (p) => File(p).readAsBytes();
    final label = Platform.environment['VM_BENCH_PLATFORM'] ?? 'linux-vm';
    await BenchRunner((r) {
      emitLine({...r, 'platform': label, 'mode': 'jit (flutter_tester)', 'runtime_lib': lib.split('/').reversed.skip(1).take(2).toList().reversed.join('/')});
    }, Stopwatch()..start())
        .run();
  }, skip: lib.isEmpty ? 'AXIOM_RUNTIME_LIB not set' : null);
}
