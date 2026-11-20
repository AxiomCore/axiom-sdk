import 'dart:async';
import 'state.dart';
import 'runtime_interface.dart';
import 'internal/axiom_codec.dart';

/// Returned by SDK endpoints defined as `http_stream`, `sse`, or `file_stream`.
class AxiomStreamQuery<T> {
  final Stream<AxiomState<T>> stream;
  AxiomStreamQuery(this.stream);
}

/// Reconnect behaviour for a [AxiomChannel], mirroring the contract stream
/// option `reconnect: "auto"`.
class AxiomReconnectPolicy {
  /// Reconnect automatically after an unexpected close or network error.
  final bool enabled;

  /// Give up after this many consecutive failed attempts; null retries
  /// forever.
  final int? maxAttempts;

  /// Delay before the first attempt; doubled per attempt up to [maxDelay].
  final Duration initialDelay;
  final Duration maxDelay;

  const AxiomReconnectPolicy({
    this.enabled = false,
    this.maxAttempts,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
  });

  /// No reconnect (default; matches contract `reconnect: "none"`).
  static const AxiomReconnectPolicy none = AxiomReconnectPolicy();

  /// Exponential back-off reconnect (contract `reconnect: "auto"`).
  static const AxiomReconnectPolicy auto = AxiomReconnectPolicy(enabled: true);

  /// Delay before attempt number [attempt] (1-based).
  Duration delayFor(int attempt) {
    final ms = initialDelay.inMilliseconds * (1 << (attempt - 1).clamp(0, 20));
    return Duration(milliseconds: ms.clamp(0, maxDelay.inMilliseconds));
  }
}

/// Returned by SDK endpoints defined as `websocket`: a typed bidirectional
/// channel. Type parameters are `<ReceiveType, SendType>` (kept from 0.147
/// for source compatibility).
///
/// [stream] is stable across reconnects; [requestId] changes when the
/// channel reconnects.
class AxiomChannel<ReceiveType, SendType> {
  int _requestId;
  final Stream<AxiomState<ReceiveType>> stream;
  final AxiomRuntime _runtime;

  /// Reconnect policy applied by the runtime implementation.
  final AxiomReconnectPolicy reconnect;

  bool _closed = false;

  AxiomChannel(
    this._requestId,
    this.stream,
    this._runtime, {
    this.reconnect = AxiomReconnectPolicy.none,
  });

  /// Current runtime request id of the underlying connection.
  int get requestId => _requestId;

  /// Used by runtime implementations when a reconnect opens a new request.
  void updateRequestId(int value) => _requestId = value;

  bool get isClosed => _closed;

  /// Sends a message up to the server via the active WebSocket.
  void send(SendType data) {
    if (_closed) throw StateError('AxiomChannel is closed');
    // Pass null for headers since WebSockets don't use HTTP-style content-type per frame.
    final bytes = AxiomCodec.encodeBody(data, null);
    _runtime.sendStreamMessage(requestId: _requestId, payload: bytes);
  }

  /// Closes the connection (cancels the request) and stops reconnecting.
  /// Idempotent.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _runtime.cancel(_requestId);
  }
}
