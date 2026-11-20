// Runtime-parity checks owned by unit b (native binding). They use only the
// public AxiomRuntime API, so they also run against the web runtime.
import 'dart:async';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'ctx.dart';

// Fixture endpoint ids (see axiom_generated/axiom_sdk.dart).
const _epEverything = 1643923642;
const _epApiKeyHeader = 1256260924;

/// Namespace bound to the hanging server (`flutter/fixtures/tool/hang.py`,
/// `--dart-define=FIXTURE_HANG_URL=...`): requests stay in flight until
/// cancelled, on every platform. No in-app server (macOS App Sandbox) and no
/// blackhole address (Chrome refuses port 9 at once).
const _slowNs = 'b_slow';
bool _slowLoaded = false;

AxiomRuntime _rt(Ctx c) => c.sdk.runtime;

Future<void> _ensureSlow(Ctx c) async {
  requireHangUrl();
  if (_slowLoaded) return;
  final bytes = (await rootBundle.load('assets/axiom/fixture.axiom'))
      .buffer
      .asUint8List();
  final r = _rt(c).tryLoadContract(
    namespace: _slowNs,
    baseUrl: fixtureHangUrl,
    contractBytes: bytes,
  );
  expectThat(r.ok, 'slow namespace load: $r');
  _slowLoaded = true;
}

AxiomQuery<Object?> _everything(
  Ctx c, {
  String ns = 'fixture',
  Map<String, dynamic> args = const {},
  AxiomCallOptions? options,
}) => _rt(c).send<Object?>(
  namespace: ns,
  endpointId: _epEverything,
  method: 'GET',
  path: '/types/everything',
  args: args,
  decoder: (j) => j,
  options: options,
);

Future<AxiomState<T>> _settled<T>(Stream<AxiomState<T>> s) => s
    .firstWhere((x) => x.isSuccess || x.hasError)
    .timeout(const Duration(seconds: 10));

Future<int> _liveId(AxiomQuery q) async {
  for (var i = 0; i < 300; i++) {
    final id = q.requestId;
    if (id != null && id != 0) return id;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw CheckFailure('query never got a request id');
}

Future<void> _until(bool Function() cond, String what) async {
  for (var i = 0; i < 300; i++) {
    if (cond()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw CheckFailure('timed out waiting for $what');
}

final checksB = <CheckDef>[
  CheckDef('b.version_handshake', 'runtime', (c) async {
    final info = _rt(c).runtimeInfo;
    expectThat(info.isCompatible, 'incompatible runtime: $info');
    expectEq(info.dataAbiVersion, AxiomRuntimeInfo.expectedDataAbiVersion, 'data abi');
  }),
  CheckDef('b.init_result', 'runtime', (c) async {
    final rt = _rt(c);
    expectThat(rt.isInitialized, 'isInitialized after create()');
    final cfg = AxiomConfig(contracts: const {});
    final first = await rt.initialize(cfg);
    expectThat(first.ok, 'initialize: $first');
    final second = await rt.initialize(cfg);
    expectThat(second.alreadyInitialized, 'second initialize is idempotent');
    expectThat(rt.initResult != null, 'initResult set');
  }),
  CheckDef('b.contract_trust', 'runtime', (c) async {
    final bytes = (await rootBundle.load('assets/axiom/fixture.axiom'))
        .buffer
        .asUint8List();
    final rt = _rt(c);
    final unsigned = rt.tryLoadContract(
      namespace: 'b_unsigned',
      baseUrl: c.baseUrl,
      contractBytes: bytes,
    );
    expectEq(unsigned.trust, AxiomContractTrust.unsigned, 'unsigned trust');
    final locked = rt.tryLoadContract(
      namespace: 'b_locked',
      baseUrl: c.baseUrl,
      contractBytes: bytes,
      sha256: '0' * 64,
    );
    expectThat(!locked.ok && locked.trust == null, 'bad lock must fail: $locked');
  }),
  CheckDef('b.cancel_explicit', 'runtime', (c) async {
    await _ensureSlow(c);
    final q = _everything(c, ns: _slowNs, args: {'b': 'cancel'});
    final states = <AxiomState<Object?>>[];
    final sub = q.stream.listen(states.add);
    try {
      await _liveId(q);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expectThat(q.cancel(), 'cancel() of a live request returns true');
      await _until(() => states.any((s) => s.hasError), 'Cancelled error');
      final e = states.firstWhere((s) => s.hasError).error!;
      expectThat(e.isCancelled, 'error is Cancelled: $e');
    } finally {
      await sub.cancel();
    }
  }),
  CheckDef('b.cancel_last_listener', 'runtime', (c) async {
    await _ensureSlow(c);
    final rt = _rt(c);
    final q = _everything(c, ns: _slowNs, args: {'b': 'shared'});
    final a = q.stream.listen((_) {});
    final b = q.stream.listen((_) {});
    final id = await _liveId(q);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await a.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expectThat(rt.cancel(id), 'request survives while another listener exists');
    await b.cancel();

    final q2 = _everything(c, ns: _slowNs, args: {'b': 'last'});
    final only = q2.stream.listen((_) {});
    final id2 = await _liveId(q2);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await only.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expectThat(!rt.cancel(id2), 'last unsubscribe cancelled the request');
  }),
  CheckDef('b.call_options', 'runtime', (c) async {
    final headers = await _settled(
      _rt(c)
          .send<Object?>(
            namespace: 'fixture',
            endpointId: _epApiKeyHeader,
            method: 'GET',
            path: '/auth/api-key-header',
            headers: {'x-api-key': 'nope'},
            args: {'x-api-key': 'nope', 'b': 'headers'},
            decoder: (j) => j,
            options: const AxiomCallOptions(
              headers: {'x-api-key': fixtureApiKey},
              cacheMode: AxiomCacheMode.refresh,
            ),
          )
          .stream,
    );
    expectThat(headers.isSuccess, 'options.headers override: ${headers.error}');
    await _ensureSlow(c); // skips the timeout half without FIXTURE_HANG_URL
    final timedOut = await _settled(
      _everything(
        c,
        ns: _slowNs,
        args: {'b': 'timeout'},
        options: const AxiomCallOptions(timeout: Duration(milliseconds: 300)),
      ).stream,
    );
    expectThat(
      timedOut.hasError && timedOut.error!.code is NetworkTimeout,
      'timeout -> NetworkTimeout, got ${timedOut.error}',
    );
  }),
  CheckDef('b.error_listener_typed_failure', 'runtime', (c) async {
    final events = <AxiomErrorEvent>[];
    final sub = _rt(c).onError.listen(events.add);
    try {
      final s = await _settled(
        _rt(c)
            .send<Object?>(
              namespace: 'fixture',
              endpointId: _epApiKeyHeader,
              method: 'GET',
              path: '/auth/api-key-header',
              headers: {'x-api-key': 'nope'},
              args: {'x-api-key': 'nope', 'b': 1},
              decoder: (j) => j,
            )
            .stream,
      );
      expectThat(s.hasError, 'expected an error');
      expectEq(s.error!.failureCode, 'unauthorized', 'failureCode');
      await _until(
        () => events.any((e) => e.endpointId == _epApiKeyHeader),
        'onError event',
      );
      expectThat(!events.any((e) => e.error.isCancelled), 'no Cancelled on onError');
    } finally {
      await sub.cancel();
    }
  }),
  CheckDef('b.cache_control', 'runtime', (c) async {
    final rt = _rt(c);
    rt.setQueryData<Object?>(
      namespace: 'fixture',
      endpointId: _epEverything,
      args: {'b': 'seed'},
      data: {'id': 'seeded'},
    );
    expectEq(
      (rt.getCachedQueryData<Object?>(
        namespace: 'fixture',
        endpointId: _epEverything,
        args: {'b': 'seed'},
      ) as Map?)?['id'],
      'seeded',
      'seeded value',
    );
    final q = _everything(c, args: {'b': 'inv'});
    var count = 0;
    final sub = q.stream.listen((_) => count++);
    try {
      await q.stream.firstWhere((s) => s.isSuccess && !s.isFetching);
      final before = count;
      rt.invalidate(namespace: 'fixture', endpointId: _epEverything);
      await q.stream.firstWhere((s) => s.isSuccess && !s.isFetching);
      expectThat(count > before, 'invalidate refetched');
      await rt.clearCache('fixture');
      await q.stream.firstWhere((s) => s.isSuccess && !s.isFetching);
      await rt.purgeCache('fixture');
      expectThat(
        rt.getCachedQueryData<Object?>(
              namespace: 'fixture',
              endpointId: _epEverything,
              args: {'b': 'seed'},
            ) ==
            null,
        'purge dropped the seeded value',
      );
    } finally {
      await sub.cancel();
    }
  }),
  CheckDef('b.namespace_global_token', 'auth', (c) async {
    final rt = _rt(c);
    // Must not throw; end-to-end injection needs contract auth methods
    // (the fixture declares none client-side).
    try {
      rt.setNamespaceAuthToken(namespace: 'fixture', token: fixtureBearerToken);
      rt.setGlobalAuthToken(fixtureBearerToken);
      rt.clearNamespaceAuthToken(namespace: 'fixture');
      rt.clearGlobalAuthToken();
      rt.setAuthProvider((ns, method) async => null);
      rt.setAuthProvider(null);
    } finally {
      resetAuthState(c);
    }
  }),
  CheckDef('b.extensions', 'runtime', (c) async {
    if (kIsWeb) skip('extensions are native only');
    final rt = _rt(c);
    final audit = await rt.extensionAudit();
    expectThat(audit != null, 'audit snapshot');
    rt.extensionLifecycle(AxiomLifecycleEvent.foreground);
    try {
      await rt.invokeExtension(const AxiomExtensionCall(
        extension: 'missing',
        export: 'run',
        interfaceSha256: 'x',
        abiSymbol: 'y',
      ));
      throw CheckFailure('invoke of a missing extension must throw');
    } on AxiomExtensionException {
      // expected
    }
  }),
  CheckDef('b.reset_session', 'runtime', (c) async {
    await _ensureSlow(c);
    final rt = _rt(c);
    final q = _everything(c, ns: _slowNs, args: {'b': 'reset'});
    final states = <AxiomState<Object?>>[];
    final sub = q.stream.listen(states.add);
    await _liveId(q);
    await rt.resetSession();
    await _until(
      () => states.any((s) => s.hasError && s.error!.isCancelled),
      'Cancelled after resetSession',
    );
    await sub.cancel();
    final after = await _settled(_everything(c, args: {'b': 'after-reset'}).stream);
    expectThat(after.isSuccess, 'contracts stay loaded: ${after.error}');
  }),
  // Keep last: tears the runtime down and starts it again.
  CheckDef('b.shutdown_restart', 'runtime', (c) async {
    final rt = _rt(c);
    await rt.shutdown();
    expectThat(!rt.isInitialized, 'not initialized after shutdown');
    await rt.shutdown();
    final r = await rt.initialize(AxiomConfig(
      contracts: {
        'fixture': AxiomContractConfig(
          baseUrl: c.baseUrl,
          assetPath: 'assets/axiom/fixture.axiom',
        ),
      },
    ));
    expectThat(r.ok && !r.alreadyInitialized, 'initialize after shutdown: $r');
    _slowLoaded = false;
    final s = await _settled(_everything(c, args: {'b': 'after-shutdown'}).stream);
    expectThat(s.isSuccess, 'call after restart: ${s.error}');
  }),
];
