// Native (dart:ffi) binding tests against a real host runtime library and the
// fixture backend. Run (see test/native/README.md):
//
//   AXIOM_RUNTIME_LIB=/path/libaxiom_runtime.so \
//   AXIOM_FIXTURE_CONTRACT=/path/backend.axiom \
//   AXIOM_FIXTURE_URL=http://127.0.0.1:8791 \
//   flutter test test/native/native_runtime_test.dart
//
// Skipped when AXIOM_RUNTIME_LIB is not set. The runtime is a process-wide
// singleton, so the tests run in order and share state.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_flutter/src/internal/contract_metadata.dart';
import 'package:axiom_flutter/src/query_manager.dart';
import 'package:flutter_test/flutter_test.dart';

final _lib = Platform.environment['AXIOM_RUNTIME_LIB'];
final _contractPath =
    Platform.environment['AXIOM_FIXTURE_CONTRACT'] ??
    '../integration_app/assets/axiom/fixture.axiom';
final _baseUrl =
    Platform.environment['AXIOM_FIXTURE_URL'] ?? 'http://127.0.0.1:8791';

const fixtureBearerToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2ZpeHR1cmUuYXhpb21jb3JlLmxvY2FsIiwiYXVkIjoiYXhpb20tZml4dHVyZSIsInN1YiI6ImZpeHR1cmUtdXNlciIsImV4cCI6NDEwMjQ0NDgwMCwiaWF0IjoxNzYzNjQwMDAwfQ.jwRiGU7TnZJe5u9JMFc25Crv5r6OscJkitUjMXAEwyU';

// Endpoint ids of the fixture contract (from the generated SDK).
const epEverything = 1643923642;
const epEcho = 1421147111;
const epCacheFirst = 3177318534;
const epNetworkOnly = 837292962;
const epAuthBearer = 1404635741;
const epClaim = 3649530469;

/// Accepts TCP connections and never answers: requests stay in flight.
late ServerSocket _blackhole;
final _held = <Socket>[];

Future<Uint8List> _fileLoader(String path) async =>
    File(path == 'fixture' ? _contractPath : path).readAsBytes();

AxiomConfig _config() => AxiomConfig(
  contracts: {
    'fixture': AxiomContractConfig(baseUrl: _baseUrl, assetPath: 'fixture'),
    'slow': AxiomContractConfig(
      baseUrl: 'http://127.0.0.1:${_blackhole.port}',
      assetPath: 'fixture',
    ),
  },
);

Future<AxiomState<T>> settle<T>(
  Stream<AxiomState<T>> s, {
  Duration timeout = const Duration(seconds: 15),
}) => s.firstWhere((x) => x.isSuccess || x.hasError).timeout(timeout);

AxiomQuery<Object?> everything(AxiomRuntime rt, {String ns = 'fixture', Map<String, dynamic> args = const {}, AxiomCallOptions? options}) =>
    rt.send<Object?>(
      namespace: ns,
      endpointId: epEverything,
      method: 'GET',
      path: '/types/everything',
      args: args,
      decoder: (j) => j,
      options: options,
    );

AxiomQuery<Object?> nonce(
  AxiomRuntime rt,
  int ep,
  String path,
  String value, {
  Map<String, dynamic>? args,
  AxiomCallOptions? options,
}) => rt.send<Object?>(
  namespace: 'fixture',
  endpointId: ep,
  method: 'GET',
  path: path,
  headers: {'x-fixture-nonce': value},
  args: args ?? {'nonce': value},
  decoder: (j) => j,
  options: options,
);

/// Waits until the query has a live request id.
Future<int> liveId(AxiomQuery q) async {
  for (var i = 0; i < 200; i++) {
    final id = q.requestId;
    if (id != null && id != 0) return id;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('no request id');
}

void main() {
  if (_lib == null || _lib.isEmpty) {
    test('native runtime tests', () {}, skip: 'AXIOM_RUNTIME_LIB not set');
    return;
  }
  late AxiomRuntime rt;

  setUpAll(() async {
    _blackhole = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _blackhole.listen(_held.add);
    rt = AxiomRuntime();
  });

  tearDownAll(() async {
    await rt.shutdown();
    for (final s in _held) {
      s.destroy();
    }
    await _blackhole.close();
  });

  test('1 version handshake + idempotent initialize', () async {
    final info = rt.runtimeInfo;
    expect(info.abiVersion, 1);
    expect(info.dataAbiVersion, 1);
    expect(info.contractReaderVersion, greaterThanOrEqualTo(3));
    expect(info.isCompatible, isTrue);

    expect(rt.isInitialized, isFalse);
    final r = await rt.initialize(_config(), assetLoader: _fileLoader);
    expect(r.ok, isTrue, reason: '$r');
    expect(r.alreadyInitialized, isFalse);
    expect(r.contracts['fixture']!.trust, AxiomContractTrust.unsigned);
    expect(r.contracts['fixture']!.status, -1);
    expect(rt.isInitialized, isTrue);
    expect(rt.initResult, isNotNull);

    final again = await rt.initialize(_config(), assetLoader: _fileLoader);
    expect(again.alreadyInitialized, isTrue);
    expect(again.ok, isTrue);

    final s = await settle(everything(rt).stream);
    expect(s.isSuccess, isTrue, reason: '${s.error}');
    expect((s.data as Map)['id'], 'e1');
  });

  test('4 contract security: locked load rejects bad hash / missing signature',
      () async {
    final bytes = await File(_contractPath).readAsBytes();
    final noSig = rt.tryLoadContract(
      namespace: 'locked',
      baseUrl: _baseUrl,
      contractBytes: bytes,
      sha256: '0' * 64,
    );
    expect(noSig.ok, isFalse);
    expect(noSig.trust, isNull);
    expect(noSig.status, FfiError.invalidContract);
    final badSig = rt.tryLoadContract(
      namespace: 'signed',
      baseUrl: _baseUrl,
      contractBytes: bytes,
      signature: 'AAAA',
      publicKey: 'AAAA',
    );
    expect(badSig.ok, isFalse);
    expect(() => rt.loadContract(
          namespace: 'locked',
          baseUrl: _baseUrl,
          contractBytes: bytes,
          sha256: '0' * 64,
        ), throwsStateError);
    final unsigned = rt.tryLoadContract(
      namespace: 'fixture2',
      baseUrl: _baseUrl,
      contractBytes: bytes,
    );
    expect(unsigned.ok, isTrue);
    expect(unsigned.isSigned, isFalse);
  });

  test('2 explicit cancel delivers Cancelled', () async {
    final q = everything(rt, ns: 'slow', args: {'c': 1});
    final states = <AxiomState<Object?>>[];
    final sub = q.stream.listen(states.add);
    final id = await liveId(q);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(q.cancel(), isTrue);
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!states.any((s) => s.hasError) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final err = states.firstWhere((s) => s.hasError).error!;
    expect(err.isCancelled, isTrue);
    expect(err.code, isA<Cancelled>());
    expect(rt.cancel(id), isFalse, reason: 'already terminal');
    await sub.cancel();
  });

  test('2 last listener cancels, shared listener keeps request alive',
      () async {
    final q = everything(rt, ns: 'slow', args: {'c': 2});
    final a = q.stream.listen((_) {});
    final bStates = <AxiomState<Object?>>[];
    final b = q.stream.listen(bStates.add);
    final id = await liveId(q);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await a.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // Still in flight: cancelling explicitly succeeds.
    expect(rt.cancel(id), isTrue, reason: 'request must survive first unsubscribe');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(bStates.any((s) => s.hasError && s.error!.isCancelled), isTrue);
    await b.cancel();

    final q2 = everything(rt, ns: 'slow', args: {'c': 3});
    final only = q2.stream.listen((_) {});
    final id2 = await liveId(q2);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await only.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(rt.cancel(id2), isFalse, reason: 'last unsubscribe must cancel');
  });

  test('7 per-call timeout -> NetworkTimeout, reported on onError', () async {
    final events = <AxiomErrorEvent>[];
    final esub = rt.onError.listen(events.add);
    final s = await settle(
      everything(rt, ns: 'slow', args: {'t': 1},
              options: const AxiomCallOptions(timeout: Duration(milliseconds: 300)))
          .stream,
    );
    expect(s.hasError, isTrue);
    expect(s.error!.code, isA<NetworkTimeout>(), reason: '${s.error}');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events.any((e) => e.namespace == 'slow' && e.error.code is NetworkTimeout), isTrue);
    await esub.cancel();
  });

  test('7 global error listener excludes cancellations; typed failure fields',
      () async {
    final events = <AxiomErrorEvent>[];
    final esub = rt.onError.listen(events.add);
    final q = rt.sendMutation<Object?>(
      namespace: 'fixture',
      endpointId: epClaim,
      method: 'POST',
      path: '/claims',
      headers: {'content-type': 'application/json'},
      body: {'name': 'taken'},
      decoder: (j) => j,
    );
    final s = await settle(q.stream);
    expect(s.hasError, isTrue);
    // ignore: avoid_print
    print('claim error: ${s.error} details=${s.error!.details} failure=${s.error!.failureCode}');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events.where((e) => e.endpointId == epClaim), isNotEmpty);
    expect(events.any((e) => e.error.isCancelled), isFalse);
    await esub.cancel();
  });

  test('7 per-call headers and cache mode refresh', () async {
    final a = await settle(nonce(rt, epNetworkOnly, '/cache/network-only', 'h1',
            options: const AxiomCallOptions(headers: {'x-fixture-nonce': 'h2'}))
        .stream);
    expect((a.data as Map)['key'], 'h2', reason: 'options.headers override');

    final first = await settle(nonce(rt, epCacheFirst, '/cache/cache-first', 'n1').stream);
    expect((first.data as Map)['key'], 'n1');
    final cached = await settle(nonce(rt, epCacheFirst, '/cache/cache-first', 'n2').stream);
    final refreshed = await settle(nonce(rt, epCacheFirst, '/cache/cache-first', 'n3',
            options: const AxiomCallOptions(cacheMode: AxiomCacheMode.refresh))
        .stream);
    // ignore: avoid_print
    print('cache-first: second=${cached.data} (${cached.source}), refresh=${refreshed.data} (${refreshed.source})');
    expect((refreshed.data as Map)['key'], 'n3');
    expect(refreshed.source, AxiomSource.network);
  });

  test('6 setQueryData / getCachedQueryData / invalidate / clear / purge',
      () async {
    rt.setQueryData<Object?>(
      namespace: 'fixture',
      endpointId: epEcho,
      args: {'x': 1},
      data: {'seeded': true},
    );
    expect(
      rt.getCachedQueryData<Object?>(namespace: 'fixture', endpointId: epEcho, args: {'x': 1}),
      {'seeded': true},
    );

    final q = everything(rt, args: {'inv': 1});
    final states = <AxiomState<Object?>>[];
    final sub = q.stream.listen(states.add);
    await q.stream.firstWhere((s) => s.isSuccess && !s.isFetching);
    expect(rt.getCachedQueryData<Object?>(namespace: 'fixture', endpointId: epEverything, args: {'inv': 1}), isNotNull);

    rt.setQueryData<Object?>(namespace: 'fixture', endpointId: epEverything, args: {'inv': 1}, data: {'id': 'optimistic'});
    await Future<void>.delayed(Duration.zero);
    expect(states.last.data, {'id': 'optimistic'});

    final before = states.length;
    rt.invalidate(namespace: 'fixture', endpointId: epEverything);
    await q.stream.firstWhere((s) => s.isSuccess && !s.isFetching && (s.data as Map)['id'] == 'e1');
    expect(states.length, greaterThan(before));

    final before2 = states.length;
    q.refresh(force: true);
    await q.stream.firstWhere((s) => s.isSuccess && !s.isFetching);
    expect(states.length, greaterThan(before2));

    final before3 = states.length;
    await rt.clearCache('fixture');
    await q.stream.firstWhere((s) => s.isSuccess && !s.isFetching);
    expect(states.length, greaterThan(before3));

    await rt.purgeCache();
    expect(rt.getCachedQueryData<Object?>(namespace: 'fixture', endpointId: epEcho, args: {'x': 1}), isNull);
    rt.invalidate(namespace: 'fixture', cacheIdentity: 'fixture.item');
    await sub.cancel();
  });

  test('5 namespace / global token setters', () async {
    AxiomContractMetadata.registerAuthMethods('fixture', ['Authorization']);
    Future<AxiomState<Object?>> who() => settle(rt
        .send<Object?>(
          namespace: 'fixture',
          endpointId: epAuthBearer,
          method: 'GET',
          path: '/auth/bearer',
          args: {'n': DateTime.now().microsecondsSinceEpoch},
          decoder: (j) => j,
        )
        .stream);
    final none = await who();
    expect(none.hasError, isTrue, reason: 'no token');
    rt.setNamespaceAuthToken(namespace: 'fixture', token: fixtureBearerToken);
    final ok = await who();
    expect(ok.isSuccess, isTrue, reason: '${ok.error}');
    rt.clearNamespaceAuthToken(namespace: 'fixture');
    expect((await who()).hasError, isTrue);
    rt.setGlobalAuthToken(fixtureBearerToken);
    expect((await who()).isSuccess, isTrue);
    rt.clearGlobalAuthToken();
    expect((await who()).hasError, isTrue);
  });

  test('5 auth provider registers and resolves fallbacks', () async {
    rt.setAuthProvider((ns, method) async => ns == 'fixture' ? 'from-provider' : null);
    final io = rt as dynamic;
    expect(await io.resolveAuthToken('fixture', ''), 'from-provider');
    rt.setAuthProvider(null);
    rt.setGlobalAuthToken('g');
    expect(await io.resolveAuthToken('fixture', ''), 'g');
    rt.clearGlobalAuthToken();
  });

  test('8 extensions: audit, lifecycle, invoke unknown', () async {
    final audit = await rt.extensionAudit();
    expect(audit, isNotNull);
    rt.extensionLifecycle(AxiomLifecycleEvent.foreground);
    await expectLater(
      rt.invokeExtension(const AxiomExtensionCall(
        extension: 'missing',
        export: 'run',
        interfaceSha256: 'x',
        abiSymbol: 'y',
        input: {'a': 1},
      )),
      throwsA(isA<AxiomExtensionException>()),
    );
    await expectLater(
      rt.loadExtension(AxiomExtensionPackage(
        target: 'android',
        packageBytes: Uint8List.fromList([1]),
        moduleBytes: Uint8List.fromList([1]),
        authorityBytes: Uint8List.fromList([1]),
        packageLockBytes: Uint8List.fromList([1]),
      )),
      throwsA(isA<AxiomExtensionException>()),
    );
  });

  test('3 resetSession cancels in-flight and clears queries', () async {
    final q = everything(rt, ns: 'slow', args: {'r': 1});
    final states = <AxiomState<Object?>>[];
    final sub = q.stream.listen(states.add);
    await liveId(q);
    rt.setNamespaceAuthToken(namespace: 'fixture', token: fixtureBearerToken);
    await rt.resetSession();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(states.any((s) => s.hasError && s.error!.isCancelled), isTrue);
    expect(AxiomQueryManager().queries().isEmpty, isTrue);
    await sub.cancel();
    // Contracts stay loaded.
    final s = await settle(everything(rt, args: {'after': 'reset'}).stream);
    expect(s.isSuccess, isTrue, reason: '${s.error}');
  });

  test('3 shutdown is idempotent and allows initialize again', () async {
    await rt.shutdown();
    expect(rt.isInitialized, isFalse);
    await rt.shutdown();
    final r = await rt.initialize(_config(), assetLoader: _fileLoader);
    expect(r.ok, isTrue, reason: '$r');
    expect(r.alreadyInitialized, isFalse);
    final s = await settle(everything(rt, args: {'after': 'shutdown'}).stream);
    expect(s.isSuccess, isTrue, reason: '${s.error}');
  });
}
