// The Axiom setup an app writes by hand (counted by tool/count_loc.py).
import 'package:axiom_flutter/axiom_flutter.dart';

import 'axiom_generated/axiom_sdk.dart';

const String benchBaseUrl =
    String.fromEnvironment('BENCH_BASE_URL', defaultValue: 'http://127.0.0.1:8851');

Future<AxiomSdk> createBenchSdk() => AxiomSdk.create(
      config: const AxiomConfig(
        contracts: {
          'bench': AxiomContractConfig(baseUrl: benchBaseUrl, assetPath: 'assets/axiom/bench.axiom'),
        },
      ),
    );
