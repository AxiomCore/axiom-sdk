// GENERATED CODE – DO NOT EDIT.
// ignore_for_file: unused_import
// ignore_for_file: invalid_null_aware_operator

import 'dart:typed_data';

enum UserRole {
  admin,
  user,
  ;

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

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      role: (json['role'] == null ? null : UserRole.fromJson(json['role'])),
      email: json['email'] as String,
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

