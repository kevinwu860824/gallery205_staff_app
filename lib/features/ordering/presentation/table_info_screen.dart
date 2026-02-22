// lib/features/ordering/presentation/table_info_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added import
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart'; // Added Auth Provider
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/features/ordering/data/repositories/ordering_repository_impl.dart';
import 'package:gallery205_staff_app/features/ordering/data/datasources/ordering_remote_data_source.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/ordering_repository.dart';

// -------------------------------------------------------------------
// 1. 樣式定義
// -------------------------------------------------------------------

class TableInfoScreen extends ConsumerStatefulWidget {
  final String tableName;
  final String orderGroupId;

  const TableInfoScreen({
    super.key,
    required this.tableName,
    required this.orderGroupId,
  });

  @override
  ConsumerState<TableInfoScreen> createState() => _TableInfoScreenState();
}

class _TableInfoScreenState extends ConsumerState<TableInfoScreen> {
  bool isLoading = true;
  Map<String, dynamic>? orderGroupData;
  List<Map<String, dynamic>> orderItems = [];
  double totalAmount = 0.0;
  
  final PrinterService _printerService = PrinterService();
  
  OrderingRepository? _repository;
  Future<void> _ensureRepository() async {
    if (_repository != null) return;
    final prefs = await SharedPreferences.getInstance();
    final client = Supabase.instance.client;
    final dataSource = OrderingRemoteDataSourceImpl(client);
    _repository = OrderingRepositoryImpl(dataSource, prefs);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // 1. 抓取訂單主檔
      final groupRes = await supabase
          .from('order_groups')
          .select('created_at, pax, note, staff_name') // Added staff_name
          .eq('id', widget.orderGroupId)
          .single();

      // 2. 抓取所有餐點
      // Changed item_options to modifiers
      final itemsRes = await supabase
          .from('order_items')
          .select('id, item_name, quantity, price, note, status, created_at, target_print_category_ids, modifiers')
          .eq('order_group_id', widget.orderGroupId)
          .order('created_at', ascending: true);

      // 3. 計算總金額 (只計算非 cancelled 的項目)
      double tempTotal = 0.0;
      final List<Map<String, dynamic>> itemsList = List<Map<String, dynamic>>.from(itemsRes);
      
      for (var item in itemsList) {
        if (item['status'] != 'cancelled') {
           double price = (item['price'] as num).toDouble();
           final mods = item['modifiers'];
           if (mods != null && mods is List) {
              for (var m in mods) {
                 if (m is Map) {
                    price += ((m['price'] ?? m['price_adjustment'] ?? 0) as num).toDouble();
                 }
              }
           }
           tempTotal += price * (item['quantity'] as num);
        }
      }

      if (mounted) {
        setState(() {
          orderGroupData = groupRes;
          orderItems = itemsList;
          totalAmount = tempTotal;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("資料讀取失敗: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ----------------------------------------------------------------
  // 核心邏輯：刪除與復原
  // ----------------------------------------------------------------

  Future<void> _deleteItem(int index) async {
    await _ensureRepository();
    final item = orderItems[index];
    final String itemId = item['id'];
    
    // Calculate total including modifiers
    double price = (item['price'] as num).toDouble();
    if (item['modifiers'] != null && item['modifiers'] is List) {
        for (var m in (item['modifiers'] as List)) {
            if (m is Map) {
                price += ((m['price'] ?? m['price_adjustment'] ?? 0) as num).toDouble();
            }
        }
    }
    final double itemTotal = price * (item['quantity'] as num);

    // 1. UI Optimistic Update
    setState(() {
      orderItems[index]['status'] = 'cancelled';
      totalAmount -= itemTotal;
    });

    try {
      // 2. Call Repository Void
      // Construct OrderItem entity
      List<Map<String, dynamic>> selectedModifiers = [];
      if (item['modifiers'] != null && item['modifiers'] is List) {
          selectedModifiers = List<Map<String, dynamic>>.from(item['modifiers']);
      }
      
      final orderItemEntity = OrderItem(
        id: itemId,
        menuItemId: item['menu_item_id'] ?? item['item_id'] ?? '', // Handle varied naming
        itemName: item['item_name'],
        quantity: (item['quantity'] as num).toInt(),
        price: (item['price'] as num).toDouble(),
        status: 'submitted', // Was submitted before void
        targetPrintCategoryIds: List<String>.from(item['target_print_category_ids'] ?? []),
        selectedModifiers: selectedModifiers,
        note: item['note'] ?? ''
      );

      await _repository!.voidOrderItem(
        orderGroupId: widget.orderGroupId,
        item: orderItemEntity,
        tableName: widget.tableName,
        orderGroupPax: orderGroupData?['pax'] ?? 0,
        staffName: (ref.read(authStateProvider).value?.name != null && ref.read(authStateProvider).value!.name.trim().isNotEmpty) 
               ? ref.read(authStateProvider).value!.name 
               : (ref.read(authStateProvider).value?.email ?? ''),
      );

      // 4. Show Undo SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).cardColor,
            content: Text("已刪除 ${item['item_name']}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            action: SnackBarAction(
              label: '復原',
              textColor: Theme.of(context).colorScheme.primary,
              onPressed: () => _undoDeleteItem(index, itemId, itemTotal),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("Delete error: $e");
      _loadData(); // Revert on error
    }
  }

  Future<void> _processReprintItem(int index) async {
    await _ensureRepository();
    final itemMap = orderItems[index];
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("正在補印...")));
    
    try {
      List<Map<String, dynamic>> selectedModifiers = [];
      if (itemMap['modifiers'] != null && itemMap['modifiers'] is List) {
          selectedModifiers = List<Map<String, dynamic>>.from(itemMap['modifiers']);
      }
      
      final orderItem = OrderItem(
        id: itemMap['id'],
        menuItemId: itemMap['menu_item_id'] ?? itemMap['item_id'] ?? '', 
        itemName: itemMap['item_name'], 
        quantity: (itemMap['quantity'] as num).toInt(),
        price: (itemMap['price'] as num).toDouble(),
        status: 'submitted',
        note: itemMap['note'] ?? '',
        targetPrintCategoryIds: List<String>.from(itemMap['target_print_category_ids'] ?? []),
        selectedModifiers: selectedModifiers
      );
      
      await _repository!.reprintSingleItem(
         orderGroupId: widget.orderGroupId, 
         item: orderItem, 
         tableName: widget.tableName,
         staffName: orderGroupData?['staff_name'] // Use original staff for reprint
      );
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("補印指令已發送")));
      
    } catch (e) {
      debugPrint("Reprint error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("補印失敗: $e")));
    }
  }

  Future<void> _undoDeleteItem(int index, String itemId, double itemTotal) async {
    setState(() {
      orderItems[index]['status'] = 'submitted'; 
      totalAmount += itemTotal;
    });

    try {
      await Supabase.instance.client
          .from('order_items')
          .update({'status': 'submitted'})
          .eq('id', itemId);
    } catch (e) {
      debugPrint("Undo error: $e");
      _loadData();
    }
  }

  // ----------------------------------------------------------------
  // UI 構建
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    TextStyle contentStyle = TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // --- Header ---
          Container(
            padding: EdgeInsets.only(top: topPadding + 10, left: 16, right: 16, bottom: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(CupertinoIcons.back, color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "桌號 ${widget.tableName}",
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis, 
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  Center(child: CupertinoActivityIndicator(color: Theme.of(context).colorScheme.onSurface))
                else if (orderGroupData == null)
                   Center(child: Text("讀取資料失敗，請稍後重試", style: TextStyle(color: Theme.of(context).colorScheme.error)))
                else ...[
                  _buildHeaderInfo(orderGroupData!),
                  const SizedBox(height: 16),
                  Divider(color: Theme.of(context).dividerColor),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("目前總額", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 16)),
                      Text(
                        "\$${totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(color: Color(0xFF32D74B), fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // --- Items List ---
          Expanded(
            child: isLoading
                ? const SizedBox.shrink()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orderItems.length,
                    separatorBuilder: (_, __) => Divider(color: Theme.of(context).dividerColor, height: 1),
                    itemBuilder: (context, index) {
                      final item = orderItems[index];
                      final bool isCancelled = item['status'] == 'cancelled';
                      
                      // Fix: Calculate Total Price (Base + Modifiers)
                      double unitPrice = (item['price'] as num).toDouble();
                      final mods = item['modifiers'];
                      final List<String> modStrings = [];
                      
                      if (mods != null && mods is List) {
                        for (var m in mods) {
                           if (m is Map) {
                              final double modPrice = ((m['price'] ?? m['price_adjustment'] ?? 0) as num).toDouble();
                              unitPrice += modPrice;
                              
                              String modName = m['name'] ?? '';
                              if (modPrice > 0) {
                                 modName += " (+\$${modPrice.toInt()})";
                              }
                              modStrings.add(modName);
                           }
                        }
                      }
                      final double lineTotal = unitPrice * (item['quantity'] as num);
                      final qty = (item['quantity'] as num).toInt();

                      // 內容區塊 Widget
                      Widget rowContent = Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor, 
                        ),
                        child: Row(
                          children: [
                            // 1. 名稱 & Modifiers
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['item_name'],
                                    style: isCancelled 
                                        ? contentStyle.copyWith(color: Theme.of(context).disabledColor, decoration: TextDecoration.lineThrough)
                                        : contentStyle,
                                  ),
                                  // Modifiers Display
                                  if (modStrings.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        modStrings.join(', '),
                                        style: TextStyle(
                                          color: isCancelled ? Theme.of(context).disabledColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          fontSize: 14
                                        ),
                                      ),
                                    ),
                                  if (item['note'] != null && item['note'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item['note'],
                                        style: TextStyle(
                                          color: isCancelled ? Theme.of(context).disabledColor : Colors.orange,
                                          fontSize: 14
                                        ),
                                      ),
                                    ),
                                  if (isCancelled)
                                    Text("(已刪除)", style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                                ],
                              ),
                            ),
                            // 2. 數量
                            SizedBox(
                              width: 50,
                              child: Text(
                                "x$qty",
                                style: isCancelled 
                                    ? contentStyle.copyWith(color: Theme.of(context).disabledColor)
                                    : contentStyle,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // 3. 價格 (顯示總金額)
                            SizedBox(
                              width: 80,
                              child: Text(
                                "\$${lineTotal.toStringAsFixed(0)}",
                                style: isCancelled 
                                    ? contentStyle.copyWith(color: Theme.of(context).disabledColor, decoration: TextDecoration.lineThrough)
                                    : contentStyle,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            // 4. Reprint Button
                            if (!isCancelled) ...[
                               const SizedBox(width: 8),
                               IconButton(
                                 onPressed: () => _processReprintItem(index),
                                 icon: Icon(CupertinoIcons.printer, color: Theme.of(context).colorScheme.primary, size: 20),
                                 constraints: const BoxConstraints(), 
                                 padding: const EdgeInsets.all(8),
                               )
                            ]
                          ],
                        ),
                      );

                      if (isCancelled) {
                        return rowContent;
                      }

                      return _SwipeToDeleteRow(
                        key: ValueKey(item['id']),
                        onDelete: () => _deleteItem(index),
                        child: rowContent,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(Map<String, dynamic> data) {
    if (data['created_at'] == null) return const SizedBox.shrink();
    final DateTime openTime = DateTime.parse(data['created_at']).toLocal();
    final Duration duration = DateTime.now().difference(openTime);
    final String durationStr = "${duration.inHours}h ${duration.inMinutes % 60}m";
    final String pax = "${data['pax'] ?? 0} 人";
    final String note = data['note'] ?? '';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _InfoChip(icon: CupertinoIcons.time, label: "${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')} ($durationStr)"),
            _InfoChip(icon: CupertinoIcons.person_2_fill, label: pax),
          ],
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Text("備註：$note", style: const TextStyle(color: Colors.orange)),
          )
        ]
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15)),
      ],
    );
  }
}

// Add Riverpod consumer to access ref
class TableInfoScreenWrapper extends ConsumerWidget {
    final String tableName;
    final String orderGroupId;
    const TableInfoScreenWrapper({super.key, required this.tableName, required this.orderGroupId});
    @override
    Widget build(BuildContext context, WidgetRef ref) {
        return TableInfoScreen(tableName: tableName, orderGroupId: orderGroupId);
    }
}

class _SwipeToDeleteRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeToDeleteRow({
    super.key,
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
    if (_dragExtent < -_threshold) {
      _animateTo(-MediaQuery.of(context).size.width).then((_) {
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
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              _animateTo(-MediaQuery.of(context).size.width).then((_) {
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
    );
  }
}