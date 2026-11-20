import 'dart:async';
import 'dart:typed_data';
import 'state.dart';
import 'runtime_interface.dart';

/// Creates the underlying runtime stream for a query. [forceRefresh] asks
/// the runtime to bypass its cache (`x-axiom-cache-mode: refresh`).
typedef AxiomQueryStreamFactory<T> =
    AxiomActiveStream<T> Function(bool forceRefresh);

/// One shared, cached query. Its [stream] is broadcast: every listener sees
/// the same fetch. When the last listener goes away while a request is in
/// flight, the request is cancelled (see API.md "Cancellation rule") and the
/// last value stays cached for the next listener.
class ActiveQuery<T> {
  final String key;

  /// Namespace / endpoint the query belongs to (null for legacy callers).
  final String? namespace;
  final int? endpointId;

  StreamController<AxiomState<T>>? _controller;
  AxiomState<T> _lastState = AxiomState.loading();
  StreamSubscription? _rustSubscription;
  bool _streamClosed = false;
  bool _forceNext = false;

  /// Runtime request id of the current (or last) fetch.
  int? currentReqId;

  final AxiomActiveStream<T> Function()? _createStream;
  final AxiomQueryStreamFactory<T>? _createForced;
  final bool Function(int requestId)? _cancel;

  ActiveQuery(
    this.key,
    AxiomActiveStream<T> Function()? createStream, {
    AxiomQueryStreamFactory<T>? create,
    bool Function(int requestId)? cancel,
    this.namespace,
    this.endpointId,
  }) : _createStream = createStream,
       _createForced = create,
       _cancel = cancel {
    _controller = StreamController<AxiomState<T>>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  Stream<AxiomState<T>> get stream => _controller!.stream;
  AxiomState<T> get state => _lastState;

  /// True while at least one listener is subscribed.
  bool get hasListener => _controller?.hasListener ?? false;

  /// True while a runtime request for this query is in flight.
  bool get isInFlight => _rustSubscription != null && !_streamClosed;

  void _onListen() {
    if (_rustSubscription == null || _streamClosed) {
      if (_lastState.hasData) {
        // Show the cached value immediately while the fetch runs.
        _controller?.add(
          AxiomState<T>.success(
            _lastState.data as T,
            _lastState.source,
            isFetching: true,
          ),
        );
      }
      _connect();
    } else {
      _controller?.add(_lastState);
    }
  }

  void _connect() {
    _streamClosed = false;
    _rustSubscription?.cancel();

    final force = _forceNext || AxiomQueryManager()._takePurgeForce(this);
    _forceNext = false;
    final AxiomActiveStream<T> active;
    if (_createForced != null) {
      active = _createForced(force);
    } else {
      active = _createStream!();
    }
    currentReqId = active.requestId;

    _rustSubscription = active.stream.listen(
      (newState) {
        if (newState.hasError && newState.error!.isCancelled) {
          // Keep the cached value; forward the cancellation to listeners that
          // are still attached (explicit AxiomQuery.cancel()).
          if (!(_controller?.isClosed ?? true)) {
            _controller?.add(
              AxiomState<T>.error(
                newState.error!,
                previousData: _lastState.data,
                previousSource: _lastState.source,
              ),
            );
          }
          _streamClosed = true;
          return;
        }
        if (newState.hasError && _lastState.hasData && newState.data == null) {
          newState = AxiomState<T>.error(
            newState.error!,
            previousData: _lastState.data,
            previousSource: _lastState.source,
          );
        }
        _lastState = newState;
        if (!(_controller?.isClosed ?? true)) {
          _controller?.add(newState);
        }
      },
      onDone: () {
        // EventType::Complete closes the runtime stream; the next subscriber
        // triggers a fresh fetch.
        _streamClosed = true;
      },
      onError: (_) {
        _streamClosed = true;
      },
    );
  }

  void _onCancel() {
    // Called only when the LAST listener of the broadcast stream leaves.
    if (isInFlight) {
      final id = currentReqId;
      // A unary response already delivered is terminal: no need to cancel.
      final waiting =
          _lastState.isLoading ||
          _lastState.isFetching ||
          _lastState.isStreaming;
      if (waiting && id != null && id != 0) _cancel?.call(id);
      _rustSubscription?.cancel();
      _rustSubscription = null;
      _streamClosed = true;
      if (_lastState.isLoading && !_lastState.hasData) {
        _lastState = AxiomState.loading();
      } else if (_lastState.isFetching && _lastState.hasData) {
        _lastState = AxiomState<T>.success(
          _lastState.data as T,
          _lastState.source,
        );
      }
    }
  }

  /// Refetches now if someone listens; otherwise the next listener fetches.
  void refetch({bool force = false}) {
    if (force) _forceNext = true;
    if (!hasListener) {
      // Nobody is watching: drop any in-flight request, fetch on next listen.
      if (isInFlight) {
        final id = currentReqId;
        if (id != null && id != 0) _cancel?.call(id);
      }
      _rustSubscription?.cancel();
      _rustSubscription = null;
      _streamClosed = true;
      return;
    }
    final previous = _rustSubscription;
    final previousId = currentReqId;
    final wasInFlight = isInFlight;
    _rustSubscription = null;
    previous?.cancel();
    if (wasInFlight && previousId != null && previousId != 0) {
      _cancel?.call(previousId);
    }
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

  /// Writes [data] as the current value and pushes it to listeners.
  void setData(Object? data) {
    _lastState = AxiomState<T>.success(data as T, AxiomSource.cache);
    if (!(_controller?.isClosed ?? true)) _controller?.add(_lastState);
  }

  /// Forgets the cached value (listeners keep what they showed).
  void clearData() {
    if (_lastState.hasData) _lastState = AxiomState.loading();
  }

  T? get data => _lastState.data;

  void dispose() {
    if (isInFlight) {
      final id = currentReqId;
      if (id != null && id != 0) _cancel?.call(id);
    }
    _rustSubscription?.cancel();
    _rustSubscription = null;
    _controller?.close();
  }
}

class AxiomQueryManager {
  static final AxiomQueryManager _instance = AxiomQueryManager._();
  factory AxiomQueryManager() => _instance;
  AxiomQueryManager._();

  final Map<String, ActiveQuery> _activeQueries = {};

  /// Values written by `setQueryData` before any query for the key exists.
  final Map<String, Object?> _seeded = {};

  /// Namespaces ('*' = all) whose runtime cache was purged from Dart; keys
  /// of these namespaces fetch with `x-axiom-cache-mode: refresh` once.
  final Set<String> _purgedNamespaces = {};
  final Set<String> _refreshedSincePurge = {};

  Stream<AxiomState<T>> watch<T>(
    String key,
    AxiomActiveStream<T> Function() createFn,
  ) {
    return watchRaw<T>(key, createFn).stream;
  }

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

  /// Refetches the query [key] (with [force], bypassing the runtime cache).
  void invalidate(String key, {bool force = false}) {
    _activeQueries[key]?.refetch(force: force);
  }

  /// Removes a key so the next watch() creates a completely fresh ActiveQuery.
  void remove(String key) {
    _activeQueries.remove(key)?.dispose();
    _seeded.remove(key);
  }

  /// Disposes every query and forgets every cached value.
  void clear() {
    for (var q in _activeQueries.values.toList()) {
      q.dispose();
    }
    _activeQueries.clear();
    _seeded.clear();
    _purgedNamespaces.clear();
    _refreshedSincePurge.clear();
  }

  /// Runtime request id of the current fetch of [key], if any.
  int? requestIdFor(String key) => _activeQueries[key]?.currentReqId;

  /// The active query for [key], if any.
  ActiveQuery? queryFor(String key) => _activeQueries[key];

  /// Queries currently known, optionally filtered.
  Iterable<ActiveQuery> queries({String? namespace, int? endpointId}) =>
      _activeQueries.values.where(
        (q) =>
            (namespace == null || q.namespace == namespace) &&
            (endpointId == null || q.endpointId == endpointId),
      );

  /// Similar to watch, but returns the full AxiomActiveStream wrapper.
  ///
  /// [create] (preferred over [createFn]) receives `forceRefresh`. [cancel]
  /// is called with the request id when the last listener leaves while the
  /// request is in flight.
  AxiomActiveStream<T> watchRaw<T>(
    String key,
    AxiomActiveStream<T> Function()? createFn, {
    AxiomQueryStreamFactory<T>? create,
    bool Function(int requestId)? cancel,
    String? namespace,
    int? endpointId,
  }) {
    final existing = _activeQueries[key];
    if (existing is ActiveQuery<T>) {
      return AxiomActiveStream<T>(existing.currentReqId ?? 0, existing.stream);
    }
    if (existing != null) {
      // Same key requested with a different type: replace it.
      _activeQueries.remove(key)?.dispose();
    }

    final query = ActiveQuery<T>(
      key,
      createFn,
      create: create,
      cancel: cancel,
      namespace: namespace,
      endpointId: endpointId,
    );
    if (_seeded.containsKey(key)) {
      final seed = _seeded.remove(key);
      if (seed is T) query.setData(seed);
    }
    _activeQueries[key] = query;
    return AxiomActiveStream<T>(query.currentReqId ?? 0, query.stream);
  }

  // ---------------------------------------------------------------------------
  // Cache control (shared by native and web runtimes)
  // ---------------------------------------------------------------------------

  /// Optimistic write of [data] for [key].
  void setData(String key, Object? data) {
    final q = _activeQueries[key];
    if (q != null) {
      q.setData(data);
    } else {
      _seeded[key] = data;
    }
  }

  /// Last value held for [key], or null.
  Object? dataFor(String key) {
    final q = _activeQueries[key];
    if (q != null) return q.data;
    return _seeded[key];
  }

  /// Force-refetches the matching queries. With [endpointIds] null every
  /// query in [namespace] matches.
  void invalidateWhere({
    required String namespace,
    Set<int>? endpointIds,
    String? key,
  }) {
    for (final q in _activeQueries.values.toList()) {
      if (key != null) {
        if (q.key != key) continue;
      } else {
        if (q.namespace != namespace) continue;
        if (endpointIds != null && !endpointIds.contains(q.endpointId)) {
          continue;
        }
      }
      q.refetch(force: true);
    }
  }

  /// Clears cached values for [namespace] (all when null). With [refetch]
  /// active queries refetch bypassing the runtime cache; inactive ones are
  /// forgotten. Later first fetches of the namespace bypass the runtime cache.
  void clearNamespace(String? namespace, {required bool refetch}) {
    final ns = namespace ?? '*';
    _purgedNamespaces.add(ns);
    _refreshedSincePurge.removeWhere(
      (k) => namespace == null || k.startsWith('$namespace\u0000'),
    );
    _seeded.removeWhere((k, _) => namespace == null || _keyInNs(k, namespace));
    for (final entry in _activeQueries.entries.toList()) {
      final q = entry.value;
      final matches =
          namespace == null ||
          q.namespace == namespace ||
          (q.namespace == null && _keyInNs(q.key, namespace));
      if (!matches) continue;
      if (refetch && q.hasListener) {
        q.refetch(force: true);
      } else if (q.hasListener) {
        // purge: keep the last value on screen until the next fetch
      } else {
        _activeQueries.remove(entry.key)?.dispose();
      }
    }
  }

  static bool _keyInNs(String key, String namespace) =>
      key.startsWith('${namespace}_');

  bool _takePurgeForce(ActiveQuery q) {
    if (_purgedNamespaces.isEmpty) return false;
    final ns = q.namespace;
    final inPurged =
        _purgedNamespaces.contains('*') ||
        (ns != null && _purgedNamespaces.contains(ns)) ||
        (ns == null && _purgedNamespaces.any((p) => _keyInNs(q.key, p)));
    if (!inPurged) return false;
    final marker = '${ns ?? ''}\u0000${q.key}';
    if (_refreshedSincePurge.contains(marker)) return false;
    _refreshedSincePurge.add(marker);
    return true;
  }
}
