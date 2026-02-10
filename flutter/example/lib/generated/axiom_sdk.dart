// GENERATED CODE – DO NOT EDIT.
// Axiom SDK for app

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:example/generated/schema_axiom_generated.dart' as schema;
import 'package:example/generated/models.dart' as models;

class AxiomSdk {
  final AxiomRuntime _runtime;

  // Private constructor to ensure proper initialization.
  AxiomSdk._(this._runtime);

  /// Asynchronously creates and initializes the Axiom SDK.
  static Future<AxiomSdk> create({required String baseUrl, String? dbPath}) async {
    // Ensure Flutter bindings are initialized for asset loading.
    WidgetsFlutterBinding.ensureInitialized();

    final contractData = await rootBundle.load('.axiom');
    final contractBytes = contractData.buffer.asUint8List();

    // Get the singleton instance of the runtime.
    final runtime = AxiomRuntime();
    // Ensure the background isolate is running and ready.
    await runtime.init();
    // Start the runtime with the contract and base URL.
    const String? _signature = null;
    const String? _publicKey = null;
    await runtime.startup(baseUrl: baseUrl, contractBytes: contractBytes, dbPath: dbPath, signature: _signature, publicKey: _publicKey);
    // Return the fully initialized SDK.
    return AxiomSdk._(runtime);
  }

  /// Endpoint "get_user" (Stream)
  /// Path: /users/{user_id}
  /// IR endpoint id: 0
  AxiomQuery<models.User>  getUser({required int userId}) {
    final queryArgs = <String, dynamic>{
      'user_id': userId,
    };
    final queryKey = 'get_user:${jsonEncode(queryArgs)}';
    final stream = AxiomQueryManager().watch<models.User>(queryKey, () {
    var path = '/users/{user_id}';
    path = path.replaceAll('{user_id}', userId.toString());
    final requestBytes = Uint8List(0);
    final rawStream = _runtime.callStream(endpointId: 0, method: "GET", path: path, requestBytes: requestBytes);
    return rawStream.map((state) {
       return state.map((bytes) {
         final jsonObject = jsonDecode(utf8.decode(bytes));
         return models.User.fromJson(jsonObject);
       });
    });
    });
    return AxiomQuery(queryKey, stream);
  }


  /// Endpoint "list_users" (Stream)
  /// Path: /users
  /// IR endpoint id: 1
  AxiomQuery<List<models.User>>  listUsers({int? limit}) {
    final queryArgs = <String, dynamic>{
      'limit': limit,
    };
    final queryKey = 'list_users:${jsonEncode(queryArgs)}';
    final stream = AxiomQueryManager().watch<List<models.User>>(queryKey, () {
    var path = '/users';
    final requestBytes = Uint8List(0);
    final rawStream = _runtime.callStream(endpointId: 1, method: "GET", path: path, requestBytes: requestBytes);
    return rawStream.map((state) {
       return state.map((bytes) {
         final jsonObject = jsonDecode(utf8.decode(bytes));
         return (jsonObject as List<dynamic>).map((e) => models.User.fromJson(e)).toList();
       });
    });
    });
    return AxiomQuery(queryKey, stream);
  }


  /// Endpoint "create_user" (Stream)
  /// Path: /users
  /// IR endpoint id: 2
  AxiomQuery<models.Message>  createUser({required models.User user}) {
    final queryArgs = <String, dynamic>{
      'user': user.toJson(),
    };
    final queryKey = 'create_user:${jsonEncode(queryArgs)}';
    final stream = AxiomQueryManager().watch<models.Message>(queryKey, () {
    var path = '/users';
    final requestBytes = Uint8List.fromList(utf8.encode(jsonEncode(user)));
    final rawStream = _runtime.callStream(endpointId: 2, method: "POST", path: path, requestBytes: requestBytes);
    return rawStream.map((state) {
       return state.map((bytes) {
         final jsonObject = jsonDecode(utf8.decode(bytes));
         return models.Message.fromJson(jsonObject);
       });
    });
    });
    return AxiomQuery(queryKey, stream);
  }


  /// Endpoint "foo_endpoint" (Stream)
  /// Path: /foo
  /// IR endpoint id: 3
  AxiomQuery<int?>  fooEndpoint() {
    final queryArgs = <String, dynamic>{
    };
    final queryKey = 'foo_endpoint:${jsonEncode(queryArgs)}';
    final stream = AxiomQueryManager().watch<int?>(queryKey, () {
    var path = '/foo';
    final requestBytes = Uint8List(0);
    final rawStream = _runtime.callStream(endpointId: 3, method: "GET", path: path, requestBytes: requestBytes);
    return rawStream.map((state) {
       return state.map((bytes) {
         final jsonObject = jsonDecode(utf8.decode(bytes));
         return jsonObject as int?;
       });
    });
    });
    return AxiomQuery(queryKey, stream);
  }


  /// Endpoint "internal_route" (Stream)
  /// Path: /_internal
  /// IR endpoint id: 4
  AxiomQuery<void>  internalRoute() {
    final queryArgs = <String, dynamic>{
    };
    final queryKey = 'internal_route:${jsonEncode(queryArgs)}';
    final stream = AxiomQueryManager().watch<void>(queryKey, () {
    var path = '/_internal';
    final requestBytes = Uint8List(0);
    final rawStream = _runtime.callStream(endpointId: 4, method: "GET", path: path, requestBytes: requestBytes);
    return rawStream.map((state) {
       return state.map((bytes) {
         return null;
       });
    });
    });
    return AxiomQuery(queryKey, stream);
  }


}
