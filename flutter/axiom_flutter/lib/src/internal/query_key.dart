import 'dart:convert';

/// Utilities for generating deterministic cache keys for Axiom queries.
class AxiomQueryKey {
  /// Builds a stable string key for a query based on the endpoint name and arguments.
  ///
  /// Example: `get_user:{"id":1}`
  static String build({
    required String endpoint,
    required Map<String, dynamic> args,
  }) {
    final normalized = _normalize(args);
    return '$endpoint:${jsonEncode(normalized)}';
  }

  /// Sorts keys alphabetically and removes null values to ensure
  /// that `{a:1, b:null}` and `{a:1}` produce the same key,
  /// and `{a:1, b:2}` is the same as `{b:2, a:1}`.
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
