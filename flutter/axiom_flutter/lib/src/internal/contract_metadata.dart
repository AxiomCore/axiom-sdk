/// Contract metadata the runtime C ABI does not expose, registered by
/// generated code (one call per namespace in `create()`), shared by the
/// native and web runtimes.
///
/// - auth method names per namespace: used by `setNamespaceAuthToken` /
///   `setGlobalAuthToken`, because `axiom_set_auth_token` needs a method name
///   and has no wildcard.
/// - cache identities per namespace: endpoint ids whose contract declares a
///   `cacheIdentity(...)`, used by `invalidate(cacheIdentity:)`.
class AxiomContractMetadata {
  AxiomContractMetadata._();

  static final Map<String, Set<String>> _authMethods = {};
  static final Map<String, Map<String, Set<int>>> _cacheIdentities = {};
  static final List<void Function(String namespace)> _listeners = [];

  /// Registers the contract auth method names of [namespace].
  static void registerAuthMethods(String namespace, Iterable<String> methods) {
    (_authMethods[namespace] ??= <String>{}).addAll(methods);
    for (final l in List.of(_listeners)) {
      l(namespace);
    }
  }

  /// Registers `cacheIdentity -> endpoint ids` for [namespace].
  static void registerCacheIdentities(
    String namespace,
    Map<String, Iterable<int>> identities,
  ) {
    final map = _cacheIdentities[namespace] ??= {};
    identities.forEach((identity, ids) {
      (map[identity] ??= <int>{}).addAll(ids);
    });
  }

  static Set<String> authMethodsFor(String namespace) =>
      _authMethods[namespace] ?? const {};

  static Iterable<String> get namespacesWithAuth => _authMethods.keys;

  /// Endpoint ids for [cacheIdentity] in [namespace], or null when unknown.
  static Set<int>? endpointsForIdentity(String namespace, String identity) =>
      _cacheIdentities[namespace]?[identity];

  /// Called with the namespace whenever auth methods are registered.
  static void addListener(void Function(String namespace) listener) =>
      _listeners.add(listener);

  static void clear() {
    _authMethods.clear();
    _cacheIdentities.clear();
  }
}
