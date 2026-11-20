### linux-chrome-idle (2026-11-20)

Machine: CPU model not reported (gVisor), 4 vCPU, 32.0 GB RAM, Debian GNU/Linux 12 (bookworm) (kernel 4.19.0-gvisor), gVisor sandbox / container (shared host). Flutter 3.32.0 • channel stable • https://github.com/flutter/flutter.git. Axiom CLI axiom 0.156.0. SDK commit `6cd7d9f (origin/flutter/parity) + benchmark-only changes on flutter/l2`. Browser: Google Chrome 158.0.8127.36 (headless=new, fresh --user-data-dir per launch).

- Web numbers: headless Chrome on a 4 vCPU Linux container (no GPU), release build (dart2js), server on 127.0.0.1. Not a physical device.
- All three clients call the same local Dart server (api/server); see README for method.
- Box was idle (checked with top before every run; see machine.quiet_check). Run 1 was made right after the release build; its small-call medians are 0.1-0.3 ms higher for all three clients, which is what pushes those ~2 ms metrics over the 10% spread.
- axiom pull used the released CLI 0.156.0 with the branch generator resolved through the app's path dependency (the CLI does not read AXIOM_FLUTTER_SDK_PATH).
- The bench drops the Axiom query key after every call (AxiomQueryManager().remove) so each call is a network request; this is the same workload as for dio/http.

#### App benchmarks: web, headless Chrome, release build, 3 full runs (not a physical device)

Each value is the median of the 3 run medians; spread = (max - min) / median of the run medians. Only metrics with spread <= 10% are listed (25 of 44). Time: lower is better; round trips/s: higher is better.

| Measurement | Client | Median | Spread | Run medians |
| --- | --- | --- | --- | --- |
| Cold start, time to first data (median of 5 launches) | Axiom | 262 ms | 2.1% | 266.5 / 261.6 / 261 |
| Cold start, runtime/client init (median of 5 launches) | Axiom | 251 ms | 2.0% | 255.3 / 250.8 / 250.2 |
| Cold start, time to first data (median of 5 launches) | dio + retrofit | 221 ms | 1.8% | 224 / 220 / 221.2 |
| Cold start, time to first data (median of 5 launches) | package:http | 219 ms | 4.1% | 222.7 / 218.9 / 213.8 |
| getItem (~110 B), p95 | dio + retrofit | 2.40 ms | 8.3% | 2.599 / 2.4 / 2.4 |
| getItem (~110 B), p95 | package:http | 2.20 ms | 9.1% | 2.4 / 2.2 / 2.199 |
| createItem (POST), p50 | Axiom | 2.10 ms | 9.5% | 2.2 / 2.099 / 2 |
| createItem (POST), p95 | dio + retrofit | 2.40 ms | 8.4% | 2.601 / 2.399 / 2.401 |
| createItem (POST), p95 | package:http | 2.30 ms | 0.0% | 2.3 / 2.3 / 2.301 |
| listItems 1 000 items (91 KB), p50 | Axiom | 5.30 ms | 3.8% | 5.5 / 5.301 / 5.299 |
| listItems 1 000 items (91 KB), p95 | Axiom | 6.40 ms | 3.1% | 6.4 / 6.4 / 6.199 |
| listItems 1 000 items (91 KB), p50 | dio + retrofit | 3.40 ms | 5.9% | 3.5 / 3.4 / 3.301 |
| listItems 1 000 items (91 KB), p95 | dio + retrofit | 7.20 ms | 9.7% | 7.2 / 7.6 / 6.9 |
| listItems 1 000 items (91 KB), p50 | package:http | 3.10 ms | 6.4% | 3.099 / 3.099 / 2.9 |
| listItems 1 000 items (91 KB), p95 | package:http | 3.60 ms | 5.6% | 3.8 / 3.6 / 3.599 |
| listItems 10 000 items (938 KB), p50 | Axiom | 33.20 ms | 1.5% | 33.3 / 33.201 / 32.799 |
| listItems 10 000 items (938 KB), p50 | dio + retrofit | 18.60 ms | 3.8% | 18.8 / 18.6 / 18.1 |
| listItems 10 000 items (938 KB), p50 | package:http | 13.20 ms | 4.5% | 13.199 / 13 / 13.6 |
| cache hit, 1 000 items, repeat call, p50 | Axiom | 5.00 ms | 6.0% | 5 / 5.199 / 4.899 |
| cache hit, 1 000 items, repeat call, p50 | dio + dio_cache_interceptor | 26.40 ms | 8.7% | 26.601 / 24.3 / 26.4 |
| cache hit, 1 000 items, repeat call, p95 | dio + dio_cache_interceptor | 29.00 ms | 3.1% | 29.7 / 29 / 28.801 |
| Decode only, 10,000 items, p50 (main isolate, no network) | jsonDecode only | 4.10 ms | 4.9% | 4.2 / 4.1 / 4 |
| Decode only, 10,000 items, p50 (main isolate, no network) | Axiom generated models | 10.80 ms | 4.6% | 10.9 / 10.8 / 10.4 |
| Decode only, 10,000 items, p50 (main isolate, no network) | json_serializable | 12.50 ms | 5.6% | 13.101 / 12.4 / 12.5 |
| Decode only, 10,000 items, p50 (main isolate, no network) | manual fromJson | 9.50 ms | 5.3% | 9.2 / 9.7 / 9.5 |

Not stable (spread above 10%, not published as a number): Cold start, runtime/client init (median of 5 launches) dio + retrofit (33%); Cold start, runtime/client init (median of 5 launches) package:http (n/a); getItem (~110 B), p50 Axiom (14%); getItem (~110 B), p95 Axiom (28%); getItem (~110 B), p50 dio + retrofit (16%); getItem (~110 B), p50 package:http (11%); createItem (POST), p95 Axiom (12%); createItem (POST), p50 dio + retrofit (10%); createItem (POST), p50 package:http (11%); listItems 10 000 items (938 KB), p95 Axiom (12%); listItems 10 000 items (938 KB), p95 dio + retrofit (12%); listItems 10 000 items (938 KB), p95 package:http (14%); cache hit, 1 000 items, repeat call, p95 Axiom (15%); Decode only, 1,000 items, p50 (main isolate, no network) jsonDecode only (128%); Decode only, 1,000 items, p50 (main isolate, no network) Axiom generated models (158%); Decode only, 1,000 items, p50 (main isolate, no network) json_serializable (75%); Decode only, 1,000 items, p50 (main isolate, no network) manual fromJson (50%); WebSocket echo, 1 000 sequential round trips web_socket_channel (13%); WebSocket echo, 1 000 sequential round trips Axiom (55%).

#### Client generation time (5 runs each)

| Tool | Mode | Median | Range |
| --- | --- | --- | --- |
| `axiom pull` (end to end) | cold | 2.46 s | 2.41–2.47 s |
| `axiom pull` (end to end) | warm | 2.18 s | 2.14–2.21 s |
| Axiom generator alone | cold | 1.41 s | 1.40–1.48 s |
| Axiom generator alone | warm | 1.17 s | 1.16–1.21 s |
| `dart run build_runner build` (retrofit + json_serializable) | cold | 25.05 s | 24.95–26.36 s |
| `dart run build_runner build` (retrofit + json_serializable) | warm | 2.65 s | 2.54–2.77 s |
| `dart run build_runner build` (retrofit + json_serializable) | warm noop | 2.34 s | 2.31–2.44 s |

cold: tool caches removed (generator snapshot; `build_runner clean`). warm: caches present; build_runner gets a changed comment in both input files; warm noop: nothing changed.

#### Lines of code for the same API (4 endpoints; non-blank, non-comment)

| Approach | Hand-written | Notes | Generated |
| --- | --- | --- | --- |
| Axiom (Acore contract + config + setup) | 70 | 55 without the WebSocket endpoint; 4 are server bodies | 564 |
| dio + retrofit + json_serializable | 57 |  | 171 |
| package:http + manual fromJson | 65 |  | 0 |

Files counted: see `tool/count_loc.py`. The Acore contract also describes the server, so it is not only client code.

#### Android APK size (`flutter build apk --release --split-per-abi`)

| ABI | Baseline (dio + http) | With Axiom SDK | Delta | of which libaxiom_runtime.so | Dart AOT (libapp.so) | web runtime assets (wasm + JS glue) | contract asset | Delta with wasm opt-out |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| arm64-v8a | 14.24 MB | 24.99 MB | 11,004 KB | 9,859 KB | 192 KB | 934 KB | 1 KB | 10,070 KB |
| armeabi-v7a | 11.50 MB | 19.53 MB | 8,220 KB | 7,087 KB | 192 KB | 934 KB | 1 KB | 7,286 KB |
| x86_64 | 15.36 MB | 28.37 MB | 13,324 KB | 12,182 KB | 192 KB | 934 KB | 1 KB | 12,390 KB |

Sizes are bytes inside the APK (the .so files are stored uncompressed, page-aligned; the wasm is compressed). The web runtime assets are shipped in Android builds because Flutter 3.32 has no per-platform assets; the opt-out in `flutter/axiom_flutter/doc/wasm-size.md` removes them (last column). The remainder of the delta is APK metadata/alignment.

#### Web bundle size (`flutter build web --release`)

| File | Baseline | With Axiom SDK | Delta |
| --- | --- | --- | --- |
| main.dart.js | 1,701 KB | 1,743 KB | 42 KB |
| main.dart.js gzip -9 | 500 KB | 514 KB | 14 KB |
| axiom_runtime.js | – | 38 KB | 38 KB |
| axiom_runtime.js:gzip | – | 7 KB | 7 KB |
| axiom_runtime_bg.wasm | – | 2,388 KB | 2,388 KB |
| axiom_runtime_bg.wasm:gzip | – | 924 KB | 924 KB |
| all JS + wasm (incl. CanvasKit) | 17.22 MB | 19.63 MB | 2,469 KB |
| all JS + wasm, gzip -9 | 6.67 MB | 7.59 MB | 944 KB |
| build/web total | 22.72 MB | 25.16 MB | 2.44 MB |


Reproduce: see `flutter/benchmarks/README.md`.

