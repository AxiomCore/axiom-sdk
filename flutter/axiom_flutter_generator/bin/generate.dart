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
// In your generate.dart script

/// Main generator entry.
Future<void> _generateSdk({
  required String axiomPath,
  required String outDirRelToLib,
  required String projectRoot,
}) async {
  // 1) Decode IR from .axiom (now correctly parses JSON)
  final ir = await _loadIrFromAxiom(axiomPath);
  final serviceName = (ir['serviceName'] as String?) ?? '';
  final outDir = _normalizeOutDir(outDirRelToLib);
  final packageName = _readPubspecName(projectRoot);
  final libOutDir = Directory('$projectRoot/lib/$outDir');
  if (!libOutDir.existsSync()) {
    libOutDir.createSync(recursive: true);
  }

  // Extract the filename to be used in the generated code
  final axiomFilename = axiomPath.split(Platform.pathSeparator).last;

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

  // --- CORRECTED SDK CLASS HEADER ---
  buffer.writeln('class AxiomSdk {');
  buffer.writeln('  final AxiomRuntime _runtime;');
  buffer.writeln();
  buffer.writeln('  AxiomSdk._(this._runtime);');
  buffer.writeln();
  buffer.writeln(
    '  static Future<AxiomSdk> create({required String baseUrl}) async {',
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
  buffer.writeln('    final runtime = AxiomRuntime();');
  buffer.writeln('    await runtime.init();');
  buffer.writeln('    runtime.initialize(baseUrl);');
  buffer.writeln('    runtime.loadContract(contractBytes);');
  buffer.writeln('    return AxiomSdk._(runtime);');
  buffer.writeln('  }');
  buffer.writeln();

  // Endpoints
  final endpoints = (ir['endpoints'] as List?) ?? const [];
  for (final ep in endpoints) {
    if (ep is Map<String, dynamic>) {
      _writeEndpointMethod(
        buffer,
        ep,
        ir,
        (ir['models'] as Map).cast<String, dynamic>(),
      );
      buffer.writeln();
    }
  }

  buffer.writeln('}');
  sdkFile.writeAsStringSync(buffer.toString());
  stdout.writeln('✅ Successfully wrote ${sdkFile.path}');
}

/// -------------------------------
/// .axiom decoding helpers
/// -------------------------------
const _obfuscationKey = 'AxiomCoreSecretKey2025!';

Uint8List _xorCipher(Uint8List data) {
  final key = utf8.encode(_obfuscationKey);
  final result = Uint8List(data.length);
  for (var i = 0; i < data.length; i++) {
    result[i] = data[i] ^ key[i % key.length];
  }
  return result;
}

Future<Map<String, dynamic>> _loadIrFromAxiom(String axiomPath) async {
  final file = File(axiomPath);
  if (!file.existsSync()) {
    throw Exception('Axiom file not found: $axiomPath');
  }

  // 1. Read File Bytes
  final fileBytes = await file.readAsBytes();

  // 2. Decrypt Outer Layer (XOR)
  // This reveals the JSON Envelope string
  final envelopeBytes = _xorCipher(fileBytes);

  // 3. Parse JSON Envelope
  // Using explicit JSON decoding to handle potential trailing garbage if needed,
  // but standard jsonDecode usually handles trailing whitespace/nulls poorly if they aren't whitespace.
  // Given your rust code handles stream deserialization, the dart code might need to be robust.
  // For now, let's assume the file is clean.
  final envelopeJsonStr = utf8
      .decode(envelopeBytes, allowMalformed: true)
      .trim();

  // Find the last '}' to strip any trailing garbage from the XOR process if the file size wasn't exact?
  // Actually, your Rust XOR preserves length exactly. If there's garbage it was there before.
  // Let's try direct decode first.

  Map<String, dynamic> envelope;
  try {
    envelope = jsonDecode(envelopeJsonStr);
  } catch (e) {
    // Fallback: try to find the JSON object boundaries if there is garbage
    final start = envelopeJsonStr.indexOf('{');
    final end = envelopeJsonStr.lastIndexOf('}');
    if (start != -1 && end != -1) {
      envelope = jsonDecode(envelopeJsonStr.substring(start, end + 1));
    } else {
      throw e;
    }
  }

  final payloadBase64 = envelope['payload'] as String;
  // We can ignore the signature here for IR extraction purposes,
  // as the runtime will verify it securely.

  // 4. Decode Base64 (Inner Layer)
  final innerObfuscated = base64Decode(payloadBase64);

  // 5. De-obfuscate Inner Payload (XOR)
  final plainBytes = _xorCipher(innerObfuscated);

  // 6. Parse the Actual Contract
  final plainJsonStr = utf8.decode(plainBytes);
  final axiomFile = jsonDecode(plainJsonStr);

  if (axiomFile is! Map<String, dynamic>) {
    throw Exception('Decrypted payload did not decode to a valid JSON object');
  }

  // 7. Extract IR
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
  Map<String, dynamic> allModels,
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
    final dartType = _dartModelTypeForTypeRef(typeRef, allModels);
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

  buffer.writeln('  /// Endpoint "$rawName"');
  buffer.writeln('  /// Path: $pathTemplate');
  buffer.writeln('  /// IR endpoint id: $epId');
  buffer.writeln('  Future<$dartReturnType> $fnName($paramsString) async {');

  buffer.writeln("    // 1. Build the path string");
  buffer.writeln("    var path = '$pathTemplate';");
  for (final p in paramInfos) {
    if (p['source'] == 'path') {
      final camelName = p['camelName'];
      buffer.writeln(
        "    path = path.replaceAll('{${p['origName']}}', $camelName.toString());",
      );
    }
  }

  buffer.writeln("\n    // 2. Build the request body (if any)");
  final reqType = '${_pascalCase(rawName)}RequestObjectBuilder';
  buffer.writeln('    final requestBytes = schema.$reqType(');

  for (final p in paramInfos) {
    // --- THIS IS THE FIX ---
    // Correctly check for `source` and only include body/query params
    if (p['source'] != 'path') {
      final camel = p['camelName'];
      final t = p['typeRef'] as Map<String, dynamic>;
      final kind = t['kind'] as String;
      final builderParamName = _camelCase(p['origName']);

      if (kind == 'named') {
        final modelName = _pascalCase(t['value']);
        final obName = 'schema.${modelName}ObjectBuilder';
        buffer.writeln('      $builderParamName: $obName(');
        final modelDef = allModels[t['value']] as Map<String, dynamic>;
        final fields = (modelDef['fields'] as List);
        for (final f in fields) {
          final fieldName = f['name'];
          final builderFieldName = _camelCase(fieldName);
          final modelFieldName = _camelCase(fieldName);
          buffer.writeln('        $builderFieldName: $camel.$modelFieldName,');
        }
        buffer.writeln('      ),');
      } else {
        buffer.writeln('      $builderParamName: $camel,');
      }
    }
  }
  buffer.writeln('    ).toBytes();');
  buffer.writeln("\n    // 3. Call the runtime");

  if (responseShape.kind == _ResponseKind.voidType) {
    buffer.writeln(
      '    await _runtime.call(endpointId: $epId, method: "$method", path: path, requestBytes: requestBytes);',
    );
    buffer.writeln('    return;');
  } else {
    buffer.writeln(
      '    final responseBytes = await _runtime.call(endpointId: $epId, method: "$method", path: path, requestBytes: requestBytes);',
    );
  }

  buffer.writeln('    if (responseBytes.isEmpty) {');
  if (returnIsOptional) {
    buffer.writeln('      return null;');
  } else if (dartReturnType == 'void') {
    buffer.writeln('      return;');
  } else {
    buffer.writeln(
      '      throw StateError("Received empty response for a non-nullable return type.");',
    );
  }
  buffer.writeln('    }');
  buffer.writeln();
  buffer.writeln(
    '    final jsonObject = jsonDecode(utf8.decode(responseBytes));',
  );

  switch (responseShape.kind) {
    case _ResponseKind.model:
      final modelName = _pascalCase(responseShape.modelName!);
      buffer.writeln('    return models.$modelName.fromJson(jsonObject);');
      break;
    case _ResponseKind.modelVec:
      final modelName = _pascalCase(responseShape.modelName!);
      buffer.writeln(
        '    return (jsonObject as List<dynamic>).map((e) => models.$modelName.fromJson(e)).toList();',
      );
      break;
    case _ResponseKind.primitiveString:
    case _ResponseKind.primitiveInt:
    case _ResponseKind.primitiveFloat:
    case _ResponseKind.primitiveBool:
      buffer.writeln('    return jsonObject as $dartReturnType;');
      break;
    case _ResponseKind.primitiveBytes:
      buffer.writeln('    return base64Decode(jsonObject as String);');
      break;
    case _ResponseKind.voidType:
      buffer.writeln('    return;');
      break;
    default: // json
      buffer.writeln('    return jsonObject;');
      break;
  }
  buffer.writeln('  }');
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

  final models = (ir['models'] as Map?)?.cast<String, dynamic>() ?? {};

  for (final modelDef in models.values) {
    if (modelDef is! Map<String, dynamic>) continue;

    final modelName = _pascalCase(modelDef['name']);
    buffer.writeln('class $modelName {');

    final fields = (modelDef['fields'] as List?) ?? [];

    // Generate final properties
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final fieldName = _camelCase(field['name']);
      final typeRef = (field['typeRef'] as Map).cast<String, dynamic>();
      final isOptional = field['isOptional'] as bool? ?? true;
      String dartType = _dartModelTypeForTypeRef(
        typeRef,
        models,
      ); // Use a new type mapper
      if (isOptional) dartType += '?';

      buffer.writeln('  final $dartType $fieldName;');
    }
    buffer.writeln();

    // Generate the constructor
    buffer.writeln('  const $modelName({');
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final fieldName = _camelCase(field['name']);
      final isOptional = field['isOptional'] as bool? ?? true;
      if (!isOptional) {
        buffer.writeln('    required this.$fieldName,');
      } else {
        buffer.writeln('    this.$fieldName,');
      }
    }
    buffer.writeln('  });');
    buffer.writeln();

    // Generate a `fromSchema` factory constructor
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
      final bang = isOptional ? '' : '!'; // <-- FIX #1 HERE

      // Handle nested models and lists of models
      if (kind == 'named') {
        final nestedModelName = _pascalCase(typeRef['value']);
        if (isOptional) {
          buffer.writeln(
            '      $camelName: schemaModel.$camelName != null ? models.$nestedModelName.fromSchema(schemaModel.$camelName!) : null,',
          );
        } else {
          buffer.writeln(
            '      $camelName: models.$nestedModelName.fromSchema(schemaModel.$camelName!),',
          );
        }
      } else if (kind == 'list' &&
          (typeRef['value'] as Map)['kind'] == 'named') {
        final innerModelName = _pascalCase((typeRef['value'] as Map)['value']);
        if (isOptional) {
          buffer.writeln(
            '      $camelName: schemaModel.$camelName?.map((e) => models.$innerModelName.fromSchema(e)).toList(),',
          );
        } else {
          buffer.writeln(
            '      $camelName: schemaModel.$camelName!.map((e) => models.$innerModelName.fromSchema(e)).toList(),',
          );
        }
      } else {
        buffer.writeln('      $camelName: schemaModel.$camelName$bang,');
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer.writeln(
      '  factory $modelName.fromJson(Map<String, dynamic> json) {',
    );
    buffer.writeln('    return $modelName(');
    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;
      final origName = field['name'] as String; // The key in the JSON
      final camelName = _camelCase(
        origName,
      ); // The property name in the Dart class
      final typeRef = (field['typeRef'] as Map).cast<String, dynamic>();
      final kind = typeRef['kind'] as String;

      String parsingLogic;
      if (kind == 'named') {
        final nestedModelName = _pascalCase(typeRef['value']);
        parsingLogic =
            'json[\'$origName\'] != null ? models.$nestedModelName.fromJson(json[\'$origName\']) : null';
      } else if (kind == 'list' &&
          (typeRef['value'] as Map)['kind'] == 'named') {
        final innerModelName = _pascalCase((typeRef['value'] as Map)['value']);
        parsingLogic =
            '(json[\'$origName\'] as List<dynamic>?)?.map((e) => models.$innerModelName.fromJson(e)).toList()';
      } else {
        parsingLogic = 'json[\'$origName\']';
      }
      buffer.writeln('      $camelName: $parsingLogic,');
    }
    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer.writeln('}');
    buffer.writeln();
  }
}

// Add this new type mapper for the model layer
String _dartModelTypeForTypeRef(
  Map<String, dynamic> t,
  Map<String, dynamic> allModels,
) {
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
      // This is the key change: prefix with 'models.'
      return 'models.${_pascalCase(t['value'] as String)}';
    case 'list':
      final innerType = (t['value'] as Map).cast<String, dynamic>();
      // Recursively call to handle nested types like List<models.User>
      return 'List<${_dartModelTypeForTypeRef(innerType, allModels)}>';
    case 'json':
      return 'Map<String, dynamic>';
    case 'map':
      // Simplified for now, as complex map keys/values are often handled as JSON.
      return 'Map<String, dynamic>';
    case 'void':
      return 'void';
    default:
      return 'dynamic';
  }
}
