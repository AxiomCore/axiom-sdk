import 'package:axiom_flutter_extensions/axiom_flutter_extensions.dart';
import 'package:flutter/material.dart';

// Create the platform folders with `flutter create .` in this directory.
// The add-on needs no code: depending on it is enough. ensureInitialized()
// only turns a missing library into a clear error early.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AxiomExtensions.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Executable extensions supported: ${AxiomExtensions.isSupported}',
          ),
        ),
      ),
    ),
  );
}
