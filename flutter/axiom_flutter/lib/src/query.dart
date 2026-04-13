import 'state.dart';
import 'query_manager.dart';

class AxiomQuery<T> {
  final String key;
  final Stream<AxiomState<T>> stream;

  /// When true this query was created for a one-shot mutation (POST/PUT/DELETE).
  /// Mutations are never cached in AxiomQueryManager — every call fires a fresh
  /// network request and the stream is not shared with any other subscriber.
  final bool isMutation;

  AxiomQuery(this.key, this.stream, {this.isMutation = false});

  /// Trigger a re-fetch of this query.
  /// No-op for mutations (they are inherently one-shot).
  void refresh() {
    if (!isMutation) {
      AxiomQueryManager().invalidate(key);
    }
  }

  Future<void> prefetch() async {
    final subscription = stream.listen(null);
    try {
      await stream.firstWhere((s) => s.hasData || s.hasError);
    } finally {
      subscription.cancel();
    }
  }
}
