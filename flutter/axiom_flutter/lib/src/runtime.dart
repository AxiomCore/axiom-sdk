// axiom_flutter/lib/src/runtime.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// --- FFI Structs and Enums (must match Rust) ---

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

  // Helper to convert code to a string name for debugging
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
  external int errorCode;
  external AxiomBuffer data;
  external AxiomBuffer errorMessage; // NEW
}

// --- FFI Function Signatures ---
typedef AxiomCallback = Void Function(Pointer<AxiomResponseBuffer> response);
typedef _AxiomInitializeNative = Int32 Function(AxiomString);
typedef _AxiomInitialize = int Function(AxiomString);
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
final _completers = HashMap<int, Completer<Uint8List>>();
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
    response.errorCode,
    response.data.ptr.address,
    response.data.len,
    response.errorMessage.ptr.address, // NEW
    response.errorMessage.len, // NEW
  ]);

  _freeResponseFfiBackground?.call(responsePtr);
}

@pragma('vm:entry-point')
void _runRustEventLoop(List<Object> args) {
  final mainIsolateDataPort = args[0] as SendPort;
  final shutdownPort = ReceivePort();
  mainIsolateDataPort.send(shutdownPort.sendPort);
  _dataPort = mainIsolateDataPort;

  final lib = AxiomRuntime._openPlatformLibrary();

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

  ReceivePort? _mainIsolatePort;

  static Future<void> dispose() async {
    if (_instance != null) {
      final completer = Completer<void>();
      _instance!._mainIsolatePort?.listen(
        null,
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );
      _commandPort?.send('shutdown');
      _instance!._mainIsolatePort?.close();
      _completers.clear();
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
      final int errorCodeValue = message[1];
      final int ptrAddress = message[2];
      final int dataLen = message[3];
      final int errorPtrAddress = message[4]; // NEW
      final int errorLen = message[5]; // NEW

      final completer = _completers.remove(requestId);
      if (completer == null) {
        if (ptrAddress != 0) {
          final buffer = calloc<AxiomBuffer>();
          buffer.ref.ptr = Pointer.fromAddress(ptrAddress);
          buffer.ref.len = dataLen;
          _freeFfi(buffer.ref);
          calloc.free(buffer);
        }

        if (errorPtrAddress != 0) {
          final buffer = calloc<AxiomBuffer>();
          buffer.ref.ptr = Pointer.fromAddress(errorPtrAddress);
          buffer.ref.len = errorLen;
          _freeFfi(buffer.ref);
          calloc.free(buffer);
        }

        return;
      }

      if (errorCodeValue == FfiError.success && ptrAddress != 0) {
        final ptr = Pointer<Uint8>.fromAddress(ptrAddress);
        final data = Uint8List.fromList(ptr.asTypedList(dataLen));
        completer.complete(data);

        final buffer = calloc<AxiomBuffer>();
        buffer.ref.ptr = ptr;
        buffer.ref.len = dataLen;
        _freeFfi(buffer.ref);
        calloc.free(buffer);
      } else {
        String errorDetails = "No additional details from runtime.";

        // Decode the error message from Rust if it exists
        if (errorPtrAddress != 0 && errorLen > 0) {
          final errorPtr = Pointer<Uint8>.fromAddress(errorPtrAddress);
          errorDetails = utf8.decode(errorPtr.asTypedList(errorLen));

          // Free the error message buffer
          final buffer = calloc<AxiomBuffer>();
          buffer.ref.ptr = Pointer.fromAddress(errorPtrAddress);
          buffer.ref.len = errorLen;
          _freeFfi(buffer.ref);
          calloc.free(buffer);
        }

        completer.completeError(
          Exception(
            'Axiom FFI call failed for request #$requestId with error: ${FfiError.name(errorCodeValue)}\n---\n$errorDetails\n---',
          ),
        );
      }
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

  void initialize(String baseUrl) {
    final units = utf8.encode(baseUrl);
    final ptr = calloc<Uint8>(units.length);
    ptr.asTypedList(units.length).setAll(0, units);
    final axStr = calloc<AxiomString>();
    axStr.ref.ptr = ptr;
    axStr.ref.len = units.length;
    final result = _initFfi(axStr.ref);
    if (result != FfiError.success) {
      throw Exception('Failed to initialize runtime. Error code: $result');
    }
    calloc.free(ptr);
    calloc.free(axStr);
  }

  void loadContract(Uint8List contractBytes) {
    final ptr = calloc<Uint8>(contractBytes.length);
    ptr.asTypedList(contractBytes.length).setAll(0, contractBytes);
    final axBuf = calloc<AxiomBuffer>();
    axBuf.ref.ptr = ptr;
    axBuf.ref.len = contractBytes.length;

    final result = _loadContractFfi(axBuf.ref);

    calloc.free(ptr);
    calloc.free(axBuf);

    if (result != FfiError.success) {
      throw Exception(
        'Failed to load Axiom contract. Error: ${FfiError.name(result)}',
      );
    }
  }

  Future<Uint8List> call({
    required int endpointId,
    required String path,
    required String method,
    required Uint8List requestBytes,
  }) {
    final requestId = _nextRequestId++;
    final completer = Completer<Uint8List>();
    _completers[requestId] = completer;

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

    completer.future.whenComplete(cleanup);

    try {
      _callFfi(requestId, endpointId, methodStr.ref, pathStr.ref, bodyBuf.ref);
    } catch (e) {
      _completers.remove(requestId);
      completer.completeError(e);
    }

    return completer.future;
  }
}
