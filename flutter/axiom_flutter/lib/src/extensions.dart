import 'dart:async';
import 'state.dart';

extension AxiomStreamExtensions<T> on Stream<AxiomState<T>> {
  
  /// Returns a Future that completes with the first valid data received.
  /// Useful for "awaiting" a stream result like a standard API call.
  /// Throws if the stream ends or errors without data.
  Future<T> unwrap() {
    return firstWhere((s) => s.data != null || (s.hasError && !s.isFetching))
        .then((s) {
          if (s.data != null) return s.data!;
          throw s.error ?? Exception("Stream completed with no data");
        });
  }

  /// Filters the stream to only emit data events.
  Stream<T> onlyData() {
    return where((s) => s.data != null).map((s) => s.data!);
  }
  
  /// Side effect: Execute callback when data arrives (cache or network).
  Stream<AxiomState<T>> onData(void Function(T data) callback) {
    return map((state) {
      if (state.data != null) callback(state.data as T);
      return state;
    });
  }
}