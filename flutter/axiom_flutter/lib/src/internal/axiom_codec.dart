import 'dart:convert';
import 'dart:typed_data';

import 'sse.dart';

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

  static const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');
  static final Converter<List<int>, Object?> _utf8Json = utf8.decoder.fuse(
    json.decoder,
  );

  static T decode<T>(Uint8List bytes, T Function(dynamic json) decoder) {
    if (bytes.isEmpty) {
      return decoder(null);
    }

    // SSE is sniffed on the bytes we already have (first 64 bytes). Encoding
    // the decoded string back to UTF-8 just to sniff it cost a full extra
    // encode + copy per response (10k items: ~5 ms native, ~5 ms dart2js).
    final isSse = AxiomSseParser.looksLike(bytes);

    // Dart VM: decode JSON straight from the UTF-8 bytes (no intermediate
    // String; ~3 ms less for 938 KB). dart2js is not faster that way, so the
    // web keeps utf8.decode + jsonDecode (JSON.parse). Tiny bodies (a BOM
    // only) keep the String path so an empty text still decodes as null.
    if (!_isWeb && !isSse && bytes.length > 3) {
      return decoder(_utf8Json.convert(bytes));
    }

    final String jsonString = utf8.decode(bytes);
    if (jsonString.isEmpty || jsonString == 'null') {
      return decoder(null);
    }

    final dynamic jsonObject = jsonDecode(
      (isSse ? sseData(jsonString) : null) ?? jsonString,
    );
    return decoder(jsonObject);
  }

  /// When [text] is a raw server-sent event (`id:`/`event:`/`data:` lines),
  /// returns the `data:` payload of its first event; otherwise null.
  /// Uses the shared [AxiomSseParser].
  static String? sseData(String text) {
    final bytes = Uint8List.fromList(utf8.encode(text));
    if (!AxiomSseParser.looksLike(bytes)) return null;
    final events = AxiomSseParser().feed(bytes, flush: true);
    return events.isEmpty ? null : utf8.decode(events.first);
  }
}
