// Web (wasm) implementation of [AxiomRuntime].
//
// The runtime is the same Rust crate as on native, compiled to
// wasm32-unknown-unknown with wasm-bindgen's `no-modules` glue
// (`lib/assets/wasm/axiom_runtime.js` + `axiom_runtime_bg.wasm`, built by
// `axiom-runtime/scripts/build-wasm-flutter.sh`). Dart calls the raw wasm
// exports (`axiom_wasm_*`, flattened ptr/len arguments) and receives events
// through the imported global `axiom_web_callback` when the host calls
// `axiom_process_responses`. Runtimes that export
// `axiom_wasm_host_notify_version` call the global `axiom_web_notify()` when a
// response is queued and the host drains in a microtask (no polling floor);
// a slow timer stays as a safety net. Older runtimes are polled every 16 ms.
//
// Loading is CSP friendly: the glue is added as `<script src>` (no inline
// script, no eval) and the wasm is compiled with WebAssembly.instantiate,
// which needs `script-src 'self' 'wasm-unsafe-eval'`. Asset URLs come from
// the Flutter engine's asset manager, so `--base-href` sub-paths work.
//
// Optional exports (added in newer runtime builds) are looked up at run time
// with a `typeof` check, so an older bundled wasm keeps working with a
// Dart-side fallback.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

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
import 'internal/auth_headers.dart';
import 'internal/axiom_codec.dart';
import 'internal/sse.dart';
import 'internal/query_key.dart';
import 'internal/tracing.dart';
import 'internal/contract_load_status.dart';
import 'internal/web_json.dart';

AxiomRuntime getRuntime() => AxiomRuntimeWeb();

const String _wasmAssetDir = 'packages/axiom_flutter/lib/assets/wasm';
const String _glueAsset = '$_wasmAssetDir/axiom_runtime.js';
const String _wasmAsset = '$_wasmAssetDir/axiom_runtime_bg.wasm';

const String _unsupportedExtensions =
    'Axiom extensions are not supported on web: the extension host is '
    'wasmtime-based and only exists in the native runtime (Android, iOS, '
    'macOS). Guard the call with `kIsWeb`.';

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

  @JS('axiom_wasm_load_contract_locked')
  external int axiomLoadContractLocked(
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
    int hPtr,
    int hLen,
  );

  @JS('axiom_wasm_call')
  external int axiomCall(
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
    int hPtr,
    int hLen,
    int bPtr,
    int bLen,
  );

  @JS('axiom_wasm_cancel')
  external int axiomCancel(JSNumber reqId);

  @JS('axiom_wasm_reset_session')
  external void axiomResetSession();

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

  // Optional exports from unit r (runtime cache control).
  // Optional exports (runtime 0.157 additive ABI, unit r + c wrappers).
  @JS('axiom_wasm_cache_invalidate_identity')
  external int axiomInvalidateCache(int nPtr, int nLen, int iPtr, int iLen);

  @JS('axiom_wasm_cache_clear_namespace')
  external int axiomClearCache(int nPtr, int nLen);

  // Optional export (runtime 0.150.1): response validation policy.
  @JS('axiom_wasm_set_validation_policy')
  external int axiomSetValidationPolicy(int nPtr, int nLen, int pPtr, int pLen);

  @JS('axiom_wasm_call_with_options')
  external int axiomCallWithOptions(
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
    int hPtr,
    int hLen,
    int bPtr,
    int bLen,
    int oPtr,
    int oLen,
  );

  @JS('axiom_wasm_register_auth_provider')
  external void axiomRegisterAuthProvider();

  @JS('axiom_wasm_clear_auth_provider')
  external void axiomClearAuthProvider();

  @JS('axiom_wasm_provide_auth_token')
  external void axiomProvideAuthToken(JSNumber reqId, int tPtr, int tLen);

  @JS('axiom_wasm_set_namespace_auth_token')
  external int axiomSetNamespaceAuthToken(
    int nPtr,
    int nLen,
    int tPtr,
    int tLen,
  );

  @JS('axiom_wasm_clear_namespace_auth_tokens')
  external int axiomClearNamespaceAuthTokens(int nPtr, int nLen);

  @JS('axiom_abi_version')
  external int axiomAbiVersion();

  @JS('axiom_data_abi_version')
  external int axiomDataAbiVersion();

  @JS('axiom_contract_reader_version')
  external int axiomContractReaderVersion();

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

/// Book-keeping for one in-flight runtime request.
class _Request {
  _Request(this.controller, this.namespace, this.endpointId);
  final StreamController<AxiomState<Uint8List>> controller;
  final String namespace;
  final int endpointId;
  Timer? timeout;
  bool timedOut = false;

  /// Server-Sent Events framing detected on the first chunk; null = unknown.
  bool? sse;
  AxiomSseParser? sseParser;
}

/// What the SDK knows about a `send` query key (for invalidate/setQueryData).
class _QueryMeta {
  _QueryMeta(this.namespace, this.endpointId, this.args);
  final String namespace;
  final int endpointId;
  final Map<String, dynamic> args;
}

/// Contract facts read from the `.axiom` JSON at load time.
class _ContractMeta {
  /// endpoint id -> auth method names the runtime looks tokens up by.
  final Map<int, List<String>> authMethods = {};

  /// endpoint id -> cache identity (`ui_contract_metadata.operations`).
  final Map<int, String> cacheIdentity = {};

  /// endpoint name -> id.
  final Map<String, int> endpointIds = {};

  /// C3.1: endpoints a plain `fetch` can serve exactly like the runtime
  /// before the wasm is ready: GET, no auth, network_only cache, no retry
  /// policy, no streaming, no response validator, not void, not a mutation.
  final Set<int> fastGet = {};

  /// Endpoints whose responses get the runtime's JSON syntax check.
  final Set<int> validated = {};

  /// The contract has a cookie-session auth method (the runtime then sends
  /// credentials on every call of the namespace).
  bool cookieSession = false;

  /// Some endpoint declares auth (any kind).
  bool anyAuth = false;

  /// Parsed without errors (fast start needs the full picture).
  bool complete = false;

  Set<String> get allAuthMethods => {for (final m in authMethods.values) ...m};

  static _ContractMeta parse(Uint8List bytes) {
    final meta = _ContractMeta();
    try {
      final root = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      if (root is! Map) return meta;
      final validators = root['validators'];
      final validatorNames = validators is Map
          ? validators.keys.map((k) => '$k').toSet()
          : <String>{};
      final candidates = <int>{};
      final endpoints = root['endpoints'];
      if (endpoints is List) {
        for (final e in endpoints) {
          if (e is! Map) continue;
          final id = (e['id'] as num?)?.toInt();
          if (id == null) continue;
          final name = e['name'];
          if (name is String) meta.endpointIds[name] = id;
          final auth = e['auth'];
          if (auth != null) meta.anyAuth = true;
          if (auth is Map && auth['methods'] is List) {
            final names = <String>[];
            for (final m in auth['methods'] as List) {
              if (m is! Map) continue;
              final n = (m['name'] ?? m['type']);
              final location = m['location'];
              final type = m['type'];
              // Cookie sessions are handled by the browser, not by tokens.
              // Same predicate as the runtime (engine.rs
              // is_cookie_session_method): type "session" in any case, and a
              // missing location counts as cookie.
              if (type is String &&
                  type.toLowerCase() == 'session' &&
                  (location == null ||
                      (location is String &&
                          location.toLowerCase() == 'cookie'))) {
                meta.cookieSession = true;
                continue;
              }
              if (n is String && n.isNotEmpty) names.add(n);
            }
            meta.authMethods[id] = names;
          }
          final validated = e['validation_enabled'] == true;
          if (validated) meta.validated.add(id);
          final cache = e['cache_policy'];
          final ret = e['return_type'];
          final retKind = ret is Map ? ret['kind'] : null;
          final hasValidator =
              retKind == 'named' && validatorNames.contains('${ret['value']}');
          if (e['method'] == 'GET' &&
              auth == null &&
              // Validated bodies need the runtime's own JSON check (M1).
              !validated &&
              (cache == null ||
                  (cache is Map && cache['strategy'] == 'network_only')) &&
              e['retry_policy'] == null &&
              e['streaming'] == null &&
              retKind is String &&
              retKind != 'void' &&
              !(validated && hasValidator)) {
            candidates.add(id);
          }
        }
      }
      final ui = root['ui_contract_metadata'];
      if (ui is Map && ui['operations'] is List) {
        for (final op in ui['operations'] as List) {
          if (op is! Map) continue;
          final id = ((op['endpoint_id'] ?? op['endpointId']) as num?)?.toInt();
          final identity = op['cache_identity'] ?? op['cacheIdentity'];
          if (id != null && identity is String) {
            meta.cacheIdentity[id] = identity;
          }
          final kind = op['operation_kind'] ?? op['operationKind'];
          if (id != null && kind != null && kind != 'query') {
            candidates.remove(id);
          }
        }
      }
      // Review B3: a namespace with any auth declaration (cookie session or
      // anything the Dart side does not reproduce) gets no fast start.
      if (!meta.cookieSession && !meta.anyAuth) {
        meta.fastGet.addAll(candidates);
      }
      meta.complete = true;
    } catch (_) {
      // Non-JSON or unknown contract encoding: no metadata, runtime still
      // validates the contract itself.
    }
    return meta;
  }
}

class AxiomRuntimeWeb implements AxiomRuntime {
  static AxiomRuntimeWeb? _instance;
  factory AxiomRuntimeWeb() => _instance ??= AxiomRuntimeWeb._internal();
  AxiomRuntimeWeb._internal();

  final _requests = <int, _Request>{};
  // Seeded from the clock: after a hot restart the wasm instance (and its
  // in-flight requests) survive while Dart state restarts, so ids must not
  // start at 1 again. Stays below 2^53 (ids cross JS as numbers).
  int _nextRequestId =
      (DateTime.now().millisecondsSinceEpoch % 100000000) * 10000 + 1;
  WasmExports? _wasmOrNull;
  Future<void>? _loading;
  Timer? _pump;
  bool _started = false;

  Future<AxiomInitResult>? _initializing;
  AxiomInitResult? _initResult;

  final _errors = StreamController<AxiomErrorEvent>.broadcast();

  // Tokens set from Dart, so resetSession can clear them and namespace /
  // global tokens can be re-applied when a contract is loaded later.
  final _methodTokens = <String, Map<String, String>>{};
  final _namespaceTokens = <String, String>{};
  String? _globalToken;
  final _appliedTokens = <String, Map<String, String>>{};
  final _runtimeNamespaceTokens = <String, String>{};
  AxiomAuthProvider? _authProvider;

  final _contracts = <String, _ContractMeta>{};
  final _queries = <String, _QueryMeta>{};
  final _overrides = <String, Object?>{};
  final _forceRefresh = <String>{};
  final _lastData = <String, Object?>{};

  @override
  bool debug = false;

  /// C1.1: response bodies the runtime handed over as the browser's own
  /// ArrayBuffer (`axiom_web_body`), by request id, until their
  /// NetworkSuccess event arrives. Value: (buffer, flags).
  final _externalBodies = <int, (JSArrayBuffer, int)>{};

  /// Bodies already parsed in [_onEvent] (JSON syntax check), so the decoder
  /// does not parse them again.
  static final Expando<_Parsed> _parsedBodies = Expando('axiomParsedBody');

  /// When false the runtime copies every body through wasm memory as before
  /// 0.150.1 (the hook is not installed). Set before initialize().
  static bool externalBodies = true;

  /// Benchmark hook: turns the C1.1 hand-over on or off for later calls
  /// (the runtime looks the global up per response).
  static void debugSetExternalBodies(bool on) {
    externalBodies = on;
    final rt = _instance;
    if (rt != null && rt._pump != null) rt._setupBodyHook();
  }

  /// Test hook: bodies received through `axiom_web_body` so far.
  static int debugExternalBodyCount = 0;

  /// C3.1 fast start, OPT-IN (`--dart-define=AXIOM_WEB_FAST_START=true`):
  /// initialize() returns once the contract assets are read when no contract
  /// needs verification, and eligible GETs run as a plain `fetch` until the
  /// wasm is ready. Caveat: the contract has then not been accepted by the
  /// runtime yet (header/version checks run when the wasm is up); if that
  /// fails later, the failure goes to onError, initResult is replaced and
  /// every queued and later call fails with it. Default: initialize() waits
  /// for the runtime (review B2).
  static bool fastStart = const bool.fromEnvironment(
    'AXIOM_WEB_FAST_START',
    defaultValue: false,
  );

  /// Test hook: calls served by the fast-start fetch so far.
  static int debugFastStartCount = 0;

  /// Completes when the runtime finished starting in the background (fast
  /// start only); null when initialize() waited for it.
  Future<void>? _runtimeReady;
  Object? _runtimeStartError;
  final _fastBaseUrls = <String, String>{};
  final _fastAborts = <int, web.AbortController>{};

  /// Test hook (integration checks only): when set, the next dispatch in
  /// [callStream] fails synchronously as if the wasm call threw.
  bool? debugFailNextDispatch;

  WasmExports get _wasm {
    final w = _wasmOrNull;
    if (w == null) {
      throw StateError(
        'Axiom runtime is not initialized: call AxiomRuntime().initialize() '
        '(or init()) first.',
      );
    }
    return w;
  }

  bool _hasExport(String name) {
    final w = _wasmOrNull;
    if (w == null) return false;
    return (w as JSObject).has(name) &&
        (w as JSObject)[name].typeofEquals('function');
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Absolute URL of a package asset, honouring `<base href>` and
  /// `assetBase` (CDN) configuration.
  static String _assetUrl(String asset) {
    final rel = ui_web.assetManager.getAssetUrl(asset);
    return Uri.parse(web.document.baseURI).resolve(rel).toString();
  }

  Future<void> _loadGlue() async {
    if (globalContext.has('wasm_bindgen')) return;
    final url = _assetUrl(_glueAsset);
    final script = web.HTMLScriptElement()
      ..type = 'text/javascript'
      ..src = url;
    final done = Completer<void>();
    script.addEventListener(
      'load',
      ((web.Event _) {
        if (!done.isCompleted) done.complete();
      }).toJS,
    );
    script.addEventListener(
      'error',
      ((web.Event _) {
        if (!done.isCompleted) {
          done.completeError(
            StateError('Axiom: failed to load the runtime glue from $url'),
          );
        }
      }).toJS,
    );
    web.document.head!.appendChild(script);
    await done.future;
    if (!globalContext.has('wasm_bindgen')) {
      // The no-modules glue declares `let wasm_bindgen` (a global lexical
      // binding, not a window property). The build script appends an
      // assignment to globalThis; an older glue without it cannot be used.
      throw StateError(
        'Axiom: $url did not define globalThis.wasm_bindgen. Rebuild the '
        'bundled runtime with axiom-runtime/scripts/build-wasm-flutter.sh.',
      );
    }
  }

  Future<void> _ensureLoaded() {
    return _loading ??= () async {
      try {
        await _loadGlue();
        final bindgen = globalContext['wasm_bindgen'] as JSFunction;
        // Returns the already-instantiated exports after a hot restart.
        final arg = JSObject()..['module_or_path'] = _assetUrl(_wasmAsset).toJS;
        final exports =
            await (bindgen.callAsFunction(null, arg) as JSPromise).toDart;
        _wasmOrNull = exports as WasmExports;
      } catch (e) {
        _loading = null;
        rethrow;
      }
    }();
  }

  void _start(String? dbPath) {
    _setupWebCallback();
    _setupNotify();
    _setupBodyHook();
    _pump?.cancel();
    // Event-driven runtimes (axiom_wasm_host_notify_version) call
    // `axiom_web_notify` when a response is queued, so the timer is only a
    // safety net. Older bundled runtimes only queue: poll at 16 ms.
    final eventDriven = _hasExport('axiom_wasm_host_notify_version');
    _pump = Timer.periodic(
      Duration(milliseconds: eventDriven ? 250 : 16),
      (_) => _drain(),
    );
    if (!_started) {
      final db = _alloc(dbPath ?? '');
      _wasm.axiomInitialize(db.ptr, db.len);
      _free(db);
      _started = true;
      _applyValidationPolicyDefine();
    }
    if (_authProvider != null) _applyAuthProvider();
  }

  /// `--dart-define=AXIOM_VALIDATION_POLICY=<json>` (e.g. `{"mode":"full"}`)
  /// sets the runtime's global response validation policy. Ignored by
  /// runtimes without `axiom_wasm_set_validation_policy`.
  void _applyValidationPolicyDefine() {
    const policy = String.fromEnvironment('AXIOM_VALIDATION_POLICY');
    if (policy.isEmpty || !_hasExport('axiom_wasm_set_validation_policy')) {
      return;
    }
    final n = _alloc('');
    final p = _alloc(policy);
    try {
      _wasm.axiomSetValidationPolicy(n.ptr, n.len, p.ptr, p.len);
    } finally {
      _free(n);
      _free(p);
    }
  }

  @override
  Future<void> init([String? dbPath]) async {
    await _ensureLoaded();
    if (_pump == null) _start(dbPath);
  }

  @override
  bool get isInitialized => _pump != null || _runtimeReady != null;

  @override
  AxiomInitResult? get initResult => _initResult;

  @override
  AxiomRuntimeInfo get runtimeInfo {
    final w = _wasmOrNull;
    if (w == null) {
      // Not loaded yet: the wasm ships inside this package, so it is the
      // version this package expects.
      return AxiomRuntimeInfo.expected;
    }
    return AxiomRuntimeInfo(
      abiVersion: w.axiomAbiVersion(),
      dataAbiVersion: w.axiomDataAbiVersion(),
      contractReaderVersion: w.axiomContractReaderVersion(),
    );
  }

  @override
  Future<AxiomInitResult> initialize(
    AxiomConfig config, {
    AxiomAssetLoader? assetLoader,
  }) {
    final done = _initResult;
    // Only a successful result is final: a failed initialize() (a contract
    // asset that could not be fetched, ...) can be retried (review F15).
    // Contract loads are idempotent, so a retry reloads all of them.
    if (done != null && done.ok && isInitialized) {
      return Future.value(
        AxiomInitResult(
          ok: done.ok,
          error: done.error,
          runtimeInfo: done.runtimeInfo,
          contracts: done.contracts,
          duration: done.duration,
          alreadyInitialized: true,
        ),
      );
    }
    return _initializing ??= _initialize(
      config,
      assetLoader,
    ).whenComplete(() => _initializing = null);
  }

  Future<AxiomInitResult> _initialize(
    AxiomConfig config,
    AxiomAssetLoader? assetLoader,
  ) async {
    final sw = Stopwatch()..start();
    debug = config.debug;
    _runtimeStartError = null;
    final fast = await _tryFastStart(config, assetLoader, sw);
    if (fast != null) return fast;
    try {
      await _ensureLoaded();
    } catch (e) {
      return AxiomInitResult(ok: false, error: e, duration: sw.elapsed);
    }
    final info = runtimeInfo;
    if (!info.isCompatible) {
      final r = AxiomInitResult(
        ok: false,
        error: AxiomVersionMismatch(info),
        runtimeInfo: info,
        duration: sw.elapsed,
      );
      return r;
    }
    if (_pump == null) _start(config.dbPath);

    final load =
        assetLoader ??
        (String path) async =>
            (await rootBundle.load(path)).buffer.asUint8List();
    final results = <String, AxiomContractLoadResult>{};
    Object? firstError;
    for (final entry in config.contracts.entries) {
      final ns = entry.key;
      final c = entry.value;
      String baseUrl = c.baseUrl;
      AxiomContractLoadResult r;
      try {
        baseUrl = config.resolveBaseUrl(ns);
        final bytes = await load(c.assetPath);
        r = tryLoadContract(
          namespace: ns,
          baseUrl: baseUrl,
          contractBytes: bytes,
          signature: c.signature,
          publicKey: c.publicKey,
          sha256: c.isLocked ? c.sha256 : null,
        );
        if (r.ok && config.requireSignedContracts && r.status == -1) {
          r = AxiomContractLoadResult(
            namespace: ns,
            baseUrl: baseUrl,
            status: r.status,
            trust: r.trust,
            error: StateError(
              'contract "$ns" loaded unsigned but requireSignedContracts is set',
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
      results[ns] = r;
    }
    final ok = results.values.every((r) => r.ok && r.error == null);
    final result = AxiomInitResult(
      ok: ok,
      error: firstError,
      runtimeInfo: info,
      contracts: results,
      duration: sw.elapsed,
    );
    _initResult = result;
    return result;
  }

  /// C3.1: start without waiting for the wasm when nothing must be verified
  /// first. Returns null to use the normal start-up. Never used when
  /// `requireSignedContracts` is set or any contract has a signature, public
  /// key or sha256 lock: those are checked by the runtime before any call.
  Future<AxiomInitResult?> _tryFastStart(
    AxiomConfig config,
    AxiomAssetLoader? assetLoader,
    Stopwatch sw,
  ) async {
    if (!fastStart || _wasmOrNull != null || _runtimeReady != null) {
      return null;
    }
    if (config.requireSignedContracts || config.contracts.isEmpty) return null;
    for (final c in config.contracts.values) {
      if (c.isLocked ||
          (c.signature ?? '').isNotEmpty ||
          (c.publicKey ?? '').isNotEmpty) {
        return null;
      }
    }
    final load =
        assetLoader ??
        (String path) async =>
            (await rootBundle.load(path)).buffer.asUint8List();
    final assets = <String, (String, Uint8List, _ContractMeta)>{};
    try {
      for (final entry in config.contracts.entries) {
        final baseUrl = config.resolveBaseUrl(entry.key);
        final bytes = await load(entry.value.assetPath);
        final meta = _ContractMeta.parse(bytes);
        if (!meta.complete) return null; // let the runtime report it
        assets[entry.key] = (baseUrl, bytes, meta);
      }
    } catch (_) {
      return null; // normal start-up reports the error
    }
    // Start the wasm download and compile only now: started earlier it
    // competes with the contract asset read that initialize() waits for.
    final loading = _ensureLoaded();
    loading.ignore();
    final results = <String, AxiomContractLoadResult>{};
    assets.forEach((ns, a) {
      _contracts[ns] = a.$3;
      _fastBaseUrls[ns] = a.$1;
      results[ns] = AxiomContractLoadResult(
        namespace: ns,
        baseUrl: a.$1,
        status: -1,
        trust: AxiomContractTrust.unsigned,
      );
    });
    final ready = Completer<void>();
    _runtimeReady = ready.future;
    () async {
      try {
        await loading;
        final info = runtimeInfo;
        if (!info.isCompatible) throw AxiomVersionMismatch(info);
        if (_pump == null) _start(config.dbPath);
        final loadResults = <String, AxiomContractLoadResult>{};
        Object? firstError;
        assets.forEach((ns, a) {
          final r = tryLoadContract(
            namespace: ns,
            baseUrl: a.$1,
            contractBytes: a.$2,
          );
          if (r.error != null) firstError ??= r.error;
          loadResults[ns] = r;
          // Per-method tokens set while the runtime was loading.
          _methodTokens[ns]?.forEach((m, t) => _setToken(ns, m, t));
        });
        _initResult = AxiomInitResult(
          ok: firstError == null,
          error: firstError,
          runtimeInfo: info,
          contracts: loadResults,
          duration: sw.elapsed,
        );
        if (firstError != null) _runtimeStartError = firstError;
      } catch (e) {
        _runtimeStartError = e;
      }
      final failed = _runtimeStartError;
      if (failed != null) {
        _errors.add(
          AxiomErrorEvent(
            AxiomError(
              stage: ErrorStage.runtime,
              category: ErrorCategory.runtime,
              code: const UnknownCode('RuntimeStartFailed'),
              message: 'Axiom runtime failed to start after fast start: $failed',
              retryable: false,
            ),
          ),
        );
      }
      if (failed != null && _initResult?.ok != false) {
        _initResult = AxiomInitResult(
          ok: false,
          error: failed,
          duration: sw.elapsed,
        );
      }
      // From here on calls take the normal path (also after a shutdown()).
      _runtimeReady = null;
      ready.complete();
    }();
    final result = AxiomInitResult(
      ok: true,
      runtimeInfo: AxiomRuntimeInfo.expected,
      contracts: results,
      duration: sw.elapsed,
    );
    _initResult = result;
    return result;
  }

  /// Test hook: fast-start eligible endpoint ids for raw contract bytes.
  static Set<int> debugFastGetForContract(Uint8List bytes) =>
      _ContractMeta.parse(bytes).fastGet;

  /// Test hook: endpoint ids of [namespace] the fast-start fetch may serve.
  Set<int> debugFastGetEndpoints(String namespace) => {
    ...?_contracts[namespace]?.fastGet,
  };

  /// True when [callStream] can serve this call with a plain fetch now.
  bool _fastEligible(
    String namespace,
    int endpointId,
    String method,
    Uint8List requestBytes,
    Map<String, String> headers,
    int? timeoutMs,
  ) {
    final meta = _contracts[namespace];
    return meta != null &&
        method == 'GET' &&
        requestBytes.isEmpty &&
        timeoutMs == null &&
        _fastBaseUrls.containsKey(namespace) &&
        meta.fastGet.contains(endpointId) &&
        !headers.keys.any(
          (k) => k.toLowerCase() == axiomCacheModeHeader.toLowerCase(),
        );
  }

  static Uint8List _json(Map<String, Object?> m) =>
      Uint8List.fromList(utf8.encode(jsonEncode(m)));

  /// Delivers an error event + Complete exactly like the runtime does.
  void _fastFail(int id, int code, Map<String, Object?> error) {
    _onEvent(id, EventType.error, code, Uint8List(0), _json(error));
    _onEvent(id, EventType.complete, code, Uint8List(0), Uint8List(0));
  }

  /// The runtime's wasm transport and engine steps for an eligible GET
  /// (http.rs execute, engine.rs fetch_network), done with `fetch`.
  void _fastFetch(
    int id,
    String namespace,
    int endpointId,
    String path,
    Map<String, String> headers,
  ) {
    debugFastStartCount++;
    final abort = web.AbortController();
    _fastAborts[id] = abort;
    final url = '${_fastBaseUrls[namespace]}$path';
    final h = web.Headers();
    headers.forEach((k, v) {
      try {
        h.append(k, v);
      } catch (_) {}
    });
    // Like runtime calls (http.rs: headers.set, replaces a caller value).
    h.set('traceparent', AxiomTracing.generateTraceparent());
    final init = web.RequestInit(
      method: 'GET',
      headers: h,
      credentials: 'omit',
      signal: abort.signal,
    );
    final validated =
        _contracts[namespace]?.validated.contains(endpointId) ?? false;
    () async {
      final web.Response resp;
      try {
        resp = await web.window.fetch(url.toJS, init).toDart;
      } catch (e) {
        if (_fastAborts.remove(id) == null) return; // cancelled
        _fastFail(id, FfiError.networkError, {
          'stage': 'NetworkSend',
          'category': 'Network',
          'code': 'NetworkConnectionFailed',
          'message': 'Network Error',
          'retryable': true,
          'details': null,
          'source': '$e',
        });
        return;
      }
      final JSArrayBuffer buffer;
      try {
        buffer = await resp.arrayBuffer().toDart;
      } catch (e) {
        if (_fastAborts.remove(id) == null) return;
        _fastFail(id, FfiError.networkError, {
          'stage': 'NetworkReceive',
          'category': 'Network',
          'code': 'NetworkConnectionFailed',
          'message': 'Connection cut during body read',
          'retryable': true,
          'details': null,
          'source': '$e',
        });
        return;
      }
      if (_fastAborts.remove(id) == null) return;
      final status = resp.status;
      if (status >= 300) {
        final text = utf8.decode(
          buffer.toDart.asUint8List(),
          allowMalformed: true,
        );
        final details = text.length > 8192 ? text.substring(0, 8192) : text;
        String? message;
        try {
          final v = jsonDecode(details);
          final m = v is Map ? v['message'] : null;
          if (m is String && m.trim().isNotEmpty) message = m;
        } catch (_) {}
        message ??= details.trim().isNotEmpty
            ? details.trim()
            : 'Request failed ($status)';
        _fastFail(
          id,
          status == 401 || status == 403
              ? FfiError.authError
              : status >= 500
              ? FfiError.serverError
              : FfiError.requestFailed,
          {
            'stage': 'NetworkReceive',
            'category': 'Server',
            'code': {'HttpStatus': status},
            'message': message,
            'retryable': false,
            'details': details.isEmpty ? null : details,
            'source': null,
          },
        );
        return;
      }
      if (!_requests.containsKey(id)) return;
      _externalBodies[id] = (
        buffer,
        (validated ? _bodyCheckJson : 0) |
            (status == 204 || status == 205 ? _bodyEmptyOk : 0),
      );
      _onEvent(id, EventType.networkSuccess, 0, Uint8List(0), Uint8List(0));
      _onEvent(id, EventType.complete, 0, Uint8List(0), Uint8List(0));
    }();
  }

  // ---------------------------------------------------------------------------
  // Event callback
  // ---------------------------------------------------------------------------

  Uint8List _copyOut(int ptr, int len) {
    if (ptr == 0 || len == 0) return Uint8List(0);
    final out = Uint8List.fromList(
      Uint8List.view(_wasm.memory.jsBuffer.toDart, ptr, len),
    );
    // The runtime leaks these buffers to the host (mem::forget); capacity
    // equals length, so freeing with (ptr, len) is exact.
    _wasm.axiomFreeMemory(ptr, len);
    return out;
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
              final data = _copyOut(dPtr.toDartInt, dLen.toDartInt);
              final err = _copyOut(ePtr.toDartInt, eLen.toDartInt);
              _onEvent(
                reqId.toDartInt,
                evtType.toDartInt,
                errCode.toDartInt,
                data,
                err,
              );
            })
            .toJS;
  }

  /// The runtime (builds with `axiom_wasm_body_external_version`) calls
  /// `axiom_web_body(id, arrayBuffer, flags)` for a successful JSON body it
  /// does not need to keep, then sends NetworkSuccess with no bytes.
  void _setupBodyHook() {
    if (!externalBodies) {
      globalContext.delete('axiom_web_body'.toJS);
      return;
    }
    globalContext['axiom_web_body'] =
        ((JSNumber reqId, JSArrayBuffer buffer, JSNumber flags) {
              final id = reqId.toDartInt;
              if (_requests.containsKey(id)) {
                _externalBodies[id] = (buffer, flags.toDartInt);
                debugExternalBodyCount++;
              }
            })
            .toJS;
  }

  static const int _bodyCheckJson = 1;
  static const int _bodyEmptyOk = 2;

  static bool _allWhitespace(Uint8List b) {
    for (final c in b) {
      if (c != 0x20 && c != 0x0a && c != 0x0d && c != 0x09) return false;
    }
    return true;
  }

  /// Same error the runtime raises when the JSON syntax check fails
  /// (engine.rs stage_validate_response, `not_json`).
  static AxiomError _notJsonError(Object e) {
    final source = e is FormatException ? e.message : e.toString();
    return _decodeError(
      FfiError.responseDeserializationFailed,
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'stage': 'ValidationResponse',
            'category': 'Validation',
            'code': 'JsonParseError',
            'message': 'Server response is not valid JSON',
            'retryable': false,
            'details': null,
            'source': source,
          }),
        ),
      ),
    );
  }

  bool _drainScheduled = false;

  void _drain() {
    _drainScheduled = false;
    _wasmOrNull?.axiomProcessResponses();
  }

  /// The runtime calls `axiom_web_notify()` (from inside wasm, at most once
  /// per drain) when it queued a response. Draining re-entrantly there is not
  /// allowed, so the drain runs in a microtask: no timer floor.
  void _setupNotify() {
    globalContext['axiom_web_notify'] = (() {
      if (_drainScheduled) return;
      _drainScheduled = true;
      scheduleMicrotask(_drain);
    }).toJS;
  }

  /// Replaces the callback with one that only frees buffers (shutdown).
  void _setupDrainCallback() {
    if (_wasmOrNull == null) return;
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
              _copyOut(dPtr.toDartInt, dLen.toDartInt);
              _copyOut(ePtr.toDartInt, eLen.toDartInt);
            })
            .toJS;
  }

  void _onEvent(
    int id,
    int evt,
    int errCode,
    Uint8List data,
    Uint8List err, {
    AxiomError? preset,
  }) {
    // ignore: parameter_assignments
    final req = _requests[id];
    if (req == null) return;
    final controller = req.controller;

    switch (evt) {
      case EventType.complete:
        if (req.sse == true && !controller.isClosed) {
          for (final e in (req.sseParser ??= AxiomSseParser()).feed(
            Uint8List(0),
            flush: true,
          )) {
            controller.add(
              AxiomState.success(e, AxiomSource.network, isStreaming: true),
            );
          }
        }
        _finish(id);
        return;
      case EventType.streamChunk:
        req.sse ??= AxiomSseParser.looksLike(data);
        if (controller.isClosed) return;
        if (req.sse!) {
          for (final e in (req.sseParser ??= AxiomSseParser()).feed(data)) {
            controller.add(
              AxiomState.success(e, AxiomSource.network, isStreaming: true),
            );
          }
          return;
        }
        controller.add(
          AxiomState.success(data, AxiomSource.network, isStreaming: true),
        );
        return;
      case EventType.error:
        _externalBodies.remove(id);
        var error = preset ?? _decodeError(errCode, err);
        if (req.timedOut && error.isCancelled) {
          error = AxiomError(
            stage: ErrorStage.networkSend,
            category: ErrorCategory.timeout,
            code: const NetworkTimeout(),
            message: 'Request timed out (AxiomCallOptions.timeout)',
            retryable: true,
          );
        }
        if (!error.isCancelled) {
          _errors.add(
            AxiomErrorEvent(
              error,
              namespace: req.namespace,
              endpointId: req.endpointId,
              requestId: id,
            ),
          );
        }
        if (!controller.isClosed) controller.add(AxiomState.error(error));
        return;
      default:
        _Parsed? parsed;
        final external = evt == EventType.networkSuccess && data.isEmpty
            ? _externalBodies.remove(id)
            : null;
        if (external != null) {
          final (buffer, flags) = external;
          data = buffer.toDart.asUint8List();
          if (flags & _bodyCheckJson != 0 &&
              !(flags & _bodyEmptyOk != 0 && _allWhitespace(data))) {
            try {
              parsed = _Parsed(AxiomWebJson.decode(buffer));
            } catch (e) {
              _onEvent(
                id,
                EventType.error,
                FfiError.responseDeserializationFailed,
                Uint8List(0),
                Uint8List(0),
                preset: _notJsonError(e),
              );
              return;
            }
          }
        }
        if (data.isEmpty && evt != EventType.networkSuccess) return;
        if (AxiomSseParser.looksLike(data)) {
          // A whole event-stream body delivered as one response.
          final events = (req.sseParser ??= AxiomSseParser()).feed(
            data,
            flush: true,
          );
          if (events.isNotEmpty) data = events.last;
        }
        if (parsed != null) _parsedBodies[data] = parsed;
        if (!controller.isClosed) {
          controller.add(
            AxiomState.success(
              data,
              (evt == EventType.cacheHit ||
                      evt == EventType.cacheHitAndFetching)
                  ? AxiomSource.cache
                  : AxiomSource.network,
              isFetching: evt == EventType.cacheHitAndFetching,
            ),
          );
        }
    }
  }

  /// Fails a request whose dispatch failed. This can run synchronously inside
  /// [callStream], before the caller has subscribed: a broadcast controller
  /// drops events while it has no listener, so the error would be lost and the
  /// caller would get an already-closed, empty stream (review F9). onError
  /// fires at once; the stream gets the error and closes on its first listen.
  void _failDispatch(int id, int status, String message) {
    final req = _requests.remove(id);
    if (req == null) return;
    req.timeout?.cancel();
    final error = _withFailure(
      _decodeError(status, Uint8List.fromList(utf8.encode(message))),
    );
    if (!error.isCancelled) {
      _errors.add(
        AxiomErrorEvent(
          error,
          namespace: req.namespace,
          endpointId: req.endpointId,
          requestId: id,
        ),
      );
    }
    final controller = req.controller;
    void deliver() {
      if (controller.isClosed) return;
      controller.add(AxiomState.error(error));
      controller.close();
    }

    if (controller.hasListener) {
      deliver();
    } else {
      controller.onListen = () => scheduleMicrotask(deliver);
    }
  }

  void _finish(int id) {
    _externalBodies.remove(id);
    final req = _requests.remove(id);
    if (req == null) return;
    req.timeout?.cancel();
    if (!req.controller.isClosed) req.controller.close();
  }

  /// Builds an [AxiomError] from an error event. The runtime normally sends
  /// AxiomError JSON, but cancellation (code 15) sends plain text and older
  /// paths may send arbitrary bytes, so parsing is tolerant.
  /// Fills [AxiomError.failureCode]/[AxiomError.failurePayload] from a
  /// contract failure body carried in `details` when the runtime did not set
  /// them. Same rules as native (runtime_io.dart `_withFailure`).
  static AxiomError _withFailure(AxiomError e) {
    if (e.failureCode != null || e.details == null) return e;
    try {
      final body = jsonDecode(e.details!);
      if (body is! Map) return e;
      String? code;
      Object? payload;
      final failure = body['failure'];
      final err = body['error'];
      if (failure is Map) {
        code = failure['code']?.toString();
        payload = failure['payload'] ?? failure['data'];
      } else if (body['failure_code'] != null || body['failureCode'] != null) {
        code = (body['failure_code'] ?? body['failureCode']).toString();
        payload = body['failure_payload'] ?? body['failurePayload'];
      } else if (err is Map &&
          err['code'] != null &&
          err.containsKey('payload')) {
        code = err['code'].toString();
        payload = err['payload'];
      } else if (err is String &&
          (body['payload'] != null || body['data'] != null)) {
        code = err;
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

  static AxiomError _decodeError(int errCode, Uint8List bytes) {
    final text = bytes.isEmpty ? '' : utf8.decode(bytes, allowMalformed: true);
    if (errCode == FfiError.cancelled) {
      return AxiomError(
        stage: ErrorStage.runtime,
        category: ErrorCategory.runtime,
        code: const Cancelled(),
        message: text.isEmpty ? 'Request cancelled by host' : text,
        retryable: false,
      );
    }
    if (text.isNotEmpty) {
      try {
        final json = jsonDecode(text);
        if (json is Map<String, dynamic> && json['stage'] != null) {
          return _withFailure(AxiomError.fromJson(json));
        }
      } catch (_) {}
    }
    return AxiomError(
      stage: ErrorStage.runtime,
      category: switch (errCode) {
        FfiError.networkError => ErrorCategory.network,
        FfiError.timeout => ErrorCategory.timeout,
        FfiError.authError => ErrorCategory.auth,
        FfiError.serverError => ErrorCategory.server,
        _ => ErrorCategory.unknown,
      },
      code: switch (errCode) {
        FfiError.timeout => const NetworkTimeout(),
        FfiError.networkError => const NetworkConnectionFailed(),
        _ => UnknownCode(FfiError.name(errCode)),
      },
      message: text.isEmpty ? FfiError.name(errCode) : text,
      retryable:
          errCode == FfiError.networkError || errCode == FfiError.timeout,
    );
  }

  // ---------------------------------------------------------------------------
  // Contracts
  // ---------------------------------------------------------------------------

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
    if (r.error is StateError && r.status != FfiError.invalidContract) {
      throw r.error!;
    }
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
    if (locked && !_hasExport('axiom_wasm_load_contract_locked')) {
      return AxiomContractLoadResult(
        namespace: namespace,
        baseUrl: baseUrl,
        status: FfiError.invalidContract,
        error: UnsupportedError(
          'This web runtime build has no axiom_wasm_load_contract_locked; '
          'rebuild the bundled wasm (runtime >= flutter/f4).',
        ),
      );
    }
    final n = _alloc(namespace),
        b = _alloc(baseUrl),
        c = _allocBytes(contractBytes),
        s = _alloc(signature ?? ''),
        p = _alloc(publicKey ?? ''),
        h = _alloc(sha256 ?? '');
    int status;
    try {
      status = locked
          ? _wasm.axiomLoadContractLocked(
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
              h.ptr,
              h.len,
            )
          : _wasm.axiomLoadContract(
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
    } catch (e) {
      status = FfiError.internalError;
    } finally {
      for (final a in [n, b, c, s, p, h]) {
        _free(a);
      }
    }
    final ok = status == 0 || status == -1;
    if (ok) {
      _contracts[namespace] = _ContractMeta.parse(contractBytes);
      _reapplyTokens(namespace);
    }
    return AxiomContractLoadResult(
      namespace: namespace,
      baseUrl: baseUrl,
      status: status,
      trust: !ok
          ? null
          : status == -1
          ? AxiomContractTrust.unsigned
          : locked
          ? AxiomContractTrust.locked
          : AxiomContractTrust.signed,
      error: ok
          ? null
          : StateError(
              'Axiom contract load failed for "$namespace" '
              '(status $status ${FfiError.name(status)})',
            ),
    );
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

  // ---------------------------------------------------------------------------
  // Calls
  // ---------------------------------------------------------------------------

  String _buildPath(
    String path,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
  ) {
    var fPath = path;
    pathParams?.forEach(
      (k, v) => fPath = fPath.replaceAll('{$k}', v.toString()),
    );
    if (queryParams != null && queryParams.isNotEmpty) {
      final filtered = <String, String>{
        for (final e in queryParams.entries)
          if (e.value != null) e.key: e.value.toString(),
      };
      if (filtered.isNotEmpty) {
        fPath +=
            (fPath.contains('?') ? '&' : '?') +
            Uri(queryParameters: filtered).query;
      }
    }
    return fPath;
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
    AxiomCallOptions? options,
  }) {
    final id = _nextRequestId++;
    // Synchronous: data and the Complete event of one drain reach listeners
    // in the same turn, so a query's "stream closed" flag is set before the
    // next subscriber arrives (otherwise a 2nd identical call could get the
    // old network state instead of a fresh cache read).
    final controller = StreamController<AxiomState<Uint8List>>.broadcast(
      sync: true,
    );
    final req = _Request(controller, namespace, endpointId);
    _requests[id] = req;
    controller.add(AxiomState.loading());

    final fPath = _buildPath(path, pathParams, queryParams);
    var merged = options?.mergeHeaders(headers) ?? {...?headers};
    // Explicit namespace-wide / global token: sent as an Authorization header
    // because backend-profile contracts publish no client auth metadata (same
    // rule as native, internal/auth_headers.dart). Contracts with registered
    // auth methods get the token through the runtime instead.
    final usesRuntimeAuth =
        (_contracts[namespace]?.allAuthMethods.isNotEmpty ?? false);
    if (!usesRuntimeAuth) {
      merged =
          AxiomAuthHeaders.withBearer(
            merged,
            _namespaceTokens[namespace] ?? _globalToken,
          ) ??
          merged;
    }

    // Runtime-enforced timeout when the wasm has axiom_wasm_call_with_options;
    // otherwise a Dart timer cancels the request (see below).
    final nativeOptions = _hasExport('axiom_wasm_call_with_options');
    final timeoutMs = options?.timeout == null
        ? null
        : (options!.timeout!.inMicroseconds / 1000).ceil().clamp(1, 1 << 31);

    void dispatch() {
      if (!_requests.containsKey(id)) return; // cancelled before dispatch
      final hStr = merged.isNotEmpty ? jsonEncode(merged) : '';
      final oStr = nativeOptions && timeoutMs != null
          ? jsonEncode({'timeoutMs': timeoutMs})
          : '';
      final allocs = <_WebAlloc>[];
      _WebAlloc a(_WebAlloc x) {
        allocs.add(x);
        return x;
      }

      int status;
      Object? thrown;
      try {
        final fault = debugFailNextDispatch;
        if (fault == true) {
          debugFailNextDispatch = null;
          throw StateError('debugFailNextDispatch');
        }
        // Inside the try: _alloc throws when the wasm is not loaded yet.
        final n = a(_alloc(namespace)),
            m = a(_alloc(method)),
            p = a(_alloc(fPath)),
            t = a(_alloc(AxiomTracing.generateTraceparent())),
            h = a(_alloc(hStr)),
            br = a(_allocBytes(requestBytes)),
            o = a(_alloc(oStr));
        status = nativeOptions
            ? _wasm.axiomCallWithOptions(
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
                h.ptr,
                h.len,
                br.ptr,
                br.len,
                o.ptr,
                o.len,
              )
            : _wasm.axiomCall(
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
                h.ptr,
                h.len,
                br.ptr,
                br.len,
              );
      } catch (e) {
        status = FfiError.internalError;
        thrown = e;
      } finally {
        for (final x in allocs) {
          try {
            _free(x);
          } catch (_) {}
        }
      }
      if (status != 0) {
        _failDispatch(
          id,
          status,
          thrown == null
              ? 'axiom_wasm_call failed (status $status)'
              : 'axiom_wasm_call failed: $thrown',
        );
        return;
      }
      final timeout = options?.timeout;
      if (timeout != null && !nativeOptions) {
        req.timeout = Timer(timeout, () {
          if (!_requests.containsKey(id)) return;
          req.timedOut = true;
          if (!cancel(id)) {
            // Not live in the runtime any more: report locally.
            _onEvent(
              id,
              EventType.error,
              FfiError.cancelled,
              Uint8List(0),
              Uint8List(0),
            );
            _finish(id);
          }
        });
      }
    }

    final ready = _runtimeReady;
    if (ready != null) {
      // C3.1: the runtime is still loading.
      if (_fastEligible(
        namespace,
        endpointId,
        method,
        requestBytes,
        merged,
        timeoutMs,
      )) {
        _fastFetch(id, namespace, endpointId, fPath, merged);
      } else {
        ready.then((_) {
          if (_pump == null) {
            _failDispatch(
              id,
              FfiError.runtimeTooOld,
              'Axiom runtime failed to start: $_runtimeStartError',
            );
          } else {
            _dispatchWithAuth(namespace, endpointId, dispatch);
          }
        });
      }
      return AxiomStreamResponse(id, controller.stream);
    }
    final startError = _runtimeStartError;
    if (startError != null) {
      // Fast start failed later (review B2): every call fails with it until
      // initialize() succeeds again.
      _failDispatch(
        id,
        FfiError.runtimeTooOld,
        'Axiom runtime failed to start: $startError',
      );
      return AxiomStreamResponse(id, controller.stream);
    }
    _dispatchWithAuth(namespace, endpointId, dispatch);
    return AxiomStreamResponse(id, controller.stream);
  }

  void _dispatchWithAuth(
    String namespace,
    int endpointId,
    void Function() dispatch,
  ) {
    final provider = _authProvider;
    final methods = _contracts[namespace]?.authMethods[endpointId] ?? const [];
    if (provider != null &&
        methods.isNotEmpty &&
        !_hasExport('axiom_wasm_register_auth_provider')) {
      // No runtime auth callback on web: ask the provider before dispatch
      // and hand its answer to the runtime token store.
      () async {
        for (final m in methods) {
          try {
            final token = await provider(namespace, m);
            if (token != null && token.isNotEmpty) {
              _setToken(namespace, m, token);
            }
          } catch (_) {}
        }
        dispatch();
      }();
    } else {
      dispatch();
    }
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
    // Headers and timeout are part of the key (F7, shared AxiomQueryKey rule,
    // same as native): a call that differs only there must not join another
    // call's request.
    String keyFor(Map<String, String> customHeaders) => AxiomQueryKey.build(
      endpoint: '${namespace}_$endpointId',
      args: args,
      headers: {...?headers, ...?options?.headers, ...customHeaders},
      timeout: options?.timeout,
    );
    final baseKey = keyFor(const {});
    _queries[baseKey] = _QueryMeta(namespace, endpointId, args);

    return AxiomQuery<T>(
      baseKey,
      (customHeaders) {
        final key = keyFor(customHeaders);
        _queries[key] = _QueryMeta(namespace, endpointId, args);
        return AxiomQueryManager().watchRaw<T>(
          key,
          null,
          namespace: namespace,
          endpointId: endpointId,
          cancel: cancel,
          forceRefresh: options?.cacheMode == AxiomCacheMode.refresh,
          create: (force) {
            if (_overrides.containsKey(key)) {
              final value = _overrides.remove(key) as T;
              _lastData[key] = value;
              return AxiomActiveStream<T>(
                0,
                Stream.value(AxiomState<T>.success(value, AxiomSource.cache)),
              );
            }
            var opts = options;
            if (_forceRefresh.remove(key) | force) {
              opts = (opts ?? const AxiomCallOptions()).copyWith(
                cacheMode: AxiomCacheMode.refresh,
              );
            }
            final active = _rawStream<T>(
              namespace: namespace,
              endpointId: endpointId,
              method: method,
              path: path,
              headers: {...?headers, ...customHeaders},
              pathParams: pathParams,
              queryParams: queryParams,
              body: body,
              decoder: decoder,
              options: opts,
            );
            return AxiomActiveStream<T>(
              active.requestId,
              active.stream.map((s) {
                if (s.hasData) _lastData[key] = s.data;
                return s;
              }),
            );
          },
        );
      },
      runtime: this,
      keyForHeaders: keyFor,
    );
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
    return AxiomQuery<T>(
      key,
      (customHeaders) => _rawStream<T>(
        namespace: namespace,
        endpointId: endpointId,
        method: method,
        path: path,
        headers: {...?headers, ...customHeaders},
        pathParams: pathParams,
        queryParams: queryParams,
        body: body,
        decoder: decoder,
        options: options,
      ),
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
    return AxiomActiveStream<T>(
      response.requestId,
      response.stream.map((s) => _decodeState<T>(s, decoder)),
    );
  }

  static AxiomState<T> _decodeState<T>(
    AxiomState<Uint8List> state,
    T Function(dynamic json) decoder,
  ) {
    if (state.hasError || state.data == null) {
      return AxiomState<T>(
        status: state.status,
        error: state.error,
        source: state.source,
        isFetching: state.isFetching,
        isMutating: state.isMutating,
        isStreaming: state.isStreaming,
      );
    }
    try {
      final parsed = _parsedBodies[state.data!];
      return AxiomState<T>.success(
        parsed != null
            ? decoder(parsed.value)
            : AxiomCodec.decode(state.data!, decoder),
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
    final out = StreamController<AxiomState<R>>.broadcast();
    late final AxiomChannel<R, S> channel;
    StreamSubscription<AxiomState<Uint8List>>? sub;
    var attempt = 0;

    void connect() {
      final r = callStream(
        namespace: namespace,
        endpointId: endpointId,
        method: method,
        path: path,
        headers: headers,
        pathParams: pathParams,
        queryParams: queryParams,
        requestBytes: Uint8List(0),
        options: options,
      );
      channel.updateRequestId(r.requestId);
      var failed = false;
      sub = r.stream.listen(
        (s) {
          if (s.hasError) {
            if (s.error!.isCancelled) return;
            failed = true;
          } else if (s.hasData) {
            attempt = 0;
          }
          if (!out.isClosed) out.add(_decodeState<R>(s, decoder));
        },
        onDone: () {
          if (channel.isClosed || out.isClosed) {
            if (!out.isClosed) out.close();
            return;
          }
          final max = reconnect.maxAttempts;
          if (reconnect.enabled && (max == null || attempt < max)) {
            attempt++;
            Timer(reconnect.delayFor(attempt), () {
              if (!channel.isClosed) connect();
            });
          } else if (!failed || !reconnect.enabled) {
            out.close();
          } else {
            out.close();
          }
        },
      );
    }

    channel = AxiomChannel<R, S>(0, out.stream, this, reconnect: reconnect);
    connect();
    out.onCancel = () {
      if (!channel.isClosed) {
        channel.close();
      }
      sub?.cancel();
    };
    return channel;
  }

  @override
  void sendStreamMessage({required int requestId, required Uint8List payload}) {
    final b = _allocBytes(payload);
    _wasm.axiomSendMsg(requestId.toJS, b.ptr, b.len);
    _free(b);
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  void _setToken(String namespace, String methodName, String token) {
    // Fast start (C3.1): runtime still loading. The token is kept in
    // _methodTokens and applied by _reapplyTokens when the contract loads.
    if (_pump == null && _runtimeReady != null) return;
    final n = _alloc(namespace), m = _alloc(methodName), t = _alloc(token);
    _wasm.axiomSetAuthToken(n.ptr, n.len, m.ptr, m.len, t.ptr, t.len);
    _free(n);
    _free(m);
    _free(t);
    (_appliedTokens[namespace] ??= {})[methodName] = token;
  }

  void _clearToken(String namespace, String methodName) {
    if (_wasmOrNull == null) return;
    final n = _alloc(namespace), m = _alloc(methodName);
    _wasm.axiomClearAuthToken(n.ptr, n.len, m.ptr, m.len);
    _free(n);
    _free(m);
    _appliedTokens[namespace]?.remove(methodName);
  }

  /// Token for ([namespace], [method]) by precedence: method > namespace >
  /// global.
  String? _effectiveToken(String namespace, String method) =>
      _methodTokens[namespace]?[method] ??
      _namespaceTokens[namespace] ??
      _globalToken;

  /// Pushes the effective token of every known auth method of [namespace]
  /// into the runtime (or clears it).
  void _reapplyTokens(String namespace) {
    if (_wasmOrNull == null) return;
    if (_hasExport('axiom_wasm_set_namespace_auth_token')) {
      // Runtime-side namespace token (0.157): covers every auth method,
      // per-method tokens keep precedence inside the runtime.
      final nt = _namespaceTokens[namespace] ?? _globalToken;
      if (nt != null) {
        if (_runtimeNamespaceTokens[namespace] != nt) {
          final n = _alloc(namespace), t = _alloc(nt);
          _wasm.axiomSetNamespaceAuthToken(n.ptr, n.len, t.ptr, t.len);
          _free(n);
          _free(t);
          _runtimeNamespaceTokens[namespace] = nt;
        }
      } else if (_runtimeNamespaceTokens.remove(namespace) != null) {
        _clearRuntimeNamespaceTokens(namespace);
        // That also dropped per-method tokens: restore the ones set from Dart.
        _methodTokens[namespace]?.forEach((m, t) => _setToken(namespace, m, t));
      }
      return;
    }
    final methods = {
      ...?_contracts[namespace]?.allAuthMethods,
      ...?_methodTokens[namespace]?.keys,
      ...?_appliedTokens[namespace]?.keys,
    };
    for (final m in methods) {
      final t = _effectiveToken(namespace, m);
      if (t == null) {
        if (_appliedTokens[namespace]?.containsKey(m) ?? false) {
          _clearToken(namespace, m);
        }
      } else if (_appliedTokens[namespace]?[m] != t) {
        _setToken(namespace, m, t);
      }
    }
  }

  @override
  void setAuthToken({
    required String namespace,
    required String methodName,
    required String token,
  }) {
    (_methodTokens[namespace] ??= {})[methodName] = token;
    _setToken(namespace, methodName, token);
  }

  @override
  void clearAuthToken({required String namespace, required String methodName}) {
    _methodTokens[namespace]?.remove(methodName);
    final fallback = _namespaceTokens[namespace] ?? _globalToken;
    if (fallback != null &&
        (_contracts[namespace]?.allAuthMethods.contains(methodName) ?? false)) {
      _setToken(namespace, methodName, fallback);
    } else {
      _clearToken(namespace, methodName);
    }
  }

  @override
  void setNamespaceAuthToken({
    required String namespace,
    required String token,
  }) {
    _namespaceTokens[namespace] = token;
    _reapplyTokens(namespace);
  }

  @override
  void clearNamespaceAuthToken({required String namespace}) {
    _namespaceTokens.remove(namespace);
    _reapplyTokens(namespace);
  }

  @override
  void setGlobalAuthToken(String token) {
    _globalToken = token;
    for (final ns in _contracts.keys) {
      _reapplyTokens(ns);
    }
  }

  @override
  void clearGlobalAuthToken() {
    _globalToken = null;
    for (final ns in _contracts.keys) {
      _reapplyTokens(ns);
    }
  }

  void _clearRuntimeNamespaceTokens(String namespace) {
    final n = _alloc(namespace);
    _wasm.axiomClearNamespaceAuthTokens(n.ptr, n.len);
    _free(n);
    _appliedTokens.remove(namespace);
  }

  @override
  void setAuthProvider(AxiomAuthProvider? provider) {
    _authProvider = provider;
    _applyAuthProvider();
  }

  /// With `axiom_wasm_register_auth_provider` the engine asks for a token
  /// (namespace, method) when a required auth method has none; the answer
  /// is always given asynchronously. Without it, [callStream] asks the
  /// provider before dispatch.
  void _applyAuthProvider() {
    if (!_hasExport('axiom_wasm_register_auth_provider')) return;
    final provider = _authProvider;
    if (provider == null) {
      _wasm.axiomClearAuthProvider();
      return;
    }
    globalContext['axiom_web_auth_callback'] =
        ((JSNumber reqId, JSString ns, JSString method) {
          final id = reqId.toDartDouble;
          Timer.run(() async {
            String? token;
            try {
              token = await provider(ns.toDart, method.toDart);
            } catch (_) {}
            final w = _wasmOrNull;
            if (w == null) return;
            final t = _alloc(token ?? '');
            w.axiomProvideAuthToken(id.toJS, t.ptr, t.len);
            _free(t);
          });
        }).toJS;
    _wasm.axiomRegisterAuthProvider();
  }

  // ---------------------------------------------------------------------------
  // Cancellation, session, shutdown
  // ---------------------------------------------------------------------------

  @override
  bool cancel(int requestId) {
    final fast = _fastAborts.remove(requestId);
    if (fast != null) {
      fast.abort();
      _fastFail(requestId, FfiError.cancelled, {
        'stage': 'Runtime',
        'category': 'Runtime',
        'code': 'Cancelled',
        'message': 'Request cancelled by host',
        'retryable': false,
        'details': null,
        'source': null,
      });
      return true;
    }
    final w = _wasmOrNull;
    if (w == null || requestId <= 0) return false;
    try {
      return w.axiomCancel(requestId.toJS) == 0;
    } catch (_) {
      return false;
    }
  }

  void _closeAllRequests(AxiomError? withError) {
    for (final id in _requests.keys.toList()) {
      final req = _requests[id]!;
      if (withError != null && !req.controller.isClosed) {
        req.controller.add(AxiomState.error(withError));
      }
      _finish(id);
    }
  }

  static AxiomError _cancelledError(String why) => AxiomError(
    stage: ErrorStage.runtime,
    category: ErrorCategory.runtime,
    code: const Cancelled(),
    message: why,
    retryable: false,
  );

  @override
  Future<void> resetSession() async {
    final w = _wasmOrNull;
    if (w != null) {
      w.axiomResetSession();
      // Deliver anything the reset queued, then close what is left.
      try {
        w.axiomProcessResponses();
      } catch (_) {}
    }
    _closeAllRequests(_cancelledError('Session reset'));
    AxiomQueryManager().clear();
    _queries.clear();
    _overrides.clear();
    _forceRefresh.clear();
    _lastData.clear();
    for (final ns in _appliedTokens.keys.toList()) {
      for (final m in _appliedTokens[ns]!.keys.toList()) {
        _clearToken(ns, m);
      }
    }
    _appliedTokens.clear();
    if (_hasExport('axiom_wasm_clear_namespace_auth_tokens')) {
      for (final ns in _runtimeNamespaceTokens.keys.toList()) {
        _clearRuntimeNamespaceTokens(ns);
      }
    }
    _runtimeNamespaceTokens.clear();
    _methodTokens.clear();
    _namespaceTokens.clear();
    _globalToken = null;
    _authProvider = null;
    if (_hasExport('axiom_wasm_clear_auth_provider')) {
      _wasm.axiomClearAuthProvider();
    }
  }

  @override
  Future<void> shutdown() async {
    final w = _wasmOrNull;
    if (w != null) {
      for (final id in _requests.keys.toList()) {
        cancel(id);
      }
      try {
        w.axiomProcessResponses();
      } catch (_) {}
    }
    _closeAllRequests(_cancelledError('Runtime shut down'));
    _pump?.cancel();
    _pump = null;
    _setupDrainCallback();
    AxiomQueryManager().clear();
    _queries.clear();
    _overrides.clear();
    _forceRefresh.clear();
    _lastData.clear();
    _initResult = null;
    _initializing = null;
    // The wasm instance, its engine and loaded contracts stay in the page
    // (a wasm module cannot be unloaded); initialize() re-attaches.
  }

  // ---------------------------------------------------------------------------
  // Cache control
  // ---------------------------------------------------------------------------

  Iterable<String> _matchingKeys({
    String? namespace,
    int? endpointId,
    Set<int>? endpointIds,
    Map<String, dynamic>? args,
  }) {
    final argsKey = args == null ? null : jsonEncode(args);
    return _queries.entries
        .where((e) {
          final m = e.value;
          if (namespace != null && m.namespace != namespace) return false;
          if (endpointId != null && m.endpointId != endpointId) return false;
          if (endpointIds != null && !endpointIds.contains(m.endpointId)) {
            return false;
          }
          if (argsKey != null) {
            final k = AxiomQueryKey.build(
              endpoint: '${m.namespace}_${m.endpointId}',
              args: args!,
            );
            if (k != e.key) return false;
          }
          return true;
        })
        .map((e) => e.key)
        .toList();
  }

  void _refetch(Iterable<String> keys, {required bool force}) {
    for (final k in keys) {
      if (force) _forceRefresh.add(k);
      AxiomQueryManager().invalidate(k);
    }
  }

  bool _runtimeInvalidate(String namespace, String identity) {
    if (!_hasExport('axiom_wasm_cache_invalidate_identity')) return false;
    final n = _alloc(namespace), i = _alloc(identity);
    try {
      return _wasm.axiomInvalidateCache(n.ptr, n.len, i.ptr, i.len) == 0;
    } finally {
      _free(n);
      _free(i);
    }
  }

  @override
  void invalidate({
    required String namespace,
    String? cacheIdentity,
    int? endpointId,
    Map<String, dynamic>? args,
  }) {
    final meta = _contracts[namespace];
    if (cacheIdentity != null) {
      _runtimeInvalidate(namespace, cacheIdentity);
      final ids = <int>{
        for (final e in (meta?.cacheIdentity ?? const <int, String>{}).entries)
          if (e.value == cacheIdentity) e.key,
        // Without UI metadata the runtime uses the endpoint name.
        if (meta?.endpointIds[cacheIdentity] case final int id) id,
      };
      _refetch(
        _matchingKeys(namespace: namespace, endpointIds: ids),
        force: true,
      );
      return;
    }
    if (endpointId != null && meta != null) {
      final identity =
          meta.cacheIdentity[endpointId] ??
          meta.endpointIds.entries
              .where((e) => e.value == endpointId)
              .map((e) => e.key)
              .firstOrNull;
      if (identity != null && args == null) {
        _runtimeInvalidate(namespace, identity);
      }
    }
    _refetch(
      _matchingKeys(namespace: namespace, endpointId: endpointId, args: args),
      force: true,
    );
  }

  @override
  void setQueryData<T>({
    required String namespace,
    required int endpointId,
    Map<String, dynamic> args = const {},
    required T data,
  }) {
    final key = AxiomQueryKey.build(
      endpoint: '${namespace}_$endpointId',
      args: args,
    );
    _lastData[key] = data;
    _overrides[key] = data;
    // Refetch of an active query goes through the factory in [send], which
    // serves the override instead of calling the runtime. An inactive key
    // serves it to its next subscriber.
    if (_queries.containsKey(key)) AxiomQueryManager().invalidate(key);
  }

  @override
  T? getCachedQueryData<T>({
    required String namespace,
    required int endpointId,
    Map<String, dynamic> args = const {},
  }) {
    final key = AxiomQueryKey.build(
      endpoint: '${namespace}_$endpointId',
      args: args,
    );
    final v = _lastData[key];
    return v is T ? v : null;
  }

  /// Removes runtime response-cache entries. With the r export this is per
  /// namespace; otherwise only the whole web cache (localStorage keys
  /// `axiom_cache_acore-cache/v1:*`, revisions kept) can be dropped from Dart.
  bool _clearRuntimeCache(String? namespace) {
    if (_hasExport('axiom_wasm_cache_clear_namespace')) {
      var ok = true;
      for (final ns
          in namespace == null ? _contracts.keys.toList() : [namespace]) {
        final n = _alloc(ns);
        try {
          ok = _wasm.axiomClearCache(n.ptr, n.len) == 0 && ok;
        } finally {
          _free(n);
        }
      }
      return ok;
    }
    if (namespace != null) return false;
    try {
      final storage = web.window.localStorage;
      final doomed = <String>[];
      for (var i = 0; i < storage.length; i++) {
        final k = storage.key(i);
        if (k != null &&
            k.startsWith('axiom_cache_acore-cache/v1:') &&
            !k.endsWith(':revision')) {
          doomed.add(k);
        }
      }
      for (final k in doomed) {
        storage.removeItem(k);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _dropDartState(String? namespace) {
    final keys = _matchingKeys(namespace: namespace);
    for (final k in keys) {
      _lastData.remove(k);
      _overrides.remove(k);
    }
    // setQueryData keys that never had a query (`<ns>_<endpointId>:<args>`).
    final own = namespace == null
        ? null
        : RegExp('^${RegExp.escape(namespace)}_\\d+:');
    bool match(String k) => own == null || own.hasMatch(k);
    _lastData.removeWhere((k, _) => match(k));
    _overrides.removeWhere((k, _) => match(k));
  }

  @override
  Future<void> clearCache([String? namespace]) async {
    _clearRuntimeCache(namespace);
    _dropDartState(namespace);
    // Refetch with refresh mode so entries the runtime could not drop (e.g.
    // a single namespace without the clear export) are overwritten.
    _refetch(_matchingKeys(namespace: namespace), force: true);
  }

  @override
  Future<void> purgeCache([String? namespace]) async {
    _clearRuntimeCache(namespace);
    _dropDartState(namespace);
  }

  // ---------------------------------------------------------------------------
  // Errors
  // ---------------------------------------------------------------------------

  @override
  Stream<AxiomErrorEvent> get onError => _errors.stream;

  // ---------------------------------------------------------------------------
  // Extensions (native only)
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadExtension(AxiomExtensionPackage package) =>
      Future.error(UnsupportedError(_unsupportedExtensions));

  @override
  Future<Object?> invokeExtension(AxiomExtensionCall call) =>
      Future.error(UnsupportedError(_unsupportedExtensions));

  @override
  void extensionLifecycle(AxiomLifecycleEvent event) =>
      throw UnsupportedError(_unsupportedExtensions);

  @override
  Future<Object?> extensionAudit() =>
      Future.error(UnsupportedError(_unsupportedExtensions));

  // ---------------------------------------------------------------------------
  // Memory helpers
  // ---------------------------------------------------------------------------

  _WebAlloc _alloc(String s) => _allocBytes(Uint8List.fromList(utf8.encode(s)));

  _WebAlloc _allocBytes(Uint8List b) {
    if (b.isEmpty) return const _WebAlloc(0, 0);
    final ptr = _wasm.axiomMalloc(b.length);
    // Re-read memory.buffer after malloc: growth detaches the old buffer.
    Uint8List.view(_wasm.memory.jsBuffer.toDart, ptr, b.length).setAll(0, b);
    return _WebAlloc(ptr, b.length);
  }

  void _free(_WebAlloc a) {
    if (a.ptr != 0) _wasm.axiomFreeMemory(a.ptr, a.len);
  }
}

class _WebAlloc {
  final int ptr, len;
  const _WebAlloc(this.ptr, this.len);
}

/// A body parsed by the JSON syntax check (value may be null).
class _Parsed {
  _Parsed(this.value);
  final Object? value;
}
