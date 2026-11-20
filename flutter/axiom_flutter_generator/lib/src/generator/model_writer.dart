import 'schema.dart';
import 'types.dart';
import 'utils.dart';

/// Writes models.dart: codec helpers, enums, unions, models, validators and
/// typed contract failures.
class ModelWriter {
  final Schema schema;
  final String header;

  ModelWriter(this.schema, {required this.header});

  TypeMapper get m => schema.mapper;

  String write() {
    final b = StringBuffer();
    b.writeln(header);
    b.writeln();
    b.writeln("import 'dart:convert';");
    b.writeln("import 'dart:typed_data';");
    b.writeln();
    b.writeln("import 'package:axiom_flutter/axiom_flutter.dart';");
    b.writeln();
    if (schema.models.values.any((m) => m.fields.any((f) => f.optional)) ||
        schema.failures.values.any((f) => f.fields.any((x) => x.optional))) {
      b.writeln('const Object _unset = Object();');
      b.writeln();
    }
    _writeCodec(b);

    for (final name in schema.enums.keys.toList()..sort()) {
      _writeEnum(b, schema.enums[name]!);
    }
    for (final name in schema.unions.keys.toList()..sort()) {
      _writeUnion(b, schema.unions[name]!);
    }
    for (final name in schema.models.keys.toList()..sort()) {
      _writeModel(b, schema.models[name]!);
      _writeValidators(b, schema.models[name]!);
    }
    _writeFailures(b);
    return b.toString();
  }

  // ---------------------------------------------------------------------------

  void _writeCodec(StringBuffer b) {
    b.write(r'''
/// JSON helpers used by the generated models and client.
abstract final class AxiomGeneratedCodec {
  static String asString(Object? v) => v as String;
  static bool asBool(Object? v) => v as bool;
  static Object? asJson(Object? v) => v;
  static void asVoid(Object? v) {}

  static int asInt(Object? v) => switch (v) {
    int() => v,
    num() => v.toInt(),
    String() => int.parse(v),
    _ => throw FormatException('expected an integer, got $v'),
  };

  static double asDouble(Object? v) => switch (v) {
    num() => v.toDouble(),
    String() => double.parse(v),
    _ => throw FormatException('expected a number, got $v'),
  };

  static DateTime asDateTime(Object? v) => switch (v) {
    String() => DateTime.parse(v),
    int() => DateTime.fromMillisecondsSinceEpoch(v, isUtc: true),
    _ => throw FormatException('expected a date-time, got $v'),
  };

  /// Bytes travel as base64 strings; a list of ints is accepted too.
  static Uint8List asBytes(Object? v) => switch (v) {
    String() => base64Decode(v),
    List() => Uint8List.fromList(v.cast<int>()),
    _ => throw FormatException('expected bytes, got $v'),
  };

  static String bytesToJson(Uint8List v) => base64Encode(v);

  static Map<String, dynamic> asObject(Object? v) =>
      (v as Map).cast<String, dynamic>();

  static List<T> asList<T>(Object? v, T Function(Object?) item) => [
    for (final e in v as List) item(e),
  ];

  static Map<String, T> asMap<T>(Object? v, T Function(Object?) value) => {
    for (final e in (v as Map).entries) e.key as String: value(e.value),
  };

  static Map<K, T> asKeyedMap<K, T>(
    Object? v,
    K Function(String) key,
    T Function(Object?) value,
  ) => {
    for (final e in (v as Map).entries) key(e.key as String): value(e.value),
  };

  static bool deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final e in a.entries) {
        if (!b.containsKey(e.key) || !deepEquals(e.value, b[e.key])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }

  static int deepHash(Object? v) => switch (v) {
    List() => Object.hashAll(v.map(deepHash)),
    Map() => Object.hashAllUnordered(
      v.entries.map((e) => Object.hash(deepHash(e.key), deepHash(e.value))),
    ),
    _ => v.hashCode,
  };

  /// Code and payload of a contract failure carried by [error]: the
  /// runtime's `failureCode`/`failurePayload`, else the server body in
  /// `details` (`{"error": {"code": ..., "payload": ...}}`).
  static (String?, Object?) failureParts(AxiomError error) {
    if (error.failureCode != null) {
      return (error.failureCode, error.failurePayload);
    }
    final details = error.details;
    if (details == null || details.isEmpty) return (null, null);
    try {
      final decoded = jsonDecode(details);
      if (decoded is Map) {
        final body = decoded['error'] is Map ? decoded['error'] as Map : decoded;
        final code = body['code'] ?? body['failure_code'];
        if (code is String) {
          return (code, body['payload'] ?? body['failure_payload']);
        }
      }
    } on FormatException {
      return (null, null);
    }
    return (null, null);
  }
}

''');
  }

  // ---------------------------------------------------------------------------

  void _writeEnum(StringBuffer b, EnumSpec e) {
    final used = <String>{'values', 'index', 'name', 'value', 'fromJson', 'toJson'};
    final members = <(String, String)>[];
    for (final v in e.values) {
      var id = GeneratorUtils.identifier(v);
      if (used.contains(id)) id = '\$$id';
      var n = 2;
      final base = id;
      while (used.contains(id)) {
        id = '$base${n++}';
      }
      used.add(id);
      members.add((id, v));
    }
    var unknown = 'unknown';
    while (used.contains(unknown)) {
      unknown = '\$$unknown';
    }

    b.write(GeneratorUtils.docComment(e.doc, ''));
    b.writeln('enum ${e.dartName} {');
    for (final (id, v) in members) {
      b.writeln('  $id(${GeneratorUtils.str(v)}),');
    }
    b.writeln('');
    b.writeln('  /// A value this client version does not know.');
    b.writeln('  $unknown(null);');
    b.writeln();
    b.writeln('  const ${e.dartName}(this.value);');
    b.writeln();
    b.writeln('  /// Wire value; null for [$unknown].');
    b.writeln('  final String? value;');
    b.writeln();
    b.writeln('  static ${e.dartName} fromJson(Object? json) {');
    b.writeln('    for (final v in values) {');
    b.writeln('      if (v.value == json) return v;');
    b.writeln('    }');
    b.writeln('    return $unknown;');
    b.writeln('  }');
    b.writeln();
    b.writeln("  String toJson() => value ?? 'unknown';");
    b.writeln('}');
    b.writeln();
  }

  // ---------------------------------------------------------------------------

  void _writeUnion(StringBuffer b, UnionSpec u) {
    final variants = [
      for (final o in u.options) (o, '${u.dartName}$o'),
    ];
    final unknown = '${u.dartName}Unknown';

    b.writeln('/// One of: ${u.options.join(', ')}.');
    b.writeln('sealed class ${u.dartName} {');
    b.writeln('  const ${u.dartName}();');
    b.writeln();
    b.writeln('  factory ${u.dartName}.fromJson(Object? json) {');
    b.writeln('    if (json is Map) {');
    if (u.discriminator != null) {
      b.writeln('      final tag = json[${GeneratorUtils.str(u.discriminator!)}];');
      b.writeln('      if (tag is String) {');
      b.writeln('        switch (tag.toLowerCase()) {');
      for (final (model, variant) in variants) {
        final tags = _discriminatorTags(model, u.discriminator!);
        b.writeln(
          '          case ${tags.map(GeneratorUtils.str).join(' || ')}:',
        );
        b.writeln('            return $variant($model.fromJson(json));');
      }
      b.writeln('        }');
      b.writeln('      }');
    }
    // Shape match: most specific option (most required keys) first.
    final ordered = [...variants]..sort((a, b) {
      final ka = _requiredKeys(a.$1).length;
      final kb = _requiredKeys(b.$1).length;
      return kb.compareTo(ka);
    });
    for (final (model, variant) in ordered) {
      final keys = _requiredKeys(model);
      final cond = keys.isEmpty
          ? 'true'
          : keys.map((k) => 'json.containsKey(${GeneratorUtils.str(k)})').join(' && ');
      b.writeln('      if ($cond) {');
      b.writeln('        return $variant($model.fromJson(json));');
      b.writeln('      }');
    }
    b.writeln('    }');
    b.writeln('    return $unknown(json);');
    b.writeln('  }');
    b.writeln();
    b.writeln('  Object? toJson();');
    b.writeln('}');
    b.writeln();

    for (final (model, variant) in variants) {
      b.writeln('final class $variant extends ${u.dartName} {');
      b.writeln('  const $variant(this.value);');
      b.writeln('  final $model value;');
      b.writeln();
      b.writeln('  @override');
      b.writeln('  Object? toJson() => value.toJson();');
      b.writeln();
      b.writeln('  @override');
      b.writeln('  bool operator ==(Object other) =>');
      b.writeln('      other is $variant && other.value == value;');
      b.writeln();
      b.writeln('  @override');
      b.writeln('  int get hashCode => value.hashCode;');
      b.writeln();
      b.writeln('  @override');
      b.writeln("  String toString() => '$variant(\$value)';");
      b.writeln('}');
      b.writeln();
    }
    b.writeln('/// A ${u.dartName} value matching no known option.');
    b.writeln('final class $unknown extends ${u.dartName} {');
    b.writeln('  const $unknown(this.raw);');
    b.writeln('  final Object? raw;');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  Object? toJson() => raw;');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  bool operator ==(Object other) =>');
    b.writeln('      other is $unknown && AxiomGeneratedCodec.deepEquals(other.raw, raw);');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  int get hashCode => AxiomGeneratedCodec.deepHash(raw);');
    b.writeln();
    b.writeln('  @override');
    b.writeln("  String toString() => '$unknown(\$raw)';");
    b.writeln('}');
    b.writeln();
  }

  List<String> _requiredKeys(String modelDart) {
    final model = schema.models[modelDart];
    if (model == null) return const [];
    return [for (final f in model.fields) if (!f.optional) f.wire];
  }

  /// Tag values selecting [modelDart]: literal/enum rule values of the
  /// discriminator field, else the model name in lower case.
  Set<String> _discriminatorTags(String modelDart, String discriminator) {
    final model = schema.models[modelDart];
    final tags = <String>{};
    if (model != null) {
      for (final f in model.fields) {
        if (f.wire != discriminator) continue;
        final v = f.validate;
        if (v?['type'] == 'literal' && v?['value'] is String) {
          tags.add((v!['value'] as String).toLowerCase());
        }
        if (v?['type'] == 'enum' && v?['values'] is List) {
          tags.addAll((v!['values'] as List).map((e) => '$e'.toLowerCase()));
        }
      }
      tags.add(model.raw.toLowerCase());
    }
    tags.add(modelDart.toLowerCase());
    return tags;
  }

  // ---------------------------------------------------------------------------

  void _writeModel(StringBuffer b, ModelSpec model) {
    _writeRecordClass(
      b,
      name: model.dartName,
      doc: model.doc,
      fields: model.fields,
    );
  }

  /// Immutable class with fromJson/toJson/copyWith/==/hashCode/toString.
  void _writeRecordClass(
    StringBuffer b, {
    required String name,
    String? doc,
    required List<FieldSpec> fields,
    String? extendsClause,
    void Function(StringBuffer b)? extra,
  }) {
    b.write(GeneratorUtils.docComment(doc, ''));
    b.writeln('class $name${extendsClause ?? ''} {');

    // Constructor
    if (fields.isEmpty) {
      b.writeln('  const $name();');
    } else {
      b.writeln('  const $name({');
      for (final f in fields) {
        b.writeln('    ${f.optional ? '' : 'required '}this.${f.dart},');
      }
      b.writeln('  });');
    }
    b.writeln();

    // fromJson
    if (fields.isEmpty) {
      b.writeln('  factory $name.fromJson(Object? json) => const $name();');
    } else {
      b.writeln('  factory $name.fromJson(Object? json) {');
      b.writeln('    final map = AxiomGeneratedCodec.asObject(json);');
      b.writeln('    return $name(');
      for (final f in fields) {
        final access = 'map[${GeneratorUtils.str(f.wire)}]';
        final expr = f.optional
            ? m.decodeNullable(f.type, access)
            : m.decode(f.type, access);
        b.writeln('      ${f.dart}: $expr,');
      }
      b.writeln('    );');
      b.writeln('  }');
    }
    b.writeln();

    // Fields
    for (final f in fields) {
      b.write(GeneratorUtils.docComment(f.doc, '  '));
      final t = m.dartType(f.type);
      final nullable = f.optional && !t.endsWith('?');
      b.writeln('  final $t${nullable ? '?' : ''} ${f.dart};');
    }
    if (fields.isNotEmpty) b.writeln();

    // toJson
    if (extendsClause != null) b.writeln('  @override');
    if (fields.isEmpty) {
      b.writeln('  Map<String, dynamic> toJson() => <String, dynamic>{};');
    } else {
      b.writeln('  Map<String, dynamic> toJson() => <String, dynamic>{');
      for (final f in fields) {
        final key = GeneratorUtils.str(f.wire);
        if (f.optional) {
          b.writeln('    if (${f.dart} case final v?) $key: ${m.encode(f.type, 'v')},');
        } else {
          b.writeln('    $key: ${m.encode(f.type, f.dart)},');
        }
      }
      b.writeln('  };');
    }
    b.writeln();

    // copyWith
    if (fields.isEmpty) {
      b.writeln('  $name copyWith() => this;');
    } else {
      b.writeln('  $name copyWith({');
      for (final f in fields) {
        final t = m.dartType(f.type);
        if (f.optional) {
          b.writeln('    Object? ${f.dart} = _unset,');
        } else {
          b.writeln('    ${t.endsWith('?') ? t : '$t?'} ${f.dart},');
        }
      }
      b.writeln('  }) => $name(');
      for (final f in fields) {
        final t = m.dartType(f.type);
        if (f.optional) {
          final nt = t.endsWith('?') ? t : '$t?';
          b.writeln(
            '    ${f.dart}: identical(${f.dart}, _unset) ? this.${f.dart} : ${f.dart} as $nt,',
          );
        } else if (t.endsWith('?')) {
          // Required JSON field: null keeps the current value.
          b.writeln('    ${f.dart}: ${f.dart} ?? this.${f.dart},');
        } else {
          b.writeln('    ${f.dart}: ${f.dart} ?? this.${f.dart},');
        }
      }
      b.writeln('  );');
    }
    b.writeln();

    // ==
    b.writeln('  @override');
    if (fields.isEmpty) {
      b.writeln('  bool operator ==(Object other) => other is $name;');
    } else {
      b.writeln('  bool operator ==(Object other) =>');
      b.writeln('      identical(this, other) ||');
      b.write('      other is $name');
      for (final f in fields) {
        if (_simpleEq(f.type)) {
          b.write(' &&\n          other.${f.dart} == ${f.dart}');
        } else {
          b.write(
            ' &&\n          AxiomGeneratedCodec.deepEquals(other.${f.dart}, ${f.dart})',
          );
        }
      }
      b.writeln(';');
    }
    b.writeln();

    // hashCode
    b.writeln('  @override');
    if (fields.isEmpty) {
      b.writeln('  int get hashCode => ${GeneratorUtils.str(name)}.hashCode;');
    } else {
      b.writeln('  int get hashCode => Object.hashAll([');
      for (final f in fields) {
        b.writeln(
          _simpleEq(f.type)
              ? '    ${f.dart},'
              : '    AxiomGeneratedCodec.deepHash(${f.dart}),',
        );
      }
      b.writeln('  ]);');
    }
    b.writeln();

    // toString
    b.writeln('  @override');
    final parts = fields
        .map((f) => '${f.dart.replaceAll('\$', '')}: ${GeneratorUtils.interp(f.dart)}')
        .join(', ');
    b.writeln("  String toString() => '$name($parts)';");
    extra?.call(b);
    b.writeln('}');
    b.writeln();
  }

  bool _simpleEq(TypeNode t) => t is PrimType && t.kind != 'bytes' || t is RefType;

  // ---------------------------------------------------------------------------

  void _writeValidators(StringBuffer b, ModelSpec model) {
    final rules = <FieldSpec, Map<String, dynamic>>{};
    for (final f in model.fields) {
      final v = f.validate;
      if (v == null) continue;
      if (v['type'] == 'string' || v['type'] == 'number' || v['type'] == 'enum') {
        rules[f] = v;
      }
    }
    if (rules.isEmpty) return;
    final cls = '${model.dartName}Validators';
    b.writeln('/// Form validators for [${model.dartName}] built from the contract field');
    b.writeln('/// rules. Each has the `TextFormField.validator` signature.');
    b.writeln('abstract final class $cls {');
    for (final entry in rules.entries) {
      _writeValidator(b, entry.key, entry.value);
    }
    b.writeln('  /// All validators by wire field name.');
    b.writeln('  static const Map<String, String? Function(String?)> all = {');
    for (final f in rules.keys) {
      b.writeln('    ${GeneratorUtils.str(f.wire)}: ${f.dart},');
    }
    b.writeln('  };');
    b.writeln('}');
    b.writeln();
  }

  void _writeValidator(StringBuffer b, FieldSpec f, Map<String, dynamic> v) {
    final rule = v['type'];
    b.writeln('  static String? ${f.dart}(String? value) {');
    if (f.optional) {
      b.writeln('    if (value == null || value.isEmpty) return null;');
    } else {
      b.writeln("    if (value == null || value.isEmpty) return 'Required';");
    }
    num? n(String k) => v[k] is num ? v[k] as num : null;
    String lit(num x) => x == x.roundToDouble() && x is! double ? '$x' : '$x';
    if (rule == 'string') {
      final min = n('min'), max = n('max'), len = n('length');
      if (len != null) {
        b.writeln("    if (value.length != ${len.toInt()}) return 'Must be exactly ${len.toInt()} characters';");
      }
      if (min != null) {
        b.writeln("    if (value.length < ${min.toInt()}) return 'Must be at least ${min.toInt()} characters';");
      }
      if (max != null) {
        b.writeln("    if (value.length > ${max.toInt()}) return 'Must be at most ${max.toInt()} characters';");
      }
      if (v['email'] == true) {
        b.writeln(r"    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {");
        b.writeln("      return 'Must be a valid email address';");
        b.writeln('    }');
      }
      if (v['url'] == true) {
        b.writeln('    final uri = Uri.tryParse(value);');
        b.writeln("    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return 'Must be a valid URL';");
      }
      if (v['uuid'] == true) {
        b.writeln(
          r"    if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(value)) {",
        );
        b.writeln("      return 'Must be a valid UUID';");
        b.writeln('    }');
      }
      if (v['regex'] is String) {
        b.writeln('    if (!RegExp(${GeneratorUtils.str(v['regex'] as String)}).hasMatch(value)) {');
        b.writeln("      return 'Invalid format';");
        b.writeln('    }');
      }
      if (v['starts_with'] is String) {
        final s = GeneratorUtils.str(v['starts_with'] as String);
        b.writeln('    if (!value.startsWith($s)) {');
        b.writeln("      return ${GeneratorUtils.str('Must start with ${v['starts_with']}')};");
        b.writeln('    }');
      }
      if (v['ends_with'] is String) {
        final s = GeneratorUtils.str(v['ends_with'] as String);
        b.writeln('    if (!value.endsWith($s)) {');
        b.writeln("      return ${GeneratorUtils.str('Must end with ${v['ends_with']}')};");
        b.writeln('    }');
      }
      if (v['includes'] is String) {
        final s = GeneratorUtils.str(v['includes'] as String);
        b.writeln('    if (!value.contains($s)) {');
        b.writeln("      return ${GeneratorUtils.str('Must contain ${v['includes']}')};");
        b.writeln('    }');
      }
    } else if (rule == 'number') {
      final isInt = v['int'] == true ||
          (f.type is PrimType && (f.type as PrimType).kind == 'int');
      b.writeln('    final number = num.tryParse(value.trim());');
      b.writeln("    if (number == null) return 'Must be a number';");
      if (isInt) {
        b.writeln("    if (number % 1 != 0) return 'Must be a whole number';");
      }
      final min = n('min'), max = n('max');
      if (min != null) {
        b.writeln("    if (number < ${lit(min)}) return 'Must be at least ${lit(min)}';");
      }
      if (max != null) {
        b.writeln("    if (number > ${lit(max)}) return 'Must be at most ${lit(max)}';");
      }
    } else if (rule == 'enum') {
      final values = (v['values'] as List).map((e) => '$e').toList();
      b.writeln(
        '    const allowed = {${values.map(GeneratorUtils.str).join(', ')}};',
      );
      b.writeln('    if (!allowed.contains(value)) {');
      b.writeln("      return ${GeneratorUtils.str('Must be one of: ${values.join(', ')}')};");
      b.writeln('    }');
    }
    b.writeln('    return null;');
    b.writeln('  }');
    b.writeln();
  }

  // ---------------------------------------------------------------------------

  void _writeFailures(StringBuffer b) {
    if (schema.failures.isEmpty) return;
    b.writeln('/// A typed failure declared by the contract (`failure` / `errors(...)`).');
    b.writeln('sealed class ContractFailure {');
    b.writeln('  const ContractFailure();');
    b.writeln();
    b.writeln('  /// Contract failure code, for example `conflict`.');
    b.writeln('  String get code;');
    b.writeln();
    b.writeln('  Map<String, dynamic> toJson();');
    b.writeln();
    b.writeln('  /// Decodes the failure carried by [error], or null.');
    b.writeln('  static ContractFailure? fromError(AxiomError error) {');
    b.writeln('    final (code, payload) = AxiomGeneratedCodec.failureParts(error);');
    b.writeln('    switch (code) {');
    for (final code in schema.failures.keys.toList()..sort()) {
      final f = schema.failures[code]!;
      b.writeln('      case ${GeneratorUtils.str(code)}:');
      b.writeln('        return ${f.dartName}.fromJson(payload);');
    }
    b.writeln('    }');
    b.writeln('    return null;');
    b.writeln('  }');
    b.writeln();
    b.writeln('  /// Registers every failure decoder with [AxiomFailureRegistry].');
    b.writeln('  static void registerAll({String? namespace}) {');
    for (final code in schema.failures.keys.toList()..sort()) {
      final f = schema.failures[code]!;
      b.writeln(
        '    AxiomFailureRegistry.register(${GeneratorUtils.str(code)}, ${f.dartName}.fromJson, namespace: namespace);',
      );
    }
    b.writeln('  }');
    b.writeln('}');
    b.writeln();

    // Per-endpoint sealed interfaces.
    final epNames = schema.endpointFailures.keys.toList()..sort();
    final ifaceOf = <String, String>{};
    for (final ep in epNames) {
      final iface = '${GeneratorUtils.pascalCase(ep)}Errors';
      ifaceOf[ep] = iface;
      b.writeln('/// Failures the `$ep` endpoint can return.');
      b.writeln('sealed class $iface implements ContractFailure {}');
      b.writeln();
    }

    for (final code in schema.failures.keys.toList()..sort()) {
      final f = schema.failures[code]!;
      final ifaces = (f.endpoints.toList()..sort()).map((e) => ifaceOf[e]!).toList();
      _writeRecordClass(
        b,
        name: f.dartName,
        doc: 'Contract failure `$code`.',
        fields: f.fields,
        extendsClause:
            ' extends ContractFailure${ifaces.isEmpty ? '' : ' implements ${ifaces.join(', ')}'}',
        extra: (b) {
          b.writeln();
          b.writeln('  static const String failureCode = ${GeneratorUtils.str(code)};');
          b.writeln();
          b.writeln('  @override');
          b.writeln('  String get code => failureCode;');
        },
      );
    }

    // when-helpers on AxiomError.
    b.writeln('/// Typed access to contract failures on [AxiomError].');
    b.writeln('extension AxiomErrorContractFailures on AxiomError {');
    b.writeln('  /// The typed contract failure, or null for other errors.');
    b.writeln('  ContractFailure? get contractFailure => ContractFailure.fromError(this);');
    b.writeln();
    for (final ep in epNames) {
      final codes = schema.endpointFailures[ep]!;
      final iface = ifaceOf[ep]!;
      final fn = 'when${GeneratorUtils.pascalCase(ep)}';
      b.writeln('  /// Failure of `$ep` as [$iface], or null.');
      b.writeln('  $iface? get ${GeneratorUtils.camelCase(ep)}Failure {');
      b.writeln('    final f = contractFailure;');
      b.writeln('    return f is $iface ? f : null;');
      b.writeln('  }');
      b.writeln();
      b.writeln('  /// Pattern match on the failures of `$ep`; [orElse] gets any other error.');
      b.writeln('  R $fn<R>({');
      for (final code in codes) {
        final f = schema.failures[code]!;
        b.writeln('    required R Function(${f.dartName} failure) ${GeneratorUtils.identifier(code)},');
      }
      b.writeln('    required R Function(AxiomError error) orElse,');
      b.writeln('  }) {');
      b.writeln('    return switch (${GeneratorUtils.camelCase(ep)}Failure) {');
      for (final code in codes) {
        final f = schema.failures[code]!;
        b.writeln('      final ${f.dartName} f => ${GeneratorUtils.identifier(code)}(f),');
      }
      b.writeln('      null => orElse(this),');
      b.writeln('    };');
      b.writeln('  }');
      b.writeln();
    }
    b.writeln('}');
    b.writeln();
  }
}
