import 'dart:convert';
import 'dart:typed_data';

class AxiomCodec {
  static Uint8List encodeBody(dynamic body, Map<String, String>? headers) {
    if (body == null) return Uint8List(0);
    if (body is Uint8List) return body;
    if (body is String) return Uint8List.fromList(utf8.encode(body));

    // Check if request is URL-encoded form data (e.g. FastAPI OAuth2PasswordRequestForm)
    final isForm =
        headers?.entries.any(
          (e) =>
              e.key.toLowerCase() == 'content-type' &&
              e.value.contains('application/x-www-form-urlencoded'),
        ) ??
        false;

    if (isForm && body is Map) {
      final parts = <String>[];
      body.forEach((key, value) {
        if (value != null) {
          parts.add(
            '${Uri.encodeQueryComponent(key.toString())}=${Uri.encodeQueryComponent(value.toString())}',
          );
        }
      });
      return Uint8List.fromList(utf8.encode(parts.join('&')));
    }

    if (body is DateTime) {
      return Uint8List.fromList(utf8.encode('"${body.toIso8601String()}"'));
    }

    return Uint8List.fromList(utf8.encode(jsonEncode(body)));
  }

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
