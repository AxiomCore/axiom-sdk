// GENERATED CODE – DO NOT EDIT.
// Axiom SDK for 

import 'package:axiom_flutter/axiom_flutter.dart';
import 'package:example/generated/schema_axiom_generated.dart' as schema;
import 'package:example/generated/models.dart' as models;

class AxiomSdk {
  final AxiomRuntime _runtime;

  // Private constructor to ensure proper initialization.
  AxiomSdk._(this._runtime);

  /// Asynchronously creates and initializes the Axiom SDK.
  static Future<AxiomSdk> create({required String baseUrl}) async {
    // Get the singleton instance of the runtime.
    final runtime = AxiomRuntime();
    // Ensure the background isolate is running and ready.
    await runtime.init();
    // Set the base URL for the runtime.
    runtime.initialize(baseUrl);
    // Return the fully initialized SDK.
    return AxiomSdk._(runtime);
  }

  /// Endpoint "get_user"
  /// Path: /users/{user_id}
  /// IR endpoint id: 0
  Future<models.User> getUser({required int userId}) async {
    final requestBytes = schema.GetUserRequestObjectBuilder(
      userId: userId,
    ).toBytes();
    final responseBytes = await _runtime.call(
      endpointId: 0,
      requestBytes: requestBytes,
    );
    final resp = schema.GetUserResponse(responseBytes);
    final schemaValue = resp.data;
    if (schemaValue == null) { throw StateError("GetUserResponse.data was null"); }
    return models.User.fromSchema(schemaValue);
  }

  /// Endpoint "list_users"
  /// Path: /users
  /// IR endpoint id: 1
  Future<List<models.User>> listUsers({required int limit}) async {
    final requestBytes = schema.ListUsersRequestObjectBuilder(
      limit: limit,
    ).toBytes();
    final responseBytes = await _runtime.call(
      endpointId: 1,
      requestBytes: requestBytes,
    );
    final resp = schema.ListUsersResponse(responseBytes);
    final schemaItems = resp.data;
    if (schemaItems == null) return <models.User>[];
    return schemaItems.map((e) => models.User.fromSchema(e)).toList();
  }

  /// Endpoint "create_user"
  /// Path: /users
  /// IR endpoint id: 2
  Future<models.Message> createUser({required models.User user}) async {
    final requestBytes = schema.CreateUserRequestObjectBuilder(
      user: schema.UserObjectBuilder(
        id: user.id,
        name: user.name,
        role: user.role,
        email: user.email,
      ),
    ).toBytes();
    final responseBytes = await _runtime.call(
      endpointId: 2,
      requestBytes: requestBytes,
    );
    final resp = schema.CreateUserResponse(responseBytes);
    final schemaValue = resp.data;
    if (schemaValue == null) { throw StateError("CreateUserResponse.data was null"); }
    return models.Message.fromSchema(schemaValue);
  }

}
