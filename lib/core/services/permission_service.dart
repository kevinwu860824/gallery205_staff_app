// lib/core/services/permission_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PermissionService {
  // 1. 單例模式 (Singleton)：確保整個 APP 都使用同一個服務實體
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // 2. 儲存目前已載入的權限清單 (使用 Set 搜尋速度比 List 快)
  final Set<String> _activePermissions = {};
  bool _isAdmin = false;
  /// 3. 檢查是否擁有某個權限
  /// 
  /// 用法範例: 
  /// if (PermissionService().hasPermission(AppPermissions.inventoryView)) { ... }
  bool hasPermission(String permissionKey) {
    if (_isAdmin) return true;
    return _activePermissions.contains(permissionKey);
  }

  /// 4. 從資料庫載入權限
  /// 
  /// 通常在使用者登入或切換店家後呼叫此方法
  Future<void> loadPermissions(String roleId, {String? roleName}) async {
    _activePermissions.clear();
    _isAdmin = false; // 重置狀態

    // ✅ 檢查是否為 Admin (不分大小寫)
    if (roleName != null && roleName.toLowerCase() == 'admin') {
      _isAdmin = true;
      debugPrint('👑 Admin 登入：權限全開 (Super Admin Mode)');
      return; // Admin 不需查表，直接結束
    }

    try {
      final response = await Supabase.instance.client
          .from('shop_role_permissions')
          .select('permission_key')
          .eq('role_id', roleId);

      final List<dynamic> data = response as List<dynamic>;

      for (var row in data) {
        if (row['permission_key'] != null) {
          _activePermissions.add(row['permission_key'] as String);
        }
      }
      debugPrint('✅ 權限載入成功 ($roleName): $_activePermissions');
      
    } catch (e) {
      debugPrint('❌ 載入權限失敗: $e');
    }
  }

  /// 清除權限 (登出用)
  void clear() {
    _activePermissions.clear();
    _isAdmin = false;
  }
}