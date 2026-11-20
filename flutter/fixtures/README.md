# Flutter SDK fixture backend

One self-contained Acore backend (`backend/`) that the released CLI 0.156.0 checks, builds and
serves with managed actions only: no database, no external services. The integration app in
`../integration_app` runs its smoke checks against it.

## Run

```bash
./backend/run.sh            # 127.0.0.1:8791
./backend/run.sh 9000       # another port
AXIOM=~/bin/axiom ./backend/run.sh
```

`run.sh` runs `axiom check`, `axiom build`, `axiom server deployment --static-key`, patches the
deployment to a fixture-only HS256 JWT provider (`backend/tool/jwt.py`), and runs
`axiom run main.acore --deployment .out/deployment.json --host 127.0.0.1 --port PORT`. Build output
goes to `backend/.out/` (git-ignored). Readiness: `curl http://127.0.0.1:8791/_axiom/ready`.

Test credentials (fixture only, never use elsewhere):

- Bearer token: `python3 backend/tool/jwt.py token` (fixed value, expires 2100; also in
  `integration_app/lib/checks/ctx.dart`).
- API key: `fixture-api-key`.

CORS allows `http://127.0.0.1:8792`, `http://localhost:8792`, `http://127.0.0.1:8802` and
`http://localhost:8802` (the web runner's origins).

## Endpoints

| Name | Method and path | Feature | Notes |
| --- | --- | --- | --- |
| `echo` | GET `/echo/{path}?q=&limit=&flag=` | path + query, optional query | echoes inputs; `flag` omitted when absent |
| `everything` | GET `/types/everything` | String, Bool, Int32, Int64 (2^53+1), Float32, Float64, Bytes (base64 `AQID`), DateTime, Json, List, nested model, List of model, Optional (omitted), Optional Map (omitted), enum rule | |
| `createItem` | POST `/items` body `{"name","qty"}` | POST JSON, status 201 | |
| `updateItem` | PUT `/items/{id}` body `{"name","qty"}` | PUT JSON | |
| `deleteItem` | DELETE `/items/{id}` | DELETE | |
| `uploadBytes` | POST `/bytes` body `"AQID"` | Bytes body | single body param: the JSON body is the value itself |
| `claim` | POST `/claims` body `"name"` | typed failure | `"taken"` → 409 `{"error":{"code":"conflict","payload":{"message","existingId"}}}` |
| `cacheNetworkOnly` | GET `/cache/network-only?nonce=` | cache networkOnly, ttl 1m | |
| `cacheCacheFirst` | GET `/cache/cache-first?nonce=` | cache cacheFirst | |
| `cacheNetworkFirst` | GET `/cache/network-first?nonce=` | cache networkFirst | |
| `cacheStale` | GET `/cache/stale-while-revalidate?nonce=` | cache staleWhileRevalidate | |
| `cachedItem` | GET `/cache/items/{id}?nonce=` | `cacheIdentity("fixture.item")`, cacheFirst 5m | |
| `touchItem` | POST `/cache/items/{id}/touch?nonce=` | `invalidates("fixture.item")` | |
| `retried` | GET `/retry?attempt=` | `retry(attempts: 3, onStatus: [502,503,504], Exponential)` | always succeeds |
| `authBearer` | GET `/auth/bearer` | bearer JWT, `guard authenticated` | 401 without a valid token |
| `authApiKeyHeader` | GET `/auth/api-key-header`, header `x-api-key` | API key in header | checked in managed code; wrong key → typed 401 `unauthorized` |
| `authApiKeyQuery` | GET `/auth/api-key-query?api_key=` | API key in query | same check |
| `sse` | GET `/stream/sse` | SSE (`text/event-stream`) | one frame `{"id":"t1","seq":1}`; public |
| `chunked` | GET `/stream/chunked` | HTTP stream (NDJSON) | one frame |
| `wsEcho` | WS `/stream/ws` | bidirectional WebSocket echo of `Ping{text,seq}` | requires the bearer token (WebSockets need per-message authorization); origins limited to the web runner |

## What could not be expressed (CLI 0.156.0, backend profile)

- **Changing response per call.** Managed code has no mutable state and no clock (pure code
  cannot read time; resources need a provider, and there is no built-in stateless counter provider
  without storage). Cache behaviour is observed through `AxiomState.source` on a second identical
  call; every cache endpoint echoes the `nonce` query value so different nonces are different keys.
- **Transient failures for retry.** Same reason: the retry endpoint always succeeds. Proving
  retries needs a fault-injecting proxy (not built).
- **Unions.** The backend type list (`axiom explain --schema`) has no union type.
- **Enums.** There is no `enum` declaration in the backend profile; `color` uses
  `Field(validate: {type: "enum", values: [...]}, type: String)`.
- **Map literals in managed output.** `return {counts: {x: 1}}` fails to type-check against
  `Map<String, Int64>`, so `counts` is `Optional` and omitted. Mixed-type list literals inside
  `Json` are also rejected.
- **API key and bearer at the same time.** A deployment has exactly one `authentication`
  provider. The fixture uses JWT (HS256) for bearer; API keys are verified in managed code by
  comparing the value, not by the `apiKey` provider. Cookie sessions are not covered.
- **Streams.** Managed stream actions emit exactly one frame per call (per message for
  WebSockets), so streams are single-frame. Multi-frame streams need a native producer,
  which the generic CLI cannot load. No Python/Node sidecar was needed.
- **WebSocket with CORS.** With a global `cors(...)` policy the upgrade is refused
  (`403 cors_denied: method is not allowed by CORS`; `cors` methods cannot list `WS`), and
  without an `Origin` header it is refused too (`403 origin_denied`). Run
  `FIXTURE_CORS=0 ./backend/run.sh` to serve a copy without `cors()`: the WebSocket echo then
  works (verified with a raw Node client sending `Origin: http://127.0.0.1:8792` and the bearer
  token), but browser HTTP calls fail CORS. Report to the CLI owners.
- **Literals in `handle(input:)`.** Input mappings accept only `Input.path/query/header/body` values.

## Additions by unit g

- **Signed contracts.** `tool/sign.sh [contract.axiom] [out.json]` signs the contract the way
  axiom-runtime verifies it: `signature = base64(Ed25519(SHA-256(bytes)))`, `publicKey` = base64 of
  the raw 32-byte key, `sha256` = hex. Default: signs `integration_app/assets/axiom/fixture.axiom`
  and writes `integration_app/assets/axiom/fixture.signed.json` (also a `wrongPublicKey`). The key
  pair `tool/fixture-signing-key.pem` is a committed FIXTURE-ONLY key. Re-run after `tool/regen.sh`
  if the contract bytes change (the build is deterministic). (`axiom-keygen sign` signs the raw
  bytes in hex, which the runtime does not accept.)
- **Auth metadata.** `authmeta/` is a second contract with the same `/auth/*` routes plus
  `auth(EndpointAuth(...))` on each endpoint; CLI 0.156.0 publishes that in `endpoints[].auth`
  directly from a native backend contract (no FastAPI `amends`). `authmeta/build.sh` builds it into
  `integration_app/assets/axiom/authmeta.axiom`; the app loads it as namespace `g_authmeta` against
  the running main fixture. The main contract still has `"auth": null` (only `require(guard:)`),
  which is why `auth.bearer_token` fails: adding the same `auth(...)` line to `authBearer` in
  `backend/main.acore` would fix it (not done, to keep endpoint metadata stable for other units).
- **WebSocket on web.** The CLI rejects an unguarded WebSocket (`AXB006 ... per-message
  authorization`; `GuardKind` has only `authenticated`), and the JWT provider reads only
  `Authorization`, which a browser cannot set on the upgrade. `FIXTURE_CORS=0 FIXTURE_AUTH=session
  ./backend/run.sh 8803` serves a copy with a cookie-session provider (`tool/session.py`): the page
  sets cookie `axiom_fixture_session`, which the browser sends on the upgrade. The server also
  demands a CSRF proof header on the upgrade (it sees method `WS`, not `GET`) and forbids `origin`
  as that header, so the fixture names `sec-websocket-extensions`, whose value browsers send
  verbatim. That defeats CSRF and is fixture only. Product findings: (1) cookie-session WebSockets
  cannot carry a real CSRF proof from a browser; (2) bearer-only deployments cannot serve browser
  WebSockets at all.
- **Variants.** `tool/variant-check.sh` adds `variant mobile(include: ["echo", "everything",
  "createItem"])` to a scratch copy, builds it with `--variant mobile`, runs the generator with
  `--variant mobile` and asserts the client has only those endpoints. With CLI 0.156.0 the build
  fails (exit 2): first `AXSERVER_FAILURE_CONTRACT at authApiKeyHeader: unknown public failure
  endpoint` (an `exposeFailure` on an excluded endpoint), and with those included,
  `AXSERVER_AUTHORING at <endpoint>: handle() endpoint is not included in this contract` for every
  excluded managed endpoint (`exclude:` too; the generator's own golden `extras` fixture fails the
  same way). `axiom explain --variant mobile` does list only the three endpoints. Product finding:
  managed backend variants cannot be built. Adding a variant line does not change the default
  build's bytes (same sha256), so it is safe to add to `main.acore` once the CLI accepts it.
