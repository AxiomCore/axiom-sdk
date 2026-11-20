// Scenarios added by unit bench2 (0.150.1 programme). Each prints AXIOM_BENCH lines through the
// same emitter as bench.dart and is selected by name in BENCH / ?bench=:
//
//   parallel  20 calls started at once, wall time until all are done (getItem, listItems(1000))
//   offline   cached repeat call, then first data while the server drops every connection
//   jank      longest main-isolate stall while a 10k-item list is fetched and decoded
//   ttfi      time to first item of the 10k list (streaming clients: NDJSON route)
//   clients   per-call latency for the extra clients (dio+compute, dio HTTP/2, platform HTTP)
//
// `proto` in every record is h1 (plain HTTP/1.1 base URL) or h2 (HTTPS base URL, HTTP/2 when the
// client negotiates it: browsers, dio_http2_adapter; dart:io clients stay on HTTP/1.1 over TLS and
// are labelled `tls_h1`).
import 'dart:async';
import 'dart:convert';

import 'package:bench_dio_client/bench_dio_client.dart' as rf;
import 'package:bench_http_client/bench_http_client.dart' as hc;
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'axiom_generated/axiom_sdk.dart';
import 'bench.dart' show axFresh;
import 'clients/platform_clients.dart';

typedef Base = Map<String, Object?> Function(String bench);
typedef Stats = Map<String, Object?> Function(List<double> ms);

double _ms(Stopwatch sw) => sw.elapsedMicroseconds / 1000.0;

/// Top-level so `compute` can send it to a background isolate (runs inline on web).
rf.ItemList decodeItemList(Uint8List bytes) =>
    rf.ItemList.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);

class ExtraBench {
  ExtraBench({
    required this.emit,
    required this.base,
    required this.stats,
    required this.baseUrl,
    required this.isH2,
    required this.calls,
  });

  final void Function(Map<String, Object?>) emit;
  final Base base;
  final Stats stats;
  final String baseUrl;
  final bool isH2;
  final int calls;

  Dio _dio() => (isH2 && !kIsWeb ? newInsecureDio(baseUrl) : null) ?? Dio(BaseOptions(baseUrl: baseUrl));

  /// Runs one client's measurement; a failure becomes a `status: error` row and the next client
  /// still runs (e.g. the native Axiom runtime does not trust the self-signed h2 certificate).
  Future<void> _guard(String bench, String? caseName, String client, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      emit({
        ...base(bench),
        if (caseName != null) 'case': caseName,
        'client': client,
        'proto': _proto(client),
        'status': 'error',
        'error': '$e'.split('\n').first,
      });
    }
  }

  http.Client _httpClient() => (isH2 && !kIsWeb ? newInsecureHttpClient() : null) ?? http.Client();

  /// The comparison clients for a list call returning the item count, by name. Axiom first.
  Map<String, Future<int> Function(int n)> listClients(AxiomSdk sdk) {
    final dioApi = rf.BenchApi(_dio(), baseUrl: baseUrl);
    final dioBytes = _dio();
    final httpApi = hc.HttpBenchApi(baseUrl, client: _httpClient());
    final out = <String, Future<int> Function(int n)>{
      'axiom': (n) async => (await axFresh(sdk.bench.listItems(n: n))).items.length,
      'dio': (n) async => (await dioApi.listItems(n)).items.length,
      'dio_compute': (n) async {
        final r = await dioBytes.get<List<int>>(
          '/items',
          queryParameters: {'n': n},
          options: Options(responseType: ResponseType.bytes),
        );
        return (await compute(decodeItemList, Uint8List.fromList(r.data!))).items.length;
      },
      'http': (n) async => (await httpApi.listItems(n)).items.length,
    };
    if (isH2 && !kIsWeb) {
      // dart:io HttpClient has no HTTP/2: the h2 listener only accepts ALPN h2, so on native
      // targets the h2 rows are Axiom, dio_http2_adapter and the platform stacks.
      out.removeWhere((k, _) => k != 'axiom');
      final h2 = newDioHttp2(baseUrl);
      if (h2 != null) {
        final api = rf.BenchApi(h2, baseUrl: baseUrl);
        out['dio_http2'] = (n) async => (await api.listItems(n)).items.length;
      }
    }
    final plat = platformHttpClient();
    if (plat != null) {
      final api = hc.HttpBenchApi(baseUrl, client: plat.client);
      out[plat.name] = (n) async => (await api.listItems(n)).items.length;
    }
    return out;
  }

  Map<String, Future<int> Function(int i)> getClients(AxiomSdk sdk) {
    final dioApi = rf.BenchApi(_dio(), baseUrl: baseUrl);
    final httpApi = hc.HttpBenchApi(baseUrl, client: _httpClient());
    final out = <String, Future<int> Function(int i)>{
      'axiom': (i) async => (await axFresh(sdk.bench.getItem(id: '${i % 50 + 1}'))).qty,
      'dio': (i) async => (await dioApi.getItem('${i % 50 + 1}')).qty,
      'http': (i) async => (await httpApi.getItem('${i % 50 + 1}')).qty,
    };
    if (isH2 && !kIsWeb) {
      // dart:io HttpClient has no HTTP/2: the h2 listener only accepts ALPN h2, so on native
      // targets the h2 rows are Axiom, dio_http2_adapter and the platform stacks.
      out.removeWhere((k, _) => k != 'axiom');
      final h2 = newDioHttp2(baseUrl);
      if (h2 != null) {
        final api = rf.BenchApi(h2, baseUrl: baseUrl);
        out['dio_http2'] = (i) async => (await api.getItem('${i % 50 + 1}')).qty;
      }
    }
    final plat = platformHttpClient();
    if (plat != null) {
      final api = hc.HttpBenchApi(baseUrl, client: plat.client);
      out[plat.name] = (i) async => (await api.getItem('${i % 50 + 1}')).qty;
    }
    return out;
  }

  String _proto(String client) {
    if (!isH2) return 'h1';
    if (kIsWeb ||
        client == 'dio_http2' ||
        client == 'cronet_http' ||
        client == 'cupertino_http' ||
        client == 'axiom') {
      // Browser fetch negotiates h2 by ALPN; the native Axiom runtime and platform stacks too.
      return 'h2';
    }
    return 'tls_h1';
  }

  // ---- (a) 20 parallel calls ----
  Future<void> parallel(AxiomSdk sdk) async {
    const width = 20, reps = 20, warm = 3;
    final cases = <String, Map<String, Future<int> Function(int i)>>{
      'parallel20_get_item': getClients(sdk),
      // n = 1000..1019: 20 distinct requests (identical Axiom queries in flight would be shared).
      'parallel20_list_1000': listClients(sdk).map((k, f) => MapEntry(k, (int i) => f(1000 + i % width))),
    };
    for (final c in cases.entries) {
      for (final client in c.value.entries) {
        await _guard('parallel', c.key, client.key, () async {
          final samples = <double>[];
          for (var r = 0; r < warm + reps; r++) {
            final sw = Stopwatch()..start();
            await Future.wait([for (var i = 0; i < width; i++) client.value(r * width + i)]);
            sw.stop();
            if (r >= warm) samples.add(_ms(sw));
          }
          emit({
            ...base('parallel'),
            'case': c.key,
            'client': client.key,
            'proto': _proto(client.key),
            'status': 'ok',
            'width': width,
            'method':
                '$width calls started together; wall time until all returned typed data; $warm warm-up rounds',
            ...stats(samples),
          });
        });
      }
    }
  }

  Future<void> _setOffline(bool on) async {
    // Control route on the plain HTTP/1.1 listener (shared state with the h2 listener).
    final ctl = baseUrl.startsWith('https')
        ? Uri.parse(baseUrl).replace(scheme: 'http', port: Uri.parse(baseUrl).port - 2)
        : Uri.parse(baseUrl);
    final r = await http.get(ctl.replace(path: '/_ctl/offline', queryParameters: {'on': on ? '1' : '0'}));
    if (r.statusCode != 200) throw StateError('offline control: ${r.statusCode}');
  }

  // ---- (b) cached repeat and first data with the network unreachable ----
  Future<void> offline(AxiomSdk sdk) async {
    const n = 1000, reps = 20;
    final dio = _dio()
      ..interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(
            store: MemCacheStore(),
            policy: CachePolicy.refreshForceCache,
            hitCacheOnNetworkFailure: true,
          ),
        ),
      );
    final dioApi = rf.BenchApi(dio, baseUrl: baseUrl);
    final httpApi = hc.HttpBenchApi(baseUrl, client: _httpClient());
    final clients = <String, Future<int> Function()>{
      'axiom': () async => (await axFresh(sdk.bench.cachedItems(n: n))).items.length,
      'dio_cache_interceptor': () async => (await dioApi.cachedItems(n)).items.length,
      'http': () async => (await httpApi.listItems(n)).items.length,
    };
    try {
      for (final c in clients.entries) {
        await _guard('offline', null, c.key, () async {
          await _setOffline(false);
          await c.value(); // fills the cache (Axiom cacheFirst; dio refreshForceCache stores)
          final cached = <double>[];
          for (var i = 0; i < reps; i++) {
            final sw = Stopwatch()..start();
            await c.value();
            sw.stop();
            cached.add(_ms(sw));
          }
          emit({
            ...base('offline'),
            'case': 'cached_repeat_list_$n',
            'client': c.key,
            'proto': _proto(c.key),
            'status': 'ok',
            'policy': c.key == 'axiom'
                ? 'contract cacheFirst ttl 10m'
                : c.key == 'http'
                ? 'no cache (network call)'
                : 'refreshForceCache (network first, cache stored)',
            ...stats(cached),
          });
          await _setOffline(true);
          final off = <double>[];
          Object? err;
          for (var i = 0; i < reps; i++) {
            final sw = Stopwatch()..start();
            try {
              final got = await c.value().timeout(const Duration(seconds: 10));
              sw.stop();
              if (got != n) throw StateError('got $got items');
              off.add(_ms(sw));
            } catch (e) {
              err = e;
              break;
            }
          }
          emit({
            ...base('offline'),
            'case': 'offline_first_data_list_$n',
            'client': c.key,
            'proto': _proto(c.key),
            'status': err == null ? 'ok' : 'no_data',
            'method': 'server drops every data connection without a response; time to typed data',
            if (err != null) 'note': '$err'.split('\n').first,
            if (off.isNotEmpty) ...stats(off),
          });
        });
      }
    } finally {
      await _setOffline(false);
    }
  }

  // ---- (c) main-isolate blocking during a 10k fetch + decode ----
  Future<Map<String, Object?>> _stalls(Future<void> Function() work) async {
    final sw = Stopwatch()..start();
    var last = 0, maxGap = 0, over16 = 0, sumOver16 = 0;
    final t = Timer.periodic(const Duration(milliseconds: 1), (_) {
      final now = sw.elapsedMicroseconds;
      final gap = now - last;
      last = now;
      if (gap > maxGap) maxGap = gap;
      if (gap > 16667) {
        over16++;
        sumOver16 += gap;
      }
    });
    await work();
    final now = sw.elapsedMicroseconds;
    t.cancel();
    final tail = now - last;
    if (tail > maxGap) maxGap = tail;
    return {
      'max_gap_ms': maxGap / 1000.0,
      'gaps_over_16ms': over16,
      'stall_ms_over_16': sumOver16 / 1000.0,
      'wall_ms': now / 1000.0,
    };
  }

  Future<void> jank(AxiomSdk sdk) async {
    const n = 10000, reps = 10;
    final clients = {
      'idle': (int _) async => await Future<void>.delayed(const Duration(milliseconds: 100)).then((_) => n),
      ...listClients(sdk),
    };
    for (final c in clients.entries) {
      await _guard('jank', 'list_$n', c.key, () async {
        await c.value(n); // warm-up
        final maxGaps = <double>[], walls = <double>[], stall = <double>[];
        var over = 0;
        for (var i = 0; i < reps; i++) {
          final s = await _stalls(() async {
            final got = await c.value(n);
            if (got != n) throw StateError('${c.key}: $got items');
          });
          maxGaps.add(s['max_gap_ms']! as double);
          walls.add(s['wall_ms']! as double);
          stall.add(s['stall_ms_over_16']! as double);
          over += s['gaps_over_16ms']! as int;
        }
        final st = stats(maxGaps);
        emit({
          ...base('jank'),
          'case': 'list_$n',
          'client': c.key,
          'proto': _proto(c.key),
          'status': 'ok',
          'method':
              '1 ms periodic timer on the UI isolate during fetch + decode to typed models; '
              'p50_ms/p95_ms/max_ms are over the per-call longest gap between ticks',
          ...st,
          'longest_stall_ms': st['max_ms'],
          'wall_p50_ms': stats(walls)['p50_ms'],
          'stall_over_16ms_p50_ms': stats(stall)['p50_ms'],
          'gaps_over_16ms_total': over,
        });
      });
    }
  }

  // ---- (d) time to first item, 10k list ----
  Future<void> ttfi(AxiomSdk sdk) async {
    const n = 10000, reps = 10;
    final httpC = _httpClient();
    final dio = _dio();
    final rows = <String, Future<void> Function()>{
      'http_ndjson': () async {
        final res = await httpC.send(http.Request('GET', Uri.parse('$baseUrl/items.ndjson?n=$n')));
        final line = await res.stream.transform(utf8.decoder).transform(const LineSplitter()).first;
        hc.Item.fromJson(jsonDecode(line) as Map<String, dynamic>);
      },
      'dio_ndjson': () async {
        final res = await dio.get<ResponseBody>(
          '/items.ndjson',
          queryParameters: {'n': n},
          options: Options(responseType: ResponseType.stream),
        );
        final line = await utf8.decoder
            .bind(res.data!.stream.map((b) => b.toList()))
            .transform(const LineSplitter())
            .first;
        rf.Item.fromJson(jsonDecode(line) as Map<String, dynamic>);
      },
    };
    for (final r in rows.entries) {
      await _guard('ttfi', 'list_$n', r.key, () async {
        await r.value();
        final samples = <double>[];
        for (var i = 0; i < reps; i++) {
          final sw = Stopwatch()..start();
          await r.value();
          sw.stop();
          samples.add(_ms(sw));
        }
        emit({
          ...base('ttfi'),
          'case': 'list_$n',
          'client': r.key,
          'proto': _proto(r.key),
          'status': 'ok',
          'method': 'NDJSON route, first line decoded to a typed item, rest of the stream abandoned',
          ...stats(samples),
        });
      });
    }
    emit({
      ...base('ttfi'),
      'case': 'list_$n',
      'client': 'axiom',
      'proto': _proto('axiom'),
      'status': 'not_available',
      'note':
          'the generated client has no streaming list call on this branch (runtime callStream exists, '
          'but no contract endpoint exposes the list as a stream); Axiom first item = full-list latency',
    });
  }

  // ---- extra clients: per-call latency (same method as bench.dart latency) ----
  Future<void> clients(AxiomSdk sdk) async {
    final lists = listClients(sdk);
    final gets = getClients(sdk);
    final cases = <String, Map<String, Future<int> Function(int)>>{
      'small_get_item': gets,
      'large_list_1000': lists.map((k, f) => MapEntry(k, (int _) => f(1000))),
      'large_list_10000': lists.map((k, f) => MapEntry(k, (int _) => f(10000))),
    };
    const warmup = 10;
    for (final c in cases.entries) {
      final perCase = c.key == 'large_list_10000' ? (calls ~/ 4).clamp(10, 1000) : calls;
      for (final client in c.value.entries) {
        await _guard('clients', c.key, client.key, () async {
          final samples = <double>[];
          for (var i = 0; i < warmup + perCase; i++) {
            final sw = Stopwatch()..start();
            await client.value(i);
            sw.stop();
            if (i >= warmup) samples.add(_ms(sw));
          }
          emit({
            ...base('clients'),
            'case': c.key,
            'client': client.key,
            'proto': _proto(client.key),
            'status': 'ok',
            'warmup': warmup,
            ...stats(samples),
          });
        });
      }
    }
  }
}
