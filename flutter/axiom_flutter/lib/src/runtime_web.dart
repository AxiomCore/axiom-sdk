import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

import 'call_options.dart';
import 'channel.dart';
import 'config.dart';
import 'errors.dart';
import 'extension_host.dart';
import 'init_result.dart';
import 'runtime_info.dart';
import 'runtime_interface.dart';
import 'state.dart';
import 'query.dart';
import 'query_manager.dart';
import 'internal/axiom_codec.dart';
import 'internal/query_key.dart';
import 'internal/tracing.dart';
import 'internal/contract_load_status.dart';

AxiomRuntime getRuntime() => AxiomRuntimeWeb();

@JS('wasm_bindgen')
external JSPromise _wasmBindgenInit(JSAny moduleOrPath);

@JS()
@staticInterop
class WasmExports {}

extension WasmExportsExt on WasmExports {
  @JS('axiom_wasm_initialize')
  external int axiomInitialize(int dbPtr, int dbLen);

  @JS('axiom_wasm_load_contract')
  external int axiomLoadContract(
    int nPtr,
    int nLen,
    int bPtr,
    int bLen,
    int cPtr,
    int cLen,
    int sPtr,
    int sLen,
    int pkPtr,
    int pkLen,
  );

  @JS('axiom_wasm_call')
  external void axiomCall(
    JSNumber reqId,
    int nPtr,
    int nLen,
    int epId,
    int mPtr,
    int mLen,
    int pPtr,
    int pLen,
    int tpPtr,
    int tpLen,
    int hPtr,
    int hLen, // <-- Headers
    int bPtr,
    int bLen, // <-- Payload
  );

  @JS('axiom_wasm_set_auth_token')
  external void axiomSetAuthToken(
    int nPtr,
    int nLen,
    int mPtr,
    int mLen,
    int tPtr,
    int tLen,
  );

  @JS('axiom_wasm_clear_auth_token')
  external void axiomClearAuthToken(int nPtr, int nLen, int mPtr, int mLen);

  @JS('axiom_wasm_send_stream_message')
  external void axiomSendMsg(JSNumber reqId, int ptr, int len);

  @JS('axiom_malloc')
  external int axiomMalloc(int size);

  @JS('axiom_free_memory')
  external void axiomFreeMemory(int ptr, int size);

  @JS('axiom_process_responses')
  external void axiomProcessResponses();

  @JS('memory')
  external WasmMemory get memory;
}

@JS()
@staticInterop
class WasmMemory {}

extension WasmMemoryExt on WasmMemory {
  @JS('buffer')
  external JSArrayBuffer get jsBuffer;
}

class AxiomRuntimeWeb implements AxiomRuntime {
  static AxiomRuntimeWeb? _instance;
  factory AxiomRuntimeWeb() => _instance ??= AxiomRuntimeWeb._internal();
  AxiomRuntimeWeb._internal();

  final _controllers = <int, StreamController<AxiomState<Uint8List>>>{};
  final _hadError = <int>{};
  int _nextRequestId = 1;
  late final WasmExports _wasm;

  @override
  bool debug = false;

  @override
  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  }) {
    final n = _alloc(namespace), m = _alloc(methodName), t = _alloc(token);
    _wasm.axiomSetAuthToken(n.ptr, n.len, m.ptr, m.len, t.ptr, t.len);
    _free(n);
    _free(m);
    _free(t);
  }

  @override
  void clearAuthToken({required String namespace, required String methodName}) {
    final n = _alloc(namespace), m = _alloc(methodName);
    _wasm.axiomClearAuthToken(n.ptr, n.len, m.ptr, m.len);
    _free(n);
    _free(m);
  }

  @override
  void sendStreamMessage({required int requestId, required Uint8List payload}) {
    final b = _allocBytes(payload);
    _wasm.axiomSendMsg(requestId.toJS, b.ptr, b.len);
    _free(b);
  }

  @override
  Future<void> init([String? dbPath]) async {
    if (globalContext.has('wasm_bindgen')) return;
    final jsCode = await rootBundle.loadString(
      'packages/axiom_flutter/lib/assets/wasm/axiom_runtime.js',
    );
    final script = web.HTMLScriptElement()
      ..type = 'application/javascript'
      ..text = '$jsCode\nwindow.wasm_bindgen = wasm_bindgen;';
    web.document.head!.appendChild(script);

    final wasmData = await rootBundle.load(
      'packages/axiom_flutter/lib/assets/wasm/axiom_runtime_bg.wasm',
    );
    _wasm =
        (await _wasmBindgenInit(wasmData.buffer.toJS).toDart) as WasmExports;
    _setupWebCallback();
    Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _wasm.axiomProcessResponses(),
    );

    final db = _alloc(dbPath ?? '');
    _wasm.axiomInitialize(db.ptr, db.len);
    _free(db);
  }

  void _setupWebCallback() {
    globalContext['axiom_web_callback'] =
        ((
              JSNumber reqId,
              JSNumber evtType,
              JSNumber errCode,
              JSNumber dPtr,
              JSNumber dLen,
              JSNumber ePtr,
              JSNumber eLen,
            ) {
              final id = reqId.toDartInt;
              final controller = _controllers[id];
              if (controller == null) return;

              if (evtType.toDartInt == EventType.complete) {
                _hadError.remove(id);
                if (!controller.isClosed) controller.close();
                _controllers.remove(id);
                return;
              }

              if (evtType.toDartInt == EventType.streamChunk) {
                Uint8List data = Uint8List.fromList(
                  Uint8List.view(
                    _wasm.memory.jsBuffer.toDart,
                    dPtr.toDartInt,
                    dLen.toDartInt,
                  ),
                );
                controller.add(
                  AxiomState.success(
                    data,
                    AxiomSource.network,
                    isStreaming: true,
                  ),
                );
                return;
              }

              if (evtType.toDartInt == EventType.error) {
                _hadError.add(id);
                String errJson = '';
                if (ePtr.toDartInt != 0) {
                  errJson = utf8.decode(
                    Uint8List.view(
                      _wasm.memory.jsBuffer.toDart,
                      ePtr.toDartInt,
                      eLen.toDartInt,
                    ),
                  );
                }
                final error = errJson.isNotEmpty
                    ? AxiomError.fromJson(jsonDecode(errJson))
                    : AxiomError(
                        stage: ErrorStage.runtime,
                        category: ErrorCategory.unknown,
                        code: UnknownCode(FfiError.name(errCode.toDartInt)),
                        message: 'Internal error',
                        retryable: false,
                      );
                controller.add(AxiomState.error(error));
                return;
              }

              if (dPtr.toDartInt != 0) {
                final data = Uint8List.fromList(
                  Uint8List.view(
                    _wasm.memory.jsBuffer.toDart,
                    dPtr.toDartInt,
                    dLen.toDartInt,
                  ),
                );
                controller.add(
                  AxiomState.success(
                    data,
                    (evtType.toDartInt == EventType.cacheHit ||
                            evtType.toDartInt == EventType.cacheHitAndFetching)
                        ? AxiomSource.cache
                        : AxiomSource.network,
                    isFetching:
                        evtType.toDartInt == EventType.cacheHitAndFetching,
                  ),
                );
              }
            })
            .toJS;
  }

  @override
  void loadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
    String? sha256,
  }) {
    if (sha256 != null) {
      throw UnimplementedError('loadContract(sha256:)');
    }
    final n = _alloc(namespace),
        b = _alloc(baseUrl),
        c = _allocBytes(contractBytes);
    final s = _alloc(signature ?? ''), p = _alloc(publicKey ?? '');
    final int status;
    try {
      status = _wasm.axiomLoadContract(
        n.ptr,
        n.len,
        b.ptr,
        b.len,
        c.ptr,
        c.len,
        s.ptr,
        s.len,
        p.ptr,
        p.len,
      );
    } finally {
      _free(n);
      _free(b);
      _free(c);
      _free(s);
      _free(p);
    }
    requireContractLoadStatus(status);
  }

  @override
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
  }) {
    final id = _nextRequestId++;
    final controller = StreamController<AxiomState<Uint8List>>.broadcast();
    _controllers[id] = controller;
    controller.add(AxiomState.loading());

    var fPath = path;
    pathParams?.forEach(
      (k, v) => fPath = fPath.replaceAll('{$k}', v.toString()),
    );

    if (queryParams != null && queryParams.isNotEmpty) {
      final filteredParams = <String, String>{};
      for (final entry in queryParams.entries) {
        if (entry.value != null)
          filteredParams[entry.key] = entry.value.toString();
      }
      if (filteredParams.isNotEmpty) {
        fPath +=
            (fPath.contains('?') ? '&' : '?') +
            Uri(queryParameters: filteredParams).query;
      }
    }

    final tp = AxiomTracing.generateTraceparent();
    final hStr = headers != null && headers.isNotEmpty
        ? jsonEncode(headers)
        : '';

    final n = _alloc(namespace),
        m = _alloc(method),
        p = _alloc(fPath),
        t = _alloc(tp),
        h = _alloc(hStr);
    final br = _allocBytes(requestBytes);

    _wasm.axiomCall(
      id.toJS,
      n.ptr,
      n.len,
      endpointId,
      m.ptr,
      m.len,
      p.ptr,
      p.len,
      t.ptr,
      t.len,
      h.ptr,
      h.len, // Passed to Wasm Rust successfully
      br.ptr,
      br.len,
    );

    _free(n);
    _free(m);
    _free(p);
    _free(t);
    _free(h);
    _free(br);
    return AxiomStreamResponse(id, controller.stream);
  }

  @override
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
  }) {
    final key = AxiomQueryKey.build(
      endpoint: '${namespace}_$endpointId',
      args: args,
    );

    // ✨ FIX: Return AxiomActiveStream by calling the QueryManager's new wrapper logic
    return AxiomQuery(key, (customHeaders) {
      final mergedHeaders = {...?headers, ...customHeaders};

      // We wrap the rawStream in a new AxiomActiveStream for AxiomQuery
      return AxiomQueryManager().watchRaw<T>(
        key,
        () => _rawStream(
          namespace: namespace,
          endpointId: endpointId,
          method: method,
          path: path,
          headers: mergedHeaders,
          pathParams: pathParams,
          queryParams: queryParams,
          body: body,
          decoder: decoder,
        ),
      );
    });
  }

  @override
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
  }) {
    final key =
        '${namespace}_${endpointId}_mut_${DateTime.now().microsecondsSinceEpoch}';
    return AxiomQuery(key, (customHeaders) {
      final mergedHeaders = {...?headers, ...customHeaders};
      return _rawStream(
        namespace: namespace,
        endpointId: endpointId,
        method: method,
        path: path,
        headers: mergedHeaders,
        pathParams: pathParams,
        queryParams: queryParams,
        body: body,
        decoder: decoder,
      );
    }, isMutation: true);
  }

  AxiomActiveStream<T> _rawStream<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
    AxiomCallOptions? options,
  }) {
    final response = callStream(
      namespace: namespace,
      endpointId: endpointId,
      method: method,
      path: path,
      headers: headers,
      pathParams: pathParams,
      queryParams: queryParams,
      requestBytes: AxiomCodec.encodeBody(body, headers),
    );

    final mappedStream = response.stream.map((state) {
      if (state.hasError) return state.map((_) => null as T);
      if (state.data != null) {
        try {
          return AxiomState<T>.success(
            AxiomCodec.decode(state.data!, decoder),
            state.source,
            isFetching: state.isFetching,
            isStreaming: state.isStreaming,
          );
        } catch (e) {
          return AxiomState<T>.error(
            AxiomError(
              stage: ErrorStage.deserialize,
              category: ErrorCategory.serialization,
              code: const CodecError(),
              message: e.toString(),
              retryable: false,
            ),
          );
        }
      }
      return state.map((_) => null as T);
    });

    return AxiomActiveStream<T>(response.requestId, mappedStream);
  }

  _WebAlloc _alloc(String s) => _allocBytes(Uint8List.fromList(utf8.encode(s)));
  _WebAlloc _allocBytes(Uint8List b) {
    final ptr = _wasm.axiomMalloc(b.length);
    Uint8List.view(_wasm.memory.jsBuffer.toDart, ptr, b.length).setAll(0, b);
    return _WebAlloc(ptr, b.length);
  }

  void _free(_WebAlloc a) => _wasm.axiomFreeMemory(a.ptr, a.len);

  @override
  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
    String? signature,
    String? publicKey,
  }) async {
    await init(dbPath);
    loadContract(
      namespace: 'default',
      baseUrl: baseUrl,
      contractBytes: contractBytes,
      signature: signature,
      publicKey: publicKey,
    );
  }

  // ---------------------------------------------------------------------------
  // Parity API (unit f1): signatures frozen, bodies implemented by later units.
  // ---------------------------------------------------------------------------

  @override
  Future<AxiomInitResult> initialize(
    AxiomConfig config, {
    AxiomAssetLoader? assetLoader,
  }) => throw UnimplementedError('initialize');

  @override
  bool get isInitialized => throw UnimplementedError('isInitialized');

  @override
  AxiomInitResult? get initResult => throw UnimplementedError('initResult');

  @override
  AxiomRuntimeInfo get runtimeInfo => throw UnimplementedError('runtimeInfo');

  @override
  AxiomContractLoadResult tryLoadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
    String? sha256,
  }) => throw UnimplementedError('tryLoadContract');

  @override
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
  }) => throw UnimplementedError('openChannel');

  @override
  void setNamespaceAuthToken({
    required String namespace,
    required String token,
  }) => throw UnimplementedError('setNamespaceAuthToken');

  @override
  void clearNamespaceAuthToken({required String namespace}) =>
      throw UnimplementedError('clearNamespaceAuthToken');

  @override
  void setGlobalAuthToken(String token) =>
      throw UnimplementedError('setGlobalAuthToken');

  @override
  void clearGlobalAuthToken() =>
      throw UnimplementedError('clearGlobalAuthToken');

  @override
  void setAuthProvider(AxiomAuthProvider? provider) =>
      throw UnimplementedError('setAuthProvider');

  @override
  bool cancel(int requestId) => throw UnimplementedError('cancel');

  @override
  Future<void> resetSession() => throw UnimplementedError('resetSession');

  @override
  Future<void> shutdown() => throw UnimplementedError('shutdown');

  @override
  void invalidate({
    required String namespace,
    String? cacheIdentity,
    int? endpointId,
    Map<String, dynamic>? args,
  }) => throw UnimplementedError('invalidate');

  @override
  void setQueryData<T>({
    required String namespace,
    required int endpointId,
    Map<String, dynamic> args = const {},
    required T data,
  }) => throw UnimplementedError('setQueryData');

  @override
  T? getCachedQueryData<T>({
    required String namespace,
    required int endpointId,
    Map<String, dynamic> args = const {},
  }) => throw UnimplementedError('getCachedQueryData');

  @override
  Future<void> clearCache([String? namespace]) =>
      throw UnimplementedError('clearCache');

  @override
  Future<void> purgeCache([String? namespace]) =>
      throw UnimplementedError('purgeCache');

  @override
  Stream<AxiomErrorEvent> get onError => throw UnimplementedError('onError');

  @override
  Future<void> loadExtension(AxiomExtensionPackage package) =>
      throw UnsupportedError('Axiom extensions are not supported on web');

  @override
  Future<Object?> invokeExtension(AxiomExtensionCall call) =>
      throw UnsupportedError('Axiom extensions are not supported on web');

  @override
  void extensionLifecycle(AxiomLifecycleEvent event) =>
      throw UnsupportedError('Axiom extensions are not supported on web');

  @override
  Future<Object?> extensionAudit() =>
      throw UnsupportedError('Axiom extensions are not supported on web');
}

class _WebAlloc {
  final int ptr, len;
  _WebAlloc(this.ptr, this.len);
}
