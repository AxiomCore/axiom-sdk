import 'package:axiom_flutter/axiom_flutter.dart';

import 'ctx.dart';

/// Calls twice with the same args; the second settled state's source tells
/// whether the runtime cache answered.
Future<AxiomState<T>> _second<T>(AxiomQuery<T> Function() make) async {
  await data(make());
  return settle(make());
}

final cacheChecks = <CheckDef>[
  CheckDef('cache.network_only', 'cache', (c) async {
    final n = 'no-${DateTime.now().microsecondsSinceEpoch}';
    final s = await _second(() => c.api.cacheNetworkOnly(xFixtureNonce: n));
    expectEq(s.data?.key, n, 'key');
    expectEq(s.source, AxiomSource.network, 'source of 2nd call');
  }),
  CheckDef('cache.cache_first', 'cache', (c) async {
    final n = 'cf-${DateTime.now().microsecondsSinceEpoch}';
    final s = await _second(() => c.api.cacheCacheFirst(xFixtureNonce: n));
    expectEq(s.data?.key, n, 'key');
    expectEq(s.source, AxiomSource.cache, 'source of 2nd call');
  }),
  CheckDef('cache.network_first', 'cache', (c) async {
    final n = 'nf-${DateTime.now().microsecondsSinceEpoch}';
    final s = await _second(() => c.api.cacheNetworkFirst(xFixtureNonce: n));
    expectEq(s.data?.key, n, 'key');
  }),
  CheckDef('cache.stale_while_revalidate', 'cache', (c) async {
    final n = 'swr-${DateTime.now().microsecondsSinceEpoch}';
    final s = await _second(() => c.api.cacheStale(xFixtureNonce: n));
    expectEq(s.data?.key, n, 'key');
    expectEq(s.source, AxiomSource.cache, 'first emitted source of 2nd call');
  }),
  CheckDef('cache.identity_invalidates', 'cache', (c) async {
    final n = 'ci-${DateTime.now().microsecondsSinceEpoch}';
    await data(c.api.cachedItem(id: 'x', xFixtureNonce: n));
    await data(c.api.touchItem(id: 'x', xFixtureNonce: n));
    final s = await settle(c.api.cachedItem(id: 'x', xFixtureNonce: n));
    expectEq(s.source, AxiomSource.network, 'source after invalidates(fixture.item)');
  }),
  CheckDef('cache.forced_refresh', 'cache', (c) async {
    skip('pending: f1 (query.refresh(force: true) -> x-axiom-cache-mode: refresh)');
  }),
  CheckDef('cache.set_get_query_data', 'cache', (c) async {
    skip('pending: f1 (setQueryData, getCachedQueryData)');
  }),
  CheckDef('cache.clear_purge', 'cache', (c) async {
    skip('pending: f1 (clearCache, purgeCache, invalidate(cacheIdentity))');
  }),
  CheckDef('retry.policy_success', 'retry', (c) async {
    final r = await data(c.api.retried(attempt: 1));
    expectEq(r.ok, true, 'ok');
  }),
  CheckDef('retry.on_503', 'retry', (c) async {
    skip('pending: fixture cannot fail transiently (managed code is stateless); needs a fault-injecting proxy');
  }),
];
