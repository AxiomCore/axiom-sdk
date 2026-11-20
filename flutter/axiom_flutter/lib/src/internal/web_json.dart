// Web only: parse a JSON response body that arrived as the browser's own
// ArrayBuffer (C1.1). TextDecoder turns it into text without copying the
// bytes into a Dart Uint8List; `jsonDecode` then parses it (on dart2js that
// is `JSON.parse` plus lazy Dart maps, the same as package:http users get).
//
// Building models directly from JS objects (C1.2) is not done here.
import 'dart:convert';
import 'dart:js_interop';

@JS('TextDecoder')
extension type _TextDecoder._(JSObject _) implements JSObject {
  external _TextDecoder();
  external JSString decode(JSAny input);
}

abstract final class AxiomWebJson {
  static final _TextDecoder _utf8 = _TextDecoder();

  /// Parses [buffer] (ArrayBuffer or typed-array view) as JSON. Throws
  /// [FormatException] on invalid JSON, like `jsonDecode`.
  static Object? decode(JSAny buffer) => jsonDecode(_utf8.decode(buffer).toDart);
}
