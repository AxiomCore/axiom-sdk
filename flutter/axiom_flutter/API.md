# axiom_flutter runtime-parity API (frozen by unit f1)

This page lists every public member added for runtime parity. Signatures are
final; bodies that say *stub* throw `UnimplementedError('<name>')` until the
native (`runtime_io.dart`), web (`runtime_web.dart`) and generator units
implement them. Everything that existed in 0.147.x keeps its signature and
behaviour. Generated code from generator 0.146.6 compiles unchanged (checked
with `examples/rpc/example/lib/axiom_generated`).

C names are from `axiom-runtime/include/axiom.h`; wasm names are the
`axiom_wasm_*` exports in `axiom-runtime/src/ffi/api.rs`.

## New types

| Type | File | Meaning |
| --- | --- | --- |
| `AxiomRuntimeInfo {abiVersion, dataAbiVersion, contractReaderVersion}` | `runtime_info.dart` | Versions reported by the runtime. `expected` = 1 / 1 / >=3. `isCompatible`, `requireCompatible()` (implemented). |
| `AxiomVersionMismatch` | `runtime_info.dart` | Exception with a readable message telling the user to upgrade runtime binary and package together. |
| `AxiomInitResult {ok, error, runtimeInfo, contracts, duration, alreadyInitialized}` + `requireOk()` | `init_result.dart` | Result of `initialize`. |
| `AxiomContractLoadResult {namespace, baseUrl, status, trust, error}`, `ok`, `isSigned` | `init_result.dart` | Per-contract status. `status` is the raw runtime status (0 signed, -1 unsigned, else `FfiError`). |
| `AxiomContractTrust {unsigned, signed, locked}` | `init_result.dart` | -1 → unsigned, 0 via `axiom_load_contract` with signature → signed, 0 via locked load → locked. |
| `AxiomCallOptions {timeout, headers, cacheMode}`, `mergeHeaders()` | `call_options.dart` | Per-call options. `mergeHeaders` (implemented) adds `x-axiom-cache-mode: refresh` for `AxiomCacheMode.refresh`. |
| `AxiomCacheMode {normal, refresh}`, `axiomCacheModeHeader` | `call_options.dart` | Cache mode; header name constant. |
| `AxiomErrorEvent {error, namespace, endpointId, requestId}` | `errors.dart` | Item of the global error stream. |
| `AxiomFailureRegistry.register(code, decoder, {namespace})`, `decode()`, `unregisterAll()`; `AxiomFailureDecoder` | `errors.dart` | Implemented. Generated `create()` registers one decoder per contract `failure`; `AxiomError.failure()` returns the typed object. |
| `AxiomExtensionPackage`, `AxiomExtensionCall`, `AxiomExtensionException`, `AxiomLifecycleEvent` (codes 0..8) | `extension_host.dart` | Extension inputs/outputs. Lifecycle codes equal the C constants (foreground 0 … appShutdown 8). |
| `AxiomReconnectPolicy {enabled, maxAttempts, initialDelay, maxDelay}`, `.none`, `.auto`, `delayFor(n)` | `channel.dart` | Mirrors contract `reconnect: "none" / "auto"`; exponential back-off (implemented). |
| `AxiomEnvironment {name, baseUrls, defaultBaseUrl}`, `fromDartDefines()` | `config.dart` | Named environment. `fromDartDefines` reads `--dart-define=AXIOM_ENV` / `AXIOM_BASE_URL`. |
| `typedef AxiomAuthProvider = Future<String?> Function(String namespace, String methodName)` | `runtime_interface.dart` | Token refresh callback. |
| `typedef AxiomAssetLoader = Future<Uint8List> Function(String assetPath)` | `runtime_interface.dart` | Asset loading for `initialize` (default `rootBundle`). |
| `Cancelled` (new `AxiomErrorCode` subclass), `FfiError.cancelled = 15` | `state.dart`, `runtime_interface.dart` | Cancellation outcome. |

## Changed existing types (additive)

| Member | Meaning |
| --- | --- |
| `AxiomContractConfig.signature`, `.publicKey`, `.sha256`, `isLocked`, `copyWith` | Contract proof. `sha256` set → locked load. All optional, const constructor kept. |
| `AxiomConfig.environment`, `.baseUrlOverrides`, `.requireSignedContracts`, `resolveBaseUrl(ns)`, `copyWith` | Base URL priority: `baseUrlOverrides` > `environment.baseUrls[ns]` > `environment.defaultBaseUrl` > contract `baseUrl`. Generated code must call `resolveBaseUrl` instead of using the hard-coded URL. `requireSignedContracts` makes `initialize` fail on status -1 (generator sets it in release). |
| `AxiomError.failureCode`, `.failurePayload`, `failure({namespace})`, `isCancelled` | Read from error JSON fields `failure_code` / `failure_payload` (camelCase also accepted). |
| `AxiomQuery(key, factory, {isMutation, runtime})`, `requestId`, `cancel()`, `refresh({force})` | `cancel()` implemented (delegates to `runtime.cancel`). `refresh()` unchanged; `refresh(force: true)` is a stub. |
| `AxiomChannel<ReceiveType, SendType>(id, stream, runtime, {reconnect})`, `requestId`, `updateRequestId()`, `isClosed`, `close()` | Type parameter order kept as `<Receive, Send>` (0.147 order; the brief's `<Send, Receive>` would silently swap meaning for existing users). `close()` implemented via `cancel`. |
| `send`, `sendMutation`, `callStream`: new `AxiomCallOptions? options` | Accepted and currently ignored (stub-level); implementers merge headers and apply timeout. |
| `loadContract(..., sha256)` | `sha256 != null` currently throws `UnimplementedError`; otherwise unchanged. |

## AxiomRuntime members

| Member | Native (C) | Web (wasm) | Behaviour / notes |
| --- | --- | --- | --- |
| `initialize(config, {assetLoader})` → `AxiomInitResult` | `axiom_initialize`, version fns, `axiom_load_contract[_locked]` | `axiom_wasm_initialize`, `axiom_wasm_data_abi_version`, `axiom_wasm_contract_reader_version`, `axiom_wasm_load_contract` | Idempotent (second call returns first result with `alreadyInitialized`). Never throws for load errors. Version mismatch → `ok=false`, `AxiomVersionMismatch`, no contracts loaded. |
| `isInitialized`, `initResult` | – | – | Dart state. |
| `runtimeInfo` | `axiom_abi_version`, `axiom_data_abi_version`, `axiom_contract_reader_version` | data + reader exports | **Web has no transport ABI export**: report `AxiomRuntimeInfo.expectedAbiVersion` (wasm is bundled with the package). |
| `tryLoadContract(...)` → `AxiomContractLoadResult` | `axiom_load_contract` / `axiom_load_contract_locked` | `axiom_wasm_load_contract` | **No wasm locked load export**: on web a `sha256` must be checked in Dart (SHA-256 of the bytes, e.g. WebCrypto `crypto.subtle.digest`) before calling the normal load, plus signature. |
| `cancel(id)` → bool | `axiom_cancel` | `axiom_wasm_cancel` | true if live. Runtime then emits `Error` with FFI code 15 and **plain-text** message `Request cancelled by host`, then `Complete`. Implementers: the current listener does `jsonDecode` on any non-empty error; it must special-case code 15 and build `AxiomError(code: Cancelled())`. |
| `resetSession()` | `axiom_reset_session` | `axiom_wasm_reset_session` | Logout: cancels in-flight, clears session cache, clears Dart query manager, Dart-side tokens and the auth provider. Contracts stay. |
| `shutdown()` | `axiom_clear_callback` + stop event loop isolate | stop JS callback | Idempotent, safe before init; allows `initialize` again (hot restart). |
| `setNamespaceAuthToken`, `clearNamespaceAuthToken`, `setGlobalAuthToken`, `clearGlobalAuthToken` | via `axiom_set_auth_token` | via `axiom_wasm_set_auth_token` | **Runtime gap**: `axiom_set_auth_token` needs a non-empty method name; there is no wildcard. Implement in Dart: keep the token and call `setAuthToken` for each auth method of the namespace (generator to emit the method list per namespace, e.g. a const in the module), and answer the auth provider with it as fallback. |
| `setAuthProvider(provider?)` | `axiom_register_auth_provider` + `axiom_provide_auth_token` | none | **Runtime gap**: the C callback passes only `request_id`; Dart must map id→namespace (it knows it) and pass `methodName: ''`. Also `crate::auth::get_token` is not called by the engine today, so the callback never fires; needs a runtime change. Web: no export; store provider and use it before dispatch. |
| `invalidate({namespace, cacheIdentity, endpointId, args})` | none for identity | none | **Runtime gap**: cacheIdentity invalidation only happens inside the engine after a mutation. Dart can refetch matching active queries with `x-axiom-cache-mode: refresh`; needs contract metadata (generator can emit endpoint→cacheIdentity map) or a new runtime export. |
| `setQueryData`, `getCachedQueryData` | – | – | Dart query manager only (key = `AxiomQueryKey.build('${ns}_$endpointId', args)`). |
| `clearCache([ns])`, `purgeCache([ns])` | none | none | No runtime cache-clear export besides `axiom_reset_session`. Dart: clear query manager state; `clearCache` refetches active queries with refresh mode, `purgeCache` does not. |
| `onError` | – | – | Broadcast stream fed from every error event; excludes `Cancelled`. |
| `openChannel<R,S>(...)` → `AxiomChannel<R,S>` | `axiom_call` + `axiom_send_stream_message` | `axiom_wasm_call` + `axiom_wasm_send_stream_message` | Reconnect per `AxiomReconnectPolicy` in Dart (new request id → `updateRequestId`). For the generator to replace the `connect()` stub. |
| `loadExtension`, `invokeExtension`, `extensionLifecycle`, `extensionAudit` | `axiom_extension_load_locked`, `_invoke`, `_lifecycle`, `_audit` (free output with `axiom_free_buffer`) | none | Web throws `UnsupportedError` (already implemented in `runtime_web.dart`). Native non-zero status → `AxiomExtensionException`. |
| `send/sendMutation/callStream(options:)` | headers into `headers_json` | same | **Runtime gap**: `CallOptions.timeout_ms` is not reachable through `axiom_call` (bridge sets `None`). Implement timeout in Dart: timer → `cancel(id)` → error with `NetworkTimeout`. |

## Cancellation rule (query lifetime)

A non-mutation query's in-flight request is cancelled when the last listener
of its shared stream unsubscribes. The last value stays cached in Dart for
the next listener, which triggers a fresh fetch if the request was
cancelled. Mutations are never cancelled implicitly; call
`AxiomQuery.cancel()`. Implementation belongs in `query_manager.dart`
(`ActiveQuery._onCancel`, currently a no-op) and `AxiomBuilder.dispose`.

## Not covered here

Unions, managed auth, batching, client-side validators (Phase 4/5). The
legacy `init`, `startup`, `loadContract`, `setAuthToken`, `clearAuthToken`,
`sendStreamMessage` remain and are not deprecated yet.
