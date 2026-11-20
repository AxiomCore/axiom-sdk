import 'package:axiom_flutter/src/internal/query_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F7: headers and timeout are part of the key, volatile headers not', () {
    String k({Map<String, String>? h, Duration? t}) =>
        AxiomQueryKey.build(endpoint: 'ns_1', args: {'id': 1}, headers: h, timeout: t);
    expect(k(), 'ns_1:{"id":1}'); // unchanged without headers (setQueryData keys)
    expect(k(h: {}), k());
    expect(k(h: {'X-Tenant': 'a'}), isNot(k(h: {'X-Tenant': 'b'})));
    expect(k(h: {'X-Tenant': 'a'}), isNot(k()));
    expect(k(h: {'a': '1', 'b': '2'}), k(h: {'b': '2', 'A': '1'}));
    expect(k(h: {'traceparent': 'x', 'Idempotency-Key': 'y', 'x-axiom-cache-mode': 'refresh'}), k());
    expect(k(t: const Duration(seconds: 1)), isNot(k(t: const Duration(seconds: 2))));
  });
}
