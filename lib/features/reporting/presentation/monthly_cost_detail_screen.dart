// lib/features/reporting/presentation/monthly_cost_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/core/constants/app_constants.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

InputDecoration _buildInputDecoration(BuildContext context, {required String hintText}) {
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

// -------------------------------------------------------------------
// 2. MonthlyCostDetailScreen (列表頁面)
// -------------------------------------------------------------------

class MonthlyCostDetailScreen extends StatefulWidget {
  final DateTime selectedMonth;
  const MonthlyCostDetailScreen({super.key, required this.selectedMonth});

  @override
  State<MonthlyCostDetailScreen> createState() => _MonthlyCostDetailScreenState();
}

class _MonthlyCostDetailScreenState extends State<MonthlyCostDetailScreen> {
  String? _shopId;
  String? _userId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _monthlyExpenses = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    _userId = Supabase.instance.client.auth.currentUser?.id;
    if (_shopId == null || _userId == null) {
      if (mounted) context.go('/');
      return;
    }
    await _fetchMonthlyExpenses();
  }

  Future<void> _fetchMonthlyExpenses() async {
    setState(() => _isLoading = true);
    final firstDayOfMonth = DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0);
    final String firstDayStr = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
    final String lastDayStr = DateFormat('yyyy-MM-dd').format(lastDayOfMonth);

    try {
      final res = await Supabase.instance.client
          .from('expense_logs_view') 
          .select('*') 
          .eq('shop_id', _shopId!)
          .filter('open_id', 'is', 'null') 
          .gte('expense_date', firstDayStr) 
          .lte('expense_date', lastDayStr) 
          .order('expense_date', ascending: false);
      _monthlyExpenses = res;
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showNoticeDialog(l10n.inventoryErrorTitle, l10n.monthlyCostDetailErrorFetch(e.toString())); 
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showNoticeDialog(String title, String content) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _NoticeDialog(title: title, content: content),
    );
  }

  Future<void> _saveEditedExpense(String id, String category, String item, String amountStr, String dateStr, String note) async {
    final l10n = AppLocalizations.of(context)!; 
    final amount = double.tryParse(amountStr);
    if (item.isEmpty || amount == null || amount <= 0) {
      _showNoticeDialog(l10n.costInputErrorInputTitle, l10n.costInputErrorInputMsg); 
      return;
    }
    try {
      await Supabase.instance.client
          .from('expense_logs')
          .update({
            'category': category,
            'item_name': item.trim(),
            'amount': amount,
            'incurred_date': dateStr,
            'notes': note.isEmpty ? null : note,
          })
          .eq('id', id);
      await _fetchMonthlyExpenses(); 
    } catch (e) {
      _showNoticeDialog(l10n.monthlyCostDetailErrorUpdate, e.toString()); 
    }
  }

  Future<void> _deleteExpense(String id) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Supabase.instance.client
          .from('expense_logs')
          .delete()
          .eq('id', id);
      await _fetchMonthlyExpenses(); 
    } catch (e) {
      _showNoticeDialog(l10n.monthlyCostDetailErrorDelete, e.toString()); 
    }
  }
  
  Future<void> _showDeleteDialog(Map<String, dynamic> expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(
        expenseName: expense['item_name'] ?? 'this cost',
      ),
    );
    if (confirm == true) {
      await _deleteExpense(expense['id']);
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> expense) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditCostDialog(expense: expense),
    );

    if (result is Map<String, dynamic>) {
      await _saveEditedExpense(
        expense['id'],
        result['category'],
        result['name'],
        result['price'],
        result['date'],
        result['note'],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildHeader(context, l10n.monthlyCostDetailTitle), 
      body: SafeArea(
        child: _isLoading
            ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
            : _monthlyExpenses.isEmpty
                ? Center(child: Text(l10n.monthlyCostDetailNoRecords, style: TextStyle(color: colorScheme.onSurface))) 
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _monthlyExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = _monthlyExpenses[index];
                      return _CostCard(
                        expense: expense,
                        onEdit: () => _showEditDialog(expense),
                        onDelete: () => _showDeleteDialog(expense),
                      );
                    },
                  ),
      ),
    );
  }
}


// -------------------------------------------------------------------
// 3. 自訂 Widget (Header, Card, Dialogs, ...)
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

class _CostCard extends StatelessWidget {
  final Map<String, dynamic> expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CostCard({required this.expense, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = expense['item_name'] ?? l10n.monthlyCostDetailItemUntitled; 
    final category = expense['category'] ?? l10n.monthlyCostDetailCategoryNA; 
    final buyer = expense['operator_name'] ?? l10n.monthlyCostDetailBuyerNA; 
    final amount = (expense['amount'] as num? ?? 0.0).toStringAsFixed(0);
    final date = DateTime.tryParse(expense['expense_date'] ?? '') ?? DateTime.now(); 

    return Container(
      height: 123, 
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '\$ $amount',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.monthlyCostDetailLabelCategory(category), 
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), 
                    Text(
                      l10n.monthlyCostDetailLabelDate(DateFormat('MM/dd').format(date)), 
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), 
                    Text(
                      l10n.monthlyCostDetailLabelBuyer(buyer), 
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(4),
                minSize: 22,
                onPressed: onEdit,
                child: Icon(CupertinoIcons.pencil, color: colorScheme.onSurface, size: 22),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(4),
                minSize: 22,
                onPressed: onDelete,
                child: Icon(CupertinoIcons.trash, color: colorScheme.onSurface, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- ✅ [修正] 編輯 Dialog：改為動態讀取類別 ---
class _EditCostDialog extends StatefulWidget {
  final Map<String, dynamic> expense;
  const _EditCostDialog({required this.expense});

  @override
  State<_EditCostDialog> createState() => _EditCostDialogState();
}

class _EditCostDialogState extends State<_EditCostDialog> {
  String? _selectedCategory; // 初始為 null (等待載入)
  late final TextEditingController _itemController;
  late final TextEditingController _amountController;
  late DateTime _incurredDate;
  late final TextEditingController _notesController;
  
  // ✅ 新增：動態類別列表
  List<String> _categories = []; 
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _itemController = TextEditingController(text: widget.expense['item_name']);
    _amountController = TextEditingController(text: (widget.expense['amount'] as num? ?? 0).toStringAsFixed(0));
    _incurredDate = DateTime.tryParse(widget.expense['expense_date'] ?? '') ?? DateTime.now();
    _notesController = TextEditingController(text: widget.expense['notes']);
    
    // 先暫存目前的 category
    _selectedCategory = widget.expense['category'];
    
    // ✅ 啟動：抓取類別
    _fetchCategories();
  }
  
  // ✅ 新增：抓取類別邏輯
  Future<void> _fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');

      if (shopId != null) {
        final res = await Supabase.instance.client
            .from('expense_categories')
            .select('name')
            .eq('shop_id', shopId)
            .order('sort_order');
        
        if (mounted) {
          setState(() {
            _categories = List<String>.from(res.map((e) => e['name']));
            
            // 如果原本的 category 不在列表裡，加回去以免顯示錯誤
            if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
              _categories.insert(0, _selectedCategory!);
            } else if (_categories.isEmpty) {
              _categories = AppConstants.expenseCategories;
            }
            
            // 如果還是 null，預設選第一個
            _selectedCategory ??= _categories.first;
            _loadingCategories = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories in Edit Dialog: $e');
    }

    // 失敗或錯誤時的備案
    if (mounted) {
      setState(() {
        _categories = AppConstants.expenseCategories;
        _selectedCategory ??= _categories.first;
        _loadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: _incurredDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (newDate != null) {
      setState(() => _incurredDate = newDate);
    }
  }

  void _onSave() {
    Navigator.of(context).pop({
      'category': _selectedCategory,
      'name': _itemController.text.trim(),
      'price': _amountController.text.trim(),
      'date': DateFormat('yyyy-MM-dd').format(_incurredDate),
      'note': _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
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
              Text(
                l10n.monthlyCostDetailEditTitle, 
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              
              // ✅ 修改：使用動態列表的 Dropdown
              _loadingCategories 
                  ? CupertinoActivityIndicator(color: colorScheme.onSurface)
                  : _WhiteDropdown(
                      value: _selectedCategory ?? '',
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                      items: _categories, // 這裡使用動態抓取的列表
                    ),
              
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: TextFormField(
                  controller: _itemController,
                  decoration: _buildInputDecoration(context, hintText: l10n.monthlyCostLabelName), 
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                  textAlignVertical: TextAlignVertical.center,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _buildInputDecoration(context, hintText: l10n.monthlyCostLabelPrice), 
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                  textAlignVertical: TextAlignVertical.center,
                ),
              ),
              const SizedBox(height: 12),
              _WhiteInputButton(
                text: DateFormat('yyyy/MM/dd').format(_incurredDate),
                icon: CupertinoIcons.calendar,
                onPressed: () => _selectDate(context),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: TextFormField(
                  controller: _notesController,
                  decoration: _buildInputDecoration(context, hintText: l10n.monthlyCostLabelNote), 
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                  textAlignVertical: TextAlignVertical.center,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TextCancelButton(onPressed: () => Navigator.of(context).pop(null)),
                  _DialogWhiteButton(text: l10n.commonSave, onPressed: _onSave), 
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  final String expenseName;
  const _ConfirmDeleteDialog({required this.expenseName});

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
              l10n.monthlyCostDetailDeleteTitle, 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.monthlyCostDetailDeleteContent(expenseName), 
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TextCancelButton(onPressed: () => Navigator.of(context).pop(false)),
                _DialogWhiteButton(
                  text: l10n.commonDelete, 
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
        child: child ?? Text(text, style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _TextCancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  const _TextCancelButton({required this.onPressed, this.text = 'Cancel'});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayText = text == 'Cancel' ? l10n.commonCancel : text;
    return TextButton(
      onPressed: onPressed,
      child: Text(displayText, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
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

class _WhiteDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  final List<String> items;
  const _WhiteDropdown({required this.value, required this.onChanged, required this.items});
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
          // ✅ 防呆：如果 value 不在 items 裡，給 null
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

class _WhiteInputButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  
  const _WhiteInputButton({required this.text, required this.icon, required this.onPressed});

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