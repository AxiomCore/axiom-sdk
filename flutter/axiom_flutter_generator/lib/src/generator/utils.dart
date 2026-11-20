/// Thrown for contract/config problems the user must fix.
class GeneratorException implements Exception {
  final String message;
  GeneratorException(this.message);
  @override
  String toString() => message;
}

/// Naming and literal helpers shared by the writers.
class GeneratorUtils {
  /// Members every Dart object has; a generated member must not reuse them.
  static const objectMembers = {
    'hashCode',
    'toString',
    'runtimeType',
    'noSuchMethod',
  };

  static const _reserved = {
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'base',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'Function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'of',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'sealed',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'type',
    'typedef',
    'var',
    'void',
    'when',
    'while',
    'with',
    'yield',
  };

  /// Splits `snake_case`, `kebab-case`, `camelCase` and spaced words.
  static List<String> _words(String name) {
    final spaced = name
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ');
    return spaced.split(' ').where((w) => w.isNotEmpty).toList();
  }

  static String pascalCase(String name) {
    final words = _words(name);
    if (words.isEmpty) return 'Unnamed';
    final buf = StringBuffer();
    for (final w in words) {
      buf.write(w[0].toUpperCase());
      buf.write(w.substring(1));
    }
    var out = buf.toString();
    if (RegExp(r'^[0-9]').hasMatch(out)) out = 'T$out';
    return out;
  }

  static String camelCase(String name) {
    final words = _words(name);
    if (words.isEmpty) return 'unnamed';
    final buf = StringBuffer(words.first[0].toLowerCase());
    buf.write(words.first.substring(1));
    for (final w in words.skip(1)) {
      buf.write(w[0].toUpperCase());
      buf.write(w.substring(1));
    }
    var out = buf.toString();
    if (RegExp(r'^[0-9]').hasMatch(out)) out = 'v$out';
    return out;
  }

  /// A lowerCamel identifier that is safe as a parameter or field name.
  static String identifier(String name, {Set<String> avoid = const {}}) {
    final c = camelCase(name);
    if (_reserved.contains(c) || avoid.contains(c)) return '\$$c';
    return c;
  }

  /// [identifier] made unique within [used] (deterministic suffix: `name2`,
  /// `name3`, ...). The result is added to [used].
  static String uniqueIdentifier(
    String name,
    Set<String> used, {
    Set<String> avoid = const {},
  }) => unique(identifier(name, avoid: {...avoid, ...objectMembers}), used);

  /// Unique identifiers for [wires] (same order). Names that are already
  /// valid identifiers as written (`userId`) are claimed first, so a
  /// converted name (`user_id`) gets the suffix (`userId2`).
  static List<String> uniqueNames(
    List<String> wires,
    Set<String> used, {
    Set<String> avoid = const {},
  }) {
    final out = List<String>.filled(wires.length, '');
    final all = {...avoid, ...objectMembers};
    final order = [
      for (var i = 0; i < wires.length; i++)
        if (identifier(wires[i], avoid: all) == wires[i]) i,
      for (var i = 0; i < wires.length; i++)
        if (identifier(wires[i], avoid: all) != wires[i]) i,
    ];
    for (final i in order) {
      out[i] = uniqueIdentifier(wires[i], used, avoid: avoid);
    }
    return out;
  }

  /// [id] or `id2`, `id3`, ... : the first not in [used]; added to [used].
  static String unique(String id, Set<String> used) {
    var out = id;
    var n = 2;
    while (used.contains(out)) {
      out = '$id${n++}';
    }
    used.add(out);
    return out;
  }

  /// `$name` or `${name}` inside a single-quoted string.
  static String interp(String identifier) =>
      identifier.startsWith('\$') ? '\${$identifier}' : '\$$identifier';

  /// Dart single-quoted string literal for [s].
  static String str(String s) {
    final escaped = s
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return "'$escaped'";
  }

  /// Dart doc comment lines for [doc] at [indent].
  static String docComment(String? doc, String indent) {
    if (doc == null || doc.trim().isEmpty) return '';
    final lines = doc
        .trim()
        .split('\n')
        .map((l) => '$indent/// ${l.trimRight()}'.trimRight());
    return '${lines.join('\n')}\n';
  }
}
