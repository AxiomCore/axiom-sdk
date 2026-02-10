// GENERATED CODE – DO NOT EDIT.
// User-facing data models.

import 'package:example/generated/schema_axiom_generated.dart' as schema;

enum UserRole {
  admin,
  user;

  String toJson() => name;

  static UserRole fromJson(dynamic value) {
    if (value is String) {
      return UserRole.values.firstWhere(
        (e) => e.name == value,
        orElse: () => throw Exception('Unknown UserRole value: $value'),
      );
    }
    throw Exception('Expected String for UserRole, got $value');
  }

}

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
  Map<String, dynamic> toJson() {
    return {
      'message': message,
    };
  }
}

class User {
  final int id;
  final String name;
  final UserRole? role;
  final String email;

  const User({
    required this.id,
    required this.name,
    this.role,
    required this.email,
  });

  factory User.fromSchema(schema.User schemaModel) {
    return User(
      id: schemaModel.id!,
      name: schemaModel.name!,
      role: schemaModel.role != null ? UserRole.fromJson(schemaModel.role!) : null,
      email: schemaModel.email!,
    );
  }
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      role: json['role'] != null ? UserRole.fromJson(json['role']) : null,
      email: json['email'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role?.toJson(),
      'email': email,
    };
  }
}

