import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  final String id;
  final String email;
  final String shopId;
  final String shopCode;
  final String role;
  final String name;

  const AuthUser({
    required this.id,
    required this.email,
    required this.shopId,
    required this.shopCode,
    required this.role,
    this.name = '',
  });

  @override
  List<Object?> get props => [id, email, shopId, shopCode, role, name];
}
