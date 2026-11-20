import 'package:flutter/material.dart';

import 'bench.dart';

final Stopwatch _mainStart = Stopwatch()..start();

void main() {
  runApp(const BenchApp());
}

class BenchApp extends StatefulWidget {
  const BenchApp({super.key});

  @override
  State<BenchApp> createState() => _BenchAppState();
}

class _BenchAppState extends State<BenchApp> {
  final List<Map<String, Object?>> _results = [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    BenchRunner((r) {
      emitLine(r);
      if (mounted) setState(() => _results.add(r));
    }, _mainStart)
        .run()
        .whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Axiom bench',
      home: Scaffold(
        appBar: AppBar(title: Text(_done ? 'Done ($benchSelection)' : 'Running $benchSelection…')),
        body: ListView(
          children: [
            for (final r in _results)
              ListTile(
                dense: true,
                title: Text('${r['bench']} ${r['case'] ?? r['items'] ?? ''} ${r['client'] ?? r['decoder'] ?? ''}'),
                subtitle: Text('${r['status'] ?? ''} p50=${r['p50_ms'] ?? r['first_data_ms'] ?? r['round_trips_per_s'] ?? ''}'),
              ),
          ],
        ),
      ),
    );
  }
}
