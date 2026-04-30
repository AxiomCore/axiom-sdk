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
      buffer.writeln("        '$irName': $pName,");
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
