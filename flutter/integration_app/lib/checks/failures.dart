import 'ctx.dart';

final failureChecks = <CheckDef>[
  CheckDef('failure.typed_409_status', 'failures', (c) async {
    final e = await failure(c.api.claim(name: 'taken'));
    expectEq(httpStatusOf(e), 409, 'HTTP status (error: $e)');
  }),
  CheckDef('failure.typed_409_payload', 'failures', (c) async {
    final e = await failure(c.api.claim(name: 'taken'));
    final text = '${e.message} ${e.details ?? ''}';
    expectThat(text.contains('conflict') || text.contains('name already taken'),
        'error carries neither code nor payload: $e / ${e.details}');
  }),
  CheckDef('failure.typed_class', 'failures', (c) async {
    skip('pending: f1/generator (AxiomError.failureCode, failurePayload, generated Conflict failure)');
  }),
  CheckDef('failure.success_path', 'failures', (c) async {
    final r = await data(c.api.claim(name: 'free'));
    expectEq(r.id, 'item-2', 'id');
  }),
];
