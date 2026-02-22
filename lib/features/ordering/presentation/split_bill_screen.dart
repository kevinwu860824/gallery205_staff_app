import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/ordering_repository.dart';

class SplitBillScreen extends StatefulWidget {
  final String groupKey;
  final List<String> currentSeats;

  const SplitBillScreen({
    super.key,
    required this.groupKey,
    required this.currentSeats,
  });

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderingRepository _repository = OrderingRepository();
  bool isLoading = true;

  // Data
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> activeOrders = []; // List of active orders for these tables
  String? sourceGroupId; // Currently selected source order ID
  
  // Tab 1: Split by Items
  final List<String> _selectedItemIds = []; // Items selected to move to NEW bill
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
      final supabase = Supabase.instance.client;
      
      // 1. Fetch all active orders for these tables (to populate dropdown)
      // This is important because after split, tables have multiple orders.
      // We assume user wants to switch between any order on these tables.
      // Note: We use table_names overlap logic or just fetch by Shop + Tables?
      // Simpler: Fetch all orders where table_names overlap with widget.currentSeats
      // But query array column is tricky. 
      // Alternative: Use the OrderingRepository logic or just fetch by IDs if we knew them.
      // We don't have IDs. 
      // Let's assume we can fetch by shop_id and filter in memory or use 'cs' operator if available.
      // Since currentSeats is List<String>, we iterate manually or use RPC.
      // For now, let's just fetch all 'dining' orders for this shop and filter.
      // Optimization: Fetch only dining orders, fairly small set.
      final hostGroup = await supabase.from('order_groups').select('shop_id').eq('id', widget.groupKey).single();
      final String shopId = hostGroup['shop_id'];

      final allDiningRes = await supabase
          .from('order_groups')
          .select('id, table_names, created_at, pax, note, color_index')
          .eq('shop_id', shopId)
          .eq('status', 'dining')
          .order('created_at', ascending: true);
      
      activeOrders = List<Map<String, dynamic>>.from(allDiningRes).where((order) {
         final List tables = order['table_names'] ?? [];
         // Check intersection
         return tables.any((t) => widget.currentSeats.contains(t));
      }).toList();

      // Ensure sourceGroupId is valid (if not in list, maybe add it? separate fetch? usually it should be in list)
      if (!activeOrders.any((o) => o['id'] == sourceGroupId)) {
         // Should not happen unless status changed.
      }

      // 2. Fetch Items for CURRENT sourceGroupId
      final itemsRes = await supabase
          .from('order_items')
          .select('id, item_name, price, quantity, status')
          .eq('order_group_id', sourceGroupId!)
          .neq('status', 'cancelled'); 
      
      allItems = List<Map<String, dynamic>>.from(itemsRes);
      _calculateTotals();
    } catch (e) {
      debugPrint("Load items error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateTotals() {
    leftTotal = 0;
    rightTotal = 0;
    for (var item in allItems) {
      final price = (item['price'] as num).toDouble();
      final qty = (item['quantity'] as num).toInt();
      final total = price * qty;
      
      if (_selectedItemIds.contains(item['id'])) {
        rightTotal += total;
      } else {
        leftTotal += total;
      }
    }
    totalAmount = leftTotal + rightTotal;
  }

  // Toggle item selection
  void _toggleItem(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
      _calculateTotals();
    });
  }

  // Execute Split by Items (DB Transaction)
  Future<void> _executeSplitItems() async {
    if (_selectedItemIds.isEmpty) return;

    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // 1. Create New Order Group (Sub-order)
      // For simplicity, we assign it to the SAME tables, but it will be a new GLobal Group.
      // To distinguish in UI, we might need a suffix or just rely on multiple groups per table (which we need to support in TableSelection).
      // Let's copy the host's info.
      
      final hostGroup = await supabase.from('order_groups').select('shop_id, table_names, pax').eq('id', widget.groupKey).single();
      final String shopId = hostGroup['shop_id'];
      final List tableNames = hostGroup['table_names'];
      // final int hostPax = hostGroup['pax']; 

      // Create new group
      final newGroupRes = await supabase.from('order_groups').insert({
        'shop_id': shopId,
        'table_names': tableNames, // Same tables
        'status': 'dining',
        'pax': 1, // Default to 1 or 0 for sub-bill
        'note': '拆單 (來自原本的 ${widget.groupKey.substring(0,4)}...) [Parent:${widget.groupKey}]', // ADDED TAG
        'color_index': DateTime.now().millisecondsSinceEpoch % 20 // Random color for distinction
      }).select('id').single();
      
      final String newGroupId = newGroupRes['id'];

      // 2. Move Items
      await supabase
          .from('order_items')
          .update({'order_group_id': newGroupId})
          .inFilter('id', _selectedItemIds);

      // 3. Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 拆單完成，可繼續拆分")));
        
        // Clear selection and reload to reflect changes (moved items will disappear)
        setState(() {
          _selectedItemIds.clear();
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
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("回復至主單?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("此操作將把目前訂單的所有品項合併回「主單 (訂單 1)」，並取消此拆單。", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
           TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("確認回復", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (confirm != true) return;
    
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('order_items')
          .update({'order_group_id': mainOrderId})
          .eq('order_group_id', sourceGroupId!)
          .neq('status', 'cancelled');

      await supabase
          .from('order_groups')
          .update({'status': 'cancelled'})
          .eq('id', sourceGroupId!);

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 已回復至主單")));
         setState(() {
           sourceGroupId = mainOrderId;
           _selectedItemIds.clear();
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
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("回復均分拆單?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("偵測到此為「按人數均分」的訂單。\n確認要取消均分，並將所有品項回歸至原始訂單嗎？", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
           TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("確認回復", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      )
    );
    
    if (confirm != true) return;
    
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    
    try {
      // 1. Delete "Split Share" and "Split Deduction" items from ALL involved orders
      final allInvolvedIds = [sourceId, ...childIds];
      await supabase
          .from('order_items')
          .delete()
          .inFilter('order_group_id', allInvolvedIds)
          .inFilter('item_name', ['分攤餐費 (Split Share)', '拆單扣除 (Split Deduction)']);

      // 2. Move any remaining items from Children to Source
      if (childIds.isNotEmpty) {
        await supabase
            .from('order_items')
            .update({'order_group_id': sourceId})
            .inFilter('order_group_id', childIds)
            .neq('status', 'cancelled');
            
        // 3. Cancel Child Orders
        await supabase
            .from('order_groups')
            .update({'status': 'cancelled'})
            .inFilter('id', childIds);
      }

      // 4. Clean up Source Note (Remove " | 均分 (1/N)" or just "均分 (1/N)")
      // We need to fetch current note again or just use cached? cached is fine.
      final sourceOrder = splitGroupOrders.firstWhere((o) => o['id'] == sourceId);
      String sNote = sourceOrder['note'];
      // Remove regex match
      sNote = sNote.replaceAll(RegExp(r' \| 均分 \(\d+/\d+\)'), '').replaceAll(RegExp(r'均分 \(\d+/\d+\)'), '').trim();
      // Handle leading pipe if any remaining (imperfect cleanup but okay)
      if (sNote.startsWith('| ')) sNote = sNote.substring(2);
      
      await supabase.from('order_groups').update({'note': sNote}).eq('id', sourceId);

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 已取消均分並回復")));
         setState(() {
           sourceGroupId = sourceId; // Go to Source
           _selectedItemIds.clear();
         });
         await _loadData(); 
      }
    } catch (e) {
      debugPrint("Undo Pax Split failed: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("回復失敗: $e")));
      setState(() => isLoading = false);
    }    
  }

  @override
  Widget build(BuildContext context) {
    // Check if current source is NOT main order
    final isSubOrder = activeOrders.isNotEmpty && sourceGroupId != activeOrders.first['id'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("拆單 (桌號: ${widget.currentSeats.join(",")})"),
        backgroundColor: Theme.of(context).cardColor,
        actions: [
          if (isSubOrder)
            IconButton(
              icon: const Icon(CupertinoIcons.arrow_uturn_left_circle_fill, color: Colors.orange), // Custom icon
              tooltip: "回復至主單",
              onPressed: _executeMergeBack,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: "按品項拆單"),
            Tab(text: "按人數均分"),
          ],
        ),
      ),
      body: isLoading 
        ? const Center(child: CupertinoActivityIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildSplitByItemsTab(),
              _buildSplitByPaxTab(),
            ],
          ),
    );
  }

  // --- Tab 1: Items ---
  Widget _buildSplitByItemsTab() {
    return Column(
      children: [
        // Headers
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          color: Theme.of(context).cardColor.withOpacity(0.5),
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
                            final String id = order['id'];
                            
                            return DropdownMenuItem(
                              value: id,
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
                                _selectedItemIds.clear(); // Reset selection on change
                              });
                              _loadData(); // Reload items for new source
                            }
                          },
                        ),
                      ),
                    )
                  : Text("原訂單 (\$${leftTotal.toStringAsFixed(0)})", style: const TextStyle(fontWeight: FontWeight.bold))
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
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    if (_selectedItemIds.contains(item['id'])) return const SizedBox.shrink(); // Hide if moved
                    return _buildItemRow(item, isLeft: true);
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              // Right List (New)
              Expanded(
                child: ListView.builder(
                  itemCount: allItems.length,
                  itemBuilder: (context, index) {
                    final item = allItems[index];
                    if (!_selectedItemIds.contains(item['id'])) return const SizedBox.shrink(); // Hide if not moved
                    return _buildItemRow(item, isLeft: false);
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
                          setState(() => _selectedItemIds.clear());
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
                          disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                          disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                          elevation: 0,
                        ),
                          onPressed: (_selectedItemIds.isEmpty || (allItems.length - _selectedItemIds.length < 1)) ? null : _executeSplitItems,
                          child: Text("確認拆出 (${_selectedItemIds.length})")
                      )
                    ),
                  ],
                ),
                if (activeOrders.length > 0 && (allItems.length - _selectedItemIds.length < 1) && _selectedItemIds.isNotEmpty)
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

  Widget _buildItemRow(Map<String, dynamic> item, {required bool isLeft}) {
    final price = (item['price'] as num).toDouble();
    final qty = (item['quantity'] as num).toInt();
    
    return InkWell(
      onTap: () => _toggleItem(item['id']),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
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
                  Text("\$${(price * qty).toStringAsFixed(0)} (x$qty)", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
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
        content: Text("將總金額 \$$totalAmount 均分為 $pax 份。\n系統將自動產生 ${pax-1} 張新訂單，並加入「分攤餐費」品項。", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
           TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("確認", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      )
    );
    if (confirm != true) return;

    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // 1. Fetch Source Group Details
      final sourceGroup = await supabase.from('order_groups').select().eq('id', sourceGroupId!).single();
      final String shopId = sourceGroup['shop_id'];
      final List tableNames = sourceGroup['table_names'];
      final double perPerson = totalAmount / pax;
      
      // 2. Create N-1 New Orders
      for (int i = 2; i <= pax; i++) {
        final newGroupRes = await supabase.from('order_groups').insert({
          'shop_id': shopId,
          'table_names': tableNames,
          'status': 'dining',
          'pax': 1,
          'note': '均分 (${i}/$pax) [Parent:$sourceGroupId]', // ADDED TAG
          'color_index': (DateTime.now().millisecondsSinceEpoch + i) % 20 
        }).select('id').single();
        
        final String newGroupId = newGroupRes['id'];
        
        // Add "Split Share" Item to New Order
        await supabase.from('order_items').insert({
          'order_group_id': newGroupId,
          'item_name': '分攤餐費 (Split Share)',
          'price': perPerson,
          'quantity': 1,
          'status': 'served', // Auto served
        });
      }
      
      // 3. Update Source Order: Add "Split Deduction" Item
      // Deduct (Total - Share) to leave exactly 1 Share in Source
      // Offset = -(Total - Share) = -(Share * (Pax - 1))
      // Or we can add a negative item.
      final double deduction = -(totalAmount - perPerson);
      
      await supabase.from('order_items').insert({
          'order_group_id': sourceGroupId!,
          'item_name': '拆單扣除 (Split Deduction)',
          'price': deduction,
          'quantity': 1,
          'status': 'served',
      });
      
      // 4. Update Source Order Note
      final String oldNote = sourceGroup['note'] ?? '';
      final String newNote = oldNote.isEmpty ? '均分 (1/$pax)' : '$oldNote | 均分 (1/$pax)';
      await supabase.from('order_groups').update({'note': newNote}).eq('id', sourceGroupId!);

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
           Text("總金額", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 18)),
           const SizedBox(height: 8),
           Text("\$${totalAmount.toStringAsFixed(0)}", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 40, fontWeight: FontWeight.bold)),
           
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
                 child: Text("$pax 人", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 32, fontWeight: FontWeight.bold)),
               ),
               _circleBtn(CupertinoIcons.add, () => setState(() => pax++)),
             ],
           ),
           
           const SizedBox(height: 40),
           Divider(color: Theme.of(context).dividerColor),
           const SizedBox(height: 40),
           
           Text("每人應付", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 18)),
           const SizedBox(height: 8),
           Text("\$${perPerson.toStringAsFixed(0)}", style: const TextStyle(color: Color(0xFF32D74B), fontSize: 48, fontWeight: FontWeight.bold)),
           
           const Spacer(),
           
           SizedBox(
             width: double.infinity,
             height: 50,
             child: ElevatedButton(
               style: ElevatedButton.styleFrom(
                 shape: const StadiumBorder(),
                 backgroundColor: Theme.of(context).colorScheme.primary,
                 foregroundColor: Theme.of(context).colorScheme.onPrimary,
                 disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                 disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                 elevation: 0,
               ),
               onPressed: pax > 1 ? _executeSplitByPax : null, 
               child: Text("確認人數均分 ($pax人)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
             ),
           ),
           const SizedBox(height: 16),
           const Text("此操作將產生分攤項目並修改訂單", style: TextStyle(color: Colors.grey, fontSize: 12)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: IconButton(
         icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
         onPressed: onPressed,
      ),
    );
  }
}
