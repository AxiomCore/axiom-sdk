import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

@JsonSerializable()
class Item {
  Item({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    required this.active,
    required this.tags,
  });

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);

  final String id;
  final String name;
  final double price;
  final int qty;
  final bool active;
  final List<String> tags;

  Map<String, dynamic> toJson() => _$ItemToJson(this);
}

@JsonSerializable()
class ItemList {
  ItemList({required this.items, required this.total});

  factory ItemList.fromJson(Map<String, dynamic> json) => _$ItemListFromJson(json);

  final List<Item> items;
  final int total;

  Map<String, dynamic> toJson() => _$ItemListToJson(this);
}

@JsonSerializable()
class ItemInput {
  ItemInput({required this.name, required this.price, required this.qty});

  factory ItemInput.fromJson(Map<String, dynamic> json) => _$ItemInputFromJson(json);

  final String name;
  final double price;
  final int qty;

  Map<String, dynamic> toJson() => _$ItemInputToJson(this);
}
