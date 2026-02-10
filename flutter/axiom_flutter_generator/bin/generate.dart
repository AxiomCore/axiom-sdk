#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

/// For classifying endpoint return shapes.
enum _ResponseKind {
  model,
  modelVec,
  primitiveString,
  primitiveInt,
  primitiveFloat,
  primitiveBool,
  primitiveBytes,
  voidType,
  json,
}

class _ResponseShape {
  final _ResponseKind kind;
  final String? modelName;
  const _ResponseShape(this.kind, [this.modelName]);

  factory _ResponseShape.model(String model) =>
      _ResponseShape(_ResponseKind.model, model);
  factory _ResponseShape.modelVec(String model) =>
      _ResponseShape(_ResponseKind.modelVec, model);
  factory _ResponseShape.primitiveString() =>
      const _ResponseShape(_ResponseKind.primitiveString);
  factory _ResponseShape.primitiveInt() =>
      const _ResponseShape(_ResponseKind.primitiveInt);
  factory _ResponseShape.primitiveFloat() =>
      const _ResponseShape(_ResponseKind.primitiveFloat);
  factory _ResponseShape.primitiveBool() =>
      const _ResponseShape(_ResponseKind.primitiveBool);
  factory _ResponseShape.primitiveBytes() =>
      const _ResponseShape(_ResponseKind.primitiveBytes);
  factory _ResponseShape.voidType() =>
      const _ResponseShape(_ResponseKind.voidType);
  factory _ResponseShape.json() => const _ResponseShape(_ResponseKind.json);
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('axiom', help: 'Path to the .axiom file')
    ..addOption(
      'out',
      help: 'Output path relative to lib/ where axiom_sdk.dart will be written',
    )
    ..addOption(
      'project-root',
      help: 'Path to the Flutter project root containing pubspec.yaml',
    )
    ..addFlag('help', negatable: false);

  final results = parser.parse(args);

  if (results['help'] == true) {
    print(parser.usage);
    exit(0);
  }

  final axiomPath = results['axiom'] as String?;
  final outDir = results['out'] as String?;
  final projectRoot = results['project-root'] as String?;

  if (axiomPath == null || outDir == null || projectRoot == null) {
    stderr.writeln(
      '❌ Missing required arguments. You must provide --axiom, --out and --project-root.',
    );
    stderr.writeln(parser.usage);
    exit(1);
  }

  try {
    await _generateSdk(
      axiomPath: axiomPath,
      outDirRelToLib: outDir,
      projectRoot: projectRoot,
    );
  } catch (e, st) {
    stderr.writeln('❌ Failed to generate Axiom SDK: $e');
    stderr.writeln(st);
    exit(1);
  }
}

/// Main generator entry.
Future<void> _generateSdk({
  required String axiomPath,
  required String outDirRelToLib,
  required String projectRoot,
}) async {
  // 1) Decode IR from .axiom
  final ir = await _loadIrFromAxiom(axiomPath);

  final serviceName = (ir['serviceName'] as String?) ?? '';

  // 2) Compute normalized output dir (relative to lib/)
  final outDir = _normalizeOutDir(outDirRelToLib);

  // 3) Determine Dart package name from pubspec.yaml
  final packageName = _readPubspecName(projectRoot);

  // 4) Prepare output directory under lib/
  final libOutDir = Directory('$projectRoot/lib/$outDir');
  if (!libOutDir.existsSync()) {
    libOutDir.createSync(recursive: true);
  }

  // Extract the filename to be used in the generated code
  final axiomFilename = axiomPath.split(Platform.pathSeparator).last;

  // --- Read .trust-axiom.json ---
  String? signature;
  String? publicKey;
  final trustFile = File('$projectRoot/.trust-axiom.json');
  if (trustFile.existsSync()) {
    try {
      final content = trustFile.readAsStringSync();
      final trustJson = jsonDecode(content) as Map<String, dynamic>;
      signature = trustJson['signature'] as String?;
      publicKey = trustJson['public_key'] as String?;
      if (signature != null) {
        stdout.writeln('🔐 Found signature in .trust-axiom.json');
      }
    } catch (e) {
      stderr.writeln('⚠️ Warning: Failed to read .trust-axiom.json: $e');
    }
  }

  // --- Generate models.dart ---
  final modelsFile = File('${libOutDir.path}/models.dart');
  final modelsBuffer = StringBuffer();
  _writeModelsFile(modelsBuffer, ir, packageName, outDir);
  modelsFile.writeAsStringSync(modelsBuffer.toString());
  stdout.writeln('✅ Successfully wrote ${modelsFile.path}');

  // --- Generate axiom_sdk.dart ---
  final sdkFile = File('${libOutDir.path}/axiom_sdk.dart');
  final buffer = StringBuffer();

  buffer.writeln('// GENERATED CODE – DO NOT EDIT.');
  buffer.writeln('// Axiom SDK for $serviceName');
  buffer.writeln();

  buffer.writeln("import 'dart:convert';");
  buffer.writeln("import 'dart:typed_data';");
  buffer.writeln("import 'package:flutter/services.dart' show rootBundle;");
  buffer.writeln(
    "import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;",
  );
  buffer.writeln("import 'package:axiom_flutter/axiom_flutter.dart';");

  final schemaImportPath = outDir.isEmpty
      ? 'schema_axiom_generated.dart'
      : '$outDir/schema_axiom_generated.dart';
  final modelsImportPath = outDir.isEmpty
      ? 'models.dart'
      : '$outDir/models.dart';

  buffer.writeln("import 'package:$packageName/$schemaImportPath' as schema;");
  buffer.writeln("import 'package:$packageName/$modelsImportPath' as models;");
  buffer.writeln();

  // Class header
  buffer.writeln('class AxiomSdk {');
  buffer.writeln('  final AxiomRuntime _runtime;');
  buffer.writeln();
  buffer.writeln('  // Private constructor to ensure proper initialization.');
  buffer.writeln('  AxiomSdk._(this._runtime);');
  buffer.writeln();
  buffer.writeln('  /// Asynchronously creates and initializes the Axiom SDK.');
  buffer.writeln(
    '  static Future<AxiomSdk> create({required String baseUrl, String? dbPath}) async {',
  );
  buffer.writeln(
    '    // Ensure Flutter bindings are initialized for asset loading.',
  );
  buffer.writeln('    WidgetsFlutterBinding.ensureInitialized();');
  buffer.writeln();
  buffer.writeln(
    "    final contractData = await rootBundle.load('$axiomFilename');",
  );
  buffer.writeln(
    '    final contractBytes = contractData.buffer.asUint8List();',
  );
  buffer.writeln();
  buffer.writeln('    // Get the singleton instance of the runtime.');
  buffer.writeln('    final runtime = AxiomRuntime();');
  buffer.writeln('    // Ensure the background isolate is running and ready.');
  buffer.writeln('    await runtime.init();');
  buffer.writeln('    // Start the runtime with the contract and base URL.');

  if (signature != null) {
    buffer.writeln("    const String? _signature = '$signature';");
  } else {
    buffer.writeln("    const String? _signature = null;");
  }

  if (publicKey != null) {
    buffer.writeln("    const String? _publicKey = '$publicKey';");
  } else {
    buffer.writeln("    const String? _publicKey = null;");
  }

  buffer.writeln(
    '    await runtime.startup(baseUrl: baseUrl, contractBytes: contractBytes, dbPath: dbPath, signature: _signature, publicKey: _publicKey);',
  );
  buffer.writeln('    // Return the fully initialized SDK.');
  buffer.writeln('    return AxiomSdk._(runtime);');
  buffer.writeln('  }');
  buffer.writeln();

  // 7) Endpoints
  final endpoints = (ir['endpoints'] as List?) ?? const [];
  for (final ep in endpoints) {
    if (ep is Map<String, dynamic>) {
      _writeEndpointMethod(buffer, ep, ir);
      buffer.writeln();
    }
  }

  buffer.writeln('}');

  // 8) Write axiom_sdk.dart
  sdkFile.writeAsStringSync(buffer.toString());
  stdout.writeln('✅ Successfully wrote ${sdkFile.path}');
}

/// -------------------------------
/// .axiom decoding helpers
/// -------------------------------
Future<Map<String, dynamic>> _loadIrFromAxiom(String axiomPath) async {
  final file = File(axiomPath);
  if (!file.existsSync()) {
    throw Exception('Axiom file not found: $axiomPath');
  }

  // 1. Read File Content
  final content = await file.readAsString();

  // 2. Parse the Actual Contract
  final axiomFile = jsonDecode(content);

  if (axiomFile is! Map<String, dynamic>) {
    throw Exception('Axiom file did not decode to a valid JSON object');
  }

  // 3. Extract IR
  final ir = axiomFile['ir'];
  if (ir is! Map<String, dynamic>) {
    throw Exception('IR object not found or invalid within the .axiom file');
  }

  return ir;
}

/// -------------------------------
/// Pubspec / path helpers
/// -------------------------------

String _readPubspecName(String projectRoot) {
  final pubspec = File('$projectRoot/pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw Exception('pubspec.yaml not found at $projectRoot/pubspec.yaml');
  }
  final content = pubspec.readAsStringSync();
  final doc = loadYaml(content);
  final name = (doc as YamlMap?)?['name'];
  if (name is! String) {
    throw Exception('Could not find a valid "name" in pubspec.yaml');
  }
  return name.trim();
}

/// Normalize output dir (strip leading/trailing slashes, optional "lib/")
String _normalizeOutDir(String outDir) {
  var d = outDir.trim();
  if (d.startsWith('lib/')) {
    d = d.substring(4);
  }
  d = d.replaceAll(RegExp(r'^/+'), '');
  d = d.replaceAll(RegExp(r'/+$'), '');
  return d;
}

/// -------------------------------
/// Naming helpers
/// -------------------------------

String _pascalCase(String name) {
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

String _camelCase(String name) {
  if (name.isEmpty) return name;
  final pascal = _pascalCase(name);
  return pascal[0].toLowerCase() + pascal.substring(1);
}

/// -------------------------------
/// Type & endpoint helpers
/// -------------------------------

_ResponseShape _classifyDartReturnType(Map<String, dynamic> t) {
  final kind = t['kind'] as String;
  final value = t['value'];

  switch (kind) {
    case 'named':
      return _ResponseShape.model(value as String);
    case 'list':
      if (value is Map<String, dynamic>) {
        final innerKind = value['kind'] as String?;
        final innerVal = value['value'];
        if (innerKind == 'named' && innerVal is String) {
          return _ResponseShape.modelVec(innerVal);
        }
      }
      return _ResponseShape.json();
    case 'string':
    case 'dateTime':
      return _ResponseShape.primitiveString();
    case 'int32':
    case 'int64':
      return _ResponseShape.primitiveInt();
    case 'float32':
    case 'float64':
      return _ResponseShape.primitiveFloat();
    case 'bool':
      return _ResponseShape.primitiveBool();
    case 'bytes':
      return _ResponseShape.primitiveBytes();
    case 'void':
      return _ResponseShape.voidType();
    default:
      return _ResponseShape.json();
  }
}

void _writeEndpointMethod(
  StringBuffer buffer,
  Map<String, dynamic> ep,
  Map<String, dynamic> ir,
) {
  final rawName = ep['name'] as String? ?? 'endpoint';
  final fnName = _camelCase(rawName);
  final epId = ep['id'] ?? 0;
  final pathTemplate = ep['path'] as String? ?? '';
  final method = ep['method'] as String? ?? 'GET';
  final returnTypeRef = (ep['returnType'] as Map).cast<String, dynamic>();
  final returnIsOptional = ep['returnIsOptional'] as bool? ?? false;
  final responseShape = _classifyDartReturnType(returnTypeRef);

  final params = (ep['parameters'] as List?) ?? const [];
  final paramDecls = <String>[];
  final paramInfos = <Map<String, dynamic>>[];

  for (final p in params) {
    if (p is! Map) continue;
    final param = p.cast<String, dynamic>();
    final name = param['name'] as String? ?? 'arg';
    final camelName = _camelCase(name);
    final typeRef = (param['typeRef'] as Map).cast<String, dynamic>();

    // In SDK endpoints, we use scoped types (models.Type)
    final dartType = _dartModelTypeForTypeRef(typeRef, scoped: true);
    final isOptional = param['isOptional'] as bool? ?? false;

    paramDecls.add(
      isOptional ? '$dartType? $camelName' : 'required $dartType $camelName',
    );

    paramInfos.add({
      'origName': name,
      'camelName': camelName,
      'typeRef': typeRef,
      'isOptional': isOptional,
      'source': param['source'] as String?,
    });
  }

  String dartReturnType;
  switch (responseShape.kind) {
    case _ResponseKind.model:
      dartReturnType = 'models.${_pascalCase(responseShape.modelName!)}';
      break;
    case _ResponseKind.modelVec:
      dartReturnType = 'List<models.${_pascalCase(responseShape.modelName!)}>';
      break;
    case _ResponseKind.primitiveString:
      dartReturnType = 'String';
      break;
    case _ResponseKind.primitiveInt:
      dartReturnType = 'int';
      break;
    case _ResponseKind.primitiveFloat:
      dartReturnType = 'double';
      break;
    case _ResponseKind.primitiveBool:
      dartReturnType = 'bool';
      break;
    case _ResponseKind.primitiveBytes:
      dartReturnType = 'Uint8List';
      break;
    case _ResponseKind.voidType:
      dartReturnType = 'void';
      break;
    default:
      dartReturnType = 'dynamic';
  }

  if (returnIsOptional && responseShape.kind != _ResponseKind.voidType) {
    dartReturnType += '?';
  }

  final paramsString = paramDecls.isEmpty ? '' : '{${paramDecls.join(', ')}}';

  buffer.writeln('  /// Endpoint "$rawName" (Stream)');
  buffer.writeln('  /// Path: $pathTemplate');
  buffer.writeln('  /// IR endpoint id: $epId');
  buffer.writeln('  AxiomQuery<$dartReturnType>  $fnName($paramsString) {');

  buffer.writeln('    final queryArgs = <String, dynamic>{');
  for (final p in paramInfos) {
    final name = p['camelName'];
    if (p['typeRef']['kind'] == 'named') {
      // Models and Enums must have toJson
      if (p['isOptional']) {
        buffer.writeln("      '${p['origName']}': $name?.toJson(),");
      } else {
        buffer.writeln("      '${p['origName']}': $name.toJson(),");
      }
    } else {
      buffer.writeln("      '${p['origName']}': $name,");
    }
  }
  buffer.writeln('    };');
  buffer.writeln("    final queryKey = '$rawName:\${jsonEncode(queryArgs)}';");

  buffer.writeln(
    '    final stream = AxiomQueryManager().watch<$dartReturnType>(queryKey, () {',
  );

  buffer.writeln("    var path = '$pathTemplate';");
  for (final p in paramInfos) {
    if (p['source'] == 'path') {
      final camelName = p['camelName'];
      buffer.writeln(
        "    path = path.replaceAll('{${p['origName']}}', $camelName.toString());",
      );
    }
  }

  bool hasBody = false;
  List<String> bodyEntries = [];
  for (final p in paramInfos) {
    if (p['source'] == 'body') {
      hasBody = true;
      bodyEntries.add(p['camelName']);
    }
  }

  if (bodyEntries.isNotEmpty) {
    final bodyVar = bodyEntries.first;
    buffer.writeln(
      "    final requestBytes = Uint8List.fromList(utf8.encode(jsonEncode($bodyVar)));",
    );
  } else {
    buffer.writeln("    final requestBytes = Uint8List(0);");
  }

  buffer.writeln(
    "    final rawStream = _runtime.callStream(endpointId: $epId, method: \"$method\", path: path, requestBytes: requestBytes);",
  );

  buffer.writeln("    return rawStream.map((state) {");
  buffer.writeln("       return state.map((bytes) {");

  if (responseShape.kind == _ResponseKind.voidType) {
    buffer.writeln("         return null;");
  } else {
    buffer.writeln(
      "         final jsonObject = jsonDecode(utf8.decode(bytes));",
    );

    switch (responseShape.kind) {
      case _ResponseKind.model:
        final modelName = _pascalCase(responseShape.modelName!);
        buffer.writeln(
          '         return models.$modelName.fromJson(jsonObject);',
        );
        break;
      case _ResponseKind.modelVec:
        final modelName = _pascalCase(responseShape.modelName!);
        buffer.writeln(
          '         return (jsonObject as List<dynamic>).map((e) => models.$modelName.fromJson(e)).toList();',
        );
        break;
      case _ResponseKind.primitiveString:
      case _ResponseKind.primitiveInt:
      case _ResponseKind.primitiveFloat:
      case _ResponseKind.primitiveBool:
        buffer.writeln('         return jsonObject as $dartReturnType;');
        break;
      case _ResponseKind.primitiveBytes:
        buffer.writeln('         return base64Decode(jsonObject as String);');
        break;
      default:
        buffer.writeln('         return jsonObject;');
    }
  }
  buffer.writeln("       });");
  buffer.writeln("    });");
  buffer.writeln('    });');
  buffer.writeln("    return AxiomQuery(queryKey, stream);");
  buffer.writeln('  }');
  buffer.writeln();
}

void _writeModelsFile(
  StringBuffer buffer,
  Map<String, dynamic> ir,
  String packageName,
  String outDir,
) {
  buffer.writeln('// GENERATED CODE – DO NOT EDIT.');
  buffer.writeln('// User-facing data models.');
  buffer.writeln();

  final schemaImportPath = outDir.isEmpty
      ? 'schema_axiom_generated.dart'
      : '$outDir/schema_axiom_generated.dart';
  buffer.writeln("import 'package:$packageName/$schemaImportPath' as schema;");
  buffer.writeln();

  final enums = (ir['enums'] as Map?)?.cast<String, dynamic>() ?? {};
  final models = (ir['models'] as Map?)?.cast<String, dynamic>() ?? {};

  // ---------------------------------------------------------
  // 1. Generate Enums
  // ---------------------------------------------------------
  for (final enumDef in enums.values) {
    if (enumDef is! Map<String, dynamic>) continue;
    final enumName = _pascalCase(enumDef['name']);
    final values = (enumDef['values'] as List?)?.cast<String>() ?? [];

    buffer.writeln('enum $enumName {');
    for (var i = 0; i < values.length; i++) {
      final val = values[i];
      final isLast = i == values.length - 1;
      buffer.writeln('  $val${isLast ? ';' : ','}');
    }
    buffer.writeln();

    // toJson
    buffer.writeln('  String toJson() => name;');
    buffer.writeln();

    // fromJson
    buffer.writeln('  static $enumName fromJson(dynamic value) {');
    buffer.writeln('    if (value is String) {');
    buffer.writeln('      return $enumName.values.firstWhere(');
    buffer.writeln('        (e) => e.name == value,');
    buffer.writeln(
      '        orElse: () => throw Exception(\'Unknown $enumName value: \$value\'),',
    );
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln(
      '    throw Exception(\'Expected String for $enumName, got \$value\');',
    );
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('}');
    buffer.writeln();
  }

  // ---------------------------------------------------------
  // 2. Generate Models
  // ---------------------------------------------------------
  for (final modelDef in models.values) {
    if (modelDef is! Map<String, dynamic>) continue;

    final modelName = _pascalCase(modelDef['name']);
    buffer.writeln('class $modelName {');

    final fields = (modelDef['fields'] as List?) ?? [];

    // Properties
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final fieldName = _camelCase(field['name']);
      final typeRef = (field['typeRef'] as Map).cast<String, dynamic>();
      final isOptional = field['isOptional'] as bool? ?? false;

      String dartType = _dartModelTypeForTypeRef(typeRef, scoped: false);
      if (isOptional) dartType += '?';

      buffer.writeln('  final $dartType $fieldName;');
    }
    buffer.writeln();

    // Constructor
    buffer.writeln('  const $modelName({');
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final fieldName = _camelCase(field['name']);
      final isOptional = field['isOptional'] as bool? ?? false;
      if (!isOptional) {
        buffer.writeln('    required this.$fieldName,');
      } else {
        buffer.writeln('    this.$fieldName,');
      }
    }
    buffer.writeln('  });');
    buffer.writeln();

    // fromSchema
    buffer.writeln(
      '  factory $modelName.fromSchema(schema.$modelName schemaModel) {',
    );
    buffer.writeln('    return $modelName(');
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final origName = field['name'];
      final camelName = _camelCase(origName);
      final typeRef = (field['typeRef'] as Map).cast<String, dynamic>();
      final kind = typeRef['kind'] as String;
      final isOptional = field['isOptional'] as bool? ?? false;
      final bang = isOptional ? '' : '!';

      if (kind == 'named') {
        final rawTypeName = typeRef['value'] as String;
        final typeName = _pascalCase(rawTypeName);
        final isEnum = enums.containsKey(rawTypeName);

        if (isEnum) {
          if (isOptional) {
            buffer.writeln(
              '      $camelName: schemaModel.$camelName != null ? $typeName.fromJson(schemaModel.$camelName!) : null,',
            );
          } else {
            buffer.writeln(
              '      $camelName: $typeName.fromJson(schemaModel.$camelName!),',
            );
          }
        } else {
          if (isOptional) {
            buffer.writeln(
              '      $camelName: schemaModel.$camelName != null ? $typeName.fromSchema(schemaModel.$camelName!) : null,',
            );
          } else {
            buffer.writeln(
              '      $camelName: $typeName.fromSchema(schemaModel.$camelName!),',
            );
          }
        }
      } else if (kind == 'list' &&
          (typeRef['value'] as Map)['kind'] == 'named') {
        final rawInnerType = (typeRef['value'] as Map)['value'] as String;
        final innerType = _pascalCase(rawInnerType);
        final isEnum = enums.containsKey(rawInnerType);
        final method = isEnum ? 'fromJson' : 'fromSchema';

        if (isOptional) {
          buffer.writeln(
            '      $camelName: schemaModel.$camelName?.map((e) => $innerType.$method(e)).toList(),',
          );
        } else {
          buffer.writeln(
            '      $camelName: schemaModel.$camelName!.map((e) => $innerType.$method(e)).toList(),',
          );
        }
      } else {
        buffer.writeln('      $camelName: schemaModel.$camelName$bang,');
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');

    // fromJson
    buffer.writeln(
      '  factory $modelName.fromJson(Map<String, dynamic> json) {',
    );
    buffer.writeln('    return $modelName(');
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final origName = field['name'] as String;
      final camelName = _camelCase(origName);
      final typeRef = (field['typeRef'] as Map).cast<String, dynamic>();
      final kind = typeRef['kind'] as String;
      final isOptional = field['isOptional'] as bool? ?? false;

      String parsingLogic;
      if (kind == 'named') {
        final nestedType = _pascalCase(typeRef['value']);

        if (isOptional) {
          parsingLogic =
              'json[\'$origName\'] != null ? $nestedType.fromJson(json[\'$origName\']) : null';
        } else {
          // Required field: Do not return null.
          parsingLogic = '$nestedType.fromJson(json[\'$origName\'])';
        }
      } else if (kind == 'list' &&
          (typeRef['value'] as Map)['kind'] == 'named') {
        final innerType = _pascalCase((typeRef['value'] as Map)['value']);

        if (isOptional) {
          parsingLogic =
              '(json[\'$origName\'] as List<dynamic>?)?.map((e) => $innerType.fromJson(e)).toList()';
        } else {
          // Required List
          parsingLogic =
              '(json[\'$origName\'] as List<dynamic>).map((e) => $innerType.fromJson(e)).toList()';
        }
      } else {
        // Primitive
        parsingLogic = 'json[\'$origName\']';
      }
      buffer.writeln('      $camelName: $parsingLogic,');
    }
    buffer.writeln('    );');
    buffer.writeln('  }');

    // toJson
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final origName = field['name'] as String;
      final camelName = _camelCase(origName);
      final typeRef = (field['typeRef'] as Map).cast<String, dynamic>();
      final kind = typeRef['kind'] as String;

      if (kind == 'named') {
        buffer.writeln("      '$origName': $camelName?.toJson(),");
      } else if (kind == 'list' &&
          (typeRef['value'] as Map)['kind'] == 'named') {
        buffer.writeln(
          "      '$origName': $camelName?.map((e) => e.toJson()).toList(),",
        );
      } else {
        buffer.writeln("      '$origName': $camelName,");
      }
    }
    buffer.writeln('    };');
    buffer.writeln('  }');

    buffer.writeln('}');
    buffer.writeln();
  }
}

// Updated type mapper
String _dartModelTypeForTypeRef(
  Map<String, dynamic> t, {
  required bool scoped, // true = models.Type, false = Type
}) {
  final kind = t['kind'] as String;
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
    case 'dateTime':
      return 'String';
    case 'bytes':
      return 'Uint8List';
    case 'named':
      final name = _pascalCase(t['value'] as String);
      return scoped ? 'models.$name' : name;
    case 'list':
      final innerType = (t['value'] as Map).cast<String, dynamic>();
      return 'List<${_dartModelTypeForTypeRef(innerType, scoped: scoped)}>';
    case 'json':
      return 'Map<String, dynamic>';
    case 'map':
      return 'Map<String, dynamic>';
    case 'void':
      return 'void';
    default:
      return 'dynamic';
  }
}
