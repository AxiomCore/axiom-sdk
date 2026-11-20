# axiom_flutter

Flutter client runtime for [AxiomCore](https://docs.axiomcore.dev) backends.

You describe your API once in an Axiom contract. `axiom pull` turns the
contract into a typed Dart client. `axiom_flutter` runs that client: it sends
the requests, validates the responses against the contract, caches them, and
gives your widgets a stream of loading, data and error states. You do not
write Dio or Retrofit code, JSON parsing, or cache logic by hand.

The network layer is a Rust runtime. It is loaded with `dart:ffi` on Android,
iOS and macOS, and as a bundled WebAssembly module on web.

> **0.150.1 behaviour change:** on Android and web the package bundles the
> lean runtime (no executable extensions, no telemetry exporter). Everything
> else works unchanged. Apps that use extensions on Android add
> [`axiom_flutter_extensions`](#extensions). iOS and macOS are unchanged.
> See [Size and performance](#size-and-performance).
<!-- VERIFY: lean default and add-on from /home/node/fp/pack/REPORT.md -->

New to the SDK? [`doc/usage.md`](doc/usage.md) lists every step from contract
to first query.

- [Install](#install)
- [Platform setup](#platform-setup)
- [Generate a client](#generate-a-client)
- [First query](#first-query)
- [Mutations](#mutations)
- [Streams and channels](#streams-and-channels)
- [Auth tokens and token refresh](#auth-tokens-and-token-refresh)
- [Cache control](#cache-control)
- [Cancellation and timeouts](#cancellation-and-timeouts)
- [Errors and typed failures](#errors-and-typed-failures)
- [Signed and hash-locked contracts](#signed-and-hash-locked-contracts)
- [Environments and base URLs](#environments-and-base-urls)
- [Extensions](#extensions)
- [Size and performance](#size-and-performance)
- [Troubleshooting](#troubleshooting)

## Install

```yaml
dependencies:
  axiom_flutter: ^0.150.0

dev_dependencies:
  axiom_flutter_generator: ^0.150.0
```

`axiom_flutter_generator` is run for you by `axiom pull`. You do not call it
from `build_runner`.

## Platform setup

| Platform | Minimum | Runtime binary |
| --- | --- | --- |
| Android | API 24 | lean `libaxiom_runtime.so` for arm64-v8a, armeabi-v7a, x86_64, shipped in the package (full runtime with executable extensions: add `axiom_flutter_extensions`) |
| iOS | 13.0 | `AxiomRuntime.xcframework`, downloaded by CocoaPods and checked against a pinned SHA-256 |
| macOS | 11.0 | same XCFramework |
| Web | any browser with WebAssembly | lean `axiom_runtime_bg.wasm`, bundled as a package asset |

Linux and Windows are not supported.

Tested for 0.150.0 with the qualification suite in `flutter/integration_app`:
Android emulator (arm64, API 36), iOS simulator and macOS (81 of 84 run
checks pass with the published runtime; the 3 WebSocket checks need the next
AxiomRuntime), and web in headless Chrome (debug, release with a strict CSP,
and dart2wasm).

<!-- VERIFY: physical Android and iOS devices; Safari and Firefox; 32-bit ARM hardware (armeabi-v7a) -->

### Android

Nothing extra to install. Add the internet permission to
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Set `minSdk = 24` (or higher) in `android/app/build.gradle(.kts)`.

Since 0.150.1 the bundled library is the LEAN runtime: no executable
extensions and no telemetry exporter (arm64 library 7.3 MB -> 4.8 MB; an arm64
release APK of the integration app went from 27.3 MB to 21.0 MB). Apps that
use executable extensions add `axiom_flutter_extensions`, which ships the full
runtime and removes the lean library from the app (see [Extensions](#extensions)).

32-bit x86 emulators are not supported. Use an x86_64 or arm64 image.

The Android emulator reaches your computer at `10.0.2.2`, not `127.0.0.1`.
For plain `http://` during development, allow cleartext traffic in a debug
network security config.

### iOS and macOS

Set the deployment target to iOS 13.0 and macOS 11.0, in the `Podfile`
(`platform :ios, '13.0'` / `platform :osx, '11.0'`) and in the Xcode project.

On macOS, apps are sandboxed. Add this key to both
`macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

For `http://localhost` on iOS, add `NSAllowsLocalNetworking` under
`NSAppTransportSecurity` in `Info.plist`.

iOS and macOS still use the published full AxiomRuntime 0.148.6 (executable
extensions included), so the lean default and `axiom_flutter_extensions`
change nothing there. The web runtime files are also copied into Apple app
bundles (about 2.5 MB, never loaded); `ios/axiom_strip_web_assets.sh` (and
the `macos/` copy) can remove them as an opt-in Run Script phase, see
[doc/wasm-size.md](doc/wasm-size.md). That script is not verified on Apple
hardware yet.

### Web

The wasm runtime is bundled with the package, so there is nothing to copy.
The browser enforces CORS: your backend must allow the origin the app runs
on. In an Axiom contract:

```
cors(origins: ["http://localhost:3000"], methods: [GET, POST],
     headers: ["accept", "content-type", "x-axiom-request-id", "x-axiom-cache-mode"],
     credentials: false, maxAge: 10m)
```

Then run the app on that origin: `flutter run -d chrome --web-port 3000`.

Loading, Content Security Policy, sub-path hosting (`--base-href`) and the
web cache are covered in [doc/web.md](doc/web.md).

## Generate a client

You need the `axiom` CLI. With a backend contract built
(`axiom build main.acore --out backend.axiom`), run in your Flutter project:

```sh
axiom pull path/to/backend.axiom --framework flutter --name todos --out lib/axiom_generated
```

This copies the contract to `assets/axiom/todos.axiom`, adds it to
`AxiomDeps.toml`, and writes `lib/axiom_generated/axiom_sdk.dart` and
`models.dart`. Add the asset folder to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/axiom/
```

Run `axiom pull` again whenever the contract changes. If a field was renamed,
`flutter analyze` shows every place that still uses the old name.

## First query

Start the runtime once, before `runApp`:

```dart
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/material.dart';

import 'axiom_generated/axiom_sdk.dart';
import 'axiom_generated/models.dart' as models;

late final AxiomSdk sdk;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sdk = await AxiomSdk.create(
    baseUrlOverrides: {'todos': 'http://127.0.0.1:8080'},
  );
  runApp(const MaterialApp(home: HelloPage()));
}
```

`AxiomSdk.create` loads every contract asset, checks that the runtime binary
and the package agree on their ABI version, and throws if start-up fails.

Every generated endpoint method returns an `AxiomQuery<T>`. Show it with
`AxiomBuilder`:

<!-- verify: continued -->
```dart
class HelloPage extends StatelessWidget {
  const HelloPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AxiomBuilder<models.Greeting, models.Greeting>(
      query: sdk.todos.hello(name: 'Flutter'),
      loading: (context) => const CircularProgressIndicator(),
      error: (context, error) => Text(error.message),
      builder: (context, state, greeting) => Text(greeting.message),
    );
  }
}
```

`state.isFetching` is true while a cached value is shown and a network
refresh runs. `state.source` tells you whether the data came from the cache
or the network.

Outside widgets, use the stream directly or wait for the first value:

```dart
final greeting = await sdk.todos.hello(name: 'Ada').stream.unwrap();

sdk.todos.hello(name: 'Ada').stream.listen((state) {
  if (state.hasData) debugPrint('${state.source}: ${state.data}');
});
```

Two widgets that ask for the same endpoint with the same arguments share one
request. Arguments are normalized, so `{a: 1, b: 2}` and `{b: 2, a: 1}` are
the same query.

## Mutations

Commands (POST, PUT, DELETE) are generated the same way. Run them from a
button with `AxiomMutationBuilder`:

```dart
AxiomMutationBuilder<models.Todo, String>(
  mutation: AxiomMutation((title) => sdk.todos.createTodo(title: title)),
  builder: (context, state, execute) => ElevatedButton(
    onPressed: state.isMutating ? null : () => execute('Write docs'),
    child: Text(state.data == null ? 'Create' : 'Created ${state.data!.id}'),
  ),
)
```

Or await it: `final todo = await sdk.todos.createTodo(title: 'x').stream.unwrap();`

If the contract says a command `invalidates` a cache identity, the generated
method refetches the active queries of that identity after the command
succeeds. If the contract marks a command idempotent, the generated method
takes an `idempotencyKey` and creates one when you do not pass it.


## Streams and channels

Server-sent events and chunked (NDJSON) endpoints generate a method that
returns a plain `Stream<T>`, one item per frame. Cancel the subscription to
close the request.

```dart
final sub = sdk.fixture.sseStream().listen((tick) => debugPrint('${tick.seq}'));
// later
await sub.cancel();
```

WebSocket endpoints generate a `...Channel()` method that returns an
`AxiomChannel<Receive, Send>`. The channel reconnects with exponential
back-off when the contract says `reconnect: "auto"`.

WebSocket limits in 0.150.0:
- iOS and macOS need the next AxiomRuntime release; with the pinned 0.148.6
  runtime a channel fails with an error that names the cause.
- On web, a browser cannot send `Authorization` on a WebSocket upgrade, so a
  WebSocket endpoint must accept a cookie session.

<!-- VERIFY: gen.ws_channel / stream.websocket_echo on web with a cookie session (FAIL in the h2 web receipts) -->

```dart
final channel = sdk.fixture.wsEchoChannel();
channel.stream.listen((state) => debugPrint('${state.data?.text}'));
channel.send(const models.Ping(text: 'hi', seq: 1));
await channel.close();
```

## Auth tokens and token refresh

Tokens are kept by the runtime and attached to every call that needs them.
Each generated module has an `axiom` helper:

```dart
// One auth method declared in the contract.
sdk.todos.axiom.setAuthToken('bearerAuth', token);

// Every auth method of the namespace.
sdk.todos.axiom.setNamespaceToken(token);

// Every namespace.
sdk.runtime.setGlobalAuthToken(token);
```

<!-- VERIFY: c.namespace_global_token (SKIP in the web and Linux host receipts) -->

For tokens that expire, register a provider. The runtime asks it for a token
when a call needs one, so you can refresh first:

```dart
sdk.runtime.setAuthProvider((namespace, methodName) async {
  return await myAuth.freshAccessToken(); // null means "no token"
});
```

<!-- VERIFY: c.auth_provider (SKIP in the web and Linux host receipts) -->

On logout, call `await sdk.runtime.resetSession();`. It cancels in-flight
requests, clears the session cache, the tokens and the provider. Loaded
contracts stay.

For a full sign-in flow (password, OAuth, MFA, secure storage), use
[`axiom_flutter_auth`](https://pub.dev/packages/axiom_flutter_auth). It plugs
into the runtime with
`AxiomAuthBinding.attach(auth, runtime: sdk.runtime, namespaces: ['api'])`.
The token is sent only to the contracts you name.

## Cache control

Caching is declared per endpoint in the contract (`network_only`,
`cache_first`, `network_first`, `stale_while_revalidate`, with a TTL). From
Dart you can:

```dart
// Skip the cache for one call.
sdk.todos.hello(
  name: 'Ada',
  options: const AxiomCallOptions(cacheMode: AxiomCacheMode.refresh),
);

// Refetch active queries of one endpoint, or of a whole namespace.
sdk.runtime.invalidate(namespace: 'todos', endpointId: TodosModule.endpointIds['hello']);
sdk.todos.axiom.invalidateAll();

// Drop cached data. clearCache refetches active queries, purgeCache does not.
await sdk.runtime.clearCache('todos');
await sdk.runtime.purgeCache();
```

`AxiomQuery.refresh(force: true)` refetches one query and skips the cache.
`setQueryData` and `getCachedQueryData` read and write the in-memory value
of a query, for optimistic updates.

## Cancellation and timeouts

A query's request is cancelled when its last listener goes away, for
example when the `AxiomBuilder` that shows it is disposed. You can cancel by
hand with `query.cancel()`. A cancelled request ends with an `AxiomError`
whose `isCancelled` is true; cancelled requests are not sent to `onError`.

```dart
final query = sdk.todos.hello(
  name: 'Ada',
  options: const AxiomCallOptions(timeout: Duration(seconds: 5)),
);
// ...
query.cancel();
```

A timeout ends the call with error code `NetworkTimeout`.


## Errors and typed failures

Errors are `AxiomError` values, delivered in `AxiomState.error` (or thrown
by `unwrap()`). Each has:

- `code`: a sealed `AxiomErrorCode` (`HttpStatus(404)`, `NetworkTimeout`,
  `NetworkConnectionFailed`, `ValidationError`, `Cancelled`, ...)
- `stage` and `category`: where and why it failed
- `retryable`: whether the runtime thinks a retry can help
- `message` and `details` (the server body, when there is one)

When the contract declares failures for an endpoint, the generator emits a
class per failure and a matcher per endpoint:

```dart
try {
  await sdk.fixture.claim(name: 'taken').stream.unwrap();
} on AxiomError catch (e) {
  final message = e.whenClaim(
    conflict: (f) => 'already taken by ${f.existingId}',
    orElse: (err) => err.message,
  );
}
```

`e.contractFailure` gives the typed failure object for any endpoint.

All errors of all queries also arrive on one stream, for logging:

```dart
sdk.runtime.onError.listen((event) {
  debugPrint('${event.namespace} ${event.endpointId}: ${event.error}');
});
```


## Signed and hash-locked contracts

`axiom pull` records the SHA-256 of each contract asset. In release builds
the generated config passes it to the runtime, which then refuses an asset
whose bytes differ (a "locked" load). If the contract is signed, pass the
signature and public key (`axiom pull --signature ... --public-key ...`, or
`signature` / `public_key` in `AxiomDeps.toml`). A partial or invalid proof
fails start-up; it never falls back to unsigned mode.

`AxiomInitResult` tells you what happened per contract:

```dart
final result = sdk.initResult;
for (final c in result.contracts.values) {
  debugPrint('${c.namespace}: ${c.trust}'); // unsigned, signed or locked
}
```

An unsigned contract prints a warning in debug mode. Set
`requireSignedContracts: true` in `AxiomConfig` to make start-up fail
instead.


## Environments and base URLs

The base URL of each contract is resolved in this order:

1. `baseUrlOverrides` passed to `AxiomSdk.create`
2. `AxiomEnvironment.baseUrls[namespace]`
3. `AxiomEnvironment.defaultBaseUrl`
4. the URL written by `axiom pull --base-url`

Without code changes: `flutter run --dart-define=AXIOM_BASE_URL=https://staging.example.com`.

```dart
sdk = await AxiomSdk.create(
  environment: const AxiomEnvironment(
    name: 'staging',
    baseUrls: {'todos': 'https://staging.example.com'},
  ),
);
```

## Extensions

On Android, iOS and macOS the runtime can load signed, sandboxed WebAssembly
extensions from bytes embedded in the app: `loadExtension`,
`invokeExtension`, `extensionLifecycle` and `extensionAudit` on
`AxiomRuntime`. A failed call throws `AxiomExtensionException`. On web these
methods throw `UnsupportedError`.

On Android the runtime bundled with `axiom_flutter` is the lean build without
executable extensions: `loadExtension` and `invokeExtension` throw
`AxiomExtensionException` with the message "Executable extensions need the
axiom_flutter_extensions package". Add the add-on to get the full runtime:

```yaml
dependencies:
  axiom_flutter: ^0.150.1
  axiom_flutter_extensions: ^0.150.1
```

It bundles `libaxiom_runtime_full.so`, which `axiom_flutter` loads in
preference to `libaxiom_runtime.so`, and its Gradle build removes the lean
library from the app (opt out with `axiom.keepLeanRuntime=true` in
`android/gradle.properties`). iOS and macOS already ship the full runtime.

<!-- VERIFY: runtime.extensions (SKIP in every receipt on the Linux box; needs a native extension build) -->

## Size and performance

What the runtime adds to an app (bytes, runtime library only; from the
`flutter/perf` artifact measurements):

| Target | Full runtime | Lean runtime (0.150.1 default) | Lean, gzip -9 |
| --- | --- | --- | --- |
| Android arm64-v8a | 10,123,728 | 5,025,888 | 2,483,034 |
| Android armeabi-v7a | 7,280,044 | 3,538,792 | 2,040,974 |
| Android x86_64 | 12,512,352 | 5,957,296 | 2,615,356 |
| Web `axiom_runtime_bg.wasm` | 2,475,214 | 2,067,867 | 786,604 |

<!-- VERIFY: replace with the final 0.150.1 artifacts from /home/node/fp/rtlean/REPORT.md (item 8) -->

- Android stores native libraries uncompressed in the APK (minSdk 24), so the
  APK and the installed app grow by the raw size; Google Play downloads are
  compressed (about the gzip column). Publish an App Bundle, or use
  `flutter build apk --split-per-abi`, so users get only their ABI.
- The plugin removes the unused web runtime from Android builds (about
  0.96 MB per APK). `axiom.keepWebAssets=true` in `android/gradle.properties`
  keeps it. iOS and macOS bundles still carry it; see
  [`doc/wasm-size.md`](doc/wasm-size.md).
- Responses of endpoints without field rules get a JSON syntax check instead
  of a full parse, which is most of the time the runtime spent on large
  lists in 0.150.0. Accept and reject behaviour is unchanged.
  <!-- VERIFY: 10k-item before/after row from /home/node/fp/bench2/REPORT.md (p1's preliminary row had 12.1% spread, not publishable) -->
- Where Axiom is still slower than `package:http`: web cold start (the wasm
  runtime and the contract load before the first call) and large uncached
  lists (the body is copied into the runtime and back, and syntax-checked).
  Repeated calls answered from the cache are faster than with
  `dio_cache_interceptor`.

Details: [App size](https://docs.axiomcore.dev/sdks/flutter-app-size),
[Performance](https://docs.axiomcore.dev/sdks/flutter-performance),
[Benchmarks](https://docs.axiomcore.dev/sdks/flutter-benchmarks).
<!-- VERIFY: 0.150.1 benchmark rows from /home/node/fp/bench2/REPORT.md; options from RTSPEED/DARTNATIVE/WEBSPEED reports -->

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `pod install` fails with a checksum mismatch | The downloaded `AxiomRuntime.xcframework.zip` does not match the SHA-256 pinned in the package. The previous framework is kept. Delete `Pods/` and retry; if it persists, the download was corrupted or the release was replaced. Do not edit the pin. |
| `The platform deployment target ... is lower than ...` or a linker error on iOS/macOS | Set iOS 13.0 / macOS 11.0 in the `Podfile` and in the Xcode project, then run `pod install` again. |
| `axiom pull` says `dart pub get failed` | Run `flutter pub get` in the project and fix the reported dependency conflict. `axiom_flutter` and `axiom_flutter_generator` must have the same minor version. |
| `axiom build` or `axiom check` cannot find `AxiomDeps.toml` | A backend contract needs an `AxiomDeps.toml` next to `main.acore` with `type = "backend"`, `targets = ["server"]` and `audiences = ["web"]`. |
| Web: every call fails, the browser console shows a CORS error | Add the app's origin to `cors(origins: [...])` in the backend contract and allow the headers the SDK sends: `accept`, `content-type`, `x-axiom-request-id`, `x-axiom-cache-mode`, `traceparent`, `tracestate` (plus `authorization` if you send tokens). Run the app on that exact origin (`--web-port`). |
| Web release build: `Null check operator used on a null value` in your own code | A dart2js bug in Dart 3.8.0 / Flutter 3.32.0, not an SDK bug: any `async` function literally named `result` crashes in release web builds (the compiler's internal `$async$result` name shadows the awaited value). Rename the function. |
| Web: after a rebuild the browser still runs the old app | Flutter's service worker can serve the previous build. Hard-reload, or test each build in a fresh browser profile (Chrome `--user-data-dir=<new dir>`). |
| Web: WebSocket endpoint gets 401 or never opens | Browsers cannot send `Authorization` on a WebSocket upgrade. Use a cookie session for WebSocket endpoints on web. |
| Web (dart2js): a 64-bit id changes its last digits | JavaScript numbers lose precision above 2^53. Use `String` for 64-bit ids, or build with `--wasm`. Native builds are not affected. |
| An endpoint that returns `204 No Content` fails with a decode error | The SDK reports success for an empty body, but the current runtime rejects an empty body when the endpoint declares a typed response. Fixed in the next runtime release; until then, return a body from that endpoint. |
| Debug console: unsigned contract warning | The contract has no signature. Fine during development. For release, sign it and pass the proof, or set `requireSignedContracts` to fail fast. |
| Android emulator: connection refused | Use `http://10.0.2.2:<port>`, add the `INTERNET` permission, and allow cleartext HTTP for debug builds. |
| Android: Gradle fails with `Unsupported class file major version` | Android builds need JDK 17. Install it and run `flutter config --jdk-dir <path>`. |
| Android: an extension call throws an error naming `axiom_flutter_extensions` | 0.150.1 bundles the lean runtime. Add `axiom_flutter_extensions: ^0.150.1`. |
| `AxiomVersionMismatch` at start-up | The native runtime and the Dart package come from different releases. Upgrade them together (`flutter pub upgrade axiom_flutter`, then `pod install` / rebuild). |

## More

- Documentation: <https://docs.axiomcore.dev>
- Example app: [`example/`](example/)
- More examples: [`flutter-quickstart`](https://github.com/AxiomCore/examples/tree/main/flutter-quickstart), [`flutter-auth`](https://github.com/AxiomCore/examples/tree/main/flutter-auth), [`flutter-offline-first`](https://github.com/AxiomCore/examples/tree/main/flutter-offline-first), [`flutter-minimal`](https://github.com/AxiomCore/examples/tree/main/flutter-minimal) (release sizes), [`stream/example`](https://github.com/AxiomCore/examples/tree/main/stream/example)
- Generator: [`axiom_flutter_generator`](https://pub.dev/packages/axiom_flutter_generator)
- Auth: [`axiom_flutter_auth`](https://pub.dev/packages/axiom_flutter_auth)
- Full API reference with runtime notes: [`API.md`](API.md)

## License

MIT
