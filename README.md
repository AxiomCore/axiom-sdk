# Axiom SDKs

Client SDKs for [AxiomCore](https://docs.axiomcore.dev).

## Flutter

If you write Dio or Retrofit clients today, you write the request code, the
JSON models, the error mapping and the cache yourself, and they drift from
the server. With Axiom, the backend is described by a contract. `axiom pull`
generates a typed Dart client from it, and `axiom_flutter` runs that client
on a Rust runtime: it sends requests, validates responses against the
contract, caches, retries, and gives widgets a stream of loading, data and
error states. When the contract changes, you pull again and the Dart
compiler shows what broke.

### Platforms

| Platform | Minimum version | Runtime |
| --- | --- | --- |
| Android | API 24 | bundled `libaxiom_runtime.so` (arm64-v8a, armeabi-v7a, x86_64) |
| iOS | 13.0 | `AxiomRuntime.xcframework`, checksum-pinned |
| macOS | 11.0 | `AxiomRuntime.xcframework`, checksum-pinned |
| Web | WebAssembly | bundled wasm |
| Linux, Windows | not supported | |

Tested for 0.150.0 on the Android emulator (arm64, API 36), the iOS
simulator and macOS (81 of 84 run checks; the 3 WebSocket checks need the
next AxiomRuntime), and web in headless Chrome.

<!-- VERIFY: physical Android and iOS devices; Safari and Firefox; 32-bit ARM hardware (armeabi-v7a) -->

### Quickstart (5 minutes)

You need Flutter 3.32 or later and the `axiom` CLI.

1. Write a backend contract. In an empty folder `todos-api/`, create
   `AxiomDeps.toml`:

   ```toml
   type = "backend"
   targets = ["server"]
   audiences = ["web"]
   ```

   and `main.acore`:

   ```
   project(id: "dev.example.todos", version: "1.0.0")
   variant default(include: ["*"])

   model Greeting { message: String }
   model GreetingIn { name: String }

   action hello(kind: ActionKind.query, input: Models.GreetingIn, output: Models.Greeting) {
     managed { return {message: "Hello, " + Input.name} }
   }
   endpoint hello(method: GET, path: "/hello/{name}") {
     request { path("name", type: String) }
     handle(action: Actions.hello, input: {name: Input.path.name})
     response(type: Models.Greeting)
   }
   ```

2. Build and run it:

   ```sh
   cd todos-api
   axiom check main.acore
   axiom build main.acore --out backend.axiom
   axiom server deployment backend.axiom backend.server.json --output deployment.json
   axiom run main.acore --deployment deployment.json --port 8080
   ```

   `curl http://127.0.0.1:8080/hello/Ada` prints `{"message":"Hello, Ada"}`.
   For a web app, also declare `cors(...)` in the contract (see
   [Web setup](flutter/axiom_flutter/README.md#web)).

3. Generate the client in your Flutter app:

   ```sh
   flutter pub add axiom_flutter dev:axiom_flutter_generator
   axiom pull ../todos-api/backend.axiom --framework flutter --name todos --out lib/axiom_generated
   ```

   Add `assets/axiom/` under `flutter: assets:` in `pubspec.yaml`.

4. Use it:

   ```dart
   import 'package:axiom_flutter/axiom_flutter.dart';
   import 'package:flutter/material.dart';

   import 'axiom_generated/axiom_sdk.dart';
   import 'axiom_generated/models.dart' as models;

   late final AxiomSdk sdk;

   Future<void> main() async {
     WidgetsFlutterBinding.ensureInitialized();
     // Android emulator: use http://10.0.2.2:8080
     sdk = await AxiomSdk.create(baseUrlOverrides: {'todos': 'http://127.0.0.1:8080'});
     runApp(MaterialApp(
       home: Scaffold(
         body: Center(
           child: AxiomBuilder<models.Greeting, models.Greeting>(
             query: sdk.todos.hello(name: 'Ada'),
             loading: (context) => const CircularProgressIndicator(),
             error: (context, error) => Text(error.message),
             builder: (context, state, greeting) => Text(greeting.message),
           ),
         ),
       ),
     ));
   }
   ```

Platform setup (Android `INTERNET` permission, macOS network entitlement,
deployment targets, CORS on web) is in the
[`axiom_flutter` README](flutter/axiom_flutter/README.md#platform-setup).
A complete app with a mutation is in
[`flutter/axiom_flutter/example`](flutter/axiom_flutter/example). More apps
(quickstart, auth, offline-first, minimal with release sizes, streams) are in
the [examples repository](https://github.com/AxiomCore/examples#flutter-examples).

### Features

- [Typed queries and mutations](flutter/axiom_flutter/README.md#first-query) with `AxiomBuilder` and `AxiomMutationBuilder`
- [Streams (SSE, NDJSON) and WebSocket channels](flutter/axiom_flutter/README.md#streams-and-channels)
- [Auth tokens and token refresh](flutter/axiom_flutter/README.md#auth-tokens-and-token-refresh), and managed sign-in with [`axiom_flutter_auth`](flutter/axiom_flutter_auth/README.md)
- [Cache strategies, invalidation and forced refresh](flutter/axiom_flutter/README.md#cache-control)
- [Cancellation and per-call timeouts](flutter/axiom_flutter/README.md#cancellation-and-timeouts)
- [Typed contract failures](flutter/axiom_flutter/README.md#errors-and-typed-failures)
- [Signed and hash-locked contracts](flutter/axiom_flutter/README.md#signed-and-hash-locked-contracts)
- [Environments and base URL overrides](flutter/axiom_flutter/README.md#environments-and-base-urls)
- [Sandboxed extensions](flutter/axiom_flutter/README.md#extensions) (Android, iOS, macOS)
- Generated models with enums, unions, validators and value equality ([generator](flutter/axiom_flutter_generator/README.md))

### Benchmarks (0.150.0 table)

This is the 0.150.0 table. The 0.150.1 re-measurement of the merged code was
not ready when this README was written; size changes in 0.150.1 are under
[Size in 0.150.1](#size-in-01501).

<!-- BENCHMARKS:START -->
Measured 2026-11-20 on a 4 vCPU Linux container: release web build in headless
Chrome 158, Flutter 3.32.0, local loopback server, three full runs. Each value
is the median of the three run medians, and only metrics whose runs agree
within 10% are shown. These are not physical-device numbers. All three clients
call the same server.

| Measurement | Axiom | dio + retrofit | package:http |
| --- | --- | --- | --- |
| Client generation, cold | 1.4 s (`axiom pull` 2.5 s) | 25.1 s (`build_runner`) | none |
| Client generation, warm | 1.2 s (`axiom pull` 2.2 s) | 2.7 s (`build_runner`) | none |
| Cold start to first data | 262 ms | 221 ms | 219 ms |
| List of 1 000 items (91 KB), p50 | 5.3 ms | 3.4 ms | 3.1 ms |
| List of 10 000 items (938 KB), p50 | 33.2 ms | 18.6 ms | 13.2 ms |
| Repeat call served from cache, 1 000 items, p50 | 5.0 ms | 26.4 ms (`dio_cache_interceptor`) | not applicable |
| Decode only, 10 000 items, p50 | 10.8 ms | 12.5 ms (`json_serializable`) | 9.5 ms (manual `fromJson`) |
| Hand-written client code | 70 lines | 57 lines (plus 171 generated) | 65 lines |

Size added to an app:

| Target | Added |
| --- | --- |
| Android APK, arm64-v8a | 11.0 MB (runtime library 9.9 MB) |
| Android APK, armeabi-v7a | 8.2 MB (runtime library 7.1 MB) |
| Android APK, x86_64 | 13.3 MB (runtime library 12.2 MB) |
| Web | 2.5 MB (0.9 MB gzip), almost all of it the wasm runtime |

Small calls (about 2 ms for every client) and WebSocket throughput did not
repeat within 10% between runs, so they are not listed. The full table,
including the unstable metrics, the method and how to reproduce it, is in
[`flutter/benchmarks`](flutter/benchmarks/README.md) and
[`flutter/benchmarks/results/README-TABLE.md`](flutter/benchmarks/results/README-TABLE.md).
<!-- BENCHMARKS:END -->

### Size in 0.150.1

From 0.150.1 `axiom_flutter` bundles the lean runtime on Android and web (no
executable extensions, no telemetry exporter). Runtime library sizes in bytes
(0.150.1: artifacts built from the merged runtime):

| Target | 0.150.0 | 0.150.1 lean (default) | Lean, gzip -9 | 0.150.1 full (`axiom_flutter_extensions`) |
| --- | --- | --- | --- | --- |
| Android arm64-v8a | 10,097,128 | 4,804,712 | 2,381,263 | 7,375,344 |
| Android armeabi-v7a | 7,258,388 | 3,410,196 | 1,963,736 | 5,197,156 |
| Android x86_64 | 12,479,672 | 5,701,680 | 2,507,701 | 8,861,496 |
| Web `axiom_runtime_bg.wasm` | 2,444,563 | 2,123,497 | 807,347 | not applicable |

The SDK's integration app as an arm64 release APK: 27.32 MB with 0.150.0,
21.07 MB with 0.150.1 and 23.65 MB with `axiom_flutter_extensions`. Android
stores the library uncompressed in the APK (minSdk 24), so an APK grows by
the raw size and a Play download by about the gzip size. The plugin also
removes the unused web runtime from Android builds. iOS and macOS still use
the full published runtime 0.148.6.

### Where Axiom is slower

- **Web cold start.** The app downloads and compiles the WebAssembly runtime
  and loads the contract before the first call; dio and http skip both. Web
  fast start (`--dart-define=AXIOM_WEB_FAST_START=true`, opt-in, with limits)
  shortens this for eligible calls.
- **Large uncached lists.** The runtime checks the body before Dart decodes
  it, and on the web copies it into wasm once. 0.150.1 replaces the full JSON
  parse with an exact syntax check for endpoints without field rules, and
  samples validation for responses of 64 KiB or more by default.
- **Small calls** are within the timer resolution of the benchmark for all
  three clients.

Axiom is faster on repeated calls its cache can answer. HTTP/2, the binary
codec, batching, streaming decode and conditional requests are not in this
release. How a call flows and what each step costs:
[Performance](https://docs.axiomcore.dev/sdks/flutter-performance).

### Packages

| Path | Package | Purpose |
| --- | --- | --- |
| [`flutter/axiom_flutter`](flutter/axiom_flutter/README.md) | [`axiom_flutter`](https://pub.dev/packages/axiom_flutter) | Runtime, widgets and API |
| [`flutter/axiom_flutter_generator`](flutter/axiom_flutter_generator/README.md) | [`axiom_flutter_generator`](https://pub.dev/packages/axiom_flutter_generator) | Generates the Dart client; run by `axiom pull` |
| [`flutter/axiom_flutter_auth`](flutter/axiom_flutter_auth/README.md) | [`axiom_flutter_auth`](https://pub.dev/packages/axiom_flutter_auth) | Managed project sign-in, token storage |
| [`flutter/axiom_flutter_extensions`](flutter/axiom_flutter_extensions/README.md) | `axiom_flutter_extensions` (0.150.1) | Full Android runtime with executable extensions |

### Versioning and compatibility

`axiom_flutter` and `axiom_flutter_generator` are released together with the
same version. Use the same minor version of both, and regenerate the client
after upgrading.

The Dart package checks the runtime binary at start-up (ABI version 1, data
ABI version 1, contract reader version 3 or later) and fails with
`AxiomVersionMismatch` if they do not match. The binary is pinned in
[`flutter/axiom_flutter/runtime-pin.json`](flutter/axiom_flutter/runtime-pin.json):

| Package | Runtime | CLI |
| --- | --- | --- |
| 0.150.x | Apple 0.148.6 (pinned, full), Android and wasm bundled in the package (lean from 0.150.1) | 0.156 or later |

## Other SDKs

| Path | Purpose |
| --- | --- |
| [`swift`](swift/Package.swift) | Swift package source for Apple clients |
| [`web`](web) | Web client packages |

Published archives and platform release artifacts are mirrored to
[AxiomCore Releases](https://github.com/AxiomCore/AxiomCore/releases).

## Documentation

- Guides and reference: <https://docs.axiomcore.dev>
- Flutter API notes: [`flutter/axiom_flutter/API.md`](flutter/axiom_flutter/API.md)
- Client runtime security: [`CLIENT-RUNTIME-SECURITY.md`](CLIENT-RUNTIME-SECURITY.md)

## Contributing

For Flutter changes, run `flutter analyze` and the package tests from the
affected package directory. Native builds also need the platform toolchain
described by that package. Do not commit build outputs, credentials,
`.DS_Store` or `.summary_files`.
