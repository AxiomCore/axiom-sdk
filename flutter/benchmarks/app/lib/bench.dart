// Benchmark runner. Prints one `AXIOM_BENCH <json>` line per result and a final
// `AXIOM_BENCH {"bench":"done",...}` line. No interaction needed.
//
// Select with --dart-define=BENCH=<list>, comma separated:
//   all (default)  latency,cache,decode,ws   (cold start needs a fresh process, see below)
//   cold:axiom | cold:dio | cold:http        one cold start measurement; run each in its own launch
//   latency | cache | decode | ws
// Other defines: BENCH_BASE_URL (default http://127.0.0.1:8851), BENCH_CALLS (default 200).
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:bench_dio_client/bench_dio_client.dart' as rf;
import 'package:bench_http_client/bench_http_client.dart' as hc;
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'axiom_generated/axiom_sdk.dart';
import 'axiom_generated/models.dart' as ax;

const String benchBaseUrl =
    String.fromEnvironment('BENCH_BASE_URL', defaultValue: 'http://127.0.0.1:8851');
const String benchSelection = String.fromEnvironment('BENCH', defaultValue: 'all');
const int benchCalls = int.fromEnvironment('BENCH_CALLS', defaultValue: 200);

String get platformName {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name;
}

String get buildMode => kReleaseMode
    ? 'release'
    : kProfileMode
        ? 'profile'
        : 'debug';

typedef Emit = void Function(Map<String, Object?> result);

void emitLine(Map<String, Object?> result) {
  // debugPrint may throttle; print reaches stdout/logcat/console on every platform.
  // ignore: avoid_print
  print('AXIOM_BENCH ${jsonEncode(result)}');
}

Map<String, Object?> stats(List<double> ms) {
  final s = [...ms]..sort();
  double pct(double p) => s[math.min(s.length - 1, (p * s.length).ceil() - 1).clamp(0, s.length - 1)];
  final mean = s.reduce((a, b) => a + b) / s.length;
  return {
    'samples': s.length,
    'p50_ms': _r(pct(0.50)),
    'p95_ms': _r(pct(0.95)),
    'mean_ms': _r(mean),
    'min_ms': _r(s.first),
    'max_ms': _r(s.last),
  };
}

double _r(double v) => (v * 1000).roundToDouble() / 1000;

double _ms(Stopwatch sw) => sw.elapsedMicroseconds / 1000.0;

Future<AxiomSdk> createBenchSdk() => AxiomSdk.create(
      config: const AxiomConfig(
        contracts: {
          'bench': AxiomContractConfig(baseUrl: benchBaseUrl, assetPath: 'assets/axiom/bench.axiom'),
        },
      ),
    );

/// Waits for the first data (or error) of an Axiom query and returns the state.
Future<AxiomState<T>> settle<T>(AxiomQuery<T> q) => q.stream
    .firstWhere((s) => s.status == AxiomStatus.success || s.status == AxiomStatus.error)
    .timeout(const Duration(seconds: 60));

Future<T> axData<T>(AxiomQuery<T> q) async {
  final s = await settle(q);
  if (s.status == AxiomStatus.error || s.data == null) {
    throw StateError('axiom error: ${s.error}');
  }
  return s.data as T;
}

Dio newDio() => Dio(BaseOptions(baseUrl: benchBaseUrl));

class BenchRunner {
  BenchRunner(this.emit, this.mainStart);
  final Emit emit;

  /// Started as the first statement of main().
  final Stopwatch mainStart;

  Map<String, Object?> _base(String bench) =>
      {'bench': bench, 'platform': platformName, 'mode': buildMode};

  Future<void> run() async {
    final sel = benchSelection.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
    final all = sel.contains('all');
    final ran = <String>[];
    Future<void> step(String name, Future<void> Function() f) async {
      ran.add(name);
      try {
        await f();
      } catch (e, st) {
        emit({..._base(name), 'status': 'error', 'error': '$e', 'stack': '$st'.split('\n').take(4).join(' | ')});
      }
    }

    for (final c in ['axiom', 'dio', 'http']) {
      if (sel.contains('cold:$c')) await step('cold:$c', () => cold(c));
    }
    AxiomSdk? sdk;
    Future<AxiomSdk> getSdk() async => sdk ??= await createBenchSdk();
    if (all || sel.contains('latency')) await step('latency', () async => latency(await getSdk()));
    if (all || sel.contains('cache')) await step('cache', () async => cache(await getSdk()));
    if (all || sel.contains('decode')) await step('decode', decode);
    if (all || sel.contains('ws')) await step('ws', () async => ws(await getSdk()));
    emit({..._base('done'), 'ran': ran, 'base_url': benchBaseUrl, 'calls': benchCalls});
  }

  // ---- cold start: runtime init + contract load + first call, from main() entry ----
  Future<void> cold(String client) async {
    final sw = Stopwatch()..start();
    int items;
    double? initMs;
    switch (client) {
      case 'axiom':
        final sdk = await createBenchSdk();
        initMs = _ms(sw);
        items = (await axData(sdk.bench.listItems(n: 1))).items.length;
      case 'dio':
        final api = rf.BenchApi(newDio(), baseUrl: benchBaseUrl);
        initMs = _ms(sw);
        items = (await api.listItems(1)).items.length;
      default:
        final api = hc.HttpBenchApi(benchBaseUrl);
        initMs = _ms(sw);
        items = (await api.listItems(1)).items.length;
    }
    sw.stop();
    emit({
      ..._base('cold'),
      'client': client,
      'status': items == 1 ? 'ok' : 'error',
      'first_data_ms': _r(_ms(sw)),
      'init_ms': _r(initMs),
      'since_main_ms': _r(_ms(mainStart)),
      'method': 'fresh launch; timer starts after runApp, before client construction; one listItems(n:1)',
    });
  }

  // ---- per-call latency ----
  Future<void> latency(AxiomSdk sdk) async {
    final dioApi = rf.BenchApi(newDio(), baseUrl: benchBaseUrl);
    final httpApi = hc.HttpBenchApi(benchBaseUrl);
    final cases = <String, Map<String, Future<int> Function(int i)>>{
      'small_get_item': {
        'axiom': (i) async => (await axData(sdk.bench.getItem(id: '${i % 50 + 1}'))).qty,
        'dio': (i) async => (await dioApi.getItem('${i % 50 + 1}')).qty,
        'http': (i) async => (await httpApi.getItem('${i % 50 + 1}')).qty,
      },
      'small_create_item': {
        'axiom': (i) async => (await axData(sdk.bench.createItem(name: 'n$i', price: 1.5, qty: i))).qty,
        'dio': (i) async => (await dioApi.createItem(rf.ItemInput(name: 'n$i', price: 1.5, qty: i))).qty,
        'http': (i) async => (await httpApi.createItem(name: 'n$i', price: 1.5, qty: i)).qty,
      },
      'large_list_1000': {
        'axiom': (i) async => (await axData(sdk.bench.listItems(n: 1000))).items.length,
        'dio': (i) async => (await dioApi.listItems(1000)).items.length,
        'http': (i) async => (await httpApi.listItems(1000)).items.length,
      },
    };
    const warmup = 20;
    for (final c in cases.entries) {
      for (final client in c.value.entries) {
        final samples = <double>[];
        for (var i = 0; i < warmup + benchCalls; i++) {
          final sw = Stopwatch()..start();
          await client.value(i);
          sw.stop();
          if (i >= warmup) samples.add(_ms(sw));
        }
        emit({
          ..._base('latency'),
          'case': c.key,
          'client': client.key,
          'status': 'ok',
          'warmup': warmup,
          ...stats(samples),
        });
      }
    }
    httpApi.close();
  }

  // ---- cache hit: time to first data on a repeat call ----
  Future<void> cache(AxiomSdk sdk) async {
    const n = 1000;
    const reps = 50;
    // Axiom: cachedItems is cacheFirst (ttl 10m) in the contract.
    {
      final first = Stopwatch()..start();
      await axData(sdk.bench.cachedItems(n: n));
      first.stop();
      final samples = <double>[];
      final sources = <String, int>{};
      for (var i = 0; i < reps; i++) {
        final sw = Stopwatch()..start();
        final s = await settle(sdk.bench.cachedItems(n: n));
        sw.stop();
        samples.add(_ms(sw));
        sources[s.source.name] = (sources[s.source.name] ?? 0) + 1;
      }
      final allCache = sources.keys.length == 1 && sources.containsKey('cache');
      emit({
        ..._base('cache'),
        'client': 'axiom',
        'case': 'repeat_list_$n',
        'status': allCache ? 'ok' : 'blocked',
        if (!allCache) 'note': 'repeat calls were not answered from the runtime cache',
        'sources': sources,
        'first_call_ms': _r(_ms(first)),
        ...stats(samples),
      });
    }
    // dio + dio_cache_interceptor, in-memory store, forceCache (ignores HTTP headers).
    {
      final dio = newDio()
        ..interceptors.add(DioCacheInterceptor(
          options: CacheOptions(store: MemCacheStore(), policy: CachePolicy.forceCache),
        ));
      final api = rf.BenchApi(dio, baseUrl: benchBaseUrl);
      final first = Stopwatch()..start();
      await api.cachedItems(n);
      first.stop();
      final samples = <double>[];
      for (var i = 0; i < reps; i++) {
        final sw = Stopwatch()..start();
        await api.cachedItems(n);
        sw.stop();
        samples.add(_ms(sw));
      }
      emit({
        ..._base('cache'),
        'client': 'dio_cache_interceptor',
        'case': 'repeat_list_$n',
        'status': 'ok',
        'store': 'MemCacheStore, CachePolicy.forceCache',
        'first_call_ms': _r(_ms(first)),
        ...stats(samples),
      });
    }
  }

  // ---- decode: bytes -> typed models, no network ----
  Future<void> decode() async {
    for (final n in const [1000, 10000]) {
      final res = await http.get(Uri.parse('$benchBaseUrl/items?n=$n'));
      final bytes = res.bodyBytes;
      final reps = n >= 10000 ? 20 : 50;
      final decoders = <String, int Function()>{
        'json_only': () => ((jsonDecode(utf8.decode(bytes)) as Map)['items'] as List).length,
        'axiom_generated': () => ax.ItemList.fromJson(jsonDecode(utf8.decode(bytes))).items.length,
        'json_serializable': () =>
            rf.ItemList.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>).items.length,
        'manual_fromJson': () =>
            hc.ItemList.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>).items.length,
      };
      for (final d in decoders.entries) {
        for (var i = 0; i < 5; i++) {
          d.value();
        }
        final samples = <double>[];
        for (var i = 0; i < reps; i++) {
          final sw = Stopwatch()..start();
          final got = d.value();
          sw.stop();
          if (got != n) throw StateError('${d.key}: decoded $got of $n');
          samples.add(_ms(sw));
          await Future<void>.delayed(Duration.zero);
        }
        emit({
          ..._base('decode'),
          'items': n,
          'bytes': bytes.length,
          'decoder': d.key,
          'status': 'ok',
          'method': 'utf8.decode + jsonDecode + fromJson on the main isolate; Axiom runtime-side validation not included',
          ...stats(samples),
        });
      }
    }
  }

  // ---- WebSocket round trips ----
  Future<void> ws(AxiomSdk sdk) async {
    const msgs = 1000;
    final wsUrl = '${benchBaseUrl.replaceFirst('http', 'ws')}/ws';
    // web_socket_channel: send one message, await its echo, repeat.
    {
      final ch = WebSocketChannel.connect(Uri.parse(wsUrl));
      await ch.ready;
      final it = StreamIterator(ch.stream);
      for (var i = 0; i < 20; i++) {
        ch.sink.add(jsonEncode({'text': 'warm', 'seq': i}));
        await it.moveNext();
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < msgs; i++) {
        ch.sink.add(jsonEncode({'text': 'ping', 'seq': i}));
        await it.moveNext();
        final p = jsonDecode(it.current as String) as Map<String, dynamic>;
        if (p['seq'] != i) throw StateError('out of order echo');
      }
      sw.stop();
      await ch.sink.close();
      emit({
        ..._base('ws'),
        'client': 'web_socket_channel',
        'status': 'ok',
        'messages': msgs,
        'round_trips_per_s': _r(msgs / (sw.elapsedMicroseconds / 1e6)),
        'mean_rtt_ms': _r(_ms(sw) / msgs),
      });
    }
    // Axiom typed channel.
    try {
      final ch = sdk.bench.wsEchoChannel(reconnect: AxiomReconnectPolicy.none);
      final it = StreamIterator(ch.stream.where((s) => s.status == AxiomStatus.success));
      final sw = Stopwatch()..start();
      for (var i = 0; i < msgs; i++) {
        ch.send(ax.Ping(text: 'ping', seq: i));
        await it.moveNext().timeout(const Duration(seconds: 10));
      }
      sw.stop();
      await ch.close();
      emit({
        ..._base('ws'),
        'client': 'axiom',
        'status': 'ok',
        'messages': msgs,
        'round_trips_per_s': _r(msgs / (sw.elapsedMicroseconds / 1e6)),
        'mean_rtt_ms': _r(_ms(sw) / msgs),
      });
    } on UnimplementedError catch (e) {
      emit({..._base('ws'), 'client': 'axiom', 'status': 'blocked', 'note': 'openChannel not implemented on this branch: $e'});
    }
  }
}
