/// Full AxiomCore runtime (executable extensions) for `axiom_flutter`.
///
/// Adding this package to `pubspec.yaml` is all that is needed on Android:
/// it bundles `libaxiom_runtime_full.so`, which `axiom_flutter` loads in
/// preference to its lean `libaxiom_runtime.so`, and its Gradle build removes
/// the lean library from the app. iOS and macOS already ship the full
/// runtime; on web executable extensions are not available.
library;

export 'src/extensions_io.dart'
    if (dart.library.js_interop) 'src/extensions_web.dart';
