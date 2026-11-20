# axiom_flutter

Flutter client runtime for [AxiomCore](https://docs.axiomcore.dev) backends.

You describe your API once in an Axiom contract. `axiom pull` turns the
contract into a typed Dart client. `axiom_flutter` runs that client: it sends
the requests, validates the responses against the contract, caches them, and
gives your widgets a stream of loading, data and error states. You do not
write Dio or Retrofit code, JSON parsing, or cache logic by hand.

The network layer is a Rust runtime. It is loaded with `dart:ffi` on Android,
iOS and macOS, and as a bundled WebAssembly module on web.

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
| Android | API 24 | `libaxiom_runtime.so` for arm64-v8a, armeabi-v7a, x86_64, shipped in the package |
| iOS | 13.0 | `AxiomRuntime.xcframework`, downloaded by CocoaPods and checked against a pinned SHA-256 |
| macOS | 11.0 | same XCFramework |
| Web | any browser with WebAssembly | `axiom_runtime_bg.wasm`, bundled as a package asset |

Linux and Windows are not supported.

<!-- VERIFY: platform runs on Android emulator, iOS simulator and macOS (lead receipt) -->

### Android

Nothing extra to install. Add the internet permission to
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Set `minSdk = 24` (or higher) in `android/app/build.gradle(.kts)`.

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

<!-- VERIFY: gen.mutation_invalidates_active_query -->

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

<!-- VERIFY: gen.ws_channel -->
<!-- VERIFY: stream.websocket_echo -->

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

<!-- VERIFY: auth.bearer_token -->
<!-- VERIFY: c.namespace_global_token -->

For tokens that expire, register a provider. The runtime asks it for a token
when a call needs one, so you can refresh first:

```dart
sdk.runtime.setAuthProvider((namespace, methodName) async {
  return await myAuth.freshAccessToken(); // null means "no token"
});
```

<!-- VERIFY: c.auth_provider -->

On logout, call `await sdk.runtime.resetSession();`. It cancels in-flight
requests, clears the session cache, the tokens and the provider. Loaded
contracts stay.

For a full sign-in flow (password, OAuth, MFA, secure storage), use
[`axiom_flutter_auth`](https://pub.dev/packages/axiom_flutter_auth). It plugs
into the runtime with `AxiomAuthBinding.attach(auth, runtime: sdk.runtime)`.

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

<!-- VERIFY: c.cancel -->
<!-- VERIFY: c.call_options_timeout -->

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

<!-- VERIFY: c.error_listener -->

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

<!-- VERIFY: c.locked_load_rejects_bad_hash -->

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

<!-- VERIFY: runtime.extensions -->

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `pod install` fails with a checksum mismatch | The downloaded `AxiomRuntime.xcframework.zip` does not match the SHA-256 pinned in the package. The previous framework is kept. Delete `Pods/` and retry; if it persists, the download was corrupted or the release was replaced. Do not edit the pin. |
| `The platform deployment target ... is lower than ...` or a linker error on iOS/macOS | Set iOS 13.0 / macOS 11.0 in the `Podfile` and in the Xcode project, then run `pod install` again. |
| `axiom pull` says `dart pub get failed` | Run `flutter pub get` in the project and fix the reported dependency conflict. `axiom_flutter` and `axiom_flutter_generator` must have the same minor version. |
| `axiom build` or `axiom check` cannot find `AxiomDeps.toml` | A backend contract needs an `AxiomDeps.toml` next to `main.acore` with `type = "backend"`, `targets = ["server"]` and `audiences = ["web"]`. |
| Web: every call fails, the browser console shows a CORS error | Add the app's origin to `cors(origins: [...])` in the backend contract and allow the `x-axiom-*` headers. Run the app on that exact origin (`--web-port`). |
| Debug console: unsigned contract warning | The contract has no signature. Fine during development. For release, sign it and pass the proof, or set `requireSignedContracts` to fail fast. |
| Android emulator: connection refused | Use `http://10.0.2.2:<port>`, add the `INTERNET` permission, and allow cleartext HTTP for debug builds. |
| `AxiomVersionMismatch` at start-up | The native runtime and the Dart package come from different releases. Upgrade them together (`flutter pub upgrade axiom_flutter`, then `pod install` / rebuild). |

## More

- Documentation: <https://docs.axiomcore.dev>
- Example app: [`example/`](example/)
- Generator: [`axiom_flutter_generator`](https://pub.dev/packages/axiom_flutter_generator)
- Auth: [`axiom_flutter_auth`](https://pub.dev/packages/axiom_flutter_auth)
- Full API reference with runtime notes: [`API.md`](API.md)

## License

MIT
