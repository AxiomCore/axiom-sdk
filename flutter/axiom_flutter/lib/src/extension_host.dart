import 'dart:typed_data';

/// Platform lifecycle events forwarded to extension hosts. Values are the
/// stable C ABI constants accepted by `axiom_extension_lifecycle`.
enum AxiomLifecycleEvent {
  foreground(0),
  background(1),
  componentRemoved(2),
  navigationAway(3),
  reload(4),
  processLoss(5),
  requestEnd(6),
  workerShutdown(7),
  appShutdown(8);

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
  final String extension;
  final String export;
  final String interfaceSha256;
  final String abiSymbol;

  /// JSON-encodable input; encoded with `jsonEncode`.
  final Object? input;

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
  final String operation;
  final int status;
  final String? message;

  AxiomExtensionException(this.operation, this.status, [this.message]);

  @override
  String toString() =>
      'AxiomExtensionException($operation failed with status $status'
      '${message == null ? '' : ': $message'})';
}
