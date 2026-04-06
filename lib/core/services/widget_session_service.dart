import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 把目前的登入 session 同步到 iOS App Group，
/// 讓 ScheduleWidget 能讀取並直接呼叫 Supabase API。
class WidgetSessionService {
  static const _channel = MethodChannel(
    'com.caffreywu.tableOrderingApp/widget_session',
  );

  /// 在 App 啟動、登入後呼叫此方法。
  static Future<void> syncSession() async {
    if (!Platform.isIOS) return;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final userId  = Supabase.instance.client.auth.currentUser?.id;
      if (session == null || userId == null) return;

      final prefs  = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId') ?? '';

      await _channel.invokeMethod('saveSession', {
        'jwt':     session.accessToken,
        'user_id': userId,
        'shop_id': shopId,
      });
    } catch (_) {}
  }

  /// 登出後呼叫，清除 Widget 的 session。
  static Future<void> clearSession() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('clearSession');
    } catch (_) {}
  }

  /// 當新增、修改、刪除事件後呼叫，強制更新 Widget
  static Future<void> reloadWidget() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('reloadWidget');
    } catch (_) {}
  }
}
