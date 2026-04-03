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

    _writeDefaultConfig(buffer);

    buffer.writeln('class AxiomSdk {');
    buffer.writeln('  final AxiomRuntime runtime;');
    buffer.writeln();

    if (isSingle) {
      buffer.writeln('  AxiomSdk._(this.runtime);');
      buffer.writeln();
      _writeCreateMethod(buffer);

      final ns = contracts.keys.first;
      final ir = contracts[ns]!['ir'] ?? contracts[ns]!;
      buffer.writeln('  void setAuthToken(String methodName, String token) {');
      buffer.writeln(
        '    runtime.setAuthToken(namespace: \'$ns\', methodName: methodName, token: token);',
      );
      buffer.writeln('  }');
      buffer.writeln('  void clearAuthToken(String methodName) {');
      buffer.writeln(
        '    runtime.clearAuthToken(namespace: \'$ns\', methodName: methodName);',
      );
      buffer.writeln('  }');
      buffer.writeln();

      final endpoints = (ir['endpoints'] as List?) ?? [];
      for (final ep in endpoints) {
        _writeEndpoint(buffer, ep, ns);
      }
    } else {
      // MULTI-CONTRACT MODE
      for (final ns in contracts.keys) {
        final moduleNamePascal = '${GeneratorUtils.pascalCase(ns)}Module';
        final moduleNameCamel = GeneratorUtils.camelCase(ns);
        buffer.writeln('  late final $moduleNamePascal $moduleNameCamel;');
      }
      buffer.writeln();
      buffer.writeln('  AxiomSdk._(this.runtime) {');
      for (final ns in contracts.keys) {
        final moduleNamePascal = '${GeneratorUtils.pascalCase(ns)}Module';
        final moduleNameCamel = GeneratorUtils.camelCase(ns);
        buffer.writeln(
          '    $moduleNameCamel = $moduleNamePascal(runtime, \'$ns\');',
        );
      }
      buffer.writeln('  }');
      buffer.writeln();
      _writeCreateMethod(buffer);
    }

    buffer.writeln('}');
    buffer.writeln();

    if (!isSingle) {
      for (final entry in contracts.entries) {
        _writeModule(buffer, entry.key, entry.value);
      }
    }

    return buffer.toString();
  }

  void _writeDefaultConfig(StringBuffer buffer) {
    buffer.writeln('class AxiomDefaultConfig {');
    buffer.writeln('  static AxiomConfig get config => const AxiomConfig(');
    buffer.writeln('    contracts: {');
    for (final ns in contracts.keys) {
      buffer.writeln('      \'$ns\': AxiomContractConfig(');
      buffer.writeln('        baseUrl: \'${baseUrls[ns]}\',');
      buffer.writeln('        assetPath: \'${assetPaths[ns]}\',');
      buffer.writeln('      ),');
    }
    buffer.writeln('    },');
    buffer.writeln('  );');
    buffer.writeln('}');
    buffer.writeln();
  }

  void _writeCreateMethod(StringBuffer buffer) {
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
    buffer.writeln();
  }

  void _writeModule(StringBuffer buffer, String ns, Map<String, dynamic> def) {
    final moduleNamePascal = '${GeneratorUtils.pascalCase(ns)}Module';
    final ir = def['ir'] ?? def;

    buffer.writeln('class $moduleNamePascal {');
    buffer.writeln('  final AxiomRuntime _runtime;');
    buffer.writeln('  final String _namespace;');
    buffer.writeln();
    buffer.writeln('  $moduleNamePascal(this._runtime, this._namespace);');
    buffer.writeln();
    buffer.writeln('  void setAuthToken(String methodName, String token) {');
    buffer.writeln(
      '    _runtime.setAuthToken(namespace: _namespace, methodName: methodName, token: token);',
    );
    buffer.writeln('  }');
    buffer.writeln('  void clearAuthToken(String methodName) {');
    buffer.writeln(
      '    _runtime.clearAuthToken(namespace: _namespace, methodName: methodName);',
    );
    buffer.writeln('  }');
    buffer.writeln();

    final endpoints = (ir['endpoints'] as List?) ?? [];
    for (final ep in endpoints) {
      _writeEndpoint(buffer, ep, '_namespace');
    }

    buffer.writeln('}');
    buffer.writeln();
  }

  void _writeEndpoint(
    StringBuffer buffer,
    dynamic endpoint,
    String namespaceRef,
  ) {
    final ep = endpoint as Map<String, dynamic>;
    final methodName = GeneratorUtils.camelCase(ep['name'] as String);
    final id = ep['id'] as int;
    final path = ep['path'] as String;
    final httpMethod = (ep['method'] as String).toUpperCase();

    final returnTypeRef = ep['returnType'] as Map<String, dynamic>;
    final returnIsOptional = ep['returnIsOptional'] as bool? ?? false;

    String dartReturnType = GeneratorUtils.dartTypeFromIr(
      returnTypeRef,
      scoped: true,
    );
    if (returnIsOptional && dartReturnType != 'void') dartReturnType += '?';

    final params =
        (ep['parameters'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final isMutation = httpMethod != 'GET';

    if (isMutation) {
      _writeMutation(
        buffer,
        methodName,
        id,
        path,
        httpMethod,
        dartReturnType,
        returnTypeRef,
        params,
        namespaceRef,
      );
    } else {
      _writeQuery(
        buffer,
        methodName,
        id,
        path,
        httpMethod,
        dartReturnType,
        returnTypeRef,
        params,
        namespaceRef,
      );
    }
  }

  void _writeMutation(
    StringBuffer buffer,
    String methodName,
    int id,
    String path,
    String httpMethod,
    String dartReturnType,
    Map<String, dynamic> returnTypeRef,
    List<Map<String, dynamic>> params,
    String namespaceRef,
  ) {
    String recordType = 'void';
    if (params.isNotEmpty) {
      final fields = params
          .map((p) {
            final type = GeneratorUtils.dartTypeFromIr(
              p['typeRef'],
              scoped: true,
            );
            final name = GeneratorUtils.camelCase(p['name']);
            final isOpt = p['isOptional'] as bool? ?? false;
            return '$type${isOpt ? '?' : ''} $name';
          })
          .join(', ');
      recordType = '({$fields})';
    }

    buffer.writeln(
      '  AxiomMutation<$dartReturnType, $recordType> $methodName() {',
    );
    buffer.writeln('    return AxiomMutation((args) {');
    _writeExecutionBody(
      buffer,
      id,
      path,
      httpMethod,
      dartReturnType,
      returnTypeRef,
      params,
      true,
      namespaceRef,
    );
    buffer.writeln('    });');
    buffer.writeln('  }');
    buffer.writeln();
  }

  void _writeQuery(
    StringBuffer buffer,
    String methodName,
    int id,
    String path,
    String httpMethod,
    String dartReturnType,
    Map<String, dynamic> returnTypeRef,
    List<Map<String, dynamic>> params,
    String namespaceRef,
  ) {
    buffer.write('  AxiomQuery<$dartReturnType> $methodName(');
    if (params.isNotEmpty) {
      buffer.write('{');
      for (final p in params) {
        final pName = GeneratorUtils.camelCase(p['name']);
        final pType = GeneratorUtils.dartTypeFromIr(p['typeRef'], scoped: true);
        final isOpt = p['isOptional'] as bool? ?? false;
        buffer.write(isOpt ? '$pType? $pName, ' : 'required $pType $pName, ');
      }
      buffer.write('}');
    }
    buffer.writeln(') {');
    _writeExecutionBody(
      buffer,
      id,
      path,
      httpMethod,
      dartReturnType,
      returnTypeRef,
      params,
      false,
      namespaceRef,
    );
    buffer.writeln('  }');
    buffer.writeln();
  }

  void _writeExecutionBody(
    StringBuffer buffer,
    int id,
    String path,
    String httpMethod,
    String dartReturnType,
    Map<String, dynamic> returnTypeRef,
    List<Map<String, dynamic>> params,
    bool isMutation,
    String namespaceRef,
  ) {
    String access(String pName) => isMutation ? 'args.$pName' : pName;
    final runtimeRef = isSingle ? 'runtime' : '_runtime';

    buffer.writeln('      final argsMap = <String, dynamic>{');
    for (final p in params) {
      final pName = GeneratorUtils.camelCase(p['name']);
      final argAcc = access(pName);
      final isNamed = p['typeRef']['kind'] == 'named';
      buffer.writeln(
        "        '${p['name']}': ${isNamed ? '$argAcc?.toJson()' : argAcc},",
      );
    }
    buffer.writeln('      };');

    final pathParams = params.where((p) => p['source'] == 'path').toList();
    if (pathParams.isNotEmpty) {
      buffer.writeln('      final pathParams = <String, dynamic>{');
      for (final p in pathParams) {
        buffer.writeln(
          "        '${p['name']}': ${access(GeneratorUtils.camelCase(p['name']))},",
        );
      }
      buffer.writeln('      };');
    }

    final queryParams = params.where((p) => p['source'] == 'query').toList();
    if (queryParams.isNotEmpty) {
      buffer.writeln('      final queryParams = <String, dynamic>{');
      for (final p in queryParams) {
        buffer.writeln(
          "        '${p['name']}': ${access(GeneratorUtils.camelCase(p['name']))},",
        );
      }
      buffer.writeln('      };');
    }

    final bodyParams = params.where((p) => p['source'] == 'body').toList();
    String bodyArg = 'null';
    if (bodyParams.length == 1) {
      bodyArg = access(GeneratorUtils.camelCase(bodyParams.first['name']));
    } else if (bodyParams.length > 1) {
      buffer.writeln('      final body = {');
      for (final p in bodyParams) {
        buffer.writeln(
          "        '${p['name']}': ${access(GeneratorUtils.camelCase(p['name']))},",
        );
      }
      buffer.writeln('      };');
      bodyArg = 'body';
    }

    final shape = GeneratorUtils.classifyResponse(returnTypeRef);
    String decoder;
    if (shape.kind == ResponseKind.voidType) {
      decoder = '(json) => null';
    } else if (shape.kind == ResponseKind.model) {
      decoder =
          '(json) => models.${GeneratorUtils.pascalCase(shape.modelName!)}.fromJson(json)';
    } else if (shape.kind == ResponseKind.modelVec) {
      decoder =
          '(json) => (json as List).map((e) => models.${GeneratorUtils.pascalCase(shape.modelName!)}.fromJson(e)).toList()';
    } else {
      decoder = '(json) => json as $dartReturnType';
    }

    buffer.writeln('      return $runtimeRef.send<$dartReturnType>(');
    // Uses the dynamic namespace! In single mode it writes 'namespace_name', in multi mode it uses `_namespace`.
    final nsArg = namespaceRef.startsWith('_')
        ? namespaceRef
        : "'$namespaceRef'";
    buffer.writeln('        namespace: $nsArg,');
    buffer.writeln('        endpointId: $id,');
    buffer.writeln("        method: '$httpMethod',");
    buffer.writeln("        path: '$path',");
    buffer.writeln('        args: argsMap,');
    if (pathParams.isNotEmpty)
      buffer.writeln('        pathParams: pathParams,');
    if (queryParams.isNotEmpty)
      buffer.writeln('        queryParams: queryParams,');
    if (bodyArg != 'null') buffer.writeln('        body: $bodyArg,');
    buffer.writeln('        decoder: $decoder,');
    buffer.writeln('      );');
  }
}
