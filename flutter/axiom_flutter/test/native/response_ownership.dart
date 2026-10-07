import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:axiom_flutter/src/runtime_io.dart';

Future<void> main() async {
  final runtime = AxiomRuntimeIo();
  await runtime.init().timeout(const Duration(seconds: 10));
  runtime.loadContract(
    namespace: 'test',
    baseUrl: 'http://127.0.0.1:1',
    contractBytes: Uint8List.fromList(utf8.encode('{}')),
  );
  var rejected = false;
  try {
    runtime.loadContract(
      namespace: 'test',
      baseUrl: '',
      contractBytes: Uint8List.fromList([0]),
    );
  } on StateError {
    rejected = true;
  }
  if (!rejected) throw StateError('Native load failure was ignored');
  final requests = <Future<void>>[];
  for (var i = 0; i < 200; i++) {
    final expected = {'nonce': i, 'payload': List.filled(1024, 'x').join()};
    final response = runtime.callStream(
      namespace: 'test',
      endpointId: 1,
      method: 'POST',
      path: '/controlled',
      requestBytes: Uint8List.fromList(utf8.encode(jsonEncode(expected))),
    );
    requests.add(
      response.stream
          .firstWhere((state) => state.hasData || state.hasError)
          .timeout(const Duration(seconds: 10))
          .then((state) {
            if (state.hasError)
              throw StateError('Unexpected ABI response error');
            final actual = jsonDecode(utf8.decode(state.data!));
            if (actual['nonce'] != i ||
                actual['payload'] != expected['payload'])
              throw StateError('Native data was not owned across isolates');
          }),
    );
  }
  await Future.wait(requests);
  print(
    '200 native response ownership cases and load-error propagation passed',
  );
  exit(0);
}
