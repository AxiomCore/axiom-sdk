/// Shared rule for explicitly set namespace-wide / global tokens (native and
/// web): backend-profile contracts publish no client auth metadata
/// (`"auth": null` on every endpoint), so the runtime never injects a stored
/// token for them. The SDK therefore sends `Authorization: Bearer <token>` as
/// a request header itself, unless the caller already set an Authorization
/// header. Per-method `setAuthToken` keeps the runtime path.
class AxiomAuthHeaders {
  AxiomAuthHeaders._();

  static const String authorization = 'Authorization';

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
