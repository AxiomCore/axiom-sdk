// AxiomBuilder / AxiomMutationBuilder dispose and the query-manager
// cancellation rule, without a native runtime (fake streams).
import 'dart:async';

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:axiom_flutter/src/query_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AxiomQueryManager().clear());

  AxiomQuery<String> sharedQuery(
    String key,
    StreamController<AxiomState<String>> source,
    List<int> cancelled,
  ) => AxiomQuery<String>(
    key,
    (_) => AxiomQueryManager().watchRaw<String>(
      key,
      null,
      create: (_) => AxiomActiveStream<String>(42, source.stream),
      cancel: (id) {
        cancelled.add(id);
        return true;
      },
    ),
  );

  testWidgets('AxiomBuilder dispose cancels the in-flight request', (t) async {
    final source = StreamController<AxiomState<String>>.broadcast();
    final cancelled = <int>[];
    final q = sharedQuery('k1', source, cancelled);
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AxiomBuilder<String, String>(
          query: q,
          builder: (_, _, data) => Text(data),
          loading: (_) => const Text('loading'),
        ),
      ),
    );
    source.add(AxiomState.loading());
    await t.pump();
    expect(find.text('loading'), findsOneWidget);
    expect(source.hasListener, isTrue);

    await t.pumpWidget(const SizedBox());
    expect(cancelled, [42], reason: 'last listener left while loading');
    expect(source.hasListener, isFalse);
    await source.close();
  });

  testWidgets('two builders share a query; only the last dispose cancels', (
    t,
  ) async {
    final source = StreamController<AxiomState<String>>.broadcast();
    final cancelled = <int>[];
    final q = sharedQuery('k2', source, cancelled);
    Widget builder() => AxiomBuilder<String, String>(
      query: q,
      builder: (_, _, data) => Text(data),
    );
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [builder(), builder()]),
      ),
    );
    source.add(AxiomState.loading());
    await t.pump();
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [builder()]),
      ),
    );
    expect(cancelled, isEmpty);
    source.add(AxiomState.success('v', AxiomSource.network));
    await t.pump();
    await t.pump();
    expect(find.text('v'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    expect(cancelled, isEmpty, reason: 'response already delivered');
    await source.close();
  });

  testWidgets('AxiomMutationBuilder dispose unsubscribes without cancelling', (
    t,
  ) async {
    final source = StreamController<AxiomState<String>>.broadcast();
    final mutation = AxiomMutation<String, int>(
      (args) => AxiomQuery<String>(
        'm$args',
        (_) => AxiomActiveStream<String>(7, source.stream),
        isMutation: true,
      ),
    );
    late void Function(int) execute;
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AxiomMutationBuilder<String, int>(
          mutation: mutation,
          builder: (_, state, run) {
            execute = run;
            return Text(state.isMutating ? 'busy' : 'idle');
          },
        ),
      ),
    );
    execute(1);
    await t.pump();
    expect(find.text('busy'), findsOneWidget);
    expect(source.hasListener, isTrue);
    await t.pumpWidget(const SizedBox());
    expect(source.hasListener, isFalse);
    await source.close();
  });

  test('watching after final data starts a fresh call; during a call joins it', () async {
    final sources = <StreamController<AxiomState<String>>>[];
    AxiomQuery<String> q() => AxiomQuery<String>(
      'fresh',
      (_) => AxiomQueryManager().watchRaw<String>(
        'fresh',
        null,
        create: (_) {
          final c = StreamController<AxiomState<String>>.broadcast();
          sources.add(c);
          return AxiomActiveStream<String>(sources.length, c.stream);
        },
        cancel: (_) => true,
      ),
    );
    final a = <AxiomState<String>>[];
    final subA = q().stream.listen(a.add);
    await Future<void>.delayed(Duration.zero);
    expect(sources.length, 1);
    // Joins the running call and gets the current state, no new request.
    final b = <AxiomState<String>>[];
    final subB = q().stream.listen(b.add);
    await Future<void>.delayed(Duration.zero);
    expect(sources.length, 1);
    sources[0].add(AxiomState.success('v1', AxiomSource.network));
    await Future<void>.delayed(Duration.zero);
    expect(b.last.data, 'v1');
    // Final data delivered but Complete not yet received: a new watcher
    // starts a fresh call (networkOnly endpoints must hit the network).
    final c = <AxiomState<String>>[];
    final subC = q().stream.listen(c.add);
    await Future<void>.delayed(Duration.zero);
    expect(sources.length, 2);
    sources[1].add(AxiomState.success('v2', AxiomSource.network));
    await Future<void>.delayed(Duration.zero);
    expect(a.last.data, 'v2');
    expect(c.last.data, 'v2');
    await subA.cancel();
    await subB.cancel();
    await subC.cancel();
  });
}
