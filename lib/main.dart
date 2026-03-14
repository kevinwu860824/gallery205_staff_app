// lib/main.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:gallery205_staff_app/core/routing/app_router.dart';
import 'package:gallery205_staff_app/core/services/bootstrap_service.dart';
import 'package:gallery205_staff_app/core/services/notification_helper.dart';
import 'package:gallery205_staff_app/core/services/localization_service.dart';
import 'package:gallery205_staff_app/core/widgets/app_error_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:gallery205_staff_app/core/providers/theme_provider.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart'; // NEW

Future<void> main() async {
  await BootstrapService.init();

  final prefs = await SharedPreferences.getInstance();

  await SentryFlutter.init(
    (options) {
      // DSN 透過 dart-define 注入：flutter build --dart-define=SENTRY_DSN=https://...
      // 空 DSN 時 Sentry 會自動停用，不影響開發
      options.dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      options.tracesSampleRate = 0.1;
      options.environment = const String.fromEnvironment('DART_ENV', defaultValue: 'production');
    },
    appRunner: () {
      // Release 模式下，Flutter framework 錯誤顯示友好的 fallback UI
      if (kReleaseMode) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return const AppErrorScreen();
        };
      }

      // 捕獲 Flutter framework 錯誤並回報到 Sentry
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        Sentry.captureException(details.exception, stackTrace: details.stack);
        originalOnError?.call(details);
      };

      // 捕獲未處理的 async 錯誤（Zone 外的錯誤）
      PlatformDispatcher.instance.onError = (error, stack) {
        Sentry.captureException(error, stackTrace: stack);
        return true;
      };

      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MyApp(),
        ),
      );
    },
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
    // Note: Listener is moved to build() for Riverpod
  }

  Future<void> _loadSavedLanguage() async {
    final locale = await LocalizationService.loadSavedLocale();
    if (locale != null) {
      setState(() => _locale = locale);
    }
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    LocalizationService.saveLocale(locale);
  }

  @override
  Widget build(BuildContext context) {
    // 監聽登入狀態以設定 FCM
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((user) {
         if (user != null) {
            debugPrint('👤 User Signed In (Riverpod), Setting up FCM...');
            NotificationHelper.setupFCM();
         }
      });
    });

    // Activate InvoiceService (Global Listener)
    // Activate Background Services
    ref.watch(kitchenTicketServiceProvider);
    ref.watch(invoiceServiceProvider);

    final appThemeMode = ref.watch(themeProvider);

    ThemeData lightThemeToUse;
    ThemeMode flutterThemeMode;

    switch (appThemeMode) {
      case AppThemeMode.sage:
        lightThemeToUse = AppTheme.sageTheme;
        flutterThemeMode = ThemeMode.light; // Sage runs as a "Light" mode
        break;
      case AppThemeMode.light:
        lightThemeToUse = AppTheme.lightTheme;
        flutterThemeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        lightThemeToUse = AppTheme.lightTheme; // Not used, but fallback
        flutterThemeMode = ThemeMode.dark;
        break;
    }

    return MaterialApp.router(
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.homeTitle ?? 'Gallery 20.5',
      
      // --- Theme Configuration ---
      themeMode: flutterThemeMode,
      theme: lightThemeToUse,
      darkTheme: AppTheme.darkTheme,
      // ---------------------------

      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [
        Locale('en', ''),                                      
        Locale('it', ''),                                      
        Locale('zh', ''),                                      
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), 
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'), 
        Locale('vi', ''),
      ],
    );
  }
}