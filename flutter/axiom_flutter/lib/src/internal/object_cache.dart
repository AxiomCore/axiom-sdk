import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'dart:convert';

import 'axiom_codec.dart';
import 'sse.dart';

/// In-memory cache of decoded models (C2.1), one entry per query key.
///
/// OFF by default (`AxiomConfig.objectCacheMaxEntries` 0). A hit hands the
/// SAME instance to every later caller, so enable it only if the app treats
/// models as immutable (never sorts or edits a returned list or map in
/// place).
///
/// Correctness rule: an entry is returned only when the runtime delivered
/// byte-for-byte the body the model was decoded from. The runtime's byte
/// cache (TTL, invalidation, mutation invalidation, purge) therefore stays
/// the single source of truth; this cache only skips the decode. It is also
/// cleared on clearCache / purgeCache / invalidate / resetSession to free
/// memory. Bounded LRU by entry count and summed body bytes.
class AxiomObjectCache {
  AxiomObjectCache({this.maxEntries = 0, this.maxBytes = 8 * 1024 * 1024});

  int maxEntries;
  int maxBytes;

  final LinkedHashMap<String, _Entry> _entries = LinkedHashMap();
  int _bytes = 0;

  /// Hits and misses since start (diagnostics and tests).
  int hits = 0;
  int misses = 0;

  int get length => _entries.length;
  int get bytes => _bytes;

  /// The model decoded earlier by the same [decoder] from exactly [body]
  /// under [key], or null.
  T? lookup<T>(String key, Uint8List body, Object decoder) {
    if (maxEntries <= 0) return null;
    final e = _entries[key];
    if (e == null ||
        !identical(e.decoder, decoder) ||
        e.value is! T ||
        !sameBytes(e.body, body)) {
      misses++;
      return null;
    }
    // Move to the most recently used end.
    _entries.remove(key);
    _entries[key] = e;
    hits++;
    return e.value as T;
  }

  void store(String key, Uint8List body, Object decoder, Object? value) {
    if (maxEntries <= 0 || body.length > maxBytes) return;
    final old = _entries.remove(key);
    if (old != null) _bytes -= old.body.length;
    _entries[key] = _Entry(body, decoder, value);
    _bytes += body.length;
    while (_entries.length > maxEntries || _bytes > maxBytes) {
      final first = _entries.keys.first;
      _bytes -= _entries.remove(first)!.body.length;
    }
  }

  /// Drops entries whose key starts with [prefix] (all when null).
  void removeWhere([String? prefix]) {
    if (prefix == null) {
      _entries.clear();
      _bytes = 0;
      return;
    }
    _entries.removeWhere((k, e) {
      final hit = k.startsWith(prefix);
      if (hit) _bytes -= e.body.length;
      return hit;
    });
  }

  /// Byte equality, 8 bytes at a time where the buffers allow it.
  static bool sameBytes(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    final n = a.length;
    if (n != b.length) return false;
    var i = 0;
    if (a.offsetInBytes % 8 == 0 && b.offsetInBytes % 8 == 0 && n >= 64) {
      final words = n ~/ 8;
      final wa = a.buffer.asInt64List(a.offsetInBytes, words);
      final wb = b.buffer.asInt64List(b.offsetInBytes, words);
      for (var w = 0; w < words; w++) {
        if (wa[w] != wb[w]) return false;
      }
      i = words * 8;
    }
    for (; i < n; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _Entry {
  _Entry(this.body, this.decoder, this.value);
  final Uint8List body;
  final Object decoder;
  final Object? value;
}

final Converter<List<int>, Object?> _utf8Json = utf8.decoder.fuse(
  json.decoder,
);

/// Parses [bytes] (UTF-8 JSON) to a JSON tree on a background isolate, then
/// runs [decoder] (the generated `fromJson`) HERE, on the calling isolate
/// (C1.3). Only the parse moves: decoders may rely on isolate-local state
/// (the generated models keep unknown enum wire values in an `Expando`) and
/// are never copied. The tree comes back through `Isolate.exit` without a
/// copy. SSE bodies and parse fallbacks decode inline.
Future<T> decodeOffIsolate<T>(
  Uint8List bytes,
  T Function(dynamic json) decoder,
) async {
  if (bytes.length <= 3 || AxiomSseParser.looksLike(bytes)) {
    return AxiomCodec.decode(bytes, decoder);
  }
  // One memcpy into the transfer buffer here, none on receipt.
  final transfer = TransferableTypedData.fromList([bytes]);
  final tree = await Isolate.run(
    () => _utf8Json.convert(transfer.materialize().asUint8List()),
    debugName: 'axiom-json-parse',
  );
  return decoder(tree);
}
