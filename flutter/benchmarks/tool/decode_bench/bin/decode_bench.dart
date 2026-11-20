// Decode harness: bytes -> typed models on the Dart VM, same payload as the
// bench server (`GET /items?n=`). Run JIT: `dart run bin/decode_bench.dart`;
// AOT: `dart compile exe bin/decode_bench.dart -o /tmp/db && /tmp/db`.
// Prints one row per (n, parse, decoder): median and p90 in ms.
import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_decode_bench/gen/models.dart' as ax;
import 'package:bench_dio_client/src/models.dart' as js;
import 'package:bench_http_client/bench_http_client.dart' as hc;
import 'package:axiom_decode_bench/variants.dart' as v;

Map<String, Object?> item(int i) => {
  'id': '$i',
  'name': 'item $i',
  'price': i * 1.25,
  'qty': i % 100,
  'active': i.isEven,
  'tags': ['t${i % 7}', 'bench'],
};

Uint8List body(int n) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'items': [for (var i = 1; i <= n; i++) item(i)],
      'total': n,
    }),
  ),
);

final _fused = utf8.decoder.fuse(json.decoder);

typedef Parse = Object? Function(Uint8List);
final parsers = <String, Parse>{
  'fused': (b) => _fused.convert(b),
  'string': (b) => jsonDecode(utf8.decode(b)),
};

final decoders = <String, int Function(Object?)>{
  'json_only': (j) => ((j as Map)['items'] as List).length,
  'axiom_generated': (j) => ax.ItemList.fromJson(j).items.length,
  'json_serializable': (j) =>
      js.ItemList.fromJson(j as Map<String, dynamic>).items.length,
  'variant_a': (j) => v.listA((j as Map)['items']).length,
  'variant_b': (j) => v.listB((j as Map)['items']).length,
  'variant_c': (j) => v.listC((j as Map)['items']).length,
  'variant_bg': (j) => v.listBG((j as Map)['items']).length,
  'variant_d': (j) => v.listD((j as Map)['items']).length,
  'manual': (j) => hc.ItemList.fromJson(j as Map<String, dynamic>).items.length,
};

double _median(List<double> xs) => (xs..sort())[xs.length ~/ 2];
double _p90(List<double> xs) => (xs..sort())[(xs.length * 0.9).floor()];

void main(List<String> argv) {
  final sizes = argv.isEmpty ? [1000, 10000] : argv.map(int.parse).toList();
  final rows = <String>[];
  for (final n in sizes) {
    final bytes = body(n);
    final iters = n >= 10000 ? 60 : 400;
    // Model build only (pre-parsed tree).
    final tree = _fused.convert(bytes);
    for (final d in decoders.entries) {
      if (d.key == 'json_only') continue;
      rows.add(_run('$n', 'tree', d.key, iters, n, () => d.value(tree)));
    }
    if (const bool.fromEnvironment('treeOnly')) continue;
    for (final p in parsers.entries) {
      for (final d in decoders.entries) {
        rows.add(
          _run('$n', p.key, d.key, iters, n, () => d.value(p.value(bytes))),
        );
      }
    }
  }
  print('n\tparse\tdecoder\tmedian_ms\tp90_ms');
  rows.forEach(print);
}

String _run(String n, String parse, String dec, int iters, int expect,
    int Function() f) {
  for (var i = 0; i < iters ~/ 4 + 5; i++) {
    if (f() != expect) throw StateError('$dec decoded wrong count');
  }
  final sw = Stopwatch();
  var best = <double>[double.infinity];
  for (var round = 0; round < 3; round++) {
  final times = <double>[];
  for (var i = 0; i < iters; i++) {
    sw
      ..reset()
      ..start();
    f();
    sw.stop();
    times.add(sw.elapsedMicroseconds / 1000);
  }
  if (_median(times) < _median(best)) best = times;
  }
  final times = best;
  return '$n\t$parse\t$dec\t${_median(times).toStringAsFixed(3)}\t${_p90(times).toStringAsFixed(3)}';
}
