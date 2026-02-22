// lib/core/routing/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==============================================================================
// 1. 頁面導入
// ==============================================================================

// --- Auth & Home ---
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';

// --- Ordering (點餐) ---
import '../../features/ordering/presentation/order_history_screen.dart';
//import '../../features/ordering/presentation/guest_order_screen.dart';
//import '../../features/ordering/presentation/check_cash_open_screen.dart';
//import '../../features/ordering/presentation/customer_order_screen.dart';
//import '../../features/ordering/presentation/edit_order_screen.dart';
import '../../features/ordering/presentation/split_bill_screen.dart';
import '../../features/ordering/presentation/print_bill_screen.dart';
import '../../features/ordering/presentation/move_table_screen.dart';
import '../../features/ordering/presentation/merge_table_screen.dart'; // NEW
import '../../features/ordering/presentation/order_screen.dart';
// ✅ [修改] 替換為 V2 版桌位選擇頁面
import '../../features/ordering/presentation/table_selection_screen_v2.dart'; 
import '../../features/ordering/presentation/table_info_screen.dart';
import '../../features/ordering/presentation/payment_screen.dart'; // NEW
import '../../features/ordering/presentation/transaction_detail_screen.dart';

// --- Staff Management (人事) ---
import '../../features/staff_management/presentation/punch_in_screen.dart';
import '../../features/staff_management/presentation/work_report_screen.dart';
import '../../features/staff_management/presentation/payroll_screen.dart';
import '../../features/staff_management/presentation/payroll_detail_screen.dart'; // NEW // NEW

// --- Schedule (行事曆與排班) ---
import '../../features/schedule/presentation/calendar_group_settings_screen.dart';
import '../../features/schedule/presentation/event_detail_screen.dart';
import '../../features/schedule/presentation/personal_schedule_screen.dart';
import '../../features/schedule/presentation/shift_screen.dart';
import '../../features/schedule/presentation/schedule_view_screen.dart';
import '../../features/schedule/presentation/schedule_upload_screen.dart';
import '../../features/schedule/presentation/schedule_select_shift_type_screen.dart';
import '../../features/schedule/presentation/schedule_select_dates_screen.dart';

// --- Inventory (庫存/備料) ---
import '../../features/inventory/presentation/inventory_management_screen.dart'; // NEW
import '../../features/inventory/presentation/add_stock_item_screen.dart';
import '../../features/inventory/presentation/edit_stock_info_screen.dart';
import '../../features/inventory/presentation/stock_category_detail_screen.dart';
import '../../features/inventory/presentation/view_prep_screen.dart';
import '../../features/inventory/presentation/manage_inventory_screen.dart';
import '../../features/inventory/presentation/pages/inventory_category_list_screen.dart';
import '../../features/inventory/presentation/pages/inventory_category_detail_screen.dart';
import '../../features/inventory/presentation/manage_inventory_detail_screen.dart';
import '../../features/inventory/presentation/add_inventory_item_screen.dart';
import '../../features/inventory/presentation/inventory_view_screen.dart';
import '../../features/inventory/presentation/inventory_log_screen.dart';

// --- Settings (設定) ---
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/change_password_screen.dart';
import '../../features/settings/presentation/edit_menu_screen.dart';
import '../../features/settings/presentation/manage_table_map_screen.dart';
import '../../features/settings/presentation/manage_tables_screen.dart';
import '../../features/settings/presentation/edit_modifiers_screen.dart'; // NEW
import '../../features/settings/presentation/manage_users_screen.dart';
import '../../features/settings/presentation/printer_settings_screen.dart';
import '../../features/settings/presentation/punch_in_settings_screen.dart';
import '../../features/settings/presentation/print_test_screen.dart';
import '../../features/settings/presentation/payment_method_settings_screen.dart';
import '../../features/settings/presentation/settings_shift_screen.dart';
import '../../features/settings/presentation/manage_cost_category_screen.dart';
import '../../features/settings/presentation/language_settings_screen.dart';
import '../../features/settings/presentation/appearance_settings_screen.dart';
import '../../features/settings/presentation/role_management_screen.dart';
import '../../features/settings/presentation/tax_settings_screen.dart';
import '../../features/settings/presentation/settings_category_screen.dart'; // NEW

// --- Reporting (報表) ---
import '../../features/reporting/presentation/reporting_dashboard_screen.dart';
import '../../features/reporting/presentation/cost_input_screen.dart';
import '../../features/reporting/presentation/cost_detail_screen.dart';
import '../../features/reporting/presentation/cash_settlement_screen.dart';
import '../../features/reporting/presentation/cash_register_settings_screen.dart';
import '../../features/reporting/presentation/cost_report_screen.dart';
import '../../features/reporting/presentation/deposit_management_screen.dart';
import '../../features/reporting/presentation/cost_dashboard_screen.dart';
import '../../features/reporting/presentation/cash_flow_report_screen.dart';
import '../../features/reporting/presentation/settlement_detail_screen.dart';
import '../../features/reporting/presentation/cash_vault_screen.dart';
import '../../features/reporting/presentation/monthly_cost_input_screen.dart';
import '../../features/reporting/presentation/monthly_cost_detail_screen.dart';
import '../../features/reporting/presentation/smart_scanner_screen.dart';
import '../../features/reporting/presentation/clock_in_report_screen.dart';
import '../../features/reporting/presentation/work_report_overview_screen.dart';

// --- Todo ---
import '../../features/todo/presentation/todo_list_screen.dart';

// --- 子流程頁面 (使用 show 避免衝突) ---
import '../../features/inventory/presentation/view_prep_screen.dart' show ItemSelectionScreen, ViewItemDetailScreen;
import '../../features/settings/presentation/manage_tables_screen.dart' show AreaDetailScreen;
import '../../features/settings/presentation/edit_menu_screen.dart' show MenuCategoryDetailScreen;


// ==============================================================================
// 2. GoRouter 設定
// ==============================================================================

final GoRouter appRouter = GoRouter(
  initialLocation: '/',

  routes: [
    // --------------------------------------------------------------------------
    // Auth & Core
    // --------------------------------------------------------------------------
    GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    
    // --------------------------------------------------------------------------
    // Settings (設定)
    // --------------------------------------------------------------------------
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/roleManagement', builder: (context, state) => const RoleManagementScreen()),
    GoRoute(path: '/manageUsers', builder: (context, state) => const ManageUsersScreen()),
    GoRoute(path: '/changePassword', builder: (context, state) => const ChangePasswordScreen()),
    GoRoute(path: '/manageTables', builder: (context, state) => const ManageTablesScreen()),
    GoRoute(path: '/editMenu', builder: (context, state) => const EditMenuScreen()),
    GoRoute(path: '/editModifiers', builder: (context, state) => const EditModifiersScreen()), // NEW
    GoRoute(path: '/manageTableMap', builder: (context, state) => const ManageTableMapScreen()),
    GoRoute(path: '/printerSettings', builder: (context, state) => const PrinterSettingsScreen()),
    GoRoute(path: '/punchInSettings', builder: (context, state) => const PunchInSettingsScreen()),
    GoRoute(path: '/printTest', builder: (context, state) => const PrintTestScreen()), 
    GoRoute(path: '/paymentMethodSettings', builder: (context, state) => const PaymentMethodSettingsScreen()),
    GoRoute(path: '/languageSettings', builder: (context, state) => const LanguageSettingsScreen()),
    GoRoute(path: '/shiftSettings', builder: (context, state) => const SettingsShiftScreen()),
    GoRoute(path: '/manageCostCategories', builder: (context, state) => const ManageCostCategoryScreen()),

    GoRoute(path: '/taxSettings', builder: (context, state) => const TaxSettingsScreen()),
    GoRoute(path: '/cashSettings', builder: (context, state) => const CashRegisterSettingsScreen()), 
    GoRoute(path: '/cashRegisterSettings', builder: (context, state) => const CashRegisterSettingsScreen()), 
    GoRoute(path: '/appearanceSettings', builder: (context, state) => const AppearanceSettingsScreen()),
    GoRoute(
      path: '/settingsCategory',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return SettingsCategoryScreen(
          categoryId: args['categoryId'] as String? ?? '',
          title: args['title'] as String? ?? '',
          options: args['options'] as List<Map<String, dynamic>>? ?? [],
        );
      },
    ),

    // 子頁面
    GoRoute(
      path: '/manageTablesDetail',
      builder: (context, state) {
        final area = state.extra is String ? state.extra as String : '';
        if (area.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少區域名稱')));
        return AreaDetailScreen(area: area);
      },
    ),
    GoRoute(
      path: '/editMenuDetail',
      builder: (context, state) {
        final args = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : <String, dynamic>{};
        final id = args['id'] as String? ?? '';
        final name = args['name'] as String? ?? '';
        if (id.isEmpty || name.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少菜單類別資料')));
        return MenuCategoryDetailScreen(categoryId: id, categoryName: name);
      },
    ),

    // --------------------------------------------------------------------------
    // Ordering (點餐)
    // --------------------------------------------------------------------------
    //GoRoute(path: '/checkCash', builder: (context, state) => CheckCashOpenScreen()),
    //GoRoute(path: '/guestOrder', builder: (context, state) => const GuestOrderScreen()),
    
    // ✅ [修改] 使用新的 TableSelectionScreenV2
    GoRoute(path: '/selectArea', builder: (context, state) => const TableSelectionScreenV2()),
    
    GoRoute(
      path: '/orderHistory',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        final currentShiftOnly = args['currentShiftOnly'] as bool? ?? true;
        return OrderHistoryScreen(currentShiftOnly: currentShiftOnly);
      },
    ), 
    
    /*GoRoute(
      path: '/selectPosition',
      builder: (context, state) {
        final area = state.extra is String ? state.extra as String : '';
        if (area.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少區域參數')));
        return SelectPositionScreen(area: area);
      },
    ),*/
    GoRoute(
      path: '/order',
      builder: (context, state) {
        // 取得 extra 參數，預期是一個 Map
        final args = state.extra as Map<String, dynamic>? ?? {};
    
        final tableNumbers = args['tableNumbers'] as List<String>? ?? [];
        final orderGroupId = args['orderGroupId'] as String?;
        final isNewOrder = args['isNewOrder'] as bool? ?? true;

        if (tableNumbers.isEmpty) {
          return const Scaffold(body: Center(child: Text('錯誤：缺少桌號參數')));
        }

        return OrderScreen(
          tableNumbers: tableNumbers,
          orderGroupId: orderGroupId,
          isNewOrder: isNewOrder,
        );
      },
    ),
    /*GoRoute(
      path: '/editOrder',
      builder: (context, state) {
        final tableName = state.extra is String ? state.extra as String : ''; 
        if (tableName.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少桌名參數')));
        return EditOrderScreen(tableName: tableName);
      },
    ),*/
    GoRoute(
      path: '/splitBill',
      builder: (context, state) {
        final args = state.extra is Map ? state.extra as Map : {};
        final groupKey = args['groupKey'] as String? ?? '';
        final currentSeats = args['currentSeats'] is List ? List<String>.from(args['currentSeats']) : <String>[];
        if (groupKey.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少群組鍵 groupKey')));
        return SplitBillScreen(groupKey: groupKey, currentSeats: currentSeats);
      },
    ),
    GoRoute(
      path: '/printBill',
      builder: (context, state) {
        final args = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : {};
        final groupKey = args['groupKey'] as String? ?? '';
        final title = args['title'] as String? ?? '';
        final splitId = args['splitId'] as String?;
        if (groupKey.isEmpty || title.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少帳單關鍵參數')));
        return PrintBillScreen(groupKey: groupKey, title: title, splitId: splitId);
      },
    ),
    GoRoute(
      path: '/payment',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        final groupKey = args['groupKey'] as String? ?? '';
        final totalAmount = (args['totalAmount'] as num?)?.toDouble() ?? 0.0;
        if (groupKey.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少群組鍵')));
        return PaymentScreen(groupKey: groupKey, totalAmount: totalAmount);
      },
    ),

    GoRoute(
      path: '/tableInfo',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return TableInfoScreen(
          tableName: extra['tableName'] as String,
          orderGroupId: extra['orderGroupId'] as String,
        );
      },
    ),

    GoRoute(
      path: '/moveTable',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return MoveTableScreen(
          groupKey: extra['groupKey'] as String,
          // 注意：確保傳入的是 List<String>
          currentSeats: List<String>.from(extra['currentSeats'] as List),
        );
      },
    ),
    GoRoute(
      path: '/mergeTable',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return MergeTableScreen(
          groupKey: extra['groupKey'] as String,
          currentSeats: List<String>.from(extra['currentSeats'] as List),
        );
      },
    ),
    /*GoRoute(
      path: '/moveTable',
      builder: (context, state) {
        final args = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : {};
        final groupKey = args['groupKey'];
        final currentSeats = args['currentSeats'] is List ? List<String>.from(args['currentSeats']) : <String>[];
        if (groupKey == null) return const Scaffold(body: Center(child: Text('錯誤：缺少群組鍵 groupKey')));
        return MoveTableScreen(groupKey: groupKey, currentSeats: currentSeats);
      },
    ),*/

    // --------------------------------------------------------------------------
    // Staff & Schedule (人事與班表)
    // --------------------------------------------------------------------------
    GoRoute(path: '/punchIn', builder: (context, state) => const PunchInScreen()),
    GoRoute(path: '/workReport', builder: (context, state) => const WorkReportScreen()),
    GoRoute(path: '/shift', builder: (context, state) => const ShiftScreen()),
    GoRoute(path: '/personalSchedule', builder: (context, state) => const PersonalScheduleScreen()),
    GoRoute(path: '/calendarGroupSettings', builder: (context, state) => const CalendarGroupSettingsScreen()),
    GoRoute(path: '/scheduleView', builder: (context, state) => const ScheduleViewScreen()),
    GoRoute(path: '/scheduleUpload', builder: (context, state) => const ScheduleUploadScreen()),
    GoRoute(path: '/scheduleSelectShiftType',builder: (context, state) {final employee = state.extra; return ScheduleSelectShiftTypeScreen(employee: employee);},),
    GoRoute(path: '/scheduleSelectDates',builder: (context, state) {final args = state.extra as Employee;return ScheduleSelectDatesScreen(employee: args);},),
    GoRoute(
      path: '/eventDetail',
      builder: (context, state) {
        final args = state.extra is Map<String, dynamic> 
            ? state.extra as Map<String, dynamic> 
            : <String, dynamic>{};
        final event = args['event']; 
        final group = args['group']; 
        return EventDetailScreen(
          event: event,
          group: group,
        );
      },
    ),

    // --------------------------------------------------------------------------
    // Inventory (庫存)
    // --------------------------------------------------------------------------
    GoRoute(path: '/prep', builder: (context, state) => const ViewPrepScreen()),
    GoRoute(path: '/editStockInfo', builder: (context, state) => const EditStockInfoScreen()),
    
    // ✅ [Restored] Use EditStockListScreen (Category First)
    GoRoute(path: '/manageInventory', builder: (context, state) => const EditStockListScreen()),
    
    GoRoute(path: '/inventoryView', builder: (context, state) => const InventoryViewScreen()),
    GoRoute(path: '/inventoryLog', builder: (context, state) => const InventoryLogScreen()),
    
    GoRoute(
      path: '/stockCategoryDetail',
      builder: (context, state) {
        final category = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
        if (category == null || category.isEmpty) return const Scaffold(body: Center(child: Text("錯誤：未提供庫存類別")));
        return StockCategoryDetailScreen(category: category);
      },
    ),
    
    // ✅ 修正：使用 InventoryCategoryDetailScreen 取代 EditStockCategoryDetailScreen
    GoRoute(
      path: '/editStockCategoryDetail',
      builder: (context, state) {
        final category = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
        if (category == null || category.isEmpty) return const Scaffold(body: Center(child: Text("錯誤：未提供庫存類別")));
        return InventoryCategoryDetailScreen(
          categoryId: category['id'], 
          categoryName: category['name'],
        );
      },
    ),
    
    GoRoute(
      path: '/addStockItem',
      builder: (context, state) {
        final args = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : {};
        return AddStockItemScreen(
          categoryId: args['categoryId'],
          categoryName: args['categoryName'],
          itemId: args['itemId'],
          initialData: args['initialData'],
        );
      },
    ),
    GoRoute(
      path: '/manageInventoryDetail',
      builder: (context, state) {
        final args = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : {};
        final categoryId = args['categoryId'] as String? ?? '';
        final categoryName = args['categoryName'] as String? ?? '';
        if (categoryId.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少類別 ID')));
        return ManageInventoryDetailScreen(categoryId: categoryId, categoryName: categoryName);
      },
    ),
    GoRoute(
      path: '/addInventoryItem',
      builder: (context, state) {
        final args = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : {};
        return AddInventoryItemScreen(
          categoryId: args['categoryId'],
          categoryName: args['categoryName'],
          itemId: args['itemId'],
          initialData: args['initialData'],
        );
      },
    ),
    GoRoute(
      path: '/prepItemSelection',
      builder: (context, state) {
        final args = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : {};
        return ItemSelectionScreen(categoryId: args['categoryId'], categoryName: args['categoryName']);
      },
    ),
    GoRoute(
      path: '/prepItemDetail',
      builder: (context, state) {
        final Map<String, dynamic> item = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : <String, dynamic>{};
        if (item.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少品項詳細資料')));
        return ViewItemDetailScreen(item: item);
      },
    ),

    // --------------------------------------------------------------------------
    // Reporting (報表)
    // --------------------------------------------------------------------------
    GoRoute(path: '/dashboard', builder: (context, state) => const ReportingDashboardScreen()),
    GoRoute(path: '/costInput', builder: (context, state) => const CostInputScreen()),
    GoRoute(path: '/monthlyCostInput', builder: (context, state) => const MonthlyCostInputScreen()),
    GoRoute(path: '/cashVault', builder: (context, state) => const CashVaultScreen()),
    GoRoute(path: '/cashSettlement', builder: (context, state) => const CashSettlementScreen()),
    GoRoute(path: '/costReport', builder: (context, state) => const CostReportScreen()),
    GoRoute(path: '/depositManagement', builder: (context, state) => const DepositManagementScreen()),
    GoRoute(path: '/costDashboard', builder: (context, state) => const CostDashboardScreen()),
    GoRoute(path: '/cashFlowReport', builder: (context, state) => const CashFlowReportScreen()),
    GoRoute(path: '/smartScanner', builder: (context, state) => const SmartScannerScreen()),
    GoRoute(path: '/clockInReport',builder: (context, state) => const ClockInReportScreen(),),
    GoRoute(path: '/workReportOverview',builder: (context, state) => const WorkReportOverviewScreen(),),
    GoRoute(
      path: '/costDetails',
      builder: (context, state) {
        if (state.extra is Map<String, dynamic>) {
          final args = state.extra as Map<String, dynamic>;
          return CostDetailScreen(
            transactionId: args['transaction_id'] as String?,
            targetDate: args['targetDate'] as String?,
            openId: args['open_id'] as String?,
          );
        } else if (state.extra is String?) {
          final dateStr = state.extra as String?;
          return CostDetailScreen(targetDate: dateStr);
        } else {
          return const CostDetailScreen();
        }
      },
    ),
    GoRoute(
      path: '/settlementDetail',
      builder: (context, state) {
        final txId = state.extra is String ? state.extra as String : ''; 
        if (txId.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少交易 ID')));
        return SettlementDetailScreen(transactionId: txId);
      },
    ),
    GoRoute(path: '/monthlyCostDetail',builder: (context, state) {final selectedMonth = state.extra as DateTime? ?? DateTime.now();
        return MonthlyCostDetailScreen(selectedMonth: selectedMonth);
      },
    ),
    

    GoRoute(
      path: '/transactionDetail',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        final orderGroupId = args['orderGroupId'] as String? ?? '';
        final transactionId = args['transactionId'] as String? ?? '-';
        final isReadOnly = args['isReadOnly'] as bool? ?? false; // NEW
        if (orderGroupId.isEmpty) return const Scaffold(body: Center(child: Text('錯誤：缺少訂單 ID')));
        return TransactionDetailScreen(
          orderGroupId: orderGroupId, 
          transactionId: transactionId,
          isReadOnly: isReadOnly,
        );
      },
    ),

    // --------------------------------------------------------------------------
    // Todo
    // --------------------------------------------------------------------------
    GoRoute(path: '/todoList', builder: (context, state) => const TodoListScreen()),
    GoRoute(path: '/payroll', builder: (context, state) => const PayrollScreen()),
    GoRoute(
      path: '/payrollDetail', 
      builder: (context, state) {
         final extra = state.extra as Map<String, dynamic>;
         return PayrollDetailScreen(
           shopId: extra['shopId'],
           reportItem: extra['reportItem'],
           period: extra['period'],
         );
      }
    ), // NEW
  ],

  // 4. 錯誤處理
  errorBuilder: (context, state) {
    return Scaffold(
      appBar: AppBar(title: const Text('頁面不存在')),
      body: Center(
        child: Text('找不到路徑: ${state.error?.message ?? '未知錯誤'}'),
      ),
    );
  },
);