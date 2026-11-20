// Size build of the bench app: baseline_app/lib/main.dart plus one Axiom call.
import 'package:bench_dio_client/bench_dio_client.dart' as rf;
import 'package:bench_http_client/bench_http_client.dart' as hc;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'axiom_generated/axiom_sdk.dart';
import 'package:axiom_flutter/axiom_flutter.dart';

const String baseUrl = String.fromEnvironment('BENCH_BASE_URL', defaultValue: 'http://127.0.0.1:8851');

Future<String> load() async {
  final a = await rf.BenchApi(Dio(BaseOptions(baseUrl: baseUrl))).listItems(3);
  final b = await hc.HttpBenchApi(baseUrl).listItems(3);
  final sdk = await AxiomSdk.create(
    config: const AxiomConfig(
      contracts: {'bench': AxiomContractConfig(baseUrl: baseUrl, assetPath: 'assets/axiom/bench.axiom')},
    ),
  );
  final c = await sdk.bench.listItems(n: 3).stream.firstWhere((s) => s.hasData || s.hasError);
  return 'dio ${a.items.length}, http ${b.items.length}, axiom ${c.data?.items.length}';
}

void main() => runApp(const SizeApp());

class SizeApp extends StatelessWidget {
  const SizeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: FutureBuilder<String>(
              future: load(),
              builder: (context, s) => Text(s.data ?? '${s.error ?? '…'}'),
            ),
          ),
        ),
      );
}
