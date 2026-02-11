import 'package:flutter/material.dart';
import 'package:axiom_flutter/axiom_flutter.dart';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Waiting to test...';
  bool _isSuccess = false;

  Future<void> _testRustConnection() async {
    setState(() => _status = 'Initializing Isolate...');

    try {
      final runtime = AxiomRuntime();

      // 1. Initialize the FFI Isolate
      await runtime.init();

      // 2. Try to call a Rust function via FFI
      // We use dummy data just to see if the call reaches Rust
      // Note: This will likely return an error code from Rust because
      // the contract is empty, but THAT IS GOOD—it means Rust responded!
      await runtime.startup(
        baseUrl: "https://api.test.com",
        contractBytes: Uint8List.fromList([0, 1, 2, 3]), // Dummy bytes
      );

      setState(() {
        _isSuccess = true;
        _status = '✅ Connection Successful!\nRust is responding via FFI.';
      });
    } catch (e, s) {
      print(e);
      print(s);
      setState(() {
        _isSuccess = false;
        _status = '❌ Connection Failed!\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Axiom FFI Smoke Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isSuccess ? Icons.check_circle : Icons.help_outline,
                color: _isSuccess ? Colors.green : Colors.orange,
                size: 60,
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_status, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testRustConnection,
                child: const Text('Run Rust Bridge Test'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
