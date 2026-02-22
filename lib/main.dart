// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:gallery205_staff_app/core/routing/app_router.dart';
import 'package:gallery205_staff_app/core/services/bootstrap_service.dart';
import 'package:gallery205_staff_app/core/services/notification_helper.dart';
import 'package:gallery205_staff_app/core/services/localization_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:gallery205_staff_app/core/providers/theme_provider.dart';
import 'package:gallery205_staff_app/core/providers/theme_provider.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart'; // NEW

Future<void> main() async {
  await BootstrapService.init();
  
  // Initialize SharedPreferences here to inject into Riverpod
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
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