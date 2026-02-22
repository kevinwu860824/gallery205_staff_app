import 'package:gallery205_staff_app/features/settings/domain/entities/staff_profile.dart';

class StaffProfileModel extends StaffProfile {
  const StaffProfileModel({
    required super.id,
    required super.email,
    required super.name,
    required super.shopId,
    required super.roleName,
    required super.permissions,
  });

  // Factory to create from Supabase response (usually complex join)
  factory StaffProfileModel.fromMap(Map<String, dynamic> userMap, Map<String, dynamic> shopMap, List<String> permissionList) {
    return StaffProfileModel(
      id: userMap['id'] ?? '',
      email: userMap['email'] ?? '',
      name: userMap['users'] != null ? userMap['users']['name'] : 'Unknown', 
      shopId: shopMap['shop_code'] ?? '',
      roleName: shopMap['shop_roles'] != null ? shopMap['shop_roles']['name'] : 'Unknown', // Join result
      permissions: permissionList,
    );
  }
}
