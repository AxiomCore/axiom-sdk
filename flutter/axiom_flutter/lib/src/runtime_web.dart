import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:ansicolor/ansicolor.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

import 'runtime_interface.dart';
import 'state.dart';
import 'query.dart';
import 'query_manager.dart';
import 'channel.dart';
import 'internal/axiom_codec.dart';
import 'internal/query_key.dart';
import 'internal/tracing.dart';

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
    int bPtr,
    int bLen,
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
    final n = _alloc(namespace);
    final m = _alloc(methodName);
    final t = _alloc(token);
    _wasm.axiomSetAuthToken(n.ptr, n.len, m.ptr, m.len, t.ptr, t.len);
    _free(n);
    _free(m);
    _free(t);
  }

  @override
  void clearAuthToken({required String namespace, required String methodName}) {
    final n = _alloc(namespace);
    final m = _alloc(methodName);
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
    final db = _alloc(dbPath ?? "");
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
              Uint8List? data;
              if (dPtr.toDartInt != 0)
                data = Uint8List.fromList(
                  Uint8List.view(
                    _wasm.memory.jsBuffer.toDart,
                    dPtr.toDartInt,
                    dLen.toDartInt,
                  ),
                );
              if (evtType.toDartInt == EventType.complete) {
                controller.close();
                _controllers.remove(id);
                return;
              }
              if (evtType.toDartInt == EventType.streamChunk) {
                controller.add(
                  AxiomState.success(
                    data!,
                    AxiomSource.network,
                    isStreaming: true,
                  ),
                );
                return;
              }
              if (evtType.toDartInt == EventType.error) {
                final errJson = utf8.decode(
                  Uint8List.view(
                    _wasm.memory.jsBuffer.toDart,
                    ePtr.toDartInt,
                    eLen.toDartInt,
                  ),
                );
                controller.add(
                  AxiomState.error(AxiomError.fromJson(jsonDecode(errJson))),
                );
                return;
              }
              controller.add(
                AxiomState.success(
                  data!,
                  (evtType.toDartInt == EventType.cacheHit ||
                          evtType.toDartInt == EventType.cacheHitAndFetching)
                      ? AxiomSource.cache
                      : AxiomSource.network,
                  isFetching:
                      evtType.toDartInt == EventType.cacheHitAndFetching,
                ),
              );
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
  }) {
    final n = _alloc(namespace);
    final b = _alloc(baseUrl);
    final c = _allocBytes(contractBytes);
    final s = _alloc(signature ?? "");
    final p = _alloc(publicKey ?? "");
    _wasm.axiomLoadContract(
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
    _free(n);
    _free(b);
    _free(c);
    _free(s);
    _free(p);
  }

  @override
  AxiomStreamResponse callStream({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    required Uint8List requestBytes,
  }) {
    final id = _nextRequestId++;
    final controller = StreamController<AxiomState<Uint8List>>.broadcast();
    _controllers[id] = controller;
    controller.add(AxiomState.loading());
    var fPath = path;
    pathParams?.forEach(
      (k, v) => fPath = fPath.replaceAll('{$k}', v.toString()),
    );
    if (queryParams?.isNotEmpty ?? false)
      fPath +=
          (fPath.contains('?') ? '&' : '?') +
          Uri(
            queryParameters: queryParams!.map(
              (k, v) => MapEntry(k, v.toString()),
            ),
          ).query;
    final tp = AxiomTracing.generateTraceparent();
    final n = _alloc(namespace);
    final m = _alloc(method);
    final p = _alloc(fPath);
    final t = _alloc(tp);
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
      br.ptr,
      br.len,
    );
    _free(n);
    _free(m);
    _free(p);
    _free(t);
    _free(br);
    return AxiomStreamResponse(id, controller.stream);
  }

  @override
  AxiomQuery<T> send<T>({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    Map<String, dynamic> args = const {},
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
  }) {
    final key = AxiomQueryKey.build(
      endpoint: '${namespace}_$endpointId',
      args: args,
    );
    return AxiomQuery(
      key,
      AxiomQueryManager().watch<T>(
        key,
        () =>
            callStream(
              namespace: namespace,
              endpointId: endpointId,
              method: method,
              path: path,
              pathParams: pathParams,
              queryParams: queryParams,
              requestBytes: AxiomCodec.encodeBody(body),
            ).stream.map((state) {
              if (state.data != null)
                return AxiomState.success(
                  AxiomCodec.decode(state.data!, decoder),
                  state.source,
                  isFetching: state.isFetching,
                  isStreaming: state.isStreaming,
                );
              return state.map((_) => null as T);
            }),
      ),
    );
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
}

class _WebAlloc {
  final int ptr;
  final int len;
  _WebAlloc(this.ptr, this.len);
}
