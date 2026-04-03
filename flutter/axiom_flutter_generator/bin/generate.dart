import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:axiom_flutter_generator/src/generator/sdk_writer.dart';
import 'package:axiom_flutter_generator/src/generator/model_writer.dart';
import 'package:yaml/yaml.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('config')
    ..addOption('out')
    ..addOption('project-root');

  final argResults = parser.parse(arguments);
  final configPath = argResults['config'] as String;
  final outDir = argResults['out'] as String;
  final projectRoot = argResults['project-root'] as String;

  // 1. Read Pubspec to get Package Name
  final pubspecFile = File('$projectRoot/pubspec.yaml');
  final pubspec = loadYaml(pubspecFile.readAsStringSync());
  final packageName = pubspec['name'] as String;

  // 2. Read Codegen Manifest
  final configStr = File(configPath).readAsStringSync();
  final configJson = jsonDecode(configStr);

  final isSingle = configJson['single'] == true;
  final contractsNode = configJson['contracts'] as Map<String, dynamic>;

  final Map<String, dynamic> contractsData = {};
  final Map<String, String> baseUrls = {};
  final Map<String, String> assetPaths = {};

  for (final entry in contractsNode.entries) {
    final ns = entry.key;
    final file = entry.value['file'] as String;
    final baseUrl = entry.value['baseUrl'] ?? 'http://localhost:8000';

    final fileStr = File(file).readAsStringSync();
    contractsData[ns] = jsonDecode(fileStr);
    baseUrls[ns] = baseUrl;
    assetPaths[ns] = file;
  }

  // 3. Write SDK
  final sdkWriter = SdkWriter(
    contracts: contractsData,
    baseUrls: baseUrls,
    assetPaths: assetPaths,
    isSingle: isSingle,
    packageName: packageName,
    modelsImportPath: 'axiom_generated/models.dart',
  );

  File(
    '$projectRoot/lib/$outDir/axiom_sdk.dart',
  ).writeAsStringSync(sdkWriter.write());

  // 4. Merge IRs & Write Models
  final mergedIr = {
    'models': <String, dynamic>{},
    'enums': <String, dynamic>{},
  };
  for (final def in contractsData.values) {
    final ir = def['ir'] ?? def;
    if (ir['models'] != null) mergedIr['models']!.addAll(ir['models']);
    if (ir['enums'] != null) mergedIr['enums']!.addAll(ir['enums']);
  }

  final modelWriter = ModelWriter(mergedIr);
  File(
    '$projectRoot/lib/$outDir/models.dart',
  ).writeAsStringSync(modelWriter.write());
}
