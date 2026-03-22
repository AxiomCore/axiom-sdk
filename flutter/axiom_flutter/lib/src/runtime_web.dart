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
import 'internal/axiom_codec.dart';
import 'internal/query_key.dart';

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
    int bPtr,
    int bLen,
  );

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
  Timer? _pollTimer;
  late final WasmExports _wasm;

  @override
  bool debug = false;

  @override
  Future<void> init([String? dbPath]) async {
    if (globalContext.has('wasm_bindgen')) return;

    try {
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

      final jsArrayBuffer = wasmData.buffer.toJS;
      final jsInstance = await _wasmBindgenInit(jsArrayBuffer).toDart;
      _wasm = jsInstance as WasmExports;

      _setupWebCallback();

      _pollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
        _wasm.axiomProcessResponses();
      });

      // Initialize the core engine once
      final dbLen = <int>[0];
      final dbPtr = _allocString(dbPath ?? "", dbLen);
      _wasm.axiomInitialize(dbPtr, dbLen[0]);
      _wasm.axiomFreeMemory(dbPtr, dbLen[0]);
    } catch (e) {
      throw Exception(
        'Axiom Web Runtime failed to initialize.\nInner error: $e',
      );
    }
  }

  void _logTransaction(String direction, int reqId, dynamic details) {
    if (!debug) return;
    final pen = AnsiPen()..white(bold: true);
    if (direction == 'OUT')
      pen.xterm(063);
    else
      pen.xterm(034);
    final prefix = direction == 'OUT' ? '➔ WASM CALL' : '← WASM RESP';
    print(pen('$prefix [#$reqId]'));
    print(details);
  }

  void _setupWebCallback() {
    globalContext['axiom_web_callback'] =
        ((
              JSNumber reqId,
              JSNumber eventTypeObj,
              JSNumber errorCodeObj,
              JSNumber dataPtrObj,
              JSNumber dataLenObj,
              JSNumber errorPtrObj,
              JSNumber errorLenObj,
            ) {
              final requestId = reqId.toDartInt;
              final eventType = eventTypeObj.toDartInt;
              final errorCode = errorCodeObj.toDartInt;
              final dataPtr = dataPtrObj.toDartInt;
              final dataLen = dataLenObj.toDartInt;
              final errorPtr = errorPtrObj.toDartInt;
              final errorLen = errorLenObj.toDartInt;

              final controller = _controllers[requestId];

              Uint8List? dataBytes;
              if (dataPtr != 0 && dataLen > 0) {
                final view = Uint8List.view(
                  _wasm.memory.jsBuffer.toDart,
                  dataPtr,
                  dataLen,
                );
                dataBytes = Uint8List.fromList(view);
                _wasm.axiomFreeMemory(dataPtr, dataLen);
              }

              String? errorJson;
              if (errorPtr != 0 && errorLen > 0) {
                final view = Uint8List.view(
                  _wasm.memory.jsBuffer.toDart,
                  errorPtr,
                  errorLen,
                );
                errorJson = utf8.decode(Uint8List.fromList(view));
                _wasm.axiomFreeMemory(errorPtr, errorLen);
              }

              final evtName = eventType == EventType.networkSuccess
                  ? 'NetworkSuccess'
                  : eventType == EventType.cacheHit
                  ? 'CacheHit'
                  : eventType == EventType.cacheHitAndFetching
                  ? 'CacheHitAndFetching'
                  : eventType == EventType.error
                  ? 'Error'
                  : 'Complete';

              _logTransaction('IN', requestId, {
                'eventType': evtName,
                'hasData': dataBytes != null,
                'hasError': errorJson != null,
              });

              if (controller == null || controller.isClosed) return;

              if (eventType == EventType.complete) {
                controller.close();
                _controllers.remove(requestId);
                return;
              }

              if (eventType == EventType.error) {
                AxiomError richError = errorJson != null
                    ? AxiomError.fromJson(jsonDecode(errorJson))
                    : AxiomError(
                        stage: ErrorStage.runtime,
                        category: ErrorCategory.unknown,
                        code: UnknownCode(FfiError.name(errorCode)),
                        message: "Internal Wasm error",
                        retryable: false,
                      );
                controller.add(AxiomState.error(richError));
                return;
              }

              if (dataBytes != null) {
                final source =
                    (eventType == EventType.cacheHit ||
                        eventType == EventType.cacheHitAndFetching)
                    ? AxiomSource.cache
                    : AxiomSource.network;
                controller.add(
                  AxiomState.success(
                    dataBytes,
                    source,
                    isFetching: eventType == EventType.cacheHitAndFetching,
                  ),
                );
              }
            })
            .toJS;
  }

  int _allocString(String str, List<int> outLen) {
    if (str.isEmpty) {
      outLen[0] = 0;
      return 0;
    }
    final bytes = utf8.encode(str);
    final ptr = _wasm.axiomMalloc(bytes.length);
    outLen[0] = bytes.length;
    Uint8List.view(
      _wasm.memory.jsBuffer.toDart,
      ptr,
      bytes.length,
    ).setAll(0, bytes);
    return ptr;
  }

  int _allocBytes(Uint8List bytes) {
    if (bytes.isEmpty) return 0;
    final ptr = _wasm.axiomMalloc(bytes.length);
    Uint8List.view(
      _wasm.memory.jsBuffer.toDart,
      ptr,
      bytes.length,
    ).setAll(0, bytes);
    return ptr;
  }

  @override
  void loadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
  }) {
    final nsLen = <int>[0];
    final nsPtr = _allocString(namespace, nsLen);
    final bLen = <int>[0];
    final bPtr = _allocString(baseUrl, bLen);
    final cPtr = _allocBytes(contractBytes);
    final sLen = <int>[0];
    final sPtr = signature != null ? _allocString(signature, sLen) : 0;
    final pkLen = <int>[0];
    final pkPtr = publicKey != null ? _allocString(publicKey, pkLen) : 0;

    final result = _wasm.axiomLoadContract(
      nsPtr,
      nsLen[0],
      bPtr,
      bLen[0],
      cPtr,
      contractBytes.length,
      sPtr,
      sLen[0],
      pkPtr,
      pkLen[0],
    );

    _wasm.axiomFreeMemory(nsPtr, nsLen[0]);
    _wasm.axiomFreeMemory(bPtr, bLen[0]);
    _wasm.axiomFreeMemory(cPtr, contractBytes.length);
    if (sPtr != 0) _wasm.axiomFreeMemory(sPtr, sLen[0]);
    if (pkPtr != 0) _wasm.axiomFreeMemory(pkPtr, pkLen[0]);

    if (result == FfiError.successUnverified)
      _printSecurityWarning();
    else if (result != FfiError.success)
      throw Exception(
        'Failed to load Axiom contract. Error: ${FfiError.name(result)}',
      );
  }

  @override
  Stream<AxiomState<Uint8List>> callStream({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    required Uint8List requestBytes,
  }) {
    final requestId = _nextRequestId++;

    // FIX: Must be a broadcast stream!
    final controller = StreamController<AxiomState<Uint8List>>.broadcast();

    _controllers[requestId] = controller;
    controller.add(AxiomState.loading());

    final nsLen = <int>[0];
    final nsPtr = _allocString(namespace, nsLen);
    final mLen = <int>[0];
    final mPtr = _allocString(method, mLen);
    final pLen = <int>[0];
    final pPtr = _allocString(path, pLen);
    final bPtr = _allocBytes(requestBytes);

    _logTransaction('OUT', requestId, {
      'namespace': namespace,
      'endpointId': endpointId,
      'method': method,
      'path': path,
    });

    _wasm.axiomCall(
      requestId.toJS,
      nsPtr,
      nsLen[0],
      endpointId,
      mPtr,
      mLen[0],
      pPtr,
      pLen[0],
      bPtr,
      requestBytes.length,
    );

    _wasm.axiomFreeMemory(nsPtr, nsLen[0]);
    _wasm.axiomFreeMemory(mPtr, mLen[0]);
    _wasm.axiomFreeMemory(pPtr, pLen[0]);
    _wasm.axiomFreeMemory(bPtr, requestBytes.length);

    controller.onCancel = () => _controllers.remove(requestId);
    return controller.stream;
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
    final queryKey = '$namespace:endpoint_$endpointId:${jsonEncode(args)}';
    final stream = AxiomQueryManager().watch<T>(queryKey, () {
      var finalPath = path;
      pathParams?.forEach(
        (k, v) => finalPath = finalPath.replaceAll('{$k}', v.toString()),
      );
      if (queryParams?.isNotEmpty ?? false) {
        final uri = Uri(
          queryParameters: queryParams!.map(
            (k, v) => MapEntry(k, v.toString()),
          ),
        );
        finalPath += (finalPath.contains('?') ? '&' : '?') + uri.query;
      }
      return callStream(
        namespace: namespace,
        endpointId: endpointId,
        method: method,
        path: finalPath,
        requestBytes: AxiomCodec.encodeBody(body),
      ).map((state) {
        if (state.hasError) return state.map((_) => null as T);
        if (state.data != null) {
          try {
            return AxiomState.success(
              AxiomCodec.decode(state.data!, decoder),
              state.source,
              isFetching: state.isFetching,
            );
          } catch (e) {
            return AxiomState.error(
              AxiomError(
                stage: ErrorStage.deserialize,
                category: ErrorCategory.serialization,
                code: const CodecError(),
                message: "Failed to decode: $e",
                retryable: false,
                details: e.toString(),
              ),
            );
          }
        }
        return state.map((_) => null as T);
      });
    });
    return AxiomQuery(queryKey, stream);
  }

  void _printSecurityWarning() {
    final warningPen = AnsiPen()..yellow();
    print('');
    print(
      warningPen(
        '┌────────────────────────────────────────────────────────────┐',
      ),
    );
    print(
      warningPen(
        '│ ⚠️  AXIOM SECURITY WARNING                                 │',
      ),
    );
    print(
      warningPen(
        '├────────────────────────────────────────────────────────────┤',
      ),
    );
    print(
      warningPen(
        '│ You are loading an UNVERIFIED contract.                    │',
      ),
    );
    print(
      warningPen(
        '│ Unsigned contracts skip cryptographic integrity checks     │',
      ),
    );
    print(
      warningPen(
        '│ and could potentially execute malicious logic.             │',
      ),
    );
    print(
      warningPen(
        '│                                                            │',
      ),
    );
    print(
      warningPen(
        '│ Learn more about the risks and how to sign contracts:      │',
      ),
    );
    print(
      warningPen(
        '│ https://docs.axiomcore.dev/cloud-security/signed-contracts │',
      ),
    );
    print(
      warningPen(
        '└────────────────────────────────────────────────────────────┘',
      ),
    );
    print('');
  }

  @override
  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
    String? signature,
    String? publicKey,
  }) async {
    // Legacy support: redirects to modern multi-contract load
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
