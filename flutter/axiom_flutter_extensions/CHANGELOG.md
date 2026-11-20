## 0.150.1 - 2026-11-21

- Requires Flutter 3.32 or newer (Dart 3.8), stated in `environment.flutter`. pub.dev rejects an Android-only plugin whose Flutter constraint allows versions before 1.20.
- First release. Bundles the full AxiomCore runtime for Android
  (`libaxiom_runtime_full.so`, arm64-v8a, armeabi-v7a, x86_64; built from
  axiom-runtime with default features: executable extensions and telemetry
  exporter) and removes `axiom_flutter`'s lean `libaxiom_runtime.so` from the
  app. Opt out of the removal with `axiom.keepLeanRuntime=true`.
- `AxiomExtensions.ensureInitialized()` and `AxiomExtensions.isSupported`.
- iOS and macOS: no effect (axiom_flutter already uses the full runtime there).
  Web: no effect (executable extensions are native only).
