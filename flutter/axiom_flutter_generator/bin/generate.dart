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
