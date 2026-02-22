import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/auth/data/datasources/auth_data_source.dart';
import 'package:gallery205_staff_app/features/auth/data/models/auth_user_model.dart';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  static const String keySavedShopCodes = 'savedShopCodeList';
  static const String keyLastUserSession = 'lastUserSession';

  AuthLocalDataSourceImpl(this.sharedPreferences);

  @override
  Future<List<String>> getSavedShopCodes() async {
    return sharedPreferences.getStringList(keySavedShopCodes) ?? [];
  }

  @override
  Future<void> saveShopCode(String code) async {
    final list = sharedPreferences.getStringList(keySavedShopCodes) ?? [];
    if (!list.contains(code)) {
      list.add(code);
      await sharedPreferences.setStringList(keySavedShopCodes, list);
    }
  }

  @override
  Future<void> removeShopCode(String code) async {
    final list = sharedPreferences.getStringList(keySavedShopCodes) ?? [];
    if (list.contains(code)) {
      list.remove(code);
      await sharedPreferences.setStringList(keySavedShopCodes, list);
    }
  }

  @override
  Future<void> saveUserSession(AuthUserModel user) async {
    await sharedPreferences.setString(keyLastUserSession, jsonEncode(user.toJson()));
  }

  @override
  Future<AuthUserModel?> getLastUserSession() async {
    final jsonStr = sharedPreferences.getString(keyLastUserSession);
    if (jsonStr == null) return null;
    try {
      return AuthUserModel.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearUserSession() async {
    await sharedPreferences.remove(keyLastUserSession);
  }

  @override
  Future<Map<String, dynamic>?> getLoginCredential(String shopCode) async {
     final savedLoginsRaw = sharedPreferences.getString('savedLogins');
     if (savedLoginsRaw == null) return null;
     
     final Map<String, dynamic> loginMap = jsonDecode(savedLoginsRaw);
     // The key format used in legacy code was '$shopCode+$email'.
     // But we want to find by shopCode primarily to auto-fill.
     // The legacy code searched for keys starting with '$shopCode+'.
     
     final matchingKey = loginMap.keys.firstWhere(
      (key) => key.startsWith('$shopCode+'),
      orElse: () => '',
    );
    
    if (matchingKey.isNotEmpty) {
      return loginMap[matchingKey];
    }
    return null;
  }

  @override
  Future<void> saveLoginCredential(String shopCode, String email, String password) async {
      final savedLoginsRaw = sharedPreferences.getString('savedLogins');
      final Map<String, dynamic> loginMap = savedLoginsRaw != null ? jsonDecode(savedLoginsRaw) : {};

      final key = '$shopCode+$email';
      loginMap[key] = {
        'shopCode': shopCode,
        'email': email,
        'password': password
      };
      await sharedPreferences.setString('savedLogins', jsonEncode(loginMap));
  }

  @override
  Future<void> saveCurrentShopInfo({required String shopId, required String shopCode}) async {
    await sharedPreferences.setString('savedShopId', shopId);
    await sharedPreferences.setString('savedShopCode', shopCode);
  }
}
