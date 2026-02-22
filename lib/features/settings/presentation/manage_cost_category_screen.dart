// lib/features/settings/presentation/manage_cost_category_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart'; 
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 2. ManageCostCategoryScreen (主頁面)
// -------------------------------------------------------------------
class ManageCostCategoryScreen extends StatefulWidget {
  const ManageCostCategoryScreen({super.key});

  @override
  State<ManageCostCategoryScreen> createState() => _ManageCostCategoryScreenState();
}

class _ManageCostCategoryScreenState extends State<ManageCostCategoryScreen> {
  String? _shopId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  bool _isEditing = false; 

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');

    if (_shopId == null) {
      if (mounted) context.pop();
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('expense_categories')
          .select('id, name, type, sort_order') 
          .eq('shop_id', _shopId!)
          .order('type') 
          .order('sort_order', ascending: true);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showNoticeDialog(l10n.costCategoryNoticeErrorTitle, l10n.costCategoryNoticeErrorLoad); 
      }
    }
  }

  void _reorderCategories(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });
    
    _updateCategorySortOrder();
  }

  Future<void> _updateCategorySortOrder() async {
    final updates = _categories.mapIndexed((index, category) {
      return {'id': category['id'], 'sort_order': index};
    }).toList();

    try {
      await Supabase.instance.client
          .from('expense_categories')
          .upsert(updates); 
    } catch (e) {
      debugPrint('Error updating sort order: $e');
    }
  }

  // --- 新增類別 ---
  Future<void> _showAddCategoryDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    String selectedType = 'COGS'; 

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _CategoryDialog(
        title: l10n.costCategoryAddTitle,
        nameController: nameController,
        initialType: selectedType,
      ),
    );

    if (result != null && result['name']!.isNotEmpty) {
      await _saveCategoryToDb(result['name']!.trim(), result['type']!);
    }
  }

  Future<void> _saveCategoryToDb(String name, String type) async {
    try {
      await Supabase.instance.client.from('expense_categories').insert({
        'shop_id': _shopId,
        'name': name,
        'type': type,
        'sort_order': _categories.length, 
      });
      _fetchCategories(); 
    } catch (e) {
      debugPrint('Error adding category: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showNoticeDialog(l10n.costCategoryNoticeErrorTitle, l10n.costCategoryNoticeErrorAdd);
      }
    }
  }

  // --- 編輯類別 ---
  Future<void> _showEditCategoryDialog(Map<String, dynamic> category) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: category['name']);
    
    // 使用新的通用 Dialog，傳入目前的 Type
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _CategoryDialog(
        title: l10n.costCategoryEditTitle,
        nameController: nameController,
        initialType: category['type'] ?? 'COGS', 
      ),
    );

    // 檢查是否有變更
    if (result != null && result['name']!.isNotEmpty) {
      final newName = result['name']!.trim();
      final newType = result['type']!;

      if (newName != category['name'] || newType != category['type']) {
        await _updateCategoryInDb(category['id'], newName, newType);
      }
    }
  }

  // 更新 DB (包含 type)
  Future<void> _updateCategoryInDb(String id, String newName, String newType) async {
    try {
      await Supabase.instance.client
          .from('expense_categories')
          .update({
            'name': newName,
            'type': newType,
          })
          .eq('id', id);
      _fetchCategories(); 
    } catch (e) {
      debugPrint('Error updating category: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showNoticeDialog(l10n.costCategoryNoticeErrorTitle, l10n.costCategoryNoticeErrorUpdate);
      }
    }
  }

  // --- 刪除類別 ---
  Future<void> _showDeleteConfirmationDialog(Map<String, dynamic> category) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteCategoryConfirmationDialog(categoryName: category['name']),
    );

    if (result == true) {
      await _deleteCategoryFromDb(category['id']);
    }
  }

  Future<void> _deleteCategoryFromDb(String id) async {
    try {
      await Supabase.instance.client
          .from('expense_categories')
          .delete()
          .eq('id', id);
      _fetchCategories();
    } catch (e) {
      debugPrint('Error deleting category: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showNoticeDialog(l10n.costCategoryNoticeErrorTitle, l10n.costCategoryNoticeErrorDelete);
      }
    }
  }
  
  Future<void> _showNoticeDialog(String title, String content) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (_) => _NoticeDialog(
        title: title,
        content: content,
        okButtonText: l10n.commonOK,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
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
                    l10n.costCategoryTitle, 
                    textAlign: TextAlign.center,
                    style: AppTextStyles.settingsPageTitle.copyWith(color: colorScheme.onSurface),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    _isEditing ? CupertinoIcons.check_mark : CupertinoIcons.pencil,
                    color: colorScheme.onSurface,
                    size: 30,
                  ),
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing; 
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
          : SingleChildScrollView( 
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        Flexible( 
                          fit: FlexFit.loose,
                          child: ReorderableListView.builder(
                            padding: EdgeInsets.zero, 
                            shrinkWrap: true, 
                            physics: const ClampingScrollPhysics(), 
                            itemCount: _categories.length,
                            onReorder: _reorderCategories,
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final isLastItem = index == _categories.length - 1;

                              return _CategoryListItem( 
                                key: ValueKey(category['id']), 
                                category: category,
                                isEditing: _isEditing,
                                onTap: _isEditing 
                                    ? () => _showEditCategoryDialog(category) 
                                    : () {}, 
                                onDelete: () => _showDeleteConfirmationDialog(category), 
                                isLastItem: isLastItem, 
                              );
                            },
                          ),
                        ),
                        if (!_isEditing) 
                          _AddCategoryButton(onPressed: _showAddCategoryDialog),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 自訂 Widget：列表項目 & 按鈕
// -------------------------------------------------------------------

class _CategoryListItem extends StatelessWidget {
  final Map<String, dynamic> category;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isLastItem; 

  const _CategoryListItem({
    super.key,
    required this.category,
    required this.isEditing,
    required this.onTap,
    required this.onDelete,
    required this.isLastItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque, // 確保點擊整行都有效
          child: Container(
            color: theme.cardColor, 
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            child: Row(
              children: [
                if (isEditing)
                  GestureDetector(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Icon(
                        CupertinoIcons.minus_circle_fill,
                        color: colorScheme.error,
                        size: 24,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    category['name'],
                    style: AppTextStyles.settingsListItem.copyWith(color: colorScheme.onSurface),
                  ),
                ),
                
                // Requirement 1: 顯示 Type 標籤 (COGS / OPEX)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.transparent, 
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category['type'] ?? '',
                    style: TextStyle(
                      color: Colors.grey, // 使用淺灰色區分
                      fontSize: 12, 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                if (isEditing) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    CupertinoIcons.line_horizontal_3,
                    color: Colors.grey,
                    size: 22,
                  )
                ]
              ],
            ),
          ),
        ),
        if (!isLastItem) 
          Padding(
            padding: EdgeInsets.only(left: isEditing ? 56.0 : 20.0), 
            child: Divider(
              height: 1.0,
              thickness: 1.0,
              color: theme.dividerColor,
            ),
          ),
      ],
    );
  }
}

class _AddCategoryButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddCategoryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: theme.cardColor, 
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.add,
              color: colorScheme.onSurface,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.costCategoryAddButton, 
              style: AppTextStyles.settingsListItem.copyWith(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Dialogs ---

class _CategoryDialog extends StatefulWidget {
  final String title;
  final TextEditingController nameController;
  final String initialType;

  const _CategoryDialog({
    required this.title,
    required this.nameController,
    required this.initialType,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late String _currentSelectedType;

  @override
  void initState() {
    super.initState();
    _currentSelectedType = widget.initialType;
  }
  
  InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
      final theme = Theme.of(context);
      return InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
        filled: true,
        fillColor: theme.scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      );
    }

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
              widget.title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            
            // 類型選擇器
            CupertinoSegmentedControl<String>(
              groupValue: _currentSelectedType,
              unselectedColor: theme.cardColor, 
              selectedColor: colorScheme.primary, 
              borderColor: colorScheme.primary, 
              padding: EdgeInsets.zero,
              children: {
                'COGS': Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    l10n.costCategoryTypeCOGS, 
                    style: TextStyle(
                      color: _currentSelectedType == 'COGS' ? colorScheme.onPrimary : colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ),
                'OPEX': Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    l10n.costCategoryTypeOPEX, 
                    style: TextStyle(
                      color: _currentSelectedType == 'OPEX' ? colorScheme.onPrimary : colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ),
              },
              onValueChanged: (value) {
                setState(() => _currentSelectedType = value);
              },
            ),
            
            const SizedBox(height: 20),
            TextField(
              controller: widget.nameController,
              decoration: _buildInputDecoration(hintText: l10n.costCategoryHintName, context: context), 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              textAlignVertical: TextAlignVertical.center,
            ),
            const SizedBox(height: 30),
            _DialogButtons(
              cancelText: l10n.commonCancel, 
              onCancel: () => Navigator.of(context).pop(null),
              confirmText: l10n.commonSave, 
              // 回傳 Map 包含 Name 和 Type
              onConfirm: () => Navigator.of(context).pop({
                'name': widget.nameController.text,
                'type': _currentSelectedType,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButtons extends StatelessWidget {
  final String cancelText;
  final VoidCallback onCancel;
  final String confirmText;
  final VoidCallback onConfirm;
  final Color? confirmButtonColor;

  const _DialogButtons({
    required this.cancelText,
    required this.onCancel,
    required this.confirmText,
    required this.onConfirm,
    this.confirmButtonColor, 
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DialogWhiteButton(
          text: cancelText,
          onPressed: onCancel,
          buttonWidth: 109.6, 
        ),
        const SizedBox(width: 20),
        _DialogWhiteButton(
          text: confirmText,
          onPressed: onConfirm,
          buttonColor: confirmButtonColor ?? colorScheme.primary, 
          textColor: confirmButtonColor == null ? colorScheme.onPrimary : Colors.white,
          buttonWidth: 109.6,
        ),
      ],
    );
  }
}

class _DialogWhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? buttonColor;
  final Color? textColor;
  final double buttonWidth;

  const _DialogWhiteButton({
    required this.text,
    this.onPressed,
    this.buttonColor,
    this.textColor,
    this.buttonWidth = 109.6, 
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: buttonWidth,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor ?? theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: EdgeInsets.zero, 
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor ?? colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DeleteCategoryConfirmationDialog extends StatelessWidget {
  final String categoryName;

  const _DeleteCategoryConfirmationDialog({required this.categoryName});

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
              l10n.costCategoryDeleteTitle(categoryName), 
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.costCategoryDeleteContent, 
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _DialogButtons(
              cancelText: l10n.commonCancel, 
              onCancel: () => Navigator.of(context).pop(false),
              confirmText: l10n.commonDelete, 
              onConfirm: () => Navigator.of(context).pop(true),
              confirmButtonColor: colorScheme.error, 
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeDialog extends StatelessWidget {
  final String title;
  final String content;
  final String okButtonText;

  const _NoticeDialog({
    required this.title,
    required this.content,
    required this.okButtonText,
  });

  @override
  Widget build(BuildContext context) {
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
              text: okButtonText,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  Iterable<E> mapIndexed<E>(E Function(int index, T item) f) sync* {
    var index = 0;
    for (final item in this) {
      yield f(index++, item);
    }
  }
}