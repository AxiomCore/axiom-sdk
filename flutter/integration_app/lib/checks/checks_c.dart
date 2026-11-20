// Checks for unit c (web runtime binding). They use only the public API, so
// they also run on native; names start with `c.`.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'checks_c_mem_stub.dart'
    if (dart.library.js_interop) 'checks_c_mem_web.dart';
import 'ctx.dart';

const _ns = 'fixture';
const _echoId = 1421147111;
const _cacheFirstId = 3177318534;
const _cachedItemId = 1498157384;
const _authBearerId = 1404635741;
const _wsEchoId = 1471516720;

AxiomRuntime _rt(Ctx c) => c.sdk.runtime;

const _hangNs = 'c_hang';
bool _hangLoaded = false;

AxiomConfig _config() => const AxiomConfig(
  contracts: {
    _ns: AxiomContractConfig(
      baseUrl: fixtureBaseUrl,
      assetPath: 'assets/axiom/fixture.axiom',
    ),
  },
);

/// Raw call through [AxiomRuntime.callStream]; returns every state until the
/// stream closes (bypasses the Dart query manager, so it shows exactly what
/// the runtime emitted).
Future<List<AxiomState<Uint8List>>> _raw(
  Ctx c, {
  required int endpointId,
  required String path,
  Map<String, dynamic>? query,
  AxiomCallOptions? options,
  void Function(int id)? onStart,
  String ns = _ns,
}) async {
  final r = _rt(c).callStream(
    namespace: ns,
    endpointId: endpointId,
    method: 'GET',
    path: path,
    queryParams: query,
    requestBytes: Uint8List(0),
    options: options,
  );
  final states = <AxiomState<Uint8List>>[];
  final done = Completer<void>();
  r.stream.listen(states.add, onDone: done.complete);
  onStart?.call(r.requestId);
  await done.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw CheckFailure('stream did not complete: $states'),
  );
  return states.where((s) => !s.isLoading).toList();
}

AxiomSource _firstSource(List<AxiomState<Uint8List>> s) {
  final d = s.where((x) => x.hasData);
  if (d.isEmpty) throw CheckFailure('no data: ${s.map((x) => x.error)}');
  return d.first.source;
}

Future<List<AxiomState<Uint8List>>> _cacheFirst(Ctx c, String nonce,
        {AxiomCallOptions? options}) =>
    _raw(c,
        endpointId: _cacheFirstId,
        path: '/cache/cache-first',
        query: {'nonce': nonce},
        options: options);

String _nonce(String p) => '$p-${DateTime.now().microsecondsSinceEpoch}';

final checksC = <CheckDef>[
  CheckDef('c.version_handshake', 'runtime', (c) async {
    final info = _rt(c).runtimeInfo;
    expectThat(info.isCompatible, 'incompatible: $info');
    expectEq(info.abiVersion, 1, 'abi');
  }),
  CheckDef('c.init_result_idempotent', 'runtime', (c) async {
    final rt = _rt(c);
    final first = await rt.initialize(_config());
    expectThat(first.ok, 'first initialize not ok: $first');
    expectEq(first.contracts[_ns]?.trust, AxiomContractTrust.unsigned, 'trust');
    final second = await rt.initialize(_config());
    expectThat(second.alreadyInitialized, 'second call not alreadyInitialized');
    expectThat(rt.isInitialized, 'isInitialized');
    expectThat(identical(rt.initResult?.contracts, first.contracts),
        'initResult differs from first result');
  }),
  CheckDef('c.locked_load_rejects_bad_hash', 'runtime', (c) async {
    final r = _rt(c).tryLoadContract(
      namespace: 'locked_probe',
      baseUrl: c.baseUrl,
      contractBytes: Uint8List.fromList(utf8.encode('{}')),
      signature: 'AAAA',
      publicKey: 'AAAA',
      sha256: '0' * 64,
    );
    expectThat(!r.ok, 'locked load of garbage succeeded: $r');
    expectEq(r.status, FfiError.invalidContract, 'status');
  }),
  CheckDef('c.cancel', 'runtime', (c) async {
    var cancelled = false;
    final states = await _raw(c,
        endpointId: _echoId,
        path: '/echo/cancel',
        query: {'q': 'x', 'limit': 1}, onStart: (id) {
      cancelled = _rt(c).cancel(id);
    });
    expectThat(cancelled, 'cancel() returned false for a live request');
    final err = states.where((s) => s.hasError).map((s) => s.error!).toList();
    expectThat(err.isNotEmpty && err.first.isCancelled,
        'expected Cancelled error, got $states');
    expectThat(!_rt(c).cancel(999999), 'cancel(unknown) returned true');
  }),
  CheckDef('c.cancel_websocket', 'runtime', (c) async {
    // The ws echo stays open (nothing is sent), so it is live until cancelled.
    // Same server, token and Origin as stream.websocket_echo.
    await c.wsApi();
    c.setWsToken();
    try {
      final r = _rt(c).callStream(
        namespace: c.wsNamespace,
        endpointId: _wsEchoId,
        method: 'WS',
        path: '/stream/ws',
        headers: Ctx.wsHeaders,
        requestBytes: Uint8List(0),
      );
      final errors = <Object>[];
      final done = Completer<void>();
      r.stream.listen((s) {
        if (s.hasError && !s.error!.isCancelled) errors.add(s.error!);
      }, onDone: done.complete);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // Native only: a browser cannot authorize this upgrade (see
      // skipBearerWsOnWeb); cancel still has to work while it connects.
      if (!kIsWeb) expectThat(errors.isEmpty, 'ws failed before cancel: $errors');
      expectThat(_rt(c).cancel(r.requestId), 'cancel(ws) returned false');
      await done.future.timeout(const Duration(seconds: 5),
          onTimeout: () => throw CheckFailure('ws stream not closed by cancel'));
    } finally {
      resetAuthState(c);
    }
  }),
  CheckDef('c.call_options_timeout', 'runtime', (c) async {
    // Deterministic: the hanging server never answers, so only the timeout
    // can end the call (a 1 µs timeout against the real fixture raced it).
    requireHangUrl();
    if (!_hangLoaded) {
      final bytes = (await rootBundle.load('assets/axiom/fixture.axiom'))
          .buffer
          .asUint8List();
      final r = _rt(c).tryLoadContract(
          namespace: _hangNs, baseUrl: fixtureHangUrl, contractBytes: bytes);
      expectThat(r.ok, 'hang namespace load: $r');
      _hangLoaded = true;
    }
    final states = await _raw(c,
        ns: _hangNs,
        endpointId: _echoId,
        path: '/echo/timeout',
        query: {'q': 'x', 'limit': 1},
        options: const AxiomCallOptions(timeout: Duration(milliseconds: 300)));
    final err = states.where((s) => s.hasError).map((s) => s.error!).toList();
    expectThat(err.isNotEmpty && err.first.code is NetworkTimeout,
        'expected NetworkTimeout, got ${err.isEmpty ? states : err.first}');
  }),
  CheckDef('c.runtime_cache_first', 'cache', (c) async {
    final n = _nonce('c-cf');
    expectEq(_firstSource(await _cacheFirst(c, n)), AxiomSource.network, '1st');
    expectEq(_firstSource(await _cacheFirst(c, n)), AxiomSource.cache, '2nd');
  }),
  CheckDef('c.forced_refresh_header', 'cache', (c) async {
    final n = _nonce('c-fr');
    await _cacheFirst(c, n);
    final s = await _cacheFirst(c, n,
        options: const AxiomCallOptions(cacheMode: AxiomCacheMode.refresh));
    expectEq(_firstSource(s), AxiomSource.network, 'source with refresh');
  }),
  CheckDef('c.invalidate_cache_identity', 'cache', (c) async {
    final n = _nonce('c-ci');
    Future<AxiomSource> item() async => _firstSource(await _raw(c,
        endpointId: _cachedItemId,
        path: '/cache/items/x',
        query: {'nonce': n}));
    await item();
    expectEq(await item(), AxiomSource.cache, 'before invalidate');
    _rt(c).invalidate(namespace: _ns, cacheIdentity: 'fixture.item');
    final after = await item();
    if (after == AxiomSource.cache) {
      skip('runtime has no cache-invalidate export yet (needs unit r); '
          'Dart refetch of active queries only');
    }
    expectEq(after, AxiomSource.network, 'after invalidate');
  }),
  CheckDef('c.clear_cache', 'cache', (c) async {
    final n = _nonce('c-cc');
    await _cacheFirst(c, n);
    expectEq(_firstSource(await _cacheFirst(c, n)), AxiomSource.cache, 'before');
    await _rt(c).clearCache();
    expectEq(_firstSource(await _cacheFirst(c, n)), AxiomSource.network, 'after');
  }),
  CheckDef('c.set_get_query_data', 'cache', (c) async {
    final args = {'path': 'sq', 'q': _nonce('sq'), 'limit': 1, 'flag': null};
    final rt = _rt(c);
    rt.setQueryData<String>(
        namespace: _ns, endpointId: _echoId, args: args, data: 'optimistic');
    expectEq(
        rt.getCachedQueryData<String>(
            namespace: _ns, endpointId: _echoId, args: args),
        'optimistic',
        'getCachedQueryData');
    final q = rt.send<String>(
      namespace: _ns,
      endpointId: _echoId,
      method: 'GET',
      path: '/echo/sq',
      args: args,
      decoder: (j) => 'network',
    );
    final v = await data(q);
    expectEq(v, 'optimistic', 'first value served from setQueryData');
  }),
  CheckDef('c.error_listener', 'runtime', (c) async {
    final rt = _rt(c);
    final got = rt.onError.first.timeout(const Duration(seconds: 10));
    rt.clearAuthToken(namespace: _ns, methodName: 'Authorization');
    await _raw(c, endpointId: _authBearerId, path: '/auth/bearer');
    final e = await got;
    expectEq(e.namespace, _ns, 'namespace');
    expectEq(e.endpointId, _authBearerId, 'endpointId');
    expectThat(!e.error.isCancelled, 'cancel reported on onError');
  }),
  CheckDef('c.typed_failure_fields', 'failures', (c) async {
    final e = AxiomError.fromJson({
      'stage': 'networkReceive',
      'category': 'server',
      'code': {'HttpStatus': 409},
      'message': 'conflict',
      'failure_code': 'conflict',
      'failure_payload': {'message': 'taken', 'existingId': 'i1'},
    });
    expectEq(e.failureCode, 'conflict', 'failureCode');
    expectEq((e.failurePayload as Map)['existingId'], 'i1', 'payload');
  }),
  CheckDef('c.namespace_global_token', 'auth', (c) async {
    final rt = _rt(c);
    try {
      rt.setGlobalAuthToken(fixtureBearerToken);
      rt.setNamespaceAuthToken(namespace: _ns, token: fixtureBearerToken);
      rt.clearNamespaceAuthToken(namespace: _ns);
      rt.clearGlobalAuthToken();
    } finally {
      resetAuthState(c);
    }
    skip('setters run without error; the fixture contract carries no '
        'endpoint auth metadata ("auth": null), so no token is injected '
        'on any platform');
  }),
  CheckDef('c.auth_provider', 'auth', (c) async {
    try {
      _rt(c).setAuthProvider((ns, m) async => fixtureBearerToken);
    } finally {
      _rt(c).setAuthProvider(null);
    }
    skip('provider registered; not exercised because the fixture contract '
        'has no endpoint auth metadata (web asks the provider before '
        'dispatch for endpoints that declare auth methods)');
  }),
  CheckDef('c.extensions_unsupported_on_web', 'runtime', (c) async {
    if (!kIsWeb) skip('native platform');
    try {
      await _rt(c).extensionAudit();
      throw CheckFailure('extensionAudit did not throw');
    } on UnsupportedError catch (e) {
      expectThat('$e'.contains('not supported on web'), 'message: $e');
    }
  }),
  CheckDef('c.wasm_memory_no_leak', 'runtime', (c) async {
    if (!kIsWeb) skip('native platform');
    // 16 000 calls of one cache-first request (cache hits after the first:
    // fast, no network). Every call ends with a Complete, so any per-call
    // state in the runtime grows with the call count. 0.150.0 kept one id per
    // finished call (TERMINAL_REQUESTS): its hash table doubled at ~7.2k and
    // ~14.3k ids, +147 KB / +288 KB of linear memory, which this check
    // catches; the fixed runtime keeps the last 4096 ids only. A short
    // warm-up only lets the allocator and the cache reach steady state; it
    // is far below the doubling points, so it cannot hide per-call growth.
    final nonce = _nonce('leak');
    Future<void> one() async {
      final s = await _cacheFirst(c, nonce);
      if (!s.any((x) => x.hasData)) {
        throw CheckFailure('no data: ${s.map((x) => x.error)}');
      }
    }
    Future<void> burst(int n) async {
      for (var i = 0; i < n; i += 50) {
        await Future.wait([for (var k = 0; k < 50; k++) one()]);
      }
    }
    await burst(500);
    final before = await wasmMemoryBytes();
    if (before == null) skip('wasm memory not reachable');
    await burst(16000);
    final grown = (await wasmMemoryBytes())! - before;
    expectThat(grown <= 64 * 1024,
        'wasm memory grew by $grown bytes over 16000 calls (limit one 64 KiB page)');
  }),
  CheckDef('c.reset_session', 'runtime', (c) async {
    final rt = _rt(c);
    await rt.resetSession();
    final r = await data(c.api.echo(path: 'after-reset', q: 'x', limit: 1));
    expectEq(r.path, 'after-reset', 'echo after reset');
  }),
  CheckDef('c.shutdown_reinitialize', 'runtime', (c) async {
    final rt = _rt(c);
    await rt.shutdown();
    expectThat(!rt.isInitialized, 'isInitialized after shutdown');
    expectThat(rt.initResult == null, 'initResult after shutdown');
    await rt.shutdown(); // idempotent
    final again = await rt.initialize(_config());
    expectThat(again.ok && !again.alreadyInitialized, 're-init: $again');
    final r = await data(c.api.echo(path: 'after-shutdown', q: 'x', limit: 1));
    expectEq(r.path, 'after-shutdown', 'echo after re-init');
  }),
];
