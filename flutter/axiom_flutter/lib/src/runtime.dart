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

import 'state.dart';
import 'query.dart';
import 'query_manager.dart';
import 'internal/axiom_codec.dart';
import 'internal/query_key.dart';

export 'state.dart';

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
  static const int successUnverified = -1;
  static const int success = 0;
  static const int unknownError = 1;
  static const int requestParsingFailed = 2;
  static const int networkError = 3;
  static const int responseDeserializationFailed = 4;
  static const int unknownEndpoint = 5;
  static const int timeout = 6;
  static const int requestFailed = 7;
  static const int authError = 8;
  static const int serverError = 9;
  static const int invalidContract = 10;
  static const int runtimeTooOld = 11;
  static const int contractNotLoaded = 12;
  static const int initializationFailed = 13;
  static const int internalError = 14;

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
      _ => 'UnrecognizedErrorCode',
    };
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

typedef AxiomCallback = Void Function(Pointer<AxiomResponseBuffer> response);

typedef _AxiomInitializeNative = Int32 Function(AxiomString, AxiomString);
typedef _AxiomInitialize = int Function(AxiomString, AxiomString);

typedef _AxiomLoadContractNative =
    Int32 Function(AxiomBuffer, AxiomString, AxiomString);
typedef _AxiomLoadContract =
    int Function(AxiomBuffer, AxiomString, AxiomString);

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
    // A small sleep can prevent the isolate from pegging a CPU core at 100%
    // if there are no events to process.
    sleep(const Duration(milliseconds: 5));
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
        AxiomError richError;
        if (errorPtr != 0 && errorLen > 0) {
          try {
            final ptr = Pointer<Uint8>.fromAddress(errorPtr);
            final jsonStr = utf8.decode(ptr.asTypedList(errorLen));
            final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
            richError = AxiomError.fromJson(jsonMap);
          } catch (e) {
            richError = AxiomError(
              stage: ErrorStage.ffiBoundary,
              category: ErrorCategory.runtime,
              code: const UnknownCode("JsonParseFailure"),
              message: "Failed to parse rich error from Rust: $e",
              retryable: false,
            );
          }
        } else {
          richError = AxiomError(
            stage: ErrorStage.runtime,
            category: ErrorCategory.unknown,
            code: UnknownCode(FfiError.name(errorCodeValue)),
            message: "An unknown internal error occurred in Rust",
            retryable: false,
          );
        }
        controller.add(AxiomState.error(richError));

        const nonRecoverableErrors = [
          FfiError.unknownEndpoint,
          FfiError.invalidContract,
          FfiError.contractNotLoaded,
        ];
        if (nonRecoverableErrors.contains(errorCodeValue)) {
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
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libaxiom_runtime.so');
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libaxiom_runtime.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('axiom_runtime.dll');
    }
    throw UnsupportedError('Unsupported platform');
  }

  Future<void> startup({
    required String baseUrl,
    required Uint8List contractBytes,
    String? dbPath,
    String? signature,
    String? publicKey,
  }) async {
    final String resolvedDbPath;
    if (dbPath != null) {
      resolvedDbPath = dbPath;
    } else {
      final appDocsDir = await getApplicationDocumentsDirectory();
      resolvedDbPath = appDocsDir.path;
    }

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

    loadContract(contractBytes, signature, publicKey);
  }

  void loadContract(
    Uint8List contractBytes,
    String? signature,
    String? publicKey,
  ) {
    final ptr = calloc<Uint8>(contractBytes.length);
    ptr.asTypedList(contractBytes.length).setAll(0, contractBytes);
    final axBuf = calloc<AxiomBuffer>();
    axBuf.ref
      ..ptr = ptr
      ..len = contractBytes.length;

    final Pointer<AxiomString> sigStr = calloc<AxiomString>();
    Pointer<Uint8> sigPtr = nullptr;
    if (signature != null) {
      final units = utf8.encode(signature);
      sigPtr = calloc<Uint8>(units.length);
      sigPtr.asTypedList(units.length).setAll(0, units);
      sigStr.ref
        ..ptr = sigPtr
        ..len = units.length;
    } else {
      sigStr.ref
        ..ptr = nullptr
        ..len = 0;
    }

    // Prepare Public Key
    final Pointer<AxiomString> pkStr = calloc<AxiomString>();
    Pointer<Uint8> pkPtr = nullptr;
    if (publicKey != null) {
      final units = utf8.encode(publicKey);
      pkPtr = calloc<Uint8>(units.length);
      pkPtr.asTypedList(units.length).setAll(0, units);
      pkStr.ref
        ..ptr = pkPtr
        ..len = units.length;
    } else {
      pkStr.ref
        ..ptr = nullptr
        ..len = 0;
    }

    final result = _loadContractFfi(axBuf.ref, sigStr.ref, pkStr.ref);

    // Free memory
    calloc.free(ptr);
    calloc.free(axBuf);

    if (sigPtr != nullptr) calloc.free(sigPtr);
    calloc.free(sigStr);

    if (pkPtr != nullptr) calloc.free(pkPtr);
    calloc.free(pkStr);

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

  /// High-level API to perform a query or mutation.
  ///
  /// This abstracts the complexities of URL construction, serialization,
  /// and caching away from the generated code.
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

    final pathUnits = utf8.encode(path);
    final pathPtr = calloc<Uint8>(pathUnits.length);
    pathPtr.asTypedList(pathUnits.length).setAll(0, pathUnits);
    final pathStr = calloc<AxiomString>()
      ..ref.ptr = pathPtr
      ..ref.len = pathUnits.length;

    final bodyPtr = calloc<Uint8>(requestBytes.length);
    bodyPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);
    final bodyBuf = calloc<AxiomBuffer>()
      ..ref.ptr = bodyPtr
      ..ref.len = requestBytes.length;

    final methodUnits = utf8.encode(method);
    final methodPtr = calloc<Uint8>(methodUnits.length);
    methodPtr.asTypedList(methodUnits.length).setAll(0, methodUnits);
    final methodStr = calloc<AxiomString>()
      ..ref.ptr = methodPtr
      ..ref.len = methodUnits.length;

    try {
      _callFfi(requestId, endpointId, methodStr.ref, pathStr.ref, bodyBuf.ref);
    } catch (e, st) {
      _controllers.remove(requestId);
      controller.addError(e, st);
      controller.close();
    } finally {
      Future.microtask(() {
        calloc.free(pathPtr);
        calloc.free(pathStr);
        calloc.free(bodyPtr);
        calloc.free(bodyBuf);
        calloc.free(methodPtr);
        calloc.free(methodStr);
      });
    }

    controller.onCancel = () {
      _controllers.remove(requestId);
    };

    return controller.stream;
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
        '│ ⚠️  AXIOM SECURITY WARNING                                  │',
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
        '│ https://axiomcore.dev/docs/security/unsigned-contracts     │',
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
