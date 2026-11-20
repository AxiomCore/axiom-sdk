import 'utils.dart';

/// Resolved Dart-side type of an IR `typeRef` (plus field validation hints).
sealed class TypeNode {
  const TypeNode();
}

class PrimType extends TypeNode {
  /// One of string, int, double, bool, dateTime, bytes.
  final String kind;
  const PrimType(this.kind);
}

class JsonType extends TypeNode {
  const JsonType();
}

class VoidType extends TypeNode {
  const VoidType();
}

/// A generated class or enum declared in models.dart.
class RefType extends TypeNode {
  final String dartName;

  /// model, enum, union.
  final String kind;
  const RefType(this.dartName, this.kind);
}

class ListType extends TypeNode {
  final TypeNode item;
  const ListType(this.item);
}

class MapType extends TypeNode {
  final TypeNode key;
  final TypeNode value;
  const MapType(this.key, this.value);
}

/// Converts IR type references to Dart types and JSON (de)serialisation code.
class TypeMapper {
  /// Prefix for generated types (`models.` from the SDK file, '' in models).
  final String prefix;

  /// IR enum names (raw) known in the schema.
  final Set<String> enumNames;

  TypeMapper({required this.prefix, required this.enumNames});

  String get codec => '${prefix}AxiomGeneratedCodec';

  TypeNode resolve(Map<String, dynamic> typeRef) {
    final kind = typeRef['kind'] as String? ?? 'json';
    switch (kind) {
      case 'string':
        return const PrimType('string');
      case 'int32':
      case 'int64':
      case 'int':
        return const PrimType('int');
      case 'float32':
      case 'float64':
      case 'float':
      case 'double':
        return const PrimType('double');
      case 'bool':
        return const PrimType('bool');
      case 'dateTime':
        return const PrimType('dateTime');
      case 'bytes':
        return const PrimType('bytes');
      case 'void':
        return const VoidType();
      case 'named':
        final raw = typeRef['value'] as String;
        final name = GeneratorUtils.pascalCase(raw);
        return RefType(name, enumNames.contains(raw) ? 'enum' : 'model');
      case 'list':
        return ListType(
          resolve((typeRef['value'] as Map).cast<String, dynamic>()),
        );
      case 'map':
        final args = typeRef['value'] as List;
        return MapType(
          resolve((args[0] as Map).cast<String, dynamic>()),
          resolve((args[1] as Map).cast<String, dynamic>()),
        );
      default:
        return const JsonType();
    }
  }

  String dartType(TypeNode t) => switch (t) {
    PrimType(kind: 'string') => 'String',
    PrimType(kind: 'int') => 'int',
    PrimType(kind: 'double') => 'double',
    PrimType(kind: 'bool') => 'bool',
    PrimType(kind: 'dateTime') => 'DateTime',
    PrimType(kind: 'bytes') => 'Uint8List',
    PrimType() => 'Object?',
    JsonType() => 'Object?',
    VoidType() => 'void',
    RefType(:final dartName) => '$prefix$dartName',
    ListType(:final item) => 'List<${dartType(item)}>',
    MapType(:final key, :final value) =>
      'Map<${dartType(key)}, ${dartType(value)}>',
  };

  /// Expression of type `T Function(Object?)` decoding one JSON value.
  String decodeFn(TypeNode t) => switch (t) {
    PrimType(kind: 'string') => '$codec.asString',
    PrimType(kind: 'int') => '$codec.asInt',
    PrimType(kind: 'double') => '$codec.asDouble',
    PrimType(kind: 'bool') => '$codec.asBool',
    PrimType(kind: 'dateTime') => '$codec.asDateTime',
    PrimType(kind: 'bytes') => '$codec.asBytes',
    RefType(:final dartName) => '$prefix$dartName.fromJson',
    JsonType() || PrimType() => '$codec.asJson',
    VoidType() => '$codec.asVoid',
    ListType() || MapType() => '(e) => ${decode(t, 'e')}',
  };

  /// Expression decoding the JSON value [x] (non-null) into [t].
  ///
  /// Types known statically decode inline (`x as String`), not through a
  /// helper call, and a nullable value is read once (see [decodeNullable]).
  String decode(TypeNode t, String x) => switch (t) {
    JsonType() => x,
    PrimType(kind: 'string') => '($x as String)',
    PrimType(kind: 'bool') => '($x as bool)',
    ListType(:final item) => '$codec.asList($x, ${decodeFn(item)})',
    MapType(:final key, :final value) =>
      _isStringKey(key)
          ? '$codec.asMap($x, ${decodeFn(value)})'
          : '$codec.asKeyedMap($x, ${_keyDecodeFn(key)}, ${decodeFn(value)})',
    _ => '${decodeFn(t)}($x)',
  };

  /// Decoding of a nullable value.
  String decodeNullable(TypeNode t, String x) => t is JsonType
      ? x
      : 'switch ($x) { null => null, final v => ${decode(t, 'v')} }';

  bool _isStringKey(TypeNode key) =>
      key is PrimType && key.kind == 'string' || key is JsonType;

  String _keyDecodeFn(TypeNode key) => switch (key) {
    PrimType(kind: 'int') => 'int.parse',
    PrimType(kind: 'double') => 'double.parse',
    PrimType(kind: 'bool') => "(k) => k == 'true'",
    PrimType(kind: 'dateTime') => 'DateTime.parse',
    RefType(kind: 'enum', :final dartName) => '$prefix$dartName.fromJson',
    _ => '(k) => k',
  };

  bool isIdentityEncode(TypeNode t) => switch (t) {
    PrimType(kind: 'string' || 'int' || 'double' || 'bool') => true,
    JsonType() => true,
    ListType(:final item) => isIdentityEncode(item),
    MapType(:final key, :final value) =>
      _isStringKey(key) && isIdentityEncode(value),
    _ => false,
  };

  /// Expression encoding the non-null Dart value [x] as JSON.
  String encode(TypeNode t, String x) {
    if (isIdentityEncode(t)) return x;
    return switch (t) {
      PrimType(kind: 'dateTime') => '$x.toIso8601String()',
      PrimType(kind: 'bytes') => '$codec.bytesToJson($x)',
      RefType() => '$x.toJson()',
      ListType(:final item) => '[for (final e in $x) ${encode(item, 'e')}]',
      MapType(:final key, :final value) =>
        '{for (final e in $x.entries) ${_keyEncode(key, 'e.key')}: ${encode(value, 'e.value')}}',
      _ => x,
    };
  }

  String _keyEncode(TypeNode key, String x) => switch (key) {
    PrimType(kind: 'string') => x,
    PrimType(kind: 'dateTime') => '$x.toIso8601String()',
    RefType(kind: 'enum') => '$x.toJson()',
    _ => '$x.toString()',
  };

  /// Expression converting [x] (non-null) to a header/query/path string.
  String toParamString(TypeNode t, String x) => switch (t) {
    PrimType(kind: 'string') => x,
    PrimType(kind: 'dateTime') => '$x.toIso8601String()',
    PrimType(kind: 'bytes') => '$codec.bytesToJson($x)',
    RefType(kind: 'enum') => '$x.toJson()',
    PrimType() => '$x.toString()',
    _ => 'jsonEncode(${encode(t, x)})',
  };

  bool usesBytes(TypeNode t) => switch (t) {
    PrimType(kind: 'bytes') => true,
    ListType(:final item) => usesBytes(item),
    MapType(:final key, :final value) => usesBytes(key) || usesBytes(value),
    _ => false,
  };
}
