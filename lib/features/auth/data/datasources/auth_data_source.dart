import 'package:gallery205_staff_app/features/auth/data/models/auth_user_model.dart';

abstract class AuthRemoteDataSource {
  Stream<AuthUserModel?> get authStateChanges;
  
  Future<AuthUserModel?> getCurrentUser();

  Future<String?> fetchUserName(String userId, String shopId);
  
  Future<AuthUserModel> login({
    required String email, 
    required String password, 
    required String shopCode
  });
  
  Future<void> logout();
}

abstract class AuthLocalDataSource {
  Future<List<String>> getSavedShopCodes();
  Future<void> saveShopCode(String code);
  Future<void> removeShopCode(String code);
  
  Future<void> saveUserSession(AuthUserModel user);
  Future<AuthUserModel?> getLastUserSession();
  Future<void> clearUserSession();

  // Credentials Management
  Future<Map<String, dynamic>?> getLoginCredential(String shopCode);
  Future<void> saveLoginCredential(String shopCode, String email, String password);
  
  // Persist current active shop info for HomeScreen usage
  Future<void> saveCurrentShopInfo({required String shopId, required String shopCode});
}
