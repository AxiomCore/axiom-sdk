import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/material.dart';

import 'axiom_generated/axiom_sdk.dart';
import 'checks/all.dart';
import 'checks/ctx.dart';
import 'checks/runner.dart';

void main() {
  runApp(const FixtureApp());
}

Future<AxiomSdk> createFixtureSdk() {
  return AxiomSdk.create(
    config: const AxiomConfig(
      contracts: {
        'fixture': AxiomContractConfig(
          baseUrl: fixtureBaseUrl,
          assetPath: 'assets/axiom/fixture.axiom',
        ),
      },
    ),
  );
}

class FixtureApp extends StatefulWidget {
  const FixtureApp({super.key});

  @override
  State<FixtureApp> createState() => _FixtureAppState();
}

class _FixtureAppState extends State<FixtureApp> {
  final List<CheckResult> _results = [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    Ctx? ctx;
    Object? setupError;
    try {
      ctx = Ctx(await createFixtureSdk());
    } catch (e) {
      setupError = e;
    }
    await runChecks(ctx, allChecks, setupError: setupError, onResult: (r) {
      if (mounted) setState(() => _results.add(r));
    });
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final pass = _results.where((r) => r.outcome == Outcome.pass).length;
    final fail = _results.where((r) => r.outcome == Outcome.fail).length;
    final skipped = _results.where((r) => r.outcome == Outcome.skip).length;
    return MaterialApp(
      title: 'Axiom fixture checks',
      home: Scaffold(
        appBar: AppBar(
          title: Text(_done
              ? 'Done: $pass pass, $fail fail, $skipped skip'
              : 'Running ${_results.length}/${allChecks.length}'),
        ),
        body: ListView.builder(
          itemCount: _results.length,
          itemBuilder: (context, i) {
            final r = _results[i];
            final (icon, color) = switch (r.outcome) {
              Outcome.pass => (Icons.check_circle, Colors.green),
              Outcome.fail => (Icons.error, Colors.red),
              Outcome.skip => (Icons.remove_circle_outline, Colors.grey),
            };
            return ListTile(
              key: ValueKey(r.def.name),
              leading: Icon(icon, color: color),
              title: Text(r.def.name),
              subtitle: r.message.isEmpty ? Text(r.def.feature) : Text('${r.def.feature}: ${r.message}'),
            );
          },
        ),
      ),
    );
  }
}
