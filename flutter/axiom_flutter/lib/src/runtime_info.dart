/// Version handshake between the Dart package and the native or wasm runtime.
///
/// Backed by `axiom_abi_version`, `axiom_data_abi_version` and
/// `axiom_contract_reader_version` (native) and
/// `axiom_wasm_data_abi_version` / `axiom_wasm_contract_reader_version` (web).
class AxiomRuntimeInfo {
  /// Transport ABI (`axiom_abi_version`). Must equal [expectedAbiVersion].
  final int abiVersion;

  /// Data semantics ABI (`axiom_data_abi_version`). Must equal
  /// [expectedDataAbiVersion].
  final int dataAbiVersion;

  /// Contract descriptor reader capability
  /// (`axiom_contract_reader_version`). Must be at least
  /// [minContractReaderVersion].
  final int contractReaderVersion;

  const AxiomRuntimeInfo({
    required this.abiVersion,
    required this.dataAbiVersion,
    required this.contractReaderVersion,
  });

  /// Transport ABI this Dart package was written against.
  static const int expectedAbiVersion = 1;

  /// Data ABI this Dart package was written against.
  static const int expectedDataAbiVersion = 1;

  /// Oldest contract reader this Dart package accepts.
  static const int minContractReaderVersion = 3;

  /// The versions this package expects.
  static const AxiomRuntimeInfo expected = AxiomRuntimeInfo(
    abiVersion: expectedAbiVersion,
    dataAbiVersion: expectedDataAbiVersion,
    contractReaderVersion: minContractReaderVersion,
  );

  /// Whether this runtime can be driven by this Dart package.
  bool get isCompatible =>
      abiVersion == expectedAbiVersion &&
      dataAbiVersion == expectedDataAbiVersion &&
      contractReaderVersion >= minContractReaderVersion;

  /// Throws [AxiomVersionMismatch] when [isCompatible] is false.
  void requireCompatible() {
    if (!isCompatible) throw AxiomVersionMismatch(this);
  }

  Map<String, int> toJson() => {
    'abiVersion': abiVersion,
    'dataAbiVersion': dataAbiVersion,
    'contractReaderVersion': contractReaderVersion,
  };

  @override
  String toString() =>
      'AxiomRuntimeInfo(abi: $abiVersion, dataAbi: $dataAbiVersion, '
      'contractReader: $contractReaderVersion)';
}

/// Thrown (and reported in [AxiomInitResult.error]) when the loaded runtime
/// library does not match this Dart package.
class AxiomVersionMismatch implements Exception {
  final AxiomRuntimeInfo actual;
  final AxiomRuntimeInfo expected;

  AxiomVersionMismatch(
    this.actual, [
    this.expected = AxiomRuntimeInfo.expected,
  ]);

  @override
  String toString() =>
      'AxiomVersionMismatch: the Axiom runtime library reports '
      'abi=${actual.abiVersion}, dataAbi=${actual.dataAbiVersion}, '
      'contractReader=${actual.contractReaderVersion}, but axiom_flutter '
      'requires abi=${expected.abiVersion}, dataAbi=${expected.dataAbiVersion}, '
      'contractReader>=${expected.contractReaderVersion}. Upgrade the runtime '
      'binary (pod / Android jniLibs / web wasm) and axiom_flutter together.';
}
