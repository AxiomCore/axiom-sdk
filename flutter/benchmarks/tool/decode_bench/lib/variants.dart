// Hand-written candidate decoder shapes (A/B for the generator).
class Item {
  const Item(this.active, this.id, this.name, this.price, this.qty, this.tags);
  final bool active;
  final String id;
  final String name;
  final double price;
  final int qty;
  final List<String> tags;
}

int asInt(Object? v) => switch (v) {
  int() => v,
  num() => v.toInt(),
  String() => int.parse(v),
  _ => throw FormatException('expected an integer, got $v'),
};
double asDouble(Object? v) => switch (v) {
  num() => v.toDouble(),
  String() => double.parse(v),
  _ => throw FormatException('expected a number, got $v'),
};
Map<String, dynamic> asObject(Object? v) =>
    v is Map<String, dynamic> ? v : (v as Map).cast<String, dynamic>();

// A: inline casts, collection-for lists.
Item itemA(Object? json) {
  final map = asObject(json);
  return Item(
    map['active'] as bool,
    map['id'] as String,
    map['name'] as String,
    switch (map['price']) { final double v => v, final v => asDouble(v) },
    switch (map['qty']) { final int v => v, final v => asInt(v) },
    [for (final e in map['tags'] as List) e as String],
  );
}

List<Item> listA(Object? j) => [for (final e in j as List) itemA(e)];

// B: fixed-length lists via List.generate.
Item itemB(Object? json) {
  final map = asObject(json);
  final tags = map['tags'] as List;
  return Item(
    map['active'] as bool,
    map['id'] as String,
    map['name'] as String,
    switch (map['price']) { final double v => v, final v => asDouble(v) },
    switch (map['qty']) { final int v => v, final v => asInt(v) },
    List<String>.generate(tags.length, (i) => tags[i] as String, growable: false),
  );
}

List<Item> listB(Object? j) {
  final l = j as List;
  return List<Item>.generate(l.length, (i) => itemB(l[i]), growable: false);
}

// C: fixed-length via List.filled-less loop (List<Item?> avoided): growable
// with preset capacity is not exposed in Dart; use generate for outer, for
// tags a collection-for.
Item itemC(Object? json) {
  final map = asObject(json);
  return Item(
    map['active'] as bool,
    map['id'] as String,
    map['name'] as String,
    switch (map['price']) { final double v => v, final v => asDouble(v) },
    switch (map['qty']) { final int v => v, final v => asInt(v) },
    List<String>.of((map['tags'] as List).cast<String>(), growable: false),
  );
}

List<Item> listC(Object? j) {
  final l = j as List;
  return List<Item>.generate(l.length, (i) => itemC(l[i]), growable: false);
}

// D: like B, tags via List.from (VM fast path for List<dynamic> sources).
Item itemD(Object? json) {
  final map = asObject(json);
  return Item(
    map['active'] as bool,
    map['id'] as String,
    map['name'] as String,
    switch (map['price']) { final double v => v, final v => asDouble(v) },
    switch (map['qty']) { final int v => v, final v => asInt(v) },
    List<String>.from(map['tags'] as List, growable: false),
  );
}

List<Item> listD(Object? j) {
  final l = j as List;
  return List<Item>.generate(l.length, (i) => itemD(l[i]), growable: false);
}

// BG: like B but growable lists (no behaviour change for callers that add).
Item itemBG(Object? json) {
  final map = asObject(json);
  final tags = map['tags'] as List;
  return Item(
    map['active'] as bool,
    map['id'] as String,
    map['name'] as String,
    switch (map['price']) { final double v => v, final v => asDouble(v) },
    switch (map['qty']) { final int v => v, final v => asInt(v) },
    List<String>.generate(tags.length, (i) => tags[i] as String),
  );
}

List<Item> listBG(Object? j) {
  final l = j as List;
  return List<Item>.generate(l.length, (i) => itemBG(l[i]));
}
