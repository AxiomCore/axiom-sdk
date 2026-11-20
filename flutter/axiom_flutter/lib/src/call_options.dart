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

/// Response validation policy (runtime 0.150.1+; ignored by runtimes without
/// a validation policy, such as the published Apple runtime 0.148.6, which
/// always validate fully).
enum AxiomValidationPolicy {
  /// Full below 64 KiB, sampled at or above (runtime default).
  auto,

  /// Validate every item.
  full,

  /// Validate the envelope and the first and last items of large lists.
  sample,

  /// No response validation (syntax check only).
  off,
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

  /// Response validation for this call (sent as call option `"validation"`).
  /// Null uses the endpoint, namespace or global policy.
  final AxiomValidationPolicy? validation;

  /// Creates call options. All fields are optional.
  const AxiomCallOptions({
    this.timeout,
    this.headers,
    this.cacheMode = AxiomCacheMode.normal,
    this.validation,
  });

  /// Headers to send for these options merged over [base].
  Map<String, String> mergeHeaders(Map<String, String>? base) => {
    ...?base,
    ...?headers,
    if (cacheMode == AxiomCacheMode.refresh) axiomCacheModeHeader: 'refresh',
  };

  /// Returns a copy with the given fields replaced.
  AxiomCallOptions copyWith({
    Duration? timeout,
    Map<String, String>? headers,
    AxiomCacheMode? cacheMode,
    AxiomValidationPolicy? validation,
  }) => AxiomCallOptions(
    timeout: timeout ?? this.timeout,
    headers: headers ?? this.headers,
    cacheMode: cacheMode ?? this.cacheMode,
    validation: validation ?? this.validation,
  );
}
