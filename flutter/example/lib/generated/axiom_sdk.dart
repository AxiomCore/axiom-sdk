// GENERATED CODE – DO NOT EDIT.
// Axiom SDK for 

import 'dart:convert';
import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:example/generated/schema_axiom_generated.dart' as schema;
import 'package:example/generated/models.dart' as models;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

class AxiomSdk {
  final AxiomRuntime _runtime;

  AxiomSdk._(this._runtime);

  /// Asynchronously creates and initializes the Axiom SDK.
  static Future<AxiomSdk> create({required String baseUrl}) async {
    // Ensure Flutter bindings are initialized for asset loading.
    WidgetsFlutterBinding.ensureInitialized();

    // Load the contract file automatically from assets.
    final contractData = await rootBundle.load('python-example_mobile_0.1.0.axiom');
    final contractBytes = contractData.buffer.asUint8List();

    // Get the singleton instance of the runtime.
    final runtime = AxiomRuntime();
    // Ensure the background isolate is running and ready.
    await runtime.init();
    // Set the base URL for the runtime.
    runtime.initialize(baseUrl);
    // Load the contract into the Rust runtime.
    runtime.loadContract(contractBytes);
    // Return the fully initialized SDK.
    return AxiomSdk._(runtime);
  }

  /// Endpoint "get_user"
  /// Path: /users/{user_id}
  /// IR endpoint id: 0
  Future<models.User> getUser({required int userId}) async {
    // 1. Build the path string
    var path = '/users/{user_id}';
    path = path.replaceAll('{user_id}', userId.toString());

    // 2. Build the request body (if any)
    final requestBytes = schema.GetUserRequestObjectBuilder(
      userId: userId,
    ).toBytes();

    // 3. Call the runtime
    final responseBytes = await _runtime.call(endpointId: 0, method: "GET", path: path, requestBytes: requestBytes);
    if (responseBytes.isEmpty) {
      throw StateError("Received empty response for a non-nullable return type.");
    }

    final jsonObject = jsonDecode(utf8.decode(responseBytes));
    return models.User.fromJson(jsonObject);
  }

  /// Endpoint "list_users"
  /// Path: /users
  /// IR endpoint id: 1
  Future<List<models.User>> listUsers({required int limit}) async {
    // 1. Build the path string
    var path = '/users';

    // 2. Build the request body (if any)
    final requestBytes = schema.ListUsersRequestObjectBuilder(
      limit: limit,
    ).toBytes();

    // 3. Call the runtime
    final responseBytes = await _runtime.call(endpointId: 1, method: "GET", path: path, requestBytes: requestBytes);
    if (responseBytes.isEmpty) {
      throw StateError("Received empty response for a non-nullable return type.");
    }

    final jsonObject = jsonDecode(utf8.decode(responseBytes));
    return (jsonObject as List<dynamic>).map((e) => models.User.fromJson(e)).toList();
  }

  /// Endpoint "create_user"
  /// Path: /users
  /// IR endpoint id: 2
  Future<models.Message> createUser({required models.User user}) async {
    // 1. Build the path string
    var path = '/users';

    // 2. Build the request body (if any)
    final requestBytes = schema.CreateUserRequestObjectBuilder(
      user: schema.UserObjectBuilder(
        id: user.id,
        name: user.name,
        role: user.role,
        email: user.email,
      ),
    ).toBytes();

    // 3. Call the runtime
    final responseBytes = await _runtime.call(endpointId: 2, method: "POST", path: path, requestBytes: requestBytes);
    if (responseBytes.isEmpty) {
      throw StateError("Received empty response for a non-nullable return type.");
    }

    final jsonObject = jsonDecode(utf8.decode(responseBytes));
    return models.Message.fromJson(jsonObject);
  }

  /// Endpoint "foo_endpoint"
  /// Path: /foo
  /// IR endpoint id: 3
  Future<int?> fooEndpoint() async {
    // 1. Build the path string
    var path = '/foo';

    // 2. Build the request body (if any)
    final requestBytes = schema.FooEndpointRequestObjectBuilder(
    ).toBytes();

    // 3. Call the runtime
    final responseBytes = await _runtime.call(endpointId: 3, method: "GET", path: path, requestBytes: requestBytes);
    if (responseBytes.isEmpty) {
      return null;
    }

    final jsonObject = jsonDecode(utf8.decode(responseBytes));
    return jsonObject as int?;
  }

}
