import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 移除 flutter_dynamic_icon 的 import

import 'package:gallery205_staff_app/core/providers/theme_provider.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  // 移除了 _changeAppIcon 函式，因為我們現在固定使用單一圖示

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentThemeMode = ref.watch(themeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.settingAppearance,
          style: AppTextStyles.homeAppBarTitle.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. App Default (Sage)
                _buildThemeItem(
                  context,
                  ref,
                  label: l10n.themeSage, 
                  mode: AppThemeMode.sage,
                  isSelected: currentThemeMode == AppThemeMode.sage,
                ),

                // Separator
                Divider(
                  height: 1,
                  color: colorScheme.onSurface.withOpacity(0.1),
                  indent: 16,
                  endIndent: 16,
                ),

                // 2. Dark Mode
                _buildThemeItem(
                  context,
                  ref,
                  label: l10n.themeDark,
                  mode: AppThemeMode.dark,
                  isSelected: currentThemeMode == AppThemeMode.dark,
                ),

                // Separator
                Divider(
                  height: 1,
                  color: colorScheme.onSurface.withOpacity(0.1),
                  indent: 16,
                  endIndent: 16,
                ),

                // 3. Light Mode
                _buildThemeItem(
                  context,
                  ref,
                  label: l10n.themeLight,
                  mode: AppThemeMode.light,
                  isSelected: currentThemeMode == AppThemeMode.light,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeItem(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required AppThemeMode mode, 
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return CupertinoListTile(
      title: Text(
        label,
        style: AppTextStyles.settingsListItem.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? const Icon(CupertinoIcons.checkmark_alt, color: AppColors.loginAccent)
          : null,
      onTap: () {
        // 只保留切換 App 內顏色的邏輯
        ref.read(themeProvider.notifier).setThemeMode(mode);
      },
      backgroundColor: Colors.transparent, 
    );
  }
}