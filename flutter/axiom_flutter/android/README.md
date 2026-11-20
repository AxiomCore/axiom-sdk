# axiom_flutter Android module

This module ships the prebuilt LEAN AxiomCore runtime (no executable
extensions, no telemetry exporter; variant `lean` in `runtime-pin.json`),
`libaxiom_runtime.so`, for
`arm64-v8a`, `armeabi-v7a` and `x86_64` under `src/main/jniLibs/<abi>/`. It has
no Java or Kotlin code: the plugin is declared `ffiPlugin: true` in
`pubspec.yaml`, and Dart opens the library with
`DynamicLibrary.open('libaxiom_runtime_full.so')` first (shipped by the
`axiom_flutter_extensions` add-on, which also removes the lean library from
the app) and then `DynamicLibrary.open('libaxiom_runtime.so')`
(`lib/src/runtime_io.dart`).

To refresh all bundled runtimes at once (lean Android + lean wasm here, full
Android in `axiom_flutter_extensions`), with pins and the pin check:
`flutter/axiom_flutter/tool/bundle_runtime.sh <artifact-root>` (layout
`lean/{android,wasm}`, `full/android`; see the script header).

## Requirements for apps
- `minSdk 24` or higher (the library is built against android-24). New Flutter
  apps default to 21; set `minSdk = 24` in `android/app/build.gradle(.kts)`.
- `android.permission.INTERNET` in the main manifest.
- 32-bit x86 emulators are not supported (no `x86` library).
- No R8/ProGuard rules are needed (`consumer-rules.pro` explains why).
- Plain HTTP backends need a network security config. The integration app
  allows cleartext to `10.0.2.2` (the host as seen from the emulator) in debug
  builds only: `flutter/integration_app/android/app/src/debug/`.
  Run it against the fixture backend with
  `flutter run --dart-define=FIXTURE_BASE_URL=http://10.0.2.2:8791`.

## Cache directory
When `init()` gets no `dbPath`, the Android runtime stores its sled cache in
`<getApplicationSupportDirectory()>/axiom` (the app's private files directory).
Pass `AxiomConfig.dbPath` to override it.

## Why the libraries are committed
The three stripped libraries are 29.8 MB raw, 14.2 MB zipped, below the
40 MB limit set for in-package distribution, so there is no download step and
builds work offline. AGP stores them uncompressed and 16 KB aligned in the APK
(`zipalign -c -P 16 -v 4` passes).

## Producing and updating the libraries
```sh
. ~/.profile   # Android SDK, NDK 26.3.11579264, cargo-ndk, Rust android targets
export RUSTUP_TOOLCHAIN=stable CARGO_TARGET_DIR=/tmp/axiom-android-target
axiom-runtime/scripts/build-android-so.sh /tmp/axiom-android arm64-v8a armeabi-v7a x86_64
flutter/axiom_flutter/tool/fetch_android_runtime.sh /tmp/axiom-android "axiom-runtime <branch> <commit>"
flutter/axiom_flutter/tool/fetch_android_runtime.sh --check
```
The build script links with 16 KB max page size and fails if an `axiom_*`
export from `include/axiom.h` is missing. `fetch_android_runtime.sh` rejects
libraries whose LOAD segments are not 16 KB aligned, copies them into
`jniLibs/`, and writes their sha256 and size into both `runtime-pin.json`
files (`android.libraries`). `--check` verifies the committed files against
the pin.
