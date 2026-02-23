// lib/features/reporting/presentation/reporting_dashboard_screen.dart

// import 'dart:ui'; 
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// ✅ 新增 Import
import 'package:gallery205_staff_app/core/services/permission_service.dart';
import 'package:gallery205_staff_app/core/constants/app_permissions.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart';
import 'package:gallery205_staff_app/core/services/invoice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class ReportingDashboardScreen extends ConsumerStatefulWidget {
  const ReportingDashboardScreen({super.key});

  @override
  ConsumerState<ReportingDashboardScreen> createState() => _ReportingDashboardScreenState();
}

class _ReportingDashboardScreenState extends ConsumerState<ReportingDashboardScreen> {
  int _pendingInvoiceCount = 0;
  bool _isCheckingPending = false;
  bool _isBatchProcessing = false;
  int _processProgress = 0;
  int _processTotal = 0;

  @override
  void initState() {
    super.initState();
    _checkPendingInvoices();
  }

  Future<void> _checkPendingInvoices() async {
    if (_isCheckingPending) return;
    setState(() => _isCheckingPending = true);

    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) return;

      final response = await supabase
          .from('order_groups')
          .select('id')
          .eq('shop_id', shopId)
          .eq('status', 'completed')
          .isFilter('ezpay_invoice_number', null)
          .eq('tax_snapshot->>rate', '5')
          .count(CountOption.exact);

      if (mounted) {
        setState(() {
          _pendingInvoiceCount = response.count;
        });
      }
    } catch (e) {
      debugPrint("Error checking pending invoices: $e");
    } finally {
      if (mounted) setState(() => _isCheckingPending = false);
    }
  }

  Future<void> _startBatchProcess() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("批次補開發票"),
        content: Text("偵測到有 $_pendingInvoiceCount 筆訂單尚未開立發票，確定要開始批次開立嗎？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("取消")),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text("開始處理")),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isBatchProcessing = true;
      _processProgress = 0;
    });

    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) return;

      // Fetch pending IDs
      final List<dynamic> res = await supabase
          .from('order_groups')
          .select('id')
          .eq('shop_id', shopId)
          .eq('status', 'completed')
          .isFilter('ezpay_invoice_number', null)
          .eq('tax_snapshot->>rate', '5');

      final List<String> pendingIds = res.map((e) => e['id'] as String).toList();
      _processTotal = pendingIds.length;
      int successCount = 0;
      int failCount = 0;

      final invoiceService = ref.read(invoiceServiceProvider);

      for (String id in pendingIds) {
        if (!mounted) break;
        try {
          final result = await invoiceService.issueInvoice(id);
          if (result != null) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          debugPrint("Batch issue error for $id: $e");
        }
        
        if (mounted) {
          setState(() {
            _processProgress++;
          });
        }
        // Small delay to avoid hammering the API too fast
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (mounted) {
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("批次處理完成"),
            content: Text("成功：$successCount 筆\n失敗：$failCount 筆"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text("確定")),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("批次處理發生錯誤: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBatchProcessing = false;
        });
        _checkPendingInvoices(); // Refresh count
      }
    }
  }

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
      body: Column(
        children: [
          if (_pendingInvoiceCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "有 $_pendingInvoiceCount 筆訂單尚未上傳發票",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown),
                        ),
                        const Text(
                          "可能是先前網路中斷導致，建議進行批次補傳。",
                          style: TextStyle(fontSize: 12, color: Colors.brown),
                        ),
                      ],
                    ),
                  ),
                  _isBatchProcessing 
                    ? SizedBox(
                        width: 100,
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: _processTotal > 0 ? _processProgress / _processTotal : 0,
                              backgroundColor: Colors.orange.shade100,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 4),
                            Text("$_processProgress / $_processTotal", style: const TextStyle(fontSize: 10, color: Colors.orange)),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _startBatchProcess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        child: const Text("批次補傳"),
                      ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
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
          ),
        ],
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