# The web runtime in non-web builds

`axiom_flutter` runs the Axiom runtime on the web as WebAssembly. Two files
are declared as package assets in `pubspec.yaml`:

| file | size | gzip |
| --- | --- | --- |
| `lib/assets/wasm/axiom_runtime_bg.wasm` | 2.45 MB | ~0.92 MB |
| `lib/assets/wasm/axiom_runtime.js` (glue) | 39 KB | ~9 KB |

Flutter 3.32 has no per-platform assets, so these files are also copied into
Android, iOS and macOS bundles, which never load them (they use the native
runtime). Measured on the integration app (Linux, Flutter 3.32.0): an Android
arm64 release APK is 27,087,035 bytes with the files and 26,130,228 bytes
without them (−957 KB, because the APK compresses the wasm). An iOS/macOS app
grows by the uncompressed 2.48 MB before App Store compression.

Options that were tried and do not work with Flutter 3.32:

- per-platform assets in `pubspec.yaml`: not supported by this Flutter version;
- shipping the files under `lib/` without declaring them as assets:
  `flutter build web` then does not copy them, so the web build breaks;
- a web plugin registration: it cannot serve files either.

So the package keeps bundling them (the web works offline, straight from the
package, with no CDN). Apps that want to drop the files from native builds can
opt out in their own project:


## Android: removed automatically (since flutter/perf)

The plugin's own `android/build.gradle` deletes
`packages/axiom_flutter/lib/assets/wasm/**` from the app's merged Flutter
assets after Flutter copies them, so Android APKs/AABs no longer carry the web
runtime. Measured (benchmarks app, arm64 release APK, Flutter 3.32.0):
26,988,656 bytes with the files, 26,032,037 bytes without (−956,619).
To keep them, add `axiom.keepWebAssets=true` to the app's
`android/gradle.properties` (or pass
`--android-project-arg=axiom.keepWebAssets=true`). The app-side snippet below
is no longer needed on Android. iOS/macOS: a CocoaPods script phase runs
before the Runner target copies `flutter_assets`, so the plugin cannot remove
them there; the app-side opt-out below still applies.

## Android (verified)

Append to `android/app/build.gradle.kts`:

```kotlin
// axiom_flutter: drop the web runtime (wasm + JS glue) from Android builds.
tasks.matching { it.name.startsWith("copyFlutterAssets") }.configureEach {
    doLast {
        outputs.files.forEach { out ->
            fileTree(out) { include("**/packages/axiom_flutter/lib/assets/wasm/**") }
                .forEach { it.delete() }
        }
    }
}
```

The Groovy (`build.gradle`) form:

```groovy
tasks.matching { it.name.startsWith("copyFlutterAssets") }.configureEach {
    doLast {
        outputs.files.each { out ->
            fileTree(out) { include "**/packages/axiom_flutter/lib/assets/wasm/**" }
                .each { it.delete() }
        }
    }
}
```

`androidResources { ignoreAssetsPattern = ... }` does NOT work: Flutter copies
its assets after the AAPT asset merge.

## iOS and macOS (not verified: no Apple tools on the box where this was written)

Use the script shipped with the package as a Run Script build phase of the
Runner target, placed after the phase that runs `xcode_backend.sh build`
(iOS "Run Script") and before "Thin Binary" (iOS), or before the
`macos_assemble.sh embed` Run Script phase (macOS):

```sh
"${PODS_ROOT}/../.symlinks/plugins/axiom_flutter/ios/axiom_strip_web_assets.sh"
# macOS: "${PODS_ROOT}/../.symlinks/plugins/axiom_flutter/macos/axiom_strip_web_assets.sh"
```

Uncheck "Based on dependency analysis" for that phase, and set
`ENABLE_USER_SCRIPT_SANDBOXING = NO` for the target if Xcode denies the
delete. The script removes the files from the unsigned `App.framework` in
`${BUILT_PRODUCTS_DIR}` before Flutter embeds and signs it. Do NOT delete them
after "Thin Binary" (an earlier version of this page said so): by then
`App.framework` is signed, and changing its resources breaks the signature
seal on device builds and App Store validation (the script re-signs in that
case). A CocoaPods `script_phase` cannot do this: it runs in the pod target,
which builds before the Runner target assembles `flutter_assets`.
The asset manifest still lists the two files, which is harmless because
native code never requests them.
