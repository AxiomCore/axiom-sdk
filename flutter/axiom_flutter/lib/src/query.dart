import 'dart:async';
import 'package:axiom_flutter/src/runtime_interface.dart';

import 'call_options.dart';
import 'state.dart';
import 'query_manager.dart';

/// A lazily started, cached call.
///
/// Cancellation rule: a query's network request is cancelled
/// (`AxiomRuntime.cancel`) when the last listener of its shared stream
/// unsubscribes while the request is still in flight, unless the request is
/// a mutation (mutations always run to completion unless [cancel] is called
/// explicitly). The cached value stays available for the next listener.
class AxiomQuery<T> {
  final String _baseKey;
  final String Function(Map<String, String> customHeaders)? _keyForHeaders;
  final bool isMutation;

  /// Query key. Custom headers set with [setHeader] are part of it when the
  /// runtime supplied a key function (native), so calls that differ only in
  /// headers do not share a request.
  String get key => _keyForHeaders == null || _customHeaders.isEmpty
      ? _baseKey
      : _keyForHeaders(_customHeaders);

  final AxiomRuntime? _runtime;
  int? _requestId;

  final Map<String, String> _customHeaders = {};
  Stream<AxiomState<T>>? _cachedStream;

  // The factory returns the wrapper so QueryManager can grab the Request ID
  final AxiomActiveStream<T> Function(Map<String, String> headers)
  _streamFactory;

  AxiomQuery(
    String key,
    this._streamFactory, {
    this.isMutation = false,
    AxiomRuntime? runtime,
    String Function(Map<String, String> customHeaders)? keyForHeaders,
  }) : _baseKey = key,
       _keyForHeaders = keyForHeaders,
       _runtime = runtime;

  /// Runtime request id of the current fetch, once [stream] was read.
  int? get requestId {
    if (!isMutation) {
      final live = AxiomQueryManager().requestIdFor(key);
      if (live != null && live != 0) return live;
    }
    return _requestId;
  }

  void setHeader(String key, String value) {
    _customHeaders[key] = value;
  }

  /// The public getter for the UI
  Stream<AxiomState<T>> get stream {
    // ✨ FIX: Extract .stream from the AxiomActiveStream wrapper
    if (_cachedStream == null) {
      final active = _streamFactory(_customHeaders);
      _requestId = active.requestId;
      _cachedStream = active.stream;
    }
    return _cachedStream!;
  }

  /// Refetches this query. With [force] the fetch bypasses the runtime cache
  /// (header `x-axiom-cache-mode: refresh`, see [AxiomCacheMode.refresh]).
  void refresh({bool force = false}) {
    if (isMutation) return;
    AxiomQueryManager().invalidate(key, force: force);
  }

  /// Cancels the in-flight request, if any. Listeners receive one error
  /// with code [Cancelled]. Returns true when a live request was cancelled.
  bool cancel() {
    final id = requestId;
    if (id == null || id == 0) return false;
    return (_runtime ?? AxiomRuntime()).cancel(id);
  }

  Future<void> prefetch() async {
    final subscription = stream.listen(null);
    try {
      // Wait for a settled value so a background revalidation is not
      // cancelled when this temporary listener leaves.
      await stream.firstWhere((s) => (s.hasData && !s.isFetching) || s.hasError);
    } finally {
      subscription.cancel();
    }
  }
}
