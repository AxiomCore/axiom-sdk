// Runs the whole integration check list on the host VM against a host build
// of the native runtime (dart:ffi, same code path as Android/iOS/macOS) and
// writes a receipt. Skipped unless AXIOM_RUNTIME_LIB is set.
//
//   flutter/fixtures/backend/run.sh 8791 &
//   AXIOM_RUNTIME_LIB=/abs/libaxiom_runtime.so \
//   AXIOM_RECEIPT_OUT=receipts/receipt-linux-host.json \
//   flutter test test/native_host_checks_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:axiom_fixture_app/checks/all.dart';
import 'package:axiom_fixture_app/checks/ctx.dart';
import 'package:axiom_fixture_app/checks/runner.dart';
import 'package:axiom_fixture_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lib = Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
  TestWidgetsFlutterBinding.ensureInitialized();
  test('integration checks on the host native runtime', () async {
    final ctx = Ctx(await createFixtureSdk());
    final results = await runChecks(ctx, allChecks);
    final out = Platform.environment['AXIOM_RECEIPT_OUT'];
    if (out != null && out.isNotEmpty) {
      File(out)
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
          'platform': 'linux-host-ffi',
          'runtimeLib': lib.split('/').last,
          'pass': results.where((r) => r.outcome == Outcome.pass).length,
          'fail': results.where((r) => r.outcome == Outcome.fail).length,
          'skip': results.where((r) => r.outcome == Outcome.skip).length,
          'checks': results.map((r) => r.toJson()).toList(),
        }));
    }
  }, skip: lib.isEmpty ? 'AXIOM_RUNTIME_LIB not set' : null,
     timeout: const Timeout(Duration(minutes: 10)));
}
