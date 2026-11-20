// Behavioural proof for the final runtime (integ): exact JSON acceptance
// (1e400, invalid UTF-8 rejected like the full parse) and a Protobuf-codec
// contract that fails to load instead of aborting the process.
//   AXIOM_RUNTIME_LIB=<lib> PROOF_URL=http://127.0.0.1:8939 \
//   PROOF_PROTO=/abs/proto.axiom flutter test test/integ_proof_test.dart
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_fixture_app/axiom_generated/axiom_sdk.dart';
import 'package:axiom_fixture_app/checks/ctx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lib = Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
  final url = Platform.environment['PROOF_URL'] ?? '';
  final proto = Platform.environment['PROOF_PROTO'] ?? '';
  test('final runtime proof', () async {
    final runtime = AxiomRuntime();
    final init = await runtime.initialize(
      AxiomConfig(contracts: {
        'fixture': AxiomContractConfig(
            baseUrl: url, assetPath: 'assets/axiom/fixture.axiom'),
        'proto': AxiomContractConfig(baseUrl: url, assetPath: proto),
      }),
      assetLoader: (p) async => Uint8List.fromList(File(p).readAsBytesSync()),
    );
    // ignore: avoid_print
    print('PROOF init: $init');
    expect(init.ok, isFalse, reason: 'the Protobuf contract must fail to load');
    final fixture = FixtureModule(runtime, 'fixture');
    final s = await settle(fixture.cacheNetworkOnly(nonce: 'ok'));
    // ignore: avoid_print
    print('PROOF ok: status=${s.status} data=${s.data?.key}');
    expect(s.data?.key, 'a');
    for (final n in ['inf', 'utf8']) {
      final e = await settle(fixture.cacheNetworkOnly(nonce: n));
      // ignore: avoid_print
      print('PROOF $n: status=${e.status} error=${e.error}');
      expect(e.status, AxiomStatus.error, reason: n);
    }
  }, skip: lib.isEmpty ? 'AXIOM_RUNTIME_LIB not set' : null);
}
