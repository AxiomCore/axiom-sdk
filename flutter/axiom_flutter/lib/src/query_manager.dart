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
    // _rustSubscription?.cancel();
    // _rustSubscription = null;
  }

  void refetch() {
    _rustSubscription?.cancel();

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
    Stream<AxiomState<T>> Function() createFn,
  ) {
    if (_activeQueries.containsKey(key)) {
      final query = _activeQueries[key] as ActiveQuery<T>;
      return query.stream;
    }

    final query = ActiveQuery<T>(key, createFn);
    _activeQueries[key] = query;
    return query.stream;
  }

  void invalidate(String key) {
    if (_activeQueries.containsKey(key)) {
      _activeQueries[key]?.refetch();
    }
  }

  void clear() {
    for (var q in _activeQueries.values) {
      q.dispose();
    }
    _activeQueries.clear();
  }
}
