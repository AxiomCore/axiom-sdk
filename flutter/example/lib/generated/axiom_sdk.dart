// GENERATED CODE – DO NOT EDIT.
// ignore_for_file: unused_import
// ignore_for_file: invalid_null_aware_operator

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:example/generated/models.dart' as models;

class AxiomSdk {
  final AxiomRuntime _runtime;

  AxiomSdk._(this._runtime);

  static Future<AxiomSdk> create({required String baseUrl, String? dbPath}) async {
    WidgetsFlutterBinding.ensureInitialized();
    final contractData = await rootBundle.load('.axiom');
    final contractBytes = contractData.buffer.asUint8List();
    final runtime = AxiomRuntime();
    await runtime.init();
    await runtime.startup(
      baseUrl: baseUrl,
      contractBytes: contractBytes,
      dbPath: dbPath,
      signature: null,
      publicKey: null,
    );
    return AxiomSdk._(runtime);
  }

  AxiomQuery<models.User> getUser({required int userId, }) {
    final args = <String, dynamic>{
      'user_id': userId,
    };
    final pathParams = <String, dynamic>{
      'user_id': userId,
    };
    return _runtime.send<models.User>(
      endpointId: 0,
      method: 'GET',
      path: '/users/{user_id}',
      args: args,
      pathParams: pathParams,
      decoder: (json) => models.User.fromJson(json),
    );
  }

  AxiomQuery<List<models.User>> listUsers({int? limit, }) {
    final args = <String, dynamic>{
      'limit': limit,
    };
    final queryParams = <String, dynamic>{
      'limit': limit,
    };
    return _runtime.send<List<models.User>>(
      endpointId: 1,
      method: 'GET',
      path: '/users',
      args: args,
      queryParams: queryParams,
      decoder: (json) => (json as List).map((e) => models.User.fromJson(e)).toList(),
    );
  }

  AxiomQuery<models.Message> createUser({required models.User user, }) {
    final args = <String, dynamic>{
      'user': user?.toJson(),
    };
    return _runtime.send<models.Message>(
      endpointId: 2,
      method: 'POST',
      path: '/users',
      args: args,
      body: user,
      decoder: (json) => models.Message.fromJson(json),
    );
  }

  AxiomQuery<int?> fooEndpoint() {
    final args = <String, dynamic>{
    };
    return _runtime.send<int?>(
      endpointId: 3,
      method: 'GET',
      path: '/foo',
      args: args,
      decoder: (json) => json as int?,
    );
  }

  AxiomQuery<void> internalRoute() {
    final args = <String, dynamic>{
    };
    return _runtime.send<void>(
      endpointId: 4,
      method: 'GET',
      path: '/_internal',
      args: args,
      decoder: (json) => null,
    );
  }

}
