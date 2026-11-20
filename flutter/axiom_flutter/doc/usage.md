# Using axiom_flutter: the steps today

This page lists what a Flutter developer does, in order, to call an AxiomCore
backend from a Flutter app with `axiom_flutter` 0.150.x and Axiom CLI 0.156.0.
The full tutorial with explanations is the
[Flutter quickstart](https://docs.axiomcore.dev/getting-started/quickstart-flutter);
the reference is [Flutter and Dart](https://docs.axiomcore.dev/sdks/flutter).

How these steps were checked (20 Nov 2026, Debian 12 x86_64, Flutter 3.32.0,
`axiom` 0.156.0, `axiom_flutter` and `axiom_flutter_generator` from branch
`flutter/perf` through `pubspec_overrides.yaml`): steps 1 to 6 were run as
written. The backend answered `curl`; `axiom pull` succeeded; every Dart block
on this page analyzes with no issues; `flutter build web --release` and
`flutter build apk --release --split-per-abi` succeeded (the APK build fails
with a manifest merger error until step 5 sets `minSdk = 24`). The app was not
run on a device, emulator or browser for this page; the quickstart's device
runs are recorded with the 0.150.0 release.

## 0. Tools

| Tool | Version | Check |
| --- | --- | --- |
| Axiom CLI | 0.156.0 | `axiom --version` |
| Flutter | 3.32 or newer (Dart 3.8) | `flutter --version` |
| Android builds | Android SDK and **JDK 17** | `flutter doctor` |
| iOS and macOS builds | Xcode and CocoaPods | `flutter doctor` |
| Web | Chrome | `flutter devices` |

## 1. Write the backend contract

```bash
mkdir -p talks/talks-api && cd talks/talks-api
```

`AxiomDeps.toml` must sit next to the contract:

```toml
type = "backend"
targets = ["server"]
audiences = ["web"]
```

`main.acore` (two endpoints, no database):

```acore
project(id: "docs.talks", version: "1.0.0")
variant default(include: ["*"])

model Talk { id: String title: String speaker: String }
model TalkList { talks: List<Models.Talk> }
model NewTalk { title: String speaker: String }

cors(origins: ["http://localhost:5000", "http://127.0.0.1:5000"], methods: [GET, POST], headers: ["accept", "content-type", "authorization", "x-axiom-request-id", "x-axiom-cache-mode", "traceparent", "tracestate"], credentials: false, maxAge: 10m)

action listTalks(kind: ActionKind.query, output: Models.TalkList) {
  managed {
    return {talks: [
      {id: "t1", title: "Typed APIs in Flutter", speaker: "Ada"},
      {id: "t2", title: "Contracts over REST", speaker: "Grace"}
    ]}
  }
}
endpoint listTalks(method: GET, path: "/talks") {
  handle(action: Actions.listTalks)
  response(type: Models.TalkList)
}
action createTalk(kind: ActionKind.command, input: Models.NewTalk, output: Models.Talk) {
  managed { return {id: "t3", title: Input.title, speaker: Input.speaker} }
}
endpoint createTalk(method: POST, path: "/talks") {
  request { body("title", type: String) body("speaker", type: String) }
  handle(action: Actions.createTalk, input: {title: Input.body.title, speaker: Input.body.speaker})
  response(type: Models.Talk, status: 201)
}
```

The `cors(...)` line is needed only for the web build. Keep every header in
it: the SDK sends `accept`, `traceparent` and `tracestate` on every call, and
a missing header makes the browser preflight fail (the app shows no data).

## 2. Build and run the backend

```bash
axiom check main.acore
axiom build main.acore --out backend.axiom
axiom server deployment backend.axiom backend.server.json --output deployment.json
axiom run main.acore --deployment deployment.json --port 8080
```

In a second terminal, `curl -s http://127.0.0.1:8080/talks` prints the two
talks as JSON.

## 3. Create the app and add the packages

```bash
cd ..   # talks/
flutter create --platforms android,ios,macos,web talks_app
cd talks_app
flutter pub add axiom_flutter:^0.150.0 dev:axiom_flutter_generator:^0.150.0
```

Add the packages **before** the first pull: when they are missing, CLI
0.156.0 adds `axiom_flutter` 0.147.5, which has no Android support. Keep both
packages on the same version.

## 4. Generate the client

```bash
axiom pull ../talks-api/backend.axiom --framework flutter --name talks --out lib/axiom_generated
```

Last line: `✅ axiom pull finished successfully.` The pull copies the contract
to `assets/axiom/talks.axiom`, lists it in `pubspec.yaml`, runs
`dart pub get`, and writes `lib/axiom_generated/axiom_sdk.dart` and
`models.dart`. Pull again after every contract change. The only `axiom pull`
options in 0.156.0 are `--contract`, `--contract-config`, `--framework`,
`--name` and `--out`.

## 5. Platform setup

- **Android:** `minSdk = 24` in `android/app/build.gradle.kts`;
  `<uses-permission android:name="android.permission.INTERNET"/>` in
  `android/app/src/main/AndroidManifest.xml`; for a plain-HTTP development
  backend, a debug-only network security config that allows cleartext to
  `10.0.2.2` (the emulator's address for your computer). ABIs: `arm64-v8a`,
  `armeabi-v7a`, `x86_64` (no 32-bit `x86`). Gradle needs JDK 17.
- **iOS:** `platform :ios, '13.0'` in `ios/Podfile`; for plain HTTP to a local
  backend, `NSAllowsLocalNetworking` under `NSAppTransportSecurity` in
  `Info.plist`. CocoaPods downloads the runtime and checks its SHA-256.
- **macOS:** `platform :osx, '11.0'` in `macos/Podfile` and deployment target
  11.0 in Xcode; `com.apple.security.network.client` in both
  `DebugProfile.entitlements` and `Release.entitlements`.
- **Web:** nothing to add. The backend must allow the page's origin (CORS).

## 6. First query and mutation

`lib/main.dart`:

```dart
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'axiom_generated/axiom_sdk.dart';
import 'axiom_generated/models.dart' as models;

late final AxiomSdk sdk;

/// The Android emulator reaches your computer at 10.0.2.2.
String backendUrl() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://127.0.0.1:8080';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sdk = await AxiomSdk.create(baseUrlOverrides: {'talks': backendUrl()});
  runApp(const MaterialApp(home: TalksPage()));
}

class TalksPage extends StatelessWidget {
  const TalksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Talks')),
      body: AxiomBuilder<models.TalkList, models.TalkList>(
        query: sdk.talks.listTalks(),
        loading: (context) => const Center(child: CircularProgressIndicator()),
        error: (context, error) => Center(child: Text(error.message)),
        builder: (context, state, list) => ListView(
          children: [
            for (final talk in list.talks)
              ListTile(title: Text(talk.title), subtitle: Text(talk.speaker)),
          ],
        ),
      ),
      floatingActionButton: AxiomMutationBuilder<models.Talk, String>(
        mutation: AxiomMutation(
          (title) => sdk.talks.createTalk(title: title, speaker: 'You'),
        ),
        builder: (context, state, execute) => FloatingActionButton.extended(
          onPressed: state.isMutating ? null : () => execute('My new talk'),
          label: Text(
            state.data == null ? 'Add talk' : 'Created ${state.data!.id}',
          ),
        ),
      ),
    );
  }
}
```

Run it:

```bash
flutter analyze
flutter run -d chrome --web-port 5000      # web
flutter run -d emulator-5554                # Android emulator (id from `flutter devices`)
flutter run -d macos                        # macOS
```

`AxiomSdk.create()` throws when the runtime or a contract fails to load, so
call it before `runApp`. Outside `AxiomBuilder`, a query is a stream:
`await sdk.talks.listTalks().stream.unwrap()` returns the first value or
throws the `AxiomError`.

## 7. Auth

Tokens live in runtime memory only; restore them from secure storage at
start-up.

```dart
// After sign-in: send `Authorization: Bearer <token>` to this contract only.
sdk.runtime.setNamespaceAuthToken(namespace: 'talks', token: accessToken);

// Or fetch a fresh token when a call needs one (null = signed out).
sdk.runtime.setAuthProvider((namespace, methodName) async => myAuth.token());

// Logout: cancels calls, clears tokens and the session cache.
await sdk.runtime.resetSession();
```

For managed sign-in (password, email code, social, MFA, refresh), add
`axiom_flutter_auth` and attach it with
`AxiomAuthBinding.attach(auth, namespaces: ['talks'])`; see its README.

## 8. Cache

The contract chooses the cache per `GET` endpoint with
`cache(strategy: ..., ttl: ...)` (`networkOnly`, `cacheFirst`, `networkFirst`,
`staleWhileRevalidate`). From Dart:

```dart
query.refresh();                                   // revalidate one query
sdk.talks.listTalks(
  options: const AxiomCallOptions(cacheMode: AxiomCacheMode.refresh),
);                                                 // skip the cache once
sdk.talks.axiom.invalidateAll();                   // refetch the contract's active queries
await sdk.runtime.clearCache();                    // drop cached data and refetch
```

The cache is stored in the app support directory on Android, iOS and macOS and
in `localStorage` on the web (`AxiomConfig.dbPath` overrides the native
location). It is not a credential store.

## 9. Lean runtime and the extensions add-on

From 0.150.1, `axiom_flutter` bundles the **lean** runtime on Android and the
web: everything above works, but executable AxiomCore extensions
(`loadExtension`, `invokeExtension`, `extensionLifecycle`, `extensionAudit`)
are not compiled in. Apps that use extensions on Android add the add-on:

```bash
flutter pub add axiom_flutter_extensions:^0.150.1
```

The add-on carries the full Android runtime and the app then ships only that
library. Calling an extension method on the lean runtime throws an error that
names `axiom_flutter_extensions`. On iOS and macOS nothing changes: they keep
the full published runtime 0.148.6 until the next Apple runtime release. On
the web extensions are not available with either package.
<!-- VERIFY: lean default, add-on name/version, error text and "only one library per APK" are confirmed by /home/node/fp/pack/REPORT.md (unit pack, not DONE at time of writing) -->

Size and speed details: [`wasm-size.md`](wasm-size.md),
[App size](https://docs.axiomcore.dev/sdks/flutter-app-size) and
[Performance](https://docs.axiomcore.dev/sdks/flutter-performance).
