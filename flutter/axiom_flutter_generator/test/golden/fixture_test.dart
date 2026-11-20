// Golden test: generates from committed contracts and compares with the
// committed, dart-formatted output in `<case>/expected/*.dart.golden`.
//
// Update after an intended change: UPDATE_GOLDENS=1 dart test
import 'dart:convert';
import 'dart:io';

import 'package:axiom_flutter_generator/axiom_flutter_generator.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

final _root = Directory('test/golden');

ContractInput _input(
  String file,
  String namespace, {
  String? baseUrl,
  String? signature,
  String? publicKey,
}) {
  final bytes = File('${_root.path}/$file').readAsBytesSync();
  return ContractInput(
    namespace: namespace,
    contract: jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    assetPath: 'assets/axiom/$namespace.axiom',
    baseUrl: baseUrl,
    signature: signature,
    publicKey: publicKey,
    sha256: sha256.convert(bytes).toString(),
  );
}

Future<Map<String, String>> _formatted(Map<String, String> files) async {
  final dir = Directory.systemTemp.createTempSync('axiom_golden_');
  final paths = <String>[];
  for (final e in files.entries) {
    final f = File('${dir.path}/${e.key}')..writeAsStringSync(e.value);
    paths.add(f.path);
  }
  final r = await Process.run(Platform.resolvedExecutable, ['format', ...paths]);
  expect(r.exitCode, 0, reason: 'dart format failed: ${r.stderr}');
  return {
    for (final e in files.keys) e: File('${dir.path}/$e').readAsStringSync(),
  };
}

Future<void> _compare(String caseName, Map<String, String> generated) async {
  final out = await _formatted(generated);
  final expectedDir = Directory('${_root.path}/$caseName/expected');
  final update = Platform.environment['UPDATE_GOLDENS'] == '1';
  for (final e in out.entries) {
    final golden = File('${expectedDir.path}/${e.key}.golden');
    if (update) {
      golden
        ..createSync(recursive: true)
        ..writeAsStringSync(e.value);
      continue;
    }
    expect(golden.existsSync(), isTrue, reason: 'missing ${golden.path}; run with UPDATE_GOLDENS=1');
    expect(e.value, golden.readAsStringSync(), reason: '${e.key} differs from ${golden.path}');
  }
}

void main() {
  test('fixture contract', () async {
    final files = generate([_input('fixture/fixture.axiom', 'fixture')]);
    await _compare('fixture', files);
  });

  test('extras contract: enums, unions, validators, signed config', () async {
    final files = generate([
      _input(
        'extras/extras.axiom',
        'extras',
        baseUrl: 'https://api.example.com',
        signature: 'c2lnbmF0dXJl',
        publicKey: 'cHVibGljLWtleQ==',
      ),
    ]);
    await _compare('extras', files);
  });

  test('output is deterministic and imports only the public API', () {
    final a = generate([_input('fixture/fixture.axiom', 'fixture')]);
    final b = generate([_input('fixture/fixture.axiom', 'fixture')]);
    expect(a, b);
    for (final content in a.values) {
      expect(content, startsWith('// GENERATED CODE - DO NOT EDIT.\n// axiom_flutter_generator $generatorVersion'));
      expect(content, isNot(contains('package:axiom_flutter/src/')));
      expect(content, isNot(contains('print(')));
      for (final line in content.split('\n').where((l) => l.startsWith('import '))) {
        expect(
          line,
          anyOf(
            startsWith("import 'dart:"),
            "import 'package:axiom_flutter/axiom_flutter.dart';",
            // Legacy start-up fallback until initialize() lands everywhere.
            "import 'package:flutter/services.dart' show rootBundle;",
            "import 'models.dart' as models;",
          ),
        );
      }
    }
  });

  test('variant mismatch is rejected', () {
    final input = _input('fixture/fixture.axiom', 'fixture');
    (input.contract['project'] as Map)['variant'] = 'mobile';
    expect(() => generate([input], variant: 'web'), throwsA(isA<GeneratorException>()));
  });

  test('variant keeps only member endpoints when the contract lists them', () {
    final input = _input('fixture/fixture.axiom', 'fixture');
    final eps = (input.contract['ir'] as Map)['endpoints'] as Map;
    (eps['echo'] as Map)['variants'] = ['mobile'];
    (eps['claim'] as Map)['variants'] = ['web'];
    final sdk = generate([input], variant: 'mobile')['axiom_sdk.dart']!;
    expect(sdk, contains('AxiomQuery<models.Echo> echo('));
    expect(sdk, isNot(contains(' claim(')));
  });
}
