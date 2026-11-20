// GENERATED CODE - DO NOT EDIT.
// axiom_flutter_generator 0.150.0
// bench: dev.axiomcore.bench 1.0.0 variant default schema 82a84e0daf09

import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'models.dart' as models;

/// Contract configuration written by `axiom pull`.
abstract final class AxiomDefaultConfig {
  static const AxiomConfig config = AxiomConfig(
    contracts: {
      'bench': AxiomContractConfig(
        // Neither the contract nor the pull config names a base URL;
        // override with AxiomEnvironment or --dart-define=AXIOM_BASE_URL.
        baseUrl: 'http://localhost:8000',
        assetPath: 'assets/axiom/bench.axiom',
      ),
    },
  );

  /// sha256 of each contract asset at generation time.
  static const Map<String, String> contractSha256 = {
    'bench': 'd413b70fc237fd5c9d30c7434c51d8f7d9e493d5f123fe3e18f6f773a59fc790',
  };
}

/// Entry point of the generated client.
class AxiomSdk {
  /// Wraps an already initialized [runtime] (tests, custom start-up).
  AxiomSdk.fromRuntime(
    this.runtime, [
    this.initResult = const AxiomInitResult(ok: true),
  ]) : bench = BenchModule._(runtime, 'bench');

  final AxiomRuntime runtime;

  /// Outcome of runtime start-up and contract loading.
  final AxiomInitResult initResult;

  /// Endpoints of the `bench` contract.
  final BenchModule bench;

  /// Starts the runtime and loads the contracts.
  ///
  /// Base URL priority: [baseUrlOverrides] > [environment] (or the
  /// config's, else `--dart-define=AXIOM_ENV` / `AXIOM_BASE_URL`) >
  /// the generated default. Throws when initialization fails.
  static Future<AxiomSdk> create({
    AxiomConfig? config,
    AxiomEnvironment? environment,
    Map<String, String>? baseUrlOverrides,
    AxiomAssetLoader? assetLoader,
  }) async {
    final base = config ?? AxiomDefaultConfig.config;
    final cfg = base.copyWith(
      environment:
          environment ?? base.environment ?? AxiomEnvironment.fromDartDefines(),
      baseUrlOverrides: baseUrlOverrides,
    );
    final runtime = AxiomRuntime();
    runtime.debug = cfg.debug;
    AxiomInitResult result;
    try {
      result = await runtime.initialize(cfg, assetLoader: assetLoader);
    } on UnimplementedError {
      // Runtime package without initialize(): legacy start-up.
      result = await _legacyInit(runtime, cfg, assetLoader);
    }
    result.requireOk();
    return AxiomSdk.fromRuntime(runtime, result);
  }
}

/// Client for the `bench` contract (dev.axiomcore.bench 1.0.0).
class BenchModule {
  BenchModule._(this._runtime, this._namespace)
    : axiom = BenchModuleAxiomNamespace._(_runtime, _namespace);

  final AxiomRuntime _runtime;
  final String _namespace;

  /// Auth tokens and cache control for this namespace.
  final BenchModuleAxiomNamespace axiom;

  /// Endpoint ids by contract endpoint name.
  static const Map<String, int> endpointIds = {
    'cachedItems': 1375712977,
    'createItem': 3770474694,
    'getItem': 3817711848,
    'listItems': 113632206,
    'wsEcho': 3413220605,
  };

  /// Endpoint ids by contract cache identity.
  static const Map<String, List<int>> cacheIdentities = {};

  /// Auth method names declared by the contract.
  static const List<String> authMethods = [];

  /// `GET /cached/items`.
  ///
  /// Cache: `cache_first`, ttl 600s. Pass `options: AxiomCallOptions(cacheMode: AxiomCacheMode.refresh)` to bypass it.
  AxiomQuery<models.ItemList> cachedItems({
    required int n,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.ItemList>(
      namespace: _namespace,
      endpointId: 1375712977,
      method: 'GET',
      path: '/cached/items',
      headers: options?.mergeHeaders(null),
      queryParams: {'n': n.toString()},
      args: <String, dynamic>{'n': n},
      decoder: models.ItemList.fromJson,
      options: options,
    );
  }

  /// `POST /items`.
  AxiomQuery<models.Item> createItem({
    required String name,
    required double price,
    required int qty,
    String? idempotencyKey,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{
      if (idempotencyKey case final k?) 'Idempotency-Key': k,
    };
    return _runtime.sendMutation<models.Item>(
      namespace: _namespace,
      endpointId: 3770474694,
      method: 'POST',
      path: '/items',
      headers: options?.mergeHeaders(headers) ?? headers,
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'price': price,
        'qty': qty,
      }),
      args: <String, dynamic>{'name': name, 'price': price, 'qty': qty},
      decoder: models.Item.fromJson,
      options: options,
    );
  }

  /// `GET /items/{id}`.
  ///
  /// Cache: `network_only`, ttl 60s. Pass `options: AxiomCallOptions(cacheMode: AxiomCacheMode.refresh)` to bypass it.
  AxiomQuery<models.Item> getItem({
    required String id,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Item>(
      namespace: _namespace,
      endpointId: 3817711848,
      method: 'GET',
      path: '/items/{id}',
      headers: options?.mergeHeaders(null),
      pathParams: {'id': Uri.encodeComponent(id)},
      args: <String, dynamic>{'id': id},
      decoder: models.Item.fromJson,
      options: options,
    );
  }

  /// `GET /items`.
  ///
  /// Cache: `network_only`, ttl 60s. Pass `options: AxiomCallOptions(cacheMode: AxiomCacheMode.refresh)` to bypass it.
  AxiomQuery<models.ItemList> listItems({
    required int n,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.ItemList>(
      namespace: _namespace,
      endpointId: 113632206,
      method: 'GET',
      path: '/items',
      headers: options?.mergeHeaders(null),
      queryParams: {'n': n.toString()},
      args: <String, dynamic>{'n': n},
      decoder: models.ItemList.fromJson,
      options: options,
    );
  }

  /// `WS /ws` (websocket).
  AxiomQuery<models.Ping> wsEcho({
    required models.Ping message,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Ping>(
      namespace: _namespace,
      endpointId: 3413220605,
      method: 'WS',
      path: '/ws',
      headers: options?.mergeHeaders(null),
      body: jsonEncode(message.toJson()),
      args: <String, dynamic>{'message': message.toJson()},
      decoder: models.Ping.fromJson,
      options: options,
    );
  }

  /// Typed WebSocket channel for `wsEcho`: send [models.Ping], receive [models.Ping].
  AxiomChannel<models.Ping, models.Ping> wsEchoChannel({
    AxiomReconnectPolicy reconnect = AxiomReconnectPolicy.auto,
    AxiomCallOptions? options,
  }) {
    return _runtime.openChannel<models.Ping, models.Ping>(
      namespace: _namespace,
      endpointId: 3413220605,
      method: 'WS',
      path: '/ws',
      headers: options?.mergeHeaders(null),
      decoder: models.Ping.fromJson,
      reconnect: reconnect,
      options: options,
    );
  }

  /// Refetches the active queries of every endpoint with [identity].
  void invalidateIdentity(String identity) {
    final ids = cacheIdentities[identity];
    if (ids == null) return;
    _invalidateEndpoints(_runtime, _namespace, ids);
  }
}

/// Namespace-level runtime controls for `bench`.
class BenchModuleAxiomNamespace {
  BenchModuleAxiomNamespace._(this._runtime, this._namespace);

  final AxiomRuntime _runtime;
  final String _namespace;

  void setAuthToken(String methodName, String token) {
    _runtime.setAuthToken(
      namespace: _namespace,
      methodName: methodName,
      token: token,
    );
  }

  void clearAuthToken(String methodName) {
    _runtime.clearAuthToken(namespace: _namespace, methodName: methodName);
  }

  /// Sets [token] for every auth method of this namespace.
  void setNamespaceToken(String token) {
    _runtime.setNamespaceAuthToken(namespace: _namespace, token: token);
  }

  void clearNamespaceToken() {
    _runtime.clearNamespaceAuthToken(namespace: _namespace);
  }

  /// Marks every cached query of this namespace stale and refetches.
  void invalidateAll() {
    _runtime.invalidate(namespace: _namespace);
  }
}

/// Start-up for axiom_flutter versions whose initialize() is not
/// implemented yet: init + loadContract per namespace.
Future<AxiomInitResult> _legacyInit(
  AxiomRuntime runtime,
  AxiomConfig cfg,
  AxiomAssetLoader? assetLoader,
) async {
  final load =
      assetLoader ??
      (String path) async => (await rootBundle.load(path)).buffer.asUint8List();
  await runtime.init(cfg.dbPath);
  final contracts = <String, AxiomContractLoadResult>{};
  for (final entry in cfg.contracts.entries) {
    final baseUrl = cfg.resolveBaseUrl(entry.key);
    runtime.loadContract(
      namespace: entry.key,
      baseUrl: baseUrl,
      contractBytes: await load(entry.value.assetPath),
      signature: entry.value.signature,
      publicKey: entry.value.publicKey,
    );
    contracts[entry.key] = AxiomContractLoadResult(
      namespace: entry.key,
      baseUrl: baseUrl,
      status: entry.value.signature == null ? -1 : 0,
      trust: entry.value.signature == null
          ? AxiomContractTrust.unsigned
          : AxiomContractTrust.signed,
    );
  }
  return AxiomInitResult(ok: true, contracts: contracts);
}

/// Refetches active queries of [endpointIds] after a mutation (the runtime
/// already dropped their cached responses).
void _invalidateEndpoints(
  AxiomRuntime runtime,
  String namespace,
  List<int> endpointIds,
) {
  for (final id in endpointIds) {
    try {
      runtime.invalidate(namespace: namespace, endpointId: id);
    } on UnimplementedError {
      return;
    }
  }
}
