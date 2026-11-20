/// Shared rule for explicitly set namespace-wide / global tokens (native and
/// web): backend-profile contracts publish no client auth metadata
/// (`"auth": null` on every endpoint), so the runtime never injects a stored
/// token for them. The SDK therefore sends `Authorization: Bearer <token>` as
/// a request header itself, unless the caller already set an Authorization
/// header. Per-method `setAuthToken` keeps the runtime path.
///
/// Scope: a namespace token is only ever sent for its own namespace
/// ([explicitTokenFor]). A global token reaches every namespace, including
/// contracts on third-party hosts, so it is only what the app set explicitly
/// with `setGlobalAuthToken`; the SDK and `AxiomAuthBinding` never set one.
class AxiomAuthHeaders {
  AxiomAuthHeaders._();

  static const String authorization = 'Authorization';

  /// The explicit token for a call of [namespace]: its own namespace token,
  /// otherwise the app-set [globalToken]. A token stored for another
  /// namespace is never returned, and an empty namespace (unknown caller)
  /// gets only the global token.
  static String? explicitTokenFor(
    String namespace,
    Map<String, String> namespaceTokens,
    String? globalToken,
  ) {
    final own = namespace.isEmpty ? null : namespaceTokens[namespace];
    if (own != null && own.isNotEmpty) return own;
    return (globalToken == null || globalToken.isEmpty) ? null : globalToken;
  }

  /// True when [headers] already carries an Authorization header (any case).
  static bool hasAuthorization(Map<String, String>? headers) =>
      headers != null &&
      headers.keys.any((k) => k.toLowerCase() == 'authorization');

  /// [headers] plus `Authorization: Bearer <token>` when [token] is non-empty
  /// and no Authorization header is present. Returns [headers] unchanged
  /// otherwise.
  static Map<String, String>? withBearer(
    Map<String, String>? headers,
    String? token,
  ) {
    if (token == null || token.isEmpty || hasAuthorization(headers)) {
      return headers;
    }
    final value = token.toLowerCase().startsWith('bearer ')
        ? token
        : 'Bearer $token';
    return {...?headers, authorization: value};
  }
}
