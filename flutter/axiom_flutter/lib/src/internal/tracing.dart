import 'dart:math';

/// Generates W3C Trace Context strings.
/// Rust's opentelemetry parses this to link Frontend spans to Backend spans.
class AxiomTracing {
  static final _random = Random.secure();

  /// Returns standard W3C traceparent: 00-[trace_id]-[span_id]-01
  static String generateTraceparent() {
    final traceId = _generateHex(16); // 32 chars
    final spanId = _generateHex(8);   // 16 chars
    return '00-$traceId-$spanId-01';
  }

  static String _generateHex(int bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
