import 'ctx.dart';

final typeChecks = <CheckDef>[
  CheckDef('types.scalars', 'models', (c) async {
    final r = await data(c.api.everything());
    final s = r.scalars;
    expectEq(s.s, 'hello', 'String');
    expectEq(s.b, true, 'Bool');
    expectEq(s.i32, 2147483647, 'Int32');
    // Compared as text: dart2js cannot hold 2^53+1 exactly, which is what this proves on web.
    expectEq('${s.i64}', '9007199254740993', 'Int64 exact');
    expectEq(s.f32, 1.5, 'Float32');
    expectEq(s.f64, 3.141592653589793, 'Float64');
    expectEq(s.bytes.toList().toString(), '[1, 2, 3]', 'Bytes');
    expectEq(s.at.toUtc(), DateTime.utc(2026, 11, 20, 12), 'DateTime');
    expectThat(s.json is Map && (s.json as Map)['nested'] is Map, 'Json: got ${s.json}');
  }),
  CheckDef('types.collections_nested_optional', 'models', (c) async {
    final r = await data(c.api.everything());
    expectEq(r.tags.join(','), 'a,b', 'List<String>');
    expectEq(r.inner.label, 'in', 'nested model');
    expectEq(r.inners.length, 2, 'List<Model>');
    expectEq(r.inners[1].depth, 1, 'List<Model>[1].depth');
    expectEq(r.note, null, 'Optional omitted');
    expectEq(r.counts, null, 'Optional<Map> omitted');
  }),
  CheckDef('types.enum_field', 'models', (c) async {
    final r = await data(c.api.everything());
    // The contract carries an enum validation rule; generator 0.146 emits String.
    expectEq(r.color.toJson(), 'green', 'enum value');
  }),
  CheckDef('types.enum_generated_type', 'generator', (c) async {
    skip('pending: generator unit (enum rule emitted as String, not a Dart enum)');
  }),
  CheckDef('types.union', 'generator', (c) async {
    skip('pending: backend profile has no union type (CLI 0.156.0); see fixtures/README.md');
  }),
];
