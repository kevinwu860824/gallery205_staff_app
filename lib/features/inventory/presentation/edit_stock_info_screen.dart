// lib/features/inventory/presentation/edit_stock_info_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// 輔助方法：統一輸入框樣式
InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
    final theme = Theme.of(context);
    return InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
        filled: true,
        fillColor: theme.scaffoldBackgroundColor, // Use scaffold background for contrast within cards/dialogs
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25), // 高度圓角
            borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
    );
}

// -------------------------------------------------------------------
// 1. 備料類別列表頁面 (EditStockInfoScreen)
// -------------------------------------------------------------------

class EditStockInfoScreen extends StatefulWidget {
  const EditStockInfoScreen({super.key});

  @override
  State<EditStockInfoScreen> createState() => _EditStockInfoScreenState();
}

class _EditStockInfoScreenState extends State<EditStockInfoScreen> {
  bool isEditing = false;
  Map<String, Map<String, dynamic>> categoriesByName = {};
  List<String> sortedCategoryNames = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    final res = await Supabase.instance.client
        .from('stock_categories')
        .select()
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);

    final map = <String, Map<String, dynamic>>{};
    final names = <String>[];

    for (final row in res) {
      final name = row['name'] as String;
      map[name] = {
        'id': row['id'],
        'name': name,
        'sort_order': row['sort_order'],
      };
      names.add(name);
    }

    setState(() {
      categoriesByName = map;
      sortedCategoryNames = names;
    });
  }

  Future<void> _addCategory() async {
    final l10n = AppLocalizations.of(context)!;
    // ✅ [修正] 使用自訂 Dialog
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddEditDialog(
        title: l10n.stockCategoryAddDialogTitle, 
        hintText: l10n.stockCategoryHintName, 
        existingNames: categoriesByName.keys.toList(),
      ),
    );

    if (name != null && name.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      final id = const Uuid().v4();
      final sortOrder = sortedCategoryNames.length;

      await Supabase.instance.client.from('stock_categories').insert({
        'id': id,
        'shop_id': shopId,
        'name': name,
        'sort_order': sortOrder,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _loadCategories();
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final l10n = AppLocalizations.of(context)!;
    // ✅ [新增] 編輯 Dialog
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _AddEditDialog(
        title: l10n.stockCategoryEditDialogTitle, 
        hintText: l10n.stockCategoryHintName, 
        initialName: category['name'],
        existingNames: categoriesByName.keys.toList(),
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != category['name']) {
      await Supabase.instance.client
          .from('stock_categories')
          .update({'name': newName})
          .eq('id', category['id']);
      await _loadCategories();
    }
  }

  Future<void> _deleteCategory(String category) async {
    final l10n = AppLocalizations.of(context)!;
    // ✅ [修正] 使用自訂 Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        title: l10n.stockCategoryDeleteTitle, 
        content: l10n.stockCategoryDeleteContent(category), 
      ),
    );

    if (confirm == true) {
      final id = categoriesByName[category]?['id'];
      if (id != null) {
        await Supabase.instance.client
            .from('stock_categories')
            .delete()
            .eq('id', id);
        await _loadCategories();
      }
    }
  }

  void _navigateToCategoryDetail(String categoryName) {
    final category = categoriesByName[categoryName];
    if (category == null) return;

    // 將整個 category Map 傳遞下去
    context.push(
      '/stockCategoryDetail',
      extra: category, // 傳遞 Map
    ).then((_) => _loadCategories());
  }

  Future<void> _updateCategoryOrder() async {
    for (int i = 0; i < sortedCategoryNames.length; i++) {
      final name = sortedCategoryNames[i];
      final id = categoriesByName[name]?['id'];
      if (id != null) {
        await Supabase.instance.client
            .from('stock_categories')
            .update({'sort_order': i})
            .eq('id', id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.stockCategoryTitle,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isEditing ? CupertinoIcons.check_mark_circled : CupertinoIcons.pencil,
              color: colorScheme.onSurface,
              size: 28,
            ),
            onPressed: () => setState(() => isEditing = !isEditing),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                isEditing
                    ? ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex--;
                          final moved = sortedCategoryNames.removeAt(oldIndex);
                          sortedCategoryNames.insert(newIndex, moved);
                          setState(() {});
                          await _updateCategoryOrder();
                        },
                        children: sortedCategoryNames.asMap().entries.map<Widget>((entry) {
                          final i = entry.key;
                          final categoryName = entry.value;
                          final category = categoriesByName[categoryName]!;
                          return Column(
                            key: ValueKey(category['id']),
                            children: [
                              _CustomTile(
                                title: categoryName,
                                isEditing: true,
                                reorderIndex: i,
                                onDelete: () => _deleteCategory(categoryName),
                                onEdit: () => _editCategory(category),
                                onTap: () => _navigateToCategoryDetail(categoryName),
                              ),
                              if (i < sortedCategoryNames.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: theme.dividerColor, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        }).toList(),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: sortedCategoryNames.length,
                        itemBuilder: (_, index) {
                          final categoryName = sortedCategoryNames[index];
                          return Column(
                            children: [
                              _CustomTile(
                                title: categoryName,
                                isEditing: false,
                                onTap: () => _navigateToCategoryDetail(categoryName),
                              ),
                              if (index < sortedCategoryNames.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: theme.dividerColor, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        },
                      ),
                
                if (sortedCategoryNames.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(color: theme.dividerColor, height: 1, thickness: 0.5),
                  ),
                
                CupertinoButton(
                  onPressed: _addCategory,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    l10n.stockCategoryAddButton, 
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
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
// 2. 列表卡片元件 (_CustomTile)
// -------------------------------------------------------------------

class _CustomTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool isEditing;
  final int? reorderIndex;

  const _CustomTile({
    required this.title,
    required this.isEditing,
    this.onTap,
    this.onDelete,
    this.onEdit,
    this.reorderIndex,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (isEditing) {
      // 編輯模式
      return Container(
        key: key, // 確保 ReorderableListView 正常工作
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 刪除按鈕
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
              onPressed: onDelete,
            ),
            const SizedBox(width: 10),
            // 名稱 (點擊編輯)
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: onEdit, 
                child: Text(
                  title,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
              ),
            ),
            // 排序手柄
            if (reorderIndex != null) // 僅在需要排序時顯示
              ReorderableDragStartListener(
                index: reorderIndex!, 
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(CupertinoIcons.bars, color: colorScheme.onSurface),
                ),
              ),
          ],
        ),
      );
    } else {
      // 正常模式
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
        onPressed: onTap, // 正常模式點擊是進入下一頁
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface, size: 20),
          ],
        ),
      );
    }
  }
}

// -------------------------------------------------------------------
// 3. 輔助 Dialog 類別 (新增/編輯)
// -------------------------------------------------------------------

class _AddEditDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String? initialName;
  final List<String> existingNames;

  const _AddEditDialog({
    required this.title,
    required this.hintText,
    required this.existingNames,
    this.initialName,
  });

  @override
  State<_AddEditDialog> createState() => _AddEditDialogState();
}

class _AddEditDialogState extends State<_AddEditDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    if (widget.initialName == null && widget.existingNames.contains(name)) {
      // 可以在這裡顯示錯誤訊息
      return; 
    }
    
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditMode = widget.initialName != null;
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
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: controller,
              decoration: _buildInputDecoration(hintText: widget.hintText, context: context),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null), 
                  child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16))
                ),
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary, 
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                    ),
                    child: Text(
                      isEditMode ? l10n.commonSave : l10n.commonAdd, 
                      style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 4. 輔助 Dialog 類別 (刪除確認)
// -------------------------------------------------------------------

class _DeleteDialog extends StatelessWidget {
  final String title;
  final String content;

  const _DeleteDialog({required this.title, required this.content});

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
        height: 183, 
        decoration: BoxDecoration(
          color: theme.cardColor, 
          borderRadius: BorderRadius.circular(25), 
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 標題
            Text(
              title, 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500)
            ),
            
            // 內容
            Text(
              content, 
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16)
            ),
            
            // 按鈕區塊
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16))), 
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error, 
                      foregroundColor: colorScheme.onError, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(l10n.commonDelete, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}