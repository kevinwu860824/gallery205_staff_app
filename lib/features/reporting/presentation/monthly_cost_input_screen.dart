// lib/features/reporting/presentation/monthly_cost_input_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
// 保留 AppConstants 作為備案
import 'package:gallery205_staff_app/core/constants/app_constants.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w500),
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
// 2. MonthlyCostInputScreen
// -------------------------------------------------------------------

class MonthlyCostInputScreen extends StatefulWidget {
  const MonthlyCostInputScreen({super.key});

  @override
  State<MonthlyCostInputScreen> createState() => _MonthlyCostInputScreenState();
}

class _MonthlyCostInputScreenState extends State<MonthlyCostInputScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _shopId;
  String? _userId;
  bool _isLoading = true;
  double _totalMonthlyCost = 0.0;
  
  // ✅ 修改：改為動態列表
  List<String> _categories = [];
  String? _selectedCategory; // 初始為 null

  final _itemController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _incurredDate = DateTime.now();
  final _notesController = TextEditingController();
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _incurredDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    _initializeData();
  }
  
  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    _userId = Supabase.instance.client.auth.currentUser?.id;
    if (_shopId == null || _userId == null) {
      if (mounted) context.go('/');
      return;
    }

    // ✅ 修改：同時抓取「總開銷」和「類別列表」
    await Future.wait([
      _fetchTotalCost(),
      _fetchCategories(),
    ]);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ✅ 新增：從資料庫抓取類別
  Future<void> _fetchCategories() async {
    try {
      // 這裡您可以決定是否要過濾。
      // 如果 Monthly Cost 通常是 OPEX，您可以加 .eq('type', 'OPEX')
      // 但為了彈性，我們先抓取全部
      final res = await Supabase.instance.client
          .from('expense_categories')
          .select('name')
          .eq('shop_id', _shopId!)
          .order('sort_order', ascending: true);
      
      if (mounted) {
        setState(() {
          _categories = List<String>.from(res.map((e) => e['name']));
          
          // 設定預設值
          if (_categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          } else {
            // 備案：若資料庫為空，顯示「其他」
            _categories = ['其他'];
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      // 錯誤備案
      if (mounted) {
        setState(() {
          _categories = ['其他'];
          _selectedCategory = _categories.first;
        });
      }
    }
  }

  Future<void> _fetchTotalCost() async {
    final l10n = AppLocalizations.of(context)!;
    // setState(() => _isLoading = true); // 移除這行，因為我們現在由 _initializeData 統一控制 Loading
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final String firstDayStr = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
    final String lastDayStr = DateFormat('yyyy-MM-dd').format(lastDayOfMonth);

    try {
      final res = await Supabase.instance.client
          .from('expense_logs')
          .select('amount') 
          .eq('shop_id', _shopId!)
          .filter('open_id', 'is', 'null') 
          .gte('incurred_date', firstDayStr)
          .lte('incurred_date', lastDayStr);

      _totalMonthlyCost = res.fold(
          0.0, (sum, item) => sum + (item['amount'] as num? ?? 0.0));
    } catch (e) {
      _showNoticeDialog(l10n.inventoryErrorTitle, '${l10n.punchErrorGeneric(e.toString())}'); 
    }
    // setState(() => _isLoading = false); // 移除這行
  }

  void _changeMonth(int increment) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + increment, 1);
      _incurredDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      _isLoading = true; // 切換月份時顯示 loading
    });
    _fetchTotalCost().then((_) => setState(() => _isLoading = false));
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final newDate = await showDatePicker(
      context: context,
      initialDate: _incurredDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              surface: theme.cardColor,
              onSurface: colorScheme.onSurface,
            ),
            dialogBackgroundColor: theme.cardColor,
          ),
          child: child!,
        );
      },
    );
    if (newDate != null) {
      setState(() => _incurredDate = newDate);
    }
  }

  Future<void> _showNoticeDialog(String title, String content, {bool popPage = false}) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _NoticeDialog(title: title, content: content),
    );
    if (popPage && mounted) {
      context.pop(); 
    }
  }

  Future<void> _saveExpense() async {
    final l10n = AppLocalizations.of(context)!;
    if (_itemController.text.trim().isEmpty || _amountController.text.trim().isEmpty) {
      _showNoticeDialog(l10n.monthlyCostErrorInputTitle, l10n.monthlyCostErrorInputMsg); 
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      await Supabase.instance.client.from('expense_logs').insert({
        'shop_id': _shopId,
        'user_id': _userId,
        'open_id': null, 
        'category': _selectedCategory ?? 'Other', // 防呆
        'item_name': _itemController.text.trim(),
        'amount': double.parse(_amountController.text.trim()),
        'incurred_date': DateFormat('yyyy-MM-dd').format(_incurredDate),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      });
      
      _itemController.clear();
      _amountController.clear();
      _notesController.clear();
      FocusScope.of(context).unfocus();
      
      await _fetchTotalCost();

    } catch (e) {
      _showNoticeDialog(l10n.monthlyCostErrorSaveFailed, e.toString()); 
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildHeader(context, l10n.monthlyCostTitle, actions: [ 
        CupertinoButton( 
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(CupertinoIcons.bars, color: colorScheme.onSurface, size: 30),
          
          onPressed: () async { 
            await context.push('/monthlyCostDetail', extra: _selectedMonth);
            _fetchTotalCost();
          },
        ),
      ]),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- 月份選擇器 ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    DateFormat('yyyy/MM').format(_selectedMonth),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  CupertinoButton(
                    child: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface, size: 30),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // --- 總金額卡片 ---
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
                      l10n.monthlyCostTotal, 
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _isLoading
                      ? CupertinoActivityIndicator(color: colorScheme.onSurface)
                      : Text(
                          '\$${_totalMonthlyCost.toStringAsFixed(0)}',
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
              
              // --- 輸入表單 ---
              // ✅ 修改：傳入動態列表 _categories
              _CustomDropdown(
                value: _selectedCategory ?? '',
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedCategory = newValue);
                  }
                },
                items: _categories,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _itemController,
                decoration: _buildInputDecoration(hintText: l10n.monthlyCostLabelName, context: context), 
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                textAlignVertical: TextAlignVertical.center,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _buildInputDecoration(hintText: l10n.monthlyCostLabelPrice, context: context), 
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                textAlignVertical: TextAlignVertical.center,
              ),
              const SizedBox(height: 15),
              _CustomInputButton( // 日期
                text: DateFormat('yyyy/MM/dd').format(_incurredDate),
                icon: CupertinoIcons.calendar,
                onPressed: () => _selectDate(context),
              ),
              const SizedBox(height: 15),
              TextFormField( // 備註
                controller: _notesController,
                decoration: _buildInputDecoration(hintText: l10n.monthlyCostLabelNote, context: context), 
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                textAlignVertical: TextAlignVertical.center,
              ),
              const SizedBox(height: 35),
              
              // --- 儲存按鈕 ---
              _DialogWhiteButton(
                text: l10n.commonSave, 
                onPressed: _isSaving ? null : _saveExpense,
                child: _isSaving ? CupertinoActivityIndicator(color: colorScheme.onPrimary) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 自訂 Widget (Header, Buttons, Dialogs, ...)
// -------------------------------------------------------------------

// --- 統一的頁面頂部 (Header) ---
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

// --- Dialog 專用的小白按鈕 (Save / OK) ---
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
        child: child ?? Text(text, style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// --- Dialog 1: Notice (OK) ---
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
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Text(content, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            _DialogWhiteButton(text: l10n.commonOk, onPressed: () => Navigator.of(context).pop()), 
          ],
        ),
      ),
    );
  }
}

// --- 表單中的下拉選單 (Category) ---
class _CustomDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  final List<String> items;
  const _CustomDropdown({required this.value, required this.onChanged, required this.items});
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
          // ✅ 防呆：如果資料庫還沒載入，value可能不在items裡
          value: items.contains(value) ? value : null, 
          hint: Text(value.isEmpty ? l10n.costInputLoadingCategories : value, style: TextStyle(color: colorScheme.onSurface)), 
          isExpanded: true,
          icon: Icon(CupertinoIcons.chevron_down, color: colorScheme.onSurface),
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          dropdownColor: theme.cardColor,
        ),
      ),
    );
  }
}

// --- 表單中的白色按鈕 (Date) ---
class _CustomInputButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  
  const _CustomInputButton({required this.text, required this.icon, required this.onPressed});

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
          children: [
            Icon(icon, color: colorScheme.onSurface, size: 22),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}