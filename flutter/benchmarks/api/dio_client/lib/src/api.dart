import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'models.dart';

part 'api.g.dart';

@RestApi()
abstract class BenchApi {
  factory BenchApi(Dio dio, {String? baseUrl}) = _BenchApi;

  @GET('/items')
  Future<ItemList> listItems(@Query('n') int n);

  @GET('/cached/items')
  Future<ItemList> cachedItems(@Query('n') int n);

  @GET('/items/{id}')
  Future<Item> getItem(@Path('id') String id);

  @POST('/items')
  Future<Item> createItem(@Body() ItemInput input);
}
