// Checks for unit g (gaps left by the first units). Public API only, so they
// run on every platform; names start with `g.`.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'ctx.dart';

const _echoId = 1421147111;

/// Written by `fixtures/tool/sign.sh` next to the contract asset.
class _Signed {
  _Signed(this.bytes, this.sha256, this.signature, this.publicKey, this.wrongPublicKey);
  final Uint8List bytes;
  final String sha256, signature, publicKey, wrongPublicKey;
}

_Signed? _signedCache;
Future<_Signed> _signed() async {
  if (_signedCache != null) return _signedCache!;
  final bytes = (await rootBundle.load('assets/axiom/fixture.axiom')).buffer.asUint8List();
  final Map<String, dynamic> j;
  try {
    j = jsonDecode(await rootBundle.loadString('assets/axiom/fixture.signed.json'))
        as Map<String, dynamic>;
  } catch (e) {
    skip('assets/axiom/fixture.signed.json missing: run fixtures/tool/sign.sh ($e)');
  }
  return _signedCache = _Signed(bytes, j['sha256'] as String, j['signature'] as String,
      j['publicKey'] as String, j['wrongPublicKey'] as String);
}

var _probe = 0;
String _ns(String tag) => 'g_${tag}_${_probe++}';

AxiomContractLoadResult _load(
  Ctx c,
  String ns,
  Uint8List bytes, {
  String? signature,
  String? publicKey,
  String? sha256,
}) =>
    c.sdk.runtime.tryLoadContract(
      namespace: ns,
      baseUrl: c.baseUrl,
      contractBytes: bytes,
      signature: signature,
      publicKey: publicKey,
      sha256: sha256,
    );

/// One echo call through [ns]; proves a loaded contract is usable.
Future<void> _echoThrough(Ctx c, String ns) async {
  final r = c.sdk.runtime.callStream(
    namespace: ns,
    endpointId: _echoId,
    method: 'GET',
    path: '/echo/signed',
    queryParams: {'q': 'x', 'limit': 1},
    requestBytes: Uint8List(0),
  );
  final states = <AxiomState<Uint8List>>[];
  final done = Completer<void>();
  r.stream.listen(states.add, onDone: done.complete, onError: (Object e) {
    if (!done.isCompleted) done.complete();
  });
  await done.future.timeout(const Duration(seconds: 10),
      onTimeout: () => throw CheckFailure('echo through $ns did not complete'));
  final data = states.where((s) => s.hasData).toList();
  expectThat(data.isNotEmpty, 'echo through $ns: ${states.map((s) => s.error)}');
  final body = jsonDecode(utf8.decode(data.last.data!)) as Map<String, dynamic>;
  expectEq(body['path'], 'signed', 'echo path');
}

// ---- item 3: auth metadata (fixtures/authmeta, loaded as a second namespace) ----
const _amBearerId = 3349796008;
const _amKeyHeaderId = 2562402651;
const _amKeyQueryId = 2366628782;
const _amNs = 'g_authmeta';
bool _amLoaded = false;

Future<void> _authmeta(Ctx c) async {
  if (_amLoaded) return;
  final ByteData raw;
  try {
    raw = await rootBundle.load('assets/axiom/authmeta.axiom');
  } catch (e) {
    skip('assets/axiom/authmeta.axiom missing: run fixtures/authmeta/build.sh ($e)');
  }
  final r = _load(c, _amNs, raw.buffer.asUint8List());
  expectThat(r.ok, 'loading authmeta failed: $r');
  _amLoaded = true;
}

/// Earlier checks (auth_f binding, c.namespace_global_token) may leave a
/// global token, which also applies to this namespace; start from none.
void _noTokens(Ctx c) {
  final rt = c.sdk.runtime;
  try {
    rt.clearGlobalAuthToken();
  } on UnimplementedError {
    // Runtime without global tokens: nothing to clear.
  }
  try {
    rt.clearNamespaceAuthToken(namespace: _amNs);
  } on UnimplementedError {
    // ignore
  }
  for (final m in const ['Authorization', 'x-api-key', 'api_key']) {
    rt.clearAuthToken(namespace: _amNs, methodName: m);
  }
}

/// Raw GET through [ns]; returns (http-ish outcome, decoded body or error).
Future<(bool ok, Object? value)> _get(Ctx c, String ns, int id, String path,
    {Map<String, dynamic>? query, Map<String, String>? headers}) async {
  final r = c.sdk.runtime.callStream(
    namespace: ns,
    endpointId: id,
    method: 'GET',
    path: path,
    queryParams: query,
    headers: headers,
    requestBytes: Uint8List(0),
  );
  final states = <AxiomState<Uint8List>>[];
  final done = Completer<void>();
  r.stream.listen(states.add, onDone: done.complete, onError: (Object e) {
    if (!done.isCompleted) done.complete();
  });
  await done.future.timeout(const Duration(seconds: 10),
      onTimeout: () => throw CheckFailure('$path did not complete: $states'));
  final d = states.where((s) => s.hasData).toList();
  if (d.isNotEmpty) return (true, jsonDecode(utf8.decode(d.last.data!)));
  return (false, states.map((s) => s.error).whereType<AxiomError>().firstOrNull);
}

final List<CheckDef> checksG = [
  // ---- item 2: signed and hash-locked contracts ----
  CheckDef('g.signed_load_trust_signed', 'contract-trust', (c) async {
    final s = await _signed();
    final ns = _ns('signed');
    final r = _load(c, ns, s.bytes, signature: s.signature, publicKey: s.publicKey);
    expectThat(r.ok, 'signed load failed: $r');
    expectEq(r.status, 0, 'status (0 = verified)');
    expectEq(r.trust, AxiomContractTrust.signed, 'trust');
    await _echoThrough(c, ns);
  }),
  CheckDef('g.locked_load_right_sha256', 'contract-trust', (c) async {
    final s = await _signed();
    final ns = _ns('locked');
    final r = _load(c, ns, s.bytes,
        signature: s.signature, publicKey: s.publicKey, sha256: s.sha256);
    expectThat(r.ok, 'locked load failed: $r');
    expectEq(r.status, 0, 'status');
    expectEq(r.trust, AxiomContractTrust.locked, 'trust');
    await _echoThrough(c, ns);
  }),
  CheckDef('g.locked_load_wrong_sha256_rejected', 'contract-trust', (c) async {
    final s = await _signed();
    // Flip one hex digit of the right hash.
    final wrong = (s.sha256[0] == '0' ? '1' : '0') + s.sha256.substring(1);
    final r = _load(c, _ns('wrongsha'), s.bytes,
        signature: s.signature, publicKey: s.publicKey, sha256: wrong);
    expectThat(!r.ok, 'wrong sha256 accepted: $r');
    expectEq(r.status, FfiError.invalidContract, 'status');
  }),
  CheckDef('g.tampered_bytes_rejected', 'contract-trust', (c) async {
    final s = await _signed();
    // Find a one-byte change that still parses as a contract (an unsigned
    // load accepts it), so the signed rejection below is the signature's.
    Uint8List? tampered;
    for (var i = s.bytes.length - 1; i >= 0 && i >= s.bytes.length - 4096; i -= 7) {
      final t = Uint8List.fromList(s.bytes);
      t[i] ^= 0x01;
      if (_load(c, _ns('tprobe'), t).ok) {
        tampered = t;
        break;
      }
    }
    if (tampered == null) {
      // Every probed change broke parsing; still require rejection.
      tampered = Uint8List.fromList(s.bytes)..[s.bytes.length - 1] ^= 0x01;
    }
    final signed = _load(c, _ns('tsigned'), tampered,
        signature: s.signature, publicKey: s.publicKey);
    expectThat(!signed.ok, 'tampered bytes accepted with the original signature: $signed');
    final locked = _load(c, _ns('tlocked'), tampered,
        signature: s.signature, publicKey: s.publicKey, sha256: s.sha256);
    expectThat(!locked.ok, 'tampered bytes accepted by the locked load: $locked');
  }),
  CheckDef('g.wrong_key_rejected', 'contract-trust', (c) async {
    final s = await _signed();
    final r = _load(c, _ns('wrongkey'), s.bytes,
        signature: s.signature, publicKey: s.wrongPublicKey);
    expectThat(!r.ok, 'signature accepted with the wrong public key: $r');
    expectEq(r.status, FfiError.invalidContract, 'status');
    final l = _load(c, _ns('wrongkeyl'), s.bytes,
        signature: s.signature, publicKey: s.wrongPublicKey, sha256: s.sha256);
    expectThat(!l.ok, 'locked load accepted the wrong public key: $l');
  }),
  // initialize() uses the same tryLoadContract path (runtime_web.dart
  // _initialize) and is idempotent, so it is not re-run here.
  CheckDef('g.auth_metadata_in_contract', 'auth-metadata', (c) async {
    final raw = await rootBundle.loadString('assets/axiom/authmeta.axiom').catchError(
        (Object e) => skip('assets/axiom/authmeta.axiom missing: run fixtures/authmeta/build.sh'));
    final eps = (jsonDecode(raw)['endpoints'] as List).cast<Map<String, dynamic>>();
    final bearer = eps.firstWhere((e) => e['name'] == 'authBearer');
    final auth = bearer['auth'] as Map<String, dynamic>?;
    expectThat(auth != null, 'authBearer has "auth": null');
    final m = (auth!['methods'] as List).first as Map<String, dynamic>;
    expectEq(m['type'], 'bearer', 'method type');
    expectEq(m['name'], 'Authorization', 'method name');
    expectEq(bearer['id'], _amBearerId, 'endpoint id (update checks_g.dart after build.sh)');
  }),
  CheckDef('g.auth_set_token_injects_bearer', 'auth-metadata', (c) async {
    await _authmeta(c);
    _noTokens(c);
    final rt = c.sdk.runtime;
    rt.clearAuthToken(namespace: _amNs, methodName: 'Authorization');
    final before = await _get(c, _amNs, _amBearerId, '/auth/bearer');
    expectThat(!before.$1, 'authBearer answered without a token: ${before.$2}');
    rt.setAuthToken(namespace: _amNs, methodName: 'Authorization', token: fixtureBearerToken);
    try {
      final after = await _get(c, _amNs, _amBearerId, '/auth/bearer');
      expectThat(after.$1, 'authBearer with setAuthToken: ${after.$2}');
      expectEq((after.$2 as Map)['method'], 'bearer', 'who.method');
    } finally {
      rt.clearAuthToken(namespace: _amNs, methodName: 'Authorization');
    }
    final cleared = await _get(c, _amNs, _amBearerId, '/auth/bearer');
    expectThat(!cleared.$1, 'authBearer still answered after clearAuthToken');
  }),
  CheckDef('g.auth_set_token_injects_api_key_header', 'auth-metadata', (c) async {
    await _authmeta(c);
    _noTokens(c);
    final rt = c.sdk.runtime;
    rt.setAuthToken(namespace: _amNs, methodName: 'x-api-key', token: fixtureApiKey);
    try {
      // No x-api-key header passed by the caller: the runtime adds it.
      final r = await _get(c, _amNs, _amKeyHeaderId, '/auth/api-key-header');
      expectThat(r.$1, 'api key header not injected: ${r.$2}');
      expectEq((r.$2 as Map)['method'], 'apiKey', 'who.method');
    } finally {
      rt.clearAuthToken(namespace: _amNs, methodName: 'x-api-key');
    }
  }),
  CheckDef('g.auth_set_token_injects_api_key_query', 'auth-metadata', (c) async {
    await _authmeta(c);
    _noTokens(c);
    final rt = c.sdk.runtime;
    rt.setAuthToken(namespace: _amNs, methodName: 'api_key', token: fixtureApiKey);
    try {
      final r = await _get(c, _amNs, _amKeyQueryId, '/auth/api-key-query');
      expectThat(r.$1, 'api key query not injected: ${r.$2}');
    } finally {
      rt.clearAuthToken(namespace: _amNs, methodName: 'api_key');
    }
  }),
  CheckDef('g.auth_provider_injects_token', 'auth-metadata', (c) async {
    await _authmeta(c);
    _noTokens(c);
    final rt = c.sdk.runtime;
    rt.clearAuthToken(namespace: _amNs, methodName: 'Authorization');
    final asked = <String>[];
    rt.setAuthProvider((ns, method) async {
      asked.add('$ns/$method');
      return ns == _amNs ? fixtureBearerToken : null;
    });
    try {
      final r = await _get(c, _amNs, _amBearerId, '/auth/bearer');
      expectThat(asked.isNotEmpty, 'auth provider was never asked');
      expectThat(asked.first.startsWith('$_amNs/'), 'provider asked for ${asked.first}');
      expectThat(r.$1, 'authBearer with provider token: ${r.$2} (asked: $asked)');
    } finally {
      rt.setAuthProvider(null);
      rt.clearAuthToken(namespace: _amNs, methodName: 'Authorization');
    }
  }),
];
