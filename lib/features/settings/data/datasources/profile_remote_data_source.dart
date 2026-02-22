import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/features/settings/data/models/staff_profile_model.dart';
import 'package:flutter/foundation.dart';

abstract class ProfileRemoteDataSource {
  Future<StaffProfileModel> fetchUserProfile(String userId, String shopId);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient supabaseClient;

  ProfileRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<StaffProfileModel> fetchUserProfile(String userId, String shopId) async {
    try {
      // 1. Get Basic User Info (Auth)
      final User? user = supabaseClient.auth.currentUser;
      if (user == null || user.id != userId) throw Exception("User not authenticated or ID mismatch");

      // 2. Get User-Shop Map (Role & Name)
      // Join 'shop_roles' table to get role name.
      // Note: The foreign key in 'user_shop_map' likely points to 'shop_roles'.
      // If the FK name is standard, it should find 'shop_roles'.
      final userShopRes = await supabaseClient
          .from('user_shop_map')
          .select('shop_code, role_id, shop_roles(id, name), users(name, email)') 
          .eq('user_id', userId)
          .eq('shop_code', shopId)
          .single();

      // 3. Get Permissions via Role
      // Query 'shop_role_permissions' directly. It stores 'permission_key'.
      final roleId = userShopRes['role_id'];
      List<String> permissions = [];
      
      if (roleId != null) {
        final permRes = await supabaseClient
            .from('shop_role_permissions')
            .select('permission_key')
            .eq('role_id', roleId);
            
        // Extract codes directly from 'permission_key'
        permissions = List<Map<String, dynamic>>.from(permRes)
            .map((e) => e['permission_key'] as String)
            .toList();
      }

      // 4. Construct Model
      return StaffProfileModel.fromMap(
        userShopRes,
        userShopRes,
        permissions
      );

    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      throw Exception("Failed to fetch profile: $e");
    }
  }
}
