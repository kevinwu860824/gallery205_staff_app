import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/core/constants/app_constants.dart';
import 'package:gallery205_staff_app/features/auth/data/datasources/auth_data_source.dart';
import 'package:gallery205_staff_app/features/auth/data/models/auth_user_model.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;

  AuthRemoteDataSourceImpl(this.supabaseClient);

  @override
  Stream<AuthUserModel?> get authStateChanges {
    // This is complex because Supabase auth state doesn't natively carry our 'role' or 'shopId'
    // We might need to just rely on re-fetching the profile on auth change, 
    // or typically we use a StreamController that we feed.
    // For now, let's just listen to Supabase and yield null if signed out.
    // Full user hydration might occur in the Repository.
    return supabaseClient.auth.onAuthStateChange.asyncMap((event) async {
       final user = event.session?.user;
       if (user == null) return null;
       
       // Note: To get the full AuthUserModel (with role/shop), we need to query DB.
       // However, doing async DB calls in this stream transform can be tricky.
       // It is often better handled in the Repository or Logic layer.
       // Here we might just return the user if we have session metadata, or null.
       
       // For this implementation, we will act simple:
       // The Repository will handle hydrating the full user model.
       // The DataSource just wrappers the raw auth events if needed,
       // but strictly speaking, our AuthUserModel requires shop info which isn't in raw auth.
       
       return null; // Placeholder: Repository handles hydration via getCurrentUser calls.
    });
  }

  @override
  Future<String?> fetchUserName(String userId, String shopId) async {
    try {
      debugPrint('[AuthRemote] fetchUserName: userId=$userId, shopId=$shopId');
      // Wait, in previous step I passed localUser.shopId to this method.
      // But inside the method, I used 'shop_code' column eq shopId.
      // Let's verify if the column is 'shop_code' (UUID) or 'shop_id' (UUID).
      // Based on previous code: .eq('shop_code', shopId) in login().
      
      final response = await supabaseClient
          .from('user_shop_map')
          .select('users(name, email)')
          .eq('user_id', userId)
          .eq('shop_code', shopId)
          .maybeSingle();
      
      debugPrint('[AuthRemote] fetchUserName response: $response');
      
      if (response != null && response['users'] != null) {
         final name = response['users']['name'] as String?;
         if (name != null && name.isNotEmpty) return name;
         return response['users']['email'] as String?;
      }

      // Fallback: Query 'users' table directly (if RLS allows)
      // This is helpful if user_shop_map join fails for some reason.
      final userRes = await supabaseClient
          .from('users')
          .select('name')
          .eq('id', userId)
          .maybeSingle();
      
      if (userRes != null && userRes['name'] != null) {
          return userRes['name'] as String;
      }

      return null;
    } catch (e) {
      debugPrint('[AuthRemote] fetchUserName error: $e');
      return null;
    }
  }

  @override
  Future<AuthUserModel?> getCurrentUser() async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) return null;

    // We need to Hydrate the user with Shop and Role info.
    // Does the current session metadata contain it?
    // If we saved it in user_metadata, we could read it. 
    // Currently, typical Clean Architecture would query the relation tables.
    // However, we need to know *which* shop they are currently logged into.
    // This state is actually "App State" (Current Shop), not just "Auth State".
    
    // For now, returning null here and letting the UseCase/Provider orchestrate 
    // the "Check Local Storage for Last Shop -> Verify Token" flow is safer.
    return null; 
  }

  @override
  Future<AuthUserModel> login({
    required String email, 
    required String password, 
    required String shopCode
  }) async {
    // 1. Authenticate with Supabase Auth
    final response = await supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    final user = response.user;
    if (user == null) {
      throw Exception('Login failed: No user returned');
    }

    // 2. Validate Shop Code exists and get Shop ID
    final shopRes = await supabaseClient
        .from('shops')
        .select('id')
        .eq('code', shopCode)
        .maybeSingle();

    if (shopRes == null) {
      // Cleanup: Sign out if shop validation fails
      await supabaseClient.auth.signOut();
      throw Exception('Shop code not found: $shopCode');
    }
    
    final shopId = shopRes['id'] as String;

    // 3. Validate User Role in this Shop
    final mappingRes = await supabaseClient
        .from('user_shop_map')
        .select('role, users(name)') // Fetch name too
        .eq('user_id', user.id)
        .eq('shop_code', shopId) 
        .maybeSingle();

    if (mappingRes == null) {
      await supabaseClient.auth.signOut();
      throw Exception('User has no permission for this shop');
    }
    
    final role = mappingRes['role'] as String;
    String? nameFromDb;
    if (mappingRes['users'] != null) {
      nameFromDb = mappingRes['users']['name'];
    }

    return AuthUserModel(
      id: user.id,
      email: user.email ?? email,
      shopId: shopId,
      shopCode: shopCode,
      role: role,
      name: nameFromDb ?? user.userMetadata?['name'] ?? user.email ?? email,
    );
  }

  @override
  Future<void> logout() async {
    await supabaseClient.auth.signOut();
  }
}
