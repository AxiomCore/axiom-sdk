// Native Dart VM harness driver: the "native (Linux VM)" column (a server CPU, not a phone).
//
//   dart run tool/vm_bench.dart --lib /abs/libaxiom_runtime.so [--runs 3] [--out results/raw-vm.jsonl]
//       [--base http://127.0.0.1:8771] [--bench latency,cache,decode,extra] [--h2 clients,parallel]
//       [--calls 200] [--cold 5]
//
// Each run is one fresh `flutter test test/vm_bench_test.dart` process in ../app (Dart VM, JIT:
// axiom_flutter imports the Flutter SDK, so `dart run`/`dart compile exe` cannot load it; the
// flutter_tester VM is the closest native host). Run i writes records with "run": "vm-<i>" (h1)
// and "vm-h2-<i>" (HTTPS listener, BENCH_PROTO=h2). The bench server must be running with its
// TLS listener: tool/server.sh 8771 8773.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> argv) async {
  final a = <String, String>{};
  for (var i = 0; i + 1 < argv.length; i += 2) {
    a[argv[i].replaceFirst(RegExp('^--'), '')] = argv[i + 1];
  }
  final lib = a['lib'] ?? Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
  if (lib.isEmpty || !File(lib).existsSync()) {
    stderr.writeln('need --lib /abs/libaxiom_runtime.so (or AXIOM_RUNTIME_LIB)');
    exit(2);
  }
  final root = File.fromUri(Platform.script).parent.parent.path;
  final runs = int.parse(a['runs'] ?? '3');
  final out = File(a['out'] ?? '$root/results/raw-vm.jsonl');
  final base = a['base'] ?? 'http://127.0.0.1:8771';
  final bench = a['bench'] ?? 'latency,cache,decode,extra';
  final h2 = a['h2'] ?? 'clients,parallel';
  final calls = a['calls'] ?? '200';
  final cold = int.parse(a['cold'] ?? '5');
  out.parent.createSync(recursive: true);
  final sink = out.openWrite();
  Future<void> one(String sel, String proto, String label) async {
    stdout.writeln('== $label ($proto: $sel)');
    final p = await Process.start(
      'flutter',
      [
        'test',
        'test/vm_bench_test.dart',
        '--dart-define=BENCH_BASE_URL=$base',
        '--dart-define=BENCH_PROTO=$proto',
        '--dart-define=BENCH_CALLS=$calls',
      ],
      workingDirectory: '$root/app',
      environment: {'AXIOM_RUNTIME_LIB': lib, 'VM_BENCH': sel},
    );
    p.stderr.transform(utf8.decoder).listen(stderr.write);
    await for (final line in p.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      final i = line.indexOf('AXIOM_BENCH ');
      if (i < 0) continue;
      final rec = jsonDecode(line.substring(i + 12)) as Map<String, dynamic>;
      rec['run'] = label;
      sink.writeln(jsonEncode(rec));
      stdout.writeln('${rec['bench']} ${rec['case'] ?? rec['items'] ?? ''} ${rec['client'] ?? rec['decoder'] ?? ''} '
          '${rec['status'] ?? ''} p50=${rec['p50_ms'] ?? rec['round_trips_per_s'] ?? ''}');
    }
    final code = await p.exitCode;
    if (code != 0) stderr.writeln('$label: flutter test exited $code');
  }

  for (var r = 1; r <= runs; r++) {
    // Cold start: one fresh process per measurement (timer starts in the test body; the VM and
    // test-runner start-up before it are not counted, as engine start-up is not on the app side).
    for (var i = 1; i <= cold; i++) {
      for (final c in const ['axiom', 'dio', 'http']) {
        await one('cold:$c', 'h1', 'vm-$r-cold-$c-$i');
      }
    }
    await one(bench, 'h1', 'vm-$r');
    if (h2.isNotEmpty && h2 != 'none') await one(h2, 'h2', 'vm-h2-$r');
  }
  await sink.close();
  stdout.writeln('wrote ${out.path}');
}
