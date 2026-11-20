/// Plain `package:http` client with hand-written `fromJson` for the benchmark API.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class Item {
  Item({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    required this.active,
    required this.tags,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        qty: (json['qty'] as num).toInt(),
        active: json['active'] as bool,
        tags: (json['tags'] as List).cast<String>(),
      );

  final String id;
  final String name;
  final double price;
  final int qty;
  final bool active;
  final List<String> tags;
}

class ItemList {
  ItemList({required this.items, required this.total});

  factory ItemList.fromJson(Map<String, dynamic> json) => ItemList(
        items: [
          for (final e in json['items'] as List) Item.fromJson(e as Map<String, dynamic>),
        ],
        total: (json['total'] as num).toInt(),
      );

  final List<Item> items;
  final int total;
}

class HttpBenchApi {
  HttpBenchApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await _client.get(Uri.parse('$baseUrl$path'));
    if (res.statusCode != 200) {
      throw http.ClientException('GET $path: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<ItemList> listItems(int n) async => ItemList.fromJson(await _get('/items?n=$n'));

  Future<Item> getItem(String id) async =>
      Item.fromJson(await _get('/items/${Uri.encodeComponent(id)}'));

  Future<Item> createItem({required String name, required double price, required int qty}) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/items'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'name': name, 'price': price, 'qty': qty}),
    );
    if (res.statusCode != 201) {
      throw http.ClientException('POST /items: ${res.statusCode}');
    }
    return Item.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  void close() => _client.close();
}
