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
tool/             server.sh, run_web.sh, bench_tooling.py, bench_size.py, count_loc.py,
                  collect_results.py, render_readme.py
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

## Caveats

- Headless Chrome on a shared 4 vCPU container is not a phone. Localhost has no network latency,
  which magnifies client overhead; on a real network the per-call differences are a smaller share.
- Web timers: `Stopwatch` resolution in Chrome is 0.1 ms (or coarser without cross-origin isolation).
- The bench server is the same for all clients, but its own cost is in every number.
- The SDK is under active change on `flutter/parity`; results name the SDK commit they ran on.
- Physical-device runs (one mid-range Android, one iPhone) are still to do.

## Findings (SDK issues these benchmarks exposed)

1. **Web: 16 ms polling floor.** `axiom_flutter/lib/src/runtime_web.dart` drives the wasm runtime
   with `Timer.periodic(16 ms, axiomProcessResponses)`, so every Axiom call on web waits for the
   next tick: p50 ≈ 16 ms for a 110-byte response where dio/http take ≈ 2 ms on localhost.
   Processing responses when the fetch promise resolves would remove most of this.
2. **Repeat identical query can skip the request.** In `query_manager.dart`, a new listener on a
   key whose last request has emitted data but not yet its Complete event receives the old state
   and no fetch starts, even for `networkOnly` endpoints.
3. **Axiom WebSocket channel not implemented**: `openChannel` throws `UnimplementedError` on web
   and native on this branch, so the Axiom WebSocket result is `blocked`.
4. **Android**: `axiom_flutter` on this branch has no `android/` plugin, so the APK "with Axiom" contains
   only the Dart code; the runtime `.so` is not in it (see the APK note in the results).
5. **Wasm runtime ships on every platform.** The package lists `lib/assets/wasm/*` as Flutter
   assets, so Android (and iOS/macOS) builds carry the 2.4 MB web runtime (942 KB compressed in the
   APK) that they never load. That is nearly all of the measured APK delta today.
6. `axiom pull` rewrites `AxiomDeps.toml` with an absolute contract path (the tooling script
   restores the repo copy after each run).
