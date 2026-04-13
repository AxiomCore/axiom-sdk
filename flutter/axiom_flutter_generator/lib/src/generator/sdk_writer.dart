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
        // ✅ GENERATE RPCs for Multi-mode
        _writeModelRpcs(
          buffer,
          entry.value['ir'] ?? entry.value,
          '${GeneratorUtils.pascalCase(entry.key)}Module',
        );
      }
    } else {
      // ✅ GENERATE RPCs for Single-mode
      final ns = contracts.keys.first;
      final ir = contracts[ns]!['ir'] ?? contracts[ns]!;
      _writeModelRpcs(buffer, ir, 'AxiomSdk');
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

    final returnTypeRef =
        (ep['returnType'] as Map<String, dynamic>?) ?? {'kind': 'void'};
    final returnIsOptional = ep['returnIsOptional'] as bool? ?? false;

    final params =
        (ep['parameters'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // === NEW STREAMING LOGIC ===
    final streaming = ep['streaming'] as Map<String, dynamic>?;
    final isWs = streaming?['type'] == 'websocket';
    final isStream = streaming != null && !isWs;
    final isMutation = httpMethod != 'GET';

    Map<String, dynamic> actualReturnTypeRef = returnTypeRef;
    if (streaming != null &&
        streaming.containsKey('responseType') &&
        streaming['responseType'] != null) {
      actualReturnTypeRef = streaming['responseType'] as Map<String, dynamic>;
    }

    String dartReturnType = GeneratorUtils.dartTypeFromIr(
      actualReturnTypeRef,
      scoped: true,
    );
    if (returnIsOptional && dartReturnType != 'void') dartReturnType += '?';

    if (isWs) {
      _writeWebSocket(
        buffer,
        methodName,
        id,
        path,
        dartReturnType,
        actualReturnTypeRef,
        params,
        namespaceRef,
        streaming,
      );
    } else if (isStream) {
      _writeStream(
        buffer,
        methodName,
        id,
        path,
        httpMethod,
        dartReturnType,
        actualReturnTypeRef,
        params,
        namespaceRef,
      );
    } else if (isMutation) {
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

  void _writeWebSocket(
    StringBuffer buffer,
    String methodName,
    int id,
    String path,
    String dartReturnType, // This was the default return type, we'll override
    Map<String, dynamic> returnTypeRef,
    List<Map<String, dynamic>> params,
    String namespaceRef,
    Map<String, dynamic>? streaming, // Pass the streaming def here
  ) {
    // 1. Resolve Receive Type (from serverMessages)
    final serverMsgs = streaming?['serverMessages'] as List?;
    final receiveTypeRef = (serverMsgs != null && serverMsgs.isNotEmpty)
        ? serverMsgs[0]['model'] as Map<String, dynamic>
        : {'kind': 'json'};
    final receiveType = GeneratorUtils.dartTypeFromIr(
      receiveTypeRef,
      scoped: true,
    );

    // 2. Resolve Send Type (from clientMessages)
    final clientMsgs = streaming?['clientMessages'] as List?;
    final sendTypeRef = (clientMsgs != null && clientMsgs.isNotEmpty)
        ? clientMsgs[0]['model'] as Map<String, dynamic>
        : {'kind': 'json'};
    final sendType = GeneratorUtils.dartTypeFromIr(sendTypeRef, scoped: true);

    buffer.write('  AxiomChannel<$receiveType, $sendType> $methodName(');
    _writeMethodParams(buffer, params);
    buffer.writeln(') {');

    _writeParamMaps(buffer, params, false);

    final nsArg = namespaceRef.startsWith('_')
        ? namespaceRef
        : "'$namespaceRef'";

    buffer.writeln('    final res = _runtime.callStream(');
    buffer.writeln('      namespace: $nsArg,');
    buffer.writeln('      endpointId: $id,');
    buffer.writeln('      method: \'WS\',');
    buffer.writeln('      path: \'$path\',');
    if (params.any((p) => p['source'] == 'path'))
      buffer.writeln('      pathParams: pathParams,');
    if (params.any((p) => p['source'] == 'query'))
      buffer.writeln('      queryParams: queryParams,');
    buffer.writeln('      requestBytes: Uint8List(0),');
    buffer.writeln('    );');

    // Generate Decoder for ReceiveType
    final shape = GeneratorUtils.classifyResponse(receiveTypeRef);
    String decoderLogic;
    if (shape.kind == ResponseKind.model) {
      decoderLogic =
          'models.${GeneratorUtils.pascalCase(shape.modelName!)}.fromJson(jsonDecode(utf8.decode(state.data!)))';
    } else {
      decoderLogic = 'utf8.decode(state.data!) as $receiveType';
    }

    buffer.writeln('    final mapped = res.stream.map((state) {');
    buffer.writeln(
      '      if (state.hasError) return state.map<$receiveType>((_) => throw \'\');',
    );
    buffer.writeln('      if (state.data != null) {');
    buffer.writeln('        try {');
    buffer.writeln(
      '          return AxiomState<$receiveType>.success($decoderLogic, state.source, isStreaming: true);',
    );
    buffer.writeln('        } catch (e) { print("WS Decode Error: \$e"); }');
    buffer.writeln('      }');
    buffer.writeln('      return AxiomState<$receiveType>.loading();');
    buffer.writeln('    });');

    buffer.writeln(
      '    return AxiomChannel<$receiveType, $sendType>(res.requestId, mapped, _runtime);',
    );
    buffer.writeln('  }');
    buffer.writeln();
  }

  // --- NEW: HTTP Stream Generator ---
  void _writeStream(
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
    buffer.write('  AxiomStreamQuery<$dartReturnType> $methodName(');
    _writeMethodParams(buffer, params);
    buffer.writeln(') {');

    _writeParamMaps(buffer, params, false);

    final shape = GeneratorUtils.classifyResponse(returnTypeRef);
    String decoder;
    if (shape.kind == ResponseKind.voidType) {
      decoder = '(bytes) => null';
    } else {
      String jsonParser;
      if (shape.kind == ResponseKind.model) {
        jsonParser =
            'models.${GeneratorUtils.pascalCase(shape.modelName!)}.fromJson(json)';
      } else if (shape.kind == ResponseKind.modelVec) {
        jsonParser =
            '(json as List).map((e) => models.${GeneratorUtils.pascalCase(shape.modelName!)}.fromJson(e)).toList()';
      } else {
        jsonParser = 'json as $dartReturnType';
      }

      decoder =
          '''(bytes) {
          final str = utf8.decode(bytes).trim();
          if (str.isEmpty) return null;

          // Split chunk sequences explicitly (Newline JSON/SSE events fallback handler)
          final lines = str.split('\\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          if (lines.isEmpty) return null;

          for (var line in lines) {
            if (line.startsWith('data:')) {
              line = line.substring(5).trim();
            }
            try {
              final json = jsonDecode(line);
              return $jsonParser;
            } catch (_) {}
          }

          if (str is $dartReturnType) return str as $dartReturnType;
          return null;
        }''';
    }

    final nsArg = namespaceRef.startsWith('_')
        ? namespaceRef
        : "'$namespaceRef'";
    buffer.writeln('    final res = _runtime.callStream(');
    buffer.writeln('      namespace: $nsArg,');
    buffer.writeln('      endpointId: $id,');
    buffer.writeln('      method: \'$httpMethod\',');
    buffer.writeln('      path: \'$path\',');
    if (params.any((p) => p['source'] == 'path'))
      buffer.writeln('      pathParams: pathParams,');
    if (params.any((p) => p['source'] == 'query'))
      buffer.writeln('      queryParams: queryParams,');
    buffer.writeln(
      '      requestBytes: Uint8List(0),',
    ); // Usually GET streams don't have bodies
    buffer.writeln('    );');

    buffer.writeln('    final mapped = res.stream.map((state) {');
    buffer.writeln(
      '      if (state.hasError) return state.map<$dartReturnType>((_) => throw \'\');',
    );
    buffer.writeln('      if (state.data != null) {');
    buffer.writeln('         final decodeFn = $decoder;');
    buffer.writeln('         final decodedData = decodeFn(state.data!);');
    buffer.writeln(
      '         if (decodedData == null) return AxiomState<$dartReturnType>.loading();',
    );
    buffer.writeln(
      '         return AxiomState<$dartReturnType>.success(decodedData, state.source, isStreaming: state.isStreaming);',
    );
    buffer.writeln('      }');
    buffer.writeln('      return AxiomState<$dartReturnType>.loading();');
    buffer.writeln('    });');

    buffer.writeln('    return AxiomStreamQuery<$dartReturnType>(mapped);');
    buffer.writeln('  }');
    buffer.writeln();
  }

  void _writeMethodParams(
    StringBuffer buffer,
    List<Map<String, dynamic>> params,
  ) {
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
  }

  void _writeParamMaps(
    StringBuffer buffer,
    List<Map<String, dynamic>> params,
    bool isMutation,
  ) {
    String access(String pName) => isMutation ? 'args.$pName' : pName;

    buffer.writeln('      final argsMap = <String, dynamic>{');
    for (final p in params) {
      final pName = GeneratorUtils.camelCase(p['name']);
      final isNamed = p['typeRef']['kind'] == 'named';
      buffer.writeln(
        "        '${p['name']}': ${isNamed ? '${access(pName)}?.toJson()' : access(pName)},",
      );
    }
    buffer.writeln('      };');

    final pathParams = params.where((p) => p['source'] == 'path').toList();
    if (pathParams.isNotEmpty) {
      buffer.writeln('      final pathParams = <String, dynamic>{');
      for (final p in pathParams)
        buffer.writeln(
          "        '${p['name']}': ${access(GeneratorUtils.camelCase(p['name']))},",
        );
      buffer.writeln('      };');
    }

    final queryParams = params.where((p) => p['source'] == 'query').toList();
    if (queryParams.isNotEmpty) {
      buffer.writeln('      final queryParams = <String, dynamic>{');
      for (final p in queryParams)
        buffer.writeln(
          "        '${p['name']}': ${access(GeneratorUtils.camelCase(p['name']))},",
        );
      buffer.writeln('      };');
    }

    final bodyParams = params.where((p) => p['source'] == 'body').toList();
    if (bodyParams.isNotEmpty) {
      if (bodyParams.length == 1) {
        buffer.writeln(
          '      final body = ${access(GeneratorUtils.camelCase(bodyParams.first['name']))};',
        );
      } else {
        buffer.writeln('      final body = {');
        for (final p in bodyParams)
          buffer.writeln(
            "        '${p['name']}': ${access(GeneratorUtils.camelCase(p['name']))},",
          );
        buffer.writeln('      };');
      }
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
    bool hasBody = params.any((p) => p['source'] == 'body');
    String recordType = '()';

    final fields = params.map((p) {
      final type = GeneratorUtils.dartTypeFromIr(p['typeRef'], scoped: true);
      final name = GeneratorUtils.camelCase(p['name']);
      final isOpt = p['isOptional'] as bool? ?? false;
      return '$type${isOpt ? '?' : ''} $name';
    }).toList();

    // ✅ ESCAPE HATCH: If IR missed the body param, add a raw fallback body
    if (!hasBody) {
      fields.add('Map<String, dynamic>? body');
    }

    if (fields.isNotEmpty) {
      recordType = '({${fields.join(', ')}})';
    }

    buffer.writeln(
      '  AxiomMutation<$dartReturnType, $recordType> $methodName() {',
    );
    buffer.writeln(
      '    return AxiomMutation((\$queryArgs) {',
    ); // ✅ Use $queryArgs
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
    String access(String pName) => isMutation ? '\$queryArgs.$pName' : pName;
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
    } else if (isMutation) {
      bodyArg = access('body');
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

    final sendMethod = isMutation ? 'sendMutation' : 'send';

    buffer.writeln('      return $runtimeRef.$sendMethod<$dartReturnType>(');

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

  void _writeModelRpcs(
    StringBuffer buffer,
    Map<String, dynamic> ir,
    String moduleName,
  ) {
    final models = (ir['models'] as Map?)?.cast<String, dynamic>() ?? {};
    final endpoints =
        (ir['endpoints'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    for (final modelEntry in models.entries) {
      final modelClassName = GeneratorUtils.pascalCase(modelEntry.key);
      final rpcs = (modelEntry.value['rpcs'] as Map?)?.cast<String, dynamic>();

      if (rpcs == null || rpcs.isEmpty) continue;

      buffer.writeln('// RPC Extension for $modelClassName');
      buffer.writeln(
        'extension ${modelClassName}Rpc on models.$modelClassName {',
      );

      for (final rpcEntry in rpcs.entries) {
        final rpcName = GeneratorUtils.camelCase(rpcEntry.key);
        final rpcDef = rpcEntry.value as Map<String, dynamic>;

        final epRef = rpcDef['endpoint'];
        final targetEp = endpoints.firstWhere((e) {
          if (epRef is int) return e['id'] == epRef;
          if (epRef is String) return e['name'] == epRef;
          if (epRef is Map)
            return e['id'] == epRef['id'] || e['name'] == epRef['name'];
          return false;
        }, orElse: () => <String, dynamic>{});

        if (targetEp.isEmpty) {
          print(
            'Warning: RPC "$rpcName" skipped because target endpoint was not found.',
          );
          continue;
        }

        final targetMethodName = GeneratorUtils.camelCase(targetEp['name']);
        final args =
            (rpcDef['arguments'] as Map?)?.cast<String, dynamic>() ?? {};
        final resolver =
            (rpcDef['resolver'] as Map?)?.cast<String, dynamic>() ?? {};

        final httpMethod = (targetEp['method'] as String).toUpperCase();
        final isWs = targetEp['streaming']?['type'] == 'websocket';
        final isStream = targetEp['streaming'] != null && !isWs;
        final isMutation = httpMethod != 'GET' && !isWs && !isStream;

        buffer.write('  dynamic $rpcName($moduleName module');
        if (args.isNotEmpty) {
          buffer.write(', {');
          for (final argEntry in args.entries) {
            final argName = GeneratorUtils.camelCase(argEntry.key);
            final dartType = GeneratorUtils.dartTypeFromIr(
              argEntry.value,
              scoped: true,
            );
            buffer.write('required $dartType $argName, ');
          }
          buffer.write('}');
        }
        buffer.writeln(') {');

        // Helper to resolve string values
        String resolveValue(String val) {
          if (val.startsWith('\$args.')) {
            return GeneratorUtils.camelCase(val.substring(6));
          } else if (val.startsWith('\$this.')) {
            return 'this.${GeneratorUtils.camelCase(val.substring(6))}';
          }
          return "'$val'";
        }

        // Flatten resolver for easy lookup
        final flatResolver = <String, String>{};
        final groupedResolver = <String, Map<String, String>>{
          'path': {},
          'query': {},
          'body': {},
          'header': {},
        };

        for (final section in groupedResolver.keys) {
          final sectionMap = resolver[section] as Map?;
          if (sectionMap != null) {
            for (final entry in sectionMap.entries) {
              final k = entry.key as String;
              final v = entry.value.toString();
              groupedResolver[section]![k] = v;
              flatResolver[k] = v;
            }
          }
        }

        final epParams =
            (targetEp['parameters'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
        final callArgs = <String, String>{};
        final hasNamedBody = epParams.any((p) => p['source'] == 'body');

        for (final epParam in epParams) {
          final source = epParam['source'] as String;
          final origName = epParam['name'] as String;
          final paramName = GeneratorUtils.camelCase(origName);
          final typeRef = epParam['typeRef'] as Map<String, dynamic>;

          if (source == 'body' && typeRef['kind'] == 'named') {
            final section = groupedResolver['body']!;
            if (section.isNotEmpty) {
              final modelName = GeneratorUtils.pascalCase(typeRef['value']);
              final modelArgs = StringBuffer('models.$modelName(');
              for (final entry in section.entries) {
                final fieldName = GeneratorUtils.camelCase(entry.key);
                final resolvedVal = resolveValue(entry.value);
                modelArgs.write('$fieldName: $resolvedVal, ');
              }
              modelArgs.write(')');
              callArgs[paramName] = modelArgs.toString();
            }
          } else {
            String? mappedValue =
                groupedResolver[source]![origName] ?? flatResolver[origName];
            if (mappedValue != null) {
              callArgs[paramName] = resolveValue(mappedValue);
            }
          }
        }

        // ✅ ESCAPE HATCH: Map the resolver body to the raw fallback body map
        if (!hasNamedBody && groupedResolver['body']!.isNotEmpty) {
          final mapArgs = StringBuffer('{');
          for (final entry in groupedResolver['body']!.entries) {
            mapArgs.write("'${entry.key}': ${resolveValue(entry.value)}, ");
          }
          mapArgs.write('}');
          callArgs['body'] = mapArgs.toString();
        }

        if (isMutation) {
          buffer.write('    return module.$targetMethodName().mutationFn(');
          if (epParams.isNotEmpty || !hasNamedBody) {
            // ✅ Updated condition
            buffer.writeln('(');
            for (final entry in callArgs.entries) {
              buffer.writeln('      ${entry.key}: ${entry.value},');
            }
            buffer.writeln('    ));');
          } else {
            buffer.writeln('());');
          }
        } else {
          buffer.writeln('    return module.$targetMethodName(');
          for (final entry in callArgs.entries) {
            buffer.writeln('      ${entry.key}: ${entry.value},');
          }
          buffer.writeln('    );');
        }

        buffer.writeln('  }');
      }
      buffer.writeln('}');
      buffer.writeln();
    }
  }
}
