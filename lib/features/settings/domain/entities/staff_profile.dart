import 'package:equatable/equatable.dart';

class StaffProfile extends Equatable {
  final String id;
  final String email;
  final String name; // Display Name
  final String shopId;
  final String roleName;
  final List<String> permissions; // List of permission codes (e.g., 'view_reports', 'manage_table')

  const StaffProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.shopId,
    required this.roleName,
    required this.permissions,
  });

  @override
  List<Object?> get props => [id, email, name, shopId, roleName, permissions];
}
