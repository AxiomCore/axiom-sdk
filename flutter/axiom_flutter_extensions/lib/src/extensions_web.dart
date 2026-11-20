/// Entry point of the add-on. On web executable extensions are native only,
/// so this package has no effect.
abstract final class AxiomExtensions {
  /// Does nothing on web.
  static void ensureInitialized() {}

  /// Always false on web: executable extensions are native only.
  static bool get isSupported => false;
}
