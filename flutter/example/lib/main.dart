import 'package:flutter/material.dart';
import 'generated/axiom_sdk.dart';
import 'generated/schema_axiom_generated.dart' as schema;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final sdk = AxiomSdk(baseUrl: "http://localhost:8000");

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Axiom Example")),
        body: FutureBuilder(
          future: sdk.getUser(userId: 1),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Text("Loading...");
            final user = snap.data as schema.User;
            return Text("User: ${user.name}");
          },
        ),
      ),
    );
  }
}
