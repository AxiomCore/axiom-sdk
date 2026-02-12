import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

import '../lib/src/generator/model_writer.dart';
import '../lib/src/generator/sdk_writer.dart';

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

Future<void> _generateSdk({
  required String axiomPath,
  required String outDirRelToLib,
  required String projectRoot,
}) async {
  // 1. Decode IR
  final ir = await _loadIrFromAxiom(axiomPath);

  // 2. Setup Paths
  final outDir = _normalizeOutDir(outDirRelToLib);
  final libOutDir = Directory('$projectRoot/lib/$outDir');
  if (!libOutDir.existsSync()) {
    libOutDir.createSync(recursive: true);
  }

  final packageName = _readPubspecName(projectRoot);
  final axiomFilename = axiomPath.split(Platform.pathSeparator).last;
  final modelsImportPath = outDir.isEmpty
      ? 'models.dart'
      : '$outDir/models.dart';

  // 3. Read .trust-axiom.json
  String? signature;
  String? publicKey;
  final trustFile = File('$projectRoot/.trust-axiom.json');
  if (trustFile.existsSync()) {
    try {
      final content = trustFile.readAsStringSync();
      final trustJson = jsonDecode(content) as Map<String, dynamic>;
      signature = trustJson['signature'] as String?;
      publicKey = trustJson['public_key'] as String?;
      stdout.writeln('🔐 Found signature in .trust-axiom.json');
    } catch (e) {
      stderr.writeln('⚠️ Warning: Failed to read .trust-axiom.json: $e');
    }
  }

  // 4. Generate models.dart
  final modelsFile = File('${libOutDir.path}/models.dart');
  final modelWriter = ModelWriter(ir);
  modelsFile.writeAsStringSync(modelWriter.write());
  stdout.writeln('✅ Successfully wrote ${modelsFile.path}');

  // 5. Generate axiom_sdk.dart
  final sdkFile = File('${libOutDir.path}/axiom_sdk.dart');
  final sdkWriter = SdkWriter(
    ir: ir,
    packageName: packageName,
    modelsImportPath: modelsImportPath,
    axiomFilename: axiomFilename,
    signature: signature,
    publicKey: publicKey,
  );
  sdkFile.writeAsStringSync(sdkWriter.write());
  stdout.writeln('✅ Successfully wrote ${sdkFile.path}');
}

Future<Map<String, dynamic>> _loadIrFromAxiom(String axiomPath) async {
  final file = File(axiomPath);
  if (!file.existsSync()) {
    throw Exception('Axiom file not found: $axiomPath');
  }
  final content = await file.readAsString();
  final axiomFile = jsonDecode(content);
  if (axiomFile is! Map<String, dynamic>) {
    throw Exception('Axiom file invalid JSON');
  }
  return axiomFile['ir'] as Map<String, dynamic>;
}

String _readPubspecName(String projectRoot) {
  final pubspec = File('$projectRoot/pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw Exception('pubspec.yaml not found at $projectRoot/pubspec.yaml');
  }
  final content = pubspec.readAsStringSync();
  final doc = loadYaml(content);
  final name = (doc as YamlMap?)?['name'];
  return name.toString().trim();
}

String _normalizeOutDir(String outDir) {
  var d = outDir.trim();
  if (d.startsWith('lib/')) {
    d = d.substring(4);
  }
  d = d.replaceAll(RegExp(r'^/+'), '');
  d = d.replaceAll(RegExp(r'/+$'), '');
  return d;
}
