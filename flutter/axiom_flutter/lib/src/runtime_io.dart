import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ansicolor/ansicolor.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart' as path_provider;

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
import 'internal/contract_metadata.dart';
import 'internal/query_key.dart';
import 'internal/tracing.dart';
import 'internal/contract_load_status.dart';

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
typedef AxiomAuthCallbackNative = Void Function(Uint64 requestId);

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
typedef _AxiomLoadContractLockedNative =
    Int32 Function(
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomString,
      AxiomString,
      AxiomString,
    );
typedef _AxiomLoadContractLocked =
    int Function(
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomString,
      AxiomString,
      AxiomString,
    );
typedef _AxiomRegisterCallbackNative =
    Void Function(Pointer<NativeFunction<AxiomCallback>>);
typedef _AxiomRegisterCallback =
    void Function(Pointer<NativeFunction<AxiomCallback>>);
typedef _AxiomRegisterAuthNative =
    Void Function(Pointer<NativeFunction<AxiomAuthCallbackNative>>);
typedef _AxiomRegisterAuth =
    void Function(Pointer<NativeFunction<AxiomAuthCallbackNative>>);
typedef _AxiomProvideAuthNative = Void Function(Uint64, AxiomString);
typedef _AxiomProvideAuth = void Function(int, AxiomString);

// 8 Arguments exactly matching Rust signature
typedef _AxiomCallNative =
    Int32 Function(
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
    int Function(
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
typedef _AxiomVoidNative = Void Function();
typedef _AxiomVoid = void Function();
typedef _AxiomU32Native = Uint32 Function();
typedef _AxiomU32 = int Function();
typedef _AxiomCancelNative = Int32 Function(Uint64);
typedef _AxiomCancel = int Function(int);
typedef _AxiomFreeResponseBufferNative =
    Void Function(Pointer<AxiomResponseBuffer>);
typedef _AxiomFreeResponseBuffer = void Function(Pointer<AxiomResponseBuffer>);
typedef _AxiomFreeBufferNative = Void Function(AxiomBuffer);
typedef _AxiomFreeBuffer = void Function(AxiomBuffer);
typedef _AxiomExtLifecycleNative = Int32 Function(Uint32);
typedef _AxiomExtLifecycle = int Function(int);
typedef _AxiomExtLoadNative =
    Int32 Function(
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomBuffer,
      AxiomBuffer,
      AxiomBuffer,
    );
typedef _AxiomExtLoad =
    int Function(
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomBuffer,
      AxiomBuffer,
      AxiomBuffer,
    );
typedef _AxiomExtInvokeNative =
    Int32 Function(
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      Pointer<AxiomBuffer>,
    );
typedef _AxiomExtInvoke =
    int Function(
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      Pointer<AxiomBuffer>,
    );
typedef _AxiomExtAuditNative = Int32 Function(Pointer<AxiomBuffer>);
typedef _AxiomExtAudit = int Function(Pointer<AxiomBuffer>);

// Optional functions added by axiom-runtime branch flutter/r (looked up with
// providesSymbol; the published 0.148.6 runtime does not have them).
typedef _AxiomStrStatusNative = Int32 Function(AxiomString);
typedef _AxiomStrStatus = int Function(AxiomString);
typedef _AxiomStr2StatusNative = Int32 Function(AxiomString, AxiomString);
typedef _AxiomStr2Status = int Function(AxiomString, AxiomString);
typedef _AxiomCallWithOptionsNative =
    Int32 Function(
      Uint64,
      AxiomString,
      Uint32,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomString,
    );
typedef _AxiomCallWithOptions =
    int Function(
      int,
      AxiomString,
      int,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomString,
      AxiomBuffer,
      AxiomString,
    );
typedef AxiomAuthCallbackV2Native =
    Void Function(Uint64 requestId, Pointer<Utf8> namespace, Pointer<Utf8> method);
typedef _AxiomRegisterAuthV2Native =
    Void Function(Pointer<NativeFunction<AxiomAuthCallbackV2Native>>);
typedef _AxiomRegisterAuthV2 =
    void Function(Pointer<NativeFunction<AxiomAuthCallbackV2Native>>);

/// Book-keeping for one in-flight runtime request.
class _Call {
  final StreamController<AxiomState<Uint8List>> controller;
  final String namespace;
  final int endpointId;
  Timer? timeout;
  bool timedOut = false;
  _Call(this.controller, this.namespace, this.endpointId);
}

final _calls = HashMap<int, _Call>();

/// Request ids are unique per process generation (time based) so responses
/// of a previous generation (Flutter hot restart) can never be routed to a
/// new request.
int _nextRequestId = DateTime.now().microsecondsSinceEpoch;

Future<void>? _initFuture;
bool _initialized = false;
Isolate? _eventIsolate;
SendPort? _eventControl;
ReceivePort? _mainPort;
Future<AxiomInitResult>? _initResultFuture;
AxiomInitResult? _initResult;

// Event-loop isolate globals (separate isolate, separate copies).
SendPort? _dataPort;
_AxiomFreeResponseBuffer? _freeResponseFfiBackground;

/// Opens the runtime library. `AXIOM_RUNTIME_LIB` (only when set) points at
/// an explicit library path, used by host tests on Linux/macOS.
DynamicLibrary _openLibrary() {
  final override = Platform.environment['AXIOM_RUNTIME_LIB'];
  if (override != null && override.isNotEmpty) {
    return DynamicLibrary.open(override);
  }
  return AxiomRuntimeIo._openPlatformLibrary();
}

@pragma('vm:entry-point')
void _axiomCallbackHandler(Pointer<AxiomResponseBuffer> responsePtr) {
  if (responsePtr == nullptr) return;
  try {
    final response = responsePtr.ref;
    // Native ownership ends in this callback. Send owned Dart bytes, never addresses.
    final data = response.data.ptr == nullptr || response.data.len == 0
        ? Uint8List(0)
        : Uint8List.fromList(response.data.ptr.asTypedList(response.data.len));
    final error =
        response.errorMessage.ptr == nullptr || response.errorMessage.len == 0
        ? Uint8List(0)
        : Uint8List.fromList(
            response.errorMessage.ptr.asTypedList(response.errorMessage.len),
          );
    _dataPort?.send([
      response.requestId,
      response.eventType,
      response.errorCode,
      data,
      error,
    ]);
  } finally {
    _freeResponseFfiBackground?.call(responsePtr);
  }
}

/// Polls `axiom_process_responses` (which blocks up to 100 ms when idle) on
/// a dedicated isolate. Stops on a `'shutdown'` message or when the main
/// isolate exits (Flutter hot restart), so a stale loop never competes with
/// the next generation for responses.
@pragma('vm:entry-point')
Future<void> _runRustEventLoop(List<Object> args) async {
  final mainIsolateDataPort = args[0] as SendPort;
  final mainIsolate = args[1] as Isolate;
  final control = ReceivePort();
  var running = true;
  control.listen((msg) {
    if (msg == 'shutdown') {
      running = false;
      control.close();
    }
  });
  mainIsolate.addOnExitListener(control.sendPort, response: 'shutdown');
  _dataPort = mainIsolateDataPort;

  final lib = _openLibrary();
  _freeResponseFfiBackground = lib
      .lookupFunction<_AxiomFreeResponseBufferNative, _AxiomFreeResponseBuffer>(
        'axiom_free_response_buffer',
      );
  final registerCallback = lib
      .lookupFunction<_AxiomRegisterCallbackNative, _AxiomRegisterCallback>(
        'axiom_register_callback',
      );
  registerCallback(Pointer.fromFunction(_axiomCallbackHandler));

  final processResponses = lib.lookupFunction<_AxiomVoidNative, _AxiomVoid>(
    'axiom_process_responses',
  );

  mainIsolateDataPort.send(control.sendPort);

  while (running) {
    processResponses();
    // Yield so the control port can deliver 'shutdown'.
    await Future<void>.delayed(Duration.zero);
  }
  mainIsolateDataPort.send('stopped');
}

class AxiomRuntimeIo implements AxiomRuntime {
  static AxiomRuntimeIo? _instance;
  factory AxiomRuntimeIo() => _instance ??= AxiomRuntimeIo._internal();

  static late final DynamicLibrary _lib;
  late final _AxiomInitialize _initFfi;
  late final _AxiomLoadContract _loadContractFfi;
  late final _AxiomLoadContractLocked? _loadContractLockedFfi;
  late final _AxiomCall _callFfi;
  late final _AxiomSetAuthToken _setAuthFfi;
  late final _AxiomClearAuthToken _clearAuthFfi;
  late final _AxiomSendStreamMsg _sendStreamMsgFfi;
  late final _AxiomCancel? _cancelFfi;
  late final _AxiomVoid? _resetSessionFfi;
  late final _AxiomVoid? _clearCallbackFfi;
  late final _AxiomCallWithOptions? _callWithOptionsFfi;
  late final _AxiomStr2Status? _cacheInvalidateIdentityFfi;
  late final _AxiomStrStatus? _cacheClearNamespaceFfi;
  late final _AxiomStr2Status? _setNamespaceTokenFfi;
  late final _AxiomStrStatus? _clearNamespaceTokensFfi;
  late final _AxiomVoid? _clearAuthProviderFfi;

  /// Namespaces with a successfully loaded contract.
  final Set<String> _loadedNamespaces = {};

  AxiomRuntimeIo._internal() {
    _lib = _openLibrary();
    _initFfi = _lib.lookupFunction<_AxiomInitializeNative, _AxiomInitialize>(
      'axiom_initialize',
    );
    _loadContractFfi = _lib
        .lookupFunction<_AxiomLoadContractNative, _AxiomLoadContract>(
          'axiom_load_contract',
        );
    _loadContractLockedFfi = _has('axiom_load_contract_locked')
        ? _lib.lookupFunction<
            _AxiomLoadContractLockedNative,
            _AxiomLoadContractLocked
          >('axiom_load_contract_locked')
        : null;
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
    _cancelFfi = _has('axiom_cancel')
        ? _lib.lookupFunction<_AxiomCancelNative, _AxiomCancel>('axiom_cancel')
        : null;
    _resetSessionFfi = _has('axiom_reset_session')
        ? _lib.lookupFunction<_AxiomVoidNative, _AxiomVoid>(
            'axiom_reset_session',
          )
        : null;
    _clearCallbackFfi = _has('axiom_clear_callback')
        ? _lib.lookupFunction<_AxiomVoidNative, _AxiomVoid>(
            'axiom_clear_callback',
          )
        : null;
    _callWithOptionsFfi = _has('axiom_call_with_options')
        ? _lib.lookupFunction<_AxiomCallWithOptionsNative, _AxiomCallWithOptions>(
            'axiom_call_with_options',
          )
        : null;
    _cacheInvalidateIdentityFfi = _has('axiom_cache_invalidate_identity')
        ? _lib.lookupFunction<_AxiomStr2StatusNative, _AxiomStr2Status>(
            'axiom_cache_invalidate_identity',
          )
        : null;
    _cacheClearNamespaceFfi = _has('axiom_cache_clear_namespace')
        ? _lib.lookupFunction<_AxiomStrStatusNative, _AxiomStrStatus>(
            'axiom_cache_clear_namespace',
          )
        : null;
    _setNamespaceTokenFfi = _has('axiom_set_namespace_auth_token')
        ? _lib.lookupFunction<_AxiomStr2StatusNative, _AxiomStr2Status>(
            'axiom_set_namespace_auth_token',
          )
        : null;
    _clearNamespaceTokensFfi = _has('axiom_clear_namespace_auth_tokens')
        ? _lib.lookupFunction<_AxiomStrStatusNative, _AxiomStrStatus>(
            'axiom_clear_namespace_auth_tokens',
          )
        : null;
    _clearAuthProviderFfi = _has('axiom_clear_auth_provider')
        ? _lib.lookupFunction<_AxiomVoidNative, _AxiomVoid>(
            'axiom_clear_auth_provider',
          )
        : null;
    AxiomContractMetadata.addListener(_applyTokensFor);
  }

  static bool _has(String symbol) {
    try {
      return _lib.providesSymbol(symbol);
    } catch (_) {
      return false;
    }
  }

  @override
  bool debug = false;

  final StreamController<AxiomErrorEvent> _errors =
      StreamController<AxiomErrorEvent>.broadcast();

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Explicit per-method tokens set through [setAuthToken].
  final Map<String, Map<String, String>> _methodTokens = {};
  final Map<String, String> _namespaceTokens = {};
  String? _globalToken;
  AxiomAuthProvider? _authProvider;
  NativeCallable<AxiomAuthCallbackNative>? _authCallable;

  @override
  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  }) {
    (_methodTokens[namespace] ??= {})[methodName] = token;
    _setNativeToken(namespace, methodName, token);
  }

  @override
  void clearAuthToken({required String namespace, required String methodName}) {
    _methodTokens[namespace]?.remove(methodName);
    final fallback = _namespaceTokens[namespace] ?? _globalToken;
    if (fallback != null) {
      _setNativeToken(namespace, methodName, fallback);
    } else {
      _clearNativeToken(namespace, methodName);
    }
  }

  void _setNativeToken(String namespace, String methodName, String token) {
    using((Arena arena) {
      _setAuthFfi(
        _toAxiomString(namespace, arena),
        _toAxiomString(methodName, arena),
        _toAxiomString(token, arena),
      );
    });
  }

  void _clearNativeToken(String namespace, String methodName) {
    using((Arena arena) {
      _clearAuthFfi(
        _toAxiomString(namespace, arena),
        _toAxiomString(methodName, arena),
      );
    });
  }

  /// Pushes namespace/global tokens to the runtime for [namespace]: through
  /// `axiom_set_namespace_auth_token` when the runtime has it, otherwise to
  /// every registered auth method without an explicit per-method token.
  void _applyTokensFor(String namespace) {
    final token = _namespaceTokens[namespace] ?? _globalToken;
    final setNs = _setNamespaceTokenFfi;
    final clearNs = _clearNamespaceTokensFfi;
    if (setNs != null && clearNs != null) {
      using((Arena arena) {
        if (token != null) {
          setNs(_toAxiomString(namespace, arena), _toAxiomString(token, arena));
        } else {
          // Also clears per-method tokens: restore the explicit ones below.
          clearNs(_toAxiomString(namespace, arena));
        }
      });
      if (token == null) {
        _methodTokens[namespace]?.forEach(
          (method, t) => _setNativeToken(namespace, method, t),
        );
      }
      return;
    }
    final explicit = _methodTokens[namespace] ?? const {};
    for (final method in AxiomContractMetadata.authMethodsFor(namespace)) {
      if (explicit.containsKey(method)) continue;
      if (token != null) {
        _setNativeToken(namespace, method, token);
      } else {
        _clearNativeToken(namespace, method);
      }
    }
  }

  @override
  void setNamespaceAuthToken({
    required String namespace,
    required String token,
  }) {
    _namespaceTokens[namespace] = token;
    _applyTokensFor(namespace);
  }

  @override
  void clearNamespaceAuthToken({required String namespace}) {
    _namespaceTokens.remove(namespace);
    _applyTokensFor(namespace);
  }

  /// Namespaces a global token must be pushed to.
  Iterable<String> get _tokenNamespaces => {
    ...AxiomContractMetadata.namespacesWithAuth,
    if (_setNamespaceTokenFfi != null) ..._loadedNamespaces,
  };

  @override
  void setGlobalAuthToken(String token) {
    _globalToken = token;
    for (final ns in _tokenNamespaces.toList()) {
      _applyTokensFor(ns);
    }
  }

  @override
  void clearGlobalAuthToken() {
    _globalToken = null;
    for (final ns in _tokenNamespaces.toList()) {
      if (_namespaceTokens.containsKey(ns)) continue;
      _applyTokensFor(ns);
    }
  }

  NativeCallable<AxiomAuthCallbackV2Native>? _authCallableV2;

  @override
  void setAuthProvider(AxiomAuthProvider? provider) {
    _authProvider = provider;
    if (provider == null) {
      if (_clearAuthProviderFfi != null &&
          (_authCallable != null || _authCallableV2 != null)) {
        _clearAuthProviderFfi();
        // The native side forgot the callables; keep them alive (a callback
        // may already be queued) but register again on the next provider.
        _authRegistered = false;
      }
      return;
    }
    if (_authRegistered) return;
    if (_has('axiom_register_auth_provider_v2') &&
        _has('axiom_provide_auth_token')) {
      _authCallableV2 ??= NativeCallable<AxiomAuthCallbackV2Native>.listener(
        _onAuthRequestedV2,
      );
      _lib.lookupFunction<_AxiomRegisterAuthV2Native, _AxiomRegisterAuthV2>(
        'axiom_register_auth_provider_v2',
      )(_authCallableV2!.nativeFunction);
      _authRegistered = true;
      return;
    }
    if (_authCallable != null) {
      _authRegistered = true;
      return;
    }
    if (!_has('axiom_register_auth_provider') ||
        !_has('axiom_provide_auth_token')) {
      return;
    }
    // The runtime calls back from a worker thread; a listener callable posts
    // the request to this isolate. It stays registered for the process
    // lifetime (there is no C function to unregister); with no provider the
    // fallback tokens answer.
    _authCallable = NativeCallable<AxiomAuthCallbackNative>.listener(
      _onAuthRequested,
    );
    _lib.lookupFunction<_AxiomRegisterAuthNative, _AxiomRegisterAuth>(
      'axiom_register_auth_provider',
    )(_authCallable!.nativeFunction);
    _authRegistered = true;
  }

  bool _authRegistered = false;

  /// v2 callback: namespace and method come from the runtime (strings stay
  /// valid until axiom_provide_auth_token is called).
  void _onAuthRequestedV2(
    int requestId,
    Pointer<Utf8> namespace,
    Pointer<Utf8> method,
  ) {
    String ns = '';
    String m = '';
    try {
      ns = namespace == nullptr ? '' : namespace.toDartString();
      m = method == nullptr ? '' : method.toDartString();
    } catch (_) {}
    if (ns.isEmpty) ns = _calls[requestId]?.namespace ?? '';
    resolveAuthToken(ns, m).then(
      (token) => _provideToken(requestId, token ?? ''),
      onError: (Object _) => _provideToken(requestId, ''),
    );
  }

  /// Answers one runtime token request (`AxiomAuthCallback`).
  void _onAuthRequested(int requestId) {
    final call = _calls[requestId];
    final namespace = call?.namespace ?? '';
    resolveAuthToken(namespace, '').then(
      (token) => _provideToken(requestId, token ?? ''),
      onError: (Object _) => _provideToken(requestId, ''),
    );
  }

  /// Token for [namespace]/[methodName]: auth provider first, then the
  /// per-method, namespace and global tokens set from Dart.
  Future<String?> resolveAuthToken(String namespace, String methodName) async {
    final provider = _authProvider;
    if (provider != null) {
      final token = await provider(namespace, methodName);
      if (token != null) return token;
    }
    final explicit = _methodTokens[namespace];
    if (methodName.isNotEmpty && explicit?[methodName] != null) {
      return explicit![methodName];
    }
    return _namespaceTokens[namespace] ??
        _globalToken ??
        // v1 callback (no method name): a namespace with exactly one
        // explicit per-method token answers with it.
        (methodName.isEmpty && explicit != null && explicit.length == 1
            ? explicit.values.first
            : null);
  }

  void _provideToken(int requestId, String token) {
    using((Arena arena) {
      _lib.lookupFunction<_AxiomProvideAuthNative, _AxiomProvideAuth>(
        'axiom_provide_auth_token',
      )(requestId, _toAxiomString(token, arena));
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

  // ---------------------------------------------------------------------------
  // Init and version handshake
  // ---------------------------------------------------------------------------

  @override
  Future<void> init([String? dbPath]) {
    return _initFuture ??= _start(dbPath);
  }

  Future<void> _start(String? dbPath) async {
    // A previous Dart generation (hot restart) may have left its callback
    // registered; drop it before the new event loop registers its own.
    _clearCallbackFfi?.call();
    // Same for an auth provider callable of a dead generation.
    if (_clearAuthProviderFfi != null) {
      _clearAuthProviderFfi();
      _authRegistered = false;
      if (_authProvider != null) setAuthProvider(_authProvider);
    }

    final ready = Completer<void>();
    final mainIsolatePort = ReceivePort();
    _mainPort = mainIsolatePort;

    mainIsolatePort.listen((message) {
      if (message is SendPort) {
        _eventControl = message;
        if (!ready.isCompleted) ready.complete();
        return;
      }
      if (message is! List) return;
      _onResponse(
        message[0] as int,
        message[1] as int,
        message[2] as int,
        message[3] as Uint8List,
        message[4] as Uint8List,
      );
    });

    _eventIsolate = await Isolate.spawn(_runRustEventLoop, [
      mainIsolatePort.sendPort,
      Isolate.current,
    ], debugName: 'axiom-runtime-events');
    final resolvedDb = await _resolveDbPath(dbPath);
    using((Arena arena) => _initFfi(_toAxiomString(resolvedDb, arena)));
    await ready.future;
    _initialized = true;
  }

  /// The runtime only creates its response cache and auth store when given a
  /// database path, so default to `<app support>/axiom` (a temp directory
  /// when path_provider is unavailable, e.g. host tests).
  /// `AXIOM_DB_PATH` (environment, only when set) overrides the default.
  static Future<String> _resolveDbPath(String? dbPath) async {
    if (dbPath != null && dbPath.isNotEmpty) return dbPath;
    final env = Platform.environment['AXIOM_DB_PATH'];
    if (env != null && env.isNotEmpty) return env;
    try {
      final dir = await path_provider.getApplicationSupportDirectory();
      return '${dir.path}${Platform.pathSeparator}axiom';
    } catch (_) {
      return '${Directory.systemTemp.path}${Platform.pathSeparator}axiom_runtime_$pid';
    }
  }

  void _onResponse(
    int requestId,
    int eventTypeValue,
    int errorCodeValue,
    Uint8List data,
    Uint8List error,
  ) {
    final call = _calls[requestId];
    if (call == null) return;
    final controller = call.controller;
    if (controller.isClosed) {
      _finishCall(requestId);
      return;
    }

    if (eventTypeValue == EventType.complete) {
      _finishCall(requestId);
      controller.close();
      return;
    }

    if (eventTypeValue == EventType.streamChunk) {
      controller.add(
        AxiomState.success(data, AxiomSource.network, isStreaming: true),
      );
      return;
    }

    if (eventTypeValue == EventType.error) {
      var richError = parseRuntimeError(errorCodeValue, error);
      if (richError.isCancelled && call.timedOut) {
        richError = AxiomError(
          stage: ErrorStage.networkReceive,
          category: ErrorCategory.timeout,
          code: const NetworkTimeout(),
          message: 'Request timed out (per-call timeout)',
          retryable: true,
        );
      }
      _logTransaction('IN', requestId, 'error ${richError.message}');
      if (!richError.isCancelled) {
        _reportError(richError, call.namespace, call.endpointId, requestId);
      }
      controller.add(AxiomState.error(richError));
      return;
    }

    if (data.isNotEmpty) {
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
  }

  void _finishCall(int requestId) {
    final call = _calls.remove(requestId);
    call?.timeout?.cancel();
  }

  void _reportError(
    AxiomError error,
    String? namespace,
    int? endpointId,
    int? requestId,
  ) {
    if (_errors.hasListener) {
      _errors.add(
        AxiomErrorEvent(
          error,
          namespace: namespace,
          endpointId: endpointId,
          requestId: requestId,
        ),
      );
    }
  }

  /// Builds an [AxiomError] from an error event. Tolerates non-JSON messages
  /// (cancellation is plain text) and JSON missing fields.
  static AxiomError parseRuntimeError(int code, Uint8List bytes) {
    final text = bytes.isEmpty ? '' : utf8.decode(bytes, allowMalformed: true);
    if (code == FfiError.cancelled) {
      return AxiomError(
        stage: ErrorStage.runtime,
        category: ErrorCategory.runtime,
        code: const Cancelled(),
        message: text.isEmpty ? 'Request cancelled' : text,
        retryable: false,
      );
    }
    if (text.isNotEmpty) {
      try {
        final json = jsonDecode(text);
        if (json is Map<String, dynamic>) {
          return _withFailure(
            AxiomError(
              stage: ErrorStage.fromString('${json['stage'] ?? 'runtime'}'),
              category: ErrorCategory.fromString(
                '${json['category'] ?? _categoryFor(code).name}',
              ),
              code: json['code'] == null
                  ? _codeFor(code)
                  : AxiomErrorCode.fromJson(json['code']),
              message: '${json['message'] ?? FfiError.name(code)}',
              retryable: json['retryable'] == true,
              details: json['details']?.toString(),
              failureCode: (json['failure_code'] ?? json['failureCode'])
                  ?.toString(),
              failurePayload: json['failure_payload'] ?? json['failurePayload'],
            ),
          );
        }
      } catch (_) {
        // fall through: plain text
      }
    }
    return AxiomError(
      stage: ErrorStage.runtime,
      category: _categoryFor(code),
      code: _codeFor(code),
      message: text.isEmpty ? FfiError.name(code) : text,
      retryable: code == FfiError.networkError || code == FfiError.timeout,
    );
  }

  /// Fills [AxiomError.failureCode]/[AxiomError.failurePayload] from a
  /// contract failure body carried in `details` (`{"error": "<code>", ...}`
  /// or `{"failure": {"code": ..., "payload": ...}}`), when the runtime did
  /// not set them.
  static AxiomError _withFailure(AxiomError e) {
    if (e.failureCode != null || e.details == null) return e;
    try {
      final body = jsonDecode(e.details!);
      if (body is! Map) return e;
      String? code;
      Object? payload;
      final failure = body['failure'];
      if (failure is Map) {
        code = failure['code']?.toString();
        payload = failure['payload'] ?? failure['data'];
      } else if (body['failure_code'] != null || body['failureCode'] != null) {
        code = (body['failure_code'] ?? body['failureCode']).toString();
        payload = body['failure_payload'] ?? body['failurePayload'];
      } else if (body['error'] is Map &&
          (body['error'] as Map)['code'] != null &&
          (body['error'] as Map).containsKey('payload')) {
        final err = body['error'] as Map;
        code = err['code'].toString();
        payload = err['payload'];
      } else if (body['error'] is String &&
          (body['payload'] != null || body['data'] != null)) {
        code = body['error'] as String;
        payload = body['payload'] ?? body['data'];
      } else if (body['code'] is String &&
          (body['payload'] != null || body['data'] != null)) {
        code = body['code'] as String;
        payload = body['payload'] ?? body['data'];
      }
      if (code == null) return e;
      return AxiomError(
        stage: e.stage,
        category: e.category,
        code: e.code,
        message: e.message,
        retryable: e.retryable,
        details: e.details,
        failureCode: code,
        failurePayload: payload,
      );
    } catch (_) {
      return e;
    }
  }

  static ErrorCategory _categoryFor(int code) => switch (code) {
    FfiError.networkError => ErrorCategory.network,
    FfiError.timeout => ErrorCategory.timeout,
    FfiError.authError => ErrorCategory.auth,
    FfiError.serverError => ErrorCategory.server,
    FfiError.invalidContract ||
    FfiError.contractNotLoaded ||
    FfiError.unknownEndpoint => ErrorCategory.contract,
    FfiError.responseDeserializationFailed => ErrorCategory.serialization,
    FfiError.requestParsingFailed => ErrorCategory.validation,
    _ => ErrorCategory.runtime,
  };

  static AxiomErrorCode _codeFor(int code) => switch (code) {
    FfiError.timeout => const NetworkTimeout(),
    FfiError.networkError => const NetworkConnectionFailed(),
    FfiError.contractNotLoaded => const ContractMissing(),
    FfiError.invalidContract => const ContractInvalid(),
    FfiError.unknownEndpoint => const EndpointNotFound(),
    FfiError.cancelled => const Cancelled(),
    _ => UnknownCode(FfiError.name(code)),
  };

  @override
  bool get isInitialized => _initialized;

  @override
  AxiomInitResult? get initResult => _initResult;

  AxiomRuntimeInfo? _runtimeInfo;

  @override
  AxiomRuntimeInfo get runtimeInfo => _runtimeInfo ??= _readRuntimeInfo();

  AxiomRuntimeInfo _readRuntimeInfo() {
    int read(String symbol) {
      if (!_has(symbol)) return 0;
      return _lib.lookupFunction<_AxiomU32Native, _AxiomU32>(symbol)();
    }

    return AxiomRuntimeInfo(
      abiVersion: read('axiom_abi_version'),
      dataAbiVersion: read('axiom_data_abi_version'),
      contractReaderVersion: read('axiom_contract_reader_version'),
    );
  }

  @override
  Future<AxiomInitResult> initialize(
    AxiomConfig config, {
    AxiomAssetLoader? assetLoader,
  }) {
    final pending = _initResultFuture;
    if (pending != null) {
      return pending.then(
        (r) => AxiomInitResult(
          ok: r.ok,
          error: r.error,
          runtimeInfo: r.runtimeInfo,
          contracts: r.contracts,
          duration: r.duration,
          alreadyInitialized: true,
        ),
      );
    }
    final future = _initialize(config, assetLoader);
    _initResultFuture = future;
    return future;
  }

  Future<AxiomInitResult> _initialize(
    AxiomConfig config,
    AxiomAssetLoader? assetLoader,
  ) async {
    final watch = Stopwatch()..start();
    debug = config.debug;
    final info = runtimeInfo;
    if (!info.isCompatible) {
      final result = AxiomInitResult(
        ok: false,
        error: AxiomVersionMismatch(info),
        runtimeInfo: info,
        duration: watch.elapsed,
      );
      _initResult = result;
      return result;
    }
    try {
      await init(config.dbPath);
    } catch (e) {
      final result = AxiomInitResult(
        ok: false,
        error: e,
        runtimeInfo: info,
        duration: watch.elapsed,
      );
      _initResult = result;
      return result;
    }

    final loader =
        assetLoader ??
        (String path) async => (await rootBundle.load(path)).buffer.asUint8List();
    final contracts = <String, AxiomContractLoadResult>{};
    Object? firstError;
    for (final entry in config.contracts.entries) {
      final ns = entry.key;
      final c = entry.value;
      String baseUrl = c.baseUrl;
      AxiomContractLoadResult r;
      try {
        baseUrl = config.resolveBaseUrl(ns);
        final bytes = await loader(c.assetPath);
        r = tryLoadContract(
          namespace: ns,
          baseUrl: baseUrl,
          contractBytes: bytes,
          signature: c.signature,
          publicKey: c.publicKey,
          sha256: c.isLocked ? c.sha256 : null,
        );
        if (r.ok && config.requireSignedContracts && !r.isSigned) {
          r = AxiomContractLoadResult(
            namespace: ns,
            baseUrl: baseUrl,
            status: r.status,
            trust: r.trust,
            error: StateError(
              'Contract "$ns" loaded unsigned but requireSignedContracts '
              'is set',
            ),
          );
        }
      } catch (e) {
        r = AxiomContractLoadResult(
          namespace: ns,
          baseUrl: baseUrl,
          status: FfiError.invalidContract,
          error: e,
        );
      }
      if (r.error != null) firstError ??= r.error;
      contracts[ns] = r;
    }
    final ok = contracts.values.every((r) => r.ok && r.error == null);
    final result = AxiomInitResult(
      ok: ok,
      error: firstError,
      runtimeInfo: info,
      contracts: Map.unmodifiable(contracts),
      duration: watch.elapsed,
    );
    _initResult = result;
    return result;
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
    final r = tryLoadContract(
      namespace: namespace,
      baseUrl: baseUrl,
      contractBytes: contractBytes,
      signature: signature,
      publicKey: publicKey,
      sha256: sha256,
    );
    requireContractLoadStatus(r.status);
  }

  @override
  AxiomContractLoadResult tryLoadContract({
    required String namespace,
    required String baseUrl,
    required Uint8List contractBytes,
    String? signature,
    String? publicKey,
    String? sha256,
  }) {
    final locked = sha256 != null && sha256.isNotEmpty;
    if (locked && _loadContractLockedFfi == null) {
      return AxiomContractLoadResult(
        namespace: namespace,
        baseUrl: baseUrl,
        status: FfiError.runtimeTooOld,
        error: StateError('runtime has no axiom_load_contract_locked'),
      );
    }
    final status = using((Arena arena) {
      final cPtr = arena<Uint8>(contractBytes.length);
      cPtr.asTypedList(contractBytes.length).setAll(0, contractBytes);
      final buf = arena<AxiomBuffer>()
        ..ref.ptr = cPtr
        ..ref.len = contractBytes.length;
      if (locked) {
        return _loadContractLockedFfi!(
          _toAxiomString(namespace, arena),
          _toAxiomString(baseUrl, arena),
          buf.ref,
          _toAxiomString(signature ?? '', arena),
          _toAxiomString(publicKey ?? '', arena),
          _toAxiomString(sha256.toLowerCase(), arena),
        );
      }
      return _loadContractFfi(
        _toAxiomString(namespace, arena),
        _toAxiomString(baseUrl, arena),
        buf.ref,
        _toAxiomString(signature ?? '', arena),
        _toAxiomString(publicKey ?? '', arena),
      );
    });
    final ok = status == FfiError.success || status == FfiError.successUnverified;
    if (ok) {
      _loadedNamespaces.add(namespace);
      if (_setNamespaceTokenFfi != null &&
          (_namespaceTokens[namespace] ?? _globalToken) != null) {
        _applyTokensFor(namespace);
      }
    }
    return AxiomContractLoadResult(
      namespace: namespace,
      baseUrl: baseUrl,
      status: status,
      trust: !ok
          ? null
          : status == FfiError.successUnverified
          ? AxiomContractTrust.unsigned
          : locked
          ? AxiomContractTrust.locked
          : AxiomContractTrust.signed,
      error: ok
          ? null
          : StateError(
              'Axiom contract load failed for "$namespace" '
              '(status $status, ${FfiError.name(status)})',
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Calls
  // ---------------------------------------------------------------------------

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
    final requestId = _nextRequestId++;
    final controller = StreamController<AxiomState<Uint8List>>.broadcast();
    final call = _Call(controller, namespace, endpointId);
    _calls[requestId] = call;
    controller.add(AxiomState.loading());

    final effectiveHeaders = options != null
        ? options.mergeHeaders(headers)
        : headers;

    var finalPath = path;
    pathParams?.forEach(
      (k, v) => finalPath = finalPath.replaceAll('{$k}', v.toString()),
    );

    if (queryParams != null && queryParams.isNotEmpty) {
      final filteredParams = <String, String>{};
      for (final entry in queryParams.entries) {
        if (entry.value != null) {
          filteredParams[entry.key] = entry.value.toString();
        }
      }
      if (filteredParams.isNotEmpty) {
        finalPath +=
            (finalPath.contains('?') ? '&' : '?') +
            Uri(queryParameters: filteredParams).query;
      }
    }

    final traceparent = AxiomTracing.generateTraceparent();
    final headersJson = effectiveHeaders != null && effectiveHeaders.isNotEmpty
        ? jsonEncode(effectiveHeaders)
        : '';

    _logTransaction('OUT', requestId, {
      'ns': namespace,
      'ep': endpointId,
      'm': method,
      'p': finalPath,
    });

    final withOptions = _callWithOptionsFfi;
    final timeout = options?.timeout;
    final nativeTimeout = withOptions != null && timeout != null;
    final callStatus = using((Arena arena) {
      final bPtr = arena<Uint8>(requestBytes.length);
      bPtr.asTypedList(requestBytes.length).setAll(0, requestBytes);
      final b = arena<AxiomBuffer>()
        ..ref.ptr = bPtr
        ..ref.len = requestBytes.length;
      // axiom_call copies every argument before returning.
      if (nativeTimeout) {
        return withOptions(
          requestId,
          _toAxiomString(namespace, arena),
          endpointId,
          _toAxiomString(method, arena),
          _toAxiomString(finalPath, arena),
          _toAxiomString(traceparent, arena),
          _toAxiomString(headersJson, arena),
          b.ref,
          _toAxiomString(
            jsonEncode({
              'timeoutMs': timeout.inMilliseconds,
              if (options!.cacheMode == AxiomCacheMode.refresh)
                'cacheMode': 'refresh',
            }),
            arena,
          ),
        );
      }
      return _callFfi(
        requestId,
        _toAxiomString(namespace, arena),
        endpointId,
        _toAxiomString(method, arena),
        _toAxiomString(finalPath, arena),
        _toAxiomString(traceparent, arena),
        _toAxiomString(headersJson, arena),
        b.ref,
      );
    });

    if (callStatus != 0) {
      final err = AxiomError(
        stage: ErrorStage.requestBuild,
        category: ErrorCategory.runtime,
        code: _initialized
            ? UnknownCode(FfiError.name(callStatus))
            : const NotInitialized(),
        message:
            'Axiom request was rejected before dispatch (status $callStatus).',
        retryable: false,
      );
      _calls.remove(requestId);
      _reportError(err, namespace, endpointId, requestId);
      // Deliver after the caller attached its listener.
      scheduleMicrotask(() {
        controller.add(AxiomState.error(err));
        controller.close();
      });
    } else if (timeout != null && !nativeTimeout) {
      // Runtime without axiom_call_with_options: timer + cancel.
      call.timeout = Timer(timeout, () {
        if (!_calls.containsKey(requestId)) return;
        call.timedOut = true;
        if (!cancel(requestId)) call.timedOut = false;
      });
    }

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
    AxiomCallOptions? options,
  }) {
    final key = AxiomQueryKey.build(
      endpoint: '${namespace}_$endpointId',
      args: args,
    );

    return AxiomQuery(key, (customHeaders) {
      final mergedHeaders = {...?headers, ...customHeaders};
      return AxiomQueryManager().watchRaw<T>(
        key,
        null,
        namespace: namespace,
        endpointId: endpointId,
        cancel: cancel,
        forceRefresh: options?.cacheMode == AxiomCacheMode.refresh,
        create: (force) => _rawStream(
          namespace: namespace,
          endpointId: endpointId,
          method: method,
          path: path,
          headers: force
              ? {...mergedHeaders, axiomCacheModeHeader: 'refresh'}
              : mergedHeaders,
          pathParams: pathParams,
          queryParams: queryParams,
          body: body,
          decoder: decoder,
          options: options,
        ),
      );
    }, runtime: this);
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

    return AxiomQuery(
      key,
      (customHeaders) {
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
          options: options,
        );
      },
      isMutation: true,
      runtime: this,
    );
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
      options: options,
    );
    final requestId = response.requestId;

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
          final err = AxiomError(
            stage: ErrorStage.deserialize,
            category: ErrorCategory.serialization,
            code: const CodecError(),
            message: e.toString(),
            retryable: false,
          );
          _reportError(err, namespace, endpointId, requestId);
          return AxiomState<T>.error(err);
        }
      }
      return state.map((_) => null as T);
    });

    return AxiomActiveStream<T>(requestId, mappedStream);
  }

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
  }) {
    late AxiomChannel<R, S> channel;
    final out = StreamController<AxiomState<R>>.broadcast();
    StreamSubscription<AxiomState<R>>? sub;
    var attempt = 0;

    void connect() {
      final active = _rawStream<R>(
        namespace: namespace,
        endpointId: endpointId,
        method: method,
        path: path,
        headers: headers,
        pathParams: pathParams,
        queryParams: queryParams,
        decoder: decoder,
        options: options,
      );
      channel.updateRequestId(active.requestId);
      sub = active.stream.listen(
        (state) {
          if (state.hasData) attempt = 0;
          if (state.hasError && state.error!.isCancelled && channel.isClosed) {
            return;
          }
          if (!out.isClosed) out.add(state);
        },
        onDone: () {
          if (channel.isClosed || out.isClosed) {
            out.close();
            return;
          }
          final canRetry =
              reconnect.enabled &&
              (reconnect.maxAttempts == null ||
                  attempt < reconnect.maxAttempts!);
          if (!canRetry) {
            out.close();
            return;
          }
          attempt++;
          Timer(reconnect.delayFor(attempt), () {
            if (channel.isClosed || out.isClosed) {
              if (!out.isClosed) out.close();
              return;
            }
            connect();
          });
        },
      );
    }

    channel = AxiomChannel<R, S>(0, out.stream, this, reconnect: reconnect);
    out.onCancel = () {
      if (!channel.isClosed) channel.close();
      sub?.cancel();
    };
    connect();
    return channel;
  }

  // ---------------------------------------------------------------------------
  // Cancellation, session, shutdown
  // ---------------------------------------------------------------------------

  @override
  bool cancel(int requestId) {
    final fn = _cancelFfi;
    if (fn == null || requestId == 0) return false;
    try {
      return fn(requestId) == FfiError.success;
    } catch (_) {
      return false;
    }
  }

  /// Closes every Dart-side call stream with a [Cancelled] error (used when
  /// the runtime drops requests without emitting events).
  void _closeAllCalls(String message) {
    final pending = Map.of(_calls);
    _calls.clear();
    for (final c in pending.values) {
      c.timeout?.cancel();
      if (c.controller.isClosed) continue;
      c.controller.add(
        AxiomState.error(
          AxiomError(
            stage: ErrorStage.runtime,
            category: ErrorCategory.runtime,
            code: const Cancelled(),
            message: message,
            retryable: false,
          ),
        ),
      );
      c.controller.close();
    }
  }

  @override
  Future<void> resetSession() async {
    // axiom_reset_session aborts in-flight tasks and drains queued events
    // without delivering a Cancelled/Complete pair, so close streams here.
    _resetSessionFfi?.call();
    _closeAllCalls('Request cancelled by resetSession');
    // Let the Cancelled events reach query listeners before disposing.
    await Future<void>.delayed(Duration.zero);
    AxiomQueryManager().clear();
    for (final entry in _methodTokens.entries) {
      for (final method in entry.value.keys) {
        _clearNativeToken(entry.key, method);
      }
    }
    _methodTokens.clear();
    _namespaceTokens.clear();
    _globalToken = null;
    // Also drop tokens the runtime stored itself (answers of the auth
    // provider): every namespace / registered method is cleared natively.
    final clearNs = _clearNamespaceTokensFfi;
    if (clearNs != null) {
      for (final ns in _loadedNamespaces) {
        using((Arena arena) => clearNs(_toAxiomString(ns, arena)));
      }
    }
    for (final ns in AxiomContractMetadata.namespacesWithAuth.toList()) {
      for (final m in AxiomContractMetadata.authMethodsFor(ns)) {
        _clearNativeToken(ns, m);
      }
    }
    setAuthProvider(null);
  }

  @override
  Future<void> shutdown() async {
    final starting = _initFuture;
    if (starting == null) {
      _initResultFuture = null;
      _initResult = null;
      return;
    }
    try {
      await starting;
    } catch (_) {}
    for (final id in _calls.keys.toList()) {
      cancel(id);
    }
    // After this returns no callback runs and queued responses are freed
    // by the runtime instead of being delivered.
    _clearCallbackFfi?.call();
    _closeAllCalls('Request cancelled by shutdown');
    await Future<void>.delayed(Duration.zero);
    AxiomQueryManager().clear();

    final isolate = _eventIsolate;
    final port = _mainPort;
    if (isolate != null) {
      final exited = ReceivePort();
      isolate.addOnExitListener(exited.sendPort);
      _eventControl?.send('shutdown');
      try {
        await exited.first.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        isolate.kill(priority: Isolate.immediate);
      }
      exited.close();
    }
    port?.close();
    _eventIsolate = null;
    _eventControl = null;
    _mainPort = null;
    _initFuture = null;
    _initialized = false;
    _initResultFuture = null;
    _initResult = null;
  }

  // ---------------------------------------------------------------------------
  // Cache control
  // ---------------------------------------------------------------------------

  @override
  void invalidate({
    required String namespace,
    String? cacheIdentity,
    int? endpointId,
    Map<String, dynamic>? args,
  }) {
    final manager = AxiomQueryManager();
    if (endpointId != null && args != null) {
      manager.invalidateWhere(
        namespace: namespace,
        key: AxiomQueryKey.build(
          endpoint: '${namespace}_$endpointId',
          args: args,
        ),
      );
      return;
    }
    if (endpointId != null) {
      manager.invalidateWhere(namespace: namespace, endpointIds: {endpointId});
      return;
    }
    if (cacheIdentity != null) {
      final native = _cacheInvalidateIdentityFfi;
      if (native != null) {
        using(
          (Arena arena) => native(
            _toAxiomString(namespace, arena),
            _toAxiomString(cacheIdentity, arena),
          ),
        );
      }
      // Refetch the endpoints the generator registered for the identity
      // (all of the namespace when unknown).
      final ids = AxiomContractMetadata.endpointsForIdentity(
        namespace,
        cacheIdentity,
      );
      manager.invalidateWhere(namespace: namespace, endpointIds: ids);
      return;
    }
    manager.invalidateWhere(namespace: namespace);
  }

  @override
  void setQueryData<T>({
    required String namespace,
    required int endpointId,
    Map<String, dynamic> args = const {},
    required T data,
  }) {
    AxiomQueryManager().setData(
      AxiomQueryKey.build(endpoint: '${namespace}_$endpointId', args: args),
      data,
    );
  }

  @override
  T? getCachedQueryData<T>({
    required String namespace,
    required int endpointId,
    Map<String, dynamic> args = const {},
  }) {
    final value = AxiomQueryManager().dataFor(
      AxiomQueryKey.build(endpoint: '${namespace}_$endpointId', args: args),
    );
    return value is T ? value : null;
  }

  /// Clears the runtime cache of [namespace] (all loaded when null) when the
  /// runtime has `axiom_cache_clear_namespace`; returns false otherwise.
  bool _clearNativeCache(String? namespace) {
    final native = _cacheClearNamespaceFfi;
    if (native == null) return false;
    final targets = namespace == null ? _loadedNamespaces.toList() : [namespace];
    for (final ns in targets) {
      using((Arena arena) => native(_toAxiomString(ns, arena)));
    }
    return true;
  }

  @override
  Future<void> clearCache([String? namespace]) async {
    _clearNativeCache(namespace);
    AxiomQueryManager().clearNamespace(namespace, refetch: true);
  }

  @override
  Future<void> purgeCache([String? namespace]) async {
    _clearNativeCache(namespace);
    AxiomQueryManager().clearNamespace(namespace, refetch: false);
  }

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------

  @override
  Stream<AxiomErrorEvent> get onError => _errors.stream;

  // ---------------------------------------------------------------------------
  // Extensions
  // ---------------------------------------------------------------------------

  void _requireSymbol(String symbol) {
    if (!_has(symbol)) {
      throw AxiomExtensionException(
        symbol,
        FfiError.runtimeTooOld,
        'runtime library has no $symbol',
      );
    }
  }

  AxiomBuffer _toBuffer(Uint8List bytes, Arena arena) {
    final ptr = arena<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    ptr.asTypedList(bytes.length).setAll(0, bytes);
    return arena<AxiomBuffer>().ref
      ..ptr = ptr
      ..len = bytes.length;
  }

  /// Copies and frees a runtime-owned output buffer.
  Object? _takeJson(Pointer<AxiomBuffer> out) {
    final buf = out.ref;
    if (buf.ptr == nullptr || buf.len == 0) return null;
    final text = utf8.decode(buf.ptr.asTypedList(buf.len), allowMalformed: true);
    _lib.lookupFunction<_AxiomFreeBufferNative, _AxiomFreeBuffer>(
      'axiom_free_buffer',
    )(buf);
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  @override
  Future<void> loadExtension(AxiomExtensionPackage package) async {
    _requireSymbol('axiom_extension_load_locked');
    final fn = _lib.lookupFunction<_AxiomExtLoadNative, _AxiomExtLoad>('axiom_extension_load_locked');
    final status = using(
      (Arena arena) => fn(
        _toAxiomString(package.target, arena),
        _toAxiomString(package.configJson, arena),
        _toBuffer(package.packageBytes, arena),
        _toBuffer(package.moduleBytes, arena),
        _toBuffer(package.authorityBytes, arena),
        _toBuffer(package.packageLockBytes, arena),
      ),
    );
    if (status != FfiError.success) {
      throw AxiomExtensionException(
        'loadExtension',
        status,
        FfiError.name(status),
      );
    }
  }

  @override
  Future<Object?> invokeExtension(AxiomExtensionCall call) async {
    _requireSymbol('axiom_extension_invoke');
    final fn = _lib.lookupFunction<_AxiomExtInvokeNative, _AxiomExtInvoke>('axiom_extension_invoke');
    return using((Arena arena) {
      final out = arena<AxiomBuffer>();
      out.ref
        ..ptr = nullptr
        ..len = 0;
      final status = fn(
        _toAxiomString(call.extension, arena),
        _toAxiomString(call.export, arena),
        _toAxiomString(call.interfaceSha256, arena),
        _toAxiomString(call.abiSymbol, arena),
        _toAxiomString(jsonEncode(call.input), arena),
        out,
      );
      final result = _takeJson(out);
      if (status != FfiError.success) {
        final message = result is Map && result['error'] != null
            ? '${result['error']}'
            : FfiError.name(status);
        throw AxiomExtensionException('invokeExtension', status, message);
      }
      return result;
    });
  }

  @override
  void extensionLifecycle(AxiomLifecycleEvent event) {
    _requireSymbol('axiom_extension_lifecycle');
    final fn = _lib.lookupFunction<_AxiomExtLifecycleNative, _AxiomExtLifecycle>('axiom_extension_lifecycle');
    final status = fn(event.code);
    if (status != FfiError.success) {
      throw AxiomExtensionException(
        'extensionLifecycle',
        status,
        FfiError.name(status),
      );
    }
  }

  @override
  Future<Object?> extensionAudit() async {
    _requireSymbol('axiom_extension_audit');
    final fn = _lib.lookupFunction<_AxiomExtAuditNative, _AxiomExtAudit>('axiom_extension_audit');
    return using((Arena arena) {
      final out = arena<AxiomBuffer>();
      out.ref
        ..ptr = nullptr
        ..len = 0;
      final status = fn(out);
      final result = _takeJson(out);
      if (status != FfiError.success) {
        throw AxiomExtensionException(
          'extensionAudit',
          status,
          result is Map ? '${result['error']}' : FfiError.name(status),
        );
      }
      return result;
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AxiomString _toAxiomString(String s, Arena arena) {
    final units = utf8.encode(s);
    final ptr = arena<Uint8>(units.isEmpty ? 1 : units.length);
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
