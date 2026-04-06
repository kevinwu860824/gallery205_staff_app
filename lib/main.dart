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
import 'package:gallery205_staff_app/core/providers/connectivity_provider.dart';
import 'package:gallery205_staff_app/core/widgets/offline_banner.dart';
import 'package:gallery205_staff_app/core/services/hub_client.dart';
import 'package:gallery205_staff_app/core/services/hub_server.dart';
import 'package:gallery205_staff_app/core/constants/app_constants.dart';

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

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedLanguage();
    // Note: Listener is moved to build() for Riverpod
    WidgetsBinding.instance.addPostFrameCallback((_) => _initHubServices());
  }

  Future<void> _initHubServices() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final isHub = prefs.getBool(AppConstants.keyIsHubDevice) ?? false;
    if (isHub) {
      final server = ref.read(hubServerProvider);
      server.onOrderChanged = () {
        ref.read(orderingRepositoryProvider).syncOfflineOrders();
      };
      server.onSyncRequested = () async {
        await ref.read(orderingRepositoryProvider).syncOfflineOrders();
      };
      await server.start();
    } else {
      HubClient().init((available) {
        if (mounted) {
          ref.read(hubAvailableProvider.notifier).state = available;
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App 從背景回到前景時，觸發離線訂單同步 + Hub Server 重啟
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed — checking offline sync');
      ref.read(orderingRepositoryProvider).syncOfflineOrders();

      final prefs = ref.read(sharedPreferencesProvider);
      final isHub = prefs.getBool(AppConstants.keyIsHubDevice) ?? false;
      if (isHub) {
        final server = ref.read(hubServerProvider);
        server.onOrderChanged ??= () {
          ref.read(orderingRepositoryProvider).syncOfflineOrders();
        };
        if (!server.isRunning) {
          server.start();
          debugPrint('🔄 Hub server restarted on resume');
        }
      }
    }
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

    // 監聽網路狀態：斷線 → 上線時自動觸發離線訂單同步
    ref.listen(isOnlineProvider, (previous, next) {
      final wasOffline = previous?.value == false;
      final nowOnline = next.value == true;
      if (wasOffline && nowOnline) {
        debugPrint('🌐 Network restored — syncing offline orders');
        ref.read(orderingRepositoryProvider).syncOfflineOrders();
      }
    });

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

      // 全域狀態 Banner：疊在所有畫面頂部
      builder: (context, child) {
        return Column(
          children: [
            const OfflineBanner(),
            Expanded(child: child ?? const SizedBox()),
          ],
        );
      },
    );
  }
}