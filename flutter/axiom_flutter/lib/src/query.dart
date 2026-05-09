import 'dart:async';
import 'package:axiom_flutter/src/runtime_interface.dart';

import 'state.dart';
import 'query_manager.dart';

class AxiomQuery<T> {
  final String key;
  final bool isMutation;

  final Map<String, String> _customHeaders = {};
  Stream<AxiomState<T>>? _cachedStream;

  // The factory returns the wrapper so QueryManager can grab the Request ID
  final AxiomActiveStream<T> Function(Map<String, String> headers)
  _streamFactory;

  AxiomQuery(this.key, this._streamFactory, {this.isMutation = false});

  void setHeader(String key, String value) {
    _customHeaders[key] = value;
  }

  /// The public getter for the UI
  Stream<AxiomState<T>> get stream {
    // ✨ FIX: Extract .stream from the AxiomActiveStream wrapper
    _cachedStream ??= _streamFactory(_customHeaders).stream;
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
