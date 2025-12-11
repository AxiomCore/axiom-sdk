// GENERATED – DO NOT EDIT.
// Low-level FFI bridge to AxiomRuntime (Rust) for this project only.

import 'dart:async';
import 'dart:collection';
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

enum FfiError {
  success,
  unknownError,
  requestParsingFailed,
  networkError,
  responseDeserializationFailed,
  unknownEndpoint,
}

base class AxiomResponseBuffer extends Struct {
  @Uint64() external int requestId;
  @Int32() external int errorCode; // Use Int32 for enums
  external AxiomBuffer data;
}

// --- FFI Function Signatures ---
typedef AxiomCallback = Void Function(AxiomResponseBuffer response);
typedef _AxiomInitializeNative = Void Function(AxiomString);
typedef _AxiomInitialize = void Function(AxiomString);
typedef _AxiomRegisterCallbackNative = Void Function(Pointer<NativeFunction<AxiomCallback>>);
typedef _AxiomRegisterCallback = void Function(Pointer<NativeFunction<AxiomCallback>>);
typedef _AxiomCallNative = Void Function(Uint64, Uint32, AxiomBuffer);
typedef _AxiomCall = void Function(int, int, AxiomBuffer);
typedef _AxiomFreeBufferNative = Void Function(AxiomBuffer);
typedef _AxiomFreeBuffer = void Function(AxiomBuffer);
typedef _AxiomProcessResponsesNative = Void Function();
typedef _AxiomProcessResponses = void Function();


// --- Global state for managing async callbacks ---
final _completers = HashMap<int, Completer<Uint8List>>();
int _nextRequestId = 1;
SendPort? _commandPort;
Completer<void>? _initCompleter;
SendPort? _dataPort;

@pragma('vm:entry-point')
void _axiomCallbackHandler(AxiomResponseBuffer response) {
  _dataPort?.send([
    response.requestId,
    response.errorCode, // Now sending the integer error code
    response.data.ptr.address,
    response.data.len
  ]);
}

@pragma('vm:entry-point')
void _runRustEventLoop(List<Object> args) {
  final mainIsolateDataPort = args[0] as SendPort;
  final shutdownPort = ReceivePort();
  mainIsolateDataPort.send(shutdownPort.sendPort);
  _dataPort = mainIsolateDataPort;
  
  final lib = AxiomRuntime._openPlatformLibrary();
  final registerCallback = lib.lookupFunction<_AxiomRegisterCallbackNative, _AxiomRegisterCallback>('axiom_register_callback');
  registerCallback(Pointer.fromFunction(_axiomCallbackHandler));
  final processResponses = lib.lookupFunction<_AxiomProcessResponsesNative, _AxiomProcessResponses>('axiom_process_responses');

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
      _instance!._mainIsolatePort?.listen(null, onDone: () {
        if (!completer.isCompleted) completer.complete();
      });
      _commandPort?.send('shutdown');
      _instance!._mainIsolatePort?.close();
      _completers.clear();
      _instance = null;
      _commandPort = null;
      _initCompleter = null;
      await completer.future.timeout(const Duration(milliseconds: 200), onTimeout: () {});
    }
  }

  static late final DynamicLibrary _lib;
  late final _AxiomInitialize _initFfi;
  late final _AxiomCall _callFfi;
  static late final _AxiomFreeBuffer _freeFfi;

  AxiomRuntime._internal() {
    _lib = _openPlatformLibrary();
    _initFfi = _lib.lookupFunction<_AxiomInitializeNative, _AxiomInitialize>('axiom_initialize');
    _callFfi = _lib.lookupFunction<_AxiomCallNative, _AxiomCall>('axiom_call');
    _freeFfi = _lib.lookupFunction<_AxiomFreeBufferNative, _AxiomFreeBuffer>('axiom_free_buffer');
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
      final int len = message[3];

      final completer = _completers.remove(requestId);
      if (completer == null) {
        if (ptrAddress != 0) {
            final buffer = calloc<AxiomBuffer>();
            buffer.ref.ptr = Pointer.fromAddress(ptrAddress);
            buffer.ref.len = len;
            _freeFfi(buffer.ref);
            calloc.free(buffer);
        }
        return;
      }

      if (errorCodeValue == FfiError.success.index && ptrAddress != 0) {
        final ptr = Pointer<Uint8>.fromAddress(ptrAddress);
        final data = Uint8List.fromList(ptr.asTypedList(len));
        completer.complete(data);
        
        final buffer = calloc<AxiomBuffer>();
        buffer.ref.ptr = ptr;
        buffer.ref.len = len;
        _freeFfi(buffer.ref);
        calloc.free(buffer);
      } else {
        // Map the integer error code back to the enum for a clear error message.
        final error = FfiError.values[errorCodeValue];
        completer.completeError(Exception('Axiom FFI call failed for request #$requestId with error: ${error.name}'));
      }
    });

    await Isolate.spawn(_runRustEventLoop, [_mainIsolatePort!.sendPort]);
    return _initCompleter!.future;
  }
  
  static DynamicLibrary _openPlatformLibrary() {
    if (Platform.isIOS) { return DynamicLibrary.process(); }
    throw UnsupportedError('AxiomRuntime is only available on iOS in this build');
  }

  void initialize(String baseUrl) {
    final units = Uint8List.fromList(baseUrl.codeUnits);
    final ptr = malloc<Uint8>(units.length);
    ptr.asTypedList(units.length).setAll(0, units);
    final axStrPtr = malloc<AxiomString>();
    axStrPtr.ref..ptr = ptr..len = units.length;
    _initFfi(axStrPtr.ref);
    malloc.free(ptr);
    malloc.free(axStrPtr);
  }

  Future<Uint8List> call({
    required int endpointId,
    required Uint8List requestBytes,
  }) {
    final requestId = _nextRequestId++;
    final completer = Completer<Uint8List>();
    _completers[requestId] = completer;

    final inPtr = malloc<Uint8>(requestBytes.length);
    inPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);
    final inBufPtr = malloc<AxiomBuffer>();
    inBufPtr.ref..ptr = inPtr..len = requestBytes.length;

    try {
      _callFfi(requestId, endpointId, inBufPtr.ref);
    } catch (e) {
      _completers.remove(requestId);
      completer.completeError(e);
    } finally {
      malloc.free(inPtr);
      malloc.free(inBufPtr);
    }

    return completer.future;
  }
}
