// lib/features/settings/presentation/edit_stock_list_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart'; // 需要 Uuid 來新增品項
import 'package:gallery205_staff_app/l10n/app_localizations.dart'; // [新增] 引入多語言

// UI 顏色和樣式定義 (匹配 Figma)
// UI 顏色和樣式定義 (匹配 Figma)
// Note: _AppColors removed, using Theme.of(context) instead.

// 輔助方法：統一輸入框樣式
InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
    return InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
        filled: false,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10), 
        isDense: true,
    );
}

class _LabeledInput extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledInput({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Text(
            "$label：",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 1. 庫存類別列表頁面 (EditStockListScreen)
// -------------------------------------------------------------------

class EditStockListScreen extends StatefulWidget {
  const EditStockListScreen({super.key});

  @override
  State<EditStockListScreen> createState() => _EditStockListScreenState();
}

class _EditStockListScreenState extends State<EditStockListScreen> {
  bool isEditing = false;
  List<Map<String, dynamic>> categories = [];
  String? shopId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final res = await Supabase.instance.client
        .from('inventory_categories')
        .select()
        .eq('shop_id', shopId!)
        .order('sort_order', ascending: true);
        
    setState(() {
      categories = List<Map<String, dynamic>>.from(res);
    });
  }
  
  Future<void> _addCategory() async {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => _AddEditDialog(
        title: l10n.inventoryCategoryAddDialogTitle, // 'Add New Category'
        hintText: l10n.inventoryCategoryHintName, // 'Category Name'
        existingNames: categories.map((c) => c['name'] as String).toList(),
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (shopId == null) return;
      await Supabase.instance.client
          .from('inventory_categories')
          .insert({
            'name': result,
            'shop_id': shopId,
            'sort_order': categories.length,
          });
      _loadCategories();
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => _AddEditDialog(
        title: l10n.inventoryCategoryEditDialogTitle, // 'Edit Category'
        hintText: l10n.inventoryCategoryHintName, // 'Category Name'
        initialName: category['name'],
        existingNames: categories.map((c) => c['name'] as String).toList(),
      ),
    );

    if (result != null && result.isNotEmpty && result != category['name']) {
      await Supabase.instance.client
          .from('inventory_categories')
          .update({'name': result})
          .eq('id', category['id']);
      _loadCategories();
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        title: l10n.inventoryCategoryDeleteTitle, // 'Delete Category'
        content: l10n.inventoryCategoryDeleteContent(category['name']), // 'Are you sure to delete Category: ${category['name']}?'
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client
          .from('inventory_categories')
          .delete()
          .eq('id', category['id']);
      _loadCategories();
    }
  }
  
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    
    // 1. 更新本地狀態
    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);
    setState(() {});

    // 2. 更新 Supabase
    for (int i = 0; i < categories.length; i++) {
      await Supabase.instance.client
          .from('inventory_categories')
          .update({'sort_order': i})
          .eq('id', categories[i]['id']);
    }
  }

  void _navigateToCategoryDetail(Map<String, dynamic> category) {
    context.push('/editStockCategoryDetail', extra: category)
      .then((_) => _loadCategories());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // --- 內容區 (ListView) ---
          ListView(
            padding: EdgeInsets.only(top: safeAreaTop + 60, left: 16, right: 16, bottom: 40), 
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    isEditing
                        ? ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            onReorder: _onReorder,
                            children: categories.asMap().entries.map<Widget>((entry) {
                              final i = entry.key;
                              final category = entry.value;
                              return Column(
                                key: ValueKey(category['id']),
                                children: [
                                  _CustomTile(
                                    title: category['name'],
                                    isEditing: true,
                                    reorderIndex: i,
                                    onDelete: () => _deleteCategory(category),
                                    onEdit: () => _editCategory(category),
                                    onTap: () => _navigateToCategoryDetail(category),
                                  ),
                                   if (i < categories.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Divider(color: colorScheme.onSurface.withOpacity(0.2), height: 1, thickness: 0.5),
                                    )
                                ],
                              );
                            }).toList(),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: categories.length,
                            itemBuilder: (_, index) {
                              final category = categories[index];
                              return Column(
                                children: [
                                  _CustomTile(
                                    title: category['name'],
                                    isEditing: false,
                                    onTap: () => _navigateToCategoryDetail(category),
                                  ),
                                  if (index < categories.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Divider(color: colorScheme.onSurface.withOpacity(0.2), height: 1, thickness: 0.5),
                                    )
                                ],
                              );
                            },
                          ),
                    
                    if (categories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Divider(color: Theme.of(context).dividerColor, height: 1, thickness: 0.5),
                      ),
                    
                    CupertinoButton(
                      onPressed: _addCategory,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        l10n.inventoryCategoryAddButton, // '＋ Add New Category'
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

          // --- 頂部標題和按鈕 (固定) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: EdgeInsets.only(top: safeAreaTop, bottom: 10, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_left),
                    color: colorScheme.onSurface,
                    iconSize: 30,
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      l10n.inventoryCategoryTitle, // 'Edit Stock List'
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.03,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => isEditing = !isEditing),
                    child: Icon(
                      isEditing ? CupertinoIcons.check_mark_circled : CupertinoIcons.pencil, 
                      color: colorScheme.onSurface, 
                      size: 30
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 2. 庫存品項列表頁面 (EditStockCategoryDetailScreen)
// -------------------------------------------------------------------

class EditStockCategoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> category; // 接收整個 category map
  const EditStockCategoryDetailScreen({super.key, required this.category});

  @override
  State<EditStockCategoryDetailScreen> createState() => _EditStockCategoryDetailScreenState();
}

class _EditStockCategoryDetailScreenState extends State<EditStockCategoryDetailScreen> {
  bool isEditing = false;
  List<Map<String, dynamic>> items = [];
  String? shopId;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final categoryId = widget.category['id'];

    final itemRes = await Supabase.instance.client
        .from('inventory_items')
        .select()
        .eq('category_id', categoryId)
        .eq('shop_id', shopId!)
        .order('sort_order', ascending: true); // Corrected: removed extra parenthesis

    setState(() {
      items = List<Map<String, dynamic>>.from(itemRes);
    });
  }


  Future<void> _saveOrder() async {
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      await Supabase.instance.client
          .from('inventory_items')
          .update({'sort_order': i})
          .eq('id', item['id']);
    }
  }


  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        title: l10n.inventoryItemDeleteTitle, // 'Delete Product'
        content: l10n.inventoryItemDeleteContent(item['name']), // 'Are you sure to delete ${item['name']}?'
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client
          .from('inventory_items')
          .delete()
          .eq('id', item['id']);
      await _loadItems();
    }
  }


  Future<void> _editItem(Map<String, dynamic> item) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _AddEditStockItemDialog(
        isEditing: true,
        item: item,
      ),
    );

    if (result != null) {
      await Supabase.instance.client
          .from('inventory_items')
          .update(result)
          .eq('id', item['id']);
      await _loadItems();
    }
  }


  Future<void> _addItem() async {
    if (shopId == null) return;
    final categoryId = widget.category['id'];

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _AddEditStockItemDialog(
        isEditing: false,
      ),
    );
    
    if (result != null) {
      final newItem = {
        ...result,
        'id': const Uuid().v4(),
        'category_id': categoryId,
        'shop_id': shopId,
        'sort_order': items.length,
      };

      await Supabase.instance.client
          .from('inventory_items')
          .insert(newItem);

      await _loadItems();
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // --- 內容區 (ListView) ---
          ListView(
            padding: EdgeInsets.only(top: safeAreaTop + 60, left: 16, right: 16, bottom: 40), 
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    // 列表
                    isEditing
                        ? ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            onReorder: (oldIndex, newIndex) async {
                              if (newIndex > oldIndex) newIndex--;
                              final item = items.removeAt(oldIndex);
                              items.insert(newIndex, item);
                              await _saveOrder();
                              setState(() {});
                            },
                            children: items.asMap().entries.map<Widget>((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return Column(
                                key: ValueKey(item['id']),
                                children: [
                                  _CustomTile(
                                    title: item['name'],
                                    isEditing: true,
                                    reorderIndex: index,
                                    onDelete: () => _deleteItem(item),
                                    onEdit: () => _editItem(item),
                                  ),
                                  if (index < items.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Divider(color: colorScheme.onSurface.withOpacity(0.2), height: 1, thickness: 0.5),
                                    )
                                ],
                              );
                            }).toList(),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: items.length,
                            itemBuilder: (_, index) {
                              final item = items[index];
                              return Column(
                                children: [
                                  _CustomTile(
                                    title: item['name'],
                                    isEditing: false,
                                    onTap: () => _editItem(item), // 正常模式點擊也是編輯
                                  ),
                                  if (index < items.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Divider(color: colorScheme.onSurface.withOpacity(0.2), height: 1, thickness: 0.5),
                                    )
                                ],
                              );
                            },
                          ),
                    
                    // ＋ Add New Product (移入卡片內部)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Divider(color: Theme.of(context).dividerColor, height: 1, thickness: 0.5),
                    ),
                    
                    CupertinoButton(
                      onPressed: _addItem,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        l10n.inventoryItemAddButton, // '＋ Add New Product'
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
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


          // --- 頂部標題和返回按鈕 (固定) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: EdgeInsets.only(top: safeAreaTop, bottom: 10, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_left),
                    color: colorScheme.onSurface,
                    iconSize: 30,
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.category['name'] ?? l10n.inventoryCategoryDetailTitle, // 顯示類別名稱
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.03,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => isEditing = !isEditing),
                    child: Icon(
                      isEditing ? CupertinoIcons.check_mark_circled : CupertinoIcons.pencil, 
                      color: colorScheme.onSurface, 
                      size: 30
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 區域/桌位卡片元件 (_CustomTile) - (Figma: Zone 1 / Product 1)
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
    if (isEditing) {
      // 編輯模式
      return Container(
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                ),
              ),
            ),
            // 排序手柄
            if (reorderIndex != null) // 僅在需要排序時顯示
              ReorderableDragStartListener(
                index: reorderIndex!, 
                  child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(CupertinoIcons.bars, color: Colors.grey),
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Icon(CupertinoIcons.chevron_right, color: Theme.of(context).colorScheme.onSurface, size: 20),
          ],
        ),
      );
    }
  }
}


// -------------------------------------------------------------------
// 4. 輔助 Dialog 類別 (新增/編輯 類別)
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
      return; 
    }
    
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final isEditMode = widget.initialName != null;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: controller,
              decoration: _buildInputDecoration(hintText: widget.hintText, context: context),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null), 
                  child: Text(l10n.commonCancel, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)) // 'Cancel'
                ),
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor, 
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                    ),
                    child: Text(
                      isEditMode ? l10n.commonSave : l10n.commonAdd, // 'Save' : 'Add'
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)
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
// 5. 輔助 Dialog 類別 (刪除確認)
// -------------------------------------------------------------------

class _DeleteDialog extends StatelessWidget {
  final String title;
  final String content;

  const _DeleteDialog({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 183, 
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, 
          borderRadius: BorderRadius.circular(25), 
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 標題
            Text(
              title, 
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500)
            ),
            
            // 內容
            Text(
              content, 
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)
            ),
            
            // 按鈕區塊
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16))), // 'Cancel'
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor, 
                      foregroundColor: Theme.of(context).colorScheme.onPrimary, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(l10n.commonDelete, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), // 'Delete'
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
// 6. 輔助 Dialog 類別 (新增/編輯 庫存品項) (Figma: Add New Product)
// -------------------------------------------------------------------

class _AddEditStockItemDialog extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? item;

  const _AddEditStockItemDialog({
    required this.isEditing,
    this.item,
  });

  @override
  State<_AddEditStockItemDialog> createState() => _AddEditStockItemDialogState();
}

class _AddEditStockItemDialogState extends State<_AddEditStockItemDialog> {
  late final TextEditingController nameController;
  late final TextEditingController unitController;
  late final TextEditingController stockController;
  late final TextEditingController parController;
  late final TextEditingController contentPerUnitController;
  late final TextEditingController contentUnitController;

  @override
  void initState() {
    super.initState();
    final currentStock = (widget.item?['current_stock'] as num?)?.toDouble() ?? 0;
    final parLevel = (widget.item?['par_level'] as num?)?.toDouble() ?? 0;
    final contentPerUnit = (widget.item?['content_per_unit'] as num?)?.toDouble() ?? 1.0;
    final contentUnit = widget.item?['content_unit'] as String? ?? '';

    nameController = TextEditingController(text: widget.item?['name'] ?? '');
    unitController = TextEditingController(text: widget.item?['unit_label'] ?? widget.item?['unit'] ?? '');
    stockController = TextEditingController(text: currentStock.toString());
    parController = TextEditingController(text: (widget.item?['par_level'] as num? ?? widget.item?['low_stock_threshold'] as num? ?? 0).toString());
    contentPerUnitController = TextEditingController(text: contentPerUnit.toString());
    contentUnitController = TextEditingController(text: contentUnit);
  }

  @override
  void dispose() {
    nameController.dispose();
    unitController.dispose();
    stockController.dispose();
    parController.dispose();
    contentPerUnitController.dispose();
    contentUnitController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();
    final unit = unitController.text.trim();
    final stock = double.tryParse(stockController.text.trim()) ?? 0.0;
    final par = double.tryParse(parController.text.trim()) ?? 0.0;
    final contentPerUnit = double.tryParse(contentPerUnitController.text.trim()) ?? 1.0;
    final contentUnit = contentUnitController.text.trim();
    
    if (name.isEmpty || unit.isEmpty) {
      // 可以在此顯示 SnackBar
      return;
    }

    final updateData = {
      'name': name,
      'unit': unit, // Legacy field support
      'unit_label': unit, // Also write to unit_label for consistency
      'current_stock': stock,
      'par_level': par, // Legacy support
      'low_stock_threshold': par, // New field support
      'content_per_unit': contentPerUnit,
      'content_unit': contentUnit.isEmpty ? null : contentUnit,
    };
    
    Navigator.of(context).pop(updateData);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(
              widget.isEditing ? l10n.inventoryItemEditDialogTitle : l10n.inventoryItemAddDialogTitle, // 'Edit Product' : 'Add New Product'
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 20),
            
            _LabeledInput(
              label: l10n.inventoryItemHintName,
              child: TextFormField(
                controller: nameController,
                decoration: _buildInputDecoration(hintText: '', context: context),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            _LabeledInput(
              label: l10n.inventoryItemHintUnit,
              child: TextFormField(
                controller: unitController,
                decoration: _buildInputDecoration(hintText: '', context: context),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            _LabeledInput(
              label: l10n.inventoryItemHintStock,
              child: TextFormField(
                controller: stockController,
                decoration: _buildInputDecoration(hintText: '', context: context),
                keyboardType: TextInputType.number,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            _LabeledInput(
              label: l10n.inventoryItemHintPar,
              child: TextFormField(
                controller: parController,
                decoration: _buildInputDecoration(hintText: '', context: context),
                keyboardType: TextInputType.number,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Unit Conversion Fields
            _LabeledInput(
               label: "每單位含量",
               child: Row(
               children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: contentPerUnitController,
                    decoration: _buildInputDecoration(hintText: '', context: context),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                  ),
                ),
                const Text(" "),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: contentUnitController,
                    decoration: _buildInputDecoration(hintText: '單位', context: context),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                  ),
                ),
               ],
              ),
            ),
            // Helper text
             Padding(
               padding: const EdgeInsets.only(top: 4, left: 4),
               child: Align(
                 alignment: Alignment.centerLeft,
                 child: Text(
                    "例如: 1 瓶 (Unit) = 700 ml (Content)",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                 ),
               ),
             ),
            
            const SizedBox(height: 30),

            // 按鈕區塊
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null), 
                  child: Text(l10n.commonCancel, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)) // 'Cancel'
                ),
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                    ),
                    child: Text(widget.isEditing ? l10n.commonSave : l10n.commonAdd, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)), // 'Save' : 'Add'
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}