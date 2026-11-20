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

    final dynamic jsonObject = jsonDecode(sseData(jsonString) ?? jsonString);
    return decoder(jsonObject);
  }

  /// When [text] is a raw server-sent event (`id:`/`event:`/`data:` lines),
  /// returns the joined `data:` payload; otherwise null.
  static String? sseData(String text) {
    final first = text.trimLeft();
    if (first.startsWith('{') || first.startsWith('[') || first.startsWith('"')) {
      return null;
    }
    final lines = const LineSplitter().convert(text);
    final data = <String>[];
    var sawField = false;
    for (final line in lines) {
      if (line.isEmpty) continue;
      final colon = line.indexOf(':');
      if (colon <= 0 && !line.startsWith(':')) return null;
      if (line.startsWith(':')) continue; // comment / heartbeat
      final field = line.substring(0, colon);
      if (!const {'id', 'event', 'data', 'retry'}.contains(field)) return null;
      sawField = true;
      var value = line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'data') data.add(value);
    }
    if (!sawField || data.isEmpty) return null;
    return data.join('\n');
  }
}
