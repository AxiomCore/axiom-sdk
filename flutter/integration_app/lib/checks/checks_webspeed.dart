// Unit webspeed: web response bodies outside wasm (C1.1) and the fast-start
// first call (C3.1). Web only; native skips.
import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../axiom_generated/axiom_sdk.dart';
import 'checks_webspeed_stub.dart'
    if (dart.library.js_interop) 'checks_webspeed_web.dart';
import 'ctx.dart';

void _webOnly() {
  if (!wsIsWeb) skip('web only (wasm runtime)');
}

final checksWebspeed = <CheckDef>[
  CheckDef('ws.body_outside_wasm', 'webspeed', (c) async {
    _webOnly();
    final before = wsExternalBodies();
    final r = await data(c.api.echo(path: 'ws1', q: 'body', limit: 7, flag: false));
    expectEq(r.path, 'ws1', 'path');
    expectEq(r.limit, 7, 'limit');
    expectThat(
      wsExternalBodies() > before,
      'the body was copied through wasm (axiom_web_body not used; '
      'old bundled wasm?)',
    );
  }),
  CheckDef('ws.invalid_json_same_error', 'webspeed', (c) async {
    _webOnly();
    // A namespace whose base URL is the page's base: /index.html is a 200
    // text/html body, which the runtime's JSON syntax check rejects.
    final rt = c.sdk.runtime;
    final bytes = (await rootBundle.load('assets/axiom/fixture.axiom'))
        .buffer
        .asUint8List();
    rt.loadContract(
      namespace: 'ws_html',
      baseUrl: wsPageBase(),
      contractBytes: bytes,
    );
    final resp = rt.callStream(
      namespace: 'ws_html',
      endpointId: FixtureModule.endpointIds['echo']!,
      method: 'GET',
      path: '/index.html',
      requestBytes: Uint8List(0),
    );
    final s = await resp.stream
        .firstWhere((s) => s.status != AxiomStatus.loading)
        .timeout(const Duration(seconds: 10));
    expectEq(s.status, AxiomStatus.error, 'status');
    expectEq(s.error!.stage, ErrorStage.validationResponse, 'stage');
    expectEq(s.error!.category, ErrorCategory.validation, 'category');
    expectEq(s.error!.message, 'Server response is not valid JSON', 'message');
  }),
  CheckDef('ws.fast_start_eligibility', 'webspeed', (c) async {
    _webOnly();
    final fast = wsFastGet('fixture');
    final ids = FixtureModule.endpointIds;
    // Fast start is opt-in (review B2): nothing is eligible unless the app
    // was built with AXIOM_WEB_FAST_START=true; the rules are checked below
    // on raw contract bytes. Validated endpoints are never eligible (M1).
    if (wsFastStartEnabled()) expectEq(fast.isNotEmpty, true, 'fast set');
    expectThat(
      !fast.contains(ids['cacheCacheFirst']),
      'cache_first endpoint must not be eligible',
    );
    expectThat(!fast.contains(ids['createItem']), 'POST must not be eligible');
    // Streaming (sse, chunked, WebSocket) and retry-policy endpoints.
    for (final name in ['sse', 'chunked', 'wsEcho', 'retried']) {
      final id = ids[name];
      if (id != null) {
        expectThat(!fast.contains(id), '$name must not be eligible');
      }
    }
    // Informational: how many calls the fast path served at start-up.
    expectThat(wsFastStarts() >= 0, 'counter');
  }),

  CheckDef('ws.fast_start_default_off', 'webspeed', (c) async {
    _webOnly();
    if (const bool.fromEnvironment('AXIOM_WEB_FAST_START')) {
      skip('built with AXIOM_WEB_FAST_START=true');
    }
    expectEq(wsFastStartEnabled(), false, 'fast start default (review B2)');
  }),
  CheckDef('ws.fast_start_auth_namespaces_excluded', 'webspeed', (c) async {
    _webOnly();
    final raw = utf8.decode(
      (await rootBundle.load('assets/axiom/fixture.axiom')).buffer.asUint8List(),
    );
    Set<int> with_(Map<String, Object?>? auth, {bool unvalidate = true}) {
      final root = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in root['endpoints'] as List) {
        final m = e as Map<String, dynamic>;
        // Make plain GETs otherwise eligible (validation off) so only the
        // auth rule can exclude them.
        if (unvalidate) m['validation_enabled'] = false;
        if (m['name'] == 'authBearer') m['auth'] = auth;
      }
      return wsFastGetForContract(Uint8List.fromList(utf8.encode(jsonEncode(root))));
    }

    final echo = FixtureModule.endpointIds['echo'];
    expectThat(with_(null).contains(echo), 'baseline: unvalidated echo eligible');
    // Runtime predicate: type "Session" in any case, missing location = cookie.
    expectEq(
      with_({'required': true, 'methods': [{'type': 'Session'}]}).isEmpty,
      true,
      'cookie-session namespace (type Session, no location) must get no fast start',
    );
    expectEq(
      with_({'required': true, 'methods': [{'type': 'bearer', 'name': 'bearer'}]}).isEmpty,
      true,
      'namespace with any auth method must get no fast start',
    );
    expectThat(
      !with_(null, unvalidate: false).contains(echo),
      'validated endpoint must not be eligible (M1)',
    );
  }),
  CheckDef('ws.bom_body_rejected_like_runtime', 'webspeed', (c) async {
    _webOnly();
    // serde rejects a leading BOM; TextDecoder() would strip it (review M1).
    final rt = c.sdk.runtime;
    final bytes = (await rootBundle.load('assets/axiom/fixture.axiom'))
        .buffer
        .asUint8List();
    rt.loadContract(
      namespace: 'ws_data',
      baseUrl: 'data:application/json;base64,',
      contractBytes: bytes,
    );
    final resp = rt.callStream(
      namespace: 'ws_data',
      endpointId: FixtureModule.endpointIds['echo']!,
      method: 'GET',
      path: base64Encode([0xEF, 0xBB, 0xBF, ...utf8.encode('{"path":"p"}')]),
      requestBytes: Uint8List(0),
    );
    final s = await resp.stream
        .firstWhere((s) => s.status != AxiomStatus.loading)
        .timeout(const Duration(seconds: 10));
    expectEq(s.status, AxiomStatus.error, 'status');
    expectEq(s.error!.stage, ErrorStage.validationResponse, 'stage');
    expectEq(s.error!.message, 'Server response is not valid JSON', 'message');
  }),
];
