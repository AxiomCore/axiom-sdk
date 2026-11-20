import 'dart:typed_data';

import 'ctx.dart';

final unaryChecks = <CheckDef>[
  CheckDef('unary.get_path_query', 'unary', (c) async {
    final r = await data(c.api.echo(path: 'abc', q: 'hi there', limit: 3, flag: true));
    expectEq(r.path, 'abc', 'path');
    expectEq(r.q, 'hi there', 'q');
    expectEq(r.limit, 3, 'limit');
    expectEq(r.flag, true, 'flag');
  }),
  CheckDef('unary.get_optional_query_omitted', 'unary', (c) async {
    final r = await data(c.api.echo(path: 'p', q: 'x', limit: 0));
    expectEq(r.flag, null, 'flag');
  }),
  CheckDef('unary.post_json', 'unary', (c) async {
    final r = await data(c.api.createItem(name: 'pen', qty: 2));
    expectEq(r.id, 'item-1', 'id');
    expectEq(r.name, 'pen', 'name');
    expectEq(r.qty, 2, 'qty');
  }),
  CheckDef('unary.put_json', 'unary', (c) async {
    final r = await data(c.api.updateItem(id: 'i9', name: 'cup', qty: 5));
    expectEq(r.id, 'i9', 'id');
    expectEq(r.qty, 5, 'qty');
  }),
  CheckDef('unary.delete', 'unary', (c) async {
    final r = await data(c.api.deleteItem(id: 'i9'));
    expectEq(r.deleted, true, 'deleted');
    expectEq(r.id, 'i9', 'id');
  }),
  CheckDef('unary.bytes_body', 'unary', (c) async {
    final r = await data(c.api.uploadBytes(data: Uint8List.fromList([1, 2, 3])));
    expectEq(r.data.toList().toString(), '[1, 2, 3]', 'echoed bytes');
  }),
];
