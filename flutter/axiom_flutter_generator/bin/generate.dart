import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:axiom_flutter_generator/axiom_flutter_generator.dart';
import 'package:crypto/crypto.dart';
import 'package:toml/toml.dart';
import 'package:yaml/yaml.dart';

/// CLI used by `axiom pull --framework flutter`.
///
/// Per-contract keys read from AxiomDeps.toml `[contracts.<name>]`:
/// `source`, `base_url`, `variant`, `signature`, `public_key`, `sha256`.
/// Flags override them (`--base-url`, `--variant`, ... apply to every
/// contract unless `--namespace` selects one).
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config', help: 'Path to AxiomDeps.toml')
    ..addOption('out', help: 'Output dir relative to lib/, e.g. axiom_generated')
    ..addOption('project-root', help: 'Absolute path to the Flutter project root')
    ..addOption('base-url', help: 'Default base URL baked into the generated config')
    ..addOption('variant', help: 'Emit only the endpoints of this contract variant')
    ..addOption('namespace', help: 'Apply --base-url/--signature/... to this contract only')
    ..addOption('signature', help: 'Contract signature (base64)')
    ..addOption('public-key', help: 'Public key verifying the signature (base64)')
    ..addOption('sha256', help: 'Contract sha256 (computed from the asset when omitted)')
    ..addFlag('format', defaultsTo: true, help: 'Run dart format on the output')
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    _fail('${e.message}\n${parser.usage}');
  }
  if (args['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }
  final configPath = args['config'] as String?;
  final outDir = (args['out'] as String?) ?? 'axiom_generated';
  final projectRoot = (args['project-root'] as String?) ?? Directory.current.path;
  if (configPath == null) _fail('--config <AxiomDeps.toml> is required');

  final pubspecFile = File('$projectRoot/pubspec.yaml');
  if (!pubspecFile.existsSync()) _fail('pubspec.yaml not found at $projectRoot');
  loadYaml(pubspecFile.readAsStringSync());

  final tomlFile = File(configPath);
  if (!tomlFile.existsSync()) _fail('AxiomDeps.toml not found at $configPath');
  final tomlDoc = TomlDocument.parse(tomlFile.readAsStringSync()).toMap();
  final contractsNode = tomlDoc['contracts'] as Map<String, dynamic>?;
  if (contractsNode == null || contractsNode.isEmpty) {
    _fail('No [contracts] found in $configPath');
  }

  final only = args['namespace'] as String?;
  String? flag(String name, String ns) =>
      (only == null || only == ns) ? args[name] as String? : null;

  final inputs = <ContractInput>[];
  String? variant = args['variant'] as String?;
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';

  for (final entry in contractsNode.entries) {
    final name = entry.key;
    final meta = (entry.value as Map).cast<String, dynamic>();
    final assetPath = 'assets/axiom/$name.axiom';
    final candidates = <String>[
      '$projectRoot/$assetPath',
      if (meta['source'] is String) _resolve(meta['source'] as String, tomlFile.parent.path),
      '$home/.axiom/contracts/$name/contract.axiom',
    ];
    final found = candidates.where((p) => File(p).existsSync()).firstOrNull;
    if (found == null) {
      _fail('contract "$name" not found. Tried:\n  ${candidates.join('\n  ')}\nRun: axiom pull');
    }
    final bytes = File(found).readAsBytesSync();
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _fail('contract "$name" at $found is not valid JSON: ${e.message}');
    }
    variant ??= meta['variant'] as String?;
    inputs.add(
      ContractInput(
        namespace: name,
        contract: parsed,
        assetPath: assetPath,
        baseUrl: flag('base-url', name) ?? meta['base_url'] as String? ?? _contractBaseUrl(parsed),
        signature: flag('signature', name) ?? meta['signature'] as String?,
        publicKey: flag('public-key', name) ?? meta['public_key'] as String?,
        sha256: flag('sha256', name) ?? meta['sha256'] as String? ?? sha256.convert(bytes).toString(),
      ),
    );
    final built = (parsed['project'] as Map?)?['variant'];
    if (variant != null && built == 'default' && variant != 'default') {
      stderr.writeln(
        'WARNING: contract "$name" was built for the default variant; it has no '
        'per-endpoint variant data, so all endpoints are emitted. Build it with '
        '`axiom build --variant $variant` for a variant-only client.',
      );
    }
  }

  final Map<String, String> files;
  try {
    files = generate(inputs, variant: variant);
  } on GeneratorException catch (e) {
    _fail(e.message);
  }

  final written = <String>[];
  for (final e in files.entries) {
    final path = '$projectRoot/lib/$outDir/${e.key}';
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(e.value);
    written.add(path);
  }
  if (args['format'] as bool) {
    final r = await Process.run(Platform.resolvedExecutable, ['format', ...written]);
    if (r.exitCode != 0) stderr.writeln('WARNING: dart format failed: ${r.stderr}');
  }
  for (final p in written) {
    stdout.writeln('  → wrote $p');
  }
  stdout.writeln('✅ axiom_flutter_generator $generatorVersion done');
}

String _resolve(String path, String base) =>
    path.startsWith('/') ? path : '$base/$path';

/// A base URL recorded in the contract itself, if any.
String? _contractBaseUrl(Map<String, dynamic> contract) {
  for (final key in ['base_url', 'baseUrl']) {
    final v = contract[key] ?? (contract['ir'] as Map?)?[key];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

Never _fail(String message) {
  stderr.writeln('ERROR: $message');
  exit(1);
}
