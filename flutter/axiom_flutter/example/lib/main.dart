// Minimal axiom_flutter app: one query and one mutation.
//
// The client in lib/axiom_generated was written by
// `axiom pull backend/backend.axiom --framework flutter --name todos
// --out lib/axiom_generated`. See README.md for the backend commands.
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'axiom_generated/axiom_sdk.dart';
import 'axiom_generated/models.dart' as models;

late final AxiomSdk sdk;

/// The Android emulator reaches your computer at 10.0.2.2.
String backendUrl() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://127.0.0.1:8080';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Starts the runtime and loads assets/axiom/todos.axiom.
  sdk = await AxiomSdk.create(baseUrlOverrides: {'todos': backendUrl()});
  runApp(const MaterialApp(home: ExamplePage()));
}

/// Shows a greeting (query) and a button that creates a todo (mutation).
class ExamplePage extends StatelessWidget {
  /// Creates the page.
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('axiom_flutter example')),
      body: Center(
        // Query: GET /hello/{name}. Rebuilds on loading, data and error.
        child: AxiomBuilder<models.Greeting, models.Greeting>(
          query: sdk.todos.hello(name: 'Flutter'),
          loading: (context) => const CircularProgressIndicator(),
          error: (context, error) => Text('Error: ${error.message}'),
          builder: (context, state, greeting) => Text(greeting.message),
        ),
      ),
      floatingActionButton: const CreateTodoButton(),
    );
  }
}

/// Sends POST /todos when pressed.
class CreateTodoButton extends StatelessWidget {
  /// Creates the button.
  const CreateTodoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AxiomMutationBuilder<models.Todo, String>(
      mutation: AxiomMutation((title) => sdk.todos.createTodo(title: title)),
      builder: (context, state, execute) => FloatingActionButton.extended(
        onPressed: state.isMutating ? null : () => execute('Write docs'),
        label: Text(
          state.data == null ? 'Create todo' : 'Created ${state.data!.id}',
        ),
      ),
    );
  }
}
