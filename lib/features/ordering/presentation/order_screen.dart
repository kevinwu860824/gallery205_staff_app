import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:flutter/services.dart'; // import services
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart';
import 'package:gallery205_staff_app/features/ordering/presentation/modifier_selection_dialog.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';

// Styles

class OrderScreen extends ConsumerStatefulWidget {
  final List<String> tableNumbers;
  final String? orderGroupId; 
  final bool isNewOrder;      

  const OrderScreen({
    super.key, 
    required this.tableNumbers,
    this.orderGroupId,
    this.isNewOrder = true,
  });

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  String selectedCategoryId = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider);
    final cartItems = ref.watch(cartProvider);
    final int totalCartQty = cartItems.fold<int>(0, (sum, item) => sum + item.quantity);
    
    // Listen for Submission State (Omitted for brevity, kept same)
    ref.listen(orderSubmissionControllerProvider, (prev, next) {
       next.when(
          data: (_) {
             if (next.hasValue && !next.isLoading) {}
          },
          error: (err, stack) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $err')));
          },
          loading: () {}
       );
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("桌號: ${widget.tableNumbers.join(", ")}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.isNewOrder ? "新訂單" : "加點", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12))
          ],
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IconButton(icon: const Icon(CupertinoIcons.cart, size: 28), onPressed: () => _showCartReviewDialog(context)),
              if (totalCartQty > 0)
                Positioned(
                  top: 5, right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$totalCartQty', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          // [NEW] Ordered Items Button (Only for existing orders)
          if (widget.orderGroupId != null) ...[
            IconButton(
              icon: const Icon(CupertinoIcons.doc_text, size: 28),
              onPressed: () => _showOrderedItemsDialog(context),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
      body: menuAsync.when(
        loading: () => Center(child: CupertinoActivityIndicator(color: Theme.of(context).colorScheme.onSurface)),
        error: (err, stack) => Center(child: Text('Error loading menu: $err', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        data: (menuData) {
          final categories = menuData.categories;
          final allItems = menuData.items;

          if (categories.isEmpty) return const Center(child: Text("No Categories", style: TextStyle(color: Colors.white)));

          // Initialize selection if empty
          if (selectedCategoryId.isEmpty && categories.isNotEmpty) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                 if (mounted) setState(() => selectedCategoryId = categories.first.id);
             });
          }
          
          // Search Logic
          final searchText = _searchController.text.trim().toLowerCase();
          final List<dynamic> currentItems; // Dynamic to avoid type issues if needed, but should be MenuItem
          
          if (searchText.isNotEmpty) {
             currentItems = allItems.where((i) => i.name.toLowerCase().contains(searchText)).toList();
          } else {
             currentItems = allItems.where((i) => i.categoryId == selectedCategoryId).toList();
          }

          return Row(
            children: [
              // 1. Categories Sidebar (Left)
              Container(
                width: 110,
                color: Theme.of(context).cardColor,
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = searchText.isEmpty && selectedCategoryId == cat.id; // Deselect if searching
                    return GestureDetector(
                      onTap: () {
                         // Clear search when changing category
                         _searchController.clear();
                         setState(() => selectedCategoryId = cat.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).scaffoldBackgroundColor : Colors.transparent,
                          border: isSelected ? Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)) : null,
                        ),
                        child: Text(
                          cat.name, 
                          textAlign: TextAlign.center, 
                          style: TextStyle(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7), 
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
                            fontSize: 15
                          )
                        ),
                      ),
                    );
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              
              // 2. Items Grid (Right)
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: "搜尋品項...",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          onChanged: (_) => setState((){}), // Trigger rebuild to filter
                        ),
                      ),
                      
                      // Grid
                      Expanded(
                        child: currentItems.isEmpty 
                        ? const Center(child: Text("沒有符合的商品", style: TextStyle(color: Colors.grey)))
                        : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160, // Ensure items are at least ~160px wide (or fewer cols)
                        childAspectRatio: 0.85, // Taller items to fit 2 lines of text + price safely
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: currentItems.length,
                      itemBuilder: (context, index) {
                        final item = currentItems[index];
                        // Print Cat Logic
                        List<String> effectivePrintIds = item.targetPrintCategoryIds;
                        if (effectivePrintIds.isEmpty) {
                           final cat = categories.cast<MenuCategory>().firstWhere((c) => c.id == item.categoryId, orElse: () => categories.first);
                           effectivePrintIds = cat.targetPrintCategoryIds;
                        }

                        final bool isAvailable = item.isAvailable;

                        return GestureDetector(
                          onTap: isAvailable ? () {
                             showDialog(
                               context: context,
                               builder: (context) => ModifierSelectionDialog(
                                 itemId: item.id, 
                                 itemName: item.name, 
                                 basePrice: item.price,
                                 isMarketPrice: item.isMarketPrice,
                                 targetPrintCategoryIds: effectivePrintIds,
                                 onAddToCart: (orderItem) {
                                    ref.read(cartProvider.notifier).addToCart(orderItem);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                       SnackBar(
                                         content: Text("已加入: ${orderItem.itemName}"), 
                                         duration: const Duration(milliseconds: 600)
                                       )
                                    );
                                 },
                               ),
                             );
                          } : null,
                          onLongPress: () async {
                              // Toggle Availability
                              // Haptic feedback
                              HapticFeedback.mediumImpact();
                              
                              final repo = ref.read(orderingRepositoryProvider);
                              await repo.toggleMenuItemAvailability(item.id, isAvailable);
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isAvailable ? "${item.name} 已暫停銷售" : "${item.name} 已恢復銷售"))
                                );
                                // Refresh Menu
                                ref.refresh(menuProvider);
                              }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isAvailable ? Theme.of(context).cardColor : Theme.of(context).disabledColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                              border: isAvailable ? null : Border.all(color: Colors.red.withOpacity(0.5), width: 2),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: isAvailable ? 1.0 : 0.4,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Text(
                                          item.name, 
                                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.isMarketPrice ? "時價" : "\$${item.price.toStringAsFixed(0)}", 
                                        style: TextStyle(
                                          color: item.isMarketPrice ? Theme.of(context).colorScheme.primary : const Color(0xFF32D74B), 
                                          fontSize: 16, 
                                          fontWeight: FontWeight.bold
                                        )
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isAvailable)
                                  Transform.rotate(
                                    angle: -0.2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text("暫停銷售", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                        ),
                      ),
                    ],
                  ),
                ),
              ), // End Expanded
            ], // End Row Children
          );
        },
      )
    );
  }

  void _showCartReviewDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _CartReviewDialog(), 
    );
    
    if (result == true) {
      final cartItems = ref.read(cartProvider);
      if (cartItems.isEmpty) return;
      
      final user = ref.read(authStateProvider).value;
      // [FIX] Ensure we don't pass whitespace-only name
      final staffName = (user?.name != null && user!.name.trim().isNotEmpty) ? user.name : (user?.email ?? '');

      final success = await ref.read(orderSubmissionControllerProvider.notifier).submitOrder(
        items: cartItems,
        tableNumbers: widget.tableNumbers,
        orderGroupId: widget.orderGroupId,
        isNewOrder: widget.isNewOrder,
        staffName: staffName,
      );
      
      if (success) {
         ref.read(cartProvider.notifier).clearCart();
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 訂單已送出')));
            context.pop(); 
         }
      }
    }
  }

  void _showOrderedItemsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _OrderedItemsDialog(orderGroupId: widget.orderGroupId!),
    );
  }
}

class _OrderedItemsDialog extends ConsumerStatefulWidget {
  final String orderGroupId;
  const _OrderedItemsDialog({required this.orderGroupId});

  @override
  ConsumerState<_OrderedItemsDialog> createState() => _OrderedItemsDialogState();
}

class _OrderedItemsDialogState extends ConsumerState<_OrderedItemsDialog> {
  late Future<List<OrderItem>> _itemsFuture;
  List<OrderItem>? _displayedItems;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _itemsFuture = ref.read(orderingRepositoryProvider).getOrderItems(widget.orderGroupId);
    });
  }

  Future<void> _deleteItem(int index, OrderItem item) async {
    // 1. Optimistic Update
    setState(() {
      if (_displayedItems != null) {
        _displayedItems![index] = item.copyWith(status: 'cancelled');
      }
    });

    try {
      // 2. Call Repository (Void Logic)
      // Need tableName? The dialog only has orderGroupId.
      // We might need to fetch table name or pass it in. 
      // Dialog is inside OrderScreen which has tableNumbers.
      // But _OrderedItemsDialog is separate.
      // Let's pass tableNumbers to _OrderedItemsDialog.
      
      // Since I can't easily change the constructor across files without reading them all,
      // I'll try to fetch basic info if needed, OR just pass "N/A" if printing strictly needs it.
      // Actually printing needs it.
      
      // Let's fetch group details if strictly needed, or since we are in a refactor,
      // let's do it properly: update constructor to accept tableNames. 
      // But to save tool calls, I can fetch it (it's async anyway).
      
      // However, OrderScreen DOES have tableNumbers. I should pass it.
      // I will update the call site in next tool call if I change constructor.
      // For now, let's just fetch it inside void to be safe and independent.
      
      // Wait, voidOrderItem takes tableName.
      // I'll fetch it from DB for safety.
      final supabase = Supabase.instance.client;
      String tableName = "Unknown";
      int pax = 0;
      try {
        final g = await supabase.from('order_groups').select('table_names, pax').eq('id', widget.orderGroupId).single();
        final names = List<String>.from(g['table_names'] ?? []);
        if (names.isNotEmpty) tableName = names.join(",");
        pax = g['pax'] ?? 0;
      } catch(_) {}

      await ref.read(orderingRepositoryProvider).voidOrderItem(
        orderGroupId: widget.orderGroupId, 
        item: item, 
        tableName: tableName, 
        orderGroupPax: pax,
        staffName: (ref.read(authStateProvider).value?.name != null && ref.read(authStateProvider).value!.name.trim().isNotEmpty) 
            ? ref.read(authStateProvider).value!.name 
            : (ref.read(authStateProvider).value?.email ?? ''),
      );
      
      // Success snackbar?
    } catch (e) {
      // Revert if failed
      _loadItems();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("刪除失敗: $e")));
    }
  }

  // ... build ...

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("已點餐點"),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<List<OrderItem>>(
          future: _itemsFuture,
          builder: (context, snapshot) {
             if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CupertinoActivityIndicator());
             if (snapshot.hasError) return Center(child: Text("讀取失敗: ${snapshot.error}"));
             
             final items = snapshot.data ?? [];
             if (_displayedItems == null) {
                _displayedItems = items;
             }
             
             if (_displayedItems!.isEmpty) return const Center(child: Text("無餐點"));

             return ListView.separated(
               itemCount: _displayedItems!.length,
               separatorBuilder: (c, i) => const Divider(height: 1),
               itemBuilder: (context, index) {
                 final item = _displayedItems![index];
                 final bool isCancelled = item.status == 'cancelled';
                 final String modifiers = item.selectedModifiers.map((m) => m['name'] ?? '').join(', ');
                 
                 final tile = Container(
                   color: Theme.of(context).dialogBackgroundColor, // 確保不透明，擋住底下的紅色
                   child: ListTile(
                     contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                     title: Text(item.itemName, style: TextStyle(
                        decoration: isCancelled ? TextDecoration.lineThrough : null, 
                        color: isCancelled ? Theme.of(context).disabledColor : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold
                     )),
                       subtitle: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Text("x${item.quantity}   \$${item.totalPrice.toStringAsFixed(0)}", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                          if (modifiers.isNotEmpty) Text(modifiers, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                          if (item.note.isNotEmpty) Text("備註: ${item.note}", style: TextStyle(fontSize: 12, color: Colors.orange)),
                       ],
                     ),
                     trailing: isCancelled ? null : IconButton(
                        icon: Icon(CupertinoIcons.printer, color: Theme.of(context).colorScheme.primary), 
                        onPressed: () => _processReprintItem(item)
                     ),
                   ),
                 );

                 if (isCancelled) return tile;

                 return _SwipeToDeleteRow(
                   onDelete: () => _deleteItem(index, item),
                   child: tile,
                 );
               },
             );
          }
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("關閉")),
      ]
    );
  }

  Future<void> _processReprintItem(OrderItem item) async {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("正在補印...")));
    
    try {
      // Fetch table name needed for reprint
      final supabase = Supabase.instance.client;
      String tableName = "Unknown";
      try {
        final g = await supabase.from('order_groups').select('table_names').eq('id', widget.orderGroupId).single();
        final names = List<String>.from(g['table_names'] ?? []);
        if (names.isNotEmpty) tableName = names.join(",");
      } catch(_) {}

      await ref.read(orderingRepositoryProvider).reprintSingleItem(
        orderGroupId: widget.orderGroupId,
        item: item,
        tableName: tableName,
        staffName: (ref.read(authStateProvider).value?.name != null && ref.read(authStateProvider).value!.name.trim().isNotEmpty) 
            ? ref.read(authStateProvider).value!.name 
            : (ref.read(authStateProvider).value?.email ?? ''),
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("補印指令已發送")));
      
    } catch (e) {
      debugPrint("Reprint error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("補印失敗: $e")));
    }
  }
}

// --- Cart Dialog ---

class _CartReviewDialog extends ConsumerWidget {
  const _CartReviewDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final double total = notifier.totalPrice;
    
    return _CartReviewDialogContent(
       cartItems: cartItems, 
       totalPrice: total,
       onRemove: (index) => notifier.removeFromCart(index),
       onSubmit: () async {
          Navigator.pop(context, true); 
       }
    );
  }
}

class _CartReviewDialogContent extends StatelessWidget {
  final List<OrderItem> cartItems;
  final double totalPrice;
  final Function(int) onRemove;
  final VoidCallback onSubmit;
  
  const _CartReviewDialogContent({
    required this.cartItems, 
    required this.totalPrice, 
    required this.onRemove, 
    required this.onSubmit
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("訂單確認", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(CupertinoIcons.xmark, color: Colors.grey)
                )
              ]
            )
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          // Cart List
          Flexible(
            child: cartItems.isEmpty 
              ? const Padding(padding: EdgeInsets.all(20), child: Text("購物車是空的", style: TextStyle(color:Colors.grey)))
              : ListView.separated(
              shrinkWrap: true,
              itemCount: cartItems.length,
              separatorBuilder: (c, i) => Divider(height: 1, color: Theme.of(context).dividerColor),
              itemBuilder: (context, index) {
                final item = cartItems[index];
                final hasModifiers = item.selectedModifiers.isNotEmpty;
                
                return ListTile(
                  title: Text(
                    item.itemName,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show Modifiers
                      if (hasModifiers) ...[
                        const SizedBox(height: 4),
                        Wrap(
                           spacing: 6,
                           children: item.selectedModifiers.map((m) {
                              final price = (m['price'] as num).toDouble();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                child: Text("${m['name']}${price > 0 ? ' +\$${price.toInt()}' : ''}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
                              );
                           }).toList(),
                        )
                      ],
                      // Show Note
                      if (item.note.isNotEmpty) ...[
                         const SizedBox(height: 4),
                         Text("備註: ${item.note}", style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 14)),
                      ]
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Total per Line logic already in OrderItem
                      Text(
                        "x${item.quantity}   \$${item.totalPrice.toStringAsFixed(0)}",
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(CupertinoIcons.trash, color: Theme.of(context).colorScheme.error, size: 24),
                        onPressed: () => onRemove(index)
                      )
                    ]
                  )
                );
              }
            )
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("總計", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
                    Text("\$${totalPrice.toStringAsFixed(0)}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold))
                  ]
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: const Color(0xFF32D74B),
                    // Disable submit if empty
                    onPressed: cartItems.isEmpty ? null : onSubmit,
                    child: const Text("確認送單並列印", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  )
                )
              ]
            )
          ),
        ],
      ),
    );
  }
}

class _SwipeToDeleteRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeToDeleteRow({
    required this.child,
    required this.onDelete,
  });

  @override
  State<_SwipeToDeleteRow> createState() => _SwipeToDeleteRowState();
}

class _SwipeToDeleteRowState extends State<_SwipeToDeleteRow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0;
  final double _buttonWidth = 80.0;
  final double _threshold = 150.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.primaryDelta! < 0 || _dragExtent < 0) {
      setState(() {
        _dragExtent += details.primaryDelta!;
        if (_dragExtent > 0) _dragExtent = 0; 
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final double width = context.size?.width ?? MediaQuery.of(context).size.width;
    if (_dragExtent < -_threshold) {
      _animateTo(-width).then((_) {
        widget.onDelete();
      });
    } 
    else if (_dragExtent < -(_buttonWidth / 2)) {
      _animateTo(-_buttonWidth);
    } 
    else {
      _animateTo(0);
    }
  }

  Future<void> _animateTo(double target) {
    final start = _dragExtent;
    _controller.reset();
    final animation = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    animation.addListener(() {
      setState(() {
        _dragExtent = animation.value;
      });
    });

    return _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                final double width = context.size?.width ?? MediaQuery.of(context).size.width;
                _animateTo(-width).then((_) {
                  widget.onDelete();
                });
              },
              child: Container(
                color: Theme.of(context).colorScheme.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 28),
                child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 28),
              ),
            ),
          ),
          
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}