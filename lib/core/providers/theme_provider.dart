import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';

// Key for SharedPreferences
const String _kThemeModeKey = 'theme_mode';

// Custom Enum to support 3 distinct modes including our new Default (Sage)
enum AppThemeMode {
  sage,  // Default "Sage Calm"
  light, // Standard Light
  dark,  // Standard Dark
}

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  final SharedPreferences _prefs;

  ThemeNotifier(this._prefs) : super(_loadThemeMode(_prefs));

  static AppThemeMode _loadThemeMode(SharedPreferences prefs) {
    final savedMode = prefs.getString(_kThemeModeKey);
    if (savedMode == 'light') return AppThemeMode.light;
    if (savedMode == 'dark') return AppThemeMode.dark;
    if (savedMode == 'sage') return AppThemeMode.sage;
    
    // Default to Sage (App Default) if not set
    return AppThemeMode.sage; 
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    String modeStr;
    switch (mode) {
      case AppThemeMode.light:
        modeStr = 'light';
        break;
      case AppThemeMode.dark:
        modeStr = 'dark';
        break;
      case AppThemeMode.sage:
      default:
        modeStr = 'sage';
        break;
    }
    await _prefs.setString(_kThemeModeKey, modeStr);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});
