// lib/core/services/notification_helper.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:gallery205_staff_app/core/routing/app_router.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notification =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notification.initialize(settings);
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    await _notification.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          'calendar_channel',
          'Calendar Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      // ✅ v19 正確且「唯一」需要的排程設定
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancel(int id) async {
    await _notification.cancel(id);
  }

  // --- FCM (Firebase Cloud Messaging) Logic ---

  static Future<void> setupFCM() async {
    final messaging = FirebaseMessaging.instance;
    
    // 1. Request Permission
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('🔕 User declined notification permission');
      return;
    }
    debugPrint('🔔 Notification permission granted');

    // 2. iOS APNs Token Check
    if (Platform.isIOS) {
      String? apnsToken = await messaging.getAPNSToken();
      if (apnsToken == null) {
        await Future.delayed(const Duration(seconds: 3));
        apnsToken = await messaging.getAPNSToken();
      }
      debugPrint('🍎 APNs Token: $apnsToken');
    }

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Get & Save FCM Token
    await _uploadToken();

    // 4. Listen for Token Refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _uploadToken(token: newToken);
    });

    // 5. Setup Handlers
    _setupForegroundHandler();
    _setupBackgroundHandler();
  }

  static Future<void> _uploadToken({String? token}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
    debugPrint('🔥 FCM Token: $fcmToken');

    if (fcmToken != null) {
      try {
        await supabase.from('user_fcm_tokens').upsert(
          {
            'user_id': user.id,
            'token': fcmToken,
            'platform': Platform.isIOS ? 'ios' : 'android',
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'token',
        );
        debugPrint('✅ FCM Token uploaded');
      } catch (e) {
        debugPrint('❌ Token upload failed: $e');
      }
    }
  }

  static void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔥 [Foreground] FCM Message: ${message.notification?.title}');
      
      final notification = message.notification;
      
      if (notification != null) {
        scheduleNotification(
          id: notification.hashCode,
          title: notification.title ?? 'New Notification',
          body: notification.body ?? '',
          scheduledDate: DateTime.now().add(const Duration(seconds: 1)),
        );
      }
    });
  }

  static Future<void> _setupBackgroundHandler() async {
    // App in background -> Open App
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    
    // App Terminated -> Open App
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }

  static void _handleMessage(RemoteMessage message) {
    if (message.data['route'] != null) {
      final routePath = message.data['route'];
      debugPrint('🚀 Notification tapped, navigating to: $routePath');
      appRouter.push(routePath);
    }
  }
}
