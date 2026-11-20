// FILE: lib/src/config.dart

/// Configuration for one contract namespace.
class AxiomContractConfig {
  /// Default base URL baked in by the generator. Overridden by
  /// [AxiomConfig.baseUrlOverrides], then by [AxiomConfig.environment].
  final String baseUrl;

  /// Flutter asset path of the `.axiom` contract, e.g. `assets/axiom/ns.axiom`.
  final String assetPath;

  /// Detached contract signature (base64). Passed to `axiom_load_contract`
  /// / `axiom_load_contract_locked`. Null loads unsigned (status -1, dev only).
  final String? signature;

  /// Public key (base64) that verifies [signature].
  final String? publicKey;

  /// Lowercase hex sha256 of the contract bytes. When set the contract is
  /// loaded with `axiom_load_contract_locked`, which rejects a mismatched
  /// hash or a missing/invalid signature before activation. Written by
  /// `axiom pull`; generated code sets it in release builds.
  final String? sha256;

  const AxiomContractConfig({
    required this.baseUrl,
    required this.assetPath,
    this.signature,
    this.publicKey,
    this.sha256,
  });

  /// True when this contract must go through the hash-locked load.
  bool get isLocked => sha256 != null && sha256!.isNotEmpty;

  AxiomContractConfig copyWith({
    String? baseUrl,
    String? assetPath,
    String? signature,
    String? publicKey,
    String? sha256,
  }) => AxiomContractConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    assetPath: assetPath ?? this.assetPath,
    signature: signature ?? this.signature,
    publicKey: publicKey ?? this.publicKey,
    sha256: sha256 ?? this.sha256,
  );
}

/// A named deployment environment (for example `dev`, `staging`, `prod`)
/// mapping namespaces to base URLs.
class AxiomEnvironment {
  final String name;

  /// Base URL per namespace for this environment.
  final Map<String, String> baseUrls;

  /// Base URL used for namespaces missing from [baseUrls]; null keeps the
  /// contract default.
  final String? defaultBaseUrl;

  const AxiomEnvironment({
    required this.name,
    this.baseUrls = const {},
    this.defaultBaseUrl,
  });

  /// Reads `--dart-define=AXIOM_ENV=<name>` and
  /// `--dart-define=AXIOM_BASE_URL=<url>` at compile time. Returns null when
  /// neither is defined.
  static AxiomEnvironment? fromDartDefines() {
    const name = String.fromEnvironment('AXIOM_ENV');
    const url = String.fromEnvironment('AXIOM_BASE_URL');
    if (name.isEmpty && url.isEmpty) return null;
    return AxiomEnvironment(
      name: name.isEmpty ? 'custom' : name,
      defaultBaseUrl: url.isEmpty ? null : url,
    );
  }
}

class AxiomConfig {
  final Map<String, AxiomContractConfig> contracts;
  final bool debug;
  final String? dbPath;

  /// Selected environment; its URLs override contract defaults.
  final AxiomEnvironment? environment;

  /// Highest-priority base URL per namespace (e.g. from app settings).
  final Map<String, String> baseUrlOverrides;

  /// Fail initialization when a contract is loaded unsigned. Generated code
  /// sets this in release builds.
  final bool requireSignedContracts;

  const AxiomConfig({
    required this.contracts,
    this.debug = false,
    this.dbPath,
    this.environment,
    this.baseUrlOverrides = const {},
    this.requireSignedContracts = false,
  });

  /// Effective base URL for [namespace]:
  /// [baseUrlOverrides] > [environment] namespace URL >
  /// [environment] default URL > [AxiomContractConfig.baseUrl].
  String resolveBaseUrl(String namespace) {
    final override = baseUrlOverrides[namespace];
    if (override != null) return override;
    final env = environment;
    if (env != null) {
      final url = env.baseUrls[namespace] ?? env.defaultBaseUrl;
      if (url != null) return url;
    }
    final contract = contracts[namespace];
    if (contract == null) {
      throw ArgumentError.value(namespace, 'namespace', 'no such contract');
    }
    return contract.baseUrl;
  }

  AxiomConfig copyWith({
    Map<String, AxiomContractConfig>? contracts,
    bool? debug,
    String? dbPath,
    AxiomEnvironment? environment,
    Map<String, String>? baseUrlOverrides,
    bool? requireSignedContracts,
  }) => AxiomConfig(
    contracts: contracts ?? this.contracts,
    debug: debug ?? this.debug,
    dbPath: dbPath ?? this.dbPath,
    environment: environment ?? this.environment,
    baseUrlOverrides: baseUrlOverrides ?? this.baseUrlOverrides,
    requireSignedContracts:
        requireSignedContracts ?? this.requireSignedContracts,
  );
}
