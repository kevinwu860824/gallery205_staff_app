import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

import 'package:gallery205_staff_app/core/constants/app_permissions.dart';
import 'package:gallery205_staff_app/features/settings/presentation/providers/profile_providers.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:gallery205_staff_app/core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    // 1. 監聽 Profile 狀態
    final profileAsync = ref.watch(profileProvider);
    final permissionHelper = ref.watch(permissionProvider);
    
    // 2. 獲取使用者顯示名稱 (Loading 時顯示預設)
    final userName = profileAsync.maybeWhen(
      data: (profile) => profile.name,
      orElse: () => l10n.defaultUser,
    );

    final colorScheme = Theme.of(context).colorScheme;
    
    // 3. 處理 Loading 狀態
    // 如果第一次載入還在轉圈圈，顯示全螢幕 Loading
    if (profileAsync.isLoading && !profileAsync.hasValue) {
       return Scaffold(
         backgroundColor: Theme.of(context).scaffoldBackgroundColor,
         body: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
       );
    }

    final double kMinHeight =
        kToolbarHeight + MediaQuery.of(context).padding.top;

    // ==========================================================
    // 建立選項列表 (分類邏輯)
    // ==========================================================
    final List<Map<String, dynamic>> personnelOptions = [];
    final List<Map<String, dynamic>> menuInvOptions = [];
    final List<Map<String, dynamic>> equipTableOptions = [];
    final List<Map<String, dynamic>> systemOptions = [];

    // --- 1. 人員與權限管理 ---
    if (permissionHelper.hasPermission(AppPermissions.setStaff)) {
      personnelOptions.add({
        'icon': CupertinoIcons.group,
        'label': l10n.userMgmtTitle,
        'route': '/manageUsers',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.backPayroll)) {
      personnelOptions.add({
        'icon': CupertinoIcons.money_dollar_circle, 
        'label': l10n.settingPayroll,
        'route': '/payroll',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.setRole)) {
      personnelOptions.add({
        'icon': CupertinoIcons.lock_shield,
        'label': l10n.roleMgmtTitle,
        'route': '/roleManagement',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.setShift)) {
      personnelOptions.add({
        'icon': CupertinoIcons.clock,
        'label': l10n.shiftSetupTitle,
        'route': '/shiftSettings',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.setPunch)) {
      personnelOptions.add({
        'icon': CupertinoIcons.placemark,
        'label': l10n.punchInSetupTitle,
        'route': '/punchInSettings',
      });
    }

    // --- 2. 菜單與庫存設定 ---
    if (permissionHelper.hasPermission(AppPermissions.setMenu)) {
      menuInvOptions.add({
        'icon': CupertinoIcons.book,
        'label': l10n.menuEditTitle,
        'route': '/editMenu',
      });
      menuInvOptions.add({
        'icon': CupertinoIcons.eyedropper_full, 
        'label': l10n.settingModifiers,
        'route': '/editModifiers',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.setInv)) {
      menuInvOptions.addAll([
        {
          'icon': CupertinoIcons.cube_box,
          'label': l10n.inventoryManagementTitle,
          'route': '/manageInventory',
        },
        {
          'icon': CupertinoIcons.doc_text,
          'label': l10n.prepViewTitle,
          'route': '/editStockInfo',
        },
        {
          'icon': CupertinoIcons.list_bullet,
          'label': l10n.inventoryLogTitle,
          'route': '/inventoryLog',
        },
      ]);
    }

    // --- 3. 設備與桌位配置 ---
    if (permissionHelper.hasPermission(AppPermissions.setPrinter)) {
      equipTableOptions.add({
        'icon': CupertinoIcons.printer,
        'label': l10n.printerSettingsTitle,
        'route': '/printerSettings',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.setTableMap)) {
      equipTableOptions.add({
        'icon': CupertinoIcons.map,
        'label': l10n.settingTableMap,
        'route': '/manageTableMap',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.setTableList)) {
      equipTableOptions.add({
        'icon': CupertinoIcons.table_fill,
        'label': l10n.tableMgmtTitle,
        'route': '/manageTables',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.setCashReg)) {
      equipTableOptions.add({
        'icon': CupertinoIcons.archivebox,
        'label': l10n.cashRegSetupTitle,
        'route': '/cashSettings',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.setPay)) {
      equipTableOptions.add({
        'icon': CupertinoIcons.creditcard,
        'label': l10n.paymentSetupTitle,
        'route': '/paymentMethodSettings',
      });
    }
    if (permissionHelper.hasPermission(AppPermissions.setCostCat)) {
      equipTableOptions.add({
        'icon': CupertinoIcons.percent,
        'label': l10n.settingTax,
        'route': '/taxSettings',
      });
      equipTableOptions.add({
        'icon': CupertinoIcons.tag,
        'label': l10n.costCategoryTitle,
        'route': '/manageCostCategories',
      });
    }

    // --- 4. 系統設定 ---
    systemOptions.addAll([
      {
        'icon': CupertinoIcons.paintbrush,
        'label': l10n.settingAppearance,
        'route': '/appearanceSettings',
      },
      {
        'icon': CupertinoIcons.globe,
        'label': l10n.settingLanguage,
        'route': '/languageSettings',
      },
      {
        'icon': CupertinoIcons.lock,
        'label': l10n.changePasswordTitle,
        'route': '/changePassword',
      },
      {
        'icon': CupertinoIcons.arrow_right_square,
        'label': l10n.settingLogout,
        'action': 'logout', 
      },
    ]);

    // 建立分類卡片列表
    final List<Map<String, dynamic>> categories = [
      if (personnelOptions.isNotEmpty)
        {
          'id': 'personnel',
          'title': l10n.settingCategoryPersonnel,
          'icon': CupertinoIcons.person_2_fill,
          'options': personnelOptions,
          'color': const Color(0xFF5C7A6B),
        },
      if (menuInvOptions.isNotEmpty)
        {
          'id': 'menuInv',
          'title': l10n.settingCategoryMenuInv,
          'icon': CupertinoIcons.square_grid_2x2_fill,
          'options': menuInvOptions,
          'color': const Color(0xFF6B8E7D),
        },
      if (equipTableOptions.isNotEmpty)
        {
          'id': 'equipTable',
          'title': l10n.settingCategoryEquipTable,
          'icon': CupertinoIcons.wrench_fill,
          'options': equipTableOptions,
          'color': const Color(0xFF7A9E8E),
        },
      {
        'id': 'system',
        'title': l10n.settingCategorySystem,
        'icon': CupertinoIcons.settings_solid,
        'options': systemOptions,
        'color': const Color(0xFF8DA399),
      },
    ];

    // ==========================================================
    // UI 建構
    // ==========================================================

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // 標題 "Settings"
            SliverAppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              pinned: true,
              expandedHeight: 130.0,
              iconTheme: IconThemeData(
                color: colorScheme.onSurface,
              ),
              centerTitle: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
                titlePadding: EdgeInsets.zero,
                title: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double currentHeight = constraints.maxHeight;
                    final bool isSnapped = currentHeight <= (kMinHeight + 50);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // --- A. 大標題 (靠左) ---
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: isSnapped ? 0.0 : 1.0,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  left: 16.0, bottom: 16.0),
                              child: Text(
                                l10n.settingsTitle, 
                                style: AppTextStyles.settingsPageTitle.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // --- B. 小標題 (置中) ---
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: isSnapped ? 1.0 : 0.0,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                l10n.settingsTitle, 
                                style: AppTextStyles.settingsListItem.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 使用者名稱卡片
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 18.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 66, vertical: 32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      userName, 
                      style: AppTextStyles.settingsUserDisplayName.copyWith(
                        color: colorScheme.onSurface, // Changed to dynamic
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 分類列表 (標準清單樣式)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Column(
                      children: [
                        for (int i = 0; i < categories.length; i++) ...[
                          _buildCategoryListTile(context, categories[i]),
                          if (i < categories.length - 1)
                            Divider(
                              height: 1.0,
                              thickness: 1.2,
                              color: colorScheme.onSurface.withOpacity(0.1),
                              indent: 61.0,
                              endIndent: 20.0,
                            )
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 50),
            ),
          ],
        ),
      ),
    );
  }

  // UI 輔助函式：建立分類列表項
  Widget _buildCategoryListTile(BuildContext context, Map<String, dynamic> category) {
    final Color topColor = category['color'] as Color;

    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      leading: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          category['icon'] as IconData,
          color: topColor,
          size: 18,
        ),
      ),
      title: Text(
        category['title'] as String,
        style: AppTextStyles.settingsListItem.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        size: 18,
      ),
      onTap: () {
        context.push('/settingsCategory', extra: {
          'categoryId': category['id'],
          'title': category['title'],
          'options': category['options'],
        });
      },
    );
  }

  // UI 輔助函式：建立列表選項 (保留給其他可能的用途或登出)
  Widget _buildListTile(BuildContext context, WidgetRef ref, Map<String, dynamic> option) {
    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      leading: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          option['icon'] as IconData,
          color: Theme.of(context).scaffoldBackgroundColor,
          size: 18,
        ),
      ),
      title: Text(
        option['label'] as String,
        style: AppTextStyles.settingsListItem.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_right,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        size: 18,
      ),
      onTap: () async {
        if (option['action'] == 'logout') {
          await ref.read(authRepositoryProvider).logout();
          if (context.mounted) context.go('/');
        } else {
          context.push(option['route'] as String);
        }
      },
    );
  }
}