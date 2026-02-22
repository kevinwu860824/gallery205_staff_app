// lib/features/reporting/presentation/reporting_dashboard_screen.dart

// import 'dart:ui'; 
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ✅ 新增 Import
import 'package:gallery205_staff_app/core/services/permission_service.dart';
import 'package:gallery205_staff_app/core/constants/app_permissions.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart'; // [新增] 引入多語言

// ✅ 1. 修改模型：加入 permissionKey
class _ReportButton {
  final String label;
  final IconData icon;
  final String? route;
  final String? permissionKey; // 新增欄位

  const _ReportButton({
    required this.label,
    required this.icon,
    this.route,
    this.permissionKey, // 建構子加入
  });
}

class ReportingDashboardScreen extends StatelessWidget {
  const ReportingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增] 取得翻譯

    // ✅ 2. 設定每個按鈕對應的權限 Key (移入 build 方法以支援多語言)
    final List<_ReportButton> allButtons = [
      _ReportButton(
        label: l10n.reportingCashFlow, // 'Cash Flow'
        icon: CupertinoIcons.money_dollar,
        route: '/cashFlowReport',
        permissionKey: AppPermissions.backCashFlow,
      ),
      _ReportButton(
        label: l10n.reportingCostSum, // 'Cost Sum'
        icon: CupertinoIcons.doc_text,
        route: '/costReport',
        permissionKey: AppPermissions.backCostSum,
      ),
      _ReportButton(
        label: l10n.reportingDashboard, // 'Dashboard'
        icon: CupertinoIcons.chart_bar_alt_fill,
        route: '/costDashboard',
        permissionKey: AppPermissions.backDashboard,
      ),
      _ReportButton(
        label: l10n.reportingCashVault, // 'Cash Vault'
        icon: CupertinoIcons.archivebox,
        route: '/cashVault',
        permissionKey: AppPermissions.backCashVault,
      ),
      _ReportButton(
        label: l10n.reportingClockIn, // 'Clock-in'
        icon: CupertinoIcons.clock,
        route: '/clockInReport', // 假設這是對應的路由
        permissionKey: AppPermissions.backClockIn,
      ),
      _ReportButton(
        label: l10n.reportingWorkReport, // 'Work Report'
        icon: CupertinoIcons.book,
        route: '/workReportOverview', // 假設這是對應的路由
        permissionKey: AppPermissions.backWorkReport,
      ),
      _ReportButton(
        label: l10n.homeMonthlyCost, 
        icon: CupertinoIcons.archivebox,
        route: '/monthlyCostInput',
        permissionKey: AppPermissions.homeMonthlyCost,
      ),
      _ReportButton(
        label: "歷史訂單", // TODO: Add to l10n
        icon: CupertinoIcons.list_bullet,
        route: '/orderHistory', 
        permissionKey: AppPermissions.backOrderHistory, // Defined in previous step
      ),
    ];

    // ✅ 3. 過濾按鈕：只顯示有權限的項目
    final visibleButtons = allButtons.where((btn) {
      if (btn.permissionKey == null) return true; // 沒設限制的預設顯示
      return PermissionService().hasPermission(btn.permissionKey!);
    }).toList();

    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark; // Unused here

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, 
      appBar: AppBar(
        title: Text(
          l10n.reportingTitle, // 'Backstage'
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 20, left: 24, right: 24),
        child: visibleButtons.isEmpty 
          ? Center(child: Text(l10n.reportingNoAccess, style: TextStyle(color: theme.hintColor)))
          : GridView.builder(
              itemCount: visibleButtons.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, 
                crossAxisSpacing: 16, 
                mainAxisSpacing: 0, 
                childAspectRatio: 0.75, 
              ),
              itemBuilder: (context, index) {
                final button = visibleButtons[index];
                return _LiquidGlassIcon(
                  label: button.label,
                  icon: button.icon,
                  onPressed: button.route != null
                      ? () => context.push(button.route!, extra: button.route == '/orderHistory' ? {'currentShiftOnly': false} : null)
                      : null,
                );
              },
            ),
      ),
    );
  }
}

class _LiquidGlassIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _LiquidGlassIcon({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const double iconSize = 62.0; 
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector( 
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              color: Theme.of(context).cardColor,
              boxShadow: isLight ? [
                 BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : [], 
            ),
            child: Center(
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 30.0, 
              ),
            ),
          ),
          const SizedBox(height: 4.0), 
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12, 
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}