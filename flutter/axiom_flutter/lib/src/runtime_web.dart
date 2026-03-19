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
  external int axiomInitialize(int urlPtr, int urlLen, int dbPtr, int dbLen);

  @JS('axiom_wasm_load_contract')
  external int axiomLoadContract(
    int contractPtr,
    int contractLen,
    int sigPtr,
    int sigLen,
    int pkPtr,
    int pkLen,
  );

  @JS('axiom_wasm_call')
  external void axiomCall(
    JSNumber reqId,
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
  Future<void> init() async {
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
    } catch (e) {
      throw Exception(
        'Axiom Web Runtime failed to initialize.\nInner error: $e',
      );
    }
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

              if (controller == null || controller.isClosed) return;

              if (eventType == EventType.complete) {
                controller.close();
                _controllers.remove(requestId);
                return;
              }

              if (eventType == EventType.error) {
                AxiomError richError;
                if (errorJson != null) {
                  try {
                    richError = AxiomError.fromJson(jsonDecode(errorJson));
                  } catch (e) {
                    richError = AxiomError(
                      stage: ErrorStage.ffiBoundary,
                      category: ErrorCategory.runtime,
                      code: const UnknownCode("JsonParseFailure"),
                      message: "Failed to parse: $e",
                      retryable: false,
                    );
                  }
                } else {
                  richError = AxiomError(
                    stage: ErrorStage.runtime,
                    category: ErrorCategory.unknown,
                    code: UnknownCode(FfiError.name(errorCode)),
                    message: "Internal Wasm error",
                    retryable: false,
                  );
                }
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
  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
    String? signature,
    String? publicKey,
  }) async {
    final urlLen = <int>[0];
    final urlPtr = _allocString(baseUrl, urlLen);

    final dbLen = <int>[0];
    final dbPtr = _allocString(dbPath ?? "", dbLen);

    final result = _wasm.axiomInitialize(urlPtr, urlLen[0], dbPtr, dbLen[0]);

    // PREVENT MEMORY LEAK
    _wasm.axiomFreeMemory(urlPtr, urlLen[0]);
    _wasm.axiomFreeMemory(dbPtr, dbLen[0]);

    if (result != FfiError.success) {
      throw Exception('Failed to initialize runtime. Error code: $result');
    }

    loadContract(contractBytes, signature, publicKey);
  }

  @override
  void loadContract(
    Uint8List contractBytes,
    String? signature,
    String? publicKey,
  ) {
    final contractPtr = _allocBytes(contractBytes);

    final sigLen = <int>[0];
    final sigPtr = signature != null ? _allocString(signature, sigLen) : 0;

    final pkLen = <int>[0];
    final pkPtr = publicKey != null ? _allocString(publicKey, pkLen) : 0;

    final result = _wasm.axiomLoadContract(
      contractPtr,
      contractBytes.length,
      sigPtr,
      sigLen[0],
      pkPtr,
      pkLen[0],
    );

    // PREVENT MEMORY LEAK
    _wasm.axiomFreeMemory(contractPtr, contractBytes.length);
    if (sigPtr != 0) _wasm.axiomFreeMemory(sigPtr, sigLen[0]);
    if (pkPtr != 0) _wasm.axiomFreeMemory(pkPtr, pkLen[0]);

    if (result == FfiError.successUnverified) {
      _printSecurityWarning();
      return;
    }

    if (result != FfiError.success) {
      throw Exception(
        'Failed to load Axiom contract. Error: ${FfiError.name(result)}',
      );
    }
  }

  @override
  Stream<AxiomState<Uint8List>> callStream({
    required int endpointId,
    required String method,
    required String path,
    required Uint8List requestBytes,
  }) {
    final requestId = _nextRequestId++;
    final controller = StreamController<AxiomState<Uint8List>>();
    _controllers[requestId] = controller;

    controller.add(AxiomState.loading());

    final mLen = <int>[0];
    final mPtr = _allocString(method, mLen);

    final pLen = <int>[0];
    final pPtr = _allocString(path, pLen);

    final bPtr = _allocBytes(requestBytes);

    _wasm.axiomCall(
      requestId.toJS,
      endpointId,
      mPtr,
      mLen[0],
      pPtr,
      pLen[0],
      bPtr,
      requestBytes.length,
    );

    // PREVENT MEMORY LEAK
    _wasm.axiomFreeMemory(mPtr, mLen[0]);
    _wasm.axiomFreeMemory(pPtr, pLen[0]);
    _wasm.axiomFreeMemory(bPtr, requestBytes.length);

    controller.onCancel = () {
      _controllers.remove(requestId);
    };

    return controller.stream;
  }

  @override
  AxiomQuery<T> send<T>({
    required int endpointId,
    required String method,
    required String path,
    Map<String, dynamic> args = const {},
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Object? body,
    required T Function(dynamic json) decoder,
  }) {
    // Exact same send implementation as before
    final endpointKey = 'endpoint_$endpointId';
    final queryKey = AxiomQueryKey.build(endpoint: endpointKey, args: args);

    final stream = AxiomQueryManager().watch<T>(queryKey, () {
      var finalPath = path;
      if (pathParams != null) {
        pathParams.forEach((key, value) {
          finalPath = finalPath.replaceAll('{$key}', value.toString());
        });
      }

      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri(
          queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
        );
        final separator = finalPath.contains('?') ? '&' : '?';
        finalPath += '$separator${uri.query}';
      }

      final requestBytes = AxiomCodec.encodeBody(body);

      return callStream(
        endpointId: endpointId,
        method: method,
        path: finalPath,
        requestBytes: requestBytes,
      ).map((state) {
        if (state.hasError) return state.map((_) => null as T);
        if (state.data != null) {
          try {
            final decodedData = AxiomCodec.decode(state.data!, decoder);
            return AxiomState.success(
              decodedData,
              state.source,
              isFetching: state.isFetching,
            );
          } catch (e) {
            return AxiomState.error(
              AxiomError(
                stage: ErrorStage.deserialize,
                category: ErrorCategory.serialization,
                code: const CodecError(),
                message: "Failed to decode response: $e",
                retryable: false,
                details: e.toString(),
              ),
              previousData: null,
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
}
