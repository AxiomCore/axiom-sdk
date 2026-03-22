import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ansicolor/ansicolor.dart';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

import 'runtime_interface.dart';
import 'state.dart';
import 'query.dart';
import 'query_manager.dart';
import 'internal/axiom_codec.dart';
import 'internal/query_key.dart';

AxiomRuntime getRuntime() => AxiomRuntimeIo();

base class AxiomString extends Struct {
  external Pointer<Uint8> ptr;
  @Uint64()
  external int len;
}

base class AxiomBuffer extends Struct {
  external Pointer<Uint8> ptr;
  @Uint64()
  external int len;
}

base class AxiomResponseBuffer extends Struct {
  @Uint64()
  external int requestId;
  @Int32()
  external int eventType;
  @Int32()
  external int errorCode;
  external AxiomBuffer data;
  external AxiomBuffer errorMessage;
}

typedef AxiomCallback = Void Function(Pointer<AxiomResponseBuffer> response);

typedef _AxiomInitializeNative = Int32 Function(AxiomString);
typedef _AxiomInitialize = int Function(AxiomString);

typedef _AxiomLoadContractNative =
    Int32 Function(
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomString,
      AxiomString,
    );
typedef _AxiomLoadContract =
    int Function(
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomString,
      AxiomString,
    );

typedef _AxiomRegisterCallbackNative =
    Void Function(Pointer<NativeFunction<AxiomCallback>>);
typedef _AxiomRegisterCallback =
    void Function(Pointer<NativeFunction<AxiomCallback>>);

typedef _AxiomCallNative =
    Void Function(
      Uint64,
      AxiomString,
      Uint32,
      AxiomString,
      AxiomString,
      AxiomBuffer,
    );
typedef _AxiomCall =
    void Function(int, AxiomString, int, AxiomString, AxiomString, AxiomBuffer);

typedef _AxiomFreeBufferNative = Void Function(AxiomBuffer);
typedef _AxiomFreeBuffer = void Function(AxiomBuffer);

typedef _AxiomProcessResponsesNative = Void Function();
typedef _AxiomProcessResponses = void Function();

typedef _AxiomFreeResponseBufferNative =
    Void Function(Pointer<AxiomResponseBuffer>);
typedef _AxiomFreeResponseBuffer = void Function(Pointer<AxiomResponseBuffer>);

final _controllers = HashMap<int, StreamController<AxiomState<Uint8List>>>();
int _nextRequestId = 1;
SendPort? _commandPort;
Completer<void>? _initCompleter;
SendPort? _dataPort;
_AxiomFreeResponseBuffer? _freeResponseFfiBackground;

@pragma('vm:entry-point')
void _axiomCallbackHandler(Pointer<AxiomResponseBuffer> responsePtr) {
  if (responsePtr == nullptr) return;
  final response = responsePtr.ref;
  _dataPort?.send([
    response.requestId,
    response.eventType,
    response.errorCode,
    response.data.ptr.address,
    response.data.len,
    response.errorMessage.ptr.address,
    response.errorMessage.len,
  ]);
  _freeResponseFfiBackground?.call(responsePtr);
}

@pragma('vm:entry-point')
void _runRustEventLoop(List<Object> args) {
  final mainIsolateDataPort = args[0] as SendPort;
  final shutdownPort = ReceivePort();
  mainIsolateDataPort.send(shutdownPort.sendPort);
  _dataPort = mainIsolateDataPort;

  final lib = AxiomRuntimeIo._openPlatformLibrary();
  _freeResponseFfiBackground = lib
      .lookupFunction<_AxiomFreeResponseBufferNative, _AxiomFreeResponseBuffer>(
        'axiom_free_response_buffer',
      );
  final registerCallback = lib
      .lookupFunction<_AxiomRegisterCallbackNative, _AxiomRegisterCallback>(
        'axiom_register_callback',
      );
  registerCallback(Pointer.fromFunction(_axiomCallbackHandler));

  final processResponses = lib
      .lookupFunction<_AxiomProcessResponsesNative, _AxiomProcessResponses>(
        'axiom_process_responses',
      );

  shutdownPort.listen((msg) {
    if (msg == 'shutdown') {
      shutdownPort.close();
      Isolate.current.kill();
    }
  });

  while (true) {
    processResponses();
    sleep(const Duration(milliseconds: 5));
  }
}

class AxiomRuntimeIo implements AxiomRuntime {
  static AxiomRuntimeIo? _instance;
  factory AxiomRuntimeIo() => _instance ??= AxiomRuntimeIo._internal();

  static late final DynamicLibrary _lib;
  late final _AxiomInitialize _initFfi;
  late final _AxiomLoadContract _loadContractFfi;
  late final _AxiomCall _callFfi;
  static late final _AxiomFreeBuffer _freeFfi;

  AxiomRuntimeIo._internal() {
    _lib = _openPlatformLibrary();
    _initFfi = _lib.lookupFunction<_AxiomInitializeNative, _AxiomInitialize>(
      'axiom_initialize',
    );
    _loadContractFfi = _lib
        .lookupFunction<_AxiomLoadContractNative, _AxiomLoadContract>(
          'axiom_load_contract',
        );
    _callFfi = _lib.lookupFunction<_AxiomCallNative, _AxiomCall>('axiom_call');
    _freeFfi = _lib.lookupFunction<_AxiomFreeBufferNative, _AxiomFreeBuffer>(
      'axiom_free_buffer',
    );
  }

  @override
  bool debug = false;

  void _logTransaction(String direction, int reqId, dynamic details) {
    if (!debug) return;
    final pen = AnsiPen()..white(bold: true);
    if (direction == 'OUT')
      pen.xterm(063);
    else
      pen.xterm(034);
    print(
      pen('${direction == 'OUT' ? '➔ WASM CALL' : '← WASM RESP'} [#$reqId]'),
    );
    print(details);
  }

  @override
  Future<void> init([String? dbPath]) async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    final mainIsolatePort = ReceivePort();

    mainIsolatePort.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
        _initCompleter!.complete();
        return;
      }

      final int requestId = message[0];
      final int eventTypeValue = message[1];
      final int errorCodeValue = message[2];
      final int dataPtr = message[3];
      final int dataLen = message[4];
      final int errorPtr = message[5];
      final int errorLen = message[6];

      final controller = _controllers[requestId];

      _logTransaction('IN', requestId, {
        'eventType': eventTypeValue,
        'errorCode': errorCodeValue,
        'hasData': dataPtr != 0,
      });

      if (controller == null || controller.isClosed) return;

      if (eventTypeValue == EventType.complete) {
        controller.close();
        _controllers.remove(requestId);
        return;
      }

      if (eventTypeValue == EventType.error) {
        AxiomError richError;
        if (errorPtr != 0) {
          final jsonStr = utf8.decode(
            Pointer<Uint8>.fromAddress(errorPtr).asTypedList(errorLen),
          );
          richError = AxiomError.fromJson(jsonDecode(jsonStr));
        } else {
          richError = AxiomError(
            stage: ErrorStage.runtime,
            category: ErrorCategory.unknown,
            code: UnknownCode(FfiError.name(errorCodeValue)),
            message: "Unknown internal error",
            retryable: false,
          );
        }
        controller.add(AxiomState.error(richError));
        return;
      }

      if (dataPtr != 0) {
        final data = Uint8List.fromList(
          Pointer<Uint8>.fromAddress(dataPtr).asTypedList(dataLen),
        );
        controller.add(
          AxiomState.success(
            data,
            (eventTypeValue == EventType.cacheHit ||
                    eventTypeValue == EventType.cacheHitAndFetching)
                ? AxiomSource.cache
                : AxiomSource.network,
            isFetching: eventTypeValue == EventType.cacheHitAndFetching,
          ),
        );
      }
    });

    await Isolate.spawn(_runRustEventLoop, [mainIsolatePort.sendPort]);

    // Call Rust Init
    using((Arena arena) {
      final dbStr = _toAxiomString(dbPath ?? "", arena);
      _initFfi(dbStr);
    });

    return _initCompleter!.future;
  }

  AxiomString _toAxiomString(String s, Arena arena) {
    final units = utf8.encode(s);
    final ptr = arena<Uint8>(units.length);
    ptr.asTypedList(units.length).setAll(0, units);
    final axStr = arena<AxiomString>();
    axStr.ref
      ..ptr = ptr
      ..len = units.length;
    return axStr.ref;
  }

  @override
  void loadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
  }) {
    using((Arena arena) {
      final ns = _toAxiomString(namespace, arena);
      final url = _toAxiomString(baseUrl, arena);
      final sig = _toAxiomString(signature ?? "", arena);
      final pk = _toAxiomString(publicKey ?? "", arena);

      final cPtr = arena<Uint8>(contractBytes.length);
      cPtr.asTypedList(contractBytes.length).setAll(0, contractBytes);
      final buf = arena<AxiomBuffer>()
        ..ref.ptr = cPtr
        ..ref.len = contractBytes.length;

      final result = _loadContractFfi(ns, url, buf.ref, sig, pk);
      if (result == FfiError.successUnverified)
        _printSecurityWarning();
      else if (result != FfiError.success)
        throw Exception('Failed to load contract: ${FfiError.name(result)}');
    });
  }

  // FILE: lib/src/runtime_io.dart

  @override
  Stream<AxiomState<Uint8List>> callStream({
    required String namespace,
    required int endpointId,
    required String method,
    required String path,
    required Uint8List requestBytes,
  }) {
    final requestId = _nextRequestId++;

    // FIX: Must be a broadcast stream so multiple widgets can listen to the same FFI call!
    final controller = StreamController<AxiomState<Uint8List>>.broadcast();

    _controllers[requestId] = controller;
    controller.add(AxiomState.loading());

    _logTransaction('OUT', requestId, {
      'ns': namespace,
      'ep': endpointId,
      'm': method,
      'p': path,
    });

    final arena = Arena();
    final ns = _toAxiomString(namespace, arena);
    final m = _toAxiomString(method, arena);
    final p = _toAxiomString(path, arena);
    final bPtr = arena<Uint8>(requestBytes.length);
    bPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);
    final b = arena<AxiomBuffer>()
      ..ref.ptr = bPtr
      ..ref.len = requestBytes.length;

    _callFfi(requestId, ns, endpointId, m, p, b.ref);
    Future.microtask(() => arena.releaseAll());

    controller.onCancel = () {
      // For broadcast streams, onCancel fires when the LAST listener detaches.
      _controllers.remove(requestId);
    };

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
    // 1. Build a deterministic cache key using the namespace and arguments
    final endpointKey = '${namespace}_endpoint_$endpointId';
    final queryKey = AxiomQueryKey.build(endpoint: endpointKey, args: args);

    // 2. Watch the stream (this deduplicates network calls automatically)
    final stream = AxiomQueryManager().watch<T>(queryKey, () {
      var finalPath = path;

      // 3. INTERPOLATE PATH PARAMETERS (This fixes the 422 error!)
      if (pathParams != null) {
        pathParams.forEach((key, value) {
          finalPath = finalPath.replaceAll('{$key}', value.toString());
        });
      }

      // 4. APPEND QUERY PARAMETERS
      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri(
          queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString())),
        );
        final separator = finalPath.contains('?') ? '&' : '?';
        finalPath += '$separator${uri.query}';
      }

      final requestBytes = AxiomCodec.encodeBody(body);

      // 5. CALL THE RUST ENGINE
      return callStream(
        namespace: namespace,
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

  static DynamicLibrary _openPlatformLibrary() =>
      Platform.isIOS || Platform.isMacOS
      ? DynamicLibrary.process()
      : DynamicLibrary.open('libaxiom_runtime.so');
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
