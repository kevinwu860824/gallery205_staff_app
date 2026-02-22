import 'package:gallery205_staff_app/features/auth/domain/entities/auth_user.dart';

abstract class AuthRepository {
  /// Stream of the current authenticated user. Emits null if logged out.
  Stream<AuthUser?> get authStateChanges;

  /// Gets the current authenticated user if any.
  Future<AuthUser?> getCurrentUser();

  /// Logs in with email, password, and shopCode.
  /// Throws specific exceptions for failures.
  Future<AuthUser> login({
    required String email,
    required String password,
    required String shopCode,
  });

  /// Logs out the current user.
  Future<void> logout();
  
  /// Gets list of saved shop codes for the device
  Future<List<String>> getSavedShopCodes();
  
  /// Adds a new shop code to local storage
  Future<void> addSavedShopCode(String code);

  /// Removes a shop code from local storage
  Future<void> removeSavedShopCode(String code);

  /// Gets saved credential for a shop code (for auto-fill)
  Future<Map<String, dynamic>?> getLoginCredential(String shopCode);
}
