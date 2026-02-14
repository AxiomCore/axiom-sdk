import 'state.dart';

import 'query_manager.dart';

class AxiomQuery<T> {
  final String key;
  final Stream<AxiomState<T>> stream;

  AxiomQuery(this.key, this.stream);

  void refresh() {
    AxiomQueryManager().invalidate(key);
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
