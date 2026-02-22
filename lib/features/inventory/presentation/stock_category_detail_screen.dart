// lib/features/inventory/presentation/stock_category_detail_screen.dart
// ✅ 已修正 'const' 錯誤並加入了必要的輔助元件

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 輔助元件 (UI 樣式與輔助類別)
// -------------------------------------------------------------------

// 1. 列表卡片元件
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

// 2. 刪除 Dialog
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
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16))), // 'Cancel'
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
// 主頁面：庫存品項列表 (StockCategoryDetailScreen)
// -------------------------------------------------------------------

class StockCategoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> category;

  const StockCategoryDetailScreen({
    super.key,
    required this.category,
  });

  @override
  State<StockCategoryDetailScreen> createState() => _StockCategoryDetailScreenState();
}

class _StockCategoryDetailScreenState extends State<StockCategoryDetailScreen> {
  List<Map<String, dynamic>> items = [];
  bool isEditing = false;
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
    
    final res = await Supabase.instance.client
        .from('stock_items')
        .select()
        .eq('category_id', widget.category['id'])
        .eq('shop_id', shopId!)
        .order('sort_order', ascending: true);
        
    setState(() {
      items = List<Map<String, dynamic>>.from(res);
    });
  }

  Future<void> _saveOrder() async {
    for (int i = 0; i < items.length; i++) {
      final id = items[i]['id'];
      await Supabase.instance.client
          .from('stock_items')
          .update({'sort_order': i})
          .eq('id', id);
    }
  }

  Future<void> _confirmDeleteItem(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final item = items[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog( 
        title: l10n.stockItemDetailDeleteTitle, 
        content: l10n.stockItemDetailDeleteContent(item['title'] ?? 'N/A'), 
      ),
    );

    if (confirm == true) {
      final id = items[index]['id'];
      await Supabase.instance.client
          .from('stock_items')
          .delete()
          .eq('id', id);
      await _loadItems();
    }
  }

  void _goToEditItem({Map<String, dynamic>? item}) {
    context.push(
      '/addStockItem', // 導航到 AddStockItemScreen
      extra: {
        'categoryId': widget.category['id'],
        'categoryName': widget.category['name'],
        'itemId': item?['id'],
        'initialData': item,
      },
    ).then((_) => _loadItems());
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
          widget.category['name'] ?? l10n.stockCategoryDetailItemTitle,
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
                          setState(() {});
                          await _saveOrder();
                        },
                        children: items.asMap().entries.map<Widget>((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Column(
                            key: ValueKey(item['id']),
                            children: [
                              _CustomTile( 
                                title: item['title'] ?? 'N/A',
                                isEditing: true,
                                reorderIndex: index,
                                onDelete: () => _confirmDeleteItem(index),
                                onEdit: () => _goToEditItem(item: item),
                                onTap: () => _goToEditItem(item: item),
                              ),
                              if (index < items.length - 1)
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
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final item = items[index];
                          return Column(
                            children: [
                              _CustomTile( 
                                title: item['title'] ?? 'N/A',
                                isEditing: false,
                                onTap: () => _goToEditItem(item: item),
                              ),
                              if (index < items.length - 1)
                                Padding( 
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: theme.dividerColor, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        },
                      ),
                
                if (items.isNotEmpty)
                  Padding( 
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(color: theme.dividerColor, height: 1, thickness: 0.5),
                  ),
                
                CupertinoButton(
                  onPressed: () => _goToEditItem(), // 新增品項
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text( 
                    l10n.stockCategoryDetailAddItemButton, 
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