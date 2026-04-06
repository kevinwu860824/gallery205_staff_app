import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:flutter/services.dart';
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:gallery205_staff_app/features/ordering/domain/ordering_constants.dart';

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
  MenuItem? _selectedItem;
  List<String> _selectedItemPrintIds = [];
  int? _selectedCartIndex;
  ProviderSubscription? _submissionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _submissionSub = ref.listenManual(orderSubmissionControllerProvider, (prev, next) {
        next.whenOrNull(
          error: (err, stack) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_localizeOrderError(err))),
              );
            }
          },
        );
      });
    });
  }

  @override
  void dispose() {
    _submissionSub?.close();
    _searchController.dispose();
    super.dispose();
  }

  String _localizeOrderError(Object err) {
    final msg = err.toString();
    if (msg.contains('此桌尚有未結帳')) return msg.replaceFirst('Exception: ', '');
    if (msg.contains('No Shop ID')) return '找不到店家設定，請重新登入';
    if (msg.contains('Order Group ID required')) return '加點失敗：找不到訂單編號，請重新開啟訂單頁面';
    if (msg.contains('SocketException') || msg.contains('ConnectionRefused') || msg.contains('NetworkException')) {
      return '網路連線中斷，請重試';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) return '連線逾時，請重試';
    return '送單失敗，請重試';
  }

  Future<void> _submitOrder() async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) return;

    final user = ref.read(authStateProvider).value;
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

  void _showTableOrderHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TableOrderHistorySheet(
        orderGroupId: widget.orderGroupId,
        tableNumbers: widget.tableNumbers,
      ),
    );
  }

  void _showPhoneAddItemSheet(BuildContext context, MenuItem item, List<String> effectivePrintIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PhoneAddItemSheet(
        item: item,
        printCategoryIds: effectivePrintIds,
        onAdd: (orderItem) {
          ref.read(cartProvider.notifier).addToCart(orderItem);
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.name} 已加入購物車'), duration: const Duration(seconds: 1)),
          );
        },
      ),
    );
  }

  void _showPhoneCart(BuildContext context, List<OrderItem> cartItems, bool isSubmitting) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(CupertinoIcons.cart, color: Theme.of(context).colorScheme.onSurface, size: 20),
                  const SizedBox(width: 8),
                  Text("待送出品項", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cartItems.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor),
                itemBuilder: (ctx, index) {
                  final item = cartItems[index];
                  return Dismissible(
                    key: ValueKey('phone_cart_$index${item.itemName}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      ref.read(cartProvider.notifier).removeFromCart(index);
                      if (cartItems.length == 1) Navigator.pop(ctx);
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Theme.of(context).colorScheme.error,
                      child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
                    ),
                    child: ListTile(
                      title: Text(item.itemName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      subtitle: item.selectedModifiers.isNotEmpty
                          ? Text(item.selectedModifiers.map((m) => m['name']).join(', '),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14))
                          : null,
                      trailing: Text("x${item.quantity}  \$${item.totalPrice.toStringAsFixed(0)}",
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    "總計 \$${cartItems.fold(0.0, (s, i) => s + i.totalPrice).toStringAsFixed(0)}",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    color: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    onPressed: isSubmitting ? null : () { Navigator.pop(ctx); _submitOrder(); },
                    child: isSubmitting
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : Text("確認送單", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider);
    final cartItems = ref.watch(cartProvider);
    final isSubmitting = ref.watch(orderSubmissionControllerProvider).isLoading;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final totalQty = cartItems.fold(0, (s, i) => s + i.quantity);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "桌號: ${widget.tableNumbers.join(", ")}",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.isNewOrder ? "新訂單" : "加點",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ),
        // 手機版：右上角購物車 + 點餐紀錄按鈕
        actions: !isTablet ? [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                iconSize: 28,
                icon: Icon(CupertinoIcons.cart, color: Theme.of(context).colorScheme.onSurface),
                onPressed: cartItems.isEmpty ? null : () => _showPhoneCart(context, cartItems, isSubmitting),
              ),
              if (totalQty > 0)
                Positioned(
                  right: 4, top: 4,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                    child: Text(
                      '$totalQty',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            iconSize: 28,
            icon: Icon(CupertinoIcons.doc_text, color: Theme.of(context).colorScheme.onSurface),
            tooltip: '點餐紀錄',
            onPressed: () => _showTableOrderHistory(context),
          ),
        ] : null,
      ),
      body: menuAsync.when(
        loading: () => Center(child: CupertinoActivityIndicator(color: Theme.of(context).colorScheme.onSurface)),
        error: (err, stack) => Center(child: Text('Error loading menu: $err', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        data: (menuData) {
                final categories = menuData.categories;
                final allItems = menuData.items;

                if (categories.isEmpty) return const Center(child: Text("No Categories", style: TextStyle(color: Colors.white)));

                if (selectedCategoryId.isEmpty && categories.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => selectedCategoryId = categories.first.id);
                  });
                }

                final searchText = _searchController.text.trim().toLowerCase();
                final List<MenuItem> currentItems = searchText.isNotEmpty
                    ? allItems.where((i) => i.name.toLowerCase().contains(searchText)).toList()
                    : allItems.where((i) => i.categoryId == selectedCategoryId).toList();

                return Row(
                  children: [
                    // 1. Categories Sidebar
                    Container(
                      width: 110,
                      color: Theme.of(context).cardColor,
                      child: ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = searchText.isEmpty && selectedCategoryId == cat.id;
                          return GestureDetector(
                            onTap: () {
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
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    VerticalDivider(width: 1, thickness: 0.5, color: Theme.of(context).dividerColor),

                    // 2. Middle: grid + detail panel (detail panel iPad only)
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: CupertinoSearchTextField(
                                      controller: _searchController,
                                      placeholder: "搜尋品項...",
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  Expanded(
                                    child: currentItems.isEmpty
                                        ? const Center(child: Text("沒有符合的商品", style: TextStyle(color: Colors.grey)))
                                        : GridView.builder(
                                            padding: const EdgeInsets.all(16),
                                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 140,
                                              childAspectRatio: 0.85,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                            ),
                                            itemCount: currentItems.length,
                                            itemBuilder: (context, index) {
                                              final item = currentItems[index];
                                              List<String> effectivePrintIds = item.targetPrintCategoryIds;
                                              if (effectivePrintIds.isEmpty) {
                                                final catIndex = categories.indexWhere((c) => c.id == item.categoryId);
                                                final cat = catIndex >= 0 ? categories[catIndex] : categories.first;
                                                effectivePrintIds = cat.targetPrintCategoryIds;
                                              }
                                              final bool isAvailable = item.isAvailable;
                                              final bool isSelected = _selectedItem?.id == item.id;

                                              return GestureDetector(
                                                onTap: isAvailable
                                                    ? () {
                                                        if (isTablet) {
                                                          final newIndex = ref.read(cartProvider).length;
                                                          ref.read(cartProvider.notifier).addToCart(OrderItem(
                                                            id: item.id,
                                                            menuItemId: item.id,
                                                            itemName: item.name,
                                                            quantity: 1,
                                                            price: item.price,
                                                            targetPrintCategoryIds: effectivePrintIds,
                                                          ));
                                                          setState(() {
                                                            _selectedItem = item;
                                                            _selectedItemPrintIds = effectivePrintIds;
                                                            _selectedCartIndex = newIndex;
                                                          });
                                                        } else {
                                                          // 手機：彈出視窗填寫後再加入購物車
                                                          _showPhoneAddItemSheet(context, item, effectivePrintIds);
                                                        }
                                                      }
                                                    : null,
                                                onLongPress: () async {
                                                  HapticFeedback.mediumImpact();
                                                  final messenger = ScaffoldMessenger.of(context);
                                                  final repo = ref.read(orderingRepositoryProvider);
                                                  await repo.toggleMenuItemAvailability(item.id, isAvailable);
                                                  ref.invalidate(menuProvider);
                                                  if (mounted) {
                                                    messenger.showSnackBar(
                                                      SnackBar(content: Text(isAvailable ? "${item.name} 已暫停銷售" : "${item.name} 已恢復銷售")),
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isAvailable
                                                        ? Theme.of(context).cardColor
                                                        : Theme.of(context).disabledColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                                                    border: isSelected
                                                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2.5)
                                                        : isAvailable
                                                            ? null
                                                            : Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2),
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
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (!isAvailable)
                                                        Transform.rotate(
                                                          angle: -0.2,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
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
                          ),
                          // Detail panel: iPad only
                          if (isTablet)
                            _ItemDetailPanel(
                              key: ValueKey('${_selectedItem?.id ?? '__empty__'}_$_selectedCartIndex'),
                              selectedItem: _selectedItem,
                              printCategoryIds: _selectedItemPrintIds,
                              onUpdate: (updated) {
                                if (_selectedCartIndex != null) {
                                  ref.read(cartProvider.notifier).updateItem(_selectedCartIndex!, updated);
                                }
                              },
                            ),
                        ],
                      ),
                    ),

                    // 3. Cart Panel (right 200px): iPad only
                    if (isTablet)
                      _CartPanel(
                        cartItems: cartItems,
                        isSubmitting: isSubmitting,
                        orderGroupId: widget.orderGroupId,
                        tableNumbers: widget.tableNumbers,
                        onRemove: (index) {
                          ref.read(cartProvider.notifier).removeFromCart(index);
                          setState(() {
                            if (_selectedCartIndex == index) {
                              _selectedCartIndex = null;
                              _selectedItem = null;
                            } else if (_selectedCartIndex != null && index < _selectedCartIndex!) {
                              _selectedCartIndex = _selectedCartIndex! - 1;
                            }
                          });
                        },
                        onSubmit: _submitOrder,
                      ),
                  ],
                );
              },
            ),
    );
  }
}

// ─── Cart Panel ───────────────────────────────────────────────────────────────

class _CartPanel extends ConsumerStatefulWidget {
  final List<OrderItem> cartItems;
  final bool isSubmitting;
  final String? orderGroupId;
  final List<String> tableNumbers;
  final Function(int) onRemove;
  final VoidCallback onSubmit;

  const _CartPanel({
    required this.cartItems,
    required this.isSubmitting,
    required this.onRemove,
    required this.onSubmit,
    this.orderGroupId,
    this.tableNumbers = const [],
  });

  @override
  ConsumerState<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<_CartPanel> {
  List<Map<String, dynamic>> _submittedItems = [];
  final Set<String> _selectedReprintIds = {};
  bool _isLoadingHistory = false;
  bool _isReprinting = false;

  @override
  void initState() {
    super.initState();
    _loadSubmittedItems();
  }

  Future<void> _loadSubmittedItems() async {
    if (widget.orderGroupId == null) return;
    setState(() => _isLoadingHistory = true);
    try {
      final res = await Supabase.instance.client
          .from('order_items')
          .select('id, item_id, item_name, quantity, price, note, modifiers, status, target_print_category_ids')
          .eq('order_group_id', widget.orderGroupId!)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _submittedItems = List<Map<String, dynamic>>.from(res);
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  double get _total {
    double total = 0;
    for (final item in _submittedItems) {
      if (item['status'] == OrderingConstants.orderStatusCancelled) continue;
      total += _rawToOrderItem(item).totalPrice;
    }
    for (final item in widget.cartItems) {
      total += item.totalPrice;
    }
    return total;
  }

  OrderItem _rawToOrderItem(Map<String, dynamic> item) {
    return OrderItem(
      id: item['id'] as String? ?? '',
      menuItemId: item['item_id'] as String? ?? '',
      itemName: item['item_name'] as String? ?? '',
      quantity: (item['quantity'] as num).toInt(),
      price: (item['price'] as num).toDouble(),
      note: item['note'] as String? ?? '',
      targetPrintCategoryIds: List<String>.from(item['target_print_category_ids'] ?? []),
      selectedModifiers: List<Map<String, dynamic>>.from(item['modifiers'] ?? []),
      status: item['status'] as String? ?? 'submitted',
    );
  }

  Future<void> _voidSubmittedItem(int index) async {
    final item = _submittedItems[index];
    if (item['status'] == OrderingConstants.orderStatusCancelled) return;

    setState(() {
      _submittedItems[index] = {...item, 'status': OrderingConstants.orderStatusCancelled};
      _selectedReprintIds.remove(item['id'] as String);
    });

    try {
      final user = ref.read(authStateProvider).value;
      final staffName = (user?.name != null && user!.name.trim().isNotEmpty)
          ? user.name
          : (user?.email ?? '');
      final orderItemEntity = _rawToOrderItem(item);
      await ref.read(orderingRepositoryProvider).voidOrderItem(
        orderGroupId: widget.orderGroupId!,
        item: orderItemEntity,
        tableName: widget.tableNumbers.join(', '),
        orderGroupPax: 0,
        staffName: staffName,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submittedItems[index] = item);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("刪除失敗: $e")));
      }
    }
  }

  Future<void> _reprintSelected() async {
    if (_selectedReprintIds.isEmpty || widget.orderGroupId == null) return;
    setState(() => _isReprinting = true);
    try {
      final repository = ref.read(orderingRepositoryProvider);
      final tableName = widget.tableNumbers.join(', ');
      int count = 0;
      for (final item in _submittedItems) {
        final id = item['id'] as String;
        if (!_selectedReprintIds.contains(id)) continue;
        if (item['status'] == OrderingConstants.orderStatusCancelled) continue;
        final orderItem = _rawToOrderItem(item);
        await repository.reprintSingleItem(
          orderGroupId: widget.orderGroupId!,
          item: orderItem,
          tableName: tableName,
        );
        count++;
      }
      if (mounted) {
        setState(() {
          _selectedReprintIds.clear();
          _isReprinting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已發送 $count 筆補印指令")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReprinting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("補印失敗: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;
    final hasSelection = _selectedReprintIds.isNotEmpty;
    final totalQty = widget.cartItems.fold(0, (sum, item) => sum + item.quantity);
    final submittedCount = _submittedItems.length;
    final cartCount = widget.cartItems.length;
    final totalCount = submittedCount + cartCount;

    return GestureDetector(
      onTap: () {
        if (_selectedReprintIds.isNotEmpty) setState(() => _selectedReprintIds.clear());
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(left: BorderSide(color: dividerColor, width: 0.5)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.list_bullet, color: colorScheme.onSurface, size: 20),
                  const SizedBox(width: 8),
                  Text("品項", style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (totalQty > 0)
                    Text("$totalQty 新", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
                ],
              ),
            ),

            // Items list
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CupertinoActivityIndicator())
                  : totalCount == 0
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.cart, color: colorScheme.onSurface.withValues(alpha: 0.15), size: 48),
                              const SizedBox(height: 12),
                              Text("尚無品項", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: totalCount,
                          separatorBuilder: (_, __) => Divider(height: 1, color: dividerColor),
                          itemBuilder: (context, index) {
                            // ── Submitted items ──
                            if (index < submittedCount) {
                              final item = _submittedItems[index];
                              final isCancelled = item['status'] == OrderingConstants.orderStatusCancelled;
                              final itemId = item['id'] as String;
                              final isSelected = _selectedReprintIds.contains(itemId);
                              final submittedOrderItem = _rawToOrderItem(item);
                              final unit = submittedOrderItem.unitPriceWithModifiers;
                              final modNames = submittedOrderItem.selectedModifiers
                                  .map((m) => m['name'] as String? ?? '')
                                  .where((n) => n.isNotEmpty)
                                  .toList();
                              final qty = (item['quantity'] as num).toInt();
                              final textColor = isCancelled
                                  ? colorScheme.onSurface.withValues(alpha: 0.25)
                                  : colorScheme.onSurface.withValues(alpha: 0.45);

                              Widget content = Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['item_name'] ?? '',
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "x$qty  \$${(unit * qty).toStringAsFixed(0)}",
                                          style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    if (modNames.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(modNames.join(', '), style: TextStyle(color: textColor, fontSize: 12)),
                                    ],
                                  ],
                                ),
                              );

                              if (isSelected) {
                                content = Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: colorScheme.primary, width: 1.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: content,
                                );
                              }

                              Widget tappable = GestureDetector(
                                onTap: isCancelled ? null : () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedReprintIds.remove(itemId);
                                    } else {
                                      _selectedReprintIds.add(itemId);
                                    }
                                  });
                                },
                                child: content,
                              );

                              if (isCancelled) return tappable;

                              return Dismissible(
                                key: ValueKey('submitted_$itemId'),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => _voidSubmittedItem(index),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  color: colorScheme.error,
                                  child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
                                ),
                                child: tappable,
                              );
                            }

                            // ── Cart items ──
                            final cartIndex = index - submittedCount;
                            final item = widget.cartItems[cartIndex];
                            return Dismissible(
                              key: ValueKey('cart_${cartIndex}_${item.itemName}'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => widget.onRemove(cartIndex),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: colorScheme.error,
                                child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  if (_selectedReprintIds.isNotEmpty) setState(() => _selectedReprintIds.clear());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(item.itemName, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "x${item.quantity}  \$${item.totalPrice.toStringAsFixed(0)}",
                                            style: TextStyle(color: colorScheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      if (item.selectedModifiers.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.selectedModifiers.map((m) => m['name']).join(', '),
                                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: dividerColor, width: 0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("總計", style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
                      Text("\$${_total.toStringAsFixed(0)}", style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: colorScheme.primary,
                      onPressed: hasSelection
                          ? (_isReprinting ? null : _reprintSelected)
                          : (widget.cartItems.isEmpty || widget.isSubmitting ? null : widget.onSubmit),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: hasSelection
                          ? (_isReprinting
                              ? const CupertinoActivityIndicator(color: Colors.white)
                              : Text("補印 (${_selectedReprintIds.length})", style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)))
                          : (widget.isSubmitting
                              ? const CupertinoActivityIndicator(color: Colors.white)
                              : Text("確認送單並列印", style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item Detail Panel ────────────────────────────────────────────────────────

class _ItemDetailPanel extends StatefulWidget {
  final MenuItem? selectedItem;
  final List<String> printCategoryIds;
  final Function(OrderItem) onUpdate;

  const _ItemDetailPanel({
    super.key,
    required this.selectedItem,
    required this.printCategoryIds,
    required this.onUpdate,
  });

  @override
  State<_ItemDetailPanel> createState() => _ItemDetailPanelState();
}

class _ItemDetailPanelState extends State<_ItemDetailPanel> {
  bool isLoading = false;
  List<Map<String, dynamic>> modifierGroups = [];
  final Map<String, Set<String>> _selections = {};
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.selectedItem != null) _initForItem(widget.selectedItem!);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _initForItem(MenuItem item) {
    _quantity = 1;
    _noteController.clear();
    _selections.clear();
    modifierGroups = [];
    _priceController.text = item.isMarketPrice ? '' : item.price.toStringAsFixed(0);
    _loadModifiers(item.id);
  }

  Future<void> _loadModifiers(String itemId) async {
    setState(() => isLoading = true);
    try {
      final client = Supabase.instance.client;
      final links = await client.from('menu_item_modifier_groups').select('modifier_group_id').eq('menu_item_id', itemId);
      if (links.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final groupIds = links.map((e) => e['modifier_group_id']).toList();
      final groupsRes = await client
          .from('modifier_groups')
          .select('*, modifiers(*)')
          .inFilter('id', groupIds)
          .order('sort_order', ascending: true);
      if (mounted) {
        setState(() {
          modifierGroups = List<Map<String, dynamic>>.from(groupsRes);
          for (var g in modifierGroups) {
            final mods = List<Map<String, dynamic>>.from(g['modifiers']);
            mods.sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
            g['modifiers'] = mods;
            _selections[g['id']] = {};
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load modifiers error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onModifierTap(Map<String, dynamic> group, Map<String, dynamic> modifier) {
    final String groupId = group['id'];
    final String modId = modifier['id'];
    final bool isSingle = group['selection_type'] == 'single';
    setState(() {
      if (isSingle) {
        if (_selections[groupId]!.contains(modId)) {
          _selections[groupId]!.remove(modId);
        } else {
          _selections[groupId]!.clear();
          _selections[groupId]!.add(modId);
        }
      } else {
        if (_selections[groupId]!.contains(modId)) {
          _selections[groupId]!.remove(modId);
        } else {
          final int? max = group['max_selection'];
          if (max != null && _selections[groupId]!.length >= max) return;
          _selections[groupId]!.add(modId);
        }
      }
    });
    _syncToCart();
  }


  void _syncToCart() {
    final item = widget.selectedItem;
    if (item == null) return;

    List<Map<String, dynamic>> finalModifiers = [];
    for (var group in modifierGroups) {
      final selectedIds = _selections[group['id']] ?? {};
      for (var mod in (group['modifiers'] as List)) {
        if (selectedIds.contains(mod['id'])) {
          finalModifiers.add({'id': mod['id'], 'name': mod['name'], 'price': mod['price_adjustment'], 'group_name': group['name']});
        }
      }
    }

    widget.onUpdate(OrderItem(
      id: item.id,
      menuItemId: item.id,
      itemName: item.name,
      quantity: _quantity,
      price: double.tryParse(_priceController.text) ?? item.price,
      note: _noteController.text.trim(),
      targetPrintCategoryIds: widget.printCategoryIds,
      selectedModifiers: finalModifiers,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.selectedItem;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: item == null
          ? Center(
              child: Text(
                "點選品項以開始點餐",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25), fontSize: 16),
              ),
            )
          : Row(
              children: [
                // Left: modifiers + note (scrollable)
                Expanded(
                  child: isLoading
                      ? const Center(child: CupertinoActivityIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          children: [
                            // Market price input
                            if (item.isMarketPrice) ...[
                              const SizedBox(height: 10),
                              CupertinoTextField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                placeholder: "輸入時價金額",
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                onChanged: (_) { setState(() {}); _syncToCart(); },
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ],

                            // Modifier groups
                            if (modifierGroups.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...modifierGroups.map((group) {
                                final mods = group['modifiers'] as List;
                                final selectedIds = _selections[group['id']] ?? {};
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(group['name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                                        if ((group['min_selection'] ?? 0) > 0)
                                          Text("  必選 ${group['min_selection']}", style: const TextStyle(color: Colors.red, fontSize: 11)),
                                      ]),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 7,
                                        runSpacing: 7,
                                        children: mods.map((mod) {
                                          final bool isSelected = selectedIds.contains(mod['id']);
                                          final double price = (mod['price_adjustment'] as num).toDouble();
                                          return GestureDetector(
                                            onTap: () => _onModifierTap(group, Map<String, dynamic>.from(mod)),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                                    : Theme.of(context).scaffoldBackgroundColor,
                                                border: Border.all(
                                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.3),
                                                  width: isSelected ? 1.5 : 1,
                                                ),
                                                borderRadius: BorderRadius.circular(7),
                                              ),
                                              child: Text(
                                                price > 0 ? "${mod['name']} +\$${price.toStringAsFixed(0)}" : mod['name'],
                                                style: TextStyle(
                                                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],

                            // Note
                            const SizedBox(height: 4),
                            Text("備註", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                            const SizedBox(height: 5),
                            CupertinoTextField(
                              controller: _noteController,
                              placeholder: "口味調整...",
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                              placeholderStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onChanged: (_) => _syncToCart(),
                            ),
                          ],
                        ),
                ),

                // Right: quantity + add button
                Container(
                  width: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("數量", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (_quantity > 1) {
                                setState(() => _quantity--);
                                _syncToCart();
                              }
                            },
                            child: const Icon(CupertinoIcons.minus_circle, size: 30),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text('$_quantity', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() => _quantity++);
                              _syncToCart();
                            },
                            child: const Icon(CupertinoIcons.add_circled, size: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Table Order History Sheet ────────────────────────────────────────────────

class _TableOrderHistorySheet extends ConsumerStatefulWidget {
  final String? orderGroupId;
  final List<String> tableNumbers;

  const _TableOrderHistorySheet({
    required this.orderGroupId,
    required this.tableNumbers,
  });

  @override
  ConsumerState<_TableOrderHistorySheet> createState() => _TableOrderHistorySheetState();
}

class _TableOrderHistorySheetState extends ConsumerState<_TableOrderHistorySheet> {
  bool isLoading = true;
  List<Map<String, dynamic>> orderItems = [];
  int _pax = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.orderGroupId == null) {
      setState(() { isLoading = false; });
      return;
    }
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client
            .from('order_items')
            .select('id, item_name, quantity, price, note, modifiers, status, target_print_category_ids, item_id, created_at')
            .eq('order_group_id', widget.orderGroupId!)
            .order('created_at', ascending: true),
        client
            .from('order_groups')
            .select('pax')
            .eq('id', widget.orderGroupId!)
            .maybeSingle(),
      ]);
      if (mounted) {
        setState(() {
          orderItems = List<Map<String, dynamic>>.from(results[0] as List);
          _pax = (results[1] as Map<String, dynamic>?)?['pax'] ?? 0;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); isLoading = false; });
    }
  }

  Future<void> _voidItem(int index) async {
    final item = orderItems[index];
    if (item['status'] == OrderingConstants.orderStatusCancelled) return;

    // Optimistic update
    setState(() => orderItems[index] = {...item, 'status': OrderingConstants.orderStatusCancelled});

    try {
      final repository = ref.read(orderingRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final staffName = (user?.name != null && user!.name.trim().isNotEmpty) ? user.name : (user?.email ?? '');

      final orderItemEntity = OrderItem(
        id: item['id'],
        menuItemId: item['item_id'] ?? '',
        itemName: item['item_name'] ?? '',
        quantity: (item['quantity'] as num).toInt(),
        price: (item['price'] as num).toDouble(),
        status: 'submitted',
        targetPrintCategoryIds: List<String>.from(item['target_print_category_ids'] ?? []),
        selectedModifiers: List<Map<String, dynamic>>.from(item['modifiers'] ?? []),
        note: item['note'] ?? '',
      );

      await repository.voidOrderItem(
        orderGroupId: widget.orderGroupId!,
        item: orderItemEntity,
        tableName: widget.tableNumbers.join(', '),
        orderGroupPax: _pax,
        staffName: staffName,
      );
    } catch (e) {
      debugPrint('Void order item error: $e');
      // Revert on failure
      if (mounted) setState(() => orderItems[index] = item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = orderItems
        .where((i) => i['status'] != OrderingConstants.orderStatusCancelled)
        .fold(0.0, (s, i) => s + (i['price'] as num) * (i['quantity'] as num));

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(CupertinoIcons.doc_text, color: colorScheme.onSurface, size: 20),
                const SizedBox(width: 8),
                Text("桌號 ${widget.tableNumbers.join(', ')} 點餐紀錄",
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
            child: isLoading
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CupertinoActivityIndicator()))
                : error != null
                    ? Padding(padding: const EdgeInsets.all(24), child: Text('載入失敗: $error', style: TextStyle(color: colorScheme.error)))
                    : orderItems.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(child: Text('尚無點餐紀錄', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)))),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: orderItems.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                            itemBuilder: (ctx, index) {
                              final item = orderItems[index];
                              final isCancelled = item['status'] == OrderingConstants.orderStatusCancelled;
                              final mods = (item['modifiers'] as List?) ?? [];
                              final modNames = mods.map((m) => m['name']).join(', ');
                              final itemTotal = (item['price'] as num) * (item['quantity'] as num);

                              final content = Opacity(
                                opacity: isCancelled ? 0.4 : 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              item['item_name'] ?? '',
                                              style: TextStyle(
                                                color: colorScheme.onSurface,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                decorationColor: colorScheme.onSurface,
                                                decorationThickness: 2,
                                              ),
                                            ),
                                            if (modNames.isNotEmpty)
                                              Text(modNames, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                      if (isCancelled)
                                        Text('（已刪除）', style: TextStyle(color: colorScheme.error, fontSize: 13, fontWeight: FontWeight.w500))
                                      else
                                        Text(
                                          'x${item['quantity']}  \$${itemTotal.toStringAsFixed(0)}',
                                          style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                ),
                              );

                              if (isCancelled) return content;

                              return Dismissible(
                                key: ValueKey('history_${item['id']}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  color: colorScheme.error,
                                  child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
                                ),
                                onDismissed: (_) => _voidItem(index),
                                child: content,
                              );
                            },
                          ),
          ),
          if (orderItems.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('合計', style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
                  Text('\$${total.toStringAsFixed(0)}',
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Phone Add Item Sheet ─────────────────────────────────────────────────────

class _PhoneAddItemSheet extends StatefulWidget {
  final MenuItem item;
  final List<String> printCategoryIds;
  final Function(OrderItem) onAdd;

  const _PhoneAddItemSheet({
    required this.item,
    required this.printCategoryIds,
    required this.onAdd,
  });

  @override
  State<_PhoneAddItemSheet> createState() => _PhoneAddItemSheetState();
}

class _PhoneAddItemSheetState extends State<_PhoneAddItemSheet> {
  bool isLoading = false;
  List<Map<String, dynamic>> modifierGroups = [];
  final Map<String, Set<String>> _selections = {};
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.item.isMarketPrice ? '' : widget.item.price.toStringAsFixed(0);
    _loadModifiers(widget.item.id);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadModifiers(String itemId) async {
    setState(() => isLoading = true);
    try {
      final client = Supabase.instance.client;
      final links = await client.from('menu_item_modifier_groups').select('modifier_group_id').eq('menu_item_id', itemId);
      if (links.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final groupIds = links.map((e) => e['modifier_group_id']).toList();
      final groupsRes = await client
          .from('modifier_groups')
          .select('*, modifiers(*)')
          .inFilter('id', groupIds)
          .order('sort_order', ascending: true);
      if (mounted) {
        setState(() {
          modifierGroups = List<Map<String, dynamic>>.from(groupsRes);
          for (var g in modifierGroups) {
            final mods = List<Map<String, dynamic>>.from(g['modifiers']);
            mods.sort((a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
            g['modifiers'] = mods;
            _selections[g['id']] = {};
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load modifiers error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onModifierTap(Map<String, dynamic> group, Map<String, dynamic> modifier) {
    final String groupId = group['id'];
    final String modId = modifier['id'];
    final bool isSingle = group['selection_type'] == 'single';
    setState(() {
      if (isSingle) {
        if (_selections[groupId]!.contains(modId)) {
          _selections[groupId]!.remove(modId);
        } else {
          _selections[groupId]!.clear();
          _selections[groupId]!.add(modId);
        }
      } else {
        if (_selections[groupId]!.contains(modId)) {
          _selections[groupId]!.remove(modId);
        } else {
          final int? max = group['max_selection'];
          if (max != null && _selections[groupId]!.length >= max) return;
          _selections[groupId]!.add(modId);
        }
      }
    });
  }

  void _addToCart() {
    List<Map<String, dynamic>> finalModifiers = [];
    for (var group in modifierGroups) {
      final selectedIds = _selections[group['id']] ?? {};
      for (var mod in (group['modifiers'] as List)) {
        if (selectedIds.contains(mod['id'])) {
          finalModifiers.add({'id': mod['id'], 'name': mod['name'], 'price': mod['price_adjustment'], 'group_name': group['name']});
        }
      }
    }
    widget.onAdd(OrderItem(
      id: widget.item.id,
      menuItemId: widget.item.id,
      itemName: widget.item.name,
      quantity: _quantity,
      price: double.tryParse(_priceController.text) ?? widget.item.price,
      note: _noteController.text.trim(),
      targetPrintCategoryIds: widget.printCategoryIds,
      selectedModifiers: finalModifiers,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final item = widget.item;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
          ),
          // Item name + price
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(item.name, style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold))),
                Text(
                  item.isMarketPrice ? "時價" : "\$${item.price.toStringAsFixed(0)}",
                  style: TextStyle(color: item.isMarketPrice ? colorScheme.primary : const Color(0xFF32D74B), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable content
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: isLoading
                ? const Padding(padding: EdgeInsets.all(32), child: CupertinoActivityIndicator())
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    children: [
                      // Market price input
                      if (item.isMarketPrice) ...[
                        Text("輸入時價", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                        const SizedBox(height: 6),
                        CupertinoTextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          placeholder: "輸入時價金額",
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(8)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Modifier groups
                      ...modifierGroups.map((group) {
                        final mods = group['modifiers'] as List;
                        final selectedIds = _selections[group['id']] ?? {};
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(group['name'], style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold)),
                                if ((group['min_selection'] ?? 0) > 0)
                                  Text("  必選 ${group['min_selection']}", style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ]),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: mods.map((mod) {
                                  final bool isSelected = selectedIds.contains(mod['id']);
                                  final double price = (mod['price_adjustment'] as num).toDouble();
                                  return GestureDetector(
                                    onTap: () => _onModifierTap(group, Map<String, dynamic>.from(mod)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? colorScheme.primary.withValues(alpha: 0.15) : theme.scaffoldBackgroundColor,
                                        border: Border.all(color: isSelected ? colorScheme.primary : Colors.grey.withValues(alpha: 0.3), width: isSelected ? 1.5 : 1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        price > 0 ? "${mod['name']} +\$${price.toStringAsFixed(0)}" : mod['name'],
                                        style: TextStyle(color: isSelected ? colorScheme.primary : colorScheme.onSurface, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                      // Note
                      Text("備註", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: _noteController,
                        placeholder: "口味調整...",
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                        placeholderStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14),
                        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(8)),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
          ),
          // Footer: quantity + add to cart button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero, minimumSize: const Size(36, 36),
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  child: const Icon(CupertinoIcons.minus_circle, size: 30),
                ),
                SizedBox(
                  width: 40,
                  child: Text('$_quantity', textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero, minimumSize: const Size(36, 36),
                  onPressed: () => setState(() => _quantity++),
                  child: const Icon(CupertinoIcons.add_circled, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    color: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: _addToCart,
                    child: Text("加入購物車", style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
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
