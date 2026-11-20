// The shared Authorization rule used by native (runtime_io.dart) and web
// (runtime_web.dart): a token stored for one namespace never reaches another.
import 'package:axiom_flutter/src/internal/auth_headers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('namespace token is scoped to its namespace', () {
    final tokens = {'bound': 't'};
    expect(AxiomAuthHeaders.explicitTokenFor('bound', tokens, null), 't');
    expect(AxiomAuthHeaders.explicitTokenFor('other', tokens, null), isNull);
    expect(AxiomAuthHeaders.explicitTokenFor('', tokens, null), isNull);
    expect(AxiomAuthHeaders.explicitTokenFor('other', tokens, 'g'), 'g');
  });

  test('withBearer adds a header only for a token', () {
    expect(AxiomAuthHeaders.withBearer(null, null), isNull);
    expect(AxiomAuthHeaders.withBearer({'a': 'b'}, ''), {'a': 'b'});
    expect(AxiomAuthHeaders.withBearer(null, 't'), {'Authorization': 'Bearer t'});
    expect(AxiomAuthHeaders.withBearer({'authorization': 'x'}, 't'),
        {'authorization': 'x'});
  });
}
