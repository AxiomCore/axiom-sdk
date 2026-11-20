import 'dart:async';

import 'package:axiom_flutter/axiom_flutter.dart';

import '../axiom_generated/axiom_sdk.dart';
import '../axiom_generated/models.dart';
import 'ctx.dart';

/// Generator (unit d) checks: generated types, typed failures, streams,
/// channels, call options, mutation invalidation and validators.
///
/// Checks that need a runtime member still throwing UnimplementedError
/// report SKIP with the member name.
Future<void> _pendingAware(Future<void> Function() body) async {
  try {
    await body();
  } on UnimplementedError catch (e) {
    skip('pending runtime: ${e.message}');
  }
}

final dChecks = <CheckDef>[
  CheckDef('gen.enum_type', 'generator', (c) async {
    final r = await data(c.api.everything());
    expectEq(r.color, EverythingColor.green, 'enum field');
    expectEq(EverythingColor.fromJson('purple'), EverythingColor.unknown,
        'unknown-value fallback');
    expectEq(r.color.toJson(), 'green', 'enum toJson');
  }),
  CheckDef('gen.model_value_semantics', 'generator', (c) async {
    final a = await data(c.api.everything());
    final b = Everything.fromJson(a.toJson());
    expectEq(b, a, 'fromJson(toJson()) ==');
    expectEq(b.hashCode, a.hashCode, 'hashCode');
    final changed = a.copyWith(note: 'n', id: 'e2');
    expectEq(changed.note, 'n', 'copyWith optional');
    expectEq(changed.id, 'e2', 'copyWith required');
    expectEq(changed.copyWith(note: null).note, null, 'copyWith sets null');
    expectThat(a.toString().startsWith('Everything(color: '), 'toString: $a');
    expectEq(a.scalars.bytes.toList().toString(), '[1, 2, 3]', 'base64 bytes');
  }),
  CheckDef('gen.typed_failure_when', 'failures', (c) async {
    final e = await failure(c.api.claim(name: 'taken'));
    final existing = e.whenClaim(
      conflict: (f) => f.existingId,
      orElse: (err) => 'other: $err / ${err.details}',
    );
    expectEq(existing, 'item-0', 'whenClaim(conflict)');
    final f = e.contractFailure;
    expectThat(f is ConflictFailure && f.message == 'name already taken',
        'contractFailure: $f');
    final ok = await data(c.api.claim(name: 'free'));
    expectEq(ok.id, 'item-2', 'success path');
  }),
  CheckDef('gen.typed_failure_unauthorized', 'failures', (c) async {
    final e = await failure(c.api.authApiKeyHeader(xApiKey: 'nope'));
    final f = e.authApiKeyHeaderFailure;
    expectThat(f is UnauthorizedFailure && f.message == 'bad api key',
        'authApiKeyHeaderFailure: $f (error $e / ${e.details})');
  }),
  CheckDef('gen.body_multi_field', 'unary', (c) async {
    final r = await data(c.api.createItem(name: 'pen', qty: 2));
    expectEq(r.name, 'pen', 'name');
    expectEq(r.qty, 2, 'qty');
  }),
  CheckDef('gen.call_options_refresh', 'cache', (c) => _pendingAware(() async {
        final n = 'opt-${DateTime.now().microsecondsSinceEpoch}';
        await data(c.api.cacheCacheFirst(nonce: n));
        final s = await settle(c.api.cacheCacheFirst(
          nonce: n,
          options: const AxiomCallOptions(cacheMode: AxiomCacheMode.refresh),
        ));
        expectEq(s.data?.key, n, 'key');
        expectEq(s.source, AxiomSource.network, 'source with cacheMode.refresh');
      })),
  CheckDef('gen.mutation_invalidates_active_query', 'cache', (c) => _pendingAware(() async {
        c.sdk.runtime.invalidate(namespace: 'fixture', endpointId: -1);
        final n = 'inv-${DateTime.now().microsecondsSinceEpoch}';
        final query = c.api.cachedItem(id: 'y', nonce: n);
        var successes = 0;
        final second = Completer<void>();
        final sub = query.stream.listen((s) {
          if (s.status == AxiomStatus.success && !s.isFetching) {
            successes++;
            if (successes >= 2 && !second.isCompleted) second.complete();
          }
        });
        try {
          await query.stream.firstWhere((s) => s.status == AxiomStatus.success);
          await data(c.api.touchItem(id: 'y', nonce: n));
          await second.future.timeout(const Duration(seconds: 10),
              onTimeout: () => throw CheckFailure('active query was not refetched'));
        } finally {
          await sub.cancel();
        }
      })),
  CheckDef('gen.sse_stream', 'streams', (c) => _pendingAware(() async {
        c.api.axiom.setAuthToken('sse', fixtureBearerToken);
        try {
          final t = await c.api.sseStream().first.timeout(const Duration(seconds: 10));
          expectEq(t.id, 't1', 'frame id');
          expectEq(t.seq, 1, 'frame seq');
        } finally {
          c.api.axiom.clearAuthToken('sse');
        }
      })),
  CheckDef('gen.chunked_stream', 'streams', (c) => _pendingAware(() async {
        final t = await c.api.chunkedStream().first.timeout(const Duration(seconds: 10));
        expectEq(t.seq, 1, 'frame seq');
      })),
  CheckDef('gen.ws_channel', 'streams', (c) => _pendingAware(() async {
        c.api.axiom.setAuthToken('wsEcho', fixtureBearerToken);
        final channel = c.api.wsEchoChannel();
        try {
          final reply = channel.stream
              .firstWhere((s) => s.data != null || s.error != null)
              .timeout(const Duration(seconds: 10));
          channel.send(const Ping(text: 'typed', seq: 3));
          final s = await reply;
          expectThat(s.error == null, 'channel error: ${s.error}');
          expectEq(s.data?.text, 'typed', 'echo text');
        } finally {
          await channel.close();
          c.api.axiom.clearAuthToken('wsEcho');
        }
      })),
  CheckDef('gen.validators', 'generator', (c) async {
    expectEq(EverythingValidators.color('red'), null, 'valid enum value');
    expectThat(EverythingValidators.color('pink') != null, 'invalid enum value');
    expectThat(EverythingValidators.color('') != null, 'required');
    expectThat(EverythingValidators.all.containsKey('color'), 'validator map');
  }),
  CheckDef('gen.namespace_metadata', 'generator', (c) async {
    expectEq(FixtureModule.cacheIdentities['fixture.item']?.single,
        FixtureModule.endpointIds['cachedItem'], 'cacheIdentity map');
  }),
];
