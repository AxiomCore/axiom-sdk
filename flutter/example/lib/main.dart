import 'package:flutter/material.dart';
import 'generated/axiom_sdk.dart';
import 'generated/models.dart' as models;

// Make the SDK a global variable, as it's initialized asynchronously.
late final AxiomSdk sdk;

Future<void> main() async {
  // This is required when main is async.
  WidgetsFlutterBinding.ensureInitialized();

  // Asynchronously create and initialize the SDK.
  // The app will not start until the background isolate is ready.
  sdk = await AxiomSdk.create(baseUrl: "http://127.0.0.1:8000");

  // Now, run the app with the fully initialized SDK.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  // No longer need to pass the SDK, as it's a global.
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    // sdk
    //     .createUser(user: models.User(id: 1, name: "Yash Create"))
    //     .then((value) => print("response: ${value.message}"));
    // sdk.fooEndpoint().then((value) => print("foo response: $value"));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Axiom Example")),
        body: FutureBuilder<models.User>(
          // Use the global sdk instance.
          future: sdk.getUser(userId: 1),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              print(snap.error);
              return Center(child: Text("Error: ${snap.error}"));
            }
            if (!snap.hasData) {
              return const Center(child: Text("No data received."));
            }
            final user = snap.data!;
            return Center(child: Text("User from Axiom: ${user.role}"));
          },
        ),
      ),
    );
  }
}
