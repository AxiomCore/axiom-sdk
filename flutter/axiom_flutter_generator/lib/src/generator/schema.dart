import 'types.dart';
import 'utils.dart';

class FieldSpec {
  final String wire;
  final String dart;
  final TypeNode type;
  final bool optional;
  final Map<String, dynamic>? validate;
  final String? doc;
  FieldSpec({
    required this.wire,
    required this.dart,
    required this.type,
    required this.optional,
    this.validate,
    this.doc,
  });
}

class ModelSpec {
  final String raw;
  final String dartName;
  final String? doc;
  final List<FieldSpec> fields;
  ModelSpec(this.raw, this.dartName, this.doc, this.fields);
}

class EnumSpec {
  final String dartName;
  final List<String> values;
  final String? doc;
  EnumSpec(this.dartName, this.values, this.doc);
}

class UnionSpec {
  final String dartName;
  final String? discriminator;

  /// Model dart names, in contract order.
  final List<String> options;
  UnionSpec(this.dartName, this.discriminator, this.options);
}

class FailureSpec {
  final String code;
  final String dartName;
  final List<FieldSpec> fields;

  /// Endpoint (raw names) declaring this failure.
  final Set<String> endpoints;
  FailureSpec(this.code, this.dartName, this.fields, this.endpoints);
}

/// Everything models.dart declares, computed from all contracts.
class Schema {
  final Map<String, ModelSpec> models = {};
  final Map<String, EnumSpec> enums = {};
  final Map<String, UnionSpec> unions = {};
  final Map<String, FailureSpec> failures = {};

  /// endpoint raw name -> failure codes (sorted), across contracts.
  final Map<String, List<String>> endpointFailures = {};

  late final TypeMapper mapper;

  static const _fieldAvoid = {
    'other', 'copyWith', 'toJson', 'fromJson', 'hashCode', 'toString',
    'runtimeType', 'noSuchMethod',
  };

  Schema(Map<String, Map<String, dynamic>> contracts) {
    final rawModels = <String, Map<String, dynamic>>{};
    final rawEnums = <String, Map<String, dynamic>>{};
    for (final c in contracts.values) {
      final ir = (c['ir'] ?? c) as Map<String, dynamic>;
      _entries(ir['models']).forEach((k, v) => rawModels[k] = v);
      _entries(ir['enums']).forEach((k, v) => rawEnums[k] = v);
    }
    mapper = TypeMapper(prefix: '', enumNames: rawEnums.keys.toSet());

    for (final name in rawEnums.keys.toList()..sort()) {
      final e = rawEnums[name]!;
      final values = (e['values'] as List? ?? const []).map((v) => '$v');
      final dartName = GeneratorUtils.pascalCase(name);
      enums[dartName] = EnumSpec(dartName, values.toList(), e['doc'] as String?);
    }

    for (final name in rawModels.keys.toList()..sort()) {
      final m = rawModels[name]!;
      final dartName = GeneratorUtils.pascalCase(name);
      final fields = <FieldSpec>[];
      final rawFields = _fieldList(m['fields']);
      for (final f in rawFields) {
        final wire = f['name'] as String;
        final validate = (f['validate'] as Map?)?.cast<String, dynamic>();
        var type = mapper.resolve((f['typeRef'] as Map).cast<String, dynamic>());
        type = _refine(type, validate, dartName, wire);
        fields.add(
          FieldSpec(
            wire: wire,
            dart: GeneratorUtils.identifier(wire, avoid: _fieldAvoid),
            type: type,
            optional: f['isOptional'] as bool? ?? false,
            validate: validate,
            doc: f['doc'] as String?,
          ),
        );
      }
      models[dartName] = ModelSpec(name, dartName, m['doc'] as String?, fields);
    }

    for (final c in contracts.values) {
      _collectFailures(c);
    }
  }

  /// String fields with an enum rule become enums; Json fields with a
  /// union of object refs become sealed unions.
  TypeNode _refine(
    TypeNode type,
    Map<String, dynamic>? validate,
    String model,
    String field,
  ) {
    if (validate == null) return type;
    final rule = validate['type'];
    final name = '$model${GeneratorUtils.pascalCase(field)}';
    if (rule == 'enum' && type is PrimType && type.kind == 'string') {
      final values = validate['values'];
      if (values is List && values.isNotEmpty && values.every((v) => v is String)) {
        enums[name] = EnumSpec(name, values.cast<String>(), null);
        return RefType(name, 'enum');
      }
    }
    if ((rule == 'union' || rule == 'discriminatedUnion') && type is JsonType) {
      final options = validate['options'];
      if (options is List &&
          options.isNotEmpty &&
          options.every((o) => o is Map && o['ref'] is String)) {
        unions[name] = UnionSpec(
          name,
          validate['discriminator'] as String?,
          [for (final o in options) GeneratorUtils.pascalCase(o['ref'] as String)],
        );
        return RefType(name, 'union');
      }
    }
    return type;
  }

  void _collectFailures(Map<String, dynamic> contract) {
    final ir = (contract['ir'] ?? contract) as Map<String, dynamic>;
    final perEndpoint = <String, Map<String, Map<String, dynamic>>>{};
    final fc = contract['failure_contracts'];
    if (fc is Map && fc['endpoints'] is Map) {
      (fc['endpoints'] as Map).forEach((ep, codes) {
        if (codes is Map) {
          perEndpoint[ep as String] = {
            for (final e in codes.entries)
              e.key as String: (e.value as Map).cast<String, dynamic>(),
          };
        }
      });
    }
    // Codes declared via errors(...) without a public payload contract.
    _entries(ir['endpoints']).forEach((epName, ep) {
      final errs = (ep['errors'] as List? ?? const []).cast<String>();
      for (final code in errs) {
        perEndpoint.putIfAbsent(epName, () => {}).putIfAbsent(code, () => {});
      }
    });

    final fieldSets = <String, List<Map<String, TypeNode>>>{};
    for (final epName in perEndpoint.keys.toList()..sort()) {
      final codes = perEndpoint[epName]!;
      endpointFailures[epName] = {
        ...?endpointFailures[epName],
        ...codes.keys,
      }.toList()
        ..sort();
      for (final code in codes.keys) {
        final spec = failures.putIfAbsent(
          code,
          () => FailureSpec(
            code,
            '${GeneratorUtils.pascalCase(code)}Failure',
            [],
            {},
          ),
        );
        spec.endpoints.add(epName);
        final payload = codes[code]!['payload'];
        final fields = <String, TypeNode>{};
        if (payload is Map && payload['kind'] == 'record' && payload['value'] is Map) {
          (payload['value'] as Map).forEach((k, v) {
            fields[k as String] = _payloadType((v as Map).cast<String, dynamic>());
          });
        }
        fieldSets.putIfAbsent(code, () => []).add(fields);
      }
    }
    fieldSets.forEach((code, sets) {
      final spec = failures[code]!;
      final all = <String, TypeNode>{};
      for (final s in sets) {
        all.addAll(s);
      }
      for (final existing in spec.fields) {
        all.putIfAbsent(existing.wire, () => existing.type);
      }
      final names = all.keys.toList()..sort();
      spec.fields
        ..clear()
        ..addAll([
          for (final n in names)
            FieldSpec(
              wire: n,
              dart: GeneratorUtils.identifier(n, avoid: {..._fieldAvoid, 'code'}),
              type: all[n]!,
              optional: !sets.every((s) => s.containsKey(n)),
            ),
        ]);
    });
  }

  /// Failure payload records use the IR typeRef kinds; nested records
  /// (`kind: record`) are kept as JSON.
  TypeNode _payloadType(Map<String, dynamic> t) {
    if (t['kind'] == 'record' || t['kind'] == 'optional') return const JsonType();
    return mapper.resolve(t);
  }

  static Map<String, Map<String, dynamic>> _entries(Object? node) {
    final out = <String, Map<String, dynamic>>{};
    if (node is Map) {
      node.forEach((k, v) {
        if (v is Map) out['$k'] = v.cast<String, dynamic>();
      });
    } else if (node is List) {
      for (final v in node) {
        if (v is Map && v['name'] is String) {
          out[v['name'] as String] = v.cast<String, dynamic>();
        }
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> _fieldList(Object? node) {
    final list = _entries(node).values.toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return list;
  }
}
