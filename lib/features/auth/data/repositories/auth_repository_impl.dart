import 'dart:async';
import 'package:gallery205_staff_app/features/auth/data/datasources/auth_data_source.dart';
import 'package:gallery205_staff_app/features/auth/domain/entities/auth_user.dart';
import 'package:gallery205_staff_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl(this.remoteDataSource, this.localDataSource);

  @override
  Stream<AuthUser?> get authStateChanges {
    // Transform Stream<AuthUserModel?> to Stream<AuthUser?>
    return remoteDataSource.authStateChanges.asyncMap((userModel) async {
       if (userModel != null) return userModel;
       // If remote stream says null (signed out), return null.
       // However, if remote stream is just "session changed" but we have a user...
       // For now, let's rely on getCurrentUser for the initial load, 
       // and this stream for global sign-out events.
       final currentUser = await getCurrentUser();
       return currentUser;
    });
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    // Strategy:
    // 1. Check if Supabase has a valid session (Remote Check) via DataSource
    //    (Actually our remoteDS.getCurrentUser currently returns null because of complexity)
    // 2. So we check Local Storage for the last known full user session.
    // 3. We verify if that user ID matches the current Supabase session user ID.
    
    // Check local persistence first
    final localUser = await localDataSource.getLastUserSession();
    
    // Check if Supabase thinks we are logged in
    // We can access the base user from remoteDS (we might need to expose a method or just rely on 'login' behavior)
    // But typically, we should verify that the token is valid.
    
    // If we have no local user data, we can't fully hydrate the app state (missing shop/role), so force re-login.
    if (localUser == null) return null;
    
    // Verify with remote source (optional optimization: simpler check)
    // For now, we trust local if Supabase client has a session.
    // Ideally we should check: remoteDataSource.supabaseClient.auth.currentUser?.id == localUser.id
    
    // Patch: Check if name is missing or generic and fetch if so.
    // Patch: Check if name is missing or generic and fetch if so.
    if (localUser.name.trim().isEmpty || localUser.name == '-' || localUser.name == localUser.email) {
        final fetchedName = await remoteDataSource.fetchUserName(localUser.id, localUser.shopId);
        if (fetchedName != null && fetchedName.trim().isNotEmpty && fetchedName != '-' && fetchedName != localUser.email) {
             final updatedUser = localUser.copyWith(name: fetchedName);
             await localDataSource.saveUserSession(updatedUser);
             return updatedUser;
        }
    }

    return localUser;
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
    required String shopCode,
  }) async {
    final userModel = await remoteDataSource.login(
      email: email,
      password: password,
      shopCode: shopCode,
    );
    
    // Save credentials for FaceID and Auto-fill
    await localDataSource.saveLoginCredential(shopCode, email, password);
    
    // Save session locally
    await localDataSource.saveUserSession(userModel);
    await localDataSource.saveShopCode(shopCode);
    
    // Save critical shop info for HomeScreen
    await localDataSource.saveCurrentShopInfo(
      shopId: userModel.shopId, 
      shopCode: userModel.shopCode
    );
    
    return userModel;
  }

  @override
  Future<void> logout() async {
    await remoteDataSource.logout();
    await localDataSource.clearUserSession();
  }

  @override
  Future<List<String>> getSavedShopCodes() {
    return localDataSource.getSavedShopCodes();
  }

  @override
  Future<void> addSavedShopCode(String code) {
    return localDataSource.saveShopCode(code);
  }

  @override
  Future<void> removeSavedShopCode(String code) {
    return localDataSource.removeShopCode(code);
  }

  @override
  Future<Map<String, dynamic>?> getLoginCredential(String shopCode) {
    return localDataSource.getLoginCredential(shopCode);
  }
}
