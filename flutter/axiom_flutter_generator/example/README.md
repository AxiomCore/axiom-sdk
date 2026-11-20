# axiom_flutter_generator example

The generator is a command-line tool, run by the `axiom` CLI.

In a Flutter project with `axiom_flutter` in `dependencies` and
`axiom_flutter_generator` in `dev_dependencies`:

```sh
axiom pull ../backend/backend.axiom --framework flutter --name todos --out lib/axiom_generated
```

This writes `lib/axiom_generated/axiom_sdk.dart` and `models.dart`. Use them:

```dart
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/material.dart';

import 'axiom_generated/axiom_sdk.dart';
import 'axiom_generated/models.dart' as models;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sdk = await AxiomSdk.create();
  final models.Greeting greeting =
      await sdk.todos.hello(name: 'Ada').stream.unwrap();
  debugPrint(greeting.message);
}
```

To regenerate without pulling the contract again:

```sh
dart run axiom_flutter_generator:generate --config AxiomDeps.toml --out axiom_generated
```

A complete app, with the backend contract and the generated files, is in
[`axiom_flutter/example`](https://github.com/AxiomCore/axiom-sdk/tree/main/flutter/axiom_flutter/example).
