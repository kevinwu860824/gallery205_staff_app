// lib/features/inventory/presentation/manage_inventory_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

// (假設您的 BorderedCupertinoButton 在 build 資料夾)
import '../../../build/bordered_cupertino_button.dart';
import './add_inventory_item_screen.dart';

class ManageInventoryDetailScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const ManageInventoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ManageInventoryDetailScreen> createState() => _ManageInventoryDetailScreenState();
}

class _ManageInventoryDetailScreenState extends State<ManageInventoryDetailScreen> {
  List<Map<String, dynamic>> items = [];
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    // ✅ 修正：讀取新的 'inventory_items' 表
    final res = await Supabase.instance.client
        .from('inventory_items')
        .select()
        .eq('category_id', widget.categoryId)
        .order('sort_order', ascending: true);

    setState(() {
      items = List<Map<String, dynamic>>.from(res);
    });
  }

  Future<void> _saveOrder() async {
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      // ✅ 修正：更新 'inventory_items' 表
      await Supabase.instance.client
          .from('inventory_items')
          .update({'sort_order': i})
          .eq('id', item['id']);
    }
  }

  Future<void> _confirmDeleteItem(int index) async {
    final item = items[index];
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('刪除原料品項'),
        content: Text('確定要刪除「${item['name']}」嗎？'),
        actions: [
          CupertinoDialogAction(child: const Text('取消'), onPressed: () => context.pop(false)),
          CupertinoDialogAction(isDestructiveAction: true, child: const Text('刪除'), onPressed: () => context.pop(true)),
        ],
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

  void _goToAddOrEditItem({Map<String, dynamic>? item}) {
    context.push(
      // ✅ 這是我們將在 app_router 註冊的新路徑
      '/addInventoryItem', 
      extra: {
        'categoryId': widget.categoryId,
        'categoryName': widget.categoryName,
        'itemId': item?['id'],
        'initialData': item,
      }
    ).then((_) => _loadItems());
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: '返回',
        middle: Text(widget.categoryName),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text(isEditing ? '完成' : '編輯'),
          onPressed: () => setState(() => isEditing = !isEditing),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text(''))
                  : isEditing
                      ? ReorderableListView(
                          onReorder: (oldIndex, newIndex) async {
                            if (newIndex > oldIndex) newIndex--;
                            final item = items.removeAt(oldIndex);
                            items.insert(newIndex, item);
                            setState(() {});
                            await _saveOrder();
                          },
                          children: List.generate(items.length, (index) {
                            final item = items[index];
                            final title = item['name'] ?? '未命名原料';
                            final currentStock = item['current_stock'] ?? 0;
                            final unit = item['unit'] ?? '';

                            return Container(
                              key: ValueKey(item['id']),
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              child: Row(
                                children: [
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
                                    onPressed: () => _confirmDeleteItem(index),
                                  ),
                                  Expanded(
                                    child: BorderedCupertinoButton(
                                      // 顯示庫存量
                                      text: '$title (${currentStock.toStringAsFixed(0)}$unit)', 
                                      onPressed: () => _goToAddOrEditItem(item: item),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6, right: 12),
                                    child: Icon(CupertinoIcons.bars, color: CupertinoColors.inactiveGray),
                                  )
                                ],
                              ),
                            );
                          }),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final title = item['name'] ?? '未命名原料';
                            final currentStock = item['current_stock'] ?? 0;
                            final unit = item['unit'] ?? '';

                            return BorderedCupertinoButton(
                              text: '$title (庫存: ${currentStock.toStringAsFixed(0)}$unit)',
                              onPressed: () => _goToAddOrEditItem(item: item),
                            );
                          },
                        ),
            ),
            BorderedCupertinoButton(
              text: '＋ 新增原料品項',
              onPressed: () => _goToAddOrEditItem(),
            ),
          ],
        ),
      ),
    );
  }
}