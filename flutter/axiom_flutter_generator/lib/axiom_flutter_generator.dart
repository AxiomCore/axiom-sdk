/// Dart client generator for AxiomCore contracts (`axiom pull --framework
/// flutter`). Use [generate] from tests; `bin/generate.dart` is the CLI.
library;

import 'src/generator/model_writer.dart';
import 'src/generator/schema.dart';
import 'src/generator/sdk_writer.dart';
import 'src/generator/utils.dart';

export 'src/generator/sdk_writer.dart' show ContractInput;
export 'src/generator/utils.dart' show GeneratorException;

/// Version written into every generated file header.
const String generatorVersion = '0.147.5';


/// Generates `axiom_sdk.dart` and `models.dart` for [contracts].
///
/// [variant]: when set, only endpoints of that variant are emitted. A
/// contract built for another variant (`project.variant`) is rejected.
/// Returns file name -> content.
Map<String, String> generate(List<ContractInput> contracts, {String? variant}) {
  final sorted = [...contracts]..sort((a, b) => a.namespace.compareTo(b.namespace));
  for (final c in sorted) {
    _normalize(c.contract);
    if (variant != null && variant.isNotEmpty) _applyVariant(c, variant);
  }

  final schema = Schema({for (final c in sorted) c.namespace: c.contract});
  final header = _header(sorted, variant);
  return {
    'axiom_sdk.dart': SdkWriter(contracts: sorted, schema: schema, header: header).write(),
    'models.dart': ModelWriter(schema, header: header).write(),
  };
}

String _header(List<ContractInput> contracts, String? variant) {
  final b = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT EDIT.')
    ..write('// axiom_flutter_generator $generatorVersion');
  for (final c in contracts) {
    final p = c.contract['project'];
    if (p is Map) {
      final hash = '${p['schema_hash'] ?? ''}';
      b.write(
        '\n// ${c.namespace}: ${p['project_id'] ?? '?'} ${p['version'] ?? ''}'
        '${p['variant'] != null ? ' variant ${p['variant']}' : ''}'
        '${hash.length >= 12 ? ' schema ${hash.substring(0, 12)}' : ''}',
      );
    } else {
      b.write('\n// ${c.namespace}');
    }
  }
  if (variant != null && variant.isNotEmpty) b.write('\n// --variant $variant');
  return b.toString();
}

/// Older compilers emit lists, newer ones maps; both are accepted.
void _normalize(Map<String, dynamic> contract) {
  final ir = contract['ir'];
  if (ir is! Map<String, dynamic>) return;
  final eps = ir['endpoints'];
  if (eps is List) {
    ir['endpoints'] = {
      for (final e in eps)
        if (e is Map) '${e['name']}': e,
    };
  }
  final models = ir['models'];
  if (models is List) {
    ir['models'] = {
      for (final e in models)
        if (e is Map) '${e['name']}': e,
    };
  }
}

void _applyVariant(ContractInput c, String variant) {
  final project = c.contract['project'];
  final built = project is Map ? project['variant'] as String? : null;
  if (built != null && built != variant && built != 'default') {
    throw GeneratorException(
      'Contract "${c.namespace}" was built for variant "$built", not "$variant". '
      'Rebuild it with: axiom build main.acore --variant $variant',
    );
  }
  final eps = c.ir['endpoints'];
  if (eps is! Map) return;
  // Endpoint-level membership when the compiler records it.
  eps.removeWhere((name, ep) {
    if (ep is! Map) return false;
    final variants = ep['variants'];
    if (variants is List) return !variants.contains(variant);
    return false;
  });
  // Contract-level variant table (`variants: {name: {include: [...]}}`).
  final table = c.contract['variants'];
  if (table is Map && table[variant] is Map) {
    final include = (table[variant] as Map)['include'];
    if (include is List && !include.contains('*')) {
      eps.removeWhere((name, _) => !include.contains(name));
    }
  }
}
