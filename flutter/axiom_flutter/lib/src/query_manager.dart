import 'dart:async';
import 'dart:typed_data';
import 'state.dart';
import 'runtime_interface.dart'; // Import this

class ActiveQuery<T> {
  final String key;
  StreamController<AxiomState<T>>? _controller;
  AxiomState<T> _lastState = AxiomState.loading();
  StreamSubscription? _rustSubscription;
  bool _streamClosed = false;

  // ✨ NEW: Track the active Request ID for WebSockets
  int? currentReqId;

  final AxiomActiveStream<T> Function() _createStream;

  ActiveQuery(this.key, this._createStream) {
    _controller = StreamController<AxiomState<T>>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  Stream<AxiomState<T>> get stream => _controller!.stream;
  AxiomState<T> get state => _lastState;

  void _onListen() {
    if (_rustSubscription == null || _streamClosed) {
      _connect();
    } else {
      _controller?.add(_lastState);
    }
  }

  void _connect() {
    _streamClosed = false;
    _rustSubscription?.cancel();

    // ✨ FIX: Capture the Request ID when the stream is created
    final active = _createStream();
    currentReqId = active.requestId;

    _rustSubscription = active.stream.listen(
      (newState) {
        _lastState = newState;
        if (!(_controller?.isClosed ?? true)) {
          _controller?.add(newState);
        }
      },
      onDone: () {
        // The Rust stream closed (EventType::Complete was received, which the
        // runtime translates to StreamController.close()). Mark the stream as
        // closed so the next subscriber triggers a fresh fetch.
        _streamClosed = true;
      },
      onError: (_) {
        // Dart stream-level errors are not used in this SDK (errors are sent
        // as AxiomState.error() data events), but handle defensively.
        _streamClosed = true;
      },
    );
  }

  void _onCancel() {
    // Keep _rustSubscription alive — cancelling it would abort an in-flight
    // request that may be needed by another subscriber on the broadcast stream.
    // The subscription is only cancelled in refetch() or dispose().
  }

  void refetch() {
    _rustSubscription?.cancel();
    _streamClosed = false;

    if (_lastState.hasData) {
      final refreshingState = AxiomState<T>.success(
        _lastState.data as T,
        _lastState.source,
        isFetching: true,
      );
      _lastState = refreshingState;
      _controller?.add(refreshingState);
    } else {
      final loadingState = AxiomState<T>.loading();
      _lastState = loadingState;
      _controller?.add(loadingState);
    }
    _connect();
  }

  void dispose() {
    _rustSubscription?.cancel();
    _controller?.close();
  }
}

class AxiomQueryManager {
  static final AxiomQueryManager _instance = AxiomQueryManager._();
  factory AxiomQueryManager() => _instance;
  AxiomQueryManager._();

  final Map<String, ActiveQuery> _activeQueries = {};

  Stream<AxiomState<T>> watch<T>(
    String key,
    AxiomActiveStream<T> Function() createFn, // ✨ FIX: Signature
  ) {
    if (_activeQueries.containsKey(key)) {
      final query = _activeQueries[key] as ActiveQuery<T>;
      return query.stream;
    }

    final query = ActiveQuery<T>(key, createFn);
    _activeQueries[key] = query;
    return query.stream;
  }

  // ✨ NEW: Native Send Method
  void send(String key, Uint8List payload, AxiomRuntime runtime) {
    final query = _activeQueries[key];
    if (query != null && query.currentReqId != null) {
      runtime.sendStreamMessage(
        requestId: query.currentReqId!,
        payload: payload,
      );
    } else {
      print('ATMX: Cannot send message, stream not active for $key');
    }
  }

  void invalidate(String key) {
    if (_activeQueries.containsKey(key)) {
      _activeQueries[key]?.refetch();
    }
  }

  /// Removes a key so the next watch() creates a completely fresh ActiveQuery.
  /// Use for mutations that must never share state across calls.
  void remove(String key) {
    _activeQueries.remove(key)?.dispose();
  }

  void clear() {
    for (var q in _activeQueries.values) {
      q.dispose();
    }
    _activeQueries.clear();
  }

  /// Similar to watch, but returns the full AxiomActiveStream wrapper.
  /// Used by the SDK to link the Query object to the Request ID.
  AxiomActiveStream<T> watchRaw<T>(
    String key,
    AxiomActiveStream<T> Function() createFn,
  ) {
    if (_activeQueries.containsKey(key)) {
      final query = _activeQueries[key] as ActiveQuery<T>;
      // Reconstruct wrapper from existing query
      return AxiomActiveStream<T>(query.currentReqId ?? 0, query.stream);
    }

    final query = ActiveQuery<T>(key, createFn);
    _activeQueries[key] = query;

    return AxiomActiveStream<T>(query.currentReqId ?? 0, query.stream);
  }
}
