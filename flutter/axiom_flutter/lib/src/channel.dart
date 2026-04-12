import 'dart:async';
import 'state.dart';
import 'runtime_interface.dart';
import 'internal/axiom_codec.dart';

/// Returned by SDK endpoints defined as `http_stream`, `sse`, or `file_stream`.
class AxiomStreamQuery<T> {
  final Stream<AxiomState<T>> stream;
  AxiomStreamQuery(this.stream);
}

/// Returned by SDK endpoints defined as `websocket`.
/// Provides a bidirectional communication channel.
class AxiomChannel<ReceiveType, SendType> {
  final int _requestId;
  final Stream<AxiomState<ReceiveType>> stream;
  final AxiomRuntime _runtime;

  AxiomChannel(this._requestId, this.stream, this._runtime);

  /// Sends a message up to the server via the active WebSocket.
  void send(SendType data) {
    final bytes = AxiomCodec.encodeBody(data);
    _runtime.sendStreamMessage(requestId: _requestId, payload: bytes);
  }
}
