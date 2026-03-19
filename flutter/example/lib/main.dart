import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:axiom_flutter/axiom_flutter.dart';
import 'generated/axiom_sdk.dart';
import 'generated/models.dart' as models;
import 'package:path_provider/path_provider.dart';

late final AxiomSdk sdk;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? path;
  if (!kIsWeb) {
    final dbDir = await getApplicationSupportDirectory();
    path = dbDir.path;
    print("Path: $path");
  }
  sdk = await AxiomSdk.create(baseUrl: "http://localhost:8000", dbPath: path);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UserProfileScreen(),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // This demonstrates handling errors from an action (like a button press).
  void createUser() {
    final randomId = Random().nextInt(100);
    final newUser = models.User(
      id: randomId,
      name: "Yash $randomId",
      email: "yash@genie.ai", // This will cause a validation error in Rust
      role: models.UserRole.admin,
    );

    // We only listen once for the result of this action.
    sdk.createUser(user: newUser).stream.firstWhere((s) => !s.isLoading).then((
      state,
    ) {
      if (state.hasError) {
        final error = state.error!;

        // 1. Log the full, rich error to the console for debugging.
        print('--- AXIOM ERROR CAUGHT ---');
        print('Message: ${error.message}');
        print('Stage: ${error.stage.name}');
        print('Category: ${error.category.name}');
        print('Code: ${error.code}');
        print('Details: ${error.details}');
        print('Retryable: ${error.retryable}');
        print('--------------------------');

        // 2. Show a user-friendly dialog based on the typed error.
        showDialog(
          context: context,
          builder: (ctx) {
            // Use a switch expression for type-safe error message handling
            final (title, content) = switch (error.code) {
              ValidationError() => (
                "Invalid Input",
                "Please check your form. Details:\n\n${error.details}",
              ),
              HttpStatus(code: 404) => (
                "Not Found",
                "The server could not find the requested resource.",
              ),
              HttpStatus(code: >= 500) => (
                "Server Error",
                "Our servers are having trouble. Please try again later.",
              ),
              NetworkTimeout() || NetworkConnectionFailed() => (
                "Network Error",
                "Could not connect to the server. Please check your internet connection.",
              ),
              _ => ("An Error Occurred", error.message),
            };

            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                if (error.retryable)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // You could call createUser() again here
                    },
                    child: const Text("Retry"),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      } else if (state.data != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Success: ${state.data!.message}"),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userQuery = sdk.getUser(userId: 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Axiom Profile"),
        actions: [
          IconButton(
            onPressed: createUser,
            icon: const Icon(Icons.add),
            tooltip: 'Create User (will fail validation)',
          ),
        ],
      ),
      body: const Column(children: [UserHeader(), Divider(), UserStats()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => userQuery.refresh(),
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
        error: (context, error) {
          print("UserHeader caught error: $error");
          return ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: const Text('Could not load user profile'),
            subtitle: Text(error.message),
          );
        },
        builder: (context, state, user) {
          print(
            "Building UserHeader(${state.source.name})... ${user.toJson()}",
          );
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
                  if (state.isFetching)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Updating...",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
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
        selector: (status) => status,
        loading: (_) => const LinearProgressIndicator(),
        error: (context, error) {
          print("UserStats caught error: $error");
          return Center(
            child: Text(
              'Could not load user stats: ${error.message}',
              style: TextStyle(color: Colors.red.shade800),
            ),
          );
        },
        builder: (context, state, result) {
          print("Building UserStats(${state.source.name})...");
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
                    ? Colors.orange.shade100
                    : Colors.green.shade100,
              ),
            ],
          );
        },
      ),
    );
  }
}
