import 'runtime_info.dart';

/// How a contract was trusted when it was loaded.
enum AxiomContractTrust {
  /// Loaded with `axiom_load_contract` without signature (status -1,
  /// local/unsigned development mode).
  unsigned,

  /// Signature and public key verified (status 0).
  signed,

  /// Loaded with `axiom_load_contract_locked`: sha256 lock and signature
  /// both verified.
  locked,
}

/// Load outcome for one contract namespace.
class AxiomContractLoadResult {
  final String namespace;
  final String baseUrl;

  /// Raw status returned by the runtime (0 success, -1 success unverified,
  /// otherwise an [FfiError] code).
  final int status;

  /// Trust level; null when loading failed.
  final AxiomContractTrust? trust;

  /// Error description when [ok] is false.
  final Object? error;

  const AxiomContractLoadResult({
    required this.namespace,
    required this.baseUrl,
    required this.status,
    this.trust,
    this.error,
  });

  bool get ok => status == 0 || status == -1;
  bool get isSigned =>
      trust == AxiomContractTrust.signed || trust == AxiomContractTrust.locked;

  @override
  String toString() =>
      'AxiomContractLoadResult($namespace, status: $status, trust: $trust'
      '${error == null ? '' : ', error: $error'})';
}

/// Result of [AxiomRuntime.initialize]. Calling `initialize` again returns
/// the same result (idempotent) unless [AxiomRuntime.shutdown] ran in between.
class AxiomInitResult {
  /// True when the runtime started, versions matched and every contract
  /// loaded.
  final bool ok;

  /// First fatal error (for example [AxiomVersionMismatch]), or null.
  final Object? error;

  /// Versions reported by the runtime; null if the library could not be
  /// opened.
  final AxiomRuntimeInfo? runtimeInfo;

  /// Per-namespace load results, keyed by namespace.
  final Map<String, AxiomContractLoadResult> contracts;

  /// Wall-clock time spent in initialize.
  final Duration duration;

  /// True when this result was returned from an earlier, already completed
  /// initialization.
  final bool alreadyInitialized;

  const AxiomInitResult({
    required this.ok,
    this.error,
    this.runtimeInfo,
    this.contracts = const {},
    this.duration = Duration.zero,
    this.alreadyInitialized = false,
  });

  /// Throws [error] (or a [StateError]) when [ok] is false; returns this.
  AxiomInitResult requireOk() {
    if (ok) return this;
    final e = error;
    if (e is Exception) throw e;
    if (e is Error) throw e;
    final failed = contracts.values.where((c) => !c.ok).toList();
    throw StateError('Axiom initialization failed: ${e ?? failed}');
  }

  @override
  String toString() =>
      'AxiomInitResult(ok: $ok, error: $error, runtime: $runtimeInfo, '
      'contracts: ${contracts.values.toList()}, duration: $duration)';
}
