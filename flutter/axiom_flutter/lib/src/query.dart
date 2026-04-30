import 'dart:async';
import 'state.dart';
import 'query_manager.dart';

class AxiomQuery<T> {
  final String key;
  final bool isMutation;

  final Map<String, String> _customHeaders = {};
  Stream<AxiomState<T>>? _cachedStream;
  final Stream<AxiomState<T>> Function(Map<String, String> headers)
  _streamFactory;

  AxiomQuery(this.key, this._streamFactory, {this.isMutation = false});

  /// Appends a custom header to the HTTP Request.
  /// Example: query..setHeader('Content-Type', 'application/x-www-form-urlencoded')
  void setHeader(String key, String value) {
    _customHeaders[key] = value;
  }

  /// Execution triggers here! Delaying execution until the stream is
  /// accessed allows `..setHeader` to safely apply before the network runs.
  Stream<AxiomState<T>> get stream {
    _cachedStream ??= _streamFactory(_customHeaders);
    return _cachedStream!;
  }

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
