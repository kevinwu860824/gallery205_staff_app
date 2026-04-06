// lib/features/settings/presentation/language_settings_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:gallery205_staff_app/main.dart'; // 引入 main.dart 以呼叫 setLocale

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  // 輔助方法：獲取當前語言的唯一識別 Key，用於判斷 Checkmark
  String _getCurrentLocaleKey(Locale locale) {
    if (locale.languageCode == 'zh') {
      // 判斷中文是簡體 (Hans) 還是繁體 (Hant)
      if (locale.scriptCode == 'Hans' || locale.countryCode == 'CN') {
        return 'zh-Hans';
      }
      // 如果是 zh 且不是 Hans，預設為繁體 (Hant)
      return 'zh-Hant';
    }
    // 對於其他單語言代碼 (如 en, it)，直接返回 languageCode
    return locale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);
    final currentLanguageKey = _getCurrentLocaleKey(currentLocale);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.settingLanguage, 
          style: AppTextStyles.homeAppBarTitle.copyWith(color: colorScheme.onSurface)
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        elevation: 0,
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
            final double hPadding = isTablet
                ? (MediaQuery.of(context).size.width - 600) / 2
                : 16.0;
            return Padding(
          padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. English
                _buildLanguageItem(
                  context, 
                  label: l10n.languageEnglish, 
                  localeToSet: const Locale('en'), 
                  isSelected: currentLanguageKey == 'en'
                ),
                
                // 分隔線
                Divider(
                  height: 1, 
                  color: theme.dividerColor, 
                  indent: 16, 
                  endIndent: 16
                ),

                // 2. 繁體中文 (zh-Hant)
                _buildLanguageItem(
                  context, 
                  label: l10n.languageTraditionalChinese, 
                  // 設定為帶有腳本代碼的繁體中文
                  localeToSet: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), 
                  isSelected: currentLanguageKey == 'zh-Hant'
                ),

                // 分隔線
                Divider(
                  height: 1, 
                  color: theme.dividerColor, 
                  indent: 16, 
                  endIndent: 16
                ),
                
                // 3. 簡體中文 (zh-Hans) 🎯 新增
                _buildLanguageItem(
                  context, 
                  label: l10n.languageSimplifiedChinese, 
                  // 設定為帶有腳本代碼的簡體中文
                  localeToSet: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'), 
                  isSelected: currentLanguageKey == 'zh-Hans'
                ),
                
                // 分隔線
                Divider(
                  height: 1, 
                  color: theme.dividerColor, 
                  indent: 16, 
                  endIndent: 16
                ),

                // 4. 義大利文 (it) 🎯 新增
                _buildLanguageItem(
                  context, 
                  label: l10n.languageItalian, 
                  localeToSet: const Locale('it'), 
                  isSelected: currentLanguageKey == 'it'
                ),

                // 分隔線
                Divider(
                  height: 1, 
                  color: theme.dividerColor, 
                  indent: 16, 
                  endIndent: 16
                ),

                // 5. 越南文 (vi) 🎯 新增
                _buildLanguageItem(
                  context, 
                  label: l10n.languageVietnamese, 
                  localeToSet: const Locale('vi'), 
                  isSelected: currentLanguageKey == 'vi'
                ),
              ],
            ),
          ),
          );
          },
        ),
      ),
    );
  }

  // 調整 _buildLanguageItem 參數以接受 Locale 物件
  Widget _buildLanguageItem(BuildContext context, {required String label, required Locale localeToSet, required bool isSelected}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return CupertinoListTile(
      title: Text(
        label,
        style: AppTextStyles.settingsListItem.copyWith(color: colorScheme.onSurface),
      ),
      trailing: isSelected 
          ? Icon(CupertinoIcons.checkmark_alt, color: colorScheme.primary) 
          : null,
      onTap: () {
        // 呼叫 main.dart 裡的靜態方法來切換語言，傳遞完整的 Locale 物件
        MyApp.setLocale(context, localeToSet);
      },
    );
  }
}