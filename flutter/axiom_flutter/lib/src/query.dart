import 'state.dart';

import 'query_manager.dart';

class AxiomQuery<T> {
   final String key;
   final Stream<AxiomState<T>> stream;
   
   AxiomQuery(this.key, this.stream);

   void refresh() {
      AxiomQueryManager().invalidate(key);
   }

   /// Starts fetching the data immediately, even if no widgets are listening yet.
  /// Useful for pre-loading data before navigation.
  Future<void> prefetch() async {
    // We listen to the stream to trigger the side-effect (network call).
    // The ActiveQuery logic ensures this single subscription triggers the fetch
    // and caches the result. We cancel immediately after the first data arrives
    // or error occurs, as we just wanted to 'prime the pump'.
    final subscription = stream.listen(null);
    try {
      await stream.firstWhere((s) => s.hasData || s.hasError);
    } finally {
      subscription.cancel();
    }
  }
}