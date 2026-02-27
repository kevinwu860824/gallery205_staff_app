import 'package:gallery205_staff_app/features/auth/domain/entities/auth_user.dart';

class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.email,
    required super.shopId,
    required super.shopCode,
    required super.role,
    super.name,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'],
      email: json['email'],
      shopId: json['shopId'],
      shopCode: json['shopCode'],
      role: json['role'],
      name: (json['name'] != null && json['name'].toString().trim().isNotEmpty) ? json['name'] : (json['email'] ?? ''),
    );
  }

  AuthUserModel copyWith({
    String? id,
    String? email,
    String? shopId,
    String? shopCode,
    String? role,
    String? name,
  }) {
    return AuthUserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      shopId: shopId ?? this.shopId,
      shopCode: shopCode ?? this.shopCode,
      role: role ?? this.role,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'shopId': shopId,
      'shopCode': shopCode,
      'role': role,
      'name': name,
    };
  }
}
