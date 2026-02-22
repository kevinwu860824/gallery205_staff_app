// lib/features/settings/presentation/edit_menu_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // 引入 Material 以使用 CheckboxListTile, Dialog 等
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/menu_item_recipe.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:gallery205_staff_app/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_category.dart';

// -------------------------------------------------------------------
// 1. 主菜單編輯頁面 (EditMenuScreen)
// -------------------------------------------------------------------

class EditMenuScreen extends StatefulWidget {
  const EditMenuScreen({super.key});

  @override
  State<EditMenuScreen> createState() => _EditMenuScreenState();
}

class _EditMenuScreenState extends State<EditMenuScreen> {
  bool isEditing = false;
  
  // 存放菜單類別資料
  List<Map<String, dynamic>> categoriesData = [];
  
  // 存放所有的出單工作站 (Print Categories)
  List<Map<String, dynamic>> printCategories = [];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final prefs = await SharedPreferences.getInstance();
    final shopCode = prefs.getString('savedShopCode');
    if (shopCode == null) return;

    final shopRes = await Supabase.instance.client
        .from('shops')
        .select('id')
        .eq('code', shopCode)
        .maybeSingle();

    if (shopRes == null) return;
    final shopId = shopRes['id'];

    // 1. 先抓取出單工作站列表 (用於新增/編輯時的選項)
    final printCatRes = await Supabase.instance.client
        .from('print_categories')
        .select()
        .eq('shop_id', shopId);

    // 2. 抓取菜單類別 (包含 target_print_category_ids)
    final categoryRes = await Supabase.instance.client
        .from('menu_categories')
        .select() 
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);

    List<Map<String, dynamic>> tempData = [];

    for (final category in categoryRes) {
      final categoryId = category['id'] as String;
      
      // 3. 抓取該類別下的品項 (僅用於顯示數量或預覽，實際編輯在子頁面)
      final itemRes = await Supabase.instance.client
          .from('menu_items')
          .select()
          .eq('category_id', categoryId)
          .eq('shop_id', shopId)
          .order('sort_order', ascending: true);

      // 手動構建 map 以確保型別安全並加入 items
      Map<String, dynamic> categoryMap = Map<String, dynamic>.from(category);
      categoryMap['items'] = List<Map<String, dynamic>>.from(itemRes);
      
      tempData.add(categoryMap);
    }

    if (mounted) {
      setState(() {
        printCategories = List<Map<String, dynamic>>.from(printCatRes);
        categoriesData = tempData;
      });
    }
  }
  
  Future<void> _addCategory() async {
    final l10n = AppLocalizations.of(context)!;
    // 開啟新增視窗，傳入現有名稱(查重用)與工作站列表
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _AddEditCategoryDialog(
        isEditing: false, 
        existingCategories: categoriesData.map((e) => e['name'] as String).toList(),
        availablePrintCategories: printCategories, 
      ),
    );

    if (result != null) {
      final name = result['name'];
      final targetIds = result['target_print_category_ids'];

      final prefs = await SharedPreferences.getInstance();
      final shopCode = prefs.getString('savedShopCode');
      if (shopCode == null) return;

      final shopRes = await Supabase.instance.client
          .from('shops')
          .select('id')
          .eq('code', shopCode)
          .maybeSingle();

      if (shopRes == null) return;
      final shopId = shopRes['id'];

      final maxOrder = categoriesData.length;

      // 寫入資料庫
      await Supabase.instance.client
          .from('menu_categories')
          .insert({
            'name': name,
            'sort_order': maxOrder,
            'shop_id': shopId,
            'target_print_category_ids': targetIds, // 儲存出單設定
          });

      _loadMenu();
    }
  }

  Future<void> _editCategoryName(Map<String, dynamic> categoryData) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _AddEditCategoryDialog(
        isEditing: true,
        initialName: categoryData['name'],
        initialTargetIds: List<String>.from(categoryData['target_print_category_ids'] ?? []),
        existingCategories: categoriesData.map((e) => e['name'] as String).toList(),
        availablePrintCategories: printCategories,
      ),
    );

    if (result != null) {
      await Supabase.instance.client
          .from('menu_categories')
          .update({
            'name': result['name'],
            'target_print_category_ids': result['target_print_category_ids'],
          })
          .eq('id', categoryData['id']);
      
      _loadMenu();
    }
  }

  Future<void> _deleteCategory(String categoryName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        title: l10n.menuDeleteCategoryTitle, 
        content: l10n.menuDeleteCategoryContent(categoryName),
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      final shopCode = prefs.getString('savedShopCode');
      if (shopCode == null) return;
      final shopRes = await Supabase.instance.client.from('shops').select('id').eq('code', shopCode).maybeSingle();
      if (shopRes == null) return;
      final shopId = shopRes['id'];
      
      final categoryRes = await Supabase.instance.client
          .from('menu_categories')
          .select('id')
          .eq('name', categoryName)
          .eq('shop_id', shopId) 
          .maybeSingle();
          
      if (categoryRes != null) {
        final categoryId = categoryRes['id'];
        await Supabase.instance.client.from('menu_categories').delete().eq('id', categoryId);
        _loadMenu();
      }
    }
  }

  void _navigateToCategoryDetail(String id, String name) {
    context.push(
      '/editMenuDetail', 
      // 傳遞 category info 以及 printCategories 避免重複讀取
      extra: {'id': id, 'name': name, 'printCategories': printCategories} 
    ).then((_) => _loadMenu());
  }

  Future<void> _toggleCategoryVisibility(String id, bool currentStatus) async {
    try {
      await Supabase.instance.client
          .from('menu_categories')
          .update({'is_visible': !currentStatus})
          .eq('id', id);
      
      // Update local state without full reload for speed
      setState(() {
        final index = categoriesData.indexWhere((element) => element['id'] == id);
        if (index != -1) {
          categoriesData[index]['is_visible'] = !currentStatus;
        }
      });
    } catch (e) {
      debugPrint('Error toggling visibility: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.menuEditTitle,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: () => setState(() => isEditing = !isEditing),
            child: Icon(
              isEditing ? CupertinoIcons.check_mark_circled : CupertinoIcons.pencil, 
              color: colorScheme.onSurface, 
              size: 24,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), 
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
                            final item = categoriesData.removeAt(oldIndex);
                            categoriesData.insert(newIndex, item);
                            setState(() {});
                            
                            // 更新排序到資料庫
                            for (int i = 0; i < categoriesData.length; i++) {
                                await Supabase.instance.client
                                    .from('menu_categories')
                                    .update({'sort_order': i})
                                    .eq('id', categoriesData[i]['id']);
                            }
                        },
                        children: List.generate(categoriesData.length, (index) {
                            final category = categoriesData[index];
                            return Column(
                                key: ValueKey(category['id']),
                                children: [
                                    _CategoryTile(
                                        category: category['name'],
                                        onDelete: () => _deleteCategory(category['name']),
                                        onEdit: () => _editCategoryName(category),
                                        onTap: () => _navigateToCategoryDetail(category['id'], category['name']),
                                        isEditing: true,
                                        reorderIndex: index,
                                    ),
                                    if (index < categoriesData.length - 1)
                                        Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                            child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                                        )
                                ],
                            );
                        }),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: categoriesData.length,
                        itemBuilder: (_, index) {
                          final category = categoriesData[index];
                          return Column(
                            children: [
                                _CategoryTile(
                                key: ValueKey(category['id']),
                                category: category['name'],
                                onTap: () => _navigateToCategoryDetail(category['id'], category['name']),
                                isEditing: false,
                                isVisible: category['is_visible'] == true, // Default true if null
                                onToggle: (val) => _toggleCategoryVisibility(category['id'], category['is_visible'] ?? true),
                              ),
                              if (index < categoriesData.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        },
                      ),
                
                if (categoriesData.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                  ),
                
                CupertinoButton(
                  onPressed: _addCategory,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    l10n.menuCategoryAddButton,
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
// 2. 獨立的卡片元件 (_CategoryTile)
// -------------------------------------------------------------------

class _CategoryTile extends StatelessWidget {
  final String category;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool isEditing;
  final int? reorderIndex;
  
  // NEW: Visibility Toggle
  final bool isVisible;
  final ValueChanged<bool>? onToggle;

  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.isEditing,
    this.onDelete,
    this.onEdit,
    this.reorderIndex,
    this.isVisible = true,
    this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (isEditing) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
              onPressed: onDelete,
            ),
            const SizedBox(width: 10),
            // ✅ 使用 Expanded 與 ellipsis 防止爆版
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: onEdit,
                child: Text(
                  category,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
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
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ✅ 使用 Expanded 與 ellipsis 防止爆版
            Expanded(
              child: Row(
                children: [
                  Text(
                    category, 
                    style: TextStyle(
                      color: isVisible ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.5), 
                      fontSize: 16, 
                      fontWeight: FontWeight.w500
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (!isVisible)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text("隱藏", style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.6))),
                      ),
                    ),
                ],
              ),
            ),
            
            // Toggle Switch
            Transform.scale(
              scale: 0.8,
              child: CupertinoSwitch(
                value: isVisible,
                onChanged: onToggle,
                activeColor: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),

            Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface, size: 20),
          ],
        ),
      );
    }
  }
}

// -------------------------------------------------------------------
// 3. 品項編輯頁面 (MenuCategoryDetailScreen)
// -------------------------------------------------------------------

class MenuCategoryDetailScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  // 可選參數，如果從上一頁傳來就不用重新抓取
  final List<Map<String, dynamic>>? printCategories; 

  const MenuCategoryDetailScreen({
    super.key, 
    required this.categoryId, 
    required this.categoryName,
    this.printCategories,
  });

  @override
  State<MenuCategoryDetailScreen> createState() => _MenuCategoryDetailScreenState();
}

class _MenuCategoryDetailScreenState extends State<MenuCategoryDetailScreen> {
  bool isEditing = false;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> availablePrintCategories = [];

  @override
  void initState() {
    super.initState();
    availablePrintCategories = widget.printCategories ?? [];
    _initData();
  }

  Future<void> _initData() async {
    // 如果沒有從外部傳入 printCategories，則自己抓取
    if (availablePrintCategories.isEmpty) {
       final prefs = await SharedPreferences.getInstance();
       final shopCode = prefs.getString('savedShopCode');
       if (shopCode != null) {
          final shopRes = await Supabase.instance.client.from('shops').select('id').eq('code', shopCode).maybeSingle();
          if (shopRes != null) {
             final pcRes = await Supabase.instance.client.from('print_categories').select().eq('shop_id', shopRes['id']);
             if (mounted) {
               setState(() {
                 availablePrintCategories = List<Map<String, dynamic>>.from(pcRes);
               });
             }
          }
       }
    }
    await _loadItems();
  }

  Future<void> _loadItems() async {
    final itemRes = await Supabase.instance.client
        .from('menu_items')
        .select() // select all 包含 target_print_category_ids
        .eq('category_id', widget.categoryId)
        .order('sort_order', ascending: true);

    setState(() {
      items = List<Map<String, dynamic>>.from(itemRes);
    });
  }

  Future<void> _addItem() async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final shopCode = prefs.getString('savedShopCode');
    if (shopCode == null) return;

    final shopRes = await Supabase.instance.client.from('shops').select('id').eq('code', shopCode).maybeSingle();
    if (shopRes == null) return;
    final shopId = shopRes['id'];

    // 開啟新增 Dialog
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _AddEditItemDialog(
        isEditing: false,
        availablePrintCategories: availablePrintCategories,
      ),
    );
    
    if (result != null) {
      final newItem = {
        'name': result['name'], // Only take primitive fields for main table
        'price': result['price'],
        'market_price': result['market_price'],
        'target_print_category_ids': result['target_print_category_ids'],
        'category_id': widget.categoryId,
        'shop_id': shopId,
        'sort_order': items.length,
      };

      try {
        // 1. Insert Menu Item
        final List<dynamic> res = await Supabase.instance.client
            .from('menu_items')
            .insert(newItem)
            .select('id');
        
        final newId = res.first['id'] as String;

        // 2. Insert Modifier Links
        final modifierIds = result['modifier_group_ids'] as List<String>?;
        if (modifierIds != null && modifierIds.isNotEmpty) {
           final links = modifierIds.map((gid) => {
             'menu_item_id': newId,
             'modifier_group_id': gid,
           }).toList();
           await Supabase.instance.client.from('menu_item_modifier_groups').insert(links);
        }

        // 3. Insert Recipes
        final recipes = result['recipes'] as List<MenuItemRecipe>?;
        if (recipes != null && recipes.isNotEmpty) {
           final repo = InventoryRepositoryImpl(Supabase.instance.client);
           for (final r in recipes) {
             // Create new recipe object with correct menu_item_id
             final newRecipe = MenuItemRecipe(
               id: '', 
               menuItemId: newId, 
               inventoryItemId: r.inventoryItemId, 
               quantityRequired: r.quantityRequired
             );
             await repo.saveRecipe(newRecipe, shopId);
           }
        }

        await _loadItems();
      } catch (e) {
        debugPrint('Add item error: $e');
      }
    }
  }

  Future<void> _saveOrder() async {
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      await Supabase.instance.client
          .from('menu_items')
          .update({'sort_order': i})
          .eq('id', item['id']);
    }
  }

  Future<void> _deleteItem(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final item = items[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        title: l10n.menuItemEditDialogTitle,
        content: l10n.menuDeleteCategoryContent(item['name']),
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('menu_items').delete().eq('id', item['id']);
      await _loadItems();
    }
  }

  Future<void> _toggleItemVisibility(String id, bool currentStatus) async {
    try {
      await Supabase.instance.client
          .from('menu_items')
          .update({'is_visible': !currentStatus})
          .eq('id', id);
      
      setState(() {
         final index = items.indexWhere((e) => e['id'] == id);
         if (index != -1) {
           items[index]['is_visible'] = !currentStatus;
         }
      });
    } catch (e) {
       debugPrint('Toggle Item Visi Error: $e');
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    // 開啟編輯 Dialog
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _AddEditItemDialog(
        isEditing: true,
        item: item,
        availablePrintCategories: availablePrintCategories,
      ),
    );

    if (result != null) {
      // 1. Update Menu Item
      final updateData = {
        'name': result['name'],
        'price': result['price'],
        'market_price': result['market_price'],
        'target_print_category_ids': result['target_print_category_ids'],
      };
      
      await Supabase.instance.client
          .from('menu_items')
          .update(updateData)
          .eq('id', item['id']);

      // 2. Update Modifier Links (Delete all + Insert new)
      final modifierIds = result['modifier_group_ids'] as List<String>?;
      if (modifierIds != null) {
         // A. Clean up old links
         await Supabase.instance.client
            .from('menu_item_modifier_groups')
            .delete()
            .eq('menu_item_id', item['id']);

         // B. Insert new links
         if (modifierIds.isNotEmpty) {
           final links = modifierIds.map((gid) => {
             'menu_item_id': item['id'],
             'modifier_group_id': gid,
           }).toList();
           await Supabase.instance.client.from('menu_item_modifier_groups').insert(links);
         }
      }

      // 3. Update Recipes (Delete All + Insert New)
      final recipes = result['recipes'] as List<MenuItemRecipe>?;
      if (recipes != null) {
         final repo = InventoryRepositoryImpl(Supabase.instance.client);
         final shopRes = await Supabase.instance.client.from('shops').select('id').eq('code', (await SharedPreferences.getInstance()).getString('savedShopCode') ?? '').maybeSingle();
         final shopId = shopRes?['id'] as String? ?? '';
         
         // Delete all existing recipes for this item
         // Since Repo doesn't have deleteAll, use direct client or delete one by one?
         // Direct client is better for batch delete
         await Supabase.instance.client.from('menu_item_recipes').delete().eq('menu_item_id', item['id']);
         
         // Insert new
         for (final r in recipes) {
           final newRecipe = MenuItemRecipe(
             id: '', 
             menuItemId: item['id'], 
             inventoryItemId: r.inventoryItemId, 
             quantityRequired: r.quantityRequired
           );
           await repo.saveRecipe(newRecipe, shopId);
         }
      }

      await _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.categoryName,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: () => setState(() => isEditing = !isEditing),
            child: Icon(
              isEditing ? CupertinoIcons.check_mark_circled : CupertinoIcons.pencil, 
              color: colorScheme.onSurface, 
              size: 24,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), 
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
                          final item = items.removeAt(oldIndex);
                          items.insert(newIndex, item);
                          await _saveOrder();
                          setState(() {});
                        },
                        children: List.generate(items.length, (index) {
                          final item = items[index];
                          final name = item['name'];
                          final label = item['market_price'] == true 
                            ? l10n.menuItemLabelMarketPrice 
                            : l10n.menuItemLabelPrice(item['price'].toString());

                          return Column(
                            key: ValueKey(item['id']),
                            children: [
                              _ItemTile(
                                title: name,
                                subtitle: label,
                                isEditing: true,
                                reorderIndex: index,
                                onDelete: () => _deleteItem(index),
                                onEdit: () => _editItem(item),
                              ),
                              if (index < items.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        }),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final item = items[index];
                          final name = item['name'];
                          final label = item['market_price'] == true 
                            ? l10n.menuItemLabelMarketPrice 
                            : l10n.menuItemLabelPrice(item['price'].toString());
                            
                          return Column(
                            children: [
                              _ItemTile(
                                title: name,
                                subtitle: label,
                                isEditing: false,
                                isVisible: item['is_visible'] == true, // default true
                                onToggle: (val) => _toggleItemVisibility(item['id'], item['is_visible'] ?? true),
                                onEdit: () => _editItem(item),
                              ),
                              if (index < items.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        },
                      ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                  ),
                
                CupertinoButton(
                  onPressed: _addItem,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    l10n.menuDetailAddItemButton,
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
// 4. 品項列表元件 (_ItemTile)
// -------------------------------------------------------------------

class _ItemTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isEditing;
  final int? reorderIndex;
  
  // NEW: Visibility Toggle
  final bool isVisible;
  final ValueChanged<bool>? onToggle;

  const _ItemTile({
    required this.title,
    required this.subtitle,
    required this.isEditing,
    this.onEdit,
    this.onDelete,
    this.reorderIndex,
    this.isVisible = true,
    this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (isEditing) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
              onPressed: onDelete,
            ),
            const SizedBox(width: 10),
            // ✅ 使用 Expanded 與 ellipsis 防止爆版
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: onEdit, 
                child: Text(
                  title,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
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
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
        onPressed: onEdit,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                   Expanded(
                     child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title, 
                                style: TextStyle(
                                  color: isVisible ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.5),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isVisible)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text("隱藏", style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.6))),
                                ),
                              ),
                          ],
                        ),
                        if (subtitle.isNotEmpty) 
                          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                     ),
                   ),
                ],
              ),
            ),
            
             // Toggle Switch
            Transform.scale(
              scale: 0.8,
              child: CupertinoSwitch(
                value: isVisible,
                onChanged: onToggle,
                activeColor: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),

            Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface, size: 20),
          ],
        ),
      );
    }
  }
}


// -------------------------------------------------------------------
// 5. 輔助 Dialog 類別 (新增/編輯類別)
// -------------------------------------------------------------------

class _AddEditCategoryDialog extends StatefulWidget {
  final bool isEditing;
  final String? initialName;
  final List<String>? initialTargetIds;
  final List<String> existingCategories;
  final List<Map<String, dynamic>> availablePrintCategories;

  const _AddEditCategoryDialog({
    required this.isEditing,
    required this.existingCategories,
    required this.availablePrintCategories,
    this.initialName,
    this.initialTargetIds,
  });

  @override
  State<_AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends State<_AddEditCategoryDialog> {
  late final TextEditingController controller;
  List<String> selectedPrintCategoryIds = [];

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialName);
    selectedPrintCategoryIds = widget.initialTargetIds ?? [];
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final name = controller.text.trim();
    if (name.isEmpty) return;

    if (!widget.isEditing && widget.existingCategories.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.commonNameExists)));
      return; 
    }
    
    // 回傳 Map 包含名稱和出單設定
    Navigator.of(context).pop({
      'name': name,
      'target_print_category_ids': selectedPrintCategoryIds,
    });
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditMode = widget.isEditing;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(25)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Text(isEditMode ? l10n.menuCategoryEditDialogTitle : l10n.menuCategoryAddDialogTitle, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500))),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: controller,
              decoration: _buildInputDecoration(hintText: l10n.menuCategoryHintName, context: context),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // 出單工作站多選列表
            if (widget.availablePrintCategories.isNotEmpty) ...[
              const Text("預設出單工作站:", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                height: 150, // 限制高度
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: widget.availablePrintCategories.map((pc) {
                    final id = pc['id'] as String;
                    final name = pc['name'] as String;
                    final isChecked = selectedPrintCategoryIds.contains(id);
                    return CheckboxListTile(
                      title: Text(name, style: TextStyle(color: colorScheme.onSurface, fontSize: 14), overflow: TextOverflow.ellipsis),
                      value: isChecked,
                      activeColor: colorScheme.primary,
                      checkColor: colorScheme.onPrimary,
                      dense: true,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedPrintCategoryIds.add(id);
                          } else {
                            selectedPrintCategoryIds.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16))),
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    child: Text(isEditMode ? l10n.commonSave : l10n.commonAdd, style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
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
// 6. 輔助 Dialog 類別 (刪除確認)
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
        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(25)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500)),
            Text(content, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16))),
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), padding: EdgeInsets.zero),
                    child: Text(l10n.commonDelete, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
// 7. 輔助 Dialog 類別 (新增/編輯品項)
// -------------------------------------------------------------------

// -------------------------------------------------------------------
// 7. 輔助 Dialog 類別 (新增/編輯品項)
// -------------------------------------------------------------------

class _AddEditItemDialog extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> availablePrintCategories;

  const _AddEditItemDialog({
    required this.isEditing,
    this.item,
    this.availablePrintCategories = const [],
  });

  @override
  State<_AddEditItemDialog> createState() => _AddEditItemDialogState();
}

class _AddEditItemDialogState extends State<_AddEditItemDialog> {
  late final TextEditingController nameController;
  late final TextEditingController priceController;
  late bool isMarketPrice;
  List<String> selectedPrintCategoryIds = [];
  
  // Modifiers state
  List<Map<String, dynamic>> availableModifierGroups = [];
  List<String> selectedModifierGroupIds = [];
  bool isLoadingModifiers = true;

  // Recipe State
  List<MenuItemRecipe> recipes = []; // Current recipes being edited
  List<InventoryItem> allInventoryItems = []; // For selection
  bool isLoadingRecipes = true;
  final _repo = InventoryRepositoryImpl(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.item?['name'] ?? '');
    priceController = TextEditingController(text: widget.item?['price']?.toString() ?? '');
    isMarketPrice = widget.item?['market_price'] ?? false;
    selectedPrintCategoryIds = List<String>.from(widget.item?['target_print_category_ids'] ?? []);
    
    
    _loadModifierGroups();
    _loadRecipesAndInventory();
  }

  Future<void> _loadRecipesAndInventory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopCode = prefs.getString('savedShopCode');
      if (shopCode != null) {
         final shopRes = await Supabase.instance.client.from('shops').select('id').eq('code', shopCode).maybeSingle();
         if (shopRes != null) {
            final shopId = shopRes['id'] as String;
            final invItems = await _repo.getItems(shopId);
            
            List<MenuItemRecipe> loadedRecipes = [];
            if (widget.isEditing && widget.item != null) {
               final rawRecipes = await _repo.getRecipesForMenuItem(widget.item!['id']);
               loadedRecipes = List<MenuItemRecipe>.from(rawRecipes);
            }

            if (mounted) {
               setState(() {
                 allInventoryItems = List<InventoryItem>.from(invItems);
                 recipes = loadedRecipes;
                 isLoadingRecipes = false;
               });
            }
         }
      }
    } catch (e) {
      debugPrint("Load recipes error: $e");
      if (mounted) setState(() => isLoadingRecipes = false);
    }
  }

  Future<void> _loadModifierGroups() async {
     try {
       final prefs = await SharedPreferences.getInstance();
       final shopCode = prefs.getString('savedShopCode');
       if (shopCode != null) {
          final shopRes = await Supabase.instance.client.from('shops').select('id').eq('code', shopCode).maybeSingle();
          if (shopRes != null) {
             final shopId = shopRes['id'];
             
             // 1. Fetch all groups
             final groupsRes = await Supabase.instance.client
                 .from('modifier_groups')
                 .select('id, name')
                 .eq('shop_id', shopId)
                 .order('sort_order', ascending: true);
             
             List<String> linkedIds = [];
             // 2. If editing, fetch existing links
             if (widget.isEditing && widget.item != null) {
                final linksRes = await Supabase.instance.client
                   .from('menu_item_modifier_groups')
                   .select('modifier_group_id')
                   .eq('menu_item_id', widget.item!['id']);
                
                linkedIds = List<String>.from(linksRes.map((e) => e['modifier_group_id']));
             }

             if (mounted) {
               setState(() {
                 availableModifierGroups = List<Map<String, dynamic>>.from(groupsRes);
                 selectedModifierGroupIds = linkedIds;
                 isLoadingModifiers = false;
               });
             }
          }
       }
     } catch (e) {
       debugPrint("Load modifiers error: $e");
       if (mounted) setState(() => isLoadingModifiers = false);
     }
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text);
    
    if (name.isEmpty) return;
    if (!isMarketPrice && price == null) return;

    // 1. Prepare item data
    final updateData = {
      'name': name,
      'market_price': isMarketPrice,
      if (!isMarketPrice) 'price': price,
      'target_print_category_ids': selectedPrintCategoryIds,
    };
    
    // We can't update join table here directly if we are "Adding" because we don't have ID yet.
    // So we pass the modifier data back to parent
    updateData['modifier_group_ids'] = selectedModifierGroupIds; // Custom key for parent to handle
    
    // We pass the modifier data back to parent
    updateData['modifier_group_ids'] = selectedModifierGroupIds; 
    
    // Pass recipe data back
    updateData['recipes'] = recipes;

    Navigator.of(context).pop(updateData);
  }

  void _addRecipe() async {
    // Show dialog to select inventory item
    final InventoryItem? selected = await showDialog<InventoryItem>(
      context: context,
      builder: (ctx) => _InventorySelectionDialog(items: allInventoryItems),
    );

    if (selected != null) {
      // Check if already exists to pre-fill
      final existingIdx = recipes.indexWhere((r) => r.inventoryItemId == selected.id);
      final initialQty = existingIdx != -1 ? recipes[existingIdx].quantityRequired : null;

      // Ask for quantity
      final qtyStr = await showDialog<String>(
        context: context,
        builder: (ctx) => _QuantityInputDialog(item: selected, initialValue: initialQty),
      );
      
      if (qtyStr != null) {
        final qty = double.tryParse(qtyStr) ?? 0;
        if (qty > 0) {
          setState(() {
            // Check if already exists, update if so
            final idx = recipes.indexWhere((r) => r.inventoryItemId == selected.id);
            if (idx != -1) {
              recipes[idx] = MenuItemRecipe(
                id: recipes[idx].id, 
                menuItemId: widget.item?['id'] ?? '', 
                inventoryItemId: selected.id, 
                quantityRequired: qty,
                inventoryItem: selected,
              );
            } else {
              recipes.add(MenuItemRecipe(
                id: '', // New
                menuItemId: widget.item?['id'] ?? '', 
                inventoryItemId: selected.id, 
                quantityRequired: qty,
                inventoryItem: selected,
              ));
            }
          });
        }
      }
    }
  }

  void _removeRecipe(int index) {
    setState(() {
      recipes.removeAt(index);
    });
  }

  void _editRecipe(int index) async {
    final r = recipes[index];
    final item = allInventoryItems.firstWhere((i) => i.id == r.inventoryItemId, orElse: () => InventoryItem(id: '', shopId: '', name: 'Unknown', totalUnits: 1, currentStock: 0, unitLabel: ''));
    
    final qtyStr = await showDialog<String>(
      context: context,
      builder: (ctx) => _QuantityInputDialog(item: item, initialValue: r.quantityRequired),
    );

    if (qtyStr != null) {
        final qty = double.tryParse(qtyStr) ?? 0;
        if (qty > 0) {
          setState(() {
            recipes[index] = MenuItemRecipe(
              id: r.id, 
              menuItemId: r.menuItemId, 
              inventoryItemId: r.inventoryItemId, 
              quantityRequired: qty,
              inventoryItem: item,
            );
          });
        }
    }
  }
  
  // Custom helper to build decoration
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditMode = widget.isEditing;
    
    return DefaultTabController(
      length: 2,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          // constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(25)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(isEditMode ? l10n.menuItemEditDialogTitle : l10n.menuItemAddDialogTitle, 
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)
                ),
              ),
              
              // Tabs
              TabBar(
                labelColor: colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: colorScheme.primary,
                tabs: const [
                  Tab(text: "基本設定"),
                  Tab(text: "庫存/配方"),
                ],
              ),
              
              // Content
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Basic Info
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: _buildInputDecoration(hintText: "品項名稱", context: context),
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.menuItemPriceLabel, 
                                  style: TextStyle(color: isMarketPrice ? Colors.grey : colorScheme.onSurface, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(l10n.menuItemMarketPrice, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
                                  const SizedBox(width: 4),
                                  CupertinoSwitch(
                                    value: isMarketPrice, 
                                    onChanged: (val) => setState(() => isMarketPrice = val), 
                                    activeColor: colorScheme.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!isMarketPrice)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: TextFormField(
                                controller: priceController,
                                decoration: _buildInputDecoration(hintText: l10n.menuItemHintPrice, context: context),
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                              ),
                            ),
                          
                          // Print Category
                          if (widget.availablePrintCategories.isNotEmpty) ...[
                             const SizedBox(height: 20),
                             const Text("指定出單工作站:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                             const SizedBox(height: 8),
                             Container(
                               height: 120, 
                               decoration: BoxDecoration(
                                 border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               child: ListView(
                                 shrinkWrap: true,
                                 children: widget.availablePrintCategories.map((pc) {
                                   final id = pc['id'] as String;
                                   final name = pc['name'] as String;
                                   return CheckboxListTile(
                                     title: Text(name, style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
                                     value: selectedPrintCategoryIds.contains(id),
                                     activeColor: colorScheme.primary,
                                     dense: true,
                                     onChanged: (val) {
                                       setState(() {
                                          if (val == true) selectedPrintCategoryIds.add(id);
                                          else selectedPrintCategoryIds.remove(id);
                                       });
                                     },
                                   );
                                 }).toList(),
                               ),
                             ),
                          ],
      
                          // Modifiers
                          const SizedBox(height: 20),
                          const Text("綁定配料群組:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(height: 8),
                          isLoadingModifiers 
                             ? const Center(child: CupertinoActivityIndicator())
                             : Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: availableModifierGroups.isEmpty 
                                    ? Center(child: Text("無配料群組", style: TextStyle(color: Colors.grey))) 
                                    : ListView(
                                        children: availableModifierGroups.map((group) {
                                          final id = group['id'] as String;
                                          final name = group['name'] as String;
                                          return CheckboxListTile(
                                            title: Text(name, style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
                                            value: selectedModifierGroupIds.contains(id),
                                            activeColor: colorScheme.primary,
                                            dense: true,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) selectedModifierGroupIds.add(id);
                                                else selectedModifierGroupIds.remove(id);
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                             ),
                        ],
                      ),
                    ),
                    
                    // Tab 2: Recipes
                    isLoadingRecipes
                        ? const Center(child: CupertinoActivityIndicator())
                        : Column(
                            children: [
                               Expanded(
                                 child: recipes.isEmpty
                                     ? Center(child: Text("尚未設定庫存配方", style: TextStyle(color: Colors.grey)))
                                     : ListView.separated(
                                         padding: const EdgeInsets.all(16),
                                         itemCount: recipes.length,
                                         separatorBuilder: (_, __) => const Divider(),
                                         itemBuilder: (ctx, idx) {
                                            final r = recipes[idx];
                                            final item = allInventoryItems.firstWhere((i) => i.id == r.inventoryItemId, orElse: () => InventoryItem(id: '', shopId: '', name: 'Unknown', totalUnits: 1, currentStock: 0, unitLabel: ''));
                                            return ListTile(
                                               title: Text(item.name),
                                               subtitle: Text("扣除: ${r.quantityRequired} ${item.unitLabel}"),
                                               trailing: Row(
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   IconButton(
                                                     icon: const Icon(Icons.settings, color: Colors.grey),
                                                     onPressed: () => _editRecipe(idx),
                                                   ),
                                                   IconButton(
                                                     icon: const Icon(Icons.delete, color: Colors.red),
                                                     onPressed: () => _removeRecipe(idx),
                                                   ),
                                                 ],
                                               ),
                                            );
                                         },
                                       ),
                               ),
                               Padding(
                                 padding: const EdgeInsets.all(16),
                                 child: ElevatedButton.icon(
                                   onPressed: _addRecipe, 
                                   icon: const Icon(Icons.add_link), 
                                   label: const Text("連結庫存品項"),
                                 ),
                               ),
                            ],
                          ),
                  ],
                ),
              ),

              // Footer Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                     TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(l10n.commonCancel)),
                     ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                           backgroundColor: colorScheme.primary, 
                           foregroundColor: colorScheme.onPrimary,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                        ),
                        child: Text(isEditMode ? l10n.commonSave : l10n.commonAdd),
                     ),
                   ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 8. 輔助 Dialog 類別 (庫存選擇)
// -------------------------------------------------------------------

class _InventorySelectionDialog extends StatefulWidget {
  final List<InventoryItem> items;
  const _InventorySelectionDialog({required this.items});

  @override
  State<_InventorySelectionDialog> createState() => _InventorySelectionDialogState();
}

class _InventorySelectionDialogState extends State<_InventorySelectionDialog> {
  String searchText = '';
  List<InventoryCategory> categories = [];
  String? selectedCategoryId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopCode = prefs.getString('savedShopCode');
      if (shopCode != null) {
         final shopRes = await Supabase.instance.client.from('shops').select('id').eq('code', shopCode).maybeSingle();
         if (shopRes != null) {
            final repo = InventoryRepositoryImpl(Supabase.instance.client);
            final cats = await repo.getCategories(shopRes['id']);
            if (mounted) {
              setState(() {
                categories = cats;
                isLoading = false;
              });
            }
         }
      }
    } catch(e) {
       if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var filtered = widget.items;
    
    // Category Filter
    if (selectedCategoryId != null) {
      filtered = filtered.where((i) => i.categoryId == selectedCategoryId).toList();
    }

    // Search Filter
    if (searchText.isNotEmpty) {
      filtered = filtered.where((i) => i.name.toLowerCase().contains(searchText.toLowerCase())).toList();
    }
    
    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       child: Container(
         width: 500, // Slightly wider
         height: 600,
         padding: const EdgeInsets.all(16),
         child: Column(
           children: [
             Text("選擇庫存品項", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 12),
             
             // Filters Row
             Row(
               children: [
                 // Category Dropdown
                 Expanded(
                   flex: 2,
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.shade400),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: DropdownButtonHideUnderline(
                       child: DropdownButton<String?>(
                         isExpanded: true,
                         value: selectedCategoryId,
                         hint: const Text("所有分類"),
                         items: [
                           const DropdownMenuItem(value: null, child: Text("所有分類")),
                           ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                         ],
                         onChanged: (val) => setState(() => selectedCategoryId = val),
                       ),
                     ),
                   ),
                 ),
                 const SizedBox(width: 8),
                 // Search
                 Expanded(
                   flex: 3,
                   child: TextField(
                     decoration: const InputDecoration(
                       hintText: "搜尋名稱...",
                       prefixIcon: Icon(Icons.search),
                       border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                       contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                     ),
                     onChanged: (val) => setState(() => searchText = val),
                   ),
                 ),
               ],
             ),
             
             const SizedBox(height: 12),
             Expanded(
               child: isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty 
                      ? const Center(child: Text("沒有符合的品項"))
                      : ListView.separated(
                         itemCount: filtered.length,
                         separatorBuilder: (_,__) => const Divider(height: 1),
                         itemBuilder: (ctx, idx) {
                           final item = filtered[idx];
                           return ListTile(
                             title: Text(item.name),
                             subtitle: Text("庫存: ${item.currentStock} ${item.unitLabel}"),
                             trailing: item.totalUnits > 1 ? Text("規格: ${item.totalUnits} ${item.unitLabel}") : null,
                             onTap: () => Navigator.pop(context, item),
                           );
                         },
                       ),
             ),
             TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
           ],
         ),
       ),
    );
  }
}

// -------------------------------------------------------------------
// 9. 輔助 Dialog 類別 (數量輸入)
// -------------------------------------------------------------------

class _QuantityInputDialog extends StatefulWidget {
  final InventoryItem item;
  final double? initialValue;
  const _QuantityInputDialog({required this.item, this.initialValue});
  
  @override
  State<_QuantityInputDialog> createState() => _QuantityInputDialogState();
}

class _QuantityInputDialogState extends State<_QuantityInputDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine display unit
    // If contentUnit is set (e.g. ml), use it. Else use item.unitLabel (e.g. Bottle).
    final hasContentUnit = widget.item.contentUnit != null && widget.item.contentUnit!.isNotEmpty;
    final displayUnit = hasContentUnit ? widget.item.contentUnit! : widget.item.unitLabel;
    final conversionText = hasContentUnit 
        ? "(1 ${widget.item.unitLabel} = ${widget.item.contentPerUnit} $displayUnit)"
        : "";

    return AlertDialog(
      title: const Text("輸入配方消耗量"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              suffixText: displayUnit,
              labelText: "製作一份消耗多少 $displayUnit?",
              hintText: "例如: 50",
            ),
            autofocus: true,
          ),
          if (hasContentUnit)
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Text(conversionText, style: const TextStyle(color: Colors.white70, fontSize: 13)),
             ),
          const SizedBox(height: 8),
          Text("庫存單位: ${widget.item.unitLabel}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
        ElevatedButton(
          onPressed: () {
            if (_ctrl.text.isNotEmpty) Navigator.pop(context, _ctrl.text);
          }, 
          child: const Text("確定")
        ),
      ],
    );
  }
}