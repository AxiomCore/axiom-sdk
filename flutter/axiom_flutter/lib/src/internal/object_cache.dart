import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'axiom_codec.dart';

/// In-memory cache of decoded models (C2.1), one entry per query key.
///
/// Correctness rule: an entry is returned only when the runtime delivered
/// byte-for-byte the body the model was decoded from. The runtime's byte
/// cache (TTL, invalidation, mutation invalidation, purge) therefore stays
/// the single source of truth; this cache only skips the decode. It is also
/// cleared on clearCache / purgeCache / invalidate / resetSession to free
/// memory. Bounded LRU by entry count and summed body bytes.
class AxiomObjectCache {
  AxiomObjectCache({this.maxEntries = 64, this.maxBytes = 8 * 1024 * 1024});

  int maxEntries;
  int maxBytes;

  final LinkedHashMap<String, _Entry> _entries = LinkedHashMap();
  int _bytes = 0;

  /// Hits and misses since start (diagnostics and tests).
  int hits = 0;
  int misses = 0;

  int get length => _entries.length;
  int get bytes => _bytes;

  /// The model decoded earlier from exactly [body] under [key], or null.
  T? lookup<T>(String key, Uint8List body) {
    final e = _entries[key];
    if (e == null || e.value is! T || !sameBytes(e.body, body)) {
      misses++;
      return null;
    }
    // Move to the most recently used end.
    _entries.remove(key);
    _entries[key] = e;
    hits++;
    return e.value as T;
  }

  void store(String key, Uint8List body, Object? value) {
    if (maxEntries <= 0 || body.length > maxBytes) return;
    final old = _entries.remove(key);
    if (old != null) _bytes -= old.body.length;
    _entries[key] = _Entry(body, value);
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
  _Entry(this.body, this.value);
  final Uint8List body;
  final Object? value;
}

/// Decodes [bytes] with [decoder], on a background isolate when the body
/// has at least [threshold] bytes (C1.3); inline otherwise. Falls back to
/// inline decoding when the decoder cannot be sent to another isolate.
Future<T> decodeOffIsolate<T>(
  Uint8List bytes,
  T Function(dynamic json) decoder,
) async {
  // The body crosses as TransferableTypedData: one memcpy into the transfer
  // buffer on this isolate, none on receipt.
  final transfer = TransferableTypedData.fromList([bytes]);
  try {
    return await Isolate.run(
      () => AxiomCodec.decode(transfer.materialize().asUint8List(), decoder),
      debugName: 'axiom-decode',
    );
  } on ArgumentError {
    // Unsendable decoder closure: decode here.
    return AxiomCodec.decode(bytes, decoder);
  }
}
