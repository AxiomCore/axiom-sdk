/// Naming and literal helpers shared by the writers.
class GeneratorUtils {
  static const _reserved = {
    'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
    'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
    'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
    'external', 'factory', 'false', 'final', 'finally', 'for', 'Function',
    'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
    'late', 'library', 'mixin', 'new', 'null', 'of', 'on', 'operator', 'part',
    'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
    'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'type',
    'typedef', 'var', 'void', 'when', 'while', 'with', 'yield',
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
