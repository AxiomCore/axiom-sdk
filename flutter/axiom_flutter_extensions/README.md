# axiom_flutter_extensions

Full AxiomCore runtime for [`axiom_flutter`](https://pub.dev/packages/axiom_flutter),
with **executable extensions** (signed, sandboxed WebAssembly modules loaded
through `AxiomRuntime.loadExtension` / `invokeExtension`) and the telemetry
exporter.

Since 0.150.1 `axiom_flutter` bundles a lean runtime on Android and web that
leaves these out (about 5 MB smaller per Android ABI). Add this package only
if your app uses executable extensions.

## Install

```yaml
dependencies:
  axiom_flutter: ^0.150.1
  axiom_flutter_extensions: ^0.150.1
```

No code is needed: depending on the package is enough. Optionally call
`AxiomExtensions.ensureInitialized()` before initializing Axiom to get a clear
error early if the library was not packaged:

```dart
import 'package:axiom_flutter_extensions/axiom_flutter_extensions.dart';

void main() {
  AxiomExtensions.ensureInitialized();
  // ... AxiomRuntime().initialize(...)
}
```

Without this package, extension calls on Android throw
`AxiomExtensionException` with "Executable extensions need the
axiom_flutter_extensions package".

## What it does per platform

| Platform | Effect |
| --- | --- |
| Android | Ships `libaxiom_runtime_full.so` for arm64-v8a, armeabi-v7a and x86_64 (minSdk 24). `axiom_flutter` loads it in preference to its lean `libaxiom_runtime.so`. The package's Gradle build removes the lean library from your APK/AAB so only one runtime is shipped. |
| iOS, macOS | Nothing. `axiom_flutter` already uses the full published runtime (AxiomRuntime 0.148.6) on Apple platforms. |
| Web | Nothing. Executable extensions are native only; extension methods throw `UnsupportedError` on web. |

### Keeping both libraries

To keep `axiom_flutter`'s lean `libaxiom_runtime.so` in the app as well (not
needed in normal use), add to `android/gradle.properties`:

```properties
axiom.keepLeanRuntime=true
```

## Size

Measured on the `axiom_flutter` integration app, arm64 release APK, Flutter
3.32.0: 21.3 MB with the lean default, 26.4 MB with this package
(`libaxiom_runtime_full.so` is 10.1 MB uncompressed for arm64).

## Versions

The runtime build is recorded in `runtime-pin.json` (variant `full`, sha256 per
ABI). Use the same minor version as `axiom_flutter`.

## License

MIT, see [LICENSE](LICENSE).
