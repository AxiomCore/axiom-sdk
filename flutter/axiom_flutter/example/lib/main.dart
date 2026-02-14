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
      await runtime.init();
      await runtime.startup(
        baseUrl: "",
        contractBytes: Uint8List.fromList([0]),
      );

      setState(() {
        _isSuccess = true;
        _status = '✅ Connection Successful!\nRust is responding via FFI.';
      });
    } catch (e) {
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
