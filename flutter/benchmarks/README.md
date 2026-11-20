# Axiom Flutter SDK benchmarks

A harness that compares the Axiom Flutter SDK (`axiom_flutter` + generated client) with two common
hand-written clients for the **same API on the same server**:

| Approach | Where |
| --- | --- |
| Axiom: Acore contract, `axiom pull`, generated client | `api/acore/main.acore`, `app/lib/axiom_generated/` |
| `dio` + `retrofit` + `json_serializable` (build_runner) | `api/dio_client/` |
| `package:http` + hand-written `fromJson` | `api/http_client/` |

Results are JSON in `results/`; `tool/render_readme.py` turns them into the markdown tables for
the repo README. Rules: every published number can be re-run from this directory; machine, OS,
Flutter version and method go next to every number; unfavourable numbers are published too;
emulator, simulator and headless-Chrome numbers are labelled as such.

## Layout

```
api/acore/        Acore contract (listItems, cachedItems, getItem, createItem, wsEcho)
api/server/       Dart server behind all three clients (port 8851)
api/dio_client/   retrofit + json_serializable client (generated *.g.dart committed)
api/http_client/  package:http client
app/              Flutter app (android, ios, macos, web): runner printing AXIOM_BENCH lines
baseline_app/     Same screen as app/lib/size_main.dart without the Axiom dependency (size baseline)
tool/             server.sh, run_web.sh, run_record.sh, vm_bench.dart, bench_tooling.py, bench_size.py,
                  size_table.py, count_loc.py, collect_results.py, render_readme.py
results/          raw and merged results
```

## The API and the server

Endpoints: `GET /items?n=` (n = 1, 100, 1 000, 10 000; ~110 B, 8.8 KB, 91 KB, 938 KB of JSON),
`GET /cached/items?n=` (same body; `cacheFirst` 10 min in the contract), `GET /items/{id}`,
`POST /items` (201), WebSocket `/ws` (echo).

The Acore backend cannot serve the large lists: managed code has no loops or ranges, so a
10 000-item list cannot be built. All three clients therefore call **one small Dart server**
(`api/server/bin/server.dart`, `dart:io`, pre-encoded bodies, no compression, CORS `*`). The
Axiom client is generated from the contract and pointed at that server, which is exactly what an
Axiom client does against any backend that implements the contract. The contract still builds and
runs with `axiom run` for small payloads (`api/acore`, managed bodies return one item).

## Run

Set up: `. ~/.profile` (Flutter 3.32.0), `axiom` CLI on PATH (or `AXIOM=~/bin/axiom`).

```bash
cd flutter/benchmarks
tool/server.sh &                      # bench server on 0.0.0.0:8851
(cd api/acore && axiom build main.acore --out .out/bench.axiom)   # needed by tooling + regen
```

Regenerate the clients (only after changing the API):

```bash
(cd app && axiom pull ../api/acore/.out/bench.axiom --framework flutter --name bench --out lib/axiom_generated && git checkout AxiomDeps.toml)
(cd api/dio_client && dart run build_runner build --delete-conflicting-outputs)
```

### App benchmarks

The app runs without interaction and prints one line per result:

```
AXIOM_BENCH {"bench":"latency","case":"small_get_item","client":"axiom","p50_ms":...,"platform":"web","mode":"release",...}
AXIOM_BENCH {"bench":"done",...}
```

Selection: `--dart-define=BENCH=<list>` (on web also `?bench=<list>` in the URL).
`all` (default) = `latency,cache,decode,ws`. Cold start is one measurement per process: run
`cold:axiom`, `cold:dio`, `cold:http` each in a fresh launch (5 launches each). Other defines:
`BENCH_BASE_URL` (default `http://127.0.0.1:8851`), `BENCH_CALLS` (default 200).

| Target | Command (from `app/`) |
| --- | --- |
| Web, headless Chrome (this box) | `../tool/run_web.sh ../results/raw-web.jsonl` (builds `--release`; `COLD_RUNS=5`) |
| macOS (profile) | `flutter run -d macos --profile --dart-define=BENCH=all 2>&1 \| grep AXIOM_BENCH` |
| iOS simulator (debug only; simulators do not run profile/release) | `flutter run -d <sim-id> --dart-define=BENCH=all 2>&1 \| grep AXIOM_BENCH` — label results "simulator, debug" |
| iOS device (profile) | `flutter run -d <device> --profile --dart-define=BENCH=all --dart-define=BENCH_BASE_URL=http://<mac-lan-ip>:8851` |
| Android emulator (profile, x86_64) | `flutter run -d emulator-5554 --profile --dart-define=BENCH=all --dart-define=BENCH_BASE_URL=http://10.0.2.2:8851 2>&1 \| grep AXIOM_BENCH` |
| Android device (profile) | `adb reverse tcp:8851 tcp:8851` then `flutter run -d <id> --profile --dart-define=BENCH=all` |

Cold start on native: repeat 5 times for each client, e.g.
`for c in axiom dio http; do for i in 1 2 3 4 5; do flutter run -d macos --profile --dart-define=BENCH=cold:$c 2>&1 | grep -m1 '"bench":"cold"'; done; done`
(`flutter run` exits when you quit the app; with `--no-resident` it detaches after launch and the
lines come from the device log: `adb logcat -s flutter` / `log stream --predicate 'process == "axiom_bench_app"'`).
Save the lines (only the JSON after `AXIOM_BENCH `, plus `"run":"cold-<client>-<i>"` for cold
lines) as JSONL and merge with `tool/collect_results.py --web <file> --label <platform>`.

### Tooling, LOC and size (any Linux or macOS box)

```bash
python3 tool/bench_tooling.py --out results/tooling.json   # 5 cold + 5 warm runs per tool
python3 tool/count_loc.py --out results/loc.json
python3 tool/bench_size.py --out results/size.json         # apk --split-per-abi + web, both apps
python3 tool/collect_results.py --label linux-chrome --web results/raw-web.jsonl \
  --tooling results/tooling.json --loc results/loc.json --size results/size.json
python3 tool/render_readme.py results/<date>-linux-chrome.json --insert ../../README.md
```

## Results

Numbers of record: `results/2026-11-20-linux-chrome-idle.json` (3 full web runs on an idle box,
tooling, LOC, size), rendered by `tool/render_readme.py` into `results/README-TABLE.md` (the table
for the repo README). Raw inputs: `results/raw-web-idle-run{1,2,3}.jsonl`, `tooling-l2.json`,
`loc-l2.json`, `size-l2.json`, `extra-2026-11-20-idle.json` (machine, commits).
`results/2026-11-20-linux-chrome.json` is the earlier preliminary run (shared CPUs, 16 ms web
floor still present); it is superseded and kept only for history.

### Reproduce the numbers of record

```bash
. ~/.profile                                   # Flutter 3.32.0, Android SDK, Chrome
cd flutter/benchmarks
top -bn1 | head -15                            # no cargo/rustc/gradle/other chrome running
(cd api/acore && ~/bin/axiom build main.acore --out .out/bench.axiom)
python3 tool/bench_size.py --out results/size-l2.json          # builds both apps (apk + web)
(cd app/android && ./gradlew --stop)                           # stop Gradle before timing
tool/server.sh 8851 &
tool/run_web.sh results/raw-web-idle-run1.jsonl                # release build + 15 cold launches + full set
SKIP_BUILD=1 tool/run_web.sh results/raw-web-idle-run2.jsonl
SKIP_BUILD=1 tool/run_web.sh results/raw-web-idle-run3.jsonl
AXIOM=~/bin/axiom python3 tool/bench_tooling.py --out results/tooling-l2.json
python3 tool/count_loc.py --out results/loc-l2.json
AXIOM=~/bin/axiom python3 tool/collect_results.py --label linux-chrome-idle \
  --web-runs results/raw-web-idle-run{1,2,3}.jsonl --tooling results/tooling-l2.json \
  --loc results/loc-l2.json --size results/size-l2.json \
  --extra results/extra-2026-11-20-idle.json --out results/2026-11-20-linux-chrome-idle.json
python3 tool/render_readme.py results/2026-11-20-linux-chrome-idle.json > results/README-TABLE.md
```

A full web run takes about 80 s on this box. To add a platform, merge its JSONL with
`tool/collect_results.py --label <platform>` and pass every results file to `tool/render_readme.py`.

## Scenarios added for 0.150.1 (unit bench2)

Selected like the others (`BENCH=` / `?bench=`; `extra` = all five), code in `app/lib/bench_extra.dart`:

| Name | What it measures |
| --- | --- |
| `parallel` | 20 calls started together, wall time until all returned typed data (getItem; listItems with n = 1000..1019 so no two calls are identical, identical in-flight Axiom queries would be shared) |
| `offline` | repeat call after the data is cached, then time to first data while the server drops every data connection (`/_ctl/offline?on=1`). Axiom: contract `cacheFirst`; dio: `dio_cache_interceptor` `refreshForceCache` + `hitCacheOnNetworkFailure`; http: no cache (reported as `no_data`) |
| `jank` | longest gap between ticks of a 1 ms periodic timer on the UI isolate while a 10 000-item list is fetched and decoded to typed models (10 calls; `idle` row = timer alone) |
| `ttfi` | time to first item of the 10 000-item list for clients that can stream (`/items.ndjson`, http `StreamedResponse`, dio `ResponseType.stream`). Axiom: `not_available` (the generated client has no streaming list call) |
| `clients` | per-call latency for every client incl. `dio_compute` (bytes, then `compute()` decode), `dio_http2` (`dio_http2_adapter`, native, h2 only), `cronet_http` (Android) and `cupertino_http` (iOS/macOS), selected at build time by conditional import (`app/lib/clients/`) |

HTTP/2: `tool/server.sh 8851 8853` adds a TLS listener (ALPN h2 only, self-signed certificate in
`api/server/certs/`, same routes and bodies). `BENCH_PROTO=h2` (web: `&proto=h2`) points every
client at it; records carry `"proto": "h1" | "h2"`. Web: Chrome negotiates h2 for every client
(`run_web.sh` adds `--ignore-certificate-errors` for the h2 pass only, `H2_BENCH=...`). Native:
dart:io `HttpClient` has no HTTP/2, so the native h2 rows are Axiom, `dio_http2` and the platform
stacks; the native Axiom runtime (rustls with built-in roots) does not accept the self-signed
certificate, so its native h2 rows are `error` until the runtime can trust a custom CA. The Dart
h2 listener itself is slower than the h1 one (TLS + package:http2), so compare clients within one
protocol, not h1 against h2.

Native Dart VM column (`app/test/vm_bench_test.dart`, driver `tool/vm_bench.dart`): the same
BenchRunner in the `flutter_tester` process (Dart VM, JIT) with the host runtime library from
`AXIOM_RUNTIME_LIB`. axiom_flutter imports the Flutter SDK, so plain `dart run` / `dart compile exe`
cannot load it; this column is a Linux server CPU, not a phone.

```bash
tool/server.sh 8771 8773 &
dart run tool/vm_bench.dart --lib /abs/libaxiom_runtime.so --base http://127.0.0.1:8771 --runs 3 --out results/raw-vm-<date>
python3 tool/size_table.py --out results/size-table-<date>.json        # baseline / axiom / axiom_extensions
AXIOM_RUNTIME_LIB=/abs/libaxiom_runtime.so DATE=<date> WEB_PORT_LOCK=/home/node/fp/web-port.lock \
  LOCK_TRASH=<dir> tool/run_record.sh                                  # 3 web + 3 VM runs, merge, render
python3 tool/render_readme.py --summary results/<date>-linux-chrome-idle.json --vm results/<date>-linux-vm.json \
  --size-table results/size-table-<date>.json > results/README-SUMMARY.md
python3 tool/render_readme.py --compare results/2026-11-20-linux-chrome-idle.json results/<date>-linux-chrome-idle.json
python3 tool/render_readme.py --history results/history.jsonl --release 0.150.1 results/<date>-*.json
```

## Method

- **Cold start to first data**: fresh process (web: fresh Chrome profile, so no HTTP cache);
  the timer starts in the app's first `initState`, before the client is constructed, and stops
  when `listItems(n:1)` returns typed data. For Axiom this includes loading the wasm/native
  runtime, `AxiomSdk.create` (runtime init + contract asset load) and the call; `init_ms` is
  the part before the call. Engine start-up before `main()` is not included for any client.
- **Per-call latency**: sequential calls, 20 warm-up calls then 200 measured, p50/p95. Cases:
  `getItem` (~110 B), `createItem` (POST), `listItems(1000)` (91 KB), `listItems(10000)` (938 KB).
  Axiom calls use the generated client as an app would (`query.stream` until data). After each
  Axiom call the SDK's in-memory query for that key is dropped (`AxiomQueryManager().remove`),
  otherwise a repeat identical call may be answered from the previous Dart state with no request
  (see Findings).
- **Cache hit**: one network call, then 50 repeat calls of `cachedItems(n:1000)`. Axiom uses the
  contract's `cacheFirst` policy (runtime cache); dio uses `dio_cache_interceptor` with
  `MemCacheStore` and `CachePolicy.forceCache`. The time includes decoding to typed models for both.
- **Decode**: one response body fetched once, then `utf8.decode + jsonDecode + fromJson` timed on
  the main isolate (50 reps for 1k, 20 for 10k, after 5 warm-ups) for the generated Axiom models,
  json_serializable models, manual `fromJson`, and `jsonDecode` alone. This is the Dart side only:
  the Axiom runtime also parses and validates the response before Dart sees it; that cost is part
  of the per-call latency numbers.
- **WebSocket**: 1 000 sequential echo round trips (send, await echo) after 20 warm-ups.
- **Generation time**: see the docstring of `tool/bench_tooling.py` for cold/warm definitions.
- **Lines of code**: non-blank, non-comment lines; file lists are in `tool/count_loc.py`.
- **Size**: `baseline_app` (dio + http, one call each) vs `app -t lib/size_main.dart` (same plus one
  Axiom call); `flutter build apk --release --split-per-abi` and `flutter build web --release`.
- **Stability rule (web)**: the full set is run 3 times (fresh Chrome profile per launch). For each
  metric the result is the median of the 3 run medians (cold start: the run median is the median
  of 5 launches); spread = (max - min) / median. Only metrics with spread <= 10% are published as
  numbers; the others are listed as "not stable" under the table (`web_stats` in the results JSON
  holds every run value).
- **Size breakdown**: `tool/bench_size.py` reads each APK as a zip and reports the in-APK bytes of
  `libaxiom_runtime.so`, `libapp.so` (Dart AOT), `libflutter.so`, the web runtime assets
  (`packages/axiom_flutter/lib/assets/wasm/*`) and the contract asset. It also builds the Axiom
  APKs a second time with `AXIOM_DROP_WASM=1`, which turns on the documented opt-out
  (`flutter/axiom_flutter/doc/wasm-size.md`) in `app/android/app/build.gradle.kts`. Web: raw and
  gzip -9 sizes of every `.js`/`.wasm` file under `build/web` (both CanvasKit variants are counted
  for both apps; a browser loads one).
- **Generator used by `axiom pull`**: the released CLI 0.156.0 does not read
  `AXIOM_FLUTTER_SDK_PATH`; it runs `dart run axiom_flutter_generator:generate` in the app, which
  resolves the app's path dev_dependency, i.e. the generator on this branch.

## Caveats

- Headless Chrome (`--headless=new`, no GPU) on a 4 vCPU x86_64 server container (gVisor), not a
  phone or a desktop browser. Server CPUs and a laptop/phone CPU differ in single-thread speed.
- The bench server is on local loopback: no network latency, no TLS, no compression. That
  magnifies client overhead; on a real network the per-call differences are a smaller share.
- No physical devices. macOS, iOS simulator and Android emulator numbers are pending (the lead runs
  them; commands above). The APKs were built but not run here (no emulator/KVM on this box).
- Web timers: `Stopwatch` resolution in Chrome is 0.1 ms without cross-origin isolation, so ~2 ms
  medians move by 5% per tick; that is why most small-call medians and all 1 000-item decode
  medians (~1 ms) fail the 10% rule.
- Run 1 followed the release build directly; its small-call medians are 0.1-0.3 ms higher for all
  three clients. The runs were not repeated or selected afterwards.
- The bench server's own cost is in every number, equally for all clients.
- The Axiom bench drops the query key after every call (`AxiomQueryManager().remove`), so every
  Axiom call is a network request, as for dio/http.
- The SDK is under active change on `flutter/parity`; results name the SDK and runtime commits.

## Findings (SDK issues these benchmarks exposed; status on 6cd7d9f)

1. Web 16 ms polling floor: fixed by unit h (host notify, runtime 1265a1c). Axiom getItem p50 is now
   ~2.8 ms (was 16 ms).
2. Repeat identical query skipping the request: fixed by unit h (check `h.repeat_query_refetches`).
   The bench keeps the per-call key removal so the workload is unchanged between runs.
3. Axiom WebSocket channel on web: fixed by unit h; the Axiom WS case now runs (1 000 echoes). Its
   throughput is not stable across runs (one run at half the others' rate).
4. Android: the runtime `.so` is now bundled (`axiom_flutter/android/src/main/jniLibs`); it is most
   of the APK delta (see the size table).
5. The web runtime (wasm + glue, 934 KB in the APK) still ships on every platform (Flutter 3.32 has
   no per-platform assets). Opt-out documented in `flutter/axiom_flutter/doc/wasm-size.md`.
6. `axiom pull` (CLI 0.156.0) rewrites `AxiomDeps.toml` with an absolute contract path (the tooling
   script restores the repo copy after each run).
