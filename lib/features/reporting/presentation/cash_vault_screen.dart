// lib/features/reporting/presentation/cash_vault_screen.dart
// ✅ 優化版：
// 1. Cash Detail 單行顯示 (FittedBox)
// 2. Recent Activity 支援月份切換 (Monthly View)
// 3. 實作歷史結餘回推邏輯 (Rollback Calculation)

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 1. UI 樣式定義 - Removed _AppColors
// -------------------------------------------------------------------

// -------------------------------------------------------------------
// 2. CashVaultScreen
// -------------------------------------------------------------------

class CashVaultScreen extends StatefulWidget {
  const CashVaultScreen({super.key});

  @override
  State<CashVaultScreen> createState() => _CashVaultScreenState();
}

class _CashVaultScreenState extends State<CashVaultScreen> {
  String? _shopId;
  String? _currentUserName;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTableLoading = false; // 表格專用的 Loading 狀態
  
  // 核心數據
  Map<String, dynamic> _vaultInventory = {}; // 目前最新的 Total 庫存
  double _pettyCashAmount = 0.0;
  final Map<int, int> _targetCashCounts = {}; 
  
  // 表格數據 (動態載入)
  DateTime _activityMonth = DateTime.now(); // 目前選中的月份
  List<Map<String, dynamic>> _processedLogs = []; // 該月份處理後的 Log
  
  final List<int> _denominations = [2000, 1000, 500, 200, 100, 50, 10, 5, 1];
  final currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _fetchVaultData();
  }

  Future<void> _fetchVaultData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }
    await _loadCurrentUser();
    await _loadBaseData(); // 先載入基礎庫存
  }

  Future<void> _loadCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && _shopId != null) {
      try {
        final res = await Supabase.instance.client
            .from('users')
            .select('name')
            .eq('user_id', user.id)
            .eq('shop_id', _shopId!)
            .maybeSingle();
        if (res != null) {
          _currentUserName = res['name'];
        }
      } catch (e) {
        debugPrint('Error loading user name: $e');
      }
    }
    _currentUserName ??= 'Staff';
  }

  // 1. 載入基礎資料 (目前庫存、設定)
  Future<void> _loadBaseData() async {
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('cash_vault_inventory')
            .select('*')
            .eq('shop_id', _shopId!)
            .maybeSingle(),
        Supabase.instance.client
            .from('cash_register_settings')
            .select('*')
            .eq('shop_id', _shopId!)
            .maybeSingle(),
      ]);

      final invRes = results[0] as Map<String, dynamic>? ?? {};
      final settingsRes = results[1] as Map<String, dynamic>?;

      // 處理找零櫃
      double calculatedFloat = 0.0;
      _targetCashCounts.clear();
      if (settingsRes != null) {
          for (var value in _denominations) {
              final count = settingsRes['cash_$value'] as int? ?? 0;
              _targetCashCounts[value] = count;
              calculatedFloat += value * count;
          }
      }

      if (mounted) {
        setState(() {
          _vaultInventory = invRes; // 這是「目前」的總數
          _pettyCashAmount = calculatedFloat;
        });
        // 基礎資料載入完後，載入當月 Log
        _loadLogsForMonth(_activityMonth);
      }

    } catch (e) {
      debugPrint('Error loading base data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. 切換月份
  void _changeMonth(int offset) {
    setState(() {
      _activityMonth = DateTime(_activityMonth.year, _activityMonth.month + offset);
    });
    _loadLogsForMonth(_activityMonth);
  }

  // 3. 核心邏輯：載入指定月份 Log 並計算歷史 Snapshot
  Future<void> _loadLogsForMonth(DateTime month) async {
    setState(() => _isTableLoading = true);

    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final endOfMonthStr = DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month + 1, 0));
      
      // A. 查詢「未來」的所有變動 (相對於選定月份的月底)
      // 如果選的是當月，這裡會是空的 (除了今天以後的，通常沒有)
      // 如果選的是上個月，這裡會包含「本月」的所有 Log
      final futureLogsRes = await Supabase.instance.client
          .from('cash_vault_logs')
          .select('*')
          .eq('shop_id', _shopId!)
          .gt('log_date', endOfMonthStr); // 大於月底
      
      // B. 計算「選定月份月底」的狀態
      // 公式：月底狀態 = 目前最新狀態 - (未來所有變動的總和)
      Map<String, int> monthEndSnapshot = {};
      
      // 初始化為目前最新狀態
      for (var d in _denominations) {
        monthEndSnapshot['cash_$d'] = (_vaultInventory['cash_$d'] as int? ?? 0);
      }

      // 扣除未來變動
      for (var log in futureLogsRes) {
        for (var d in _denominations) {
          int delta = (log['cash_$d'] as int? ?? 0);
          monthEndSnapshot['cash_$d'] = monthEndSnapshot['cash_$d']! - delta;
        }
      }

      // C. 查詢「選定月份」的 Logs
      final currentLogsRes = await Supabase.instance.client
          .from('cash_vault_logs')
          .select('*')
          .eq('shop_id', _shopId!)
          .gte('log_date', DateFormat('yyyy-MM-dd').format(startOfMonth))
          .lt('log_date', DateFormat('yyyy-MM-dd').format(nextMonth))
          .order('log_date', ascending: false)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> processed = [];
      Map<String, int> runningSnapshot = Map.from(monthEndSnapshot);

      // D. 依序計算每筆 Log 當下的 Snapshot
      for (var log in currentLogsRes) {
        Map<String, dynamic> entry = Map.from(log);
        
        // 1. 寫入當下 Snapshot (從 runningSnapshot 拿)
        for (var d in _denominations) {
          entry['snapshot_$d'] = runningSnapshot['cash_$d'];
        }
        processed.add(entry);

        // 2. 回推上一筆狀態 (Snapshot - Delta)
        for (var d in _denominations) {
          int delta = (log['cash_$d'] as int? ?? 0);
          runningSnapshot['cash_$d'] = runningSnapshot['cash_$d']! - delta;
        }
      }

      if (mounted) {
        setState(() {
          _processedLogs = processed;
          _isLoading = false;
          _isTableLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error loading logs: $e');
      if (mounted) setState(() { _isLoading = false; _isTableLoading = false; });
    }
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  void _showVaultManagementSheet() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.vaultManagementSheetTitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 16),
            
            ListTile(
              leading: Icon(CupertinoIcons.slider_horizontal_3, color: theme.colorScheme.onSurface),
              title: Text(l10n.vaultAdjustCounts, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                _runCalibration();
              },
            ),
            Divider(color: theme.dividerColor, height: 1),

            ListTile(
              leading: Icon(CupertinoIcons.arrow_up_circle, color: theme.colorScheme.onSurface),
              title: Text(l10n.vaultSaveMoney, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                _runBankDeposit();
              },
            ),
            Divider(color: theme.dividerColor, height: 1),
            
            ListTile(
              leading: Icon(CupertinoIcons.arrow_right_arrow_left_circle, color: theme.colorScheme.onSurface),
              title: Text(l10n.vaultChangeMoney, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18)),
              onTap: () {
                Navigator.pop(context);
                _runExchange();
              },
            ),
            Divider(color: theme.dividerColor, height: 1),
            
            const SizedBox(height: 10),
            ListTile(
              title: Center(child: Text(l10n.commonCancel, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18))),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runCalibration() async {
    final Map<int, TextEditingController> controllers = {};
    for (var d in _denominations) {
      int totalCount = (_vaultInventory['cash_$d'] as int? ?? 0);
      controllers[d] = TextEditingController(text: totalCount.toString());
    }

    final l10n = AppLocalizations.of(context)!;
    final result = await showCupertinoDialog(
      context: context,
      builder: (ctx) => _DenominationDialog(
        title: l10n.vaultAdjustCounts,
        prompt: l10n.vaultPromptAdjust,
        controllers: controllers,
        denominations: _denominations,
        isAdjustmentMode: true, 
      ),
    );

    if (result == null) return;

    final newTotalCounts = result['counts'] as Map<String, dynamic>;
    final Map<String, dynamic> deltas = {};
    double totalDeltaAmount = 0.0;

    for (var d in _denominations) {
      int oldTotal = (_vaultInventory['cash_$d'] as int? ?? 0);
      int newTotal = newTotalCounts['cash_$d'] ?? 0;
      int diff = newTotal - oldTotal;
      deltas['cash_$d'] = diff;
      totalDeltaAmount += diff * d;
    }

    if (totalDeltaAmount == 0 && deltas.values.every((v) => v == 0)) return;

    await _saveVaultLog(
      logType: 'ADJUST', 
      transactionType: 'Inventory Adjustment', 
      amount: totalDeltaAmount, 
      counts: deltas,
    );
  }

  Future<void> _runBankDeposit() async {
    final l10n = AppLocalizations.of(context)!;
    final counts = await _showDenominationEntryDialog(
      title: l10n.vaultSaveMoney,
      prompt: l10n.vaultPromptDeposit,
    );
    if (counts == null) return;
    
    await _saveVaultLog(
      logType: 'OUT', transactionType: 'Save Money', amount: counts['total'], counts: counts['counts'],
    );
  }

  Future<void> _runExchange() async {
    final l10n = AppLocalizations.of(context)!;
    final countsOut = await _showDenominationEntryDialog(
      title: l10n.vaultChangeMoneyStep1,
      prompt: l10n.vaultPromptChangeOut,
    );
    if (countsOut == null) return;

    final countsIn = await _showDenominationEntryDialog(
      title: l10n.vaultChangeMoneyStep2,
      prompt: l10n.vaultPromptChangeIn,
    );
    if (countsIn == null) return;

    if (countsOut['total'] != countsIn['total']) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.vaultErrorMismatch)));
       return;
    }

    await _saveVaultLog(
      logType: 'OUT', transactionType: 'Change Out', amount: countsOut['total'], counts: countsOut['counts']
    );
    await _saveVaultLog(
      logType: 'IN', transactionType: 'Change In', amount: countsIn['total'], counts: countsIn['counts']
    );
  }

  Future<Map<String, dynamic>?> _showDenominationEntryDialog({required String title, required String prompt}) async {
    final Map<int, TextEditingController> controllers = {};
    for (var d in _denominations) {
      controllers[d] = TextEditingController(text: ''); 
    }
    
    return await showCupertinoDialog(
      context: context,
      builder: (ctx) => _DenominationDialog(
        title: title,
        prompt: prompt,
        controllers: controllers,
        denominations: _denominations,
      ),
    );
  }

  Future<void> _saveVaultLog({
    required String logType,
    required String transactionType,
    required double amount,
    required Map<String, dynamic> counts,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final int multiplier = (logType == 'ADJUST') ? 1 : ((logType == 'IN') ? 1 : -1);
      final Map<String, dynamic> insertData = {
        'shop_id': _shopId,
        'log_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'log_type': logType,
        'transaction_type': transactionType,
        'amount': amount * multiplier, 
        'notes': transactionType,
        'operator_name': _currentUserName,
      };

      for (var d in _denominations) {
        insertData['cash_$d'] = (counts['cash_$d'] ?? 0) * multiplier;
      }

      await Supabase.instance.client.from('cash_vault_logs').insert(insertData);
      
      // 更新後重新載入 (包含重置 Total Inventory 和重新計算 Table)
      await _loadBaseData();
      
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.vaultSaveFailed(e.toString()))));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ------------------------------------------------------------------
  // Build UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final totalAsset = (_vaultInventory['current_vault_amount'] as num? ?? 0.0).toDouble();
    final vaultOnly = totalAsset - _pettyCashAmount;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),

            Expanded(
              child: _isLoading 
                ? Center(child: CupertinoActivityIndicator(color: theme.iconTheme.color))
                : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    children: [
                      _buildTotalCard(totalAsset),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(child: _buildSubCard(l10n.vaultTitleVault, vaultOnly)), 
                          const SizedBox(width: 12),
                          Expanded(child: _buildSubCard(l10n.vaultTitleCashbox, _pettyCashAmount)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      _buildCashDetailList(),
                      const SizedBox(height: 12),
                      
                      // 表格區域 (包含月份切換器)
                      _buildDailyDetailTable(),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            child: Icon(CupertinoIcons.chevron_left, color: theme.iconTheme.color, size: 32),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                l10n.vaultTitle,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 28, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            child: Icon(CupertinoIcons.command, color: theme.iconTheme.color, size: 28),
            onPressed: _showVaultManagementSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(double amount) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.vaultTotalCash, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text('\$ ${currencyFormat.format(amount)}', style: TextStyle(color: colorScheme.onSurface, fontSize: 36, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSubCard(String title, double amount) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text('\$ ${currencyFormat.format(amount)}', style: TextStyle(color: colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCashDetailList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.vaultCashDetail, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 10),
          
          ..._denominations.map((val) {
            final totalCount = (_vaultInventory['cash_$val'] as int? ?? 0);
            final boxCount = (_targetCashCounts[val] ?? 0);
            final vaultCount = totalCount - boxCount; 
            
            final totalVal = totalCount * val;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox( 
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '\$ ${currencyFormat.format(val)} X $totalCount (Vault $vaultCount + Cashbox $boxCount)',
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontFamily: 'Courier'),
                        maxLines: 1, 
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('\$ ${currencyFormat.format(totalVal)}', style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDailyDetailTable() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.vaultActivityHistory, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          
          // --- ✅ 月份切換器 ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.chevron_left, color: theme.iconTheme.color),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                DateFormat('yyyy/MM').format(_activityMonth),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.chevron_right, color: theme.iconTheme.color),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // --- 表格內容 ---
          _isTableLoading 
            ? Center(child: CupertinoActivityIndicator(color: theme.iconTheme.color))
            : _processedLogs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text(l10n.vaultNoRecords, style: const TextStyle(color: Colors.grey))),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    border: TableBorder.all(color: theme.dividerColor, width: 1),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      // Header Row
                      TableRow(
                        children: [
                          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(l10n.vaultTableDate, style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold), softWrap: false))),
                          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(l10n.vaultTableStaff, style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold), softWrap: false))),
                          ..._denominations.map((val) => Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(val.toString(), style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold), softWrap: false)))),
                        ],
                      ),
                      // Data Rows
                      ..._processedLogs.map((log) {
                        final dateStr = DateFormat('MM/dd').format(DateTime.parse(log['log_date']));
                        final operatorName = log['operator_name'] ?? '-';
                        return TableRow(
                          children: [
                            Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(dateStr, style: TextStyle(color: colorScheme.onSurface, fontSize: 14), softWrap: false))),
                            Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(operatorName, style: TextStyle(color: colorScheme.onSurface, fontSize: 14), softWrap: false))),
                            ..._denominations.map((val) {
                              final count = (log['snapshot_$val'] as int? ?? 0);
                              return Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(count.toString(), style: TextStyle(color: colorScheme.onSurface, fontSize: 14), softWrap: false)));
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 輔助 Widget (Dialog)
// -------------------------------------------------------------------

class _DenominationDialog extends StatefulWidget {
  final String title;
  final String prompt;
  final Map<int, TextEditingController> controllers;
  final List<int> denominations;
  final bool isAdjustmentMode;

  const _DenominationDialog({
    required this.title,
    required this.prompt,
    required this.controllers,
    required this.denominations,
    this.isAdjustmentMode = false,
  });

  @override
  State<_DenominationDialog> createState() => _DenominationDialogState();
}

class _DenominationDialogState extends State<_DenominationDialog> {
  double _total = 0.0;

  @override
  void initState() {
    super.initState();
    _calculate(); 
  }

  void _calculate() {
    double sum = 0.0;
    widget.controllers.forEach((val, ctrl) {
      final count = int.tryParse(ctrl.text) ?? 0;
      sum += val * count;
    });
    setState(() => _total = sum);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(widget.prompt, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 20),
            
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.denominations.map((val) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 60, child: Text('\$$val', style: TextStyle(color: colorScheme.onSurface))),
                            Expanded(
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: widget.controllers[val],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.black), // Ensure text is visible on white background
                                  decoration: const InputDecoration(border: InputBorder.none),
                                  onChanged: (_) => _calculate(),
                                ),
                              ),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            if (!widget.isAdjustmentMode)
               Text('${l10n.vaultDialogTotal(NumberFormat('#,###').format(_total))}', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: colorScheme.onPrimary),
                  onPressed: () {
                    final Map<String, dynamic> counts = {};
                    widget.controllers.forEach((k, v) => counts['cash_$k'] = int.tryParse(v.text) ?? 0);
                    Navigator.pop(context, {'total': _total, 'counts': counts});
                  },
                  child: Text(l10n.commonConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}