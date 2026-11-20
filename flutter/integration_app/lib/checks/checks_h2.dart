// Checks for unit h2 (web findings of the review: F9, F8, F15, F7); names
// start `h2.`. They run on every platform; native failures belong to the
// native owner (runtime_io.dart).
import 'dart:async';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'ctx.dart';

const _echoId = 1421147111;

/// Base URL of a server that answers every request (and CORS preflight) with
/// an empty 204, e.g. the one run_web.sh starts with H2_EMPTY_PORT.
/// Empty: h2.empty_success_reaches_listeners is skipped.
const String _emptyBase = String.fromEnvironment('H2_EMPTY_BASE_URL');

Future<AxiomState<T>> _settled<T>(Stream<AxiomState<T>> s) => s
    .firstWhere((x) => x.isSuccess || x.hasError)
    .timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw CheckFailure('no data or error within 10 s'),
    );

String _nonce() => DateTime.now().microsecondsSinceEpoch.toString();


// Awaits a query stream directly inside async functions, the way app code
// does (k finding: dart2js release crashed with "Null check operator used on
// a null value" in _StreamIterator/_awaitOnObject). Each helper is an async
// function whose code after the await must run.
Future<T> _awaitFirstWhere<T>(AxiomQuery<T> q) async {
  final s = await q.stream.firstWhere((s) => s.hasData || s.hasError);
  if (s.hasError) throw CheckFailure('error: ${s.error}');
  return s.data as T;
}

Future<T> _awaitFor<T>(AxiomQuery<T> q) async {
  await for (final s in q.stream) {
    if (s.hasError) throw CheckFailure('error: ${s.error}');
    if (s.hasData) return s.data as T;
  }
  throw CheckFailure('stream closed without data');
}

Future<T> _awaitUnwrap<T>(AxiomQuery<T> q) async {
  final v = await q.stream.unwrap();
  return v;
}

Future<void> _awaitStyles(Ctx c, String tag) async {
  final styles = <String, Future<Object?> Function(AxiomQuery<Object?>)>{
    'firstWhere': _awaitFirstWhere,
    'await for': _awaitFor,
    'unwrap': _awaitUnwrap,
  };
  for (final e in styles.entries) {
    final n = 'h2-$tag-${e.key.replaceAll(' ', '')}-${_nonce()}';
    // Fresh args (network), then the same args again (second fetch of the
    // same query), then a cache-first endpoint twice.
    for (final q in <AxiomQuery<Object?> Function()>[
      () => c.api.echo(path: n, q: 'x', limit: 1),
      () => c.api.echo(path: n, q: 'x', limit: 1),
      () => c.api.cacheCacheFirst(nonce: n),
      () => c.api.cacheCacheFirst(nonce: n),
      // Mutations are not routed through the query manager (k's crash).
      () => c.api.createItem(name: n, qty: 1),
    ]) {
      var after = false;
      final v = await e.value(q()).then((v) {
        return v;
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw CheckFailure(
          '${e.key}: the async function never resumed after the await',
        ),
      );
      after = true;
      expectThat(after && v != null, '${e.key}: no value');
    }
  }
}

final checksH2 = <CheckDef>[
  // Lead/k: awaiting a query stream inside an async function (firstWhere,
  // await for, unwrap()) must resume after the await, in release builds too.
  CheckDef('h2.await_query_stream_in_async', 'runtime', (c) async {
    await _awaitStyles(c, 'a');
  }),
  // The same for the raw runtime stream (public callStream): await for and
  // await firstWhere inside an async function must resume.
  CheckDef('h2.await_call_stream_in_async', 'runtime', (c) async {
    AxiomStreamResponse call() => c.sdk.runtime.callStream(
      namespace: 'fixture',
      endpointId: _echoId,
      method: 'GET',
      path: '/echo/h2raw',
      queryParams: {'q': _nonce(), 'limit': '1'},
      requestBytes: Uint8List(0),
    );
    Future<bool> viaAwaitFor() async {
      await for (final s in call().stream) {
        if (s.isSuccess || s.hasError) return s.isSuccess;
      }
      return false;
    }

    Future<bool> viaFirstWhere() async {
      final s = await call().stream.firstWhere((s) => s.isSuccess || s.hasError);
      return s.isSuccess;
    }

    for (final f in [viaAwaitFor, viaFirstWhere]) {
      final ok = await f().timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw CheckFailure('async function never resumed after the await'),
      );
      expectThat(ok, 'raw call did not succeed');
    }
  }),
  // F9: an error raised synchronously while callStream dispatches (wasm throw,
  // non-zero status, runtime not loaded) must reach the first listener as an
  // AxiomState error, and onError, instead of an empty, already-closed stream.
  CheckDef('h2.sync_dispatch_error_delivered', 'runtime', (c) async {
    if (!kIsWeb) skip('web only (uses the web dispatch fault hook)');
    final rt = c.sdk.runtime;
    final events = <AxiomErrorEvent>[];
    final sub = rt.onError.listen(events.add);
    try {
      (rt as dynamic).debugFailNextDispatch = true;
      final r = rt.callStream(
        namespace: 'fixture',
        endpointId: _echoId,
        method: 'GET',
        path: '/echo/h2',
        queryParams: {'q': 'h2', 'limit': '1'},
        requestBytes: Uint8List(0),
      );
      final states = await r.stream.toList().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw CheckFailure('stream never closed'),
      );
      expectThat(
        states.any((s) => s.hasError),
        'expected an error state, got ${states.map((s) => s.status).toList()}',
      );
      await Future<void>.delayed(Duration.zero);
      expectThat(
        events.any((e) => e.requestId == r.requestId),
        'onError did not fire for request ${r.requestId} (${events.length} events)',
      );
    } finally {
      try {
        (rt as dynamic).debugFailNextDispatch = null;
      } catch (_) {}
      await sub.cancel();
    }
  }),
  // F7: two queries with the same args but different per-call headers must
  // not share the first call's request. The second call supplies the correct
  // x-api-key through AxiomCallOptions.headers (which override the declared
  // header), so it must succeed although the first one failed with 401.
  CheckDef('h2.query_key_includes_call_headers', 'cache', (c) async {
    final bad = 'nope-h2-${_nonce()}';
    final e = await failure(c.api.authApiKeyHeader(xApiKey: bad));
    expectEq(httpStatusOf(e), 401, 'first call status (error: $e)');
    final s = await settle(
      c.api.authApiKeyHeader(
        xApiKey: bad,
        options: const AxiomCallOptions(headers: {'x-api-key': fixtureApiKey}),
      ),
    );
    expectThat(
      s.isSuccess && s.data?.ok == true,
      'second call (other headers) reused the first request: ${s.error ?? s.data}',
    );
  }),
  // F7: a per-call timeout is part of the key too (no reuse across timeouts).
  CheckDef('h2.query_key_includes_timeout', 'cache', (c) async {
    final n = 'h2-${_nonce()}';
    final a = c.api.echo(path: n, q: 'x', limit: 1);
    final b = c.api.echo(
      path: n,
      q: 'x',
      limit: 1,
      options: const AxiomCallOptions(timeout: Duration(seconds: 7)),
    );
    expectThat(a.key != b.key, 'same key with and without a timeout: ${a.key}');
    final s = await settle(b);
    expectThat(s.isSuccess, 'call with timeout failed: ${s.error}');
  }),
  // F8 (web): an empty 204 response must settle for listeners (never an
  // endless loading state or an empty closed stream). runtime_web.dart emits
  // success for an empty networkSuccess; with this fixture every endpoint has
  // a JSON response type (acore derives it from the action output, there is
  // no void endpoint), so the runtime rejects the empty body with a
  // validation error first. Both outcomes settle; a hang or an empty stream
  // fails.
  CheckDef('h2.empty_response_settles', 'unary', (c) async {
    if (_emptyBase.isEmpty) skip('set H2_EMPTY_BASE_URL to a 204 server');
    final rt = c.sdk.runtime;
    final bytes = (await rootBundle.load(
      'assets/axiom/fixture.axiom',
    )).buffer.asUint8List();
    final r = rt.tryLoadContract(
      namespace: 'h2_empty',
      baseUrl: _emptyBase,
      contractBytes: bytes,
    );
    if (!r.ok) throw CheckFailure('loading h2_empty failed: $r');
    final raw = rt.callStream(
      namespace: 'h2_empty',
      endpointId: _echoId,
      method: 'GET',
      path: '/echo/empty',
      queryParams: {'q': _nonce(), 'limit': '1'},
      requestBytes: Uint8List(0),
    );
    final states = await raw.stream.toList().timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw CheckFailure('raw stream never closed'),
    );
    expectThat(
      states.any((s) => s.isSuccess || s.hasError),
      'raw: stream closed without a terminal state: ${states.map((s) => s.status).toList()}',
    );
    final q = rt.send<Object?>(
      namespace: 'h2_empty',
      endpointId: _echoId,
      method: 'GET',
      path: '/echo/empty2',
      queryParams: {'q': _nonce(), 'limit': '1'},
      args: {'h2': _nonce()},
      decoder: (j) => j,
    );
    final s = await _settled(q.stream);
    expectThat(
      (s.isSuccess && s.data == null) || s.hasError,
      'send: ${s.status} ${s.error} ${s.data}',
    );
  }),
  // F15: a failed initialize() is not cached: a retry runs again and can
  // succeed. Shuts the runtime down and restores the fixture namespace.
  CheckDef('h2.failed_initialize_is_retryable', 'runtime', (c) async {
    final rt = c.sdk.runtime;
    var attempts = 0;
    Future<Uint8List> loader(String path) async {
      if (path == 'h2/flaky.axiom') {
        attempts++;
        if (attempts == 1) throw StateError('h2: offline (simulated)');
        path = 'assets/axiom/fixture.axiom';
      }
      return (await rootBundle.load(path)).buffer.asUint8List();
    }

    final config = AxiomConfig(
      contracts: {
        'fixture': AxiomContractConfig(
          baseUrl: c.baseUrl,
          assetPath: 'assets/axiom/fixture.axiom',
        ),
        'h2_flaky': AxiomContractConfig(
          baseUrl: c.baseUrl,
          assetPath: 'h2/flaky.axiom',
        ),
      },
    );
    await rt.shutdown();
    final first = await rt.initialize(config, assetLoader: loader);
    expectThat(!first.ok, 'first initialize should fail: $first');
    final second = await rt.initialize(config, assetLoader: loader);
    expectThat(
      second.ok && !second.alreadyInitialized,
      'retry returned ${second.ok ? 'ok' : 'failed'} alreadyInitialized='
      '${second.alreadyInitialized} (loader attempts $attempts): ${second.error}',
    );
    final s = await settle(c.api.echo(path: 'h2-${_nonce()}', q: 'x', limit: 1));
    expectThat(s.isSuccess, 'call after retry: ${s.error}');
  }),
];
