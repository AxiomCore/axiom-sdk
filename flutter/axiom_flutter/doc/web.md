# axiom_flutter on the web

On web, `axiom_flutter` runs the same Rust runtime as on Android and iOS,
compiled to WebAssembly and bundled in the package
(`lib/assets/wasm/axiom_runtime.js` + `axiom_runtime_bg.wasm`). You add
nothing to `web/index.html`. The digests of the bundled files are recorded in
`runtime-pin.json` (`wasm` section).

## Loading, CSP, sub-paths, compilers

- `initialize()` / `init()` adds the runtime glue as `<script src=...>` and
  loads the wasm by URL. Both URLs come from the Flutter engine's asset
  manager, so the following work unchanged: `flutter run -d chrome`,
  `flutter build web --release`, a sub-path deployment
  (`--base-href /app/`) and a CDN `assetBase`.
- No inline script and no `eval`. The minimum Content-Security-Policy is
  `script-src 'self' 'wasm-unsafe-eval'`, because WebAssembly compilation
  needs `'wasm-unsafe-eval'`. Build with `--no-web-resources-cdn` so that
  CanvasKit is served from your origin. Otherwise also allow
  `https://www.gstatic.com`. If you restrict `connect-src`, it must include
  your own origin (for the wasm fetch) and every backend base URL.
- dart2js and dart2wasm (`flutter build web --wasm`) both work. The
  integration app passes the same checks with both compilers.
- Hot restart: the wasm instance stays in the page (a wasm module cannot be
  unloaded). `initialize()` re-attaches to it. `shutdown()` stops event
  delivery and frees any buffers still in flight.

Verified in headless Chrome (receipts in
`flutter/integration_app/receipts/`): debug; release with `--base-href /app/`
and the CSP above sent as an HTTP header (0 CSP violations); release with
`--wasm`.

## CORS

Browser calls are ordinary `fetch` requests from your page's origin, so the
backend must allow that origin:

- Allow every origin you serve the app from, port included. Flutter's debug
  server picks a random port unless you pass `--web-port`. If the origin is
  not allowed, every call fails with a network error, not an HTTP status.
- In Acore: `cors(origins: [...], methods: [...], headers: [...])`. The headers
  list must include every request header the SDK may send: `content-type`,
  `accept`, `authorization` (bearer), your API-key header (for example
  `x-api-key`), `traceparent` and `tracestate` (sent on every call),
  `x-axiom-cache-mode` (forced refresh), and any custom header passed through
  `AxiomCallOptions.headers`.
- Cookie sessions need `credentials: true` and an explicit origin (no `*`).
- WebSocket: browsers send `Origin` and cannot set `Authorization` on the
  handshake. A WebSocket endpoint protected by a bearer guard cannot be
  reached from a browser. Use a cookie session, or a token the server accepts
  another way. With CLI 0.156.0, a global `cors()` policy also makes the
  server refuse WebSocket upgrades (see `flutter/fixtures/README.md`). The
  integration app therefore runs its WebSocket check against a second fixture
  instance started with `FIXTURE_CORS=0`, passed as
  `--dart-define=FIXTURE_WS_BASE_URL=...`.

## Where the response cache lives

There is no sled database on web. The runtime cache uses the page's
`localStorage`, under keys prefixed `axiom_cache_acore-cache/v1:`. If
localStorage is unavailable (privacy mode, sandboxed iframe, quota), it falls
back to memory for the lifetime of the page.

- The cache is per origin and is shared by every tab of that origin. It
  survives reloads and app restarts until it expires, is cleared, or the user
  clears site data.
- Session-partitioned entries (requests carrying credentials) are tied to the
  runtime session and become unreachable after `resetSession()`.
- `clearCache([ns])` and `purgeCache([ns])` drop the runtime entries of a
  namespace. They need the runtime export `axiom_wasm_cache_clear_namespace`,
  which the bundled build has. With an older wasm only the whole web cache can
  be dropped, by removing the localStorage keys. `invalidate(cacheIdentity:)`
  uses `axiom_wasm_cache_invalidate_identity`.
- `dbPath` in `AxiomConfig` is ignored on web.
- Auth tokens set with `setAuthToken` and friends are held in runtime memory
  only. They are not persisted.

## Feature notes

| Feature | Web behaviour |
| --- | --- |
| Version handshake | `axiom_abi_version`, `axiom_data_abi_version`, `axiom_contract_reader_version` read from the wasm. |
| Locked contract load | `axiom_wasm_load_contract_locked` (sha256 + signature). |
| Cancel / timeout | `axiom_wasm_cancel`. A timeout is enforced by the runtime (`axiom_wasm_call_with_options`); older wasm falls back to a Dart timer plus cancel. Both report `NetworkTimeout`. |
| Auth provider | `axiom_wasm_register_auth_provider`: the runtime asks Dart for a token, Dart answers asynchronously. Older wasm: Dart asks the provider before dispatch, for endpoints that declare auth methods. |
| Namespace / global token | `axiom_wasm_set_namespace_auth_token`; the global token is applied to every loaded namespace. |
| SSE | The runtime forwards raw `text/event-stream` bytes; the SDK passes on the `data:` payload of each event. |
| Extensions | Not supported (the extension host is native only). The four extension methods throw `UnsupportedError`. |
