import 'dart:ffi';
import 'dart:io';

/// Entry point of the add-on.
abstract final class AxiomExtensions {
  /// Checks that the full runtime is available. Call it before
  /// `Axiom.initialize` if you want a clear error when the add-on was not
  /// packaged (for example a custom Gradle build that dropped it).
  ///
  /// Throws [StateError] on Android when `libaxiom_runtime_full.so` cannot be
  /// loaded. On iOS and macOS the bundled runtime is already the full build,
  /// so this does nothing.
  static void ensureInitialized() {
    if (!Platform.isAndroid) return;
    try {
      DynamicLibrary.open('libaxiom_runtime_full.so');
    } on ArgumentError catch (e) {
      throw StateError(
        'axiom_flutter_extensions: libaxiom_runtime_full.so is not in this '
        'app (bundled for arm64-v8a, armeabi-v7a and x86_64). Cause: $e',
      );
    }
  }

  /// True when executable extensions can run on this platform with this
  /// package: Android (full library bundled), iOS and macOS (full runtime).
  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}
