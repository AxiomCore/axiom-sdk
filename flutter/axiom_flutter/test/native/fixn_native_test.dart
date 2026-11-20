// Native (dart:ffi) regression tests for the review findings fixed by unit
// fixn. They run against a host runtime library and a local Dart HTTP
// backend (no fixture backend needed):
//
//   AXIOM_RUNTIME_LIB=/abs/libaxiom_runtime.so flutter test test/native/fixn_native_test.dart
//   # published (0.148.6) ABI: hide the optional exports
//   AXIOM_RUNTIME_ABI=published AXIOM_RUNTIME_LIB=... flutter test test/native/fixn_native_test.dart
//
// Skipped when AXIOM_RUNTIME_LIB is not set.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

final _lib = Platform.environment['AXIOM_RUNTIME_LIB'];
final _published = Platform.environment['AXIOM_RUNTIME_ABI'] == 'published';
const _assets = '../integration_app/assets/axiom';

const epEverything = 1643923642;
const epEcho = 1421147111;
const epAmBearer = 3349796008;

/// Local backend: records requests, answers with [handler].
late HttpServer _server;
final List<HttpRequest> _seen = [];
final List<Map<String, String>> _seenHeaders = [];
Future<void> Function(HttpRequest r) handler = _ok;
Future<void> _ok(HttpRequest r) async {
  r.response
    ..headers.contentType = ContentType.json
    ..write('{"ok":true}');
  await r.response.close();
}

/// Accepts connections and never answers.
late ServerSocket _blackhole;
final _held = <Socket>[];

Future<Uint8List> _loader(String path) async => File(path).readAsBytes();

Future<AxiomState<T>> settle<T>(Stream<AxiomState<T>> s,
        {Duration timeout = const Duration(seconds: 10)}) =>
    s.firstWhere((x) => x.isSuccess || x.hasError).timeout(timeout);

void main() {
  if ((_lib ?? '').isEmpty) {
    test('fixn native tests', () {}, skip: 'AXIOM_RUNTIME_LIB not set');
    return;
  }
  late AxiomRuntime rt;

  setUpAll(() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((r) {
      _seen.add(r);
      final h = <String, String>{};
      r.headers.forEach((k, v) => h[k] = v.join(','));
      _seenHeaders.add(h);
      handler(r);
    });
    _blackhole = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _blackhole.listen(_held.add);
    rt = AxiomRuntime();
    final base = 'http://127.0.0.1:${_server.port}';
    final r = await rt.initialize(
      AxiomConfig(contracts: {
        'fx': AxiomContractConfig(
            baseUrl: base, assetPath: '$_assets/fixture.axiom'),
        'am': AxiomContractConfig(
            baseUrl: base, assetPath: '$_assets/authmeta.axiom'),
        'slow': AxiomContractConfig(
            baseUrl: 'http://127.0.0.1:${_blackhole.port}',
            assetPath: '$_assets/fixture.axiom'),
      }),
      assetLoader: _loader,
    );
    expect(r.ok, isTrue, reason: '$r');
    // Same contract with response validation off (what a void endpoint
    // looks like to the runtime: an empty body is passed through).
    final j = jsonDecode(
            File('$_assets/fixture.axiom').readAsStringSync())
        as Map<String, dynamic>;
    for (final e in (j['endpoints'] as List)) {
      (e as Map)['validation_enabled'] = false;
    }
    final nv = rt.tryLoadContract(
      namespace: 'fxnv',
      baseUrl: base,
      contractBytes: Uint8List.fromList(utf8.encode(jsonEncode(j))),
    );
    expect(nv.ok, isTrue, reason: '$nv');
  });

  setUp(() {
    handler = _ok;
    _seen.clear();
    _seenHeaders.clear();
  });

  tearDownAll(() async {
    await rt.shutdown();
    for (final s in _held) {
      s.destroy();
    }
    await _blackhole.close();
    await _server.close(force: true);
  });

  test('F8 empty 204 response completes a mutation with null data', () async {
    handler = (r) async {
      r.response.statusCode = 204;
      await r.response.close();
    };
    final q = rt.sendMutation<Object?>(
      namespace: 'fxnv',
      endpointId: epEverything,
      method: 'GET',
      path: '/types/everything',
      decoder: (j) => j,
    );
    final states = <AxiomState<Object?>>[];
    final done = Completer<void>();
    q.stream.listen(states.add, onDone: done.complete);
    await done.future.timeout(const Duration(seconds: 10));
    final last = states.lastWhere((s) => !s.isLoading);
    expect(last.isSuccess, isTrue, reason: '${states.map((s) => '${s.status} ${s.error}').toList()}');
    expect(last.data, isNull);
  });

  Future<(bool, Object?)> amBearer() async {
    final r = rt.callStream(
      namespace: 'am',
      endpointId: epAmBearer,
      method: 'GET',
      path: '/auth/bearer',
      requestBytes: Uint8List(0),
    );
    final states = <AxiomState<Uint8List>>[];
    final done = Completer<void>();
    r.stream.listen(states.add, onDone: done.complete);
    await done.future.timeout(const Duration(seconds: 10));
    final d = states.where((s) => s.hasData).toList();
    if (d.isNotEmpty) return (true, jsonDecode(utf8.decode(d.last.data!)));
    return (false, states.map((s) => s.error).whereType<AxiomError>().toList());
  }

  Future<void> bearerOnly(String token) async {
    // Drop tokens a v2 runtime stored from earlier provider answers.
    rt.clearNamespaceAuthToken(namespace: 'am');
    handler = (r) async {
      final ok = r.headers.value('authorization') == 'Bearer $token';
      r.response
        ..statusCode = ok ? 200 : 401
        ..headers.contentType = ContentType.json
        ..write(ok ? '{"method":"bearer","ok":true}' : '{"message":"no"}');
      await r.response.close();
    };
  }

  test('auth provider answers contract auth methods (published runtime too)',
      () async {
    await bearerOnly('tok-1');
    final asked = <String>[];
    rt.setAuthProvider((ns, m) async {
      asked.add('$ns/$m');
      return ns == 'am' ? 'tok-1' : null;
    });
    try {
      final r = await amBearer();
      expect(r.$1, isTrue, reason: 'asked: $asked, result: ${r.$2}');
      expect(asked, contains('am/Authorization'));
    } finally {
      rt.setAuthProvider(null);
    }
    if (_published) {
      // Provider removed: the token the Dart fallback stored is dropped.
      final after = await amBearer();
      expect(after.$1, isFalse, reason: 'token survived provider removal');
    }
  });

  test('auth provider fallback re-asks once after an auth failure', () async {
    await bearerOnly('tok-2');
    var n = 0;
    rt.setAuthProvider((ns, m) async => ++n == 1 ? 'stale' : 'tok-2');
    try {
      final r = await amBearer();
      if (_published) {
        expect(r.$1, isTrue, reason: 'asked $n times, result: ${r.$2}');
        expect(n, 2);
      } else {
        // v2 runtime asks the provider itself (no Dart retry).
        expect(n, greaterThanOrEqualTo(1));
        expect(r.$1, isFalse, reason: 'stale token accepted?');
      }
    } finally {
      rt.setAuthProvider(null);
    }
  });
}
