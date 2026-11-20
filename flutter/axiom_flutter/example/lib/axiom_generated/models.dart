// GENERATED CODE - DO NOT EDIT.
// axiom_flutter_generator 0.150.0
// todos: dev.axiomcore.example.todos 1.0.0 variant default schema 84a9b8da032b

import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';

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

class Greeting {
  const Greeting({required this.message});

  factory Greeting.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Greeting(message: AxiomGeneratedCodec.asString(map['message']));
  }

  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{'message': message};

  Greeting copyWith({String? message}) =>
      Greeting(message: message ?? this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Greeting && other.message == message;

  @override
  int get hashCode => Object.hashAll([message]);

  @override
  String toString() => 'Greeting(message: $message)';
}

class GreetingIn {
  const GreetingIn({required this.name});

  factory GreetingIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return GreetingIn(name: AxiomGeneratedCodec.asString(map['name']));
  }

  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'name': name};

  GreetingIn copyWith({String? name}) => GreetingIn(name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GreetingIn && other.name == name;

  @override
  int get hashCode => Object.hashAll([name]);

  @override
  String toString() => 'GreetingIn(name: $name)';
}

class Todo {
  const Todo({required this.done, required this.id, required this.title});

  factory Todo.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return Todo(
      done: AxiomGeneratedCodec.asBool(map['done']),
      id: AxiomGeneratedCodec.asString(map['id']),
      title: AxiomGeneratedCodec.asString(map['title']),
    );
  }

  final bool done;
  final String id;
  final String title;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'done': done,
    'id': id,
    'title': title,
  };

  Todo copyWith({bool? done, String? id, String? title}) => Todo(
    done: done ?? this.done,
    id: id ?? this.id,
    title: title ?? this.title,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          other.done == done &&
          other.id == id &&
          other.title == title;

  @override
  int get hashCode => Object.hashAll([done, id, title]);

  @override
  String toString() => 'Todo(done: $done, id: $id, title: $title)';
}

class TodoIn {
  const TodoIn({required this.title});

  factory TodoIn.fromJson(Object? json) {
    final map = AxiomGeneratedCodec.asObject(json);
    return TodoIn(title: AxiomGeneratedCodec.asString(map['title']));
  }

  final String title;

  Map<String, dynamic> toJson() => <String, dynamic>{'title': title};

  TodoIn copyWith({String? title}) => TodoIn(title: title ?? this.title);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TodoIn && other.title == title;

  @override
  int get hashCode => Object.hashAll([title]);

  @override
  String toString() => 'TodoIn(title: $title)';
}
