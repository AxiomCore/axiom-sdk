// GENERATED CODE – DO NOT EDIT.
// User-facing data models.

import 'package:example/generated/schema_axiom_generated.dart' as schema;

class Message {
  final String message;

  const Message({
    required this.message,
  });

  factory Message.fromSchema(schema.Message schemaModel) {
    return Message(
      message: schemaModel.message!,
    );
  }
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      message: json['message'],
    );
  }
}

class User {
  final int id;
  final String name;
  final String? role;
  final String? email;

  const User({
    required this.id,
    required this.name,
    this.role,
    this.email,
  });

  factory User.fromSchema(schema.User schemaModel) {
    return User(
      id: schemaModel.id!,
      name: schemaModel.name!,
      role: schemaModel.role,
      email: schemaModel.email,
    );
  }
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      email: json['email'],
    );
  }
}

