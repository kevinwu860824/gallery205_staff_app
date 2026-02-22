// lib/features/reporting/presentation/cost_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/core/constants/app_constants.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 1. UI 樣式定義
// -------------------------------------------------------------------

InputDecoration _buildInputDecoration(BuildContext context, {required String hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
  );
}

// -------------------------------------------------------------------
// 2. CostDetailScreen (主頁面)
// -------------------------------------------------------------------

class CostDetailScreen extends StatefulWidget {
  final String? transactionId;
  final String? targetDate; 
  final String? openId; 
  
  const CostDetailScreen({
    super.key,
    this.transactionId, 
    this.targetDate,
    this.openId, 
  });

  @override
  State<CostDetailScreen> createState() => _CostDetailScreenState();
}

class _CostDetailScreenState extends State<CostDetailScreen> {
  String? _shopId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _expenses = [];
  bool _isDateClosed = false; 

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    
    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    var query = Supabase.instance.client
        .from('expense_logs_view') 
        .select('*') 
        .eq('shop_id', _shopId!);

    bool isClosed = false;

    if (widget.transactionId != null) {
      // --- 情況 A: 查看「已關帳」的班次 ---
      query = query.eq('transaction_id', widget.transactionId!);
      isClosed = true; 
      
    } else if (widget.openId != null) {
      // --- 情況 B: 查看「未關帳」的細項 (來自 Daily Cost 頁面) ---
      query = query.eq('open_id', widget.openId!); 
      isClosed = false;

    } else {
      // --- 情況 C: 來自 CostReport 的「未關帳」卡片 ---
      final targetDateStr = widget.targetDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      query = query
          .eq('expense_date', targetDateStr)
          .filter('transaction_id', 'is', 'null'); 
          
      isClosed = false; 
    }

    final res = await query.order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _expenses = List<Map<String, dynamic>>.from(res);
        _isDateClosed = isClosed; 
        _isLoading = false;
      });
    }
  }
  
  Future<void> _showNoticeDialog(String title, String content) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _NoticeDialog(title: title, content: content),
    );
  }

  Future<void> _saveEditedExpense(String id, String category, String item, String amountStr) async {
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
          })
          .eq('id', id);
      
      await _fetchExpenses(); 
    } catch (e) {
      _showNoticeDialog(l10n.costDetailErrorUpdate, e.toString()); 
    }
  }

  Future<void> _deleteExpense(String id) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Supabase.instance.client
          .from('expense_logs')
          .delete()
          .eq('id', id);
      
      await _fetchExpenses(); 
    } catch (e) {
      _showNoticeDialog(l10n.costDetailErrorDelete, e.toString()); 
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

    if (result == 'delete') {
      await _showDeleteDialog(expense);
    } 
    else if (result is Map<String, dynamic>) {
      await _saveEditedExpense(
        expense['id'],
        result['category'],
        result['name'],
        result['price'],
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildHeader(context, l10n.costDetailTitle), 
        body: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildHeader(context, l10n.costDetailTitle),
      body: SafeArea(
        child: _expenses.isEmpty
            ? Center(child: Text(l10n.costDetailNoRecords, style: TextStyle(color: colorScheme.onSurface))) 
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _expenses.length,
                itemBuilder: (context, index) {
                  final expense = _expenses[index];
                  return _CostCard(
                    expense: expense,
                    onEdit: _isDateClosed ? null : () => _showEditDialog(expense),
                    onDelete: _isDateClosed ? null : () => _showDeleteDialog(expense),
                  );
                },
              ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 自訂 Widget (Header, Card, Dialogs)
// -------------------------------------------------------------------

PreferredSizeWidget _buildHeader(BuildContext context, String title) {
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
            const SizedBox(width: 58), 
          ],
        ),
      ),
    ),
  );
}

class _CostCard extends StatelessWidget {
  final Map<String, dynamic> expense;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CostCard({required this.expense, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final title = expense['item_name'] ?? l10n.costDetailItemUntitled;
    final category = expense['category'] ?? l10n.costDetailCategoryNA;
    final buyer = expense['operator_name'] ?? l10n.costDetailBuyerNA;
    final amount = (expense['amount'] as num? ?? 0.0).toStringAsFixed(0);
    final timestamp = DateTime.tryParse(expense['created_at'])?.toLocal() ?? DateTime.now();
    
    final bool isDisabled = (onEdit == null || onDelete == null);

    return Container(
      height: 120,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$ $amount',
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    DateFormat('HH:mm').format(timestamp),
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
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
                      l10n.costDetailLabelCategory(category),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.costDetailLabelBuyer(buyer),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isDisabled) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onEdit,
                  child: Icon(
                    CupertinoIcons.pencil, 
                    color: colorScheme.onSurface, 
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8), 
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onDelete,
                  child: Icon(
                    CupertinoIcons.trash, 
                    color: colorScheme.onSurface, 
                    size: 22,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EditCostDialog extends StatefulWidget {
  final Map<String, dynamic> expense;
  const _EditCostDialog({required this.expense});

  @override
  State<_EditCostDialog> createState() => _EditCostDialogState();
}

class _EditCostDialogState extends State<_EditCostDialog> {
  String? _selectedCategory; 
  late final TextEditingController _itemController;
  late final TextEditingController _amountController;
  
  List<String> _categories = []; 
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _itemController = TextEditingController(text: widget.expense['item_name']);
    _amountController = TextEditingController(text: (widget.expense['amount'] as num? ?? 0).toStringAsFixed(0));
    _selectedCategory = widget.expense['category'];
    
    _fetchCategories();
  }
  
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
            
            if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
              _categories.insert(0, _selectedCategory!);
            } else if (_categories.isEmpty) {
              _categories = AppConstants.expenseCategories;
            }
            
            _selectedCategory ??= _categories.first;
            _loadingCategories = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }

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
    super.dispose();
  }

  void _onSave() {
    Navigator.of(context).pop({
      'category': _selectedCategory,
      'name': _itemController.text.trim(),
      'price': _amountController.text.trim(),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.costDetailEditTitle, 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            
            _loadingCategories 
                ? CupertinoActivityIndicator(color: colorScheme.onSurface)
                : _WhiteDropdown(
                    value: _selectedCategory ?? '',
                    onChanged: (val) => setState(() => _selectedCategory = val!),
                    items: _categories, 
                  ),
            
            const SizedBox(height: 12),
            SizedBox(
              height: 54, 
              child: TextFormField(
                controller: _itemController,
                decoration: _buildInputDecoration(context, hintText: l10n.costInputLabelName),
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
                decoration: _buildInputDecoration(context, hintText: l10n.costInputLabelPrice),
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
              l10n.costDetailDeleteTitle, 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.costDetailDeleteContent(expenseName),
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
  
  const _DialogWhiteButton({required this.text, this.onPressed});
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
          backgroundColor: theme.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: EdgeInsets.zero,
        ),
        child: Text(text, style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _TextCancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _TextCancelButton({required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextButton(
      onPressed: onPressed,
      child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
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
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null, 
          hint: Text(value.isEmpty ? l10n.costInputLoadingCategories : value, style: TextStyle(color: colorScheme.onPrimary)), 
          isExpanded: true,
          icon: Icon(CupertinoIcons.chevron_down, color: colorScheme.onPrimary),
          style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          dropdownColor: theme.primaryColor, 
        ),
      ),
    );
  }
}