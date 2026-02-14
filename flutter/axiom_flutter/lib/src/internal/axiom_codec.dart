import 'dart:convert';
import 'dart:typed_data';

class AxiomCodec {
  static Uint8List encodeBody(dynamic body) {
    if (body == null) return Uint8List(0);
    if (body is Uint8List) return body;
    if (body is String) return Uint8List.fromList(utf8.encode(body));

    if (body is DateTime) {
      return Uint8List.fromList(utf8.encode('"${body.toIso8601String()}"'));
    }

    return Uint8List.fromList(utf8.encode(jsonEncode(body)));
  }

  /// Decodes bytes into [T].
  /// Throws [FormatException] if JSON is invalid.
  /// Throws [TypeError] if decoder mapping fails.
  static T decode<T>(Uint8List bytes, T Function(dynamic json) decoder) {
    if (bytes.isEmpty) {
      return decoder(null);
    }

    final String jsonString = utf8.decode(bytes);
    if (jsonString.isEmpty || jsonString == 'null') {
      return decoder(null);
    }

    final dynamic jsonObject = jsonDecode(jsonString);
    return decoder(jsonObject);
  }
}
