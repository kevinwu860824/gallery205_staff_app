// lib/features/reporting/presentation/cash_settlement_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settlement_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:math'; 
import '../../settings/presentation/payment_method_settings_screen.dart'; 
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';

// 白色圓角輸入框樣式
InputDecoration _buildInputDecoration(BuildContext context, {String hintText = ''}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: theme.cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
  );
}

// 點鈔輸入框樣式
InputDecoration _buildCashInputDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return InputDecoration(
    filled: true,
    fillColor: theme.cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    isDense: true,
  );
}

// -------------------------------------------------------------------
// Widget：面額輸入列 (接收外部 FocusNode)
// -------------------------------------------------------------------
class _DenominationInputRow extends StatefulWidget {
  final int value;
  final TextEditingController controller;
  final NumberFormat currencyFormat;
  final FocusNode focusNode; 

  const _DenominationInputRow({
    required this.value,
    required this.controller,
    required this.currencyFormat,
    required this.focusNode,
  });

  @override
  State<_DenominationInputRow> createState() => _DenominationInputRowState();
}

class _DenominationInputRowState extends State<_DenominationInputRow> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (widget.focusNode.hasFocus) {
      if (widget.controller.text == '0') {
        widget.controller.text = '';
      }
    }
    if (mounted) setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalValue = widget.value * (int.tryParse(widget.controller.text) ?? 0);
    
    const double inputWidth = 208.0; 
    const double inputHeight = 38.0;
    const double staticTextWidth = 56.0; 

    return Padding(
      padding: const EdgeInsets.only(bottom: 13.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: staticTextWidth, 
              alignment: Alignment.centerRight,
              child: Text(
                widget.value.toString(),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8), 
            Container(
              width: inputWidth, 
              height: inputHeight,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 17.0, right: 100.0), 
                    child: TextFormField(
                      controller: widget.controller,
                      focusNode: widget.focusNode, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                      textInputAction: TextInputAction.next,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: colorScheme.onSurface, 
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(top: 10, bottom: 5), 
                        hintText: '0',
                        hintStyle: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 17.0),
                      child: Text(
                        '= \$${widget.currencyFormat.format(totalValue)}',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

// -------------------------------------------------------------------
// 2. CashSettlementScreen (主頁面)
// -------------------------------------------------------------------

enum CashScreenMode {
  loading, 
  openCashAudit,
  settlement,
}

class CashSettlementScreen extends ConsumerStatefulWidget {
  const CashSettlementScreen({super.key});

  @override
  ConsumerState<CashSettlementScreen> createState() => _CashSettlementScreenState();
}

class _CashSettlementScreenState extends ConsumerState<CashSettlementScreen> {
  String? _shopId;
  String? _userId;
  String? _currentUserName;
  CashScreenMode _mode = CashScreenMode.loading; 
  bool _isLoading = true;
  bool _isSaving = false; 
  
  DateTime _settlementDate = DateTime.now(); 
  String? _currentOpenId; 
  
  double _pettyCashAmount = 0.0; 
  final Map<int, TextEditingController> _cashCounts = {
    2000: TextEditingController(), 1000: TextEditingController(), 500: TextEditingController(), 
    200: TextEditingController(), 100: TextEditingController(), 50: TextEditingController(), 
    10: TextEditingController(), 5: TextEditingController(), 1: TextEditingController()
  };
  
  // FocusNodes
  final FocusNode _revenueFocusNode = FocusNode();
  final Map<String, FocusNode> _paymentFocusNodes = {};
  final Map<int, FocusNode> _cashCountFocusNodes = {};
  List<FocusNode> _orderedFocusNodes = [];

  final Map<int, int> _targetCashCounts = {}; 
  final Map<int, double> _cashSubtotals = {
    2000: 0, 1000: 0, 500: 0, 200: 0, 100: 0, 50: 0, 10: 0, 5: 0, 1: 0
  };

  List<PaymentMethod> _enabledPaymentMethods = [];
  Map<String, TextEditingController> _paymentControllers = {};
  bool _enableDeposit = true; 

  final _revenueTotalController = TextEditingController();
  double _totalCash = 0.0; 
  double _paidInCash = 0.0; 
  double _expectedClosingCash = 0.0; 
  double _cashDifference = 0.0; 
  double _todayCostTotal = 0.0; 
  List<Map<String, dynamic>> _redeemedDeposits = []; 
  double _redeemedDepositTotal = 0.0;
  double _todayDepositTotal = 0.0; 
  final currencyFormat = NumberFormat('#,###', 'zh_TW');

  @override
  void initState() {
    super.initState();
    _cashCounts.forEach((key, c) {
      c.text = '';
      c.addListener(() {
        final count = int.tryParse(c.text) ?? 0;
        ref.read(settlementProvider.notifier).updateCashCount(key, count);
        _calculateAll();
      });
      _cashCountFocusNodes[key] = FocusNode();
    });
    
    _revenueTotalController.addListener(() {
      final amount = double.tryParse(_revenueTotalController.text) ?? 0.0;
      ref.read(settlementProvider.notifier).updateRevenue(amount);
      _calculateAll();
    });

    // 延遲初始化從 Provider 讀取的數據，確保 ref 已可用
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedProgress());
    _fetchInitialData();
  }

  void _loadSavedProgress() {
    final savedState = ref.read(settlementProvider);
    
    if (mounted) {
      setState(() {
        if (savedState.totalRevenue != null) {
          _revenueTotalController.text = savedState.totalRevenue!.toStringAsFixed(0);
        }
        
        savedState.cashCounts.forEach((key, value) {
          if (_cashCounts.containsKey(key)) {
            _cashCounts[key]!.text = value > 0 ? value.toString() : '';
          }
        });

        savedState.paymentAmounts.forEach((key, value) {
          if (_paymentControllers.containsKey(key)) {
             _paymentControllers[key]!.text = value > 0 ? value.toStringAsFixed(0) : '';
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _revenueTotalController.dispose();
    _revenueFocusNode.dispose();
    _cashCounts.forEach((_, c) => c.dispose());
    _cashCountFocusNodes.forEach((_, f) => f.dispose());
    _paymentControllers.forEach((_, c) => c.dispose()); 
    _paymentFocusNodes.forEach((_, f) => f.dispose());
    super.dispose();
  }

  // 安全檢查與焦點更新
  void _ensureFocusNodes() {
    // 防止 Hot Reload 後 Map 被清空導致崩潰
    if (_cashCountFocusNodes.isEmpty) {
      _cashCounts.forEach((key, _) {
        _cashCountFocusNodes[key] = FocusNode();
      });
    }
    
    // 更新焦點順序
    _orderedFocusNodes.clear();
    if (_mode == CashScreenMode.settlement) {
      _orderedFocusNodes.add(_revenueFocusNode);
      for (var method in _enabledPaymentMethods) {
        if (_paymentFocusNodes.containsKey(method.name)) {
          _orderedFocusNodes.add(_paymentFocusNodes[method.name]!);
        }
      }
    }
    final sortedKeys = _cashCountFocusNodes.keys.toList()..sort((a, b) => b.compareTo(a));
    for (var key in sortedKeys) {
      if (_cashCountFocusNodes.containsKey(key)) {
        _orderedFocusNodes.add(_cashCountFocusNodes[key]!);
      }
    }
  }

  void _moveFocus(int direction) {
    // 找出當前焦點的 index
    int currentIndex = -1;
    for (int i = 0; i < _orderedFocusNodes.length; i++) {
      if (_orderedFocusNodes[i].hasFocus) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex != -1) {
      int nextIndex = currentIndex + direction;
      // 循環切換
      if (nextIndex < 0) nextIndex = _orderedFocusNodes.length - 1;
      if (nextIndex >= _orderedFocusNodes.length) nextIndex = 0;
      
      _orderedFocusNodes[nextIndex].requestFocus();
    } else {
      if (_orderedFocusNodes.isNotEmpty) {
        _orderedFocusNodes.first.requestFocus();
      }
    }
  }

  // ... (資料載入部分保持不變) ...
  Future<void> _fetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    _userId = Supabase.instance.client.auth.currentUser?.id;

    if (_shopId == null || _userId == null) {
      if (mounted) context.go('/');
      return;
    }
    
    await _loadCurrentUser();
    await _loadPettyCashSettings();
    await _loadPaymentSettings(); 
    
    final statusRes = await Supabase.instance.client.rpc(
      'rpc_get_current_cash_status',
      params: {'p_shop_id': _shopId}
    ).single();

    final status = statusRes['status'] as String?;
    _currentOpenId = statusRes['open_id'] as String?;

    if (status == 'OPEN') {
      _mode = CashScreenMode.settlement;
      await _fetchSettlementData(); 
      _cashCounts.forEach((_, c) => c.text = ''); 
      _calculateAll();
    } else {
      _mode = CashScreenMode.openCashAudit;
    }
    
    _ensureFocusNodes();
    setState(() => _isLoading = false);
  }

  Future<void> _loadPaymentSettings() async {
    try {
      final res = await Supabase.instance.client
          .from('shop_payment_settings')
          .select('payment_methods, enable_deposit')
          .eq('shop_id', _shopId!)
          .single();
      
      List<PaymentMethod> methods = [];
      if (res.isNotEmpty) {
        final List<dynamic> data = res['payment_methods'] as List<dynamic>? ?? [];
        methods = data.map((json) => PaymentMethod.fromJson(json as Map<String, dynamic>)).toList();
        _enableDeposit = res['enable_deposit'] as bool? ?? true;
      }
      
      _enabledPaymentMethods = methods.where((m) => m.isEnabled).toList();
      
      _paymentControllers.forEach((_, c) => c.dispose()); 
      _paymentControllers.clear();
      _paymentFocusNodes.forEach((_, f) => f.dispose());
      _paymentFocusNodes.clear();

      for (var method in _enabledPaymentMethods) {
        final ctrl = TextEditingController();
        _paymentControllers[method.name] = ctrl;
        ctrl.addListener(() {
          final amount = double.tryParse(ctrl.text) ?? 0.0;
          ref.read(settlementProvider.notifier).updatePaymentAmount(method.name, amount);
          _calculateAll();
        });
        _paymentFocusNodes[method.name] = FocusNode();
      }
      
      // 載入暫存數據 (針對支付方式)
      final savedState = ref.read(settlementProvider);
      savedState.paymentAmounts.forEach((key, value) {
        if (_paymentControllers.containsKey(key)) {
          _paymentControllers[key]!.text = value > 0 ? value.toStringAsFixed(0) : '';
        }
      });
    } catch (e) {}
  }
  
  Future<void> _loadCurrentUser() async {
    if (_userId != null && _shopId != null) {
      try {
        final res = await Supabase.instance.client
            .from('users')
            .select('name')
            .eq('user_id', _userId!)
            .eq('shop_id', _shopId!)
            .maybeSingle();
        if (res != null) {
          setState(() {
            _currentUserName = res['name'];
          });
        }
      } catch (e) {
        debugPrint('Error loading user name: $e');
      }
    }
    if (_currentUserName == null) {
        setState(() => _currentUserName = 'Staff');
    }
  }

  Future<void> _loadPettyCashSettings() async {
    try {
      final settingsRes = await Supabase.instance.client
          .from('cash_register_settings')
          .select('*')
          .eq('shop_id', _shopId!)
          .single();

      double calculatedFloat = 0.0;
      _cashCounts.keys.forEach((value) {
          final count = settingsRes['cash_$value'] as int? ?? 0;
          _targetCashCounts[value] = count;
          calculatedFloat += value * count;
      });
      _pettyCashAmount = calculatedFloat;

    } catch (e) {
      _pettyCashAmount = 0.0;
    }
    _calculateAll();
  }

  Future<void> _fetchSettlementData() async {
    // 1. Existing Logic: Fetch Expense Logs
    final costRes = await Supabase.instance.client
        .from('expense_logs')
        .select('amount')
        .eq('shop_id', _shopId!)
        .eq('open_id', _currentOpenId!); 
        
    _todayCostTotal = costRes.fold(0.0, (sum, row) => sum + (row['amount'] as num? ?? 0.0));
    
    // 2. Existing Logic: Fetch Deposits
    final todayForDeposit = DateFormat('yyyy-MM-dd').format(_settlementDate); 
    final depositRes = await Supabase.instance.client
        .from('deposits')
        .select('amount')
        .eq('shop_id', _shopId!)
        .eq('received_date', todayForDeposit) 
        .filter('transaction_id', 'is', null);
        
    _todayDepositTotal = depositRes.fold(0.0, (sum, row) => sum + (row['amount'] as num? ?? 0.0));

    // -------------------------------------------------------------------------
    // 3. New Logic: Auto-fetch Revenue from Order System
    // -------------------------------------------------------------------------
    try {
      final supabase = Supabase.instance.client;
      
      // A. Total Revenue (from order_groups)
      final revenueRes = await supabase
          .from('order_groups')
          .select('final_amount')
          .eq('shop_id', _shopId!)
          .eq('open_id', _currentOpenId!)
          .eq('status', 'completed');
      
      final double totalRevenue = revenueRes.fold(0.0, (sum, row) => sum + (row['final_amount'] as num? ?? 0));
      _revenueTotalController.text = totalRevenue > 0 ? totalRevenue.toStringAsFixed(0) : '';

      // B. Payment Method Breakdown (from order_payments)
      // Note: We need to group by payment_method. Supabase doesn't support direct groupBy easily in client (without view or rpc).
      // So we fetch all payments for this open_id and aggregate locally.
      final paymentsRes = await supabase
          .from('order_payments')
          .select('payment_method, amount, order_groups!inner(status)')
          .eq('open_id', _currentOpenId!)
          .neq('order_groups.status', 'cancelled');
          
      final Map<String, double> methodTotals = {};
      for (var p in paymentsRes) {
        final method = p['payment_method'] as String;
        final amount = (p['amount'] as num).toDouble();
        methodTotals[method] = (methodTotals[method] ?? 0) + amount;
      }
      
      // Update UI Controllers
      methodTotals.forEach((method, amount) {
         if (_paymentControllers.containsKey(method)) {
           _paymentControllers[method]!.text = amount > 0 ? amount.toStringAsFixed(0) : '';
         }
      });
      
    } catch (e) {
      debugPrint("Auto-fetch revenue failed: $e");
    }

    _calculateAll();
  }

  void _calculateAll() {
    final revenue = double.tryParse(_revenueTotalController.text) ?? 0.0;
    double nonCashTotal = 0.0;
    _paymentControllers.forEach((name, controller) {
      nonCashTotal += double.tryParse(controller.text) ?? 0.0;
    });

    _redeemedDepositTotal = _enableDeposit
        ? _redeemedDeposits.fold(0.0, (sum, d) => sum + (d['amount'] as num))
        : 0.0;
    
    double nonCashEquivalents = nonCashTotal;
    _paidInCash = revenue - nonCashEquivalents; 

    _totalCash = 0.0;
    _cashCounts.forEach((value, controller) {
      final count = int.tryParse(controller.text) ?? 0;
      final subtotal = (value * count).toDouble();
      _cashSubtotals[value] = subtotal; 
      _totalCash += subtotal;
    });

    _expectedClosingCash = _pettyCashAmount + _paidInCash - _todayCostTotal;
    _cashDifference = _totalCash - _expectedClosingCash;

    if (mounted) setState(() {});
  }
  
  // ... (Open/Close Logic 保持不變) ...
  Future<void> _processOpenCash() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSaving || _shopId == null || _userId == null) return;
    setState(() => _isSaving = true);
    
    if (_totalCash != _pettyCashAmount) {
        _showNoticeDialog(l10n.inventoryErrorTitle, l10n.cashSettlementErrorCountMismatch); 
        setState(() => _isSaving = false);
        return;
    }
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int nextCount = 1;
    try {
        final countRes = await Supabase.instance.client
            .from('cash_opening')
            .select('open_count')
            .eq('shop_id', _shopId!)
            .eq('open_date', today);
        if (countRes.isNotEmpty) {
            nextCount = countRes.map((r) => r['open_count'] as int).reduce(max) + 1;
        }
    } catch (_) {}

    try {
      final insertRes = await Supabase.instance.client.from('cash_opening').insert({
        'shop_id': _shopId,
        'open_date': today,
        'open_count': nextCount,
        'opened_by_user_id': _userId,
        'petty_cash_amount': _totalCash,
      }).select('id').single();
      
      _currentOpenId = insertRes['id'] as String;
      if (mounted) {
        _showNoticeDialog(l10n.cashSettlementOpenSuccessTitle, l10n.cashSettlementOpenSuccessMsg(nextCount), popPage: true); 
      }
    } catch (e) {
         _showNoticeDialog(l10n.cashSettlementOpenFailedTitle, '${l10n.punchErrorGeneric(e.toString())}'); 
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _closeAndSave() async {
    final l10n = AppLocalizations.of(context)!; 
    if (_isSaving || _shopId == null || _currentOpenId == null) return;
    setState(() => _isSaving = true); 

    final double cashAdjustment = _totalCash - _pettyCashAmount; 
    final Map<String, int> adjustmentCounts = {}; 
    _cashCounts.forEach((value, controller) {
        final currentCount = int.tryParse(controller.text.trim()) ?? 0;
        final targetCount = _targetCashCounts[value] ?? 0;
        adjustmentCounts['cash_$value'] = currentCount - targetCount;
    });

    try {
        final transactionDate = DateFormat('yyyy-MM-dd').format(_settlementDate);
        Map<String, dynamic> paymentDetails = {};
        _paymentControllers.forEach((name, controller) {
            paymentDetails[name] = double.tryParse(controller.text) ?? 0.0;
        });
        
        final Map<String, dynamic> rpcParams = {
            'p_shop_id': _shopId, 'p_open_id': _currentOpenId, 'p_transaction_date': transactionDate,
            'p_revenue_total': double.tryParse(_revenueTotalController.text) ?? 0.0,
            'p_card_collected': double.tryParse(_paymentControllers['信用卡']?.text ?? '0') ?? 0.0,
            'p_linepay_collected': double.tryParse(_paymentControllers['LinePay']?.text ?? '0') ?? 0.0,
            'p_paper_plan_collected': double.tryParse(_paymentControllers['PaperPlan']?.text ?? '0') ?? 0.0,
            'p_redeemed_deposit_total': _enableDeposit ? _redeemedDepositTotal : 0.0,
            'p_redeemed_deposit_ids': _enableDeposit ? _redeemedDeposits.map((d) => d['id'] as String).toList() : [],
            'p_cost_total': _todayCostTotal, 
            'p_opened_cash_amount': _pettyCashAmount,
            'p_closed_cash_amount': _totalCash,
            'p_expected_cash_difference': _cashDifference,
            'p_details_json': paymentDetails,
            'p_cash_2000': int.tryParse(_cashCounts[2000]!.text) ?? 0,
            'p_cash_1000': int.tryParse(_cashCounts[1000]!.text) ?? 0,
            'p_cash_500': int.tryParse(_cashCounts[500]!.text) ?? 0,
            'p_cash_200': int.tryParse(_cashCounts[200]!.text) ?? 0,
            'p_cash_100': int.tryParse(_cashCounts[100]!.text) ?? 0,
            'p_cash_50': int.tryParse(_cashCounts[50]!.text) ?? 0,
            'p_cash_10': int.tryParse(_cashCounts[10]!.text) ?? 0,
            'p_cash_5': int.tryParse(_cashCounts[5]!.text) ?? 0,
            'p_cash_1': int.tryParse(_cashCounts[1]!.text) ?? 0,
        };

        await Supabase.instance.client.rpc('rpc_close_cash_audit_json', params: {'p_data': rpcParams});
        
        if (cashAdjustment.abs() > 0.01) { 
            await Supabase.instance.client.from('cash_vault_logs').insert({
                'shop_id': _shopId,
                'log_date': transactionDate,
                'log_type': cashAdjustment > 0 ? 'IN' : 'OUT', 
                'transaction_type': 'SETTLEMENT', 
                'amount': cashAdjustment, 
                'cash_2000': adjustmentCounts['cash_2000'],
                'cash_1000': adjustmentCounts['cash_1000'],
                'cash_500': adjustmentCounts['cash_500'],
                'cash_200': adjustmentCounts['cash_200'],
                'cash_100': adjustmentCounts['cash_100'],
                'cash_50': adjustmentCounts['cash_50'],
                'cash_10': adjustmentCounts['cash_10'],
                'cash_5': adjustmentCounts['cash_5'],
                'cash_1': adjustmentCounts['cash_1'],
                'notes': '收班結算，現金短溢: ${_cashDifference.toStringAsFixed(0)}',
                'operator_name': _currentUserName, 
            });
        }

        // --- 觸發列印關帳單與單日銷售紀錄 ---
        try {
           final rpcData = await Supabase.instance.client.rpc('rpc_get_shift_settlement_data', params: {
             'p_shop_id': _shopId,
             'p_open_id': _currentOpenId,
           });

           final uiData = {
              'paidInCash': _paidInCash,
              'cashDifference': _cashDifference,
              'depositsRedeemed': _enableDeposit ? _redeemedDepositTotal : 0.0,
           };

           debugPrint("Triggering settlement printing via PrinterService...");
           final printerService = PrinterService();
           await printerService.printSettlementRecords(
              shopId: _shopId!,
              staffName: _currentUserName ?? 'Staff',
              rpcData: rpcData as Map<String, dynamic>,
              uiData: uiData,
           );
        } catch (printErr) {
           debugPrint('Failed to print settlement: $printErr');
        }
        // ------------------------------------

        if (mounted) {
             _showNoticeDialog(l10n.cashSettlementCloseSuccessTitle, l10n.cashSettlementCloseSuccessMsg, popPage: true); 
        }
    } catch (e) {
        _showNoticeDialog(l10n.cashSettlementCloseFailedTitle, '${l10n.punchErrorGeneric(e.toString())}'); 
    } finally {
        if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _processSettlementConfirmation() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSaving) return;

    // 🔍 Check for active orders
    try {
      final activeOrders = await Supabase.instance.client
          .from('order_groups')
          .select('id')
          .eq('shop_id', _shopId!)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .neq('status', 'merged')
          .limit(1);

      if (activeOrders.isNotEmpty) {
        _showNoticeDialog("無法關帳", "尚有未結帳或未離席的訂單。\n請先完成所有桌位的結帳與清桌作業。");
        return;
      }
    } catch (e) {
      debugPrint("Check active orders failed: $e");
      // Optional: block or allow? Safer to allow if check fails, or show error.
      // Let's show error to be safe.
      _showNoticeDialog(l10n.commonError, "檢查訂單狀態失敗: $e");
      return;
    }

    if (_revenueTotalController.text.isEmpty) {
        _showNoticeDialog(l10n.costInputErrorInputTitle, l10n.cashSettlementErrorInputRevenue); 
        return;
    }
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmReviewDialog(
            pettyCash: _pettyCashAmount,
            paidInCash: _paidInCash,
            costs: _todayCostTotal,
            deposits: _enableDeposit ? _redeemedDepositTotal : 0.0,
            expectedCash: _expectedClosingCash,
            countedCash: _totalCash,
            difference: _cashDifference
        )
    );
    if (confirmed == true) await _closeAndSave();
  }

  // ------------------------------------------------------------------
  // UI Building
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // 1. 防崩潰：確保 FocusNode 存在
    _ensureFocusNodes();

    // 2. 獲取鍵盤高度
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    const toolbarHeight = 45.0; // 工具列高度
    
    // 3. 計算內容的底部 padding (確保最後一個輸入框能被捲動到工具列上方)
    final contentBottomPadding = isKeyboardVisible ? (keyboardHeight + toolbarHeight + 20) : 60.0;

    Widget content;
    if (_isLoading || _mode == CashScreenMode.loading) {
      content = Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface));
    } else if (_mode == CashScreenMode.openCashAudit) {
      content = _buildOpenAuditUI(bottomPadding: contentBottomPadding);
    } else {
      content = _buildSettlementUI(bottomPadding: contentBottomPadding);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // ✅ 關鍵：設為 false，我們自己控制 padding
      resizeToAvoidBottomInset: false, 
      appBar: _buildHeader(
        context, 
        _mode == CashScreenMode.openCashAudit ? l10n.cashSettlementTitleOpen : (_mode == CashScreenMode.settlement ? l10n.cashSettlementTitleClose : l10n.cashSettlementTitleLoading), 
        enableDeposit: _enableDeposit && _mode != CashScreenMode.loading,
        onAddPressed: _showDepositActionSheet,
      ),
      body: Stack(
        children: [
          // 主內容 (全螢幕)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: content,
            ),
          ),
          
          // ✅ 鍵盤工具列 (浮動在鍵盤上方)
          if (isKeyboardVisible)
            Positioned(
              bottom: keyboardHeight, 
              left: 0, 
              right: 0,
              child: Container(
                height: toolbarHeight,
                color: const Color(0xFFD1D3D9), // 仿 iOS 鍵盤工具列顏色
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    _ToolbarButton(
                      icon: CupertinoIcons.chevron_up,
                      onPressed: () => _moveFocus(-1),
                    ),
                    const SizedBox(width: 10),
                    _ToolbarButton(
                      icon: CupertinoIcons.chevron_down,
                      onPressed: () => _moveFocus(1),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: Size.zero,
                      child: Text(l10n.commonDone, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 17)), 
                      onPressed: () => FocusScope.of(context).unfocus(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOpenAuditUI({required double bottomPadding}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMatch = _totalCash == _pettyCashAmount;
    final successColor = theme.brightness == Brightness.dark ? Colors.white : Colors.green[700]!;
    return ListView(
      padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: bottomPadding),
      children: [
        const SizedBox(height: 10),
        Text(
          l10n.cashSettlementOpenDesc, 
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),
        _buildCashCountRows(),
        const SizedBox(height: 24),
        _buildAuditRow(l10n.cashSettlementTargetAmount, _pettyCashAmount, colorScheme.onSurface), 
        _buildAuditRow(l10n.cashSettlementTotal, _totalCash, isMatch ? successColor : colorScheme.error, isBold: true), 
        const SizedBox(height: 40),
        if (isMatch)
          Center(
            child: _WhiteButton( 
                text: l10n.commonSave, 
                onPressed: _isSaving ? null : _processOpenCash,
                child: _isSaving ? CupertinoActivityIndicator(color: colorScheme.onPrimary) : null,
            ),
          )
        else
            const SizedBox(height: 38),
      ],
    );
  }

  Widget _buildSettlementUI({required double bottomPadding}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final successColor = theme.brightness == Brightness.dark ? Colors.white : Colors.green[700]!;
    return ListView(
      padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: bottomPadding),
      children: [
        Text(l10n.cashSettlementRevenueAndPayment, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700)), 
        const SizedBox(height: 12),
        TextFormField(
          controller: _revenueTotalController, 
          focusNode: _revenueFocusNode, 
          keyboardType: const TextInputType.numberWithOptions(decimal: true), 
          textInputAction: TextInputAction.next,
          decoration: _buildInputDecoration(context, hintText: l10n.cashSettlementRevenueHint), 
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
          textAlignVertical: TextAlignVertical.center,
        ),
        
        ..._enabledPaymentMethods.map((method) => 
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: TextFormField(
                  controller: _paymentControllers[method.name]!, 
                  focusNode: _paymentFocusNodes[method.name], 
                  keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                  textInputAction: TextInputAction.next,
                  decoration: _buildInputDecoration(context, hintText: method.name),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                  textAlignVertical: TextAlignVertical.center,
              ),
            )
        ),
        
        if (_enableDeposit)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: _WhiteInputButton(
              text: l10n.cashSettlementDepositButton(_redeemedDepositTotal.toStringAsFixed(0)), 
              onPressed: _showRedeemDepositDialog,
            ),
          ),

        const SizedBox(height: 16),
        _buildAuditRow(l10n.cashSettlementReceivableCash, _paidInCash, successColor, isBold: true), 
        const Divider(height: 30, color: Colors.grey),

        Text(l10n.cashSettlementCashCountingTitle, 
          style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _buildAuditRow(l10n.cashSettlementTotalCashCounted, _totalCash, successColor, isBold: true), 
        const SizedBox(height: 8),
        _buildCashCountRows(), 
        
        const Divider(height: 30, color: Colors.grey),
        Text(l10n.cashSettlementReviewTitle, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700)), 
        const SizedBox(height: 12),

        _buildAuditRow(l10n.cashSettlementOpeningCash, _pettyCashAmount, colorScheme.onSurface), 
        _buildAuditRow(l10n.cashSettlementReceivableCash, _paidInCash, colorScheme.onSurface), 
        _buildAuditRow(l10n.cashSettlementDailyCosts, _todayCostTotal, colorScheme.onSurface),
        if (_enableDeposit)
          _buildAuditRow(l10n.cashSettlementDeposits, _redeemedDepositTotal, colorScheme.onSurface), 

        const SizedBox(height: 10),
        _buildAuditRow(l10n.cashSettlementExpectedCash, _expectedClosingCash, colorScheme.onSurface, isBold: true), 
        _buildAuditRow(l10n.cashSettlementTotalCashCounted, _totalCash, _cashDifference == 0 ? successColor : colorScheme.error, isBold: true), 

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.cashSettlementDifference, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700)), 
              Text(
                (_cashDifference > 0 ? '+ ' : '') + '\$${currencyFormat.format(_cashDifference)}',
                style: TextStyle(
                  color: _cashDifference == 0 ? successColor : colorScheme.error,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 40),
        Center(
          child: _WhiteButton(
              text: l10n.commonSubmit, 
              onPressed: _isSaving ? null : _processSettlementConfirmation,
              child: _isSaving ? const CupertinoActivityIndicator(color: Colors.black) : null,
          ),
        ),
        const SizedBox(height: 200), 
      ],
    );
  }

  Widget _buildCashCountRows() {
    // 排序：從大鈔到小鈔
    final sortedKeys = _cashCounts.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      children: sortedKeys.map((value) {
        return _DenominationInputRow(
          value: value,
          controller: _cashCounts[value]!,
          currencyFormat: currencyFormat,
          focusNode: _cashCountFocusNodes[value]!,
        );
      }).toList(),
    );
  }

  Widget _buildAuditRow(String label, double amount, Color color, {bool isBold = false}) {
    final display = '\$${currencyFormat.format(amount)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400)),
          Text(display, style: TextStyle(color: color, fontSize: 16, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );
  }

  Future<void> _showNoticeDialog(String title, String content, {bool popPage = false}) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _NoticeDialog(title: title, content: content),
    );
    if (popPage && mounted) {
      if (title.contains("成功") || title.contains("Success")) {
        ref.read(settlementProvider.notifier).reset();
      }
      context.go('/home'); 
    }
  }

  // --- Deposit (訂金) 相關 Dialogs ---
  void _showDepositActionSheet() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_mode == CashScreenMode.loading) return; 

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(l10n.cashSettlementDepositSheetTitle), 
        actions: [
          CupertinoActionSheetAction(
            child: Text(l10n.cashSettlementDepositNew), 
            onPressed: () {
              Navigator.pop(context);
              _showNewDepositDialog();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(l10n.commonCancel), 
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _showNewDepositDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.cashSettlementNewDepositTitle, style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)), 
                  const SizedBox(height: 20),
                  _buildDialogInput(nameCtrl, l10n.commonName, context), 
                  const SizedBox(height: 10),
                  _buildDialogInput(phoneCtrl, l10n.commonPhone, context, isNumber: true), 
                  const SizedBox(height: 10),
                  _buildDialogInput(amountCtrl, l10n.commonAmount, context, isNumber: true), 
                  const SizedBox(height: 10),
                  _buildDialogInput(noteCtrl, l10n.commonNotes, context), 
                  const SizedBox(height: 20),
                  
                  _WhiteButton(
                    text: l10n.commonConfirm, 
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                      final double? amount = double.tryParse(amountCtrl.text);
                      if (amount == null) return;
                      
                      Navigator.pop(context);
                      await _saveNewDeposit(nameCtrl.text, phoneCtrl.text, amount, noteCtrl.text);
                    }
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveNewDeposit(String name, String phone, double amount, String note) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (_shopId == null) return;
      await Supabase.instance.client.from('deposits').insert({
        'shop_id': _shopId,
        'customer_name': name,
        'customer_phone': phone,
        'amount': amount,
        'received_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'notes': note,
        // transaction_id = null (表示未被使用)
      });
      if (mounted) _showNoticeDialog(l10n.commonSuccess, l10n.cashSettlementDepositAddSuccess); 
    } catch (e) {
      if (mounted) _showNoticeDialog(l10n.inventoryErrorTitle, '${l10n.punchErrorGeneric(e.toString())}'); 
    }
  }

  // 選擇「今日已取貨 / 已折抵」的訂金
  Future<void> _showRedeemDepositDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 查詢尚未被折抵的訂金 (transaction_id is null)
    final res = await Supabase.instance.client
        .from('deposits')
        .select('*')
        .eq('shop_id', _shopId!)
        .filter('transaction_id', 'is', null) 
        .order('received_date', ascending: false);
    
    final List<Map<String, dynamic>> allDeposits = List<Map<String, dynamic>>.from(res);
    final Set<String> selectedIds = _redeemedDeposits.map((d) => d['id'] as String).toSet();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 500,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    Text(l10n.cashSettlementSelectRedeemedDeposit, style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)), 
                    const SizedBox(height: 10),
                    Expanded(
                      child: allDeposits.isEmpty
                          ? Center(child: Text(l10n.commonNoData, style: TextStyle(color: Colors.grey))) 
                          : ListView.builder(
                              itemCount: allDeposits.length,
                              itemBuilder: (ctx, i) {
                                final d = allDeposits[i];
                                final isSelected = selectedIds.contains(d['id']);
                                return CheckboxListTile(
                                  activeColor: colorScheme.primary,
                                  checkColor: colorScheme.onPrimary,
                                  title: Text('${d['customer_name']} (\$${d['amount']})', style: TextStyle(color: colorScheme.onSurface)),
                                  subtitle: Text('${d['received_date']} ${d['notes'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                                  value: isSelected,
                                  onChanged: (val) {
                                    setStateSB(() {
                                      if (val == true) {
                                        selectedIds.add(d['id']);
                                      } else {
                                        selectedIds.remove(d['id']);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    _WhiteButton(
                      text: l10n.commonConfirm, 
                      onPressed: () {
                        // 更新 _redeemedDeposits
                         setState(() {
                           _redeemedDeposits = allDeposits.where((d) => selectedIds.contains(d['id'])).toList();
                         });
                         _calculateAll();
                         Navigator.pop(context);
                      }
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String hint, BuildContext context, {bool isNumber = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: Colors.grey),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.onSurface)),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 自訂 Widget (Header, Buttons, Dialogs, ...)
// -------------------------------------------------------------------

PreferredSizeWidget _buildHeader(BuildContext context, String title, {bool enableDeposit = false, VoidCallback? onAddPressed}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return PreferredSize(
    preferredSize: const Size.fromHeight(100.0), 
    child: Container(
      color: theme.scaffoldBackgroundColor,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
              onPressed: () => context.go('/home'), 
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (enableDeposit)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(CupertinoIcons.add, color: colorScheme.onSurface, size: 28),
                  onPressed: onAddPressed,
                )
            else
                const SizedBox(width: 58), 
          ],
        ),
      ),
    ),
  );
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _ToolbarButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44, height: 44,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Icon(icon, color: Colors.blue, size: 28),
      ),
    );
  }
}

// 白色按鈕 (Save / Submit)
class _WhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? child;
  const _WhiteButton({required this.text, this.onPressed, this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: 140,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: child ?? Text(text, style: TextStyle(color: colorScheme.onPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// 白色輸入按鈕 (Deposit Button)
class _WhiteInputButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _WhiteInputButton({required this.text, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 54, 
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(text, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
             Icon(CupertinoIcons.chevron_down, color: colorScheme.onSurface, size: 20),
          ],
        ),
      ),
    );
  }
}

class _NoticeDialog extends StatelessWidget {
  final String title;
  final String content;
  const _NoticeDialog({required this.title, required this.content});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(content, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
                width: 100,
                child: _WhiteButton(text: l10n.commonOk, onPressed: () => Navigator.of(context).pop())
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmReviewDialog extends StatelessWidget {
    final double pettyCash;
    final double paidInCash;
    final double costs;
    final double deposits;
    final double expectedCash;
    final double countedCash;
    final double difference;

    const _ConfirmReviewDialog({
        required this.pettyCash, required this.paidInCash, required this.costs, required this.deposits,
        required this.expectedCash, required this.countedCash, required this.difference
    });

    @override
    Widget build(BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final currencyFormat = NumberFormat('#,###', 'zh_TW');
        
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Text(l10n.cashSettlementConfirmTitle, style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)), 
                        const SizedBox(height: 20),
                        _row(l10n.cashSettlementOpeningCash, pettyCash, currencyFormat, colorScheme.onSurface), 
                        _row(l10n.cashSettlementReceivableCash, paidInCash, currencyFormat, colorScheme.onSurface), 
                        _row(l10n.cashSettlementDailyCosts, costs, currencyFormat, colorScheme.onSurface),
                        if (deposits > 0) _row(l10n.cashSettlementDeposits, deposits, currencyFormat, colorScheme.onSurface), 
                        const Divider(color: Colors.grey),
                        _row(l10n.cashSettlementExpectedCash, expectedCash, currencyFormat, colorScheme.onSurface, isBold: true), 
                        _row(l10n.cashSettlementTotalCashCounted, countedCash, currencyFormat, colorScheme.onSurface, isBold: true), 
                        const SizedBox(height: 10),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Text(l10n.cashSettlementDifference, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)), 
                                Text(
                                    '\$${currencyFormat.format(difference)}',
                                    style: TextStyle(
                                        color: difference == 0 ? Colors.green : colorScheme.error,
                                        fontSize: 18, fontWeight: FontWeight.bold
                                    ),
                                )
                            ],
                        ),
                         const SizedBox(height: 30),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                                TextButton(
                                    child: Text(l10n.commonCancel, style: TextStyle(color: Colors.grey, fontSize: 18)), 
                                    onPressed: () => Navigator.pop(context, false),
                                ),
                                _WhiteButton(
                                    text: l10n.commonSubmit, 
                                    onPressed: () => Navigator.pop(context, true),
                                )
                            ],
                        )
                    ],
                ),
            ),
          ),
        );
    }
    
    Widget _row(String label, double val, NumberFormat fmt, Color color, {bool isBold = false}) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
                    Text('\$${fmt.format(val)}', style: TextStyle(color: color, fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
                ],
            ),
        );
    }
}