
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'package:gallery205_staff_app/core/services/notification_helper.dart';

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
  }
}
