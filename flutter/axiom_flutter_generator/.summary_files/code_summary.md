Project Root: /Users/yashmakan/AxiomCore/axiom-sdk/flutter/axiom_flutter_generator
Project Structure:
```
.
|-- .gitignore
|-- CHANGELOG.md
|-- LICENSE
|-- README.md
|-- analysis_options.yaml
|-- bin
    |-- generate.dart
|-- lib
    |-- src
        |-- generator
            |-- model_writer.dart
            |-- sdk_writer.dart
            |-- utils.dart
|-- pubspec.yaml

```

---
## File: bin/generate.dart

```dart
import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:axiom_flutter_generator/src/generator/sdk_writer.dart';
import 'package:axiom_flutter_generator/src/generator/model_writer.dart';
import 'package:yaml/yaml.dart';
import 'package:toml/toml.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('config', help: 'Path to AxiomDeps.toml')
    ..addOption(
      'out',
      help: 'Output dir relative to lib/, e.g. axiom_generated',
    )
    ..addOption(
      'project-root',
      help: 'Absolute path to the Flutter project root',
    );

  final argResults = parser.parse(arguments);
  final configPath = argResults['config'] as String;
  final outDir = argResults['out'] as String;
  final projectRoot = argResults['project-root'] as String;

  // ── 1. Read pubspec → package name ────────────────────────────────────────
  final pubspecFile = File('$projectRoot/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('ERROR: pubspec.yaml not found at $projectRoot');
    exit(1);
  }
  final pubspec = loadYaml(pubspecFile.readAsStringSync());
  final packageName = pubspec['name'] as String;

  // ── 2. Parse AxiomDeps.toml ───────────────────────────────────────────────
  final tomlFile = File(configPath);
  if (!tomlFile.existsSync()) {
    stderr.writeln('ERROR: AxiomDeps.toml not found at $configPath');
    exit(1);
  }

  final tomlDoc = TomlDocument.parse(tomlFile.readAsStringSync()).toMap();
  final framework = tomlDoc['framework'] as String? ?? 'flutter';

  final contractsNode = tomlDoc['contracts'] as Map<String, dynamic>?;
  if (contractsNode == null || contractsNode.isEmpty) {
    stderr.writeln('ERROR: No [contracts] found in AxiomDeps.toml');
    exit(1);
  }

  // ── 3. Load each contract's .axiom file ───────────────────────────────────
  //
  // AxiomDeps.toml contract entries:
  //
  //   [contracts.my-api]
  //   source   = "/original/path/.axiom"     # the path the user provided
  //   base_url = "http://localhost:8000"      # optional, defaults below
  //
  // The installed copy always lives at:
  //   ~/.axiom/contracts/<name>/contract.axiom
  //
  // We prefer the installed copy (stable) and fall back to source if for
  // some reason the install dir is missing (e.g. running generator directly).

  final isSingle = contractsNode.length == 1;

  final Map<String, dynamic> contractsData = {};
  final Map<String, String> baseUrls = {};
  final Map<String, String> assetPaths = {};

  for (final entry in contractsNode.entries) {
    final name = entry.key;
    final meta = entry.value as Map<String, dynamic>;
    final sourceStr = meta['source'] as String?;
    final baseUrl = meta['base_url'] as String? ?? 'http://localhost:8000';

    // Resolve installed path
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final installedPath = '$home/.axiom/contracts/$name/contract.axiom';
    final installedFile = File(installedPath);

    final String resolvedPath;
    if (installedFile.existsSync()) {
      resolvedPath = installedPath;
    } else if (sourceStr != null && File(sourceStr).existsSync()) {
      stderr.writeln(
        'WARNING: installed copy not found for "$name", falling back to source: $sourceStr',
      );
      resolvedPath = sourceStr;
    } else {
      stderr.writeln(
        'ERROR: contract "$name" not found.\n'
        '  Tried installed: $installedPath\n'
        '  Tried source:    ${sourceStr ?? "(none)"}\n'
        '  Run: axiom pull',
      );
      exit(1);
    }

    final fileStr = File(resolvedPath).readAsStringSync();
    final parsedData = jsonDecode(fileStr) as Map<String, dynamic>;

    // ── NORMALIZE IR ────────────────────────────────────────────────────────
    // Recent versions of the Acore compiler output `endpoints` and `fields` as HashMaps
    // instead of Lists. We safely normalize them back to Lists here for the SDK/Model writers.
    final ir = parsedData['ir'];
    if (ir is Map<String, dynamic>) {
      if (ir['endpoints'] is Map) {
        ir['endpoints'] = (ir['endpoints'] as Map).values.toList();
      }

      if (ir['models'] is Map) {
        for (final model in (ir['models'] as Map).values) {
          if (model is Map && model['fields'] is Map) {
            model['fields'] = (model['fields'] as Map).values.toList();
          }
        }
      }

      if (ir['enums'] is Map) {
        for (final enumDef in (ir['enums'] as Map).values) {
          if (enumDef is Map && enumDef['variants'] is Map) {
            enumDef['variants'] = (enumDef['variants'] as Map).values.toList();
          }
        }
      }
    }

    contractsData[name] = parsedData;
    baseUrls[name] = baseUrl;
    assetPaths[name] = 'assets/axiom/$name.axiom'; // Flutter asset path
  }

  // ── 4. Write axiom_sdk.dart ───────────────────────────────────────────────
  final sdkWriter = SdkWriter(
    contracts: contractsData,
    baseUrls: baseUrls,
    assetPaths: assetPaths,
    isSingle: isSingle,
    packageName: packageName,
    modelsImportPath: '$outDir/models.dart',
  );

  final sdkOutPath = '$projectRoot/lib/$outDir/axiom_sdk.dart';
  File(sdkOutPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(sdkWriter.write());
  stdout.writeln('  → wrote $sdkOutPath');

  // ── 5. Merge IRs & write models.dart ─────────────────────────────────────
  final mergedIr = <String, dynamic>{
    'models': <String, dynamic>{},
    'enums': <String, dynamic>{},
  };

  for (final def in contractsData.values) {
    final ir = def['ir'] ?? def;
    if (ir['models'] != null) {
      (mergedIr['models'] as Map).addAll(ir['models'] as Map);
    }
    if (ir['enums'] != null) {
      (mergedIr['enums'] as Map).addAll(ir['enums'] as Map);
    }
  }

  final modelWriter = ModelWriter(mergedIr);
  final modelsOutPath = '$projectRoot/lib/$outDir/models.dart';
  File(modelsOutPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(modelWriter.write());
  stdout.writeln('  → wrote $modelsOutPath');

  stdout.writeln('✅ axiom_flutter_generator done (framework: $framework)');
}

```
---
## File: lib/src/generator/model_writer.dart

```dart
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
        return wrap('DateTime.parse($access as String)');

      case 'bytes':
        return wrap('Uint8List.fromList(($access as List).cast<int>())');

      case 'list':
        final innerType = typeRef['value'] as Map<String, dynamic>;
        final innerParse = _generateParseLogic(innerType, 'e', false);
        return wrap('($access as List).map((e) => $innerParse).toList()');

      case 'map':
        // Maps in Acore IR are represented as lists of [KeyType, ValueType]
        final valueType = (typeRef['value'] as List)[1] as Map<String, dynamic>;
        final innerParse = _generateParseLogic(valueType, 'v', false);
        return wrap(
          '($access as Map).map((k, v) => MapEntry(k as String, $innerParse))',
        );

      case 'float':
      case 'double':
      case 'float32':
      case 'float64':
        return wrap('($access as num).toDouble()');

      case 'int':
      case 'int32':
      case 'int64':
      case 'bool':
      case 'string':
        final dartType = GeneratorUtils.dartTypeFromIr(typeRef, scoped: false);
        return wrap('$access as $dartType');

      default:
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
        if (isOptional) {
          return '$varName?.map((e) => ${_generateSerializeLogic(innerType, 'e', false)}).toList()';
        }
        return '$varName.map((e) => ${_generateSerializeLogic(innerType, 'e', false)}).toList()';
      case 'map':
        final valueType = (typeRef['value'] as List)[1] as Map<String, dynamic>;
        final innerSerialize = _generateSerializeLogic(valueType, 'v', false);
        if (isOptional) {
          return '$varName?.map((k, v) => MapEntry(k, $innerSerialize))';
        }
        return '$varName.map((k, v) => MapEntry(k, $innerSerialize))';
      default:
        return varName;
    }
  }
}

```
---
## File: lib/src/generator/sdk_writer.dart

```dart
import 'utils.dart';

class SdkWriter {
  final Map<String, dynamic> contracts;
  final Map<String, String> baseUrls;
  final Map<String, String> assetPaths;
  final bool isSingle;
  final String packageName;
  final String modelsImportPath;

  SdkWriter({
    required this.contracts,
    required this.baseUrls,
    required this.assetPaths,
    required this.isSingle,
    required this.packageName,
    required this.modelsImportPath,
  });

  String write() {
    final buffer = StringBuffer();
    buffer.writeln('// GENERATED CODE – DO NOT EDIT.');
    buffer.writeln('// ignore_for_file: unused_import');
    buffer.writeln('// ignore_for_file: invalid_null_aware_operator');
    buffer.writeln();
    buffer.writeln("import 'dart:convert';");
    buffer.writeln("import 'dart:typed_data';");
    buffer.writeln("import 'package:flutter/services.dart' show rootBundle;");
    buffer.writeln(
      "import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;",
    );
    buffer.writeln("import 'package:axiom_flutter/axiom_flutter.dart';");
    buffer.writeln(
      "import 'package:$packageName/$modelsImportPath' as models;",
    );
    buffer.writeln();

    _writeConfig(buffer);
    _writeSdk(buffer);

    for (final entry in contracts.entries) {
      _writeModule(buffer, entry.key, entry.value);
    }

    return buffer.toString();
  }

  void _writeConfig(StringBuffer buffer) {
    buffer.writeln('class AxiomDefaultConfig {');
    buffer.writeln('  static AxiomConfig get config => const AxiomConfig(');
    buffer.writeln('    contracts: {');
    for (final name in contracts.keys) {
      final baseUrl = baseUrls[name]!;
      final assetPath = assetPaths[name]!;
      buffer.writeln("      '$name': AxiomContractConfig(");
      buffer.writeln("        baseUrl: '$baseUrl',");
      buffer.writeln("        assetPath: '$assetPath',");
      buffer.writeln("      ),");
    }
    buffer.writeln('    },');
    buffer.writeln('  );');
    buffer.writeln('}');
    buffer.writeln();
  }

  void _writeSdk(StringBuffer buffer) {
    buffer.writeln('class AxiomSdk {');
    buffer.writeln('  final AxiomRuntime runtime;');
    buffer.writeln();
    for (final name in contracts.keys) {
      final moduleClass = '${GeneratorUtils.pascalCase(name)}Module';
      final propName = GeneratorUtils.camelCase(name);
      buffer.writeln('  late final $moduleClass $propName;');
    }
    buffer.writeln();

    buffer.writeln('  AxiomSdk._(this.runtime) {');
    for (final name in contracts.keys) {
      final moduleClass = '${GeneratorUtils.pascalCase(name)}Module';
      final propName = GeneratorUtils.camelCase(name);
      buffer.writeln("    $propName = $moduleClass(runtime, '$name');");
    }
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln(
      '  static Future<AxiomSdk> create({AxiomConfig? config}) async {',
    );
    buffer.writeln('    WidgetsFlutterBinding.ensureInitialized();');
    buffer.writeln('    final runtime = AxiomRuntime();');
    buffer.writeln('    final cfg = config ?? AxiomDefaultConfig.config;');
    buffer.writeln('    runtime.debug = cfg.debug;');
    buffer.writeln('    await runtime.init(cfg.dbPath);');
    buffer.writeln();
    buffer.writeln('    for (final entry in cfg.contracts.entries) {');
    buffer.writeln('      final c = entry.value;');
    buffer.writeln(
      '      final contractData = await rootBundle.load(c.assetPath);',
    );
    buffer.writeln(
      '      final contractBytes = contractData.buffer.asUint8List();',
    );
    buffer.writeln('      runtime.loadContract(');
    buffer.writeln('        namespace: entry.key,');
    buffer.writeln('        baseUrl: c.baseUrl,');
    buffer.writeln('        contractBytes: contractBytes,');
    buffer.writeln('      );');
    buffer.writeln('    }');
    buffer.writeln('    return AxiomSdk._(runtime);');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();
  }

  void _writeModule(
    StringBuffer buffer,
    String name,
    Map<String, dynamic> contract,
  ) {
    final className = '${GeneratorUtils.pascalCase(name)}Module';
    buffer.writeln('class $className {');
    buffer.writeln('  final AxiomRuntime _runtime;');
    buffer.writeln('  final String _namespace;');
    buffer.writeln();
    buffer.writeln('  $className(this._runtime, this._namespace);');
    buffer.writeln();
    buffer.writeln('  void setAuthToken(String methodName, String token) {');
    buffer.writeln(
      "    _runtime.setAuthToken(namespace: _namespace, methodName: methodName, token: token);",
    );
    buffer.writeln('  }');
    buffer.writeln('  void clearAuthToken(String methodName) {');
    buffer.writeln(
      "    _runtime.clearAuthToken(namespace: _namespace, methodName: methodName);",
    );
    buffer.writeln('  }');
    buffer.writeln();

    final ir = contract['ir'] ?? contract;
    final endpointsMap = ir['endpoints'] ?? {};
    final endpoints = endpointsMap is Map
        ? endpointsMap.values.toList()
        : endpointsMap as List;

    for (final ep in endpoints) {
      _writeEndpoint(buffer, ep as Map<String, dynamic>);
    }

    buffer.writeln('}');
    buffer.writeln();
  }

  void _writeEndpoint(StringBuffer buffer, Map<String, dynamic> ep) {
    final epName = GeneratorUtils.camelCase(ep['name']);
    final method = ep['method'] as String;
    final path = ep['path'] as String;
    final endpointId = ep['id'] as int? ?? 0;
    final returnTypeRef = ep['returnType'] as Map<String, dynamic>;
    final parameters =
        (ep['parameters'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final dartReturnType = GeneratorUtils.dartTypeFromIr(
      returnTypeRef,
      scoped: true,
    );
    final isMutation = [
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
      'WS',
    ].contains(method.toUpperCase());

    // --- 1. Build Parameters ---
    final paramsList = <String>[];
    String? bodyParamName;

    for (final p in parameters) {
      final pName = GeneratorUtils.camelCase(p['name']);
      final pType = GeneratorUtils.dartTypeFromIr(p['typeRef'], scoped: true);
      final isOptional = p['isOptional'] as bool? ?? false;
      final source = p['source'] as String? ?? 'query';

      if (source == 'body') {
        bodyParamName = pName;
      }

      if (isOptional) {
        paramsList.add('$pType? $pName');
      } else {
        paramsList.add('required $pType $pName');
      }
    }

    // Add fallback body map if there is no explicit body parameter on a mutation
    if (isMutation && bodyParamName == null) {
      paramsList.add('Map<String, dynamic>? body');
      bodyParamName = 'body';
    }

    // REMOVED: paramsList.add('Map<String, String>? headers'); to prevent collisions!

    final paramsSignature = paramsList.isEmpty
        ? ''
        : '{${paramsList.join(', ')}}';

    // ✨ BEAUTIFUL SYNTAX: Both Queries and Mutations now return AxiomQuery<T> directly
    buffer.writeln('  AxiomQuery<$dartReturnType> $epName($paramsSignature) {');

    // --- 2. Build Args Map ---
    buffer.writeln('      final argsMap = <String, dynamic>{');
    for (final p in parameters) {
      final pName = GeneratorUtils.camelCase(p['name']);
      final irName = p['name'];

      // If the parameter is a Model, we must call .toJson() before sending it to the args map
      // so that it serializes correctly for the cache key and network payload.
      final pTypeKind = p['typeRef']['kind'] as String? ?? '';
      if (pTypeKind == 'named') {
        final isOpt = p['isOptional'] as bool? ?? false;
        if (isOpt) {
          buffer.writeln("        '$irName': $pName?.toJson(),");
        } else {
          buffer.writeln("        '$irName': $pName.toJson(),");
        }
      } else {
        buffer.writeln("        '$irName': $pName,");
      }
    }
    buffer.writeln('      };');

    // --- 3. Build Path Params Map ---
    final pathParams = parameters.where((p) => p['source'] == 'path').toList();
    if (pathParams.isNotEmpty) {
      buffer.writeln('      final pathParams = <String, dynamic>{');
      for (final p in pathParams) {
        buffer.writeln(
          "        '${p['name']}': ${GeneratorUtils.camelCase(p['name'])},",
        );
      }
      buffer.writeln('      };');
    }

    // --- 4. Build Query Params Map ---
    final queryParams = parameters
        .where((p) => p['source'] == 'query')
        .toList();
    if (queryParams.isNotEmpty) {
      buffer.writeln('      final queryParams = <String, dynamic>{');
      for (final p in queryParams) {
        buffer.writeln(
          "        '${p['name']}': ${GeneratorUtils.camelCase(p['name'])},",
        );
      }
      buffer.writeln('      };');
    }

    // --- 5. Generate Runtime Call ---
    final callMethod = isMutation ? 'sendMutation' : 'send';
    buffer.writeln('      return _runtime.$callMethod<$dartReturnType>(');
    buffer.writeln("        namespace: _namespace,");
    buffer.writeln("        endpointId: $endpointId,");
    buffer.writeln("        method: '$method',");
    buffer.writeln("        path: '$path',");
    // REMOVED: buffer.writeln("        headers: headers,");
    buffer.writeln("        args: argsMap,");

    if (pathParams.isNotEmpty) {
      buffer.writeln("        pathParams: pathParams,");
    }
    if (queryParams.isNotEmpty) {
      buffer.writeln("        queryParams: queryParams,");
    }
    if (bodyParamName != null) {
      buffer.writeln("        body: $bodyParamName,");
    }

    buffer.writeln(
      "        decoder: (json) => ${_generateDecoder(returnTypeRef)},",
    );
    buffer.writeln('      );');
    buffer.writeln('  }');
  }

  String _generateDecoder(Map<String, dynamic> typeRef) {
    final kind = typeRef['kind'] as String;
    switch (kind) {
      case 'void':
        return 'null';
      case 'named':
        final typeName = GeneratorUtils.pascalCase(typeRef['value']);
        return 'models.$typeName.fromJson(json)';
      case 'list':
        final innerType = typeRef['value'] as Map<String, dynamic>;
        final innerDecode = _generateDecoder(innerType).replaceAll('json', 'e');
        return '(json as List).map((e) => $innerDecode).toList()';
      default:
        return 'json as dynamic';
    }
  }
}

```
---
## File: lib/src/generator/utils.dart

```dart
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

```
---
## File: pubspec.yaml

```yaml
name: axiom_flutter_generator
description: AxiomCore Flutter Generator
version: 0.69.0
homepage: https://github.com/AxiomCore/axiom-sdk
repository: https://github.com/AxiomCore/axiom-sdk
issue_tracker: https://github.com/AxiomCore/axiom-sdk/issues

environment:
  sdk: ^3.8.0

# Add regular dependencies here.
dependencies:
  path: ^1.9.1
  yaml: ^3.1.3
  args: ^2.4.0
  toml: ^0.15.0
  collection: ^1.18.0

dev_dependencies:
  lints: ^5.0.0
  test: ^1.24.0

```
---
