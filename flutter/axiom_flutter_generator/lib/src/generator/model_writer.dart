import 'utils.dart';

class ModelWriter {
  final Map<String, dynamic> ir;

  ModelWriter(this.ir);

  String write() {
    final buffer = StringBuffer();
    buffer.writeln('// GENERATED CODE – DO NOT EDIT.');
    buffer.writeln('// ignore_for_file: unused_import');
    buffer.writeln('// ignore_for_file: invalid_null_aware_operator');
    buffer.writeln();
    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln();

    final enums = (ir['enums'] as Map?)?.cast<String, dynamic>() ?? {};
    final models = (ir['models'] as Map?)?.cast<String, dynamic>() ?? {};

    // 1. Generate Enums
    for (final enumDef in enums.values) {
      _writeEnum(buffer, enumDef);
    }

    // 2. Generate Models
    for (final modelDef in models.values) {
      _writeModel(buffer, modelDef);
    }

    return buffer.toString();
  }

  void _writeEnum(StringBuffer buffer, Map<String, dynamic> enumDef) {
    final name = GeneratorUtils.pascalCase(enumDef['name']);
    final values = (enumDef['values'] as List?)?.cast<String>() ?? [];

    buffer.writeln('enum $name {');
    for (var val in values) {
      buffer.writeln('  $val,');
    }
    buffer.writeln('  ;');
    buffer.writeln();

    // toJson
    buffer.writeln('  String toJson() => name;');
    buffer.writeln();

    // fromJson
    buffer.writeln('  static $name fromJson(dynamic value) {');
    buffer.writeln('    if (value is String) {');
    buffer.writeln('      return $name.values.firstWhere(');
    buffer.writeln('        (e) => e.name == value,');
    buffer.writeln(
      '        orElse: () => throw Exception(\'Unknown $name value: \$value\'),',
    );
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln(
      '    throw Exception(\'Expected String for $name, got \$value\');',
    );
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();
  }

  void _writeModel(StringBuffer buffer, Map<String, dynamic> modelDef) {
    final className = GeneratorUtils.pascalCase(modelDef['name']);
    final fields = (modelDef['fields'] as List?) ?? [];

    buffer.writeln('class $className {');

    // Fields
    for (final f in fields) {
      final field = f as Map<String, dynamic>;
      final name = GeneratorUtils.camelCase(field['name']);
      final typeRef = field['typeRef'] as Map<String, dynamic>;
      final isOptional = field['isOptional'] as bool? ?? false;

      String dartType = GeneratorUtils.dartTypeFromIr(typeRef, scoped: false);
      if (isOptional) dartType += '?';

      buffer.writeln('  final $dartType $name;');
    }
    buffer.writeln();

    // Constructor
    buffer.writeln('  const $className({');
    for (final f in fields) {
      final field = f as Map<String, dynamic>;
      final name = GeneratorUtils.camelCase(field['name']);
      final isOptional = field['isOptional'] as bool? ?? false;
      if (!isOptional) {
        buffer.writeln('    required this.$name,');
      } else {
        buffer.writeln('    this.$name,');
      }
    }
    buffer.writeln('  });');
    buffer.writeln();

    // fromJson
    buffer.writeln(
      '  factory $className.fromJson(Map<String, dynamic> json) {',
    );
    buffer.writeln('    return $className(');

    for (final f in fields) {
      final field = f as Map<String, dynamic>;
      final origName = field['name'] as String;
      final name = GeneratorUtils.camelCase(origName);
      final typeRef = field['typeRef'] as Map<String, dynamic>;
      final isOptional = field['isOptional'] as bool? ?? false;

      final parseLogic = _generateParseLogic(
        typeRef,
        "json['$origName']",
        isOptional,
      );
      buffer.writeln('      $name: $parseLogic,');
    }

    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // toJson
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    for (final f in fields) {
      final field = f as Map<String, dynamic>;
      final origName = field['name'] as String;
      final name = GeneratorUtils.camelCase(origName);
      final typeRef = field['typeRef'] as Map<String, dynamic>;
      final isOptional = field['isOptional'] as bool? ?? false;

      final serializeLogic = _generateSerializeLogic(typeRef, name, isOptional);
      buffer.writeln("      '$origName': $serializeLogic,");
    }
    buffer.writeln('    };');
    buffer.writeln('  }');

    buffer.writeln('}');
    buffer.writeln();
  }

  String _generateParseLogic(
    Map<String, dynamic> typeRef,
    String access,
    bool isOptional,
  ) {
    final kind = typeRef['kind'] as String;

    // Null check wrapper for optionals
    String wrap(String logic) {
      return isOptional ? '($access == null ? null : $logic)' : logic;
    }

    switch (kind) {
      case 'named':
        final typeName = GeneratorUtils.pascalCase(typeRef['value']);
        return wrap('$typeName.fromJson($access)');

      case 'dateTime':
        return wrap('DateTime.parse($access)');

      case 'bytes':
        // Assuming bytes come as Base64 string or list of ints.
        // For simplicity assuming list of ints if not base64 encoded by codec.
        // Actually, internal Codec handles root types, but nested fields usually JSON.
        // Let's assume standard JSON list of ints for bytes in a model.
        return wrap('Uint8List.fromList(($access as List).cast<int>())');

      case 'list':
        final innerType = typeRef['value'] as Map<String, dynamic>;
        final innerParse = _generateParseLogic(
          innerType,
          'e',
          false,
        ); // Inner is not optional in the list map
        return wrap('($access as List).map((e) => $innerParse).toList()');

      default:
        // Primitives (int, string, bool, double)
        return access;
    }
  }

  String _generateSerializeLogic(
    Map<String, dynamic> typeRef,
    String varName,
    bool isOptional,
  ) {
    final kind = typeRef['kind'] as String;

    String wrap(String logic) {
      return isOptional ? '$varName?.$logic' : '$varName.$logic';
    }

    switch (kind) {
      case 'named':
        return wrap('toJson()');
      case 'dateTime':
        return wrap('toIso8601String()');
      case 'list':
        final innerType = typeRef['value'] as Map<String, dynamic>;
        // Special case for list serialization
        if (isOptional) {
          return '$varName?.map((e) => ${_generateSerializeLogic(innerType, 'e', false)}).toList()';
        }
        return '$varName.map((e) => ${_generateSerializeLogic(innerType, 'e', false)}).toList()';
      default:
        return varName;
    }
  }
}
