import 'dart:convert';
import 'dart:typed_data';

/// Shared text/event-stream parser (native and web). The runtime forwards raw
/// SSE bytes; this extracts the `data:` payload of each complete event
/// (multi-line data joined with `\n`; comments and id/event/retry dropped).
/// One instance per request: it buffers partial events across chunks.
class AxiomSseParser {
  static final _start = RegExp(r'^\s*(data|id|event|retry)?:');

  String _buffer = '';

  /// Incremental UTF-8 decoder: a multi-byte character split across chunks
  /// is decoded once its last byte arrives (never as U+FFFD halves).
  final StringBuffer _decoded = StringBuffer();
  late ByteConversionSink _utf8 = _newDecoder();
  ByteConversionSink _newDecoder() => const Utf8Decoder(
    allowMalformed: true,
  ).startChunkedConversion(StringConversionSink.fromStringSink(_decoded));

  /// A chunk ended in `\r`: it may be the first half of a `\r\n`.
  bool _pendingCr = false;

  /// Whether [bytes] (the first chunk of a response) looks like SSE.
  static bool looksLike(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final head = utf8.decode(
      bytes.length > 64 ? bytes.sublist(0, 64) : bytes,
      allowMalformed: true,
    );
    return _start.hasMatch(head);
  }

  /// Appends [chunk] and returns the payloads of the events now complete.
  /// With [flush] a trailing event without its blank line is returned too.
  List<Uint8List> feed(Uint8List chunk, {bool flush = false}) {
    _utf8.add(chunk);
    if (flush) {
      _utf8.close();
      _utf8 = _newDecoder();
    }
    var text = _decoded.toString();
    _decoded.clear();
    if (_pendingCr) {
      text = '\r$text';
      _pendingCr = false;
    }
    if (!flush && text.endsWith('\r')) {
      // Wait for the next chunk to know whether `\n` follows.
      text = text.substring(0, text.length - 1);
      _pendingCr = true;
    }
    _buffer += text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final out = <Uint8List>[];
    while (true) {
      final i = _buffer.indexOf('\n\n');
      if (i < 0) break;
      final block = _buffer.substring(0, i);
      _buffer = _buffer.substring(i + 2);
      final d = dataOf(block);
      if (d != null) out.add(Uint8List.fromList(utf8.encode(d)));
    }
    if (flush && _buffer.trim().isNotEmpty) {
      final d = dataOf(_buffer);
      _buffer = '';
      if (d != null) out.add(Uint8List.fromList(utf8.encode(d)));
    }
    return out;
  }

  /// The joined `data:` lines of one event block, or null when it has none.
  static String? dataOf(String block) {
    final lines = <String>[];
    for (final line in block.split('\n')) {
      if (line.startsWith('data:')) {
        var v = line.substring(5);
        if (v.startsWith(' ')) v = v.substring(1);
        lines.add(v);
      }
    }
    return lines.isEmpty ? null : lines.join('\n');
  }
}
