import 'dart:typed_data';

import 'call_options.dart';
import 'channel.dart';
import 'config.dart';
import 'errors.dart';
import 'extension_host.dart';
import 'init_result.dart';
import 'runtime_info.dart';
import 'state.dart';
import 'query.dart';

import 'runtime_stub.dart'
    if (dart.library.io) 'runtime_io.dart'
    if (dart.library.js_interop) 'runtime_web.dart';

/// Raw response stream of [AxiomRuntime.callStream].
class AxiomStreamResponse {
  /// Runtime request id; pass it to [AxiomRuntime.cancel].
  final int requestId;

  /// Raw byte states, one per chunk.
  final Stream<AxiomState<Uint8List>> stream;

  /// Creates a response.
  AxiomStreamResponse(this.requestId, this.stream);
}

/// A request id with its typed state stream.
class AxiomActiveStream<T> {
  /// Runtime request id; pass it to [AxiomRuntime.cancel].
  final int requestId;

  /// Typed states of the request.
  final Stream<AxiomState<T>> stream;

  /// Creates an active stream.
  AxiomActiveStream(this.requestId, this.stream);
}

/// Supplies a fresh credential when the runtime asks for one
/// (`axiom_register_auth_provider` callback, answered with
/// `axiom_provide_auth_token`). Return null to send the request without a
/// token. [methodName] is the contract auth method (for example
/// `Authorization`); it is an empty string when the runtime did not say.
typedef AxiomAuthProvider =
    Future<String?> Function(String namespace, String methodName);

/// Loads the bytes of a Flutter asset. Defaults to `rootBundle.load`.
typedef AxiomAssetLoader = Future<Uint8List> Function(String assetPath);

/// The process-wide Axiom runtime. One instance per isolate (singleton).
///
/// Lifecycle: [initialize] (or legacy [init] + [loadContract]) ->
/// calls -> optional [resetSession] on logout -> [shutdown] on hot restart or
/// app exit. After [shutdown], [initialize] may be called again.
abstract class AxiomRuntime {
  /// Returns the runtime for the current platform (native or web).
  factory AxiomRuntime() => getRuntime();

  /// Prints runtime events to the console when true.
  bool debug = false;

  // ---------------------------------------------------------------------------
  // Initialization and version handshake
  // ---------------------------------------------------------------------------

  /// Legacy start-up: starts the runtime with [dbPath]. Idempotent: a second
  /// call returns the first call's future. Does not load contracts.
  /// New code should use [initialize].
  Future<void> init([String? dbPath]);

  /// Starts the runtime, checks [runtimeInfo] against
  /// [AxiomRuntimeInfo.expected] and loads every contract in [config].
  ///
  /// Idempotent: while running, later calls return the first result with
  /// [AxiomInitResult.alreadyInitialized] set and ignore their arguments.
  /// Never throws for load failures; inspect [AxiomInitResult.ok] or call
  /// [AxiomInitResult.requireOk]. A version mismatch yields `ok == false`
  /// with an [AxiomVersionMismatch] error and no contracts loaded.
  ///
  /// Contracts with [AxiomContractConfig.sha256] use the locked load; base
  /// URLs come from [AxiomConfig.resolveBaseUrl]. [assetLoader] defaults to
  /// `rootBundle`.
  Future<AxiomInitResult> initialize(
    AxiomConfig config, {
    AxiomAssetLoader? assetLoader,
  });

  /// True between a successful [init]/[initialize] and [shutdown].
  bool get isInitialized;

  /// Last [initialize] result, or null.
  AxiomInitResult? get initResult;

  /// Versions reported by the loaded runtime library. Reading it opens the
  /// library but does not start the runtime.
  AxiomRuntimeInfo get runtimeInfo;

  /// Legacy start-up: [init] plus one unnamed contract. New code should use [initialize].
  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
    String? signature,
    String? publicKey,
  });

  /// Loads one contract into [namespace]. Throws [StateError] on failure.
  ///
  /// With [sha256] set this calls `axiom_load_contract_locked`, which also
  /// requires [signature] and [publicKey]. Without it, `axiom_load_contract`
  /// (unsigned when signature is null).
  void loadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
    String? sha256,
  });

  /// Like [loadContract] but returns the outcome instead of throwing.
  AxiomContractLoadResult tryLoadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
    String? sha256,
  });

  // ---------------------------------------------------------------------------
  // Calls
  // ---------------------------------------------------------------------------

  /// Sends a query to [endpointId] of [namespace]. Generated clients call
  /// this; you normally use the generated method instead.
  ///
  /// [args] build the cache key. [decoder] maps the response JSON to [T].
  AxiomQuery<T> send<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic> args = const {},
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
    AxiomCallOptions? options,
  });

  /// Like [send] for commands (POST, PUT, DELETE). The query is a mutation:
  /// it is never deduplicated and never cancelled implicitly.
  AxiomQuery<T> sendMutation<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic> args = const {},
    Object? body,
    required T Function(dynamic json) decoder,
    AxiomCallOptions? options,
  });

  /// Starts a streaming call (SSE, NDJSON, file stream) and returns the raw
  /// chunks. Generated `...Stream()` methods decode the frames for you.
  AxiomStreamResponse callStream({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    required Uint8List requestBytes,
    AxiomCallOptions? options,
  });

  /// Opens a typed bidirectional channel for a `websocket` endpoint.
  ///
  /// [decoder] maps each received JSON frame to [R]; sent values of type
  /// [S] are encoded with the SDK codec. [reconnect] mirrors the contract
  /// stream `reconnect` option. The channel's stream is broadcast and stable
  /// across reconnects; closing it cancels the request.
  AxiomChannel<R, S> openChannel<R, S>({
    required String namespace,
    required int endpointId,
    required String path,
    String method = 'GET',
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    required R Function(dynamic json) decoder,
    AxiomReconnectPolicy reconnect = AxiomReconnectPolicy.none,
    AxiomCallOptions? options,
  });

  /// Supplies an explicit bearer/API-key credential for this runtime process.
  ///
  /// This is intentionally not a session-cookie API. Contracts declaring
  /// `type = "session"` and `location = "cookie"` use the runtime-managed
  /// cookie jar automatically, keeping HttpOnly cookie values out of Dart.
  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  });

  /// Removes the token set by [setAuthToken].
  void clearAuthToken({required String namespace, required String methodName});

  /// Sets [token] for every auth method of [namespace]. Per-method tokens
  /// from [setAuthToken] take precedence.
  void setNamespaceAuthToken({
    required String namespace,
    required String token,
  });

  /// Removes the token set by [setNamespaceAuthToken].
  void clearNamespaceAuthToken({required String namespace});

  /// Sets [token] for every namespace and auth method. Namespace and
  /// per-method tokens take precedence.
  void setGlobalAuthToken(String token);

  /// Removes the token set by [setGlobalAuthToken].
  void clearGlobalAuthToken();

  /// Registers (or with null, removes) the refresh callback asked for a
  /// token when the runtime needs one. Replaces any previous provider.
  void setAuthProvider(AxiomAuthProvider? provider);

  /// Sends [payload] on the open stream [requestId] (legacy WebSocket API;
  /// prefer [AxiomChannel.send]).
  void sendStreamMessage({required int requestId, required Uint8List payload});

  // ---------------------------------------------------------------------------
  // Cancellation, session, shutdown
  // ---------------------------------------------------------------------------

  /// Requests cooperative cancellation of [requestId] (`axiom_cancel` /
  /// `axiom_wasm_cancel`). Returns true when the request was live; it then
  /// emits one error with code [Cancelled] and completes. Returns false when
  /// it was already finished or unknown. Never throws.
  bool cancel(int requestId);

  /// Logout boundary (`axiom_reset_session`): cancels every in-flight call,
  /// clears the session-partitioned cache, active queries and all tokens set
  /// from Dart, and drops the auth provider. Loaded contracts stay loaded.
  Future<void> resetSession();

  /// Tears the runtime down for hot restart or app exit: cancels in-flight
  /// calls, clears the response callback (`axiom_clear_callback`), stops the
  /// event loop isolate, closes all streams. Safe to call more than once and
  /// before init. [isInitialized] is false afterwards.
  Future<void> shutdown();

  // ---------------------------------------------------------------------------
  // Cache control
  // ---------------------------------------------------------------------------

  /// Marks cached data stale and refetches matching active queries.
  ///
  /// - [cacheIdentity]: every operation in [namespace] whose contract
  ///   metadata declares this cache identity (what a mutation's
  ///   `invalidates` list names).
  /// - [endpointId] (+ optional [args]): one endpoint, or one query key.
  /// - only [namespace]: everything in the namespace.
  void invalidate({
    required String namespace,
    String? cacheIdentity,
    int? endpointId,
    Map<String, dynamic>? args,
  });

  /// Writes [data] as the current value of the query
  /// ([namespace], [endpointId], [args]) and pushes it to listeners
  /// (optimistic update). Not persisted to the runtime cache.
  void setQueryData<T>({
    required String namespace,
    required int endpointId,
    Map<String, dynamic> args = const {},
    required T data,
  });

  /// Last value held for the query, or null if none is cached in Dart.
  T? getCachedQueryData<T>({
    required String namespace,
    required int endpointId,
    Map<String, dynamic> args = const {},
  });

  /// Clears cached data for [namespace] (all namespaces when null) and
  /// refetches the active queries.
  Future<void> clearCache([String? namespace]);

  /// Clears cached data for [namespace] (all when null) without refetching.
  /// Active queries keep their last value until their next fetch.
  Future<void> purgeCache([String? namespace]);

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------

  /// Broadcast stream of every error emitted by any call. Cancellations
  /// ([Cancelled]) are not reported.
  Stream<AxiomErrorEvent> get onError;

  // ---------------------------------------------------------------------------
  // Extensions (native only; web throws UnsupportedError)
  // ---------------------------------------------------------------------------

  /// Loads a sandboxed extension (`axiom_extension_load_locked`). Throws
  /// [AxiomExtensionException] on a non-zero status.
  Future<void> loadExtension(AxiomExtensionPackage package);

  /// Invokes a verified extension export (`axiom_extension_invoke`) and
  /// returns its decoded JSON result.
  Future<Object?> invokeExtension(AxiomExtensionCall call);

  /// Forwards a lifecycle event to every extension host
  /// (`axiom_extension_lifecycle`).
  void extensionLifecycle(AxiomLifecycleEvent event);

  /// Snapshot of extension provenance and lifecycle records
  /// (`axiom_extension_audit`), decoded from JSON.
  Future<Object?> extensionAudit();
}

/// Event type codes sent by the runtime callback.
class EventType {
  /// The request finished.
  static const int complete = 0;

  /// Data came from the network.
  static const int networkSuccess = 1;

  /// Data came from the cache.
  static const int cacheHit = 2;

  /// Cached data was returned and a network refresh started.
  static const int cacheHitAndFetching = 3;

  /// The request failed.
  static const int error = 4;

  /// One chunk of a streaming response.
  static const int streamChunk = 5;
}

/// Status codes returned by the runtime C API.
class FfiError {
  /// Contract loaded without a signature.
  static const int successUnverified = -1;

  /// Success.
  static const int success = 0;

  /// Unknown error.
  static const int unknownError = 1;

  /// The request could not be parsed.
  static const int requestParsingFailed = 2;

  /// Network error.
  static const int networkError = 3;

  /// The response could not be decoded.
  static const int responseDeserializationFailed = 4;

  /// The endpoint id is not in the contract.
  static const int unknownEndpoint = 5;

  /// Timeout.
  static const int timeout = 6;

  /// The request failed.
  static const int requestFailed = 7;

  /// Authentication failed.
  static const int authError = 8;

  /// The server returned an error.
  static const int serverError = 9;

  /// The contract is invalid or its proof does not match.
  static const int invalidContract = 10;

  /// The runtime is older than the contract needs.
  static const int runtimeTooOld = 11;

  /// No contract is loaded for the namespace.
  static const int contractNotLoaded = 12;

  /// Runtime initialization failed.
  static const int initializationFailed = 13;

  /// Internal runtime error.
  static const int internalError = 14;

  /// Request cancelled by `axiom_cancel` / reset. The error message is plain
  /// text (`Request cancelled by host`), not AxiomError JSON.
  static const int cancelled = 15;

  /// Readable name of [code].
  static String name(int code) {
    return switch (code) {
      successUnverified => 'SuccessUnverified',
      success => 'Success',
      unknownError => 'UnknownError',
      requestParsingFailed => 'RequestParsingFailed',
      networkError => 'NetworkError',
      responseDeserializationFailed => 'ResponseDeserializationFailed',
      unknownEndpoint => 'UnknownEndpoint',
      timeout => 'Timeout',
      requestFailed => 'RequestFailed',
      authError => 'AuthError',
      serverError => 'ServerError',
      invalidContract => 'InvalidContract',
      runtimeTooOld => 'RuntimeTooOld',
      contractNotLoaded => 'ContractNotLoaded',
      initializationFailed => 'InitializationFailed',
      internalError => 'InternalError',
      cancelled => 'Cancelled',
      _ => 'UnrecognizedErrorCode',
    };
  }
}
