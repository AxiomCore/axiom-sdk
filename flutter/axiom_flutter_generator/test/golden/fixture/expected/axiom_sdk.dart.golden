// GENERATED CODE - DO NOT EDIT.
// axiom_flutter_generator 0.147.5
// fixture: dev.axiomcore.fixture 1.0.0 variant default schema aa69c58ec8f5

import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';

import 'models.dart' as models;

/// Contract configuration written by `axiom pull`.
abstract final class AxiomDefaultConfig {
  static const AxiomConfig config = AxiomConfig(
    contracts: {
      'fixture': AxiomContractConfig(
        // Neither the contract nor the pull config names a base URL;
        // override with AxiomEnvironment or --dart-define=AXIOM_BASE_URL.
        baseUrl: 'http://localhost:8000',
        assetPath: 'assets/axiom/fixture.axiom',
      ),
    },
  );

  /// sha256 of each contract asset at generation time.
  static const Map<String, String> contractSha256 = {
    'fixture':
        '41c7024ba7c18d6dc99a7ef7dd5b0b634b553e0eb0ddc0b3c1fef6172e927f9a',
  };
}

/// Entry point of the generated client.
class AxiomSdk {
  /// Wraps an already initialized [runtime] (tests, custom start-up).
  AxiomSdk.fromRuntime(
    this.runtime, [
    this.initResult = const AxiomInitResult(ok: true),
  ]) : fixture = FixtureModule._(runtime, 'fixture');

  final AxiomRuntime runtime;

  /// Outcome of runtime start-up and contract loading.
  final AxiomInitResult initResult;

  /// Endpoints of the `fixture` contract.
  final FixtureModule fixture;

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
    models.ContractFailure.registerAll();
    final result = await runtime.initialize(cfg, assetLoader: assetLoader);
    result.requireOk();
    return AxiomSdk.fromRuntime(runtime, result);
  }
}

/// Client for the `fixture` contract (dev.axiomcore.fixture 1.0.0).
class FixtureModule {
  FixtureModule._(this._runtime, this._namespace)
    : axiom = FixtureModuleAxiomNamespace._(_runtime, _namespace);

  final AxiomRuntime _runtime;
  final String _namespace;

  /// Auth tokens and cache control for this namespace.
  final FixtureModuleAxiomNamespace axiom;

  /// Endpoint ids by contract endpoint name.
  static const Map<String, int> endpointIds = {
    'authApiKeyHeader': 1256260924,
    'authApiKeyQuery': 2900873362,
    'authBearer': 1404635741,
    'cacheCacheFirst': 3177318534,
    'cacheNetworkFirst': 1010416358,
    'cacheNetworkOnly': 837292962,
    'cacheStale': 929374064,
    'cachedItem': 1498157384,
    'chunked': 4017861805,
    'claim': 3649530469,
    'createItem': 631501414,
    'deleteItem': 3209564247,
    'echo': 1421147111,
    'everything': 1643923642,
    'retried': 2446114110,
    'sse': 78174837,
    'touchItem': 4036857016,
    'updateItem': 3182762126,
    'uploadBytes': 1096035656,
    'wsEcho': 1471516720,
  };

  /// Endpoint ids by contract cache identity.
  static const Map<String, List<int>> cacheIdentities = {
    'fixture.item': [1498157384],
  };

  /// Auth method names declared by the contract.
  static const List<String> authMethods = [];

  /// `GET /auth/api-key-header`.
  ///
  /// Typed failures: [models.UnauthorizedFailure]; match with `error.whenAuthApiKeyHeader(...)`.
  AxiomQuery<models.Who> authApiKeyHeader({
    required String xApiKey,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{'x-api-key': xApiKey};
    return _runtime.send<models.Who>(
      namespace: _namespace,
      endpointId: 1256260924,
      method: 'GET',
      path: '/auth/api-key-header',
      headers: options?.mergeHeaders(headers) ?? headers,
      args: <String, dynamic>{'x-api-key': xApiKey},
      decoder: models.Who.fromJson,
      options: options,
    );
  }

  /// `GET /auth/api-key-query`.
  ///
  /// Typed failures: [models.UnauthorizedFailure]; match with `error.whenAuthApiKeyQuery(...)`.
  AxiomQuery<models.Who> authApiKeyQuery({
    required String apiKey,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Who>(
      namespace: _namespace,
      endpointId: 2900873362,
      method: 'GET',
      path: '/auth/api-key-query',
      headers: options?.mergeHeaders(null),
      queryParams: {'api_key': apiKey},
      args: <String, dynamic>{'api_key': apiKey},
      decoder: models.Who.fromJson,
      options: options,
    );
  }

  /// `GET /auth/bearer`.
  AxiomQuery<models.Who> authBearer({AxiomCallOptions? options}) {
    return _runtime.send<models.Who>(
      namespace: _namespace,
      endpointId: 1404635741,
      method: 'GET',
      path: '/auth/bearer',
      headers: options?.mergeHeaders(null),
      args: <String, dynamic>{},
      decoder: models.Who.fromJson,
      options: options,
    );
  }

  /// `GET /cache/cache-first`.
  ///
  /// Cache: `cache_first`, ttl 60s. Pass `options: AxiomCallOptions(cacheMode: AxiomCacheMode.refresh)` to bypass it.
  AxiomQuery<models.Stamp> cacheCacheFirst({
    required String nonce,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 3177318534,
      method: 'GET',
      path: '/cache/cache-first',
      headers: options?.mergeHeaders(null),
      queryParams: {'nonce': nonce},
      args: <String, dynamic>{'nonce': nonce},
      decoder: models.Stamp.fromJson,
      options: options,
    );
  }

  /// `GET /cache/network-first`.
  ///
  /// Cache: `network_first`, ttl 60s. Pass `options: AxiomCallOptions(cacheMode: AxiomCacheMode.refresh)` to bypass it.
  AxiomQuery<models.Stamp> cacheNetworkFirst({
    required String nonce,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 1010416358,
      method: 'GET',
      path: '/cache/network-first',
      headers: options?.mergeHeaders(null),
      queryParams: {'nonce': nonce},
      args: <String, dynamic>{'nonce': nonce},
      decoder: models.Stamp.fromJson,
      options: options,
    );
  }

  /// `GET /cache/network-only`.
  ///
  /// Cache: `network_only`, ttl 60s. Pass `options: AxiomCallOptions(cacheMode: AxiomCacheMode.refresh)` to bypass it.
  AxiomQuery<models.Stamp> cacheNetworkOnly({
    required String nonce,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 837292962,
      method: 'GET',
      path: '/cache/network-only',
      headers: options?.mergeHeaders(null),
      queryParams: {'nonce': nonce},
      args: <String, dynamic>{'nonce': nonce},
      decoder: models.Stamp.fromJson,
      options: options,
    );
  }

  /// `GET /cache/stale-while-revalidate`.
  ///
  /// Cache: `stale_while_revalidate`, ttl 60s. Pass `options: AxiomCallOptions(cacheMode: AxiomCacheMode.refresh)` to bypass it.
  AxiomQuery<models.Stamp> cacheStale({
    required String nonce,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 929374064,
      method: 'GET',
      path: '/cache/stale-while-revalidate',
      headers: options?.mergeHeaders(null),
      queryParams: {'nonce': nonce},
      args: <String, dynamic>{'nonce': nonce},
      decoder: models.Stamp.fromJson,
      options: options,
    );
  }

  /// `GET /cache/items/{id}`.
  ///
  /// Cache: `cache_first`, ttl 300s. Pass `options: AxiomCallOptions(cacheMode: AxiomCacheMode.refresh)` to bypass it.
  ///
  /// Cache identity: `fixture.item`.
  AxiomQuery<models.Stamp> cachedItem({
    required String id,
    required String nonce,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Stamp>(
      namespace: _namespace,
      endpointId: 1498157384,
      method: 'GET',
      path: '/cache/items/{id}',
      headers: options?.mergeHeaders(null),
      pathParams: {'id': Uri.encodeComponent(id)},
      queryParams: {'nonce': nonce},
      args: <String, dynamic>{'id': id, 'nonce': nonce},
      decoder: models.Stamp.fromJson,
      options: options,
    );
  }

  /// `GET /stream/chunked` (http_stream).
  AxiomQuery<models.Tick> chunked({String? last, AxiomCallOptions? options}) {
    return _streamQuery<models.Tick>(
      '${_namespace}_4017861805_stream_${jsonEncode(<String, dynamic>{if (last case final v?) 'last': v})}',
      _runtime,
      (extra) => _runtime.callStream(
        namespace: _namespace,
        endpointId: 4017861805,
        method: 'GET',
        path: '/stream/chunked',
        headers: {...?(options?.mergeHeaders(null)), ...extra},
        queryParams: {if (last case final v?) 'last': v},
        requestBytes: Uint8List(0),
        options: options,
      ),
      models.Tick.fromJson,
    );
  }

  /// Frames of `chunked` as a typed stream. Cancelling the subscription
  /// cancels the request.
  Stream<models.Tick> chunkedStream({String? last, AxiomCallOptions? options}) {
    final response = _runtime.callStream(
      namespace: _namespace,
      endpointId: 4017861805,
      method: 'GET',
      path: '/stream/chunked',
      headers: options?.mergeHeaders(null),
      queryParams: {if (last case final v?) 'last': v},
      requestBytes: Uint8List(0),
      options: options,
    );
    return _frames(response, _runtime, models.Tick.fromJson);
  }

  /// `POST /claims`.
  ///
  /// Typed failures: [models.ConflictFailure]; match with `error.whenClaim(...)`.
  AxiomQuery<models.Item> claim({
    required String name,
    String? idempotencyKey,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{
      if (idempotencyKey case final k?) 'Idempotency-Key': k,
    };
    return _runtime.sendMutation<models.Item>(
      namespace: _namespace,
      endpointId: 3649530469,
      method: 'POST',
      path: '/claims',
      headers: options?.mergeHeaders(headers) ?? headers,
      body: jsonEncode(name),
      args: <String, dynamic>{'name': name},
      decoder: models.Item.fromJson,
      options: options,
    );
  }

  /// `POST /items`.
  AxiomQuery<models.Item> createItem({
    required String name,
    required int qty,
    String? idempotencyKey,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{
      if (idempotencyKey case final k?) 'Idempotency-Key': k,
    };
    return _runtime.sendMutation<models.Item>(
      namespace: _namespace,
      endpointId: 631501414,
      method: 'POST',
      path: '/items',
      headers: options?.mergeHeaders(headers) ?? headers,
      body: jsonEncode(<String, dynamic>{'name': name, 'qty': qty}),
      args: <String, dynamic>{'name': name, 'qty': qty},
      decoder: models.Item.fromJson,
      options: options,
    );
  }

  /// `DELETE /items/{id}`.
  AxiomQuery<models.Deleted> deleteItem({
    required String id,
    String? idempotencyKey,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{
      if (idempotencyKey case final k?) 'Idempotency-Key': k,
    };
    return _runtime.sendMutation<models.Deleted>(
      namespace: _namespace,
      endpointId: 3209564247,
      method: 'DELETE',
      path: '/items/{id}',
      headers: options?.mergeHeaders(headers) ?? headers,
      pathParams: {'id': Uri.encodeComponent(id)},
      args: <String, dynamic>{'id': id},
      decoder: models.Deleted.fromJson,
      options: options,
    );
  }

  /// `GET /echo/{path}`.
  AxiomQuery<models.Echo> echo({
    required String path,
    required String q,
    required int limit,
    bool? flag,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Echo>(
      namespace: _namespace,
      endpointId: 1421147111,
      method: 'GET',
      path: '/echo/{path}',
      headers: options?.mergeHeaders(null),
      pathParams: {'path': Uri.encodeComponent(path)},
      queryParams: {
        'q': q,
        'limit': limit.toString(),
        if (flag case final v?) 'flag': v.toString(),
      },
      args: <String, dynamic>{
        'path': path,
        'q': q,
        'limit': limit,
        if (flag case final v?) 'flag': v,
      },
      decoder: models.Echo.fromJson,
      options: options,
    );
  }

  /// `GET /types/everything`.
  AxiomQuery<models.Everything> everything({AxiomCallOptions? options}) {
    return _runtime.send<models.Everything>(
      namespace: _namespace,
      endpointId: 1643923642,
      method: 'GET',
      path: '/types/everything',
      headers: options?.mergeHeaders(null),
      args: <String, dynamic>{},
      decoder: models.Everything.fromJson,
      options: options,
    );
  }

  /// `GET /retry`.
  AxiomQuery<models.Retried> retried({
    required int attempt,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Retried>(
      namespace: _namespace,
      endpointId: 2446114110,
      method: 'GET',
      path: '/retry',
      headers: options?.mergeHeaders(null),
      queryParams: {'attempt': attempt.toString()},
      args: <String, dynamic>{'attempt': attempt},
      decoder: models.Retried.fromJson,
      options: options,
    );
  }

  /// `GET /stream/sse` (sse).
  AxiomQuery<models.Tick> sse({
    String? lastEventId,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{
      if (lastEventId case final v?) 'last-event-id': v,
    };
    return _streamQuery<models.Tick>(
      '${_namespace}_78174837_stream_${jsonEncode(<String, dynamic>{if (lastEventId case final v?) 'last-event-id': v})}',
      _runtime,
      (extra) => _runtime.callStream(
        namespace: _namespace,
        endpointId: 78174837,
        method: 'GET',
        path: '/stream/sse',
        headers: {...(options?.mergeHeaders(headers) ?? headers), ...extra},
        requestBytes: Uint8List(0),
        options: options,
      ),
      models.Tick.fromJson,
    );
  }

  /// Frames of `sse` as a typed stream. Cancelling the subscription
  /// cancels the request.
  Stream<models.Tick> sseStream({
    String? lastEventId,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{
      if (lastEventId case final v?) 'last-event-id': v,
    };
    final response = _runtime.callStream(
      namespace: _namespace,
      endpointId: 78174837,
      method: 'GET',
      path: '/stream/sse',
      headers: options?.mergeHeaders(headers) ?? headers,
      requestBytes: Uint8List(0),
      options: options,
    );
    return _frames(response, _runtime, models.Tick.fromJson);
  }

  /// `POST /cache/items/{id}/touch`.
  ///
  /// On success invalidates: `fixture.item`.
  AxiomQuery<models.Stamp> touchItem({
    required String id,
    required String nonce,
    String? idempotencyKey,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{
      if (idempotencyKey case final k?) 'Idempotency-Key': k,
    };
    final query = _runtime.sendMutation<models.Stamp>(
      namespace: _namespace,
      endpointId: 4036857016,
      method: 'POST',
      path: '/cache/items/{id}/touch',
      headers: options?.mergeHeaders(headers) ?? headers,
      pathParams: {'id': Uri.encodeComponent(id)},
      queryParams: {'nonce': nonce},
      args: <String, dynamic>{'id': id, 'nonce': nonce},
      decoder: models.Stamp.fromJson,
      options: options,
    );
    return _onSuccess(query, _runtime, () {
      _invalidateEndpoints(_runtime, _namespace, const [1498157384]);
    });
  }

  /// `PUT /items/{id}`.
  AxiomQuery<models.Item> updateItem({
    required String id,
    required String name,
    required int qty,
    String? idempotencyKey,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{
      if (idempotencyKey case final k?) 'Idempotency-Key': k,
    };
    return _runtime.sendMutation<models.Item>(
      namespace: _namespace,
      endpointId: 3182762126,
      method: 'PUT',
      path: '/items/{id}',
      headers: options?.mergeHeaders(headers) ?? headers,
      pathParams: {'id': Uri.encodeComponent(id)},
      body: jsonEncode(<String, dynamic>{'name': name, 'qty': qty}),
      args: <String, dynamic>{'id': id, 'name': name, 'qty': qty},
      decoder: models.Item.fromJson,
      options: options,
    );
  }

  /// `POST /bytes`.
  AxiomQuery<models.BytesOut> uploadBytes({
    required Uint8List data,
    String? idempotencyKey,
    AxiomCallOptions? options,
  }) {
    final headers = <String, String>{
      if (idempotencyKey case final k?) 'Idempotency-Key': k,
    };
    return _runtime.sendMutation<models.BytesOut>(
      namespace: _namespace,
      endpointId: 1096035656,
      method: 'POST',
      path: '/bytes',
      headers: options?.mergeHeaders(headers) ?? headers,
      body: jsonEncode(models.AxiomGeneratedCodec.bytesToJson(data)),
      args: <String, dynamic>{
        'data': models.AxiomGeneratedCodec.bytesToJson(data),
      },
      decoder: models.BytesOut.fromJson,
      options: options,
    );
  }

  /// `WS /stream/ws` (websocket).
  AxiomQuery<models.Ping> wsEcho({
    required models.Ping message,
    AxiomCallOptions? options,
  }) {
    return _runtime.send<models.Ping>(
      namespace: _namespace,
      endpointId: 1471516720,
      method: 'WS',
      path: '/stream/ws',
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
      endpointId: 1471516720,
      method: 'WS',
      path: '/stream/ws',
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

/// Namespace-level runtime controls for `fixture`.
class FixtureModuleAxiomNamespace {
  FixtureModuleAxiomNamespace._(this._runtime, this._namespace);

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

/// Wraps a mutation so [onSuccess] runs once after its first success.
AxiomQuery<T> _onSuccess<T>(
  AxiomQuery<T> query,
  AxiomRuntime runtime,
  void Function() onSuccess,
) {
  var done = false;
  return AxiomQuery<T>(
    query.key,
    (headers) {
      headers.forEach(query.setHeader);
      final stream = query.stream.map((state) {
        if (!done && state.status == AxiomStatus.success) {
          done = true;
          onSuccess();
        }
        return state;
      });
      return AxiomActiveStream<T>(query.requestId ?? 0, stream);
    },
    isMutation: true,
    runtime: runtime,
  );
}

/// An [AxiomQuery] over a streaming endpoint: one success state per frame.
AxiomQuery<T> _streamQuery<T>(
  String key,
  AxiomRuntime runtime,
  AxiomStreamResponse Function(Map<String, String> extra) open,
  T Function(Object?) decode,
) {
  return AxiomQuery<T>(key, (extra) {
    final response = open(extra);
    final states = response.stream.expand<AxiomState<T>>((state) {
      final error = state.error;
      if (error != null) return [AxiomState<T>.error(error)];
      final data = state.data;
      if (data == null || data.isEmpty) {
        return state.isLoading ? [AxiomState<T>.loading()] : const [];
      }
      try {
        return [
          for (final frame in _splitFrames(utf8.decode(data)))
            AxiomState<T>.success(
              decode(frame),
              state.source,
              isStreaming: true,
            ),
        ];
      } on FormatException catch (e) {
        return [
          AxiomState<T>.error(
            AxiomError(
              stage: ErrorStage.deserialize,
              category: ErrorCategory.serialization,
              code: const CodecError(),
              message: e.message,
              retryable: false,
            ),
          ),
        ];
      }
    }).asBroadcastStream();
    return AxiomActiveStream<T>(response.requestId, states);
  }, runtime: runtime);
}

/// Decodes stream chunks (JSON, NDJSON or SSE `data:` lines) into frames.
Stream<T> _frames<T>(
  AxiomStreamResponse response,
  AxiomRuntime runtime,
  T Function(Object?) decode,
) async* {
  var finished = false;
  try {
    await for (final state in response.stream) {
      final error = state.error;
      if (error != null) {
        finished = true;
        if (error.isCancelled) return;
        throw error;
      }
      final data = state.data;
      if (data != null && data.isNotEmpty) {
        for (final frame in _splitFrames(utf8.decode(data))) {
          yield decode(frame);
        }
      }
    }
    finished = true;
  } finally {
    if (!finished) {
      try {
        runtime.cancel(response.requestId);
      } on UnimplementedError {
        // Runtime without cancel support.
      }
    }
  }
}

List<Object?> _splitFrames(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (!trimmed.startsWith('data:') &&
      !trimmed.startsWith('event:') &&
      !trimmed.startsWith('id:') &&
      !trimmed.startsWith(':')) {
    try {
      return [jsonDecode(trimmed)];
    } on FormatException {
      return [
        for (final line in trimmed.split('\n'))
          if (line.trim().isNotEmpty) jsonDecode(line),
      ];
    }
  }
  final frames = <Object?>[];
  final data = <String>[];
  for (final line in '$trimmed\n\n'.split('\n')) {
    if (line.startsWith('data:')) {
      data.add(line.substring(5).trimLeft());
    } else if (line.trim().isEmpty && data.isNotEmpty) {
      frames.add(jsonDecode(data.join('\n')));
      data.clear();
    }
  }
  return frames;
}
