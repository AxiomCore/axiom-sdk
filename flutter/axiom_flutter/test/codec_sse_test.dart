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
}
