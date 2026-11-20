### linux-chrome (2026-11-20)

Machine: CPU model not reported (gVisor), 4 vCPU, 32.0 GB RAM, Debian GNU/Linux 12 (bookworm) (kernel 4.19.0-gvisor), gVisor sandbox / container (shared host). Flutter 3.32.0 • channel stable • https://github.com/flutter/flutter.git. Axiom CLI axiom 0.156.0. SDK commit `c0360c4`. Browser: Google Chrome 158.0.8127.36.

- Web numbers: headless Chrome on a 4 vCPU Linux container (no GPU), release build (dart2js), server on 127.0.0.1. Not a physical device.
- All three clients call the same local Dart server (api/server); see README for method.
- PRELIMINARY: other jobs (Flutter/wasm builds of parallel work) were using the same 4 vCPUs during both web runs. Only the Axiom per-call medians (16 ms tick floor) and the cache medians were stable; cold start and decode medians moved by up to 85% between runs. The exit gate (second run within 10%) is NOT met: rerun on an idle machine before publishing these web numbers. Tooling, LOC and size numbers are deterministic or low-variance (see ranges).

#### App benchmarks: web, headless Chrome, release build (not a physical device)

Cold start to first data (fresh browser profile per run; timer starts in the first frame, covers client/runtime init, contract load and one `listItems(n:1)`):

| Client | Runs | Median first data | Median init |
| --- | --- | --- | --- |
| axiom | 5 | 309.6 ms | 291.6 ms |
| dio | 5 | 256.9 ms | 0.3 ms |
| http | 5 | 240.8 ms | 0.0 ms |

Per-call latency (sequential calls after 20 warm-up calls):

| Case | Client | Calls | p50 | p95 |
| --- | --- | --- | --- | --- |
| small_get_item | axiom | 200 | 16.00 ms | 16.80 ms |
| small_get_item | dio | 200 | 2.50 ms | 3.40 ms |
| small_get_item | http | 200 | 2.40 ms | 3.70 ms |
| small_create_item | axiom | 200 | 16.00 ms | 16.90 ms |
| small_create_item | dio | 200 | 3.10 ms | 7.70 ms |
| small_create_item | http | 200 | 3.10 ms | 5.40 ms |
| large_list_1000 | axiom | 200 | 16.20 ms | 32.20 ms |
| large_list_1000 | dio | 200 | 7.40 ms | 22.90 ms |
| large_list_1000 | http | 200 | 5.70 ms | 9.10 ms |
| large_list_10000 | axiom | 200 | 71.00 ms | 112.50 ms |
| large_list_10000 | dio | 200 | 34.10 ms | 84.10 ms |
| large_list_10000 | http | 200 | 17.30 ms | 52.70 ms |

Cache hit, time to first data on a repeat call (1 000 items):

| Client | Case | Status | First call | Repeat p50 | Repeat p95 |
| --- | --- | --- | --- | --- | --- |
| axiom | repeat_list_1000 | ok | 87.20 ms | 15.40 ms | 49.50 ms |
| dio_cache_interceptor | repeat_list_1000 | ok | 86.40 ms | 27.90 ms | 76.50 ms |

Decode, bytes to typed models on the main isolate (no network; Axiom runtime-side validation not included):

| Items | Body | Decoder | p50 | p95 |
| --- | --- | --- | --- | --- |
| 1000 | 89 KB | json_only | 2.10 ms | 3.90 ms |
| 1000 | 89 KB | axiom_generated | 2.40 ms | 49.80 ms |
| 1000 | 89 KB | json_serializable | 2.70 ms | 54.00 ms |
| 1000 | 89 KB | manual_fromJson | 1.90 ms | 5.10 ms |
| 10000 | 916 KB | json_only | 7.60 ms | 25.20 ms |
| 10000 | 916 KB | axiom_generated | 53.10 ms | 120.60 ms |
| 10000 | 916 KB | json_serializable | 23.60 ms | 57.70 ms |
| 10000 | 916 KB | manual_fromJson | 11.30 ms | 32.70 ms |

WebSocket echo, sequential round trips (1 000 messages):

| Client | Status | Round trips | Mean RTT | Note |
| --- | --- | --- | --- | --- |
| web_socket_channel | ok | 1123/s | 0.890 ms |  |
| axiom | blocked | – | – | openChannel not implemented on this branch: UnimplementedError: openChannel |

#### Reproducibility: second web run (5 of 25 medians within 10%)

| Metric (p50 / median) | Run 1 | Run 2 | Diff |
| --- | --- | --- | --- |
| cold axiom | 309.60 ms | 573.90 ms | +85% |
| cold dio | 256.90 ms | 457.00 ms | +78% |
| cold http | 240.80 ms | 411.30 ms | +71% |
| latency small_get_item axiom | 16.00 ms | 16.00 ms | +0% |
| latency small_get_item dio | 2.50 ms | 2.90 ms | +16% |
| latency small_get_item http | 2.40 ms | 2.60 ms | +8% |
| latency small_create_item axiom | 16.00 ms | 16.00 ms | +0% |
| latency small_create_item dio | 3.10 ms | 2.70 ms | -13% |
| latency small_create_item http | 3.10 ms | 2.40 ms | -23% |
| latency large_list_1000 axiom | 16.20 ms | 16.10 ms | -1% |
| latency large_list_1000 dio | 7.40 ms | 4.50 ms | -39% |
| latency large_list_1000 http | 5.70 ms | 3.70 ms | -35% |
| latency large_list_10000 axiom | 71.00 ms | 28.90 ms | -59% |
| latency large_list_10000 dio | 34.10 ms | 20.60 ms | -40% |
| latency large_list_10000 http | 17.30 ms | 13.00 ms | -25% |
| cache repeat_list_1000 axiom | 15.40 ms | 15.80 ms | +3% |
| cache repeat_list_1000 dio_cache_interceptor | 27.90 ms | 23.80 ms | -15% |
| decode 1000 json_only | 2.10 ms | 0.40 ms | -81% |
| decode 1000 axiom_generated | 2.40 ms | 1.30 ms | -46% |
| decode 1000 json_serializable | 2.70 ms | 1.50 ms | -44% |
| decode 1000 manual_fromJson | 1.90 ms | 1.00 ms | -47% |
| decode 10000 json_only | 7.60 ms | 4.50 ms | -41% |
| decode 10000 axiom_generated | 53.10 ms | 11.00 ms | -79% |
| decode 10000 json_serializable | 23.60 ms | 12.50 ms | -47% |
| decode 10000 manual_fromJson | 11.30 ms | 9.00 ms | -20% |

#### Client generation time (5 runs each)

| Tool | Mode | Median | Range |
| --- | --- | --- | --- |
| `axiom pull` (end to end) | cold | 2.42 s | 2.39–3.37 s |
| `axiom pull` (end to end) | warm | 2.98 s | 2.12–3.07 s |
| Axiom generator alone | cold | 1.42 s | 1.42–1.50 s |
| Axiom generator alone | warm | 1.23 s | 1.17–1.28 s |
| `dart run build_runner build` (retrofit + json_serializable) | cold | 25.39 s | 24.93–26.29 s |
| `dart run build_runner build` (retrofit + json_serializable) | warm | 2.60 s | 2.53–3.77 s |
| `dart run build_runner build` (retrofit + json_serializable) | warm noop | 2.37 s | 2.30–2.52 s |

cold: tool caches removed (generator snapshot; `build_runner clean`). warm: caches present; build_runner gets a changed comment in both input files; warm noop: nothing changed.

#### Lines of code for the same API (4 endpoints; non-blank, non-comment)

| Approach | Hand-written | Notes | Generated |
| --- | --- | --- | --- |
| Axiom (Acore contract + config + setup) | 70 | 55 without the WebSocket endpoint; 4 are server bodies | 554 |
| dio + retrofit + json_serializable | 57 |  | 171 |
| package:http + manual fromJson | 65 |  | 0 |

Files counted: see `tool/count_loc.py`. The Acore contract also describes the server, so it is not only client code.

#### Android APK size (`flutter build apk --release --split-per-abi`)

| ABI | Baseline (dio + http) | With Axiom SDK | Delta |
| --- | --- | --- | --- |
| arm64-v8a | 6.54 MB | 7.50 MB | 978 KB |
| armeabi-v7a | 6.00 MB | 6.96 MB | 982 KB |
| x86_64 | 6.66 MB | 7.62 MB | 981 KB |

No Android runtime .so: axiom_flutter on this branch has no android/ plugin, so the APK cannot make Axiom calls yet. The ~1 MB delta is almost all the web wasm runtime (axiom_runtime_bg.wasm, 942 KB compressed in the APK) that the package declares as a Flutter asset and therefore ships on every platform; app Dart code (libapp.so) differs by the rest. The real Android delta will be the .so per ABI minus the wasm if the asset is made web-only.

#### Web bundle size (`flutter build web --release`)

| File | Baseline | With Axiom SDK | Delta |
| --- | --- | --- | --- |
| main.dart.js | 1,701 KB | 1,726 KB | 25 KB |
| main.dart.js gzip -9 | 500 KB | 508 KB | 8 KB |
| axiom_runtime.js | – | 37 KB | 37 KB |
| axiom_runtime.js:gzip | – | 7 KB | 7 KB |
| axiom_runtime_bg.wasm | – | 2,371 KB | 2,371 KB |
| axiom_runtime_bg.wasm:gzip | – | 917 KB | 917 KB |
| build/web total | 22.72 MB | 25.13 MB | 2.41 MB |


Reproduce: see `flutter/benchmarks/README.md`.

