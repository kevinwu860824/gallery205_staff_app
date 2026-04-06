
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'package:gallery205_staff_app/core/services/notification_helper.dart';
import 'package:gallery205_staff_app/core/services/widget_session_service.dart';

class BootstrapService {
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Timezone & Locale
    tz.initializeTimeZones();
    await initializeDateFormatting('zh_TW', null);

    // 2. Env
    await dotenv.load(fileName: ".env");

    // 3. Backend Services
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    await Firebase.initializeApp();

    // 4. Local Notifications
    await NotificationHelper.init();

    // 5. Sync widget session on ANY auth state change (login, token refresh, logout)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      switch (data.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          await WidgetSessionService.syncSession();
          break;
        case AuthChangeEvent.signedOut:
          await WidgetSessionService.clearSession();
          break;
        default:
          break;
      }
    });
  }
}
