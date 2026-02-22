
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  static const String _keyLanguageCode = 'language_code';

  static Future<Locale?> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyLanguageCode);
    if (code == null) return null;

    final parts = code.split('-');
    if (parts.length > 1) {
      return Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]);
    } else {
      return Locale(code);
    }
  }

  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    final codeToSave = locale.scriptCode != null && locale.scriptCode!.isNotEmpty
        ? '${locale.languageCode}-${locale.scriptCode}'
        : locale.languageCode;
    await prefs.setString(_keyLanguageCode, codeToSave);
  }
}
