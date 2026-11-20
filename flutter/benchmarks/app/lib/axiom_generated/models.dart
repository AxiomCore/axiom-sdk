// GENERATED CODE - DO NOT EDIT.
// axiom_flutter_generator 0.150.0
// bench: dev.axiomcore.bench 1.0.0 variant default schema 82a84e0daf09

import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';

/// JSON helpers used by the generated models and client.
abstract final class AxiomGeneratedCodec {
  static String asString(Object? v) => v as String;
  static bool asBool(Object? v) => v as bool;
  static Object? asJson(Object? v) => v;
  static void asVoid(Object? v) {}

  /// Integers (Int32 and Int64). Native and dart2wasm hold every Int64
  /// exactly, from a JSON number or a JSON string. dart2js holds integers
  /// exactly only up to 2^53-1: a larger JSON number was already rounded by
  /// the browser's JSON parser, and a larger JSON string cannot be held
  /// exactly. Such a value is never returned silently: it is counted in
  /// [unsafeIntegerCount], passed to [onUnsafeInteger], and with
  /// [strictIntegers] it throws a [FormatException] instead.
  static int asInt(Object? v) => switch (v) {
    int() => _jsNumbers && v.abs() > _maxSafe ? _unsafe(v, v) : v,
    num() => v.toInt(),
    String() => _parseInt(v),
    _ => throw FormatException('expected an integer, got $v'),
  };

  /// True on dart2js, where int and double share JavaScript numbers.
  static final bool _jsNumbers = identical(0, 0.0);
  static const int _maxSafe = 9007199254740991; // 2^53 - 1

  /// dart2js only: called with the wire value and the decoded (possibly
  /// rounded) int whenever an integer outside +/-(2^53-1) is decoded.
  static void Function(Object? wire, int decoded)? onUnsafeInteger;

  /// dart2js only: number of integers decoded outside +/-(2^53-1).
  static int unsafeIntegerCount = 0;

  /// dart2js only: throw instead of returning a possibly rounded integer.
  static bool strictIntegers = false;

  static int _parseInt(String s) {
    final v = int.parse(s);
    if (_jsNumbers && v.abs() > _maxSafe) {
      final t = s.trim();
      final canonical = t.startsWith('+') ? t.substring(1) : t;
      // Exactly representable (e.g. 2^60) only when it prints back the same.
      if (BigInt.from(v) != BigInt.parse(canonical)) return _unsafe(s, v);
    }
    return v;
  }

  static int _unsafe(Object? wire, int decoded) {
    unsafeIntegerCount++;
    if (strictIntegers) {
      throw FormatException(
        'integer $wire is outside +/-(2^53-1) and may be rounded on dart2js; '
        'send it as a JSON string or compile with dart2wasm',
      );
    }
    onUnsafeInteger?.call(wire, decoded);
    return decoded;
  }

  static double asDouble(Object? v) => switch (v) {
    num() => v.toDouble(),
    String() => double.parse(v),
    _ => throw FormatException('expected a number, got $v'),
  };

  static DateTime asDateTime(Object? v) => switch (v) {
    String() => DateTime.parse(v),
    int() => DateTime.fromMillisecondsSinceEpoch(v, isUtc: true),
    _ => throw FormatException('expected a date-time, got $v'),
  };

  /// Bytes travel as base64 strings; a list of ints is accepted too.
  static Uint8List asBytes(Object? v) => switch (v) {
    String() => base64Decode(v),
    List() => Uint8List.fromList(v.cast<int>()),
    _ => throw FormatException('expected bytes, got $v'),
  };

  static String bytesToJson(Uint8List v) => base64Encode(v);

  /// jsonDecode already returns `Map<String, dynamic>`: use it directly (a
  /// `cast` view re-checks every key and value on each read).
  static Map<String, dynamic> asObject(Object? v) =>
      v is Map<String, dynamic> ? v : (v as Map).cast<String, dynamic>();

  /// Built with its final length known (no regrowth while decoding).
  static List<T> asList<T>(Object? v, T Function(Object?) item) {
    final l = v as List;
    return List<T>.generate(l.length, (i) => item(l[i]));
  }

  static Map<String, T> asMap<T>(Object? v, T Function(Object?) value) => {
    for (final e in (v as Map).entries) e.key as String: value(e.value),
  };

  static Map<K, T> asKeyedMap<K, T>(
    Object? v,
    K Function(String) key,
    T Function(Object?) value,
  ) => {
    for (final e in (v as Map).entries) key(e.key as String): value(e.value),
  };

  static bool deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final e in a.entries) {
        if (!b.containsKey(e.key) || !deepEquals(e.value, b[e.key])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }

  /// True when [v] is, or contains, an enum value this client does not know.
  static bool hasUnknown(Object? v) => switch (v) {
    AxiomGeneratedEnum() => v.isUnknown,
    List() => v.any(hasUnknown),
    Map() => v.keys.any(hasUnknown) || v.values.any(hasUnknown),
    _ => false,
  };

  static int deepHash(Object? v) => switch (v) {
    List() => Object.hashAll(v.map(deepHash)),
    Map() => Object.hashAllUnordered(
      v.entries.map((e) => Object.hash(deepHash(e.key), deepHash(e.value))),
    ),
    _ => v.hashCode,
  };

  /// Code and payload of a contract failure carried by [error]: the
  /// runtime's `failureCode`/`failurePayload`, else the server body in
  /// `details` (`{"error": {"code": ..., "payload": ...}}`).
  static (String?, Object?) failureParts(AxiomError error) {
    if (error.failureCode != null) {
      return (error.failureCode, error.failurePayload);
    }
    final details = error.details;
    if (details == null || details.isEmpty) return (null, null);
    try {
      final decoded = jsonDecode(details);
      if (decoded is Map) {
        final body = decoded['error'] is Map
            ? decoded['error'] as Map
            : decoded;
        final code = body['code'] ?? body['failure_code'];
        if (code is String) {
          return (code, body['payload'] ?? body['failure_payload']);
        }
      }
    } on FormatException {
      return (null, null);
    }
    return (null, null);
  }
}

/// Implemented by every generated enum.
abstract interface class AxiomGeneratedEnum {
  /// True for a wire value this client version does not know.
  bool get isUnknown;
}

class Item {
  const Item({
    required this.active,
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    required this.tags,
  });

  factory Item.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Item(
      active: (map['active'] as bool),
      id: (map['id'] as String),
      name: (map['name'] as String),
      price: AxiomGeneratedCodec.asDouble(map['price']),
      qty: AxiomGeneratedCodec.asInt(map['qty']),
      tags: AxiomGeneratedCodec.asList(
        map['tags'],
        AxiomGeneratedCodec.asString,
      ),
    );
  }

  final bool active;
  final String id;
  final String name;
  final double price;
  final int qty;
  final List<String> tags;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'active': active,
    'id': id,
    'name': name,
    'price': price,
    'qty': qty,
    'tags': tags,
  };

  Item copyWith({
    bool? active,
    String? id,
    String? name,
    double? price,
    int? qty,
    List<String>? tags,
  }) => Item(
    active: active ?? this.active,
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
    qty: qty ?? this.qty,
    tags: tags ?? this.tags,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          other.active == active &&
          other.id == id &&
          other.name == name &&
          other.price == price &&
          other.qty == qty &&
          AxiomGeneratedCodec.deepEquals(other.tags, tags);

  @override
  int get hashCode => Object.hashAll([
    active,
    id,
    name,
    price,
    qty,
    AxiomGeneratedCodec.deepHash(tags),
  ]);

  @override
  String toString() =>
      'Item(active: $active, id: $id, name: $name, price: $price, qty: $qty, tags: $tags)';
}

class ItemInput {
  const ItemInput({required this.name, required this.price, required this.qty});

  factory ItemInput.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return ItemInput(
      name: (map['name'] as String),
      price: AxiomGeneratedCodec.asDouble(map['price']),
      qty: AxiomGeneratedCodec.asInt(map['qty']),
    );
  }

  final String name;
  final double price;
  final int qty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'price': price,
    'qty': qty,
  };

  ItemInput copyWith({String? name, double? price, int? qty}) => ItemInput(
    name: name ?? this.name,
    price: price ?? this.price,
    qty: qty ?? this.qty,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemInput &&
          other.name == name &&
          other.price == price &&
          other.qty == qty;

  @override
  int get hashCode => Object.hashAll([name, price, qty]);

  @override
  String toString() => 'ItemInput(name: $name, price: $price, qty: $qty)';
}

class ItemList {
  const ItemList({required this.items, required this.total});

  factory ItemList.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return ItemList(
      items: AxiomGeneratedCodec.asList(map['items'], Item.fromJson),
      total: AxiomGeneratedCodec.asInt(map['total']),
    );
  }

  final List<Item> items;
  final int total;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'items': [for (final e in items) e.toJson()],
    'total': total,
  };

  ItemList copyWith({List<Item>? items, int? total}) =>
      ItemList(items: items ?? this.items, total: total ?? this.total);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemList &&
          AxiomGeneratedCodec.deepEquals(other.items, items) &&
          other.total == total;

  @override
  int get hashCode =>
      Object.hashAll([AxiomGeneratedCodec.deepHash(items), total]);

  @override
  String toString() => 'ItemList(items: $items, total: $total)';
}

class ItemRef {
  const ItemRef({required this.id});

  factory ItemRef.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return ItemRef(id: (map['id'] as String));
  }

  final String id;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id};

  ItemRef copyWith({String? id}) => ItemRef(id: id ?? this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ItemRef && other.id == id;

  @override
  int get hashCode => Object.hashAll([id]);

  @override
  String toString() => 'ItemRef(id: $id)';
}

class ListIn {
  const ListIn({required this.n});

  factory ListIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return ListIn(n: AxiomGeneratedCodec.asInt(map['n']));
  }

  final int n;

  Map<String, dynamic> toJson() => <String, dynamic>{'n': n};

  ListIn copyWith({int? n}) => ListIn(n: n ?? this.n);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ListIn && other.n == n;

  @override
  int get hashCode => Object.hashAll([n]);

  @override
  String toString() => 'ListIn(n: $n)';
}

class Ping {
  const Ping({required this.seq, required this.text});

  factory Ping.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Ping(
      seq: AxiomGeneratedCodec.asInt(map['seq']),
      text: (map['text'] as String),
    );
  }

  final int seq;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{'seq': seq, 'text': text};

  Ping copyWith({int? seq, String? text}) =>
      Ping(seq: seq ?? this.seq, text: text ?? this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ping && other.seq == seq && other.text == text;

  @override
  int get hashCode => Object.hashAll([seq, text]);

  @override
  String toString() => 'Ping(seq: $seq, text: $text)';
}

class SocketIn {
  const SocketIn({required this.message});

  factory SocketIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return SocketIn(message: Ping.fromJson(map['message']));
  }

  final Ping message;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'message': message.toJson(),
  };

  SocketIn copyWith({Ping? message}) =>
      SocketIn(message: message ?? this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SocketIn && other.message == message;

  @override
  int get hashCode => Object.hashAll([message]);

  @override
  String toString() => 'SocketIn(message: $message)';
}
