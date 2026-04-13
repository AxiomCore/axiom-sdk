import 'dart:async';
import 'state.dart';

class ActiveQuery<T> {
  final String key;
  StreamController<AxiomState<T>>? _controller;
  AxiomState<T> _lastState = AxiomState.loading();
  StreamSubscription? _rustSubscription;

  // True once the upstream Rust stream has closed (Rust sent EventType::Complete).
  // When true, the next listen() must fire a fresh network request instead of
  // replaying _lastState. This flag is the mechanism that allows "press button
  // after error → set token → press button again → works".
  bool _streamClosed = false;

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
    if (_rustSubscription == null || _streamClosed) {
      // Either:
      // (a) First subscriber ever — start fresh.
      // (b) The previous Rust stream completed (success OR error) and a new
      //     subscriber just arrived. Always re-fetch so stale auth errors
      //     don't get replayed after the user sets a token.
      _connect();
    } else {
      // Upstream is still in-flight — replay the last known state so the
      // new subscriber sees immediate feedback (Loading / partial data).
      _controller?.add(_lastState);
    }
  }

  void _connect() {
    _streamClosed = false;
    _rustSubscription?.cancel();

    _rustSubscription = _createStream().listen(
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
}
