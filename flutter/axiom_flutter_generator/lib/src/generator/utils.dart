/// Utilities for string manipulation and type mapping.
class GeneratorUtils {
  static String pascalCase(String name) {
    if (name.isEmpty) return name;
    final parts = name
        .split(RegExp(r'[_\-\s]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return name[0].toUpperCase() + name.substring(1);

    final buf = StringBuffer();
    for (final part in parts) {
      if (part.isEmpty) continue;
      buf.write(part[0].toUpperCase());
      if (part.length > 1) {
        buf.write(part.substring(1));
      }
    }
    return buf.toString();
  }

  static String camelCase(String name) {
    if (name.isEmpty) return name;
    final pascal = pascalCase(name);
    return pascal[0].toLowerCase() + pascal.substring(1);
  }

  /// Maps IR type definitions to Dart types.
  ///
  /// [scoped]: If true, prefixes named types with `models.` (used in SDK).
  static String dartTypeFromIr(
    Map<String, dynamic> typeRef, {
    required bool scoped,
  }) {
    final kind = typeRef['kind'] as String;
    switch (kind) {
      case 'int32':
      case 'int64':
        return 'int';
      case 'float32':
      case 'float64':
        return 'double';
      case 'bool':
        return 'bool';
      case 'string':
        return 'String';
      case 'dateTime':
        return 'DateTime';
      case 'bytes':
        return 'Uint8List';
      case 'void':
        return 'void';
      case 'named':
        final name = pascalCase(typeRef['value'] as String);
        return scoped ? 'models.$name' : name;
      case 'list':
        final innerType = (typeRef['value'] as Map).cast<String, dynamic>();
        return 'List<${dartTypeFromIr(innerType, scoped: scoped)}>';
      case 'map':
        // 1. Cast the value to a List (as defined in your Python IR)
        final mapArgs = typeRef['value'] as List;

        // 2. Extract the Key and Value type references
        final keyTypeRef = mapArgs[0] as Map<String, dynamic>;
        final valueTypeRef = mapArgs[1] as Map<String, dynamic>;

        // 3. Recursively resolve the Dart types for both
        final keyType = dartTypeFromIr(keyTypeRef, scoped: scoped);
        final valueType = dartTypeFromIr(valueTypeRef, scoped: scoped);

        return 'Map<$keyType, $valueType>';
      case 'json':
        return 'dynamic'; // or Map<String, dynamic>
      default:
        return 'dynamic';
    }
  }

  /// Classifies the response shape to help generate the decoder lambda.
  static ResponseShape classifyResponse(Map<String, dynamic> typeRef) {
    final kind = typeRef['kind'] as String;
    final value = typeRef['value'];

    switch (kind) {
      case 'named':
        return ResponseShape(ResponseKind.model, modelName: value as String);
      case 'list':
        if (value is Map<String, dynamic>) {
          final innerKind = value['kind'] as String?;
          final innerVal = value['value'];
          if (innerKind == 'named' && innerVal is String) {
            return ResponseShape(ResponseKind.modelVec, modelName: innerVal);
          }
        }
        return ResponseShape(ResponseKind.json); // List of primitives
      case 'string':
        return ResponseShape(ResponseKind.primitiveString);
      case 'int32':
      case 'int64':
        return ResponseShape(ResponseKind.primitiveInt);
      case 'float32':
      case 'float64':
        return ResponseShape(ResponseKind.primitiveFloat);
      case 'bool':
        return ResponseShape(ResponseKind.primitiveBool);
      case 'bytes':
        return ResponseShape(ResponseKind.primitiveBytes);
      case 'dateTime':
        return ResponseShape(ResponseKind.dateTime);
      case 'void':
        return ResponseShape(ResponseKind.voidType);
      default:
        return ResponseShape(ResponseKind.json);
    }
  }
}

enum ResponseKind {
  model,
  modelVec,
  primitiveString,
  primitiveInt,
  primitiveFloat,
  primitiveBool,
  primitiveBytes,
  dateTime,
  voidType,
  json,
}

class ResponseShape {
  final ResponseKind kind;
  final String? modelName;
  const ResponseShape(this.kind, {this.modelName});
}
