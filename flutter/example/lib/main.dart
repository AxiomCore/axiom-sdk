import 'package:flutter/material.dart';
import 'package:axiom_flutter/axiom_flutter.dart';
import 'generated/axiom_sdk.dart';
import 'generated/models.dart' as models;

late final AxiomSdk sdk;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sdk = await AxiomSdk.create(baseUrl: "http://127.0.0.1:8000");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    sdk.fooEndpoint().stream.listen((data) {
      print(data);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: UserProfileScreen());
  }
}

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userQuery = sdk.getUser(userId: 1);

    return Scaffold(
      appBar: AppBar(title: const Text("Axiom Profile")),
      body: const Column(children: [UserHeader(), Divider(), UserStats()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          userQuery.refresh();
        },
        label: const Text("Refresh All"),
        icon: const Icon(Icons.refresh),
      ),
    );
  }
}

class UserHeader extends StatelessWidget {
  const UserHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: AxiomBuilder<models.User, models.User>(
        query: sdk.getUser(userId: 1),
        selector: (user) => [user.name, user.email],
        loading: (_) => const Center(child: CircularProgressIndicator()),
        builder: (context, state, user) {
          print("Building UserHeader... ${user.toJson()}");
          return Row(
            children: [
              const CircleAvatar(radius: 30, child: Icon(Icons.person)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  // Show if we are fetching in the background
                  if (state.isFetching)
                    const Text(
                      "Updating...",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class UserStats extends StatelessWidget {
  const UserStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.grey[100],
      child: AxiomBuilder(
        query: sdk.getUser(userId: 1),
        transform: (user) => (user.id, user.role),
        selector: (statusString) => statusString,
        loading: (_) => const LinearProgressIndicator(),
        builder: (context, state, result) {
          print("Building UserStats...");
          String statusString =
              "ID: ${result.$1} | Role: ${result.$2 ?? 'Guest'}";
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "User Statistics",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Chip(
                label: Text(statusString),
                backgroundColor: state.source == AxiomSource.cache
                    ? Colors.orange[100]
                    : Colors.green[100],
              ),
            ],
          );
        },
      ),
    );
  }
}
