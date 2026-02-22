// lib/core/constants/app_permissions.dart

class AppPermissions {
  // =========================================================
  // 1. 定義權限 Key (資料庫儲存用字串)
  // =========================================================

  // [Group 1] 主畫面 (Main Screen)
  static const String homeOrder = 'home_order';
  static const String homePrep = 'home_prep';
  static const String homeStock = 'home_stock';
  static const String homeBackDashboard = 'home_back_dashboard';
  static const String homeDailyCost = 'home_daily_cost';
  static const String homeCashFlow = 'home_cash_flow';
  static const String homeMonthlyCost = 'home_monthly_cost';
  static const String homeScan = 'home_scan';

  // [Group 2] 班表 (Schedule)
  static const String scheduleEdit = 'schedule_edit';

  // [Group 3] 後台儀表板細項 (Backstage Internal)
  static const String backCashFlow = 'back_cash_flow';
  static const String backCostSum = 'back_cost_sum';
  static const String backDashboard = 'back_dashboard';
  static const String backCashVault = 'back_cash_vault';
  static const String backClockIn = 'back_clock_in';
  static const String backViewAllClockIn = 'back_view_all_clock_in'; 
  static const String backWorkReport = 'back_work_report';
  static const String backOrderHistory = 'back_order_history';
  static const String backPayroll = 'back_payroll';
  static const String backLoginWeb = 'back_login_web';
  
  // [Group 4] 設定頁細項 (Settings Internal)
  static const String setStaff = 'set_staff';           
  static const String setRole = 'set_role';             
  static const String setPrinter = 'set_printer';       
  static const String setPrintTest = 'set_print_test';  
  static const String setTableMap = 'set_table_map';    
  static const String setTableList = 'set_table_list';  
  static const String setMenu = 'set_menu';             
  static const String setShift = 'set_shift';           
  static const String setPunch = 'set_punch';           
  static const String setPay = 'set_pay';               
  static const String setCostCat = 'set_cost_cat';      
  static const String setInv = 'set_inv';               
  static const String setCashReg = 'set_cash_reg';      
  static const String setCalGroup = 'set_cal_group';    

  // [保留舊 Key 防止報錯]
  static const String inventoryView = 'inventory_view';
  static const String inventoryEdit = 'inventory_edit';
  static const String orderTake = 'order_take';
  static const String orderCashier = 'order_cashier';
  static const String reportView = 'report_view';
  static const String reportCost = 'report_cost';
  static const String staffManage = 'staff_manage'; 
  static const String settingsAccess = 'settings_access'; 
  static const String shiftEdit = 'shift_edit';


  // =========================================================
  // 2. 定義權限群組 (使用 ARB 鍵作為標籤)
  // =========================================================
  static const List<Map<String, dynamic>> groups = [
    {
      'name': 'permGroupMainScreen',
      'permissions': [
        {'key': homeOrder, 'label': 'permHomeOrder'},
        {'key': homePrep, 'label': 'permHomePrep'},
        {'key': homeStock, 'label': 'permHomeStock'},
        {'key': homeBackDashboard, 'label': 'permHomeBackDashboard'},
        {'key': homeDailyCost, 'label': 'permHomeDailyCost'},
        {'key': homeCashFlow, 'label': 'permHomeCashFlow'},
        {'key': homeMonthlyCost, 'label': 'permHomeMonthlyCost'},
        {'key': homeScan, 'label': 'permHomeScan'},
      ]
    },
    {
      'name': 'permGroupSchedule',
      'permissions': [
        {'key': scheduleEdit, 'label': 'permScheduleEdit'},
      ]
    },
    {
      'name': 'permGroupBackstageDashboard',
      'permissions': [
        {'key': backCashFlow, 'label': 'permBackCashFlow'},
        {'key': backCostSum, 'label': 'permBackCostSum'},
        {'key': backDashboard, 'label': 'permBackDashboard'},
        {'key': backCashVault, 'label': 'permBackCashVault'},
        {'key': backClockIn, 'label': 'permBackClockIn'},
        {'key': backViewAllClockIn, 'label': 'permBackViewAllClockIn'}, 
        {'key': backWorkReport, 'label': 'permBackWorkReport'},
        {'key': backOrderHistory, 'label': 'permBackOrderHistory'},
        {'key': backPayroll, 'label': 'permBackPayroll'},
        {'key': backLoginWeb, 'label': 'permBackLoginWeb'},
      ]
    },
    {
      'name': 'permGroupSettings',
      'permissions': [
        {'key': setStaff, 'label': 'permSetStaff'},
        {'key': setRole, 'label': 'permSetRole'},
        {'key': setPrinter, 'label': 'permSetPrinter'},
        {'key': setTableMap, 'label': 'permSetTableMap'},
        {'key': setTableList, 'label': 'permSetTableList'},
        {'key': setMenu, 'label': 'permSetMenu'},
        {'key': setShift, 'label': 'permSetShift'},
        {'key': setPunch, 'label': 'permSetPunch'},
        {'key': setPay, 'label': 'permSetPay'},
        {'key': setCostCat, 'label': 'permSetCostCat'},
        {'key': setInv, 'label': 'permSetInv'},
        {'key': setCashReg, 'label': 'permSetCashReg'},
      ]
    },
  ];
}