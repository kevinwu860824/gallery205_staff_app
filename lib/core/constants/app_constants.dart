// lib/core/constants/app_constants.dart

/// AppConstants 類別
///
/// 用於存放整個 App 中共享的靜態常數，
/// 例如類別列表、設定鍵(key)等，
/// 以確保所有地方都使用相同的值。

class AppConstants {

  /// 費用類別
  ///
  /// 用於 Daily Cost (cost_input_screen.dart)
  /// 用於 Monthly Cost (monthly_cost_input_screen.dart)
  /// 用於 Cost Detail (cost_detail_screen.dart)
  static const List<String> expenseCategories = [
    '調酒', 
    '廚房', 
    '雜項', 
    '其他', 
    '好市多',
    '每月固定支出'
  ];

  // --- Supabase Tables ---
  static const String tableInventoryItems = 'inventory_items';
  static const String tableInventoryCategories = 'inventory_categories';
  static const String tableUserFcmTokens = 'user_fcm_tokens';
  static const String tableUsers = 'users';

  // --- Storage Buckets ---
  static const String bucketInventoryImages = 'inventory_images';

  // --- Shared Preferences Keys ---
  static const String keyLanguageCode = 'language_code';
  static const String keySavedShopId = 'savedShopId';

}