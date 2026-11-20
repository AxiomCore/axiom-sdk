import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ctx.dart';

enum Outcome { pass, fail, skip }

class CheckResult {
  CheckResult(this.def, this.outcome, this.message, this.elapsed);
  final CheckDef def;
  final Outcome outcome;
  final String message;
  final Duration elapsed;

  Map<String, Object?> toJson() => {
        'name': def.name,
        'feature': def.feature,
        'outcome': outcome.name.toUpperCase(),
        'message': message,
        'ms': elapsed.inMilliseconds,
      };
}

/// Runs [checks] one by one and prints `AXIOM_CHECK` lines plus `AXIOM_RECEIPT`.
Future<List<CheckResult>> runChecks(
  Ctx? ctx,
  List<CheckDef> checks, {
  Object? setupError,
  void Function(CheckResult)? onResult,
}) async {
  final results = <CheckResult>[];
  for (final def in checks) {
    final sw = Stopwatch()..start();
    CheckResult r;
    if (ctx == null) {
      r = CheckResult(def, Outcome.fail, 'setup failed: $setupError', sw.elapsed);
    } else {
      try {
        await def.run(ctx).timeout(const Duration(seconds: 20));
        r = CheckResult(def, Outcome.pass, '', sw.elapsed);
      } on CheckSkipped catch (e) {
        r = CheckResult(def, Outcome.skip, e.reason, sw.elapsed);
      } catch (e) {
        r = CheckResult(def, Outcome.fail, '$e', sw.elapsed);
      }
    }
    final msg = r.message.replaceAll('\n', ' ');
    // ignore: avoid_print
    print('AXIOM_CHECK ${def.name} ${r.outcome.name.toUpperCase()} $msg');
    results.add(r);
    onResult?.call(r);
  }
  final receipt = {
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'baseUrl': fixtureBaseUrl,
    'pass': results.where((r) => r.outcome == Outcome.pass).length,
    'fail': results.where((r) => r.outcome == Outcome.fail).length,
    'skip': results.where((r) => r.outcome == Outcome.skip).length,
    'checks': results.map((r) => r.toJson()).toList(),
  };
  // ignore: avoid_print
  print('AXIOM_RECEIPT ${jsonEncode(receipt)}');
  return results;
}
