// Name collisions (review F11) and unknown enum values (review F14).
//
// The collisions contract has fields, parameters, endpoints, enum values and
// failure codes that collide after camel-casing, with reserved words and with
// generated members. The output is a golden, and every generated models.dart
// (collisions, fixture, extras) is compiled and run with the Dart VM against
// a small stand-in for package:axiom_flutter.
//
// Update after an intended change: UPDATE_GOLDENS=1 dart test
import 'dart:convert';
import 'dart:io';

import 'package:axiom_flutter_generator/axiom_flutter_generator.dart';
import 'package:test/test.dart';

final _root = Directory('test/golden');

ContractInput _input(String file, String namespace) => ContractInput(
  namespace: namespace,
  contract: jsonDecode(File('${_root.path}/$file').readAsStringSync()) as Map<String, dynamic>,
  assetPath: 'assets/axiom/$namespace.axiom',
);

Future<String> _format(String name, String content) async {
  final dir = Directory.systemTemp.createTempSync('axiom_golden_');
  final f = File('${dir.path}/$name')..writeAsStringSync(content);
  final r = await Process.run(Platform.resolvedExecutable, ['format', f.path]);
  expect(r.exitCode, 0, reason: 'dart format failed: ${r.stderr}');
  return f.readAsStringSync();
}

const _stub = '''
class AxiomError {
  const AxiomError({this.failureCode, this.failurePayload, this.details});
  final String? failureCode;
  final Object? failurePayload;
  final String? details;
}

abstract final class AxiomFailureRegistry {
  static void register(String code, Object? Function(Object?) decode, {String? namespace}) {}
}
''';

/// Compiles [models] (with [main] appended as a second library) and runs it.
Future<ProcessResult> _run(String models, String main) async {
  final dir = Directory.systemTemp.createTempSync('axiom_models_');
  File('${dir.path}/axiom_flutter.dart').writeAsStringSync(_stub);
  File('${dir.path}/models.dart').writeAsStringSync(
    models.replaceFirst("import 'package:axiom_flutter/axiom_flutter.dart';", "import 'axiom_flutter.dart';"),
  );
  File('${dir.path}/main.dart').writeAsStringSync(main);
  return Process.run(Platform.resolvedExecutable, ['run', '${dir.path}/main.dart']);
}

void main() {
  late Map<String, String> files;
  setUpAll(() => files = generate([_input('collisions/collisions.axiom', 'collisions')]));

  test('collisions golden', () async {
    final update = Platform.environment['UPDATE_GOLDENS'] == '1';
    for (final e in files.entries) {
      final out = await _format(e.key, e.value);
      final golden = File('${_root.path}/collisions/expected/${e.key}.golden');
      if (update) {
        golden
          ..createSync(recursive: true)
          ..writeAsStringSync(out);
        continue;
      }
      expect(out, golden.readAsStringSync(), reason: '${e.key} differs from ${golden.path}');
    }
  });

  test('disambiguated names, JSON keys untouched', () async {
    final models = files['models.dart']!;
    final sdk = await _format('axiom_sdk.dart', files['axiom_sdk.dart']!);
    String ep(String name, int id) =>
        '$name({AxiomCallOptions? options}) {\n    return _runtime.send<models.Todo>(\n'
        '      namespace: _namespace,\n      endpointId: $id,';
    for (final decl in [
      'final String userId;', 'final String? userId2;', 'final String userId3;', 'final TodoLevel2 level;', 'final TodoLevel3? level2;',
      r'final String $toJson;', r'final String $copyWith;', r'final String $hashCode;',
      r'final int $hashCode2;', r'final String $class;', r'final String $other;', r'final String? $identical;',
    ]) {
      expect(models, contains(decl));
    }
    for (final key in ["'user_id'", "'userId'", "'user-id'", "'toJson'", "'copy_with'", "'hash_code'", "'hashCode'"]) {
      expect(models, contains('$key: '), reason: 'JSON key $key kept');
    }
    // Endpoints: `getUser` keeps its name; get-user, get_user (sorted) follow.
    expect(sdk, contains(ep('getUser', 2)));
    expect(sdk, contains(ep('getUser2', 3)));
    expect(sdk, contains('AxiomQuery<models.Todo> getUser3('));
    expect(sdk, contains('AxiomQuery<models.Todo> axiom2('));
    expect(sdk, contains(r'AxiomQuery<models.Todo> $hashCode('));
    expect(sdk, contains('Stream<models.Todo> feedStream('));
    expect(sdk, contains('AxiomQuery<models.Todo> feedStream2('));
    // Parameters of get_user: unique and not shadowing generated locals.
    for (final p in [
      'required String userId', 'required String userId2', r'required String $headers', r'required String $options',
      r'required String $models', r'required String $e', r'required String $jsonEncode', r'required String $class',
    ]) {
      expect(sdk, contains(p));
    }
    // Derived type names get a suffix next to the contract's TodoLevel.
    expect(models, contains('enum TodoLevel2 implements AxiomGeneratedEnum'));
    expect(models, contains('enum TodoLevel3 implements AxiomGeneratedEnum'));
    expect(models, contains('class NotFoundFailure2 '));
  });

  test('every generated models.dart compiles; unknown enum values round-trip', () async {
    final all = {
      'collisions': files['models.dart']!,
      'fixture': generate([_input('fixture/fixture.axiom', 'fixture')])['models.dart']!,
      'extras': generate([_input('extras/extras.axiom', 'extras')])['models.dart']!,
    };
    for (final e in all.entries.where((e) => e.key != 'collisions')) {
      final r = await _run(e.value, "import 'models.dart';\nvoid main() { print(AxiomGeneratedCodec.asInt('1')); }\n");
      expect(r.exitCode, 0, reason: '${e.key}: ${r.stdout}\n${r.stderr}');
    }
    final r = await _run(all['collisions']!, r'''
import 'dart:convert';
import 'models.dart';

void check(bool ok, String what) {
  if (!ok) throw StateError('FAILED: $what');
}

void main() {
  final wire = {
    'user_id': 'a', 'userId': 'b', 'user-id': 'c', 'toJson': 'd', 'copy_with': 'e', 'hashCode': 'f', 'hash_code': 1,
    'class': 'g', 'other': 'h', 'status': 'archived', 'tags': ['active', 'archived'], 'prev_status': 'ACTIVE',
    'by_status': {'x': 'gone'}, 'level': 'low',
  };
  final t = Todo.fromJson(wire);
  check(t.status == Status.$unknown && t.status.isUnknown, 'decoded unknown');
  check(Status.fromJson('unknown') == Status.unknown && !Status.unknown.isUnknown, 'wire value "unknown" is a real value');
  check(t.prevStatus == Status.aCTIVE, 'ACTIVE value kept distinct');
  final back = t.toJson();
  check(back.length == wire.length && wire.keys.every((k) => jsonEncode(back[k]) == jsonEncode(wire[k])),
      'round trip keeps unknown wire values: ${jsonEncode(back)}');
  final renamed = t.copyWith(userId: 'z');
  check(renamed.toJson()['status'] == 'archived', 'copyWith keeps raw status');
  check(jsonEncode(renamed.toJson()['tags']) == '["active","archived"]', 'copyWith keeps raw tags');
  final fixed = t.copyWith(status: Status.active, tags: [Status.active]);
  check(fixed.toJson()['status'] == 'active', 'replaced status is encoded');
  check(jsonEncode(fixed.toJson()['tags']) == '["active"]', 'replaced tags are encoded');
  check(fixed.toJson()['by_status'] is Map && (fixed.toJson()['by_status'] as Map)['x'] == 'gone', 'other raw kept');
  check(t.copyWith(byStatus: null).toJson().containsKey('by_status') == false, 'cleared optional dropped');
  check(t == Todo.fromJson(wire), 'equality ignores raw');
  var threw = false;
  try {
    Status.$unknown.toJson();
  } on StateError {
    threw = true;
  }
  check(threw, 'unknown without a wire value throws instead of inventing one');
  threw = false;
  try {
    Todo.fromJson({...wire, 'status': 'active'}).copyWith(status: Status.$unknown).toJson();
  } on StateError {
    threw = true;
  }
  check(threw, 'explicit unknown is never sent as a made-up value');
  check(FormValidators.all.length == 2 && FormValidators.all['all'] == FormValidators.all3 && FormValidators.all3('') != null, 'validators unique');
  print('ok');
}
''');
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect('${r.stdout}', contains('ok'));
  });

  test('contract type names that collide are rejected', () {
    final c = _input('collisions/collisions.axiom', 'collisions');
    final models = (c.contract['ir'] as Map)['models'] as Map;
    models['todo'] = {'name': 'todo', 'fields': <String, dynamic>{}};
    expect(
      () => generate([c]),
      throwsA(isA<GeneratorException>().having((e) => e.message, 'message', contains('"Todo"'))),
    );
  });

  test('namespaces mapping to one module class are rejected', () {
    expect(
      () => generate([_input('fixture/fixture.axiom', 'my_api'), _input('fixture/fixture.axiom', 'myApi')]),
      throwsA(isA<GeneratorException>()),
    );
  });
}
