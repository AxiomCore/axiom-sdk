import 'package:axiom_fixture_app/checks/all.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('check names are unique', () {
    final names = allChecks.map((c) => c.name).toList();
    expect(names.toSet().length, names.length);
  });
}
