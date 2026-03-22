// FILE: example/lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'axiom_generated/axiom_sdk.dart';
import 'axiom_generated/models.dart' as models;

late final AxiomSdk sdk;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? path;
  if (!kIsWeb) {
    final dbDir = await getApplicationSupportDirectory();
    path = dbDir.path;
  }

  // 1. Initialize the Runtime with Multi-Contract & Debug configurations
  final config = AxiomConfig(
    debug: true, // 🕵️‍♂️ Enables beautiful FFI Console Logs
    dbPath: path,
    contracts: {
      'users': const AxiomContractConfig(
        baseUrl: "http://localhost:8000",
        assetPath: ".axiom",
      ),
    },
  );

  sdk = await AxiomSdk.create(config);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        fontFamily: 'Inter', // Matches Tailwind default look
      ),
      home: const AxiomDashboard(),
    );
  }
}

class AxiomDashboard extends StatelessWidget {
  const AxiomDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "ATMX Flutter",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        actions: const [AuthNavbarBadge()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive layout: Row on Web/Desktop, Column on Mobile
            if (constraints.maxWidth > 800) {
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ProfileCard()),
                  SizedBox(width: 32),
                  Expanded(child: CreateUserForm()),
                ],
              );
            }
            return const Column(
              children: [ProfileCard(), SizedBox(height: 32), CreateUserForm()],
            );
          },
        ),
      ),
    );
  }
}

// ==========================================
// COMPONENT 1: Navbar Badge (Stale-While-Revalidate Sync)
// ==========================================
class AuthNavbarBadge extends StatelessWidget {
  const AuthNavbarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Both AuthNavbarBadge and ProfileCard call getUser(1).
    // Rust deduplicates this into a single network call!
    return Padding(
      padding: const EdgeInsets.only(right: 24.0),
      child: AxiomBuilder<models.User, models.User>(
        query: sdk.users.getUser(userId: 1),
        loading: (_) =>
            const Text("Connecting...", style: TextStyle(color: Colors.grey)),
        builder: (context, state, user) {
          return Row(
            children: [
              if (state.isFetching)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (state.source == AxiomSource.cache)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "⚡ CACHED",
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                "Welcome, ${user.name}",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// COMPONENT 2: Profile Card (Cache Testing)
// ==========================================
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    final query = sdk.users.getUser(userId: 1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "1. Stale-While-Revalidate",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              AxiomBuilder<models.User, models.User>(
                query: query,
                builder: (context, state, _) {
                  return TextButton.icon(
                    onPressed: state.isFetching ? null : () => query.refresh(),
                    icon: Icon(
                      state.isFetching ? Icons.sync : Icons.refresh,
                      size: 16,
                    ),
                    label: Text(state.isFetching ? "Syncing..." : "Refresh"),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          AxiomBuilder<models.User, models.User>(
            query: query,
            loading: (_) => const CircularProgressIndicator(),
            builder: (context, state, user) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "NAME",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "EMAIL",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(user.email, style: const TextStyle(fontSize: 16)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// COMPONENT 3: Form (Zero-Dart Validation)
// ==========================================
class CreateUserForm extends StatefulWidget {
  const CreateUserForm({super.key});
  @override
  State<CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends State<CreateUserForm> {
  String name = "Yash Makan";
  String email = "yash@genie.ai"; // Will trigger Rust validator

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(24),
      child: AxiomMutationBuilder<models.User, ({models.User user})>(
        mutation: sdk.users.createUser(), // The generated mutation!
        builder: (context, state, execute) {
          final isMutating = state.isMutating;

          // MAGIC: Extract the specific field error directly from the Rust AxiomError object!
          final emailError = state.error?.getFieldError('email');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "2. Zero-Dart Validation",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Submitting this form triggers the Rust rod-rs validator.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              const Text(
                "FULL NAME",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                controller: TextEditingController(text: name)
                  ..selection = TextSelection.collapsed(offset: name.length),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 16),

              const Text(
                "EMAIL (WILL FAIL SCHEMA)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              TextField(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  // Show red border if emailError exists
                  errorText: emailError != null ? "⚠️ $emailError" : null,
                ),
                controller: TextEditingController(text: email)
                  ..selection = TextSelection.collapsed(offset: email.length),
                onChanged: (v) => email = v,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isMutating
                      ? null
                      : () {
                          // Dart 3 Record syntax!
                          execute((
                            user: models.User(
                              id: 99,
                              name: name,
                              email: email,
                              role: models.UserRole.admin,
                            ),
                          ));
                        },
                  child: Text(
                    isMutating
                        ? "Validating via Rust..."
                        : state.hasData
                        ? "✅ Created Successfully!"
                        : "Submit Payload",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              if (state.hasError && emailError == null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    "Global Error: ${state.error!.message}",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
