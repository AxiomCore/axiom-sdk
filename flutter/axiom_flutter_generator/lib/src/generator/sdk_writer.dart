import 'utils.dart';

class SdkWriter {
  final Map<String, dynamic> ir;
  final String packageName;
  final String modelsImportPath;
  final String axiomFilename;
  final String? signature;
  final String? publicKey;
  final String serviceName;

  SdkWriter({
    required this.ir,
    required this.packageName,
    required this.modelsImportPath,
    required this.axiomFilename,
    this.signature,
    this.publicKey,
  }) : serviceName = (ir['serviceName'] as String?) ?? 'Axiom Service';

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

    buffer.writeln('class AxiomSdk {');
    buffer.writeln('  final AxiomRuntime _runtime;');
    buffer.writeln();
    buffer.writeln('  AxiomSdk._(this._runtime);');
    buffer.writeln();

    _writeCreateMethod(buffer);

    final endpoints = (ir['endpoints'] as List?) ?? [];
    for (final ep in endpoints) {
      _writeEndpoint(buffer, ep);
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  void _writeCreateMethod(StringBuffer buffer) {
    buffer.writeln(
      '  static Future<AxiomSdk> create({required String baseUrl, String? dbPath}) async {',
    );
    buffer.writeln('    WidgetsFlutterBinding.ensureInitialized();');
    buffer.writeln(
      "    final contractData = await rootBundle.load('$axiomFilename');",
    );
    buffer.writeln(
      '    final contractBytes = contractData.buffer.asUint8List();',
    );
    buffer.writeln('    final runtime = AxiomRuntime();');
    buffer.writeln('    await runtime.init();');

    final sig = signature != null ? "'$signature'" : "null";
    final pk = publicKey != null ? "'$publicKey'" : "null";

    buffer.writeln('    await runtime.startup(');
    buffer.writeln('      baseUrl: baseUrl,');
    buffer.writeln('      contractBytes: contractBytes,');
    buffer.writeln('      dbPath: dbPath,');
    buffer.writeln('      signature: $sig,');
    buffer.writeln('      publicKey: $pk,');
    buffer.writeln('    );');
    buffer.writeln('    return AxiomSdk._(runtime);');
    buffer.writeln('  }');
    buffer.writeln();
  }

  void _writeEndpoint(StringBuffer buffer, dynamic endpoint) {
    final ep = endpoint as Map<String, dynamic>;
    final name = ep['name'] as String;
    final methodName = GeneratorUtils.camelCase(name);
    final id = ep['id'] as int;
    final path = ep['path'] as String;
    final httpMethod = ep['method'] as String;

    final returnTypeRef = ep['returnType'] as Map<String, dynamic>;
    final returnIsOptional = ep['returnIsOptional'] as bool? ?? false;

    String dartReturnType = GeneratorUtils.dartTypeFromIr(
      returnTypeRef,
      scoped: true,
    );
    if (returnIsOptional && dartReturnType != 'void') dartReturnType += '?';

    // Parameters
    final params =
        (ep['parameters'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // 1. Generate Signature
    buffer.write('  AxiomQuery<$dartReturnType> $methodName(');
    if (params.isNotEmpty) {
      buffer.write('{');
      for (final p in params) {
        final pName = GeneratorUtils.camelCase(p['name']);
        final pType = GeneratorUtils.dartTypeFromIr(p['typeRef'], scoped: true);
        final isOpt = p['isOptional'] as bool? ?? false;
        if (isOpt) {
          buffer.write('$pType? $pName, ');
        } else {
          buffer.write('required $pType $pName, ');
        }
      }
      buffer.write('}');
    }
    buffer.writeln(') {');

    // 2. Classify params (Path, Query, Body)
    // We also build a master 'args' map for the cache key

    buffer.writeln('    final args = <String, dynamic>{');
    for (final p in params) {
      final pName = GeneratorUtils.camelCase(p['name']);
      // For cache key, we need serializable values.
      // Models have toJson, but primitives are fine.
      // We rely on the fact that models generated have toJson.
      final pTypeKind = p['typeRef']['kind'] as String;
      if (pTypeKind == 'named') {
        buffer.writeln("      '${p['name']}': $pName?.toJson(),");
      } else {
        buffer.writeln("      '${p['name']}': $pName,");
      }
    }
    buffer.writeln('    };');

    // Build sub-maps
    // Path Params
    final pathParams = params.where((p) => p['source'] == 'path').toList();
    if (pathParams.isNotEmpty) {
      buffer.writeln('    final pathParams = <String, dynamic>{');
      for (final p in pathParams) {
        final pName = GeneratorUtils.camelCase(p['name']);
        buffer.writeln("      '${p['name']}': $pName,");
      }
      buffer.writeln('    };');
    }

    // Query Params
    final queryParams = params.where((p) => p['source'] == 'query').toList();
    if (queryParams.isNotEmpty) {
      buffer.writeln('    final queryParams = <String, dynamic>{');
      for (final p in queryParams) {
        final pName = GeneratorUtils.camelCase(p['name']);
        buffer.writeln("      '${p['name']}': $pName,");
      }
      buffer.writeln('    };');
    }

    // Body Param(s)
    final bodyParams = params.where((p) => p['source'] == 'body').toList();
    String bodyArg = 'null';
    if (bodyParams.length == 1) {
      // Single body arg -> pass the object directly
      bodyArg = GeneratorUtils.camelCase(bodyParams.first['name']);
    } else if (bodyParams.length > 1) {
      // Multiple body args -> pass as map
      // Note: This logic depends on how Rust expects it.
      // Usually if multiple, it's a JSON object.
      buffer.writeln('    final body = {');
      for (final p in bodyParams) {
        final pName = GeneratorUtils.camelCase(p['name']);
        buffer.writeln("      '${p['name']}': $pName,");
      }
      buffer.writeln('    };');
      bodyArg = 'body';
    }

    // Decoder
    final responseShape = GeneratorUtils.classifyResponse(returnTypeRef);
    String decoderLambda;

    if (responseShape.kind == ResponseKind.voidType) {
      decoderLambda = '(json) => null';
    } else {
      switch (responseShape.kind) {
        case ResponseKind.model:
          final mName = GeneratorUtils.pascalCase(responseShape.modelName!);
          decoderLambda = '(json) => models.$mName.fromJson(json)';
          break;
        case ResponseKind.modelVec:
          final mName = GeneratorUtils.pascalCase(responseShape.modelName!);
          decoderLambda =
              '(json) => (json as List).map((e) => models.$mName.fromJson(e)).toList()';
          break;
        case ResponseKind.dateTime:
          decoderLambda = '(json) => DateTime.parse(json as String)';
          break;
        case ResponseKind.primitiveInt:
        case ResponseKind.primitiveFloat:
        case ResponseKind.primitiveString:
        case ResponseKind.primitiveBool:
          // Casting handles nullable if needed inside runtime or here
          decoderLambda = '(json) => json as $dartReturnType';
          break;
        case ResponseKind.primitiveBytes:
          // Assuming base64 string from JSON if it went through JSON decode
          decoderLambda = '(json) => base64Decode(json as String)';
          break;
        default:
          decoderLambda = '(json) => json';
      }
    }

    // 3. Call _runtime.send
    buffer.writeln('    return _runtime.send<$dartReturnType>(');
    buffer.writeln('      endpointId: $id,');
    buffer.writeln("      method: '$httpMethod',");
    buffer.writeln("      path: '$path',");
    buffer.writeln('      args: args,');
    if (pathParams.isNotEmpty) buffer.writeln('      pathParams: pathParams,');
    if (queryParams.isNotEmpty)
      buffer.writeln('      queryParams: queryParams,');
    if (bodyArg != 'null') buffer.writeln('      body: $bodyArg,');
    buffer.writeln('      decoder: $decoderLambda,');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
  }
}
