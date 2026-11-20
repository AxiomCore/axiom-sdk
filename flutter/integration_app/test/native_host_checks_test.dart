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
    // The test binding installs HttpOverrides that answer every dart:io
    // HttpClient request with 400; the checks' own calls (OTLP sink records,
    // issuer stubs) need the real network, like on a device.
    HttpOverrides.global = null;
    final ctx = Ctx(await createFixtureSdk());
    // AXIOM_CHECKS=a.,b.x : run only checks whose id starts with one of the
    // comma-separated prefixes (local debugging; receipts use the full list).
    final only = (Platform.environment['AXIOM_CHECKS'] ?? '')
        .split(',')
        .where((p) => p.isNotEmpty)
        .toList();
    final checks = only.isEmpty
        ? allChecks
        : allChecks.where((c) => only.any(c.name.startsWith)).toList();
    final results = await runChecks(ctx, checks);
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
