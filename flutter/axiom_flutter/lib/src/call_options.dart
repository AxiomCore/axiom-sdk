/// Header understood by the runtime engine to bypass a cached response.
const String axiomCacheModeHeader = 'x-axiom-cache-mode';

/// Cache behaviour for one call.
enum AxiomCacheMode {
  /// Contract default: serve cache then revalidate where the endpoint allows.
  normal,

  /// Skip the cached value and fetch from network, then update the cache.
  /// Sent as `x-axiom-cache-mode: refresh`.
  refresh,
}

/// Per-call options accepted by `send`, `sendMutation` and `callStream`.
class AxiomCallOptions {
  /// Deadline for the whole call. When it passes the SDK cancels the request
  /// (`axiom_cancel`) and emits an error with code [NetworkTimeout]. Null
  /// uses the runtime/contract default.
  final Duration? timeout;

  /// Extra request headers, merged over generated headers.
  final Map<String, String>? headers;

  /// Cache behaviour; [AxiomCacheMode.refresh] adds [axiomCacheModeHeader].
  final AxiomCacheMode cacheMode;

  const AxiomCallOptions({
    this.timeout,
    this.headers,
    this.cacheMode = AxiomCacheMode.normal,
  });

  /// Headers to send for these options merged over [base].
  Map<String, String> mergeHeaders(Map<String, String>? base) => {
    ...?base,
    ...?headers,
    if (cacheMode == AxiomCacheMode.refresh) axiomCacheModeHeader: 'refresh',
  };

  AxiomCallOptions copyWith({
    Duration? timeout,
    Map<String, String>? headers,
    AxiomCacheMode? cacheMode,
  }) => AxiomCallOptions(
    timeout: timeout ?? this.timeout,
    headers: headers ?? this.headers,
    cacheMode: cacheMode ?? this.cacheMode,
  );
}
