// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Item _$ItemFromJson(Map<String, dynamic> json) => Item(
  id: json['id'] as String,
  name: json['name'] as String,
  price: (json['price'] as num).toDouble(),
  qty: (json['qty'] as num).toInt(),
  active: json['active'] as bool,
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$ItemToJson(Item instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'price': instance.price,
  'qty': instance.qty,
  'active': instance.active,
  'tags': instance.tags,
};

ItemList _$ItemListFromJson(Map<String, dynamic> json) => ItemList(
  items: (json['items'] as List<dynamic>)
      .map((e) => Item.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$ItemListToJson(ItemList instance) => <String, dynamic>{
  'items': instance.items,
  'total': instance.total,
};

ItemInput _$ItemInputFromJson(Map<String, dynamic> json) => ItemInput(
  name: json['name'] as String,
  price: (json['price'] as num).toDouble(),
  qty: (json['qty'] as num).toInt(),
);

Map<String, dynamic> _$ItemInputToJson(ItemInput instance) => <String, dynamic>{
  'name': instance.name,
  'price': instance.price,
  'qty': instance.qty,
};
