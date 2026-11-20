// Model RPCs (`models.<Model>.rpcs`): extension methods on the model, built
// from the rpc example's contract (examples/rpc/backend.axiom).
//
// Update after an intended change: UPDATE_GOLDENS=1 dart test
import 'dart:convert';
import 'dart:io';

import 'package:axiom_flutter_generator/axiom_flutter_generator.dart';
import 'package:test/test.dart';

ContractInput _input() => ContractInput(
  namespace: 'rpc',
  contract:
      jsonDecode(File('test/golden/rpc/rpc.axiom').readAsStringSync())
          as Map<String, dynamic>,
  assetPath: 'assets/axiom/rpc.axiom',
);

void main() {
  test('rpc golden: Person.getContacts extension', () async {
    final files = generate([_input()]);
    final dir = Directory.systemTemp.createTempSync('axiom_golden_');
    final update = Platform.environment['UPDATE_GOLDENS'] == '1';
    for (final e in files.entries) {
      final f = File('${dir.path}/${e.key}')..writeAsStringSync(e.value);
      final r = await Process.run(Platform.resolvedExecutable, [
        'format',
        f.path,
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final golden = File('test/golden/rpc/expected/${e.key}.golden');
      if (update) {
        golden
          ..createSync(recursive: true)
          ..writeAsStringSync(f.readAsStringSync());
        continue;
      }
      expect(
        f.readAsStringSync(),
        golden.readAsStringSync(),
        reason: '${e.key} differs from ${golden.path}',
      );
    }
    final sdk = files['axiom_sdk.dart']!;
    // Nothing here uses Uint8List (rootBundle's asUint8List does not count).
    expect(sdk, isNot(contains("import 'dart:typed_data';")));
    expect(sdk, contains('extension PersonRpc on models.Person {'));
    expect(
      sdk,
      contains(
        'AxiomQuery<Object?> getContacts(RpcModule module, {required int limit, AxiomCallOptions? options})',
      ),
    );
    expect(
      sdk,
      contains(
        "body: jsonEncode(<String, dynamic>{'max_results': limit, 'person_id': id}),",
      ),
    );
  });

  test('rpc mapped to a missing endpoint is rejected', () {
    final c = _input();
    final person =
        ((c.contract['ir'] as Map)['models'] as Map)['Person'] as Map;
    ((person['rpcs'] as Map)['get_contacts'] as Map)['endpoint'] = 'nope';
    expect(() => generate([c]), throwsA(isA<GeneratorException>()));
  });
}
