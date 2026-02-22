
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:gallery205_staff_app/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:gallery205_staff_app/features/inventory/presentation/widgets/inventory_widgets.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class InventoryCategoryDetailScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;

  const InventoryCategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  ConsumerState<InventoryCategoryDetailScreen> createState() => _InventoryCategoryDetailScreenState();
}

class _InventoryCategoryDetailScreenState extends ConsumerState<InventoryCategoryDetailScreen> {
  bool isEditing = false;

  Future<void> _addItem() async {
    final shopId = await ref.read(currentShopIdProvider.future);
    if (shopId == null) return;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => const InventoryAddEditItemDialog(isEditing: false),
    );

    if (result != null) {
      final newItem = InventoryItem(
        id: const Uuid().v4(), // ID generation ideally in repo/usecase
        categoryId: widget.categoryId,
        shopId: shopId,
        sortOrder: 9999, // Append to end
        name: result['name'],
        unit: result['unit'],
        currentStock: (result['current_stock'] as num).toDouble(),
        parLevel: (result['par_level'] as num).toDouble(),
        costPerUnit: (result['cost'] as num?)?.toDouble() ?? 0.0,
        contentPerUnit: (result['content_per_unit'] as num).toDouble(),
        contentUnit: result['content_unit'],
      );
      
      await ref.read(inventoryItemsProvider(widget.categoryId).notifier).addItem(newItem);
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => InventoryDeleteDialog(
        title: l10n.inventoryItemDeleteTitle,
        content: l10n.inventoryItemDeleteContent(item.name),
      ),
    );

    if (confirm == true) {
      ref.read(inventoryItemsProvider(widget.categoryId).notifier).deleteItem(item.id);
    }
  }

  Future<void> _editItem(InventoryItem item) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => InventoryAddEditItemDialog(
        isEditing: true,
        initialName: item.name,
        initialUnit: item.unit,
        initialStock: item.currentStock,
        initialPar: item.parLevel,
        initialContentPerUnit: item.contentPerUnit,
        initialContentUnit: item.contentUnit,
      ),
    );

    if (result != null) {
       final updatedItem = InventoryItem(
        id: item.id,
        categoryId: item.categoryId,
        shopId: item.shopId,
        sortOrder: item.sortOrder,
        name: result['name'],
        unit: result['unit'],
        currentStock: (result['current_stock'] as num).toDouble(),
        parLevel: (result['par_level'] as num).toDouble(),
        costPerUnit: item.costPerUnit,
        contentPerUnit: (result['content_per_unit'] as num).toDouble(),
        contentUnit: result['content_unit'],
      );
      
      await ref.read(inventoryItemsProvider(widget.categoryId).notifier).updateItem(updatedItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final itemsState = ref.watch(inventoryItemsProvider(widget.categoryId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
           Padding(
             padding: EdgeInsets.only(top: safeAreaTop + 60, left: 16, right: 16, bottom: 40),
             child: itemsState.when(
               data: (items) {
                 // Empty state check if needed
                 
                 return SingleChildScrollView(
                   child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Column(
                        children: [
                          isEditing
                            ? ReorderableListView(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                onReorder: (oldIndex, newIndex) {
                                  ref.read(inventoryItemsProvider(widget.categoryId).notifier).reorder(oldIndex, newIndex);
                                },
                                children: items.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  return Column(
                                    key: ValueKey(item.id),
                                    children: [
                                      InventoryCustomTile(
                                        title: item.name,
                                        isEditing: true,
                                        reorderIndex: index,
                                        onDelete: () => _deleteItem(item),
                                        onEdit: () => _editItem(item),
                                      ),
                                      if (index < items.length - 1)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                          child: Divider(color: Theme.of(context).dividerColor, height: 1, thickness: 0.5),
                                        )
                                    ],
                                  );
                                }).toList(),
                            )
                            : ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return Column(
                                    children: [
                                      InventoryCustomTile(
                                        title: item.name,
                                        isEditing: false,
                                        onTap: () => _editItem(item), // Normal tap opens edit in original app
                                      ),
                                      if (index < items.length - 1)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                          child: Divider(color: Theme.of(context).dividerColor, height: 1, thickness: 0.5),
                                        )
                                    ],
                                  );
                                },
                            ),
                            
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
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                   ),
                 );
               },
               loading: () => const Center(child: CircularProgressIndicator()),
               error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: Theme.of(context).colorScheme.error))),
             ),
          ),
          
          // Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: EdgeInsets.only(top: safeAreaTop, bottom: 10, left: 16, right: 16),
              child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   IconButton(
                     icon: const Icon(CupertinoIcons.chevron_left),
                     color: Theme.of(context).colorScheme.onSurface,
                     iconSize: 30,
                     onPressed: () => context.pop(),
                   ),
                   Expanded(
                     child: Text(
                        widget.categoryName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
                       color: Theme.of(context).iconTheme.color, 
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
