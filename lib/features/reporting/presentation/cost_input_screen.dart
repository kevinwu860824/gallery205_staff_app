// lib/features/reporting/presentation/cost_input_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/core/constants/app_constants.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// 白色圓角輸入框樣式
InputDecoration _buildInputDecoration(BuildContext context, {required String hintText}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: theme.cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
  );
}

// -------------------------------------------------------------------
// 2. CostInputScreen (主頁面)
// -------------------------------------------------------------------

class CostInputScreen extends StatefulWidget {
  const CostInputScreen({super.key});

  @override
  State<CostInputScreen> createState() => _CostInputScreenState();
}

class _CostInputScreenState extends State<CostInputScreen> {
  // --- 邏輯狀態變數 ---
  String? _shopId;
  String? _userId;
  bool _isLoading = true;
  double _todayTotalCost = 0.0;
  String? _activeOpenId; 
  
  // ✅ 修改：改為動態列表
  List<String> _categories = []; 
  String? _selectedCategory; // 剛開始為 null，等資料載入後設定

  final _itemController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // --- 後端邏輯 ---

  Future<void> _fetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    _userId = Supabase.instance.client.auth.currentUser?.id;

    if (_shopId == null || _userId == null) {
      if (mounted) context.go('/');
      return;
    }
    
    // ✅ 修改：同時並行處理「檢查開帳」和「抓取類別」
    await Future.wait([
      _checkActiveShift(),
      _fetchCategories(),
    ]);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkActiveShift() async {
    try {
      final dynamic response = await Supabase.instance.client.rpc(
        'rpc_get_current_cash_status', 
        params: {'p_shop_id': _shopId}
      );

      Map<String, dynamic>? statusData;
      if (response is List && response.isNotEmpty) {
        statusData = response.first as Map<String, dynamic>;
      } else if (response is Map) {
        statusData = response as Map<String, dynamic>;
      }

      if (statusData != null && statusData['status'] == 'OPEN') {
        _activeOpenId = statusData['open_id'] as String?;
      } else {
        _activeOpenId = null;
      }

      if (_activeOpenId != null) {
        await _calculateTodayTotalCost();
      }
    } catch (e) {
      debugPrint('Error checking active shift: $e');
    }
  }

  // ✅ 新增：從資料庫抓取類別
  Future<void> _fetchCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('expense_categories')
          .select('name')
          .eq('shop_id', _shopId!)
          .order('sort_order', ascending: true); // 依照後台設定的順序
      
      if (mounted) {
        setState(() {
          // 1. 將資料庫結果轉換為 List<String>
          _categories = List<String>.from(res.map((e) => e['name']));
          
          // 2. 設定預設選中項
          if (_categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          } else {
            // 3. 如果資料庫空的 (尚未設定)，顯示「其他」
            _categories = ['其他'];
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      // 4. 發生錯誤 (例如斷網)，使用 AppConstants 作為備案
      if (mounted) {
        setState(() {
          _categories = ['其他'];
          _selectedCategory = _categories.first;
        });
      }
    }
  }

  Future<void> _calculateTodayTotalCost() async {
    if (_activeOpenId == null) return;
    try {
      final res = await Supabase.instance.client
          .from('expense_logs')
          .select('amount')
          .eq('shop_id', _shopId!)
          .eq('open_id', _activeOpenId!); 

      final total = res.fold(0.0, (sum, row) => sum + (row['amount'] as num? ?? 0.0));
      
      if (mounted) {
        setState(() {
          _todayTotalCost = total.toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error calculating total cost: $e');
    }
  }
  
  // 自訂 Dialog
  Future<void> _showNoticeDialog(String title, String content) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _NoticeDialog(title: title, content: content),
    );
  }

  Future<void> _saveExpense() async {
    final l10n = AppLocalizations.of(context)!;
    if (_activeOpenId == null) {
        _showNoticeDialog(l10n.costInputTabNotOpenTitle, l10n.costInputTabNotOpenMsg); 
        return;
    }
    
    final itemName = _itemController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (itemName.isEmpty || amount == null || amount <= 0) {
      _showNoticeDialog(
        l10n.costInputErrorInputTitle, 
        l10n.costInputErrorInputMsg, 
      );
      return;
    }

    try {
      await Supabase.instance.client.from('expense_logs').insert({
        'shop_id': _shopId,
        'open_id': _activeOpenId, 
        'category': _selectedCategory ?? 'Other', // 防呆
        'item_name': itemName,
        'amount': amount,
        'user_id': _userId,
        'transaction_id': null, 
      });

      _itemController.clear();
      _amountController.clear();
      FocusScope.of(context).unfocus(); 

      await _calculateTodayTotalCost();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.costInputSuccess), 
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      _showNoticeDialog(l10n.costInputSaveFailed, '${l10n.punchErrorGeneric(e.toString())}'); 
    }
  }

  void _viewDetails() async {
    final l10n = AppLocalizations.of(context)!;
    if (_activeOpenId == null) {
         _showNoticeDialog(l10n.costInputTabNotOpenTitle, l10n.costInputTabNotOpenMsg); 
        return;
    }
    
    await context.push('/costDetails', extra: {'open_id': _activeOpenId}); 
    await _calculateTodayTotalCost(); 
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildHeader(context, l10n.costInputTitle), 
        body: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
      );
    }
    
    // -------------------------------------------------
    // 狀態一：未開帳
    // -------------------------------------------------
    if (_activeOpenId == null) {
        return Scaffold(
             backgroundColor: theme.scaffoldBackgroundColor,
             appBar: _buildHeader(context, l10n.costInputTitle), 
             body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(CupertinoIcons.lock_fill, size: 65, color: colorScheme.error),
                            const SizedBox(height: 20),
                            Text(
                                l10n.costInputTabNotOpenPageTitle, 
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                                l10n.costInputTabNotOpenPageDesc, 
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                            ),
                            const SizedBox(height: 30),
                            _LargeWhiteButton( 
                                text: l10n.costInputButtonOpenTab, 
                                onPressed: () async {
                                  await context.push('/cashSettlement');
                                  setState(() { _isLoading = true; });
                                  await _fetchInitialData();
                                }, 
                            ),
                        ],
                    ),
                ),
            ),
        );
    }

    // -------------------------------------------------
    // 狀態二：已開帳
    // -------------------------------------------------
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildHeader(context, l10n.costInputTitle, actions: [ 
        CupertinoButton( 
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(CupertinoIcons.list_bullet, color: colorScheme.onSurface, size: 30),
          onPressed: _viewDetails,
        ),
      ]),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- 今日總開銷卡片 ---
                Container(
                  width: double.infinity,
                  height: 118,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.costInputTotalToday, 
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '\$${_todayTotalCost.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.03,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                
                // --- 類別下拉選單 ---
                _WhiteDropdown(
                  value: _selectedCategory ?? '',
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedCategory = newValue);
                    }
                  },
                  items: _categories, 
                ),
                const SizedBox(height: 15),

                // --- 品項名稱 ---
                TextFormField(
                  controller: _itemController,
                  decoration: _buildInputDecoration(context, hintText: l10n.costInputLabelName), 
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                  textAlignVertical: TextAlignVertical.center,
                ),
                const SizedBox(height: 15),

                // --- 金額 ---
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _buildInputDecoration(context, hintText: l10n.costInputLabelPrice), 
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                  textAlignVertical: TextAlignVertical.center,
                ),
                const SizedBox(height: 48),

                // --- 儲存按鈕 ---
                _DialogWhiteButton(
                  text: l10n.commonSave, 
                  onPressed: _saveExpense,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 4. 自訂輔助 Widget
// -------------------------------------------------------------------

PreferredSizeWidget _buildHeader(BuildContext context, String title, {List<Widget>? actions}) {
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
              onPressed: () => context.pop(), 
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ...(actions ?? [const SizedBox(width: 58)]),
          ],
        ),
      ),
    ),
  );
}

class _DialogWhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? child;

  const _DialogWhiteButton({required this.text, this.onPressed, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: 109.6,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: child ?? Text(
          text,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LargeWhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _LargeWhiteButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: 245, 
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center, 
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
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
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _DialogWhiteButton(
              text: l10n.commonOk,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  final List<String> items;

  const _WhiteDropdown({
    required this.value, 
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      height: 54, 
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null, 
          hint: Text(value.isEmpty ? l10n.costInputLoadingCategories : value, style: TextStyle(color: colorScheme.onSurface)), 
          isExpanded: true,
          icon: Icon(CupertinoIcons.chevron_down, color: colorScheme.onSurface),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          dropdownColor: theme.cardColor, 
        ),
      ),
    );
  }
}