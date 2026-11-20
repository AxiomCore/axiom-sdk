// Checks for unit h (web fixes found by the benchmarks); names start `h.`.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'ctx.dart';

const _echoId = 1421147111;
const _wsEchoId = 1471516720;

/// Base URL of an UNGUARDED WebSocket echo server (any path echoes text),
/// e.g. the benchmark server: `--dart-define=H_WS_ECHO_BASE_URL=http://127.0.0.1:8851`
/// with `H_WS_ECHO_PATH=/ws`. Empty: the check is skipped.
const String _wsEchoBase = String.fromEnvironment('H_WS_ECHO_BASE_URL');
const String _wsEchoPath = String.fromEnvironment(
  'H_WS_ECHO_PATH',
  defaultValue: '/ws',
);

Future<Duration> _oneCall(Ctx c) async {
  final sw = Stopwatch()..start();
  final r = c.sdk.runtime.callStream(
    namespace: 'fixture',
    endpointId: _echoId,
    method: 'GET',
    path: '/echo/h',
    queryParams: {'q': 'h'},
    requestBytes: Uint8List(0),
  );
  await r.stream.drain<void>().timeout(const Duration(seconds: 10));
  return sw.elapsed;
}

final checksH = <CheckDef>[
  // Item 1: responses are delivered event-driven, not by a 16 ms poll.
  CheckDef('h.web_no_poll_floor', 'runtime', (c) async {
    if (!kIsWeb) skip('web only');
    for (var i = 0; i < 5; i++) {
      await _oneCall(c);
    }
    final samples = <int>[];
    for (var i = 0; i < 30; i++) {
      samples.add((await _oneCall(c)).inMicroseconds);
    }
    samples.sort();
    final p50 = samples[samples.length ~/ 2] / 1000;
    // With the 16 ms pump every call took >= ~16 ms; a local echo is ~2-5 ms.
    if (p50 >= 12) {
      throw CheckFailure('p50 ${p50.toStringAsFixed(1)} ms: looks polled');
    }
  }),
  // Item 2: send() right after openChannel reaches the server (queued until
  // the request's sink exists and the socket is open) and the echo returns.
  CheckDef('h.ws_send_echo', 'streams', (c) async {
    if (_wsEchoBase.isEmpty) {
      skip('set H_WS_ECHO_BASE_URL to an unguarded echo server');
    }
    final bytes = (await rootBundle.load(
      'assets/axiom/fixture.axiom',
    )).buffer.asUint8List();
    final rt = c.sdk.runtime;
    final r = rt.tryLoadContract(
      namespace: 'h_ws',
      baseUrl: _wsEchoBase,
      contractBytes: bytes,
    );
    if (!r.ok) throw CheckFailure('loading h_ws failed: $r');
    final ch = rt.openChannel<dynamic, Map<String, dynamic>>(
      namespace: 'h_ws',
      endpointId: _wsEchoId,
      path: _wsEchoPath,
      decoder: (j) => j,
    );
    final got = Completer<Object?>();
    final sub = ch.stream.listen((s) {
      if (s.hasError && !got.isCompleted) got.completeError(s.error!);
      if (s.hasData && !got.isCompleted) got.complete(s.data);
    });
    try {
      ch.send({'text': 'h-echo', 'seq': 42}); // immediately, before open
      final v = await got.future.timeout(const Duration(seconds: 10));
      final m = v is String ? jsonDecode(v) : v;
      if (m is! Map || m['text'] != 'h-echo' || m['seq'] != 42) {
        throw CheckFailure('unexpected echo: $v');
      }
    } finally {
      await sub.cancel();
      await ch.close();
    }
  }),
];
