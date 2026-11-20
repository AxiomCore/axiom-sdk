import 'dart:convert';

/// Utilities for generating deterministic cache keys for Axiom queries.
class AxiomQueryKey {
  /// Headers that never change what a request returns (tracing, retries,
  /// cache bypass), so they are not part of a query key.
  static const volatileHeaders = {
    'traceparent',
    'tracestate',
    'idempotency-key',
    'x-request-id',
    'x-axiom-cache-mode',
  };

  /// Builds a stable string key for a query based on the endpoint name and
  /// arguments. Request [headers] (minus [volatileHeaders]) and a per-call
  /// [timeout] are part of the key, so two calls that differ only there do
  /// not share a request. Without them the key is `<endpoint>:<args json>`.
  static String build({
    required String endpoint,
    required Map<String, dynamic> args,
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    final normalized = _normalize(args);
    final base = '$endpoint:${jsonEncode(normalized)}';
    final h = <String, String>{};
    headers?.forEach((k, v) {
      final name = k.toLowerCase();
      if (!volatileHeaders.contains(name)) h[name] = v;
    });
    final sortedHeaders = {for (final k in h.keys.toList()..sort()) k: h[k]};
    return '$base'
        '${sortedHeaders.isEmpty ? '' : '|h=${jsonEncode(sortedHeaders)}'}'
        '${timeout == null ? '' : '|t=${timeout.inMicroseconds}'}';
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> input) {
    if (input.isEmpty) return const {};

    final sortedKeys = input.keys.toList()..sort();
    final result = <String, dynamic>{};

    for (final key in sortedKeys) {
      final value = input[key];
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }
}
