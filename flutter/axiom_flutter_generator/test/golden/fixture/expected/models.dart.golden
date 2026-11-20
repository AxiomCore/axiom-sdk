// GENERATED CODE - DO NOT EDIT.
// axiom_flutter_generator 0.147.5
// fixture: dev.axiomcore.fixture 1.0.0 variant default schema aa69c58ec8f5

import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';

const Object _unset = Object();

/// JSON helpers used by the generated models and client.
abstract final class AxiomGeneratedCodec {
  static String asString(Object? v) => v as String;
  static bool asBool(Object? v) => v as bool;
  static Object? asJson(Object? v) => v;
  static void asVoid(Object? v) {}

  static int asInt(Object? v) => switch (v) {
    int() => v,
    num() => v.toInt(),
    String() => int.parse(v),
    _ => throw FormatException('expected an integer, got $v'),
  };

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

  static Map<String, dynamic> asObject(Object? v) =>
      (v as Map).cast<String, dynamic>();

  static List<T> asList<T>(Object? v, T Function(Object?) item) => [
    for (final e in v as List) item(e),
  ];

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

enum EverythingColor {
  red('red'),
  green('green'),
  blue('blue'),

  /// A value this client version does not know.
  unknown(null);

  const EverythingColor(this.value);

  /// Wire value; null for [unknown].
  final String? value;

  static EverythingColor fromJson(Object? json) {
    for (final v in values) {
      if (v.value == json) return v;
    }
    return unknown;
  }

  String toJson() => value ?? 'unknown';
}

class BytesIn {
  const BytesIn({required this.data});

  factory BytesIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return BytesIn(data: AxiomGeneratedCodec.asBytes(map['data']));
  }

  final Uint8List data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'data': AxiomGeneratedCodec.bytesToJson(data),
  };

  BytesIn copyWith({Uint8List? data}) => BytesIn(data: data ?? this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BytesIn && AxiomGeneratedCodec.deepEquals(other.data, data);

  @override
  int get hashCode => Object.hashAll([AxiomGeneratedCodec.deepHash(data)]);

  @override
  String toString() => 'BytesIn(data: $data)';
}

class BytesOut {
  const BytesOut({required this.data, required this.size});

  factory BytesOut.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return BytesOut(
      data: AxiomGeneratedCodec.asBytes(map['data']),
      size: AxiomGeneratedCodec.asInt(map['size']),
    );
  }

  final Uint8List data;
  final int size;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'data': AxiomGeneratedCodec.bytesToJson(data),
    'size': size,
  };

  BytesOut copyWith({Uint8List? data, int? size}) =>
      BytesOut(data: data ?? this.data, size: size ?? this.size);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BytesOut &&
          AxiomGeneratedCodec.deepEquals(other.data, data) &&
          other.size == size;

  @override
  int get hashCode =>
      Object.hashAll([AxiomGeneratedCodec.deepHash(data), size]);

  @override
  String toString() => 'BytesOut(data: $data, size: $size)';
}

class ClaimIn {
  const ClaimIn({required this.name});

  factory ClaimIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return ClaimIn(name: AxiomGeneratedCodec.asString(map['name']));
  }

  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'name': name};

  ClaimIn copyWith({String? name}) => ClaimIn(name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ClaimIn && other.name == name;

  @override
  int get hashCode => Object.hashAll([name]);

  @override
  String toString() => 'ClaimIn(name: $name)';
}

class Conflict {
  const Conflict({required this.existingId, required this.message});

  factory Conflict.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Conflict(
      existingId: AxiomGeneratedCodec.asString(map['existingId']),
      message: AxiomGeneratedCodec.asString(map['message']),
    );
  }

  final String existingId;
  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'existingId': existingId,
    'message': message,
  };

  Conflict copyWith({String? existingId, String? message}) => Conflict(
    existingId: existingId ?? this.existingId,
    message: message ?? this.message,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conflict &&
          other.existingId == existingId &&
          other.message == message;

  @override
  int get hashCode => Object.hashAll([existingId, message]);

  @override
  String toString() => 'Conflict(existingId: $existingId, message: $message)';
}

class Cursor {
  const Cursor({this.last});

  factory Cursor.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Cursor(
      last: map['last'] == null
          ? null
          : AxiomGeneratedCodec.asString(map['last']),
    );
  }

  final String? last;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (last case final v?) 'last': v,
  };

  Cursor copyWith({Object? last = _unset}) =>
      Cursor(last: identical(last, _unset) ? this.last : last as String?);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Cursor && other.last == last;

  @override
  int get hashCode => Object.hashAll([last]);

  @override
  String toString() => 'Cursor(last: $last)';
}

class Deleted {
  const Deleted({required this.deleted, required this.id});

  factory Deleted.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Deleted(
      deleted: AxiomGeneratedCodec.asBool(map['deleted']),
      id: AxiomGeneratedCodec.asString(map['id']),
    );
  }

  final bool deleted;
  final String id;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'deleted': deleted,
    'id': id,
  };

  Deleted copyWith({bool? deleted, String? id}) =>
      Deleted(deleted: deleted ?? this.deleted, id: id ?? this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Deleted && other.deleted == deleted && other.id == id;

  @override
  int get hashCode => Object.hashAll([deleted, id]);

  @override
  String toString() => 'Deleted(deleted: $deleted, id: $id)';
}

class Echo {
  const Echo({
    this.flag,
    required this.limit,
    required this.path,
    required this.q,
  });

  factory Echo.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Echo(
      flag: map['flag'] == null
          ? null
          : AxiomGeneratedCodec.asBool(map['flag']),
      limit: AxiomGeneratedCodec.asInt(map['limit']),
      path: AxiomGeneratedCodec.asString(map['path']),
      q: AxiomGeneratedCodec.asString(map['q']),
    );
  }

  final bool? flag;
  final int limit;
  final String path;
  final String q;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (flag case final v?) 'flag': v,
    'limit': limit,
    'path': path,
    'q': q,
  };

  Echo copyWith({Object? flag = _unset, int? limit, String? path, String? q}) =>
      Echo(
        flag: identical(flag, _unset) ? this.flag : flag as bool?,
        limit: limit ?? this.limit,
        path: path ?? this.path,
        q: q ?? this.q,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Echo &&
          other.flag == flag &&
          other.limit == limit &&
          other.path == path &&
          other.q == q;

  @override
  int get hashCode => Object.hashAll([flag, limit, path, q]);

  @override
  String toString() => 'Echo(flag: $flag, limit: $limit, path: $path, q: $q)';
}

class EchoIn {
  const EchoIn({
    this.flag,
    required this.limit,
    required this.path,
    required this.q,
  });

  factory EchoIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return EchoIn(
      flag: map['flag'] == null
          ? null
          : AxiomGeneratedCodec.asBool(map['flag']),
      limit: AxiomGeneratedCodec.asInt(map['limit']),
      path: AxiomGeneratedCodec.asString(map['path']),
      q: AxiomGeneratedCodec.asString(map['q']),
    );
  }

  final bool? flag;
  final int limit;
  final String path;
  final String q;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (flag case final v?) 'flag': v,
    'limit': limit,
    'path': path,
    'q': q,
  };

  EchoIn copyWith({
    Object? flag = _unset,
    int? limit,
    String? path,
    String? q,
  }) => EchoIn(
    flag: identical(flag, _unset) ? this.flag : flag as bool?,
    limit: limit ?? this.limit,
    path: path ?? this.path,
    q: q ?? this.q,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EchoIn &&
          other.flag == flag &&
          other.limit == limit &&
          other.path == path &&
          other.q == q;

  @override
  int get hashCode => Object.hashAll([flag, limit, path, q]);

  @override
  String toString() => 'EchoIn(flag: $flag, limit: $limit, path: $path, q: $q)';
}

class Everything {
  const Everything({
    required this.color,
    this.counts,
    required this.id,
    required this.inner,
    required this.inners,
    this.note,
    required this.scalars,
    required this.tags,
  });

  factory Everything.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Everything(
      color: EverythingColor.fromJson(map['color']),
      counts: map['counts'] == null
          ? null
          : AxiomGeneratedCodec.asMap(map['counts'], AxiomGeneratedCodec.asInt),
      id: AxiomGeneratedCodec.asString(map['id']),
      inner: Inner.fromJson(map['inner']),
      inners: AxiomGeneratedCodec.asList(map['inners'], Inner.fromJson),
      note: map['note'] == null
          ? null
          : AxiomGeneratedCodec.asString(map['note']),
      scalars: Scalars.fromJson(map['scalars']),
      tags: AxiomGeneratedCodec.asList(
        map['tags'],
        AxiomGeneratedCodec.asString,
      ),
    );
  }

  final EverythingColor color;
  final Map<String, int>? counts;
  final String id;
  final Inner inner;
  final List<Inner> inners;
  final String? note;
  final Scalars scalars;
  final List<String> tags;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'color': color.toJson(),
    if (counts case final v?) 'counts': v,
    'id': id,
    'inner': inner.toJson(),
    'inners': [for (final e in inners) e.toJson()],
    if (note case final v?) 'note': v,
    'scalars': scalars.toJson(),
    'tags': tags,
  };

  Everything copyWith({
    EverythingColor? color,
    Object? counts = _unset,
    String? id,
    Inner? inner,
    List<Inner>? inners,
    Object? note = _unset,
    Scalars? scalars,
    List<String>? tags,
  }) => Everything(
    color: color ?? this.color,
    counts: identical(counts, _unset)
        ? this.counts
        : counts as Map<String, int>?,
    id: id ?? this.id,
    inner: inner ?? this.inner,
    inners: inners ?? this.inners,
    note: identical(note, _unset) ? this.note : note as String?,
    scalars: scalars ?? this.scalars,
    tags: tags ?? this.tags,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Everything &&
          other.color == color &&
          AxiomGeneratedCodec.deepEquals(other.counts, counts) &&
          other.id == id &&
          other.inner == inner &&
          AxiomGeneratedCodec.deepEquals(other.inners, inners) &&
          other.note == note &&
          other.scalars == scalars &&
          AxiomGeneratedCodec.deepEquals(other.tags, tags);

  @override
  int get hashCode => Object.hashAll([
    color,
    AxiomGeneratedCodec.deepHash(counts),
    id,
    inner,
    AxiomGeneratedCodec.deepHash(inners),
    note,
    scalars,
    AxiomGeneratedCodec.deepHash(tags),
  ]);

  @override
  String toString() =>
      'Everything(color: $color, counts: $counts, id: $id, inner: $inner, inners: $inners, note: $note, scalars: $scalars, tags: $tags)';
}

/// Form validators for [Everything] built from the contract field
/// rules. Each has the `TextFormField.validator` signature.
abstract final class EverythingValidators {
  static String? color(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    const allowed = {'red', 'green', 'blue'};
    if (!allowed.contains(value)) {
      return 'Must be one of: red, green, blue';
    }
    return null;
  }

  /// All validators by wire field name.
  static const Map<String, String? Function(String?)> all = {'color': color};
}

class Inner {
  const Inner({required this.depth, required this.label});

  factory Inner.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Inner(
      depth: AxiomGeneratedCodec.asInt(map['depth']),
      label: AxiomGeneratedCodec.asString(map['label']),
    );
  }

  final int depth;
  final String label;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'depth': depth,
    'label': label,
  };

  Inner copyWith({int? depth, String? label}) =>
      Inner(depth: depth ?? this.depth, label: label ?? this.label);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Inner && other.depth == depth && other.label == label;

  @override
  int get hashCode => Object.hashAll([depth, label]);

  @override
  String toString() => 'Inner(depth: $depth, label: $label)';
}

class Item {
  const Item({required this.id, required this.name, required this.qty});

  factory Item.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Item(
      id: AxiomGeneratedCodec.asString(map['id']),
      name: AxiomGeneratedCodec.asString(map['name']),
      qty: AxiomGeneratedCodec.asInt(map['qty']),
    );
  }

  final String id;
  final String name;
  final int qty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'qty': qty,
  };

  Item copyWith({String? id, String? name, int? qty}) =>
      Item(id: id ?? this.id, name: name ?? this.name, qty: qty ?? this.qty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item && other.id == id && other.name == name && other.qty == qty;

  @override
  int get hashCode => Object.hashAll([id, name, qty]);

  @override
  String toString() => 'Item(id: $id, name: $name, qty: $qty)';
}

class ItemInput {
  const ItemInput({required this.name, required this.qty});

  factory ItemInput.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return ItemInput(
      name: AxiomGeneratedCodec.asString(map['name']),
      qty: AxiomGeneratedCodec.asInt(map['qty']),
    );
  }

  final String name;
  final int qty;

  Map<String, dynamic> toJson() => <String, dynamic>{'name': name, 'qty': qty};

  ItemInput copyWith({String? name, int? qty}) =>
      ItemInput(name: name ?? this.name, qty: qty ?? this.qty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemInput && other.name == name && other.qty == qty;

  @override
  int get hashCode => Object.hashAll([name, qty]);

  @override
  String toString() => 'ItemInput(name: $name, qty: $qty)';
}

class ItemRef {
  const ItemRef({required this.id});

  factory ItemRef.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return ItemRef(id: AxiomGeneratedCodec.asString(map['id']));
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

class ItemUpdate {
  const ItemUpdate({required this.id, required this.name, required this.qty});

  factory ItemUpdate.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return ItemUpdate(
      id: AxiomGeneratedCodec.asString(map['id']),
      name: AxiomGeneratedCodec.asString(map['name']),
      qty: AxiomGeneratedCodec.asInt(map['qty']),
    );
  }

  final String id;
  final String name;
  final int qty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'qty': qty,
  };

  ItemUpdate copyWith({String? id, String? name, int? qty}) => ItemUpdate(
    id: id ?? this.id,
    name: name ?? this.name,
    qty: qty ?? this.qty,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemUpdate &&
          other.id == id &&
          other.name == name &&
          other.qty == qty;

  @override
  int get hashCode => Object.hashAll([id, name, qty]);

  @override
  String toString() => 'ItemUpdate(id: $id, name: $name, qty: $qty)';
}

class KeyIn {
  const KeyIn({required this.key});

  factory KeyIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return KeyIn(key: AxiomGeneratedCodec.asString(map['key']));
  }

  final String key;

  Map<String, dynamic> toJson() => <String, dynamic>{'key': key};

  KeyIn copyWith({String? key}) => KeyIn(key: key ?? this.key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is KeyIn && other.key == key;

  @override
  int get hashCode => Object.hashAll([key]);

  @override
  String toString() => 'KeyIn(key: $key)';
}

class NonceIn {
  const NonceIn({required this.key});

  factory NonceIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return NonceIn(key: AxiomGeneratedCodec.asString(map['key']));
  }

  final String key;

  Map<String, dynamic> toJson() => <String, dynamic>{'key': key};

  NonceIn copyWith({String? key}) => NonceIn(key: key ?? this.key);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NonceIn && other.key == key;

  @override
  int get hashCode => Object.hashAll([key]);

  @override
  String toString() => 'NonceIn(key: $key)';
}

class Ping {
  const Ping({required this.seq, required this.text});

  factory Ping.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Ping(
      seq: AxiomGeneratedCodec.asInt(map['seq']),
      text: AxiomGeneratedCodec.asString(map['text']),
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

class Problem {
  const Problem({required this.message});

  factory Problem.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Problem(message: AxiomGeneratedCodec.asString(map['message']));
  }

  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{'message': message};

  Problem copyWith({String? message}) =>
      Problem(message: message ?? this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Problem && other.message == message;

  @override
  int get hashCode => Object.hashAll([message]);

  @override
  String toString() => 'Problem(message: $message)';
}

class Retried {
  const Retried({required this.attempt, required this.ok});

  factory Retried.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Retried(
      attempt: AxiomGeneratedCodec.asInt(map['attempt']),
      ok: AxiomGeneratedCodec.asBool(map['ok']),
    );
  }

  final int attempt;
  final bool ok;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'attempt': attempt,
    'ok': ok,
  };

  Retried copyWith({int? attempt, bool? ok}) =>
      Retried(attempt: attempt ?? this.attempt, ok: ok ?? this.ok);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Retried && other.attempt == attempt && other.ok == ok;

  @override
  int get hashCode => Object.hashAll([attempt, ok]);

  @override
  String toString() => 'Retried(attempt: $attempt, ok: $ok)';
}

class RetryIn {
  const RetryIn({required this.attempt});

  factory RetryIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return RetryIn(attempt: AxiomGeneratedCodec.asInt(map['attempt']));
  }

  final int attempt;

  Map<String, dynamic> toJson() => <String, dynamic>{'attempt': attempt};

  RetryIn copyWith({int? attempt}) => RetryIn(attempt: attempt ?? this.attempt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RetryIn && other.attempt == attempt;

  @override
  int get hashCode => Object.hashAll([attempt]);

  @override
  String toString() => 'RetryIn(attempt: $attempt)';
}

class Scalars {
  const Scalars({
    required this.at,
    required this.b,
    required this.bytes,
    required this.f32,
    required this.f64,
    required this.i32,
    required this.i64,
    required this.json,
    required this.s,
  });

  factory Scalars.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Scalars(
      at: AxiomGeneratedCodec.asDateTime(map['at']),
      b: AxiomGeneratedCodec.asBool(map['b']),
      bytes: AxiomGeneratedCodec.asBytes(map['bytes']),
      f32: AxiomGeneratedCodec.asDouble(map['f32']),
      f64: AxiomGeneratedCodec.asDouble(map['f64']),
      i32: AxiomGeneratedCodec.asInt(map['i32']),
      i64: AxiomGeneratedCodec.asInt(map['i64']),
      json: map['json'],
      s: AxiomGeneratedCodec.asString(map['s']),
    );
  }

  final DateTime at;
  final bool b;
  final Uint8List bytes;
  final double f32;
  final double f64;
  final int i32;
  final int i64;
  final Object? json;
  final String s;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at.toIso8601String(),
    'b': b,
    'bytes': AxiomGeneratedCodec.bytesToJson(bytes),
    'f32': f32,
    'f64': f64,
    'i32': i32,
    'i64': i64,
    'json': json,
    's': s,
  };

  Scalars copyWith({
    DateTime? at,
    bool? b,
    Uint8List? bytes,
    double? f32,
    double? f64,
    int? i32,
    int? i64,
    Object? json,
    String? s,
  }) => Scalars(
    at: at ?? this.at,
    b: b ?? this.b,
    bytes: bytes ?? this.bytes,
    f32: f32 ?? this.f32,
    f64: f64 ?? this.f64,
    i32: i32 ?? this.i32,
    i64: i64 ?? this.i64,
    json: json ?? this.json,
    s: s ?? this.s,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Scalars &&
          other.at == at &&
          other.b == b &&
          AxiomGeneratedCodec.deepEquals(other.bytes, bytes) &&
          other.f32 == f32 &&
          other.f64 == f64 &&
          other.i32 == i32 &&
          other.i64 == i64 &&
          AxiomGeneratedCodec.deepEquals(other.json, json) &&
          other.s == s;

  @override
  int get hashCode => Object.hashAll([
    at,
    b,
    AxiomGeneratedCodec.deepHash(bytes),
    f32,
    f64,
    i32,
    i64,
    AxiomGeneratedCodec.deepHash(json),
    s,
  ]);

  @override
  String toString() =>
      'Scalars(at: $at, b: $b, bytes: $bytes, f32: $f32, f64: $f64, i32: $i32, i64: $i64, json: $json, s: $s)';
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

class Stamp {
  const Stamp({required this.key, required this.strategy});

  factory Stamp.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Stamp(
      key: AxiomGeneratedCodec.asString(map['key']),
      strategy: AxiomGeneratedCodec.asString(map['strategy']),
    );
  }

  final String key;
  final String strategy;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'strategy': strategy,
  };

  Stamp copyWith({String? key, String? strategy}) =>
      Stamp(key: key ?? this.key, strategy: strategy ?? this.strategy);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Stamp && other.key == key && other.strategy == strategy;

  @override
  int get hashCode => Object.hashAll([key, strategy]);

  @override
  String toString() => 'Stamp(key: $key, strategy: $strategy)';
}

class StampIn {
  const StampIn({required this.key, required this.strategy});

  factory StampIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return StampIn(
      key: AxiomGeneratedCodec.asString(map['key']),
      strategy: AxiomGeneratedCodec.asString(map['strategy']),
    );
  }

  final String key;
  final String strategy;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'strategy': strategy,
  };

  StampIn copyWith({String? key, String? strategy}) =>
      StampIn(key: key ?? this.key, strategy: strategy ?? this.strategy);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StampIn && other.key == key && other.strategy == strategy;

  @override
  int get hashCode => Object.hashAll([key, strategy]);

  @override
  String toString() => 'StampIn(key: $key, strategy: $strategy)';
}

class Tick {
  const Tick({required this.id, required this.seq});

  factory Tick.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Tick(
      id: AxiomGeneratedCodec.asString(map['id']),
      seq: AxiomGeneratedCodec.asInt(map['seq']),
    );
  }

  final String id;
  final int seq;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'seq': seq};

  Tick copyWith({String? id, int? seq}) =>
      Tick(id: id ?? this.id, seq: seq ?? this.seq);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tick && other.id == id && other.seq == seq;

  @override
  int get hashCode => Object.hashAll([id, seq]);

  @override
  String toString() => 'Tick(id: $id, seq: $seq)';
}

class Who {
  const Who({required this.method, required this.ok});

  factory Who.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Who(
      method: AxiomGeneratedCodec.asString(map['method']),
      ok: AxiomGeneratedCodec.asBool(map['ok']),
    );
  }

  final String method;
  final bool ok;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'method': method,
    'ok': ok,
  };

  Who copyWith({String? method, bool? ok}) =>
      Who(method: method ?? this.method, ok: ok ?? this.ok);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Who && other.method == method && other.ok == ok;

  @override
  int get hashCode => Object.hashAll([method, ok]);

  @override
  String toString() => 'Who(method: $method, ok: $ok)';
}

/// A typed failure declared by the contract (`failure` / `errors(...)`).
sealed class ContractFailure {
  const ContractFailure();

  /// Contract failure code, for example `conflict`.
  String get code;

  Map<String, dynamic> toJson();

  /// Decodes the failure carried by [error], or null.
  static ContractFailure? fromError(AxiomError error) {
    final (code, payload) = AxiomGeneratedCodec.failureParts(error);
    switch (code) {
      case 'conflict':
        return ConflictFailure.fromJson(payload);
      case 'unauthorized':
        return UnauthorizedFailure.fromJson(payload);
    }
    return null;
  }

  /// Registers every failure decoder with [AxiomFailureRegistry].
  static void registerAll({String? namespace}) {
    AxiomFailureRegistry.register(
      'conflict',
      ConflictFailure.fromJson,
      namespace: namespace,
    );
    AxiomFailureRegistry.register(
      'unauthorized',
      UnauthorizedFailure.fromJson,
      namespace: namespace,
    );
  }
}

/// Failures the `authApiKeyHeader` endpoint can return.
sealed class AuthApiKeyHeaderErrors implements ContractFailure {}

/// Failures the `authApiKeyQuery` endpoint can return.
sealed class AuthApiKeyQueryErrors implements ContractFailure {}

/// Failures the `claim` endpoint can return.
sealed class ClaimErrors implements ContractFailure {}

/// Contract failure `conflict`.
class ConflictFailure extends ContractFailure implements ClaimErrors {
  const ConflictFailure({required this.existingId, required this.message});

  factory ConflictFailure.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return ConflictFailure(
      existingId: AxiomGeneratedCodec.asString(map['existingId']),
      message: AxiomGeneratedCodec.asString(map['message']),
    );
  }

  final String existingId;
  final String message;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'existingId': existingId,
    'message': message,
  };

  ConflictFailure copyWith({String? existingId, String? message}) =>
      ConflictFailure(
        existingId: existingId ?? this.existingId,
        message: message ?? this.message,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictFailure &&
          other.existingId == existingId &&
          other.message == message;

  @override
  int get hashCode => Object.hashAll([existingId, message]);

  @override
  String toString() =>
      'ConflictFailure(existingId: $existingId, message: $message)';

  static const String failureCode = 'conflict';

  @override
  String get code => failureCode;
}

/// Contract failure `unauthorized`.
class UnauthorizedFailure extends ContractFailure
    implements AuthApiKeyHeaderErrors, AuthApiKeyQueryErrors {
  const UnauthorizedFailure({required this.message});

  factory UnauthorizedFailure.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return UnauthorizedFailure(
      message: AxiomGeneratedCodec.asString(map['message']),
    );
  }

  final String message;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'message': message};

  UnauthorizedFailure copyWith({String? message}) =>
      UnauthorizedFailure(message: message ?? this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnauthorizedFailure && other.message == message;

  @override
  int get hashCode => Object.hashAll([message]);

  @override
  String toString() => 'UnauthorizedFailure(message: $message)';

  static const String failureCode = 'unauthorized';

  @override
  String get code => failureCode;
}

/// Typed access to contract failures on [AxiomError].
extension AxiomErrorContractFailures on AxiomError {
  /// The typed contract failure, or null for other errors.
  ContractFailure? get contractFailure => ContractFailure.fromError(this);

  /// Failure of `authApiKeyHeader` as [AuthApiKeyHeaderErrors], or null.
  AuthApiKeyHeaderErrors? get authApiKeyHeaderFailure {
    final f = contractFailure;
    return f is AuthApiKeyHeaderErrors ? f : null;
  }

  /// Pattern match on the failures of `authApiKeyHeader`; [orElse] gets any other error.
  R whenAuthApiKeyHeader<R>({
    required R Function(UnauthorizedFailure failure) unauthorized,
    required R Function(AxiomError error) orElse,
  }) {
    return switch (authApiKeyHeaderFailure) {
      final UnauthorizedFailure f => unauthorized(f),
      null => orElse(this),
    };
  }

  /// Failure of `authApiKeyQuery` as [AuthApiKeyQueryErrors], or null.
  AuthApiKeyQueryErrors? get authApiKeyQueryFailure {
    final f = contractFailure;
    return f is AuthApiKeyQueryErrors ? f : null;
  }

  /// Pattern match on the failures of `authApiKeyQuery`; [orElse] gets any other error.
  R whenAuthApiKeyQuery<R>({
    required R Function(UnauthorizedFailure failure) unauthorized,
    required R Function(AxiomError error) orElse,
  }) {
    return switch (authApiKeyQueryFailure) {
      final UnauthorizedFailure f => unauthorized(f),
      null => orElse(this),
    };
  }

  /// Failure of `claim` as [ClaimErrors], or null.
  ClaimErrors? get claimFailure {
    final f = contractFailure;
    return f is ClaimErrors ? f : null;
  }

  /// Pattern match on the failures of `claim`; [orElse] gets any other error.
  R whenClaim<R>({
    required R Function(ConflictFailure failure) conflict,
    required R Function(AxiomError error) orElse,
  }) {
    return switch (claimFailure) {
      final ConflictFailure f => conflict(f),
      null => orElse(this),
    };
  }
}
