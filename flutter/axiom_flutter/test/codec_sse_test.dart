import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/src/internal/axiom_codec.dart';
import 'package:axiom_flutter/src/internal/sse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes raw SSE frames and plain JSON', () {
    Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));
    expect(AxiomCodec.decode(b('id: t1\ndata: {"id":"t1","seq":1}\n\n'), (j) => j), {'id': 't1', 'seq': 1});
    expect(AxiomCodec.decode(b('{"a":1}'), (j) => j), {'a': 1});
    expect(AxiomCodec.decode(b('"x"'), (j) => j), 'x');
    expect(AxiomCodec.sseData('event: tick\ndata: [1,\ndata: 2]'), '[1,\n2]');
    expect(AxiomCodec.sseData('hello world'), isNull);
  });
  test('parser splits events across chunks', () {
    final p = AxiomSseParser();
    Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));
    expect(p.feed(b('id: 1\ndata: {"a":')), isEmpty);
    final out = p.feed(b('1}\n\ndata: 2\n\n: hb\n\ndata: 3'));
    expect(out.map(utf8.decode), ['{"a":1}', '2']);
    expect(p.feed(Uint8List(0), flush: true).map(utf8.decode), ['3']);
  });
  test('F5: UTF-8 character split across chunks is not corrupted', () {
    final p = AxiomSseParser();
    final bytes = utf8.encode('data: héllo 😀\n\n');
    final out = <Uint8List>[];
    // Feed one byte at a time: every multi-byte character is split.
    for (final b in bytes) {
      out.addAll(p.feed(Uint8List.fromList([b])));
    }
    expect(out.map(utf8.decode), ['héllo 😀']);
  });
  test('F5: CRLF split across chunks keeps one multi-line event', () {
    final p = AxiomSseParser();
    Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));
    expect(p.feed(b('data: a\r')), isEmpty);
    expect(p.feed(b('\ndata: b\r\n\r')), isEmpty);
    expect(p.feed(b('\n')).map(utf8.decode), ['a\nb']);
    // A lone CR line ending still works, also at the end of a stream.
    final q = AxiomSseParser();
    expect(q.feed(b('data: x\r\r')), isEmpty);
    expect(q.feed(b('data: y\r')).map(utf8.decode), ['x']);
    expect(q.feed(Uint8List(0), flush: true).map(utf8.decode), ['y']);
  });
}
