// FILE: lib/src/config.dart

class AxiomContractConfig {
  final String baseUrl;
  final String assetPath; // e.g., 'assets/.axiom'

  const AxiomContractConfig({required this.baseUrl, required this.assetPath});
}

class AxiomConfig {
  final Map<String, AxiomContractConfig> contracts;
  final bool debug;
  final String? dbPath;

  const AxiomConfig({required this.contracts, this.debug = false, this.dbPath});
}
