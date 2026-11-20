// Unit fixn: device checks for the native review fixes (F5, F7, cancel race).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_flutter/src/internal/sse.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'ctx.dart';

const _ns = 'fixture';
const _echoId = 1421147111;

final List<CheckDef> checksFixn = [
  CheckDef('fixn.sse_split_utf8_crlf', 'streams', (c) async {
    final p = AxiomSseParser();
    final out = <String>[];
    for (final b in utf8.encode('data: héllo 😀\r\ndata: x\r\n\r\n')) {
      out.addAll(p.feed(Uint8List.fromList([b])).map(utf8.decode));
    }
    expectEq(out.join('|'), 'héllo 😀\nx', 'events');
  }),
  CheckDef('fixn.query_key_includes_headers', 'runtime', (c) async {
    if (kIsWeb) skip('web query keys: unit h (runtime_web.dart)');
    final a = c.api.everything(
      options: const AxiomCallOptions(headers: {'X-Fixn': 'a'}),
    );
    final b = c.api.everything(
      options: const AxiomCallOptions(headers: {'X-Fixn': 'b'}),
    );
    expectThat(a.key != b.key, 'same key for different headers: ${a.key}');
    final ra = await a.stream
        .firstWhere((s) => s.hasData || s.hasError)
        .timeout(const Duration(seconds: 10));
    final rb = await b.stream
        .firstWhere((s) => s.hasData || s.hasError)
        .timeout(const Duration(seconds: 10));
    expectThat(ra.hasData && rb.hasData, 'calls failed: ${ra.error} ${rb.error}');
  }),
  CheckDef('fixn.cancel_just_issued', 'runtime', (c) async {
    final rt = c.sdk.runtime;
    final r = rt.callStream(
      namespace: _ns,
      endpointId: _echoId,
      method: 'GET',
      path: '/echo/fixn',
      queryParams: {'q': 'x', 'limit': 1},
      requestBytes: Uint8List(0),
    );
    final states = <AxiomState<Uint8List>>[];
    final done = Completer<void>();
    r.stream.listen(states.add, onDone: done.complete);
    final ok = rt.cancel(r.requestId);
    await done.future.timeout(const Duration(seconds: 10),
        onTimeout: () => throw CheckFailure('stream not closed: $states'));
    final errs = states.where((s) => s.hasError).toList();
    if (ok) {
      expectThat(errs.isNotEmpty && errs.first.error!.isCancelled,
          'cancel() true but no Cancelled error: $states');
    } else {
      // Only acceptable when the call had already delivered its result.
      expectThat(states.any((s) => s.hasData),
          'cancel() returned false for a live request: $states');
    }
  }),
];
