// Unit dartnative (0.150.1): object cache (C2.1) and off-isolate decode
// (C1.3) through the real binding. Skipped unless AXIOM_RUNTIME_LIB is set.
// Uses the benchmark contract (cachedItems = cache_first 600 s,
// listItems = network_only) against a Dart server on its own isolate.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_flutter/src/query_manager.dart';
import 'package:axiom_flutter/src/runtime_io.dart';
import 'package:flutter_test/flutter_test.dart';

const _contract = '../benchmarks/app/assets/axiom/bench.axiom';
const _cachedItems = 1375712977;
const _listItems = 113632206;

class Item {
  Item(this.id, this.name, this.price);
  final String id;
  final String name;
  final double price;
}

class ItemList {
  ItemList(this.items, this.total);
  final List<Item> items;
  final int total;
  static ItemList fromJson(dynamic j) {
    final m = j as Map<String, dynamic>;
    final l = m['items'] as List;
    return ItemList(
      List<Item>.generate(l.length, (i) {
        final e = l[i] as Map<String, dynamic>;
        return Item(e['id'] as String, e['name'] as String,
            (e['price'] as num).toDouble());
      }),
      m['total'] as int,
    );
  }
}

/// Isolate-local state set by a decoder (like the generated models' raw
/// enum wire values): must survive off-isolate decoding (review B4).
final _tag = Expando<String>();

ItemList taggedDecoder(dynamic j) {
  final l = ItemList.fromJson(j);
  _tag[l] = 'kept';
  return l;
}

ItemList otherDecoder(dynamic j) => ItemList(ItemList.fromJson(j).items, -1);

/// Server on its own isolate. `?v=` in the body changes when the test sends
/// 'bump', so a changed body can be detected.
void _server(SendPort out) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final control = ReceivePort();
  var version = 0;
  control.listen((_) => version++);
  out.send([s.port, control.sendPort]);
  final bodies = <String, List<int>>{};
  await for (final r in s) {
    final n = int.parse(r.uri.queryParameters['n'] ?? '1');
    final key = '$n/$version';
    final body = bodies.putIfAbsent(
      key,
      () => utf8.encode(jsonEncode({
        'items': [
          for (var i = 1; i <= n; i++)
            {
              'id': '$i',
              'name': 'item $i v$version',
              'price': i * 1.25,
              'qty': i % 100,
              'active': i.isEven,
              'tags': ['t${i % 7}', 'bench'],
            },
        ],
        'total': n,
      })),
    );
    r.response.headers.contentType = ContentType.json;
    if (r.uri.path.startsWith('/cached')) {
      r.response.headers.set('cache-control', 'max-age=600');
    }
    r.response.add(body);
    await r.response.close();
  }
}

Future<AxiomState<T>> settle<T>(Stream<AxiomState<T>> s) => s
    .firstWhere((x) => (x.hasData && !x.isFetching) || x.hasError)
    .timeout(const Duration(seconds: 20));

void main() {
  final lib = Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
  if (lib.isEmpty) {
    test('dartnative native tests', () {}, skip: 'AXIOM_RUNTIME_LIB not set');
    return;
  }
  late AxiomRuntimeIo rt;
  late SendPort bump;

  AxiomQuery<ItemList> call(int ep, int n,
          {AxiomCallOptions? options,
          ItemList Function(dynamic) decoder = ItemList.fromJson}) =>
      rt.send<ItemList>(
        namespace: 'bench',
        endpointId: ep,
        method: 'GET',
        path: ep == _cachedItems ? '/cached/items' : '/items',
        queryParams: {'n': '$n'},
        args: {'n': n},
        decoder: decoder,
        options: options,
      );

  Future<ItemList> fetch(int ep, int n,
      {ItemList Function(dynamic) decoder = ItemList.fromJson}) async {
    final s = await settle(call(ep, n, decoder: decoder).stream);
    expect(s.hasError, isFalse, reason: '${s.error}');
    return s.data!;
  }

  setUpAll(() async {
    final ready = ReceivePort();
    await Isolate.spawn(_server, ready.sendPort);
    final msg = await ready.first as List;
    bump = msg[1] as SendPort;
    final db = Directory.systemTemp.createTempSync('axiom_dn_');
    rt = AxiomRuntime() as AxiomRuntimeIo;
    final r = await rt.initialize(
      AxiomConfig(
        dbPath: db.path,
        contracts: {
          'bench': AxiomContractConfig(
            baseUrl: 'http://127.0.0.1:${msg[0]}',
            assetPath: _contract,
          ),
        },
      ),
      assetLoader: (p) async => Uint8List.fromList(File(p).readAsBytesSync()),
    );
    expect(r.ok, isTrue, reason: '${r.error}');
  });

  Future<String> p50(int n) async {
    final times = <int>[];
    for (var i = 0; i < 30; i++) {
      final sw = Stopwatch()..start();
      await fetch(_cachedItems, n);
      times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    return 'p50=${times[15] / 1000}ms min=${times.first / 1000}ms';
  }

  test('B5 object cache is off by default: no shared mutable instance',
      () async {
    expect(rt.objectCache.maxEntries, 0);
    final a = await fetch(_listItems, 50);
    a.items.removeWhere((_) => true); // caller edits its result in place
    final b = await fetch(_listItems, 50);
    expect(identical(a, b), isFalse);
    expect(b.items.length, 50);
  });

  test('B5 object cache key includes the decoder', () async {
    rt.objectCache.maxEntries = 64;
    addTearDown(() {
      rt.objectCache.maxEntries = 0;
      rt.objectCache.removeWhere();
    });
    final a = await fetch(_listItems, 60);
    expect(a.total, 60);
    // Forget the live query (it keeps its first decoder) so the second call
    // reaches the object cache with another decoder.
    AxiomQueryManager().clear();
    final b = await fetch(_listItems, 60, decoder: otherDecoder);
    expect(b.total, -1, reason: 'decoded by its own decoder, not a hit');
  });

  test('B4 off-isolate decode keeps decoder isolate-local state', () async {
    final old = rt.decodeIsolateThreshold;
    rt.decodeIsolateThreshold = 1; // force the background path
    addTearDown(() => rt.decodeIsolateThreshold = old);
    final a = await fetch(_listItems, 1000, decoder: taggedDecoder);
    expect(a.items.length, 1000);
    expect(_tag[a], 'kept');
  });

  test('C2.1 cache-first repeat with and without the object cache', () async {
    rt.objectCache.maxEntries = 0;
    await fetch(_cachedItems, 1000);
    final off = await p50(1000);
    rt.objectCache.maxEntries = 64;
    await fetch(_cachedItems, 1000);
    final on = await p50(1000);
    rt.objectCache.maxEntries = 0;
    // ignore: avoid_print
    print('DN_CACHE_REPEAT_1K object_cache_off $off | on $on');
  });

  test('C2.1 cache hit returns the same instance; clearCache drops it',
      () async {
    rt.objectCache.maxEntries = 64;
    addTearDown(() => rt.objectCache.maxEntries = 0);
    final a = await fetch(_cachedItems, 1000);
    final times = <int>[];
    ItemList? b;
    for (var i = 0; i < 30; i++) {
      final sw = Stopwatch()..start();
      b = await fetch(_cachedItems, 1000);
      times.add(sw.elapsedMicroseconds);
    }
    expect(identical(a, b), isTrue);
    times.sort();
    // ignore: avoid_print
    print('DN_CACHE_HIT_1K p50=${times[15] / 1000}ms min=${times.first / 1000}ms '
        'hits=${rt.objectCache.hits}');
    await rt.clearCache('bench');
    expect(rt.objectCache.length, 0);
    final c = await fetch(_cachedItems, 1000);
    expect(identical(a, c), isFalse);
    expect(c.items.length, 1000);
  });

  test('C2.1 never serves a model the byte cache would not (body changed)',
      () async {
    rt.objectCache.maxEntries = 64;
    addTearDown(() => rt.objectCache.maxEntries = 0);
    final a = await fetch(_listItems, 100);
    final a2 = await fetch(_listItems, 100);
    expect(identical(a, a2), isTrue, reason: 'same bytes -> same model');
    bump.send('bump');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final b = await fetch(_listItems, 100);
    expect(identical(a, b), isFalse);
    expect(b.items.first.name, endsWith('v1'));
  });

  final totals = <int, List<int>>{};
  Future<int> longestStretchUs(int threshold) async {
    rt.decodeIsolateThreshold = threshold;
    rt.objectCache.removeWhere();
    var maxGap = 0;
    final sw = Stopwatch()..start();
    var last = 0;
    final t = Timer.periodic(const Duration(milliseconds: 1), (_) {
      final now = sw.elapsedMicroseconds;
      if (now - last > maxGap) maxGap = now - last;
      last = now;
    });
    final start = sw.elapsedMicroseconds;
    final s = await settle(
      call(_listItems, 10000,
              options: const AxiomCallOptions(cacheMode: AxiomCacheMode.refresh))
          .stream,
    );
    (totals[threshold] ??= []).add(sw.elapsedMicroseconds - start);
    // One more tick so a stretch that ends with the call is counted.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    t.cancel();
    expect(s.data!.items.length, 10000);
    return maxGap;
  }

  test('C1.3 10k body: longest synchronous stretch on the calling isolate',
      () async {
    await longestStretchUs(0); // warm up
    final inline = <int>[];
    final off = <int>[];
    for (var i = 0; i < 7; i++) {
      inline.add(await longestStretchUs(0));
      off.add(await longestStretchUs(256 * 1024));
    }
    inline.sort();
    off.sort();
    // ignore: avoid_print
    print('DN_BLOCK_10K inline_median=${inline[3] / 1000}ms '
        'isolate_median=${off[3] / 1000}ms inline=$inline off=$off');
    final ti = totals[0]!..sort();
    final to = totals[256 * 1024]!..sort();
    // ignore: avoid_print
    print('DN_TOTAL_10K inline_median=${ti[ti.length ~/ 2] / 1000}ms '
        'isolate_median=${to[to.length ~/ 2] / 1000}ms');
  });
}
