import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/src/internal/axiom_codec.dart';
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
}
