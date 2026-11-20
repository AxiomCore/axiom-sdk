// GENERATED CODE – DO NOT EDIT.
// ignore_for_file: unused_import
// ignore_for_file: invalid_null_aware_operator

import 'dart:typed_data';

class BytesIn {
  final Uint8List data;

  const BytesIn({required this.data});

  factory BytesIn.fromJson(Map<String, dynamic> json) {
    return BytesIn(
      data: Uint8List.fromList((json['data'] as List).cast<int>()),
    );
  }

  Map<String, dynamic> toJson() {
    return {'data': data};
  }
}

class BytesOut {
  final Uint8List data;
  final int size;

  const BytesOut({required this.data, required this.size});

  factory BytesOut.fromJson(Map<String, dynamic> json) {
    return BytesOut(
      data: Uint8List.fromList((json['data'] as List).cast<int>()),
      size: json['size'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'data': data, 'size': size};
  }
}

class ClaimIn {
  final String name;

  const ClaimIn({required this.name});

  factory ClaimIn.fromJson(Map<String, dynamic> json) {
    return ClaimIn(name: json['name'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'name': name};
  }
}

class Conflict {
  final String existingId;
  final String message;

  const Conflict({required this.existingId, required this.message});

  factory Conflict.fromJson(Map<String, dynamic> json) {
    return Conflict(
      existingId: json['existingId'] as String,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'existingId': existingId, 'message': message};
  }
}

class Cursor {
  final String? last;

  const Cursor({this.last});

  factory Cursor.fromJson(Map<String, dynamic> json) {
    return Cursor(last: (json['last'] == null ? null : json['last'] as String));
  }

  Map<String, dynamic> toJson() {
    return {'last': last};
  }
}

class Deleted {
  final bool deleted;
  final String id;

  const Deleted({required this.deleted, required this.id});

  factory Deleted.fromJson(Map<String, dynamic> json) {
    return Deleted(deleted: json['deleted'] as bool, id: json['id'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'deleted': deleted, 'id': id};
  }
}

class Echo {
  final bool? flag;
  final int limit;
  final String path;
  final String q;

  const Echo({
    this.flag,
    required this.limit,
    required this.path,
    required this.q,
  });

  factory Echo.fromJson(Map<String, dynamic> json) {
    return Echo(
      flag: (json['flag'] == null ? null : json['flag'] as bool),
      limit: json['limit'] as int,
      path: json['path'] as String,
      q: json['q'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'flag': flag, 'limit': limit, 'path': path, 'q': q};
  }
}

class EchoIn {
  final bool? flag;
  final int limit;
  final String path;
  final String q;

  const EchoIn({
    this.flag,
    required this.limit,
    required this.path,
    required this.q,
  });

  factory EchoIn.fromJson(Map<String, dynamic> json) {
    return EchoIn(
      flag: (json['flag'] == null ? null : json['flag'] as bool),
      limit: json['limit'] as int,
      path: json['path'] as String,
      q: json['q'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'flag': flag, 'limit': limit, 'path': path, 'q': q};
  }
}

class Everything {
  final String color;
  final Map<String, int>? counts;
  final String id;
  final Inner inner;
  final List<Inner> inners;
  final String? note;
  final Scalars scalars;
  final List<String> tags;

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

  factory Everything.fromJson(Map<String, dynamic> json) {
    return Everything(
      color: json['color'] as String,
      counts: (json['counts'] == null
          ? null
          : (json['counts'] as Map).map(
              (k, v) => MapEntry(k as String, v as int),
            )),
      id: json['id'] as String,
      inner: Inner.fromJson(json['inner']),
      inners: (json['inners'] as List).map((e) => Inner.fromJson(e)).toList(),
      note: (json['note'] == null ? null : json['note'] as String),
      scalars: Scalars.fromJson(json['scalars']),
      tags: (json['tags'] as List).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color,
      'counts': counts?.map((k, v) => MapEntry(k, v)),
      'id': id,
      'inner': inner.toJson(),
      'inners': inners.map((e) => e.toJson()).toList(),
      'note': note,
      'scalars': scalars.toJson(),
      'tags': tags.map((e) => e).toList(),
    };
  }
}

class Inner {
  final int depth;
  final String label;

  const Inner({required this.depth, required this.label});

  factory Inner.fromJson(Map<String, dynamic> json) {
    return Inner(depth: json['depth'] as int, label: json['label'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'depth': depth, 'label': label};
  }
}

class Item {
  final String id;
  final String name;
  final int qty;

  const Item({required this.id, required this.name, required this.qty});

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      name: json['name'] as String,
      qty: json['qty'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'qty': qty};
  }
}

class ItemInput {
  final String name;
  final int qty;

  const ItemInput({required this.name, required this.qty});

  factory ItemInput.fromJson(Map<String, dynamic> json) {
    return ItemInput(name: json['name'] as String, qty: json['qty'] as int);
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'qty': qty};
  }
}

class ItemRef {
  final String id;

  const ItemRef({required this.id});

  factory ItemRef.fromJson(Map<String, dynamic> json) {
    return ItemRef(id: json['id'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'id': id};
  }
}

class ItemUpdate {
  final String id;
  final String name;
  final int qty;

  const ItemUpdate({required this.id, required this.name, required this.qty});

  factory ItemUpdate.fromJson(Map<String, dynamic> json) {
    return ItemUpdate(
      id: json['id'] as String,
      name: json['name'] as String,
      qty: json['qty'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'qty': qty};
  }
}

class KeyIn {
  final String key;

  const KeyIn({required this.key});

  factory KeyIn.fromJson(Map<String, dynamic> json) {
    return KeyIn(key: json['key'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'key': key};
  }
}

class NonceIn {
  final String key;

  const NonceIn({required this.key});

  factory NonceIn.fromJson(Map<String, dynamic> json) {
    return NonceIn(key: json['key'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'key': key};
  }
}

class Ping {
  final int seq;
  final String text;

  const Ping({required this.seq, required this.text});

  factory Ping.fromJson(Map<String, dynamic> json) {
    return Ping(seq: json['seq'] as int, text: json['text'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'seq': seq, 'text': text};
  }
}

class Problem {
  final String message;

  const Problem({required this.message});

  factory Problem.fromJson(Map<String, dynamic> json) {
    return Problem(message: json['message'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'message': message};
  }
}

class Retried {
  final int attempt;
  final bool ok;

  const Retried({required this.attempt, required this.ok});

  factory Retried.fromJson(Map<String, dynamic> json) {
    return Retried(attempt: json['attempt'] as int, ok: json['ok'] as bool);
  }

  Map<String, dynamic> toJson() {
    return {'attempt': attempt, 'ok': ok};
  }
}

class RetryIn {
  final int attempt;

  const RetryIn({required this.attempt});

  factory RetryIn.fromJson(Map<String, dynamic> json) {
    return RetryIn(attempt: json['attempt'] as int);
  }

  Map<String, dynamic> toJson() {
    return {'attempt': attempt};
  }
}

class Scalars {
  final DateTime at;
  final bool b;
  final Uint8List bytes;
  final double f32;
  final double f64;
  final int i32;
  final int i64;
  final dynamic json;
  final String s;

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

  factory Scalars.fromJson(Map<String, dynamic> json) {
    return Scalars(
      at: DateTime.parse(json['at'] as String),
      b: json['b'] as bool,
      bytes: Uint8List.fromList((json['bytes'] as List).cast<int>()),
      f32: (json['f32'] as num).toDouble(),
      f64: (json['f64'] as num).toDouble(),
      i32: json['i32'] as int,
      i64: json['i64'] as int,
      json: json['json'],
      s: json['s'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'at': at.toIso8601String(),
      'b': b,
      'bytes': bytes,
      'f32': f32,
      'f64': f64,
      'i32': i32,
      'i64': i64,
      'json': json,
      's': s,
    };
  }
}

class SocketIn {
  final Ping message;

  const SocketIn({required this.message});

  factory SocketIn.fromJson(Map<String, dynamic> json) {
    return SocketIn(message: Ping.fromJson(json['message']));
  }

  Map<String, dynamic> toJson() {
    return {'message': message.toJson()};
  }
}

class Stamp {
  final String key;
  final String strategy;

  const Stamp({required this.key, required this.strategy});

  factory Stamp.fromJson(Map<String, dynamic> json) {
    return Stamp(
      key: json['key'] as String,
      strategy: json['strategy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'key': key, 'strategy': strategy};
  }
}

class StampIn {
  final String key;
  final String strategy;

  const StampIn({required this.key, required this.strategy});

  factory StampIn.fromJson(Map<String, dynamic> json) {
    return StampIn(
      key: json['key'] as String,
      strategy: json['strategy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'key': key, 'strategy': strategy};
  }
}

class Tick {
  final String id;
  final int seq;

  const Tick({required this.id, required this.seq});

  factory Tick.fromJson(Map<String, dynamic> json) {
    return Tick(id: json['id'] as String, seq: json['seq'] as int);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'seq': seq};
  }
}

class Who {
  final String method;
  final bool ok;

  const Who({required this.method, required this.ok});

  factory Who.fromJson(Map<String, dynamic> json) {
    return Who(method: json['method'] as String, ok: json['ok'] as bool);
  }

  Map<String, dynamic> toJson() {
    return {'method': method, 'ok': ok};
  }
}
