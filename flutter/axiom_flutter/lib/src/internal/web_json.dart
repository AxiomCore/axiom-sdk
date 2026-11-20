// Web only: decode JSON response bodies with the browser (C1.2).
//
// A response body arrives from the runtime as the browser's own ArrayBuffer
// (C1.1). It is turned into text with TextDecoder and parsed with JSON.parse,
// so the bytes are never copied into a Dart Uint8List and (on dart2wasm) the
// tree is never built twice:
//
// * dart2js: `jsonDecode` already is `JSON.parse` plus lazy Dart maps, so the
//   text from TextDecoder goes straight into it.
// * dart2wasm: `jsonDecode` is a Dart parser. The tree from `JSON.parse` is
//   wrapped instead: [AxiomJsMap] is a `Map<String, dynamic>` and
//   [AxiomJsList] a `List<dynamic>` over the JS objects, converting values on
//   first access. Generated `fromJson` code (and any code written against
//   `jsonDecode` output) works unchanged: `asObject` sees a
//   `Map<String, dynamic>`, `asList` iterates a `List`.
//
// Differences from `jsonDecode` (dart2wasm only): JSON numbers are JS
// doubles; an integral value within 2^53 is returned as an `int`, so `1.0`
// in the body reads as `1` (generated `asDouble` accepts both).
import 'dart:collection';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('JSON.parse')
external JSAny? _jsonParse(JSString text);

@JS('Array.isArray')
external bool _isArray(JSAny? value);

@JS('Object.keys')
external JSArray<JSString> _objectKeys(JSObject value);

@JS('TextDecoder')
extension type _TextDecoder._(JSObject _) implements JSObject {
  external _TextDecoder();
  external JSString decode(JSAny input);
}

/// True when compiled with dart2js (ints and doubles share one JS number).
const bool _isDart2js = identical(1, 1.0);

abstract final class AxiomWebJson {
  static final _TextDecoder _utf8 = _TextDecoder();

  /// Selects the decoder for tests and benchmarks: null = automatic
  /// (dart2js: jsonDecode on the TextDecoder text; dart2wasm: JS tree view).
  static bool? useJsTree;

  /// UTF-8 text of [buffer] (an ArrayBuffer or typed-array view).
  static JSString text(JSAny buffer) => _utf8.decode(buffer);

  /// Parses [buffer] as JSON. Throws [FormatException] on invalid JSON (same
  /// type as `jsonDecode`), with the browser's message.
  static Object? decode(JSAny buffer) {
    final t = text(buffer);
    if (!(useJsTree ?? !_isDart2js)) return jsonDecode(t.toDart);
    final JSAny? tree;
    try {
      tree = _jsonParse(t);
    } catch (e) {
      throw FormatException(e.toString());
    }
    return wrap(tree);
  }

  /// Converts a JSON value from `JSON.parse`: primitives directly, objects
  /// and arrays as lazy views.
  static Object? wrap(JSAny? v) {
    if (v == null) return null;
    if (v.typeofEquals('string')) return (v as JSString).toDart;
    if (v.typeofEquals('number')) {
      final d = (v as JSNumber).toDartDouble;
      if (_isDart2js) return d;
      if (d == d.truncateToDouble() && d.abs() <= 9007199254740992.0) {
        return d.toInt();
      }
      return d;
    }
    if (v.typeofEquals('boolean')) return (v as JSBoolean).toDart;
    if (_isArray(v)) return AxiomJsList(v as JSArray<JSAny?>);
    return AxiomJsMap(v as JSObject);
  }
}

bool _isContainer(JSAny? v) =>
    v != null && v.typeofEquals('object');

/// `Map<String, dynamic>` view over a JSON object from `JSON.parse`.
/// Read-only access stays on the JS object; the first write copies it into a
/// Dart map.
class AxiomJsMap extends MapBase<String, dynamic> {
  AxiomJsMap(this._js);
  final JSObject _js;
  Map<String, Object?>? _children;
  Map<String, dynamic>? _dart;

  Map<String, dynamic> _materialize() =>
      _dart ??= {for (final k in keys) k: this[k]};

  @override
  Object? operator [](Object? key) {
    final d = _dart;
    if (d != null) return d[key];
    if (key is! String) return null;
    final c = _children;
    if (c != null && c.containsKey(key)) return c[key];
    final raw = _js[key];
    if (!_isContainer(raw)) return AxiomWebJson.wrap(raw);
    final v = AxiomWebJson.wrap(raw);
    (_children ??= {})[key] = v;
    return v;
  }

  @override
  bool containsKey(Object? key) {
    final d = _dart;
    if (d != null) return d.containsKey(key);
    return key is String && _js.hasProperty(key.toJS).toDart;
  }

  @override
  Iterable<String> get keys {
    final d = _dart;
    if (d != null) return d.keys;
    final k = _objectKeys(_js);
    final n = k.length;
    return List<String>.generate(n, (i) => k[i].toDart, growable: false);
  }

  @override
  int get length => _dart?.length ?? _objectKeys(_js).length;

  @override
  void operator []=(String key, dynamic value) => _materialize()[key] = value;

  @override
  dynamic remove(Object? key) => _materialize().remove(key);

  @override
  void clear() => _materialize().clear();
}

/// `List<dynamic>` view over a JSON array from `JSON.parse`. Elements are
/// converted once, on first access.
class AxiomJsList extends ListBase<dynamic> {
  AxiomJsList(this._js) : length0 = _js.length;
  final JSArray<JSAny?> _js;
  final int length0;
  List<Object?>? _items;
  List<dynamic>? _dart;

  static const Object _unset = Object();

  @override
  int get length => _dart?.length ?? length0;

  @override
  set length(int n) => _materialize().length = n;

  List<dynamic> _materialize() =>
      _dart ??= List<dynamic>.generate(length0, (i) => this[i]);

  @override
  dynamic operator [](int index) {
    final d = _dart;
    if (d != null) return d[index];
    RangeError.checkValidIndex(index, this, null, length0);
    final items = _items ??= List<Object?>.filled(length0, _unset);
    final cached = items[index];
    if (!identical(cached, _unset)) return cached;
    return items[index] = AxiomWebJson.wrap(_js[index]);
  }

  @override
  void operator []=(int index, dynamic value) => _materialize()[index] = value;

  @override
  void add(dynamic element) => _materialize().add(element);
}
