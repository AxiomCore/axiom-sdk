import 'package:axiom_flutter/axiom_flutter.dart';

import '../axiom_generated/models.dart';
import 'ctx.dart';

final streamChecks = <CheckDef>[
  CheckDef('stream.sse', 'streams', (c) async {
    c.api.axiom.setAuthToken('sse', fixtureBearerToken);
    try {
      final r = await data(c.api.sse());
      expectEq(r.id, 't1', 'frame id');
      expectEq(r.seq, 1, 'frame seq');
    } finally {
      c.api.axiom.clearAuthToken('sse');
    }
  }),
  CheckDef('stream.chunked_ndjson', 'streams', (c) async {
    final r = await data(c.api.chunked());
    expectEq(r.seq, 1, 'frame seq');
  }),
  CheckDef('stream.websocket_echo', 'streams', (c) async {
    final api = await c.wsApi();
    // Guarded endpoint, no contract auth metadata: global token -> header.
    c.sdk.runtime.setGlobalAuthToken(fixtureBearerToken);
    try {
      // Native clients have no browser Origin; the fixture's stream policy
      // only admits the web runner's origin (browsers ignore this header).
      final r = await data(api.wsEcho(
        message: Ping(text: 'hi', seq: 7),
        options: const AxiomCallOptions(headers: {'Origin': 'http://127.0.0.1:8792'}),
      ));
      expectEq(r.text, 'hi', 'echo text');
      expectEq(r.seq, 7, 'echo seq');
    } finally {
      c.sdk.runtime.clearGlobalAuthToken();
    }
  }),
  CheckDef('stream.typed_channel', 'streams', (c) async {
    skip('pending: f1/generator (AxiomChannel<Send, Receive> with reconnect policy)');
  }),
];

final runtimeChecks = <CheckDef>[
  CheckDef('runtime.version_handshake', 'runtime', (c) async {
    skip('pending: f1 (AxiomRuntimeInfo abi/data/contract-reader versions)');
  }),
  CheckDef('runtime.init_result', 'runtime', (c) async {
    skip('pending: f1 (idempotent init returning AxiomInitResult)');
  }),
  CheckDef('runtime.contract_locked_load', 'runtime', (c) async {
    skip('pending: f1 (AxiomContractConfig signature/publicKey/sha256)');
  }),
  CheckDef('runtime.cancel', 'runtime', (c) async {
    skip('pending: f1 (AxiomRuntime.cancel, AxiomQuery.cancel)');
  }),
  CheckDef('runtime.reset_session', 'runtime', (c) async {
    skip('pending: f1 (resetSession)');
  }),
  CheckDef('runtime.shutdown', 'runtime', (c) async {
    skip('pending: f1 (shutdown clears callback)');
  }),
  CheckDef('runtime.call_options', 'runtime', (c) async {
    skip('pending: f1 (AxiomCallOptions timeout/headers/cacheMode)');
  }),
  CheckDef('runtime.error_listener', 'runtime', (c) async {
    skip('pending: f1 (global onError listener)');
  }),
  CheckDef('runtime.extensions', 'runtime', (c) async {
    skip('pending: f1 (loadExtension/invokeExtension/lifecycle/audit, native only)');
  }),
  CheckDef('runtime.base_url_override', 'runtime', (c) async {
    // The app already passes FIXTURE_BASE_URL through AxiomConfig; this proves it.
    final r = await data(c.api.echo(path: 'base', q: c.baseUrl, limit: 1));
    expectEq(r.q, c.baseUrl, 'echo');
  }),
];

