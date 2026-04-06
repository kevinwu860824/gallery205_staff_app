import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/core/services/local_db_service.dart';
import 'package:gallery205_staff_app/core/services/hub_client.dart';
import 'package:gallery205_staff_app/features/ordering/domain/ordering_constants.dart';
import 'package:gallery205_staff_app/features/ordering/data/repositories/ordering_repository_impl.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/ordering_repository.dart';
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart';

class SplitBillScreen extends ConsumerStatefulWidget {
  final String groupKey;
  final List<String> currentSeats;
  final bool embedded;
  final VoidCallback? onClose;
  final VoidCallback? onSplitComplete;

  const SplitBillScreen({
    super.key,
    required this.groupKey,
    required this.currentSeats,
    this.embedded = false,
    this.onClose,
    this.onSplitComplete,
  });

  @override
  ConsumerState<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends ConsumerState<SplitBillScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;

  // Data
  List<Map<String, dynamic>> rawItems = []; // Raw items from Database
  List<Map<String, dynamic>> allItems = []; // Consolidated items for UI
  List<Map<String, dynamic>> activeOrders = []; // List of active orders for these tables
  String? sourceGroupId; // Currently selected source order ID
  
  // Tab 1: Split by Items
  final Map<String, int> _selectedItemsQty = {}; // Mapped Item ID to quantity moved to NEW bill
  double leftTotal = 0;
  double rightTotal = 0;

  // Tab 2: Split by Pax
  int pax = 2;
  double totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    sourceGroupId = widget.groupKey; // Default to entry group
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final repo = ref.read(orderingRepositoryProvider);
      final prefs = await SharedPreferences.getInstance();
      final bool isHubDevice = prefs.getBool('isHubDevice') ?? false;
      final String hubIp = prefs.getString('hubIpAddress') ?? '';
      final bool isHubClient = hubIp.isNotEmpty && !isHubDevice;

      // 1. Fetch all related orders for this group (Hub-aware)
      // Hub mode: directly look up by group ID (no currentSeats filter needed)
      // Supabase mode: filter all dining orders by currentSeats
      List<Map<String, dynamic>> allActive = [];

      if (isHubDevice) {
        final db = LocalDbService();
        final activeByTable = await db.getActiveGroupIdsByTable();
        // Find tables belonging to widget.groupKey
        final relatedTables = activeByTable.entries
            .where((e) => e.value.contains(widget.groupKey))
            .map((e) => e.key)
            .toSet();
        // Collect all group IDs from those tables
        final relatedGroupIds = <String>{};
        for (final table in relatedTables) {
          relatedGroupIds.addAll(activeByTable[table] ?? []);
        }
        if (relatedGroupIds.isEmpty) relatedGroupIds.add(widget.groupKey);
        final allGroups = await db.getAllActivePendingOrderGroupsWithItems();
        allActive = allGroups
            .where((o) => relatedGroupIds.contains(o['id'] as String? ?? ''))
            .toList();
      } else if (isHubClient) {
        final hubClient = HubClient();
        final res = await hubClient.get('/orders/${widget.groupKey}/related');
        if (res != null && res['orders'] is List) {
          allActive = List<Map<String, dynamic>>.from(res['orders']);
        } else {
          // Fallback: at minimum load the source group
          allActive = [];
        }
      } else {
        // Supabase path
        final supabase = Supabase.instance.client;
        final hostGroup = await supabase
            .from('order_groups')
            .select('shop_id')
            .eq('id', widget.groupKey)
            .single();
        final String shopId = hostGroup['shop_id'];
        final allDiningRes = await supabase
            .from('order_groups')
            .select('id, table_names, created_at, pax, note, color_index')
            .eq('shop_id', shopId)
            .eq('status', OrderingConstants.orderStatusDining)
            .order('created_at', ascending: true);
        allActive = List<Map<String, dynamic>>.from(allDiningRes);

        // Filter Supabase results to orders sharing any of the current seats
        allActive = allActive.where((order) {
          final tables = order['table_names'];
          final List<String> tableList = tables is List
              ? List<String>.from(tables)
              : (tables is String && tables.startsWith('[') && tables.length > 2
                  ? tables.substring(1, tables.length - 1).split(',').map((e) => e.trim().replaceAll('"', '')).toList()
                  : (tables is String ? [tables] : []));
          return tableList.any((t) => widget.currentSeats.contains(t));
        }).toList();
      }

      activeOrders = allActive;

      // 確保原始訂單（widget.groupKey）始終排在第一位，其他依 created_at ASC
      activeOrders.sort((a, b) {
        if (a['id'] == widget.groupKey) return -1;
        if (b['id'] == widget.groupKey) return 1;
        final aDate = (a['created_at'] as String? ?? '');
        final bDate = (b['created_at'] as String? ?? '');
        return aDate.compareTo(bDate);
      });

      // Supabase only: filter out ghost orders (zero non-cancelled items)
      if (!isHubDevice && !isHubClient && activeOrders.length > 1) {
        try {
          final supabase = Supabase.instance.client;
          final activeGroupIds = activeOrders.map((e) => e['id'] as String).toList();
          final validItemsRes = await supabase
              .from('order_items')
              .select('order_group_id')
              .inFilter('order_group_id', activeGroupIds)
              .neq('status', OrderingConstants.orderStatusCancelled);
          final validGroupIds =
              Set<String>.from(validItemsRes.map((e) => e['order_group_id'].toString()));
          if (validGroupIds.isNotEmpty) {
            activeOrders.retainWhere(
                (o) => validGroupIds.contains(o['id']) || o['id'] == widget.groupKey);
          }
        } catch (_) {}
      }

      final contextObj = await repo.getOrderContext(sourceGroupId!);
      if (contextObj == null) {
        rawItems = [];
      } else {
        rawItems = contextObj.order.items
          .where((it) => it.status != OrderingConstants.orderStatusCancelled)
          .map((it) => {
            'id': it.id,
            'item_id': it.menuItemId,
            'item_name': it.itemName,
            'quantity': it.quantity,
            'price': it.price,
            'modifiers': it.selectedModifiers,
            'note': it.note,
            'status': it.status,
            'target_print_category_ids': it.targetPrintCategoryIds,
          }).toList();
        allItems = _consolidateItems(rawItems);
        _calculateTotals();
      }
    } catch (e) {
      debugPrint("Load items error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Combine items with the same name, price, note, and modifiers into a single UI row
  List<Map<String, dynamic>> _consolidateItems(List<Map<String, dynamic>> raw) {
     List<Map<String, dynamic>> consolidated = [];
     for (var item in raw) {
        bool found = false;
        
        // Convert modifiers to string for simple comparison
        final modStr = (item['modifiers'] ?? []).toString();
        final note = item['note'] ?? '';
        final price = (item['price'] as num).toDouble();
        final name = item['item_name'];
        final status = item['status'];
        
        for (var c in consolidated) {
           final cModStr = (c['modifiers'] ?? []).toString();
           final cNote = c['note'] ?? '';
           final cPrice = (c['price'] as num).toDouble();
           final cName = c['item_name'];
           final cStatus = c['status'];
           
           if (name == cName && price == cPrice && note == cNote && modStr == cModStr && status == cStatus) {
               // Merge into c
               c['quantity'] = (c['quantity'] as num).toInt() + (item['quantity'] as num).toInt();
               c['source_ids'].add(item['id']);
               found = true;
               break;
           }
        }
        
        if (!found) {
           var newC = Map<String, dynamic>.from(item);
           newC['source_ids'] = [item['id']];
           consolidated.add(newC);
        }
     }
     return consolidated;
  }

  void _calculateTotals() {
    leftTotal = 0;
    rightTotal = 0;
    for (var item in allItems) {
      final itemId = item['id'];
      final price = (item['price'] as num).toDouble();
      final totalQty = (item['quantity'] as num).toInt();
      
      final movedQty = _selectedItemsQty[itemId] ?? 0;
      final remainingQty = totalQty - movedQty;
      
      rightTotal += (price * movedQty);
      leftTotal += (price * remainingQty);
    }
    totalAmount = leftTotal + rightTotal;
  }

  // Toggle item selection (Move 1 to right)
  void _moveTargetItem(String itemId, {bool toRight = true}) {
    final item = allItems.firstWhere((e) => e['id'] == itemId);
    final totalQty = (item['quantity'] as num).toInt();
    final currentMoved = _selectedItemsQty[itemId] ?? 0;

    setState(() {
      if (toRight) {
         if (currentMoved < totalQty) {
            _selectedItemsQty[itemId] = currentMoved + 1;
         }
      } else {
         if (currentMoved > 0) {
            _selectedItemsQty[itemId] = currentMoved - 1;
            if (_selectedItemsQty[itemId] == 0) {
                _selectedItemsQty.remove(itemId);
            }
         }
      }
      _calculateTotals();
    });
  }

  // Execute Split by Items (DB Transaction)
  Future<void> _executeSplitItems() async {
    if (_selectedItemsQty.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final repo = ref.read(orderingRepositoryProvider);
      // Build itemQuantitiesToMove: rawItemId → qty to move
      // Handles partial qty splits (e.g. one DB row with qty=3, moving only 1)
      final Map<String, int> itemQuantitiesToMove = {};
      for (var entry in _selectedItemsQty.entries) {
        final syntheticId = entry.key;
        int remaining = entry.value;
        if (remaining <= 0) continue;

        final uiItem = allItems.firstWhere((e) => e['id'] == syntheticId);
        final List<String> sourceIds = List<String>.from(uiItem['source_ids'] ?? []);

        // Distribute moved qty across source rows (1 unit per row where possible)
        for (final rawId in sourceIds) {
          if (remaining <= 0) break;
          itemQuantitiesToMove[rawId] = (itemQuantitiesToMove[rawId] ?? 0) + 1;
          remaining--;
        }
        // If still remaining (fewer source rows than qty), assign rest to last source row
        if (remaining > 0 && sourceIds.isNotEmpty) {
          itemQuantitiesToMove[sourceIds.last] =
              (itemQuantitiesToMove[sourceIds.last] ?? 0) + remaining;
        }
      }

      await repo.splitOrderGroup(
        sourceGroupId: sourceGroupId!,
        itemQuantitiesToMove: itemQuantitiesToMove,
        targetTableNames: List<String>.from(widget.currentSeats),
      );

      // 3. Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 拆單完成，可繼續拆分")));
        
        // Clear selection and reload to reflect changes (moved items will disappear)
        setState(() {
          _selectedItemsQty.clear();
        });
        await _loadData();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("拆單失敗: $e")));
        setState(() => isLoading = false);
      }
    }
  }

  // Merge Back logic dispatcher
  Future<void> _executeMergeBack() async {
    if (activeOrders.isEmpty) return;
    
    // Check if any active order is part of a Pax Split (Note contains "均分")
    // We check the SELECTED order first. If it's part of a split, we undo that split.
    final currentOrder = activeOrders.firstWhere((o) => o['id'] == sourceGroupId, orElse: () => {});
    final String note = currentOrder['note'] ?? '';
    
    if (note.contains('均分')) {
       await _undoPaxSplit(note);
    } else {
       await _mergeToMainOrder();
    }
  }

  // Scenario 1: Revert Normal Item Split (Merge to Main Order)
  Future<void> _mergeToMainOrder() async {
    final mainOrderId = activeOrders.first['id'];
    if (sourceGroupId == mainOrderId) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("回復至主單?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("此操作將把目前訂單的所有品項合併回「主單 (訂單 1)」，並取消此拆單。", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
           TextButton(onPressed: () => Navigator.pop(context, true), child: Text("確認回復", style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      final repo = ref.read(orderingRepositoryProvider);
      await repo.revertSplit(
        sourceGroupId: sourceGroupId!,
        targetGroupId: mainOrderId,
      );

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 已回復至主單")));
         setState(() {
           sourceGroupId = mainOrderId;
           _selectedItemsQty.clear();
         });
         await _loadData(); 
      }
    } catch (e) {
      debugPrint("Merge back failed: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("回復失敗: $e")));
      setState(() => isLoading = false);
    }
  }

  // Scenario 2: Undo Pax Split (Go Dutch Revert)
  // Reverts items to the "Source" of the Pax Split (e.g. Order X), NOT necessarily Main Order.
  Future<void> _undoPaxSplit(String note) async {
    // 1. Identify the Pax Split Group
    // Regex to match "均分 (x/N)"
    final RegExp regex = RegExp(r'均分 \((\d+)/(\d+)\)');
    final match = regex.firstMatch(note);
    if (match == null) {
      // Fallback to normal merge if parsing fails
      await _mergeToMainOrder();
      return; 
    }
    
    final int totalParts = int.parse(match.group(2)!);
    
    // Find all orders that are part of this split group
    // We assume they are all active and have matching N.
    // NOTE: This assumes only ONE active pax split per table group at a time or we distinguish by N?
    // User said "No matter which order I press... revert to original".
    
    final List<Map<String, dynamic>> splitGroupOrders = activeOrders.where((o) {
      final n = o['note'] ?? '';
      return n.contains('均分') && n.contains('/$totalParts)'); 
    }).toList();

    // Identify Source (The one with index 1/N usually, or just lowest index if multiple?)
    // Actually, traditionally 1/N is the source.
    // Or we can check which one has the "Split Deduction" item? Harder to check without query.
    // Let's assume the one with "1/N" is the source (Parent).
    
    String? sourceId;
    List<String> childIds = [];
    
    for (var o in splitGroupOrders) {
      if ((o['note'] ?? '').contains('(1/$totalParts)')) {
        sourceId = o['id'];
      } else {
        childIds.add(o['id']);
      }
    }
    
    // Fallback: If no 1/N found (maybe changed?), stick to current being source if it has deduction?
    // If sourceId is null, we can't safely revert.
    if (sourceId == null) {
       // Should not happen if logic is consistent
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("無法識別原始訂單，請手動處理")));
       return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("回復均分拆單?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("偵測到此為「按人數均分」的訂單。\n確認要取消均分，並將所有品項回歸至原始訂單嗎？", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
           TextButton(onPressed: () => Navigator.pop(context, true), child: Text("確認回復", style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      final repo = ref.read(orderingRepositoryProvider);
      await repo.revertSplit(
        sourceGroupId: sourceGroupId!, // Current order to revert
        targetGroupId: sourceId,      // The original "1/N" order
      );

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 已取消均分並回復")));
         setState(() {
           sourceGroupId = sourceId; // Go to Source
           _selectedItemsQty.clear();
         });
         await _loadData(); 
      }
    } catch (e) {
      debugPrint("Undo Pax Split failed: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("回復失敗: $e")));
      setState(() => isLoading = false);
    }    
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      indicatorColor: Colors.white,
      tabs: const [
        Tab(text: "按品項拆單"),
        Tab(text: "按人數均分"),
      ],
    );
  }

  Widget _buildTabBody() {
    if (isLoading) return const Center(child: CupertinoActivityIndicator());
    return TabBarView(
      controller: _tabController,
      children: [
        _buildSplitByItemsTab(),
        _buildSplitByPaxTab(),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final isSubOrder = activeOrders.isNotEmpty && sourceGroupId != activeOrders.first['id'];

    if (widget.embedded) {
      return Column(
        children: [
          // Embedded header
          SafeArea(
            bottom: false,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      "拆單",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isSubOrder)
                    IconButton(
                      icon: const Icon(CupertinoIcons.arrow_uturn_left_circle_fill, color: Colors.orange),
                      tooltip: "回復至主單",
                      onPressed: _executeMergeBack,
                    )
                  else
                    IconButton(
                      icon: Icon(CupertinoIcons.xmark, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      onPressed: () => widget.onClose?.call(),
                    ),
                ],
              ),
            ),
          ),
          _buildTabBar(),
          Expanded(child: _buildTabBody()),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("拆單 (桌號: ${widget.currentSeats.join(",")})"),
        backgroundColor: Theme.of(context).cardColor,
        actions: [
          if (isSubOrder)
            IconButton(
              icon: const Icon(CupertinoIcons.arrow_uturn_left_circle_fill, color: Colors.orange),
              tooltip: "回復至主單",
              onPressed: _executeMergeBack,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: _buildTabBar(),
        ),
      ),
      body: _buildTabBody(),
    );
  }

  // --- Tab 1: Items ---
  Widget _buildSplitByItemsTab() {
    return Column(
      children: [
        // Headers
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
          child: Row(
            children: [
              Expanded(
                child: activeOrders.length > 1
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: sourceGroupId,
                            isDense: true,
                            isExpanded: true,
                            icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                            items: activeOrders.asMap().entries.map((entry) {
                              final int idx = entry.key + 1;
                              final Map<String, dynamic> order = entry.value;
                              return DropdownMenuItem(
                                value: order['id'] as String,
                                child: Text(
                                  "訂單 $idx",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null && val != sourceGroupId) {
                                setState(() {
                                  sourceGroupId = val;
                                  _selectedItemsQty.clear();
                                });
                                _loadData();
                              }
                            },
                          ),
                        ),
                      )
                    : Text("原訂單 (\$${leftTotal.toStringAsFixed(0)})", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Icon(CupertinoIcons.arrow_right_arrow_left, size: 20, color: Colors.grey),
              Expanded(child: Text("  新訂單 (\$${rightTotal.toStringAsFixed(0)})", style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Left List (Original)
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final itemId = item['id'];
                    final totalQty = (item['quantity'] as num).toInt();
                    final movedQty = _selectedItemsQty[itemId] ?? 0;
                    
                    if (movedQty == totalQty) return const SizedBox.shrink(); // Fully moved
                    return _buildItemRow(item, isLeft: true, displayQty: totalQty - movedQty);
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              // Right List (New)
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    final itemId = item['id'];
                    final movedQty = _selectedItemsQty[itemId] ?? 0;
                    
                    if (movedQty == 0) return const SizedBox.shrink(); // Hide if not moved at all
                    return _buildItemRow(item, isLeft: false, displayQty: movedQty);
                  },
                ),
              ),
            ],
          ),
        ),
        // Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _selectedItemsQty.clear());
                          _calculateTotals();
                        }, 
                        child: const Text("重置")
                      )
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                          disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          elevation: 0,
                        ),
                          onPressed: _isMoveValid() ? _executeSplitItems : null,
                          child: Text("確認拆出 (${_selectedItemsQty.length})")
                      )
                    ),
                  ],
                ),
                if (!_isMoveValid() && _selectedItemsQty.isNotEmpty)
                   Padding(
                     padding: const EdgeInsets.only(top: 8),
                     child: Text("⚠️ 原訂單不能為空，請至少保留一個品項", style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                   )
              ],
            ),
          ),
        )
      ],
    );
  }

  bool _isMoveValid() {
     if (_selectedItemsQty.isEmpty) return false;
     
     // Cannot move ALL items across the board (Original must have at least 1 remaining quantity overall)
     int totalRemainingQty = 0;
     for (var item in allItems) {
         final itemId = item['id'];
         final totalQty = (item['quantity'] as num).toInt();
         final movedQty = _selectedItemsQty[itemId] ?? 0;
         totalRemainingQty += (totalQty - movedQty);
     }
     if (activeOrders.isNotEmpty && totalRemainingQty == 0) return false;
     
     return true;
  }

  Widget _buildItemRow(Map<String, dynamic> item, {required bool isLeft, required int displayQty}) {
    final price = (item['price'] as num).toDouble();
    
    return InkWell(
      onTap: () => _moveTargetItem(item['id'], toRight: isLeft),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            if (!isLeft) const Icon(CupertinoIcons.arrow_left_circle, color: Colors.red, size: 20),
            if (!isLeft) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['item_name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w500)),
                  Text("\$${(price * displayQty).toStringAsFixed(0)} (x$displayQty)", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                ],
              ),
            ),
            if (isLeft) const SizedBox(width: 8),
            if (isLeft) Icon(CupertinoIcons.arrow_right_circle, color: Theme.of(context).colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // Execute Split by Pax (Go Dutch)
  Future<void> _executeSplitByPax() async {
    if (pax <= 1) return;
    
    // Check if source order is valid
    if (sourceGroupId == null) return;
    
    // Confirm Dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("確認人數均分?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("將總金額 \$$totalAmount 均分為 $pax 份。\n系統將自動產生 ${pax-1} 張新訂單，並加入「分攤餐費」品項。", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
           TextButton(onPressed: () => Navigator.pop(context, true), child: Text("確認", style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold))),
        ],
      )
    );
    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      final repo = ref.read(orderingRepositoryProvider);
      await repo.splitByPax(
        sourceGroupId: sourceGroupId!,
        pax: pax,
        totalAmount: totalAmount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 人數均分完成")));
        await _loadData();
      }
    } catch (e) {
      debugPrint("Split by Pax failed: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("均分失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- Tab 2: Pax ---
  Widget _buildSplitByPaxTab() {
     final perPerson = totalAmount / (pax > 0 ? pax : 1);
     
     return Padding(
       padding: const EdgeInsets.all(24.0),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           const Text("總金額", style: TextStyle(color: Colors.white70, fontSize: 18)),
           const SizedBox(height: 8),
           Text("\$${totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
           
           const SizedBox(height: 40),
           
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               _circleBtn(CupertinoIcons.minus, () {
                 if (pax > 1) setState(() => pax--);
               }),
               Container(
                 width: 120,
                 alignment: Alignment.center,
                 child: Text("$pax 人", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
               ),
               _circleBtn(CupertinoIcons.add, () => setState(() => pax++)),
             ],
           ),
           
           const SizedBox(height: 40),
           Divider(color: Theme.of(context).dividerColor),
           const SizedBox(height: 40),
           
           const Text("每人應付", style: TextStyle(color: Colors.white70, fontSize: 18)),
           const SizedBox(height: 8),
           Text("\$${perPerson.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
           
           const Spacer(),
           
           SizedBox(
             width: double.infinity,
             height: 50,
             child: ElevatedButton(
               style: ElevatedButton.styleFrom(
                 shape: const StadiumBorder(),
                 backgroundColor: Theme.of(context).colorScheme.primary,
                 foregroundColor: Theme.of(context).colorScheme.onPrimary,
                 disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                 disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                 elevation: 0,
               ),
               onPressed: pax > 1 ? _executeSplitByPax : null, 
               child: Text("確認人數均分 ($pax人)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
             ),
           ),
           const SizedBox(height: 16),
           const Text("此操作將產生分攤項目並修改訂單", style: TextStyle(color: Colors.white38, fontSize: 12)),
         ],
       ),
     );
  }

  Widget _circleBtn(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: IconButton(
         icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
         onPressed: onPressed,
      ),
    );
  }
}
