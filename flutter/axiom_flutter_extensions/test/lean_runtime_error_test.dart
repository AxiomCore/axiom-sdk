// Extensions on a LEAN runtime (built without executable extensions) must
// fail with a clear message that names this package. Runs against a host
// runtime library:
//
//   AXIOM_RUNTIME_LIB=/abs/lean/linux-x64/libaxiom_runtime.so flutter test
//   AXIOM_RUNTIME_LIB=/abs/full/linux-x64/libaxiom_runtime.so flutter test   # full: no add-on message
//
// Skipped when AXIOM_RUNTIME_LIB is not set.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

final _lib = Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
const _contract = '../integration_app/assets/axiom/fixture.axiom';

void main() {
  if (_lib.isEmpty) {
    test('lean runtime error', () {}, skip: 'AXIOM_RUNTIME_LIB not set');
    return;
  }
  late AxiomRuntime rt;
  late bool lean;

  setUpAll(() async {
    rt = AxiomRuntime();
    final r = await rt.initialize(
      AxiomConfig(contracts: {
        'fx': AxiomContractConfig(
            baseUrl: 'http://127.0.0.1:9', assetPath: _contract),
      }),
      assetLoader: (p) async => Uint8List.fromList(File(p).readAsBytesSync()),
    );
    expect(r.ok, isTrue, reason: '$r');
    final audit = await rt.extensionAudit();
    lean = audit is Map && audit['compiled'] == false;
    // ignore: avoid_print
    print('runtime $_lib: extensions compiled = ${!lean}; audit = $audit');
  });

  Matcher addonError() => isA<AxiomExtensionException>().having(
        (e) => e.message ?? '',
        'message',
        lean
            ? contains('Executable extensions need the axiom_flutter_extensions package')
            : isNot(contains('axiom_flutter_extensions')),
      );

  test('invokeExtension', () async {
    await expectLater(
      rt.invokeExtension(const AxiomExtensionCall(
        extension: 'missing',
        export: 'run',
        interfaceSha256: 'x',
        abiSymbol: 'y',
        input: {'a': 1},
      )),
      throwsA(addonError()),
    );
  });

  test('loadExtension', () async {
    await expectLater(
      rt.loadExtension(AxiomExtensionPackage(
        target: 'android',
        packageBytes: Uint8List.fromList([1]),
        moduleBytes: Uint8List.fromList([1]),
        authorityBytes: Uint8List.fromList([1]),
        packageLockBytes: Uint8List.fromList([1]),
      )),
      throwsA(addonError()),
    );
  });

  test('lifecycle and audit still succeed', () async {
    rt.extensionLifecycle(AxiomLifecycleEvent.foreground);
    expect(await rt.extensionAudit(), isNotNull);
  });
}
