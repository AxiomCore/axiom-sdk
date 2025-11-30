import 'package:flutter/material.dart';
import 'package:axiom_flutter/axiom_flutter.dart';
import 'generated/axiom_sdk.dart';
import 'generated/models/models.dart' as fb;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final sdk = AxiomSdk(
      AxiomRuntime()..initialize("http://localhost:3000"),
    ); // Generated automatically during `axiom pull`

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Axiom Example")),
        body: FutureBuilder(
          future: sdk.getUser(id: 1),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Text("Loading...");
            final user = snap.data as fb.User;
            return Text("User: ${user.name}");
          },
        ),
      ),
    );
  }
}
