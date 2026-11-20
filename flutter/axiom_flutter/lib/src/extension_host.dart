import 'dart:typed_data';

/// Platform lifecycle events forwarded to extension hosts. Values are the
/// stable C ABI constants accepted by `axiom_extension_lifecycle`.
enum AxiomLifecycleEvent {
  /// App moved to the foreground.
  foreground(0),

  /// App moved to the background.
  background(1),

  /// The UI component that used the extension was removed.
  componentRemoved(2),

  /// The user navigated away.
  navigationAway(3),

  /// The app or page reloads.
  reload(4),

  /// The process is about to be lost.
  processLoss(5),

  /// A request finished.
  requestEnd(6),

  /// A worker shuts down.
  workerShutdown(7),

  /// The app shuts down.
  appShutdown(8);

  /// Numeric code passed to the runtime (same as the C constant).
  final int code;
  const AxiomLifecycleEvent(this.code);
}

/// The trusted, app-embedded bytes for one sandboxed extension
/// (`axiom_extension_load_locked`). Nothing is read from a path or network.
class AxiomExtensionPackage {
  /// Extension target name (`target`).
  final String target;

  /// JSON configuration passed to the host (`config_json`).
  final String configJson;

  /// Signed package bytes.
  final Uint8List packageBytes;

  /// WASM module bytes.
  final Uint8List moduleBytes;

  /// Authority lock bytes.
  final Uint8List authorityBytes;

  /// Canonical package lock bytes.
  final Uint8List packageLockBytes;

  /// Creates a package from embedded bytes.
  const AxiomExtensionPackage({
    required this.target,
    this.configJson = '{}',
    required this.packageBytes,
    required this.moduleBytes,
    required this.authorityBytes,
    required this.packageLockBytes,
  });
}

/// One call into a verified extension export (`axiom_extension_invoke`).
class AxiomExtensionCall {
  /// Name of the loaded extension.
  final String extension;

  /// Export to call.
  final String export;

  /// SHA-256 of the export interface the app was built against.
  final String interfaceSha256;

  /// ABI symbol of the export.
  final String abiSymbol;

  /// JSON-encodable input; encoded with `jsonEncode`.
  final Object? input;

  /// Creates a call. [input] is encoded with `jsonEncode`.
  const AxiomExtensionCall({
    required this.extension,
    required this.export,
    required this.interfaceSha256,
    required this.abiSymbol,
    this.input,
  });
}

/// Thrown when an extension FFI call returns a non-zero status.
class AxiomExtensionException implements Exception {
  /// Operation that failed, for example `invoke`.
  final String operation;

  /// Non-zero status returned by the runtime.
  final int status;

  /// Message from the runtime, if any.
  final String? message;

  /// Creates the exception.
  AxiomExtensionException(this.operation, this.status, [this.message]);

  @override
  String toString() =>
      'AxiomExtensionException($operation failed with status $status'
      '${message == null ? '' : ': $message'})';
}
