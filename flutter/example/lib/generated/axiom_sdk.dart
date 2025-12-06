// GENERATED CODE – DO NOT EDIT.
// Axiom SDK for 

import 'axiom_runtime.dart';
import 'package:example/generated/schema_axiom_generated.dart' as schema;

class AxiomSdk {
  final AxiomRuntime _runtime;
  AxiomSdk({required String baseUrl})
    : _runtime = AxiomRuntime() {
    _runtime.initialize(baseUrl);
  }

  /// Endpoint "get_user"
  /// Path: /users/{user_id}
  /// IR endpoint id: 0
  Future<schema.User> getUser({required int userId}) async {
    final requestBytes = schema.GetUserRequestObjectBuilder(
      userId: userId,
    ).toBytes();
    final responseBytes = await _runtime.call(
      endpointId: 0,
      requestBytes: requestBytes,
    );
    final resp = schema.GetUserResponse(responseBytes);
    final value = resp.data;
    if (value == null) { throw StateError("GetUserResponse.data was null"); }
    return value;
  }

  /// Endpoint "list_users"
  /// Path: /users
  /// IR endpoint id: 1
  Future<List<schema.User>> listUsers({required int limit}) async {
    final requestBytes = schema.ListUsersRequestObjectBuilder(
      limit: limit,
    ).toBytes();
    final responseBytes = await _runtime.call(
      endpointId: 1,
      requestBytes: requestBytes,
    );
    final resp = schema.ListUsersResponse(responseBytes);
    final items = resp.data;
    if (items == null) return <schema.User>[];
    return List<schema.User>.unmodifiable(items);
  }

  /// Endpoint "create_user"
  /// Path: /users
  /// IR endpoint id: 2
  Future<schema.Message> createUser({required schema.User user}) async {
    final requestBytes = schema.CreateUserRequestObjectBuilder(
      user: schema.UserObjectBuilder(
        id: user.id,
        name: user.name,
        email: user.email,
      ),
    ).toBytes();
    final responseBytes = await _runtime.call(
      endpointId: 2,
      requestBytes: requestBytes,
    );
    final resp = schema.CreateUserResponse(responseBytes);
    final value = resp.data;
    if (value == null) { throw StateError("CreateUserResponse.data was null"); }
    return value;
  }

}
