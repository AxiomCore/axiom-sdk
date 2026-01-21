import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

import 'state.dart';
export 'state.dart';

// --- FFI Structs (must match Rust) ---

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

class EventType {
  static const int complete = 0;
  static const int networkSuccess = 1;
  static const int cacheHit = 2;
  static const int cacheHitAndFetching = 3;
  static const int error = 4;
}

class FfiError {
  static const int success = 0;
  static const int unknownError = 1;
  static const int requestParsingFailed = 2;
  static const int networkError = 3;
  static const int responseDeserializationFailed = 4;
  static const int unknownEndpoint = 5;
  static const int invalidContract = 10;
  static const int runtimeTooOld = 11;
  static const int contractNotLoaded = 12;
  static const int initializationFailed = 13;
  static const int internalError = 14;

  static String name(int code) {
    switch (code) {
      case success:
        return 'success';
      case unknownError:
        return 'unknownError';
      case requestParsingFailed:
        return 'requestParsingFailed';
      case networkError:
        return 'networkError';
      case responseDeserializationFailed:
        return 'responseDeserializationFailed';
      case unknownEndpoint:
        return 'unknownEndpoint';
      case invalidContract:
        return 'invalidContract';
      case runtimeTooOld:
        return 'runtimeTooOld';
      case contractNotLoaded:
        return 'contractNotLoaded';
      case initializationFailed:
        return 'initializationFailed';
      case internalError:
        return 'internalError';
      default:
        return 'unrecognizedErrorCode';
    }
  }
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

// --- FFI Function Signatures ---
typedef AxiomCallback = Void Function(Pointer<AxiomResponseBuffer> response);

typedef _AxiomInitializeNative = Int32 Function(AxiomString, AxiomString);
typedef _AxiomInitialize = int Function(AxiomString, AxiomString);

typedef _AxiomLoadContractNative = Int32 Function(AxiomBuffer);
typedef _AxiomLoadContract = int Function(AxiomBuffer);

typedef _AxiomRegisterCallbackNative =
    Void Function(Pointer<NativeFunction<AxiomCallback>>);
typedef _AxiomRegisterCallback =
    void Function(Pointer<NativeFunction<AxiomCallback>>);

typedef _AxiomCallNative =
    Void Function(Uint64, Uint32, AxiomString, AxiomString, AxiomBuffer);
typedef _AxiomCall =
    void Function(int, int, AxiomString, AxiomString, AxiomBuffer);

typedef _AxiomFreeBufferNative = Void Function(AxiomBuffer);
typedef _AxiomFreeBuffer = void Function(AxiomBuffer);

typedef _AxiomProcessResponsesNative = Void Function();
typedef _AxiomProcessResponses = void Function();

typedef _AxiomFreeResponseBufferNative =
    Void Function(Pointer<AxiomResponseBuffer>);
typedef _AxiomFreeResponseBuffer = void Function(Pointer<AxiomResponseBuffer>);

// --- Global state for managing async callbacks ---
final _controllers = HashMap<int, StreamController<AxiomState<Uint8List>>>();
int _nextRequestId = 1;
SendPort? _commandPort;
Completer<void>? _initCompleter;
SendPort? _dataPort;

// This holds the `free` function pointer for the background isolate to use.
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

  // The background isolate calls the free function it looked up.
  _freeResponseFfiBackground?.call(responsePtr);
}

@pragma('vm:entry-point')
void _runRustEventLoop(List<Object> args) {
  final mainIsolateDataPort = args[0] as SendPort;
  final shutdownPort = ReceivePort();
  mainIsolateDataPort.send(shutdownPort.sendPort);
  _dataPort = mainIsolateDataPort;

  final lib = AxiomRuntime._openPlatformLibrary();

  // The background isolate needs its own lookup for the function it will call.
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
  }
}

class AxiomRuntime {
  static AxiomRuntime? _instance;
  factory AxiomRuntime() {
    _instance ??= AxiomRuntime._internal();
    return _instance!;
  }

  // The port is now an INSTANCE variable to allow for clean re-creation on hot restart.
  ReceivePort? _mainIsolatePort;

  static Future<void> dispose() async {
    if (_instance != null) {
      final completer = Completer<void>();
      // Access the old instance's port to listen for its closure.
      _instance!._mainIsolatePort?.listen(
        null,
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      _commandPort?.send('shutdown');
      _instance!._mainIsolatePort?.close();

      _controllers.clear();
      _instance = null;
      _commandPort = null;
      _initCompleter = null;
      _freeResponseFfiBackground = null;

      await completer.future.timeout(
        const Duration(milliseconds: 200),
        onTimeout: () {},
      );
    }
  }

  static late final DynamicLibrary _lib;
  late final _AxiomInitialize _initFfi;
  late final _AxiomLoadContract _loadContractFfi;
  late final _AxiomCall _callFfi;
  static late final _AxiomFreeBuffer _freeFfi;

  AxiomRuntime._internal() {
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

  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    _mainIsolatePort = ReceivePort();

    _mainIsolatePort!.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
        if (!_initCompleter!.isCompleted) _initCompleter!.complete();
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

      // Helper to clean up raw buffers from Rust
      void freeBuffers() {
        if (dataPtr != 0) {
          final buf = calloc<AxiomBuffer>();
          buf.ref.ptr = Pointer.fromAddress(dataPtr);
          buf.ref.len = dataLen;
          _freeFfi(buf.ref);
          calloc.free(buf);
        }
        if (errorPtr != 0) {
          final buf = calloc<AxiomBuffer>();
          buf.ref.ptr = Pointer.fromAddress(errorPtr);
          buf.ref.len = errorLen;
          _freeFfi(buf.ref);
          calloc.free(buf);
        }
      }

      if (controller == null || controller.isClosed) {
        freeBuffers();
        return;
      }

      if (eventTypeValue == EventType.complete) {
        controller.close();
        _controllers.remove(requestId);
        freeBuffers();
        return;
      }

      if (eventTypeValue == EventType.error) {
        String errorDetails = "Unknown error";
        if (errorPtr != 0 && errorLen > 0) {
          final ptr = Pointer<Uint8>.fromAddress(errorPtr);
          errorDetails = utf8.decode(ptr.asTypedList(errorLen));
        }
        final errorName = FfiError.name(errorCodeValue);
        final exception = Exception('Axiom Error: $errorName\n$errorDetails');
        controller.add(AxiomState.error(exception));
        if (errorCodeValue == FfiError.requestParsingFailed) {
          controller.close();
          _controllers.remove(requestId);
        }
        freeBuffers();
        return;
      }

      // Success Event (Cache or Network)
      if (dataPtr != 0) {
        final ptr = Pointer<Uint8>.fromAddress(dataPtr);
        final data = Uint8List.fromList(ptr.asTypedList(dataLen));

        final source =
            (eventTypeValue == EventType.cacheHit ||
                eventTypeValue == EventType.cacheHitAndFetching)
            ? AxiomSource.cache
            : AxiomSource.network;
        final isFetching = eventTypeValue == EventType.cacheHitAndFetching;

        controller.add(
          AxiomState.success(data, source, isFetching: isFetching),
        );
      }

      freeBuffers();
    });

    await Isolate.spawn(_runRustEventLoop, [_mainIsolatePort!.sendPort]);
    return _initCompleter!.future;
  }

  static DynamicLibrary _openPlatformLibrary() {
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    throw UnsupportedError(
      'AxiomRuntime is only available on iOS in this build',
    );
  }

  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
  }) async {
    // 1. Determine DB path. Use app documents directory if not provided.
    final String resolvedDbPath;
    if (dbPath != null) {
      resolvedDbPath = dbPath;
    } else {
      final appDocsDir = await getApplicationDocumentsDirectory();
      resolvedDbPath = appDocsDir.path;
    }

    // 2. Initialize Rust with both paths.
    final urlUnits = utf8.encode(baseUrl);
    final urlPtr = calloc<Uint8>(urlUnits.length);
    urlPtr.asTypedList(urlUnits.length).setAll(0, urlUnits);
    final urlStr = calloc<AxiomString>();
    urlStr.ref
      ..ptr = urlPtr
      ..len = urlUnits.length;

    final dbUnits = utf8.encode(resolvedDbPath);
    final dbPtr = calloc<Uint8>(dbUnits.length);
    dbPtr.asTypedList(dbUnits.length).setAll(0, dbUnits);
    final dbStr = calloc<AxiomString>();
    dbStr.ref
      ..ptr = dbPtr
      ..len = dbUnits.length;

    final result = _initFfi(urlStr.ref, dbStr.ref);

    calloc.free(urlPtr);
    calloc.free(urlStr);
    calloc.free(dbPtr);
    calloc.free(dbStr);

    if (result != FfiError.success) {
      throw Exception('Failed to initialize runtime. Error code: $result');
    }

    // 3. Load the contract.
    loadContract(contractBytes);
  }

  void loadContract(Uint8List contractBytes) {
    final ptr = calloc<Uint8>(contractBytes.length);
    ptr.asTypedList(contractBytes.length).setAll(0, contractBytes);
    final axBuf = calloc<AxiomBuffer>();
    axBuf.ref
      ..ptr = ptr
      ..len = contractBytes.length;
    final result = _loadContractFfi(axBuf.ref);
    calloc.free(ptr);
    calloc.free(axBuf);
    if (result != FfiError.success) {
      throw Exception(
        'Failed to load Axiom contract. Error: ${FfiError.name(result)}',
      );
    }
  }

  Stream<AxiomState<Uint8List>> callStream({
    required int endpointId,
    required String method,
    required String path,
    required Uint8List requestBytes,
  }) {
    final requestId = _nextRequestId++;
    final controller = StreamController<AxiomState<Uint8List>>();
    _controllers[requestId] = controller;

    final pathUnits = utf8.encode(path);
    final pathPtr = calloc<Uint8>(pathUnits.length);
    pathPtr.asTypedList(pathUnits.length).setAll(0, pathUnits);
    final pathStr = calloc<AxiomString>();
    pathStr.ref.ptr = pathPtr;
    pathStr.ref.len = pathUnits.length;

    final bodyPtr = calloc<Uint8>(requestBytes.length);
    bodyPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);
    final bodyBuf = calloc<AxiomBuffer>();
    bodyBuf.ref.ptr = bodyPtr;
    bodyBuf.ref.len = requestBytes.length;

    final methodUnits = utf8.encode(method);
    final methodPtr = calloc<Uint8>(methodUnits.length);
    methodPtr.asTypedList(methodUnits.length).setAll(0, methodUnits);
    final methodStr = calloc<AxiomString>();
    methodStr.ref.ptr = methodPtr;
    methodStr.ref.len = methodUnits.length;

    void cleanup() {
      calloc.free(pathPtr);
      calloc.free(pathStr);
      calloc.free(bodyPtr);
      calloc.free(bodyBuf);
      calloc.free(methodPtr);
      calloc.free(methodStr);
    }

    // Add initial loading state
    controller.add(AxiomState.loading());

    try {
      _callFfi(requestId, endpointId, methodStr.ref, pathStr.ref, bodyBuf.ref);
    } catch (e) {
      _controllers.remove(requestId);
      controller.addError(e);
      controller.close();
    }

    // Ensure memory is freed after call returns (async/safe)
    Timer.run(cleanup);

    controller.onCancel = () {
      // TODO: Send cancel signal to Rust
      _controllers.remove(requestId);
    };

    return controller.stream;
  }
}
