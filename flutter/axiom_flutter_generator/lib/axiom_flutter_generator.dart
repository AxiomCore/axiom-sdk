library axiom_flutter_generator;

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class AxiomGeneratorConfig {
  final String outputDir;
  final String projectRoot;

  AxiomGeneratorConfig({required this.projectRoot, required this.outputDir});
}

class IR {
  final List<dynamic> endpoints;
  IR(this.endpoints);

  factory IR.fromJson(Map<String, dynamic> json) {
    return IR(json['endpoints'] as List<dynamic>);
  }
}

Future<void> generateAxiomSdk(AxiomGeneratorConfig cfg, String irJson) async {
  final ir = IR.fromJson(jsonDecode(irJson));
  final sdkPath = p.join(cfg.projectRoot, cfg.outputDir, "axiom_sdk.dart");

  final sb = StringBuffer();

  sb.writeln("""
import 'dart:typed_data';
import 'package:axiom_flutter/axiom_flutter.dart';
import 'models/models.dart'; // flatc output

class AxiomSdk {
  final AxiomRuntime _runtime;

  AxiomSdk(this._runtime);
""");

  for (final ep in ir.endpoints) {
    final name = ep['name'];
    final id = ep['id'];
    final params = ep['parameters'] as List<dynamic>;
    final returnType = ep['returnType'];

    // 1. Generate Dart method signature
    final paramsSignature = params
        .map((p) {
          final t = mapTypeToDart(p['typeRef']);
          return "required $t ${p['name']}";
        })
        .join(", ");

    // 2. Build FlatBuffers request code
    final reqBuilder = _generateRequestBuilder(name, params);

    // 3. Parse FlatBuffers response code
    final respParser = _generateResponseParser(name, returnType);

    sb.writeln("""
  Future<${mapTypeToDart(returnType)}> $name({$paramsSignature}) async {
    // Build request FlatBuffer
    final requestBytes = () {
      $reqBuilder
    }();

    final responseBytes = await _runtime.call(
      endpointId: $id,
      requestBytes: requestBytes,
    );

    // Parse response
    return () {
      $respParser
    }();
  }
""");
  }

  sb.writeln("}"); // end class

  // Write to disk
  final dir = Directory(p.join(cfg.projectRoot, cfg.outputDir));
  if (!dir.existsSync()) dir.createSync(recursive: true);

  File(sdkPath).writeAsStringSync(sb.toString());
}

String mapTypeToDart(dynamic typeRef) {
  final kind = typeRef['kind'];

  switch (kind) {
    case "int32":
      return "int";
    case "int64":
      return "int";
    case "float32":
    case "float64":
      return "double";
    case "bool":
      return "bool";
    case "string":
      return "String";
    case "named":
      return typeRef['value']; // e.g. "User"
    case "list":
      return "List<${mapTypeToDart(typeRef['value'])}>";
    default:
      return "dynamic";
  }
}

/// Request FlatBuffer builder template
String _generateRequestBuilder(String epName, List params) {
  final bName = "fb.${_toPascal(epName)}Request";
  final args = params.map((p) => "${p['name']}: ${p['name']}").join(", ");
  return """
final b = fb.Builder();
final req = $bName.create$bName(
  b,
  $args
);
b.finish(req);
return b.buffer;
""";
}

/// Response FlatBuffer parser template
String _generateResponseParser(String epName, dynamic returnType) {
  final respName = "fb.${_toPascal(epName)}Response";
  final kind = returnType['kind'];

  if (kind == "named") {
    final model = returnType['value'];
    return """
final buf = fb.Buffer(responseBytes);
final resp = $respName.getRootAs$respName(buf);
return resp.data!;
""";
  }

  return "throw UnimplementedError('Unsupported response type');";
}

String _toPascal(String name) {
  return name.substring(0, 1).toUpperCase() + name.substring(1);
}
