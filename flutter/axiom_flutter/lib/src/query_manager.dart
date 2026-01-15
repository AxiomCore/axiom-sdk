import 'dart:async';
import 'state.dart';

/// A wrapper that makes a Stream behave like a ValueListenable/BehaviorSubject.
/// It replays the latest event to new listeners.
class ActiveQuery<T> {
  final String key;
  StreamController<AxiomState<T>>? _controller;
  AxiomState<T> _lastState = AxiomState.loading();
  StreamSubscription? _rustSubscription;
  final Stream<AxiomState<T>> Function() _createStream;

  ActiveQuery(this.key, this._createStream) {
    _controller = StreamController<AxiomState<T>>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  Stream<AxiomState<T>> get stream => _controller!.stream;
  AxiomState<T> get state => _lastState;

   void _onListen() {
    if (_rustSubscription == null) {
      _connect();
    } else {
      _controller?.add(_lastState);
    }
  }

  void _connect() {
    _rustSubscription = _createStream().listen((newState) {
      _lastState = newState;
      if (!(_controller?.isClosed ?? true)) {
        _controller?.add(newState);
      }
    });
  }

  void _onCancel() {
    // Optional: If no one is listening anymore, we could cancel the Rust stream
    // to save battery. For now, we keep it alive for caching purposes.
    // _rustSubscription?.cancel();
    // _rustSubscription = null;
  }

  void refetch() {
    // Cancel the old subscription (stop listening to old Rust request)
    _rustSubscription?.cancel();
    
    // Emit a 'refreshing' state (optional but good UX)
    // We keep the old data but set isFetching=true
    if (_lastState.hasData) {
        final refreshingState = AxiomState<T>.success(
            _lastState.data as T, 
            _lastState.source, 
            isFetching: true
        );
        _lastState = refreshingState;
        _controller?.add(refreshingState);
    } else {
        // Or just loading if no data
        final loadingState = AxiomState<T>.loading();
        _lastState = loadingState;
        _controller?.add(loadingState);
    }

    // Re-connect: Call the create function again to start a NEW request in Rust
    _connect();
  }
  
  void dispose() {
    _rustSubscription?.cancel();
    _controller?.close();
  }
}

class AxiomQueryManager {
  // Singleton
  static final AxiomQueryManager _instance = AxiomQueryManager._();
  factory AxiomQueryManager() => _instance;
  AxiomQueryManager._();

  final Map<String, ActiveQuery> _activeQueries = {};

  /// Returns an existing stream if active, or creates a new one.
  Stream<AxiomState<T>> watch<T>(String key, Stream<AxiomState<T>> Function() createFn) {
    if (_activeQueries.containsKey(key)) {
      final query = _activeQueries[key] as ActiveQuery<T>;
      return query.stream;
    }

    final query = ActiveQuery<T>(key, createFn);
    _activeQueries[key] = query;
    return query.stream;
  }

  /// Forces a refresh for a specific query key (triggers network call)
  void invalidate(String key) {
     if (_activeQueries.containsKey(key)) {
      _activeQueries[key]?.refetch();
    }
  }
  
  /// Clears all queries (e.g. on logout or hot restart)
  void clear() {
    for (var q in _activeQueries.values) {
      q.dispose();
    }
    _activeQueries.clear();
  }
}