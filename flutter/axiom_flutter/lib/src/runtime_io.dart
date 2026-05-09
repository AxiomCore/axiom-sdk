import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ansicolor/ansicolor.dart';
import 'package:ffi/ffi.dart';

import 'runtime_interface.dart';
import 'state.dart';
import 'query.dart';
import 'query_manager.dart';
import 'internal/axiom_codec.dart';
import 'internal/query_key.dart';
import 'internal/tracing.dart';

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

// 8 Arguments exactly matching Rust signature
typedef _AxiomCallNative =
    Void Function(
      Uint64,
      AxiomString,
      Uint32,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomBuffer,
    );
typedef _AxiomCall =
    void Function(
      int,
      AxiomString,
      int,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomBuffer,
    );

typedef _AxiomSetAuthTokenNative =
    Void Function(AxiomString, AxiomString, AxiomString);
typedef _AxiomSetAuthToken =
    void Function(AxiomString, AxiomString, AxiomString);
typedef _AxiomClearAuthTokenNative = Void Function(AxiomString, AxiomString);
typedef _AxiomClearAuthToken = void Function(AxiomString, AxiomString);
typedef _AxiomSendStreamMsgNative = Void Function(Uint64, AxiomBuffer);
typedef _AxiomSendStreamMsg = void Function(int, AxiomBuffer);
typedef _AxiomProcessResponsesNative = Void Function();
typedef _AxiomProcessResponses = void Function();
typedef _AxiomFreeResponseBufferNative =
    Void Function(Pointer<AxiomResponseBuffer>);
typedef _AxiomFreeResponseBuffer = void Function(Pointer<AxiomResponseBuffer>);

final _controllers = HashMap<int, StreamController<AxiomState<Uint8List>>>();
final _hadError = HashSet<int>();

int _nextRequestId = 1;
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
  late final _AxiomSetAuthToken _setAuthFfi;
  late final _AxiomClearAuthToken _clearAuthFfi;
  late final _AxiomSendStreamMsg _sendStreamMsgFfi;

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
    _setAuthFfi = _lib
        .lookupFunction<_AxiomSetAuthTokenNative, _AxiomSetAuthToken>(
          'axiom_set_auth_token',
        );
    _clearAuthFfi = _lib
        .lookupFunction<_AxiomClearAuthTokenNative, _AxiomClearAuthToken>(
          'axiom_clear_auth_token',
        );
    _sendStreamMsgFfi = _lib
        .lookupFunction<_AxiomSendStreamMsgNative, _AxiomSendStreamMsg>(
          'axiom_send_stream_message',
        );
  }

  @override
  bool debug = false;

  @override
  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  }) {
    using((Arena arena) {
      _setAuthFfi(
        _toAxiomString(namespace, arena),
        _toAxiomString(methodName, arena),
        _toAxiomString(token, arena),
      );
    });
  }

  @override
  void clearAuthToken({required String namespace, required String methodName}) {
    using((Arena arena) {
      _clearAuthFfi(
        _toAxiomString(namespace, arena),
        _toAxiomString(methodName, arena),
      );
    });
  }

  @override
  void sendStreamMessage({required int requestId, required Uint8List payload}) {
    using((Arena arena) {
      final ptr = arena<Uint8>(payload.length);
      ptr.asTypedList(payload.length).setAll(0, payload);
      final buf = arena<AxiomBuffer>()
        ..ref.ptr = ptr
        ..ref.len = payload.length;
      _sendStreamMsgFfi(requestId, buf.ref);
    });
  }

  @override
  Future<void> init([String? dbPath]) async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    final mainIsolatePort = ReceivePort();

    mainIsolatePort.listen((message) {
      if (message is SendPort) {
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
      if (controller == null || controller.isClosed) return;

      if (eventTypeValue == EventType.complete) {
        _hadError.remove(requestId);
        controller.close();
        _controllers.remove(requestId);
        return;
      }

      if (eventTypeValue == EventType.streamChunk) {
        final data = Uint8List.fromList(
          Pointer<Uint8>.fromAddress(dataPtr).asTypedList(dataLen),
        );
        controller.add(
          AxiomState.success(data, AxiomSource.network, isStreaming: true),
        );
        return;
      }

      if (eventTypeValue == EventType.error) {
        _hadError.add(requestId);
        AxiomError richError = errorPtr != 0
            ? AxiomError.fromJson(
                jsonDecode(
                  utf8.decode(
                    Pointer<Uint8>.fromAddress(errorPtr).asTypedList(errorLen),
                  ),
                ),
              )
            : AxiomError(
                stage: ErrorStage.runtime,
                category: ErrorCategory.unknown,
                code: UnknownCode(FfiError.name(errorCodeValue)),
                message: 'Internal error',
                retryable: false,
              );
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
    using((Arena arena) => _initFfi(_toAxiomString(dbPath ?? '', arena)));
    return _initCompleter!.future;
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
      final cPtr = arena<Uint8>(contractBytes.length);
      cPtr.asTypedList(contractBytes.length).setAll(0, contractBytes);
      final buf = arena<AxiomBuffer>()
        ..ref.ptr = cPtr
        ..ref.len = contractBytes.length;
      _loadContractFfi(
        _toAxiomString(namespace, arena),
        _toAxiomString(baseUrl, arena),
        buf.ref,
        _toAxiomString(signature ?? '', arena),
        _toAxiomString(publicKey ?? '', arena),
      );
    });
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
  }) {
    final requestId = _nextRequestId++;
    final controller = StreamController<AxiomState<Uint8List>>.broadcast();
    _controllers[requestId] = controller;
    controller.add(AxiomState.loading());

    var finalPath = path;
    pathParams?.forEach(
      (k, v) => finalPath = finalPath.replaceAll('{$k}', v.toString()),
    );

    if (queryParams != null && queryParams.isNotEmpty) {
      final filteredParams = <String, String>{};
      for (final entry in queryParams.entries) {
        if (entry.value != null)
          filteredParams[entry.key] = entry.value.toString();
      }
      if (filteredParams.isNotEmpty) {
        finalPath +=
            (finalPath.contains('?') ? '&' : '?') +
            Uri(queryParameters: filteredParams).query;
      }
    }

    final traceparent = AxiomTracing.generateTraceparent();
    final headersJson = headers != null && headers.isNotEmpty
        ? jsonEncode(headers)
        : '';

    _logTransaction('OUT', requestId, {
      'ns': namespace,
      'ep': endpointId,
      'm': method,
      'p': finalPath,
    });

    final arena = Arena();
    final bPtr = arena<Uint8>(requestBytes.length);
    bPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);
    final b = arena<AxiomBuffer>()
      ..ref.ptr = bPtr
      ..ref.len = requestBytes.length;

    _callFfi(
      requestId,
      _toAxiomString(namespace, arena),
      endpointId,
      _toAxiomString(method, arena),
      _toAxiomString(finalPath, arena),
      _toAxiomString(traceparent, arena),
      _toAxiomString(headersJson, arena), // Passed to Native Rust successfully
      b.ref,
    );
    Future.microtask(() => arena.releaseAll());

    controller.onCancel = () => _controllers.remove(requestId);
    return AxiomStreamResponse(requestId, controller.stream);
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

  AxiomString _toAxiomString(String s, Arena arena) {
    final units = utf8.encode(s);
    final ptr = arena<Uint8>(units.length);
    ptr.asTypedList(units.length).setAll(0, units);
    return arena<AxiomString>().ref
      ..ptr = ptr
      ..len = units.length;
  }

  void _logTransaction(String dir, int id, dynamic details) {
    if (!debug) return;
    final pen = AnsiPen()
      ..white(bold: true)
      ..xterm(dir == 'OUT' ? 063 : 034);
    print(pen('${dir == 'OUT' ? '➔ CALL' : '← RESP'} [#$id] $details'));
  }

  static DynamicLibrary _openPlatformLibrary() =>
      Platform.isIOS || Platform.isMacOS
      ? DynamicLibrary.process()
      : DynamicLibrary.open('libaxiom_runtime.so');

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
