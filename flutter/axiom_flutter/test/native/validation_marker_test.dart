// AxiomState.validation end to end through the native binding (runtime
// 0.150.1 marks sampled/unvalidated responses in the Complete event's data).
// Skipped unless AXIOM_RUNTIME_LIB is set AND the library reports the marker
// (a forced `sample` call on a large list comes back as `sampled`); older
// libraries (and the published Apple runtime) report `unknown`/`full`.
//
//   AXIOM_RUNTIME_LIB=/abs/libaxiom_runtime.so \
//     flutter test test/native/validation_marker_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_flutter/src/runtime_io.dart';
import 'package:flutter_test/flutter_test.dart';

const _contract = '../benchmarks/app/assets/axiom/bench.axiom';
const _listItems = 113632206;

/// The bench contract has no validators; add a plain-array one for ItemList
/// so the runtime validates (and, for large bodies, samples) it.
Uint8List _contractWithValidator() {
  final d = jsonDecode(File(_contract).readAsStringSync()) as Map;
  (d['validators'] as Map)['ItemList'] = 'properties:\n'
      '  items:\n'
      '    items:\n'
      '      properties:\n'
      '        id:\n'
      '          type: string\n'
      '        name:\n'
      '          min: 1\n'
      '          type: string\n'
      '      type: object\n'
      '    type: array\n'
      '  total:\n'
      '    type: number\n'
      'type: object\n';
  return Uint8List.fromList(utf8.encode(jsonEncode(d)));
}

void _server(SendPort out) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  out.send(s.port);
  await for (final r in s) {
    final n = int.parse(r.uri.queryParameters['n'] ?? '1');
    r.response.headers.contentType = ContentType.json;
    r.response.add(utf8.encode(jsonEncode({
      'items': [
        for (var i = 1; i <= n; i++)
          {'id': '$i', 'name': 'item $i', 'price': i * 1.25, 'qty': i % 100,
           'active': i.isEven, 'tags': ['t${i % 7}', 'bench']},
      ],
      'total': n,
    })));
    await r.response.close();
  }
}

void main() {
  final lib = Platform.environment['AXIOM_RUNTIME_LIB'] ?? '';
  if (lib.isEmpty) {
    test('validation marker', () {}, skip: 'AXIOM_RUNTIME_LIB not set');
    return;
  }
  late AxiomRuntimeIo rt;

  Future<AxiomState<int>> call(int n, [AxiomValidationPolicy? v]) => rt
      .send<int>(
        namespace: 'bench',
        endpointId: _listItems,
        method: 'GET',
        path: '/items',
        queryParams: {'n': '$n'},
        args: {'n': n, 'v': v?.name},
        decoder: (j) => ((j as Map)['items'] as List).length,
        options: v == null ? null : AxiomCallOptions(validation: v),
      )
      .stream
      .firstWhere((x) => (x.hasData && !x.isFetching) || x.hasError)
      .timeout(const Duration(seconds: 20));

  setUpAll(() async {
    final ready = ReceivePort();
    await Isolate.spawn(_server, ready.sendPort);
    final port = await ready.first as int;
    final db = Directory.systemTemp.createTempSync('axiom_vm_');
    final bytes = _contractWithValidator();
    rt = AxiomRuntime() as AxiomRuntimeIo;
    final r = await rt.initialize(
      AxiomConfig(
        dbPath: db.path,
        contracts: {
          'bench': AxiomContractConfig(
            baseUrl: 'http://127.0.0.1:$port',
            assetPath: _contract,
          ),
        },
      ),
      assetLoader: (_) async => bytes,
    );
    expect(r.ok, isTrue, reason: '${r.error}');
  });

  test('AxiomState.validation reflects the runtime policy', () async {
    // ~150 KB body: above the 64 KiB auto threshold.
    final probe = await call(2000, AxiomValidationPolicy.sample);
    expect(probe.hasError, isFalse, reason: '${probe.error}');
    if (probe.validation != AxiomValidationMode.sampled) {
      markTestSkipped('library does not report the validation marker '
          '(got ${probe.validation})');
      return;
    }
    expect(probe.data, 2000);

    final auto = await call(2000);
    expect(auto.validation, AxiomValidationMode.sampled, reason: 'auto, large');
    final small = await call(5);
    expect(small.validation, AxiomValidationMode.full, reason: 'auto, small');
    expect(small.data, 5);
    final full = await call(2000, AxiomValidationPolicy.full);
    expect(full.validation, AxiomValidationMode.full, reason: 'option full');
    final off = await call(2000, AxiomValidationPolicy.off);
    expect(off.validation, AxiomValidationMode.off, reason: 'option off');
  });
}
