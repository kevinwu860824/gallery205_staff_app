// lib/features/ordering/presentation/table_selection_screen_v2.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../domain/repositories/ordering_repository.dart';
import '../domain/repositories/session_repository.dart'; // NEW
import '../data/repositories/ordering_repository_impl.dart';
import '../data/datasources/ordering_remote_data_source.dart';
import '../domain/models/table_model.dart';
import '../domain/entities/order_item.dart';

// -------------------------------------------------------------------
// 1. 樣式與色盤定義
// -------------------------------------------------------------------

class TableSelectionScreenV2 extends StatefulWidget {
  const TableSelectionScreenV2({super.key});

  @override
  State<TableSelectionScreenV2> createState() => _TableSelectionScreenV2State();
}

class _TableSelectionScreenV2State extends State<TableSelectionScreenV2> {
  OrderingRepository? _orderingRepo;
  SessionRepository? _sessionRepo;
  
  List<AreaModel> areas = [];
  String? selectedAreaId;
  List<TableModel> tables = [];
  bool isLoading = true;

  final Set<String> _selectedEmptyTables = {};

  bool _isDialogOpen = false;
  bool _isShiftClosed = false;
  
  int unsyncedCount = 0;
  int failedPrintCount = 0;

  RealtimeChannel? _subscription;
  StreamSubscription? _printTaskSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _checkShiftStatus().then((_) => _initData());
    _subscribeToRealtime();
    
    // Auto Refresh every 10 seconds (User request)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
       if (mounted) {
          _checkFailedPrints();
          _checkSyncStatus();
          // Also refresh tables if we have a selected area
          if (selectedAreaId != null) {
              // Use a 'silent' load to avoid loading spinner flickering if desired?
              // Existing _loadTablesForArea sets isLoading=true. 
              // We should create a silent refresh method or modify _loadTablesForArea.
              _silentRefreshTables();
          }
       }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _printTaskSubscription?.cancel();
    if (_subscription != null) {
      Supabase.instance.client.removeChannel(_subscription!);
      _subscription = null;
    }
    super.dispose();
  }

  Future<void> _subscribeToRealtime() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final client = Supabase.instance.client;
    // Listen to changes in order_groups to refresh table status
    _subscription = client.channel('public:order_groups:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_groups',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
             debugPrint("Realtime update received: ${payload.eventType}");
             if (selectedAreaId != null && mounted) {
                // Throttle? Or just reload. 
                // Delay slightly to ensure DB consistency if needed, but usually instant.
                _loadTablesForArea(selectedAreaId!);
             }
          },
        )
        .subscribe();
  }

  Future<void> _ensureRepository() async {
    if (_orderingRepo == null || _sessionRepo == null) {
      final prefs = await SharedPreferences.getInstance();
      final client = Supabase.instance.client;
      final dataSource = OrderingRemoteDataSourceImpl(client);
      final impl = OrderingRepositoryImpl(dataSource, prefs);
      _orderingRepo = impl;
      _sessionRepo = impl;
    }

    // Always ensure listener is active
    if (_printTaskSubscription == null) {
        _printTaskSubscription = _orderingRepo!.onPrintTaskUpdate.listen((_) {
           _checkFailedPrints();
        });
        // Initial check logic moved here or called by caller? 
        // Caller _initData calls it via _checkSyncStatus usually? No.
        // Let's explicitly check once we have a listener.
        _checkFailedPrints();
    }
  }

  Future<void> _checkShiftStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;
    
    try {
      final res = await Supabase.instance.client.rpc('rpc_get_current_cash_status', params: {'p_shop_id': shopId}).single();
      if (res['status'] != 'OPEN') {
        if (mounted) {
           setState(() => _isShiftClosed = true);
           _showShiftClosedDialog();
        }
      }
    } catch (e) {
      debugPrint("Check shift status failed: $e");
    }
  }

  Future<void> _checkSyncStatus() async {
    _ensureRepository();
    if (_orderingRepo != null) {
       final count = await _orderingRepo!.getUnsyncedOrdersCount();
       if (mounted && count != unsyncedCount) {
          setState(() => unsyncedCount = count);
       }
       _checkFailedPrints();
    }
  }

  Future<void> _checkFailedPrints() async {
    if (_orderingRepo != null) {
      try {
        final items = await _orderingRepo!.fetchFailedPrintItems();
        if (mounted && items.length != failedPrintCount) {
           setState(() => failedPrintCount = items.length);
        }
      } catch (_) {}
    }
  }

  Future<void> _triggerManualSync() async {
     setState(() => isLoading = true);
     await _orderingRepo!.syncOfflineOrders();
     await _checkSyncStatus();
     setState(() => isLoading = false);
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("同步完成")));
  }

  void _showShiftClosedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: _DarkStyleDialog(
          title: "尚未開班",
          contentWidget: const Text("請先至【關帳】進行開班，\n才能開始進行點餐作業。", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
          onConfirm: () => context.go('/cashSettlement'),
          confirmText: "前往開班",
          onCancel: () => context.go('/home'),
          cancelText: "返回首頁",
        ),
      ),
    );
  }

  Future<void> _initData() async {
    setState(() => isLoading = true);
    await _ensureRepository();
    
    try {
      final fetchedAreas = await _sessionRepo!.fetchAreas();
      if (fetchedAreas.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final lastArea = prefs.getString('last_selected_area');
        
        final initialArea = fetchedAreas.any((a) => a.id == lastArea) 
            ? lastArea 
            : fetchedAreas.first.id;

        areas = fetchedAreas;
        selectedAreaId = initialArea;
        await _loadTablesForArea(initialArea!);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadTablesForArea(String areaId) async {
    setState(() => isLoading = true);
    await _silentRefreshTables(areaIdOverride: areaId);
    if(mounted) setState(() {
       selectedAreaId = areaId;
       isLoading = false;
    });
  }

  Future<void> _silentRefreshTables({String? areaIdOverride}) async {
    final targetArea = areaIdOverride ?? selectedAreaId;
    if (targetArea == null) return;
    
    await _ensureRepository();
    // Do NOT clear _selectedEmptyTables on silent refresh to avoid losing selection state while user is active
    if(areaIdOverride != null) _selectedEmptyTables.clear(); 

    try {
      final fetchedTables = await _sessionRepo!.fetchTablesInArea(targetArea);
      if(areaIdOverride != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_selected_area', areaIdOverride);
      }

      if (mounted) {
         setState(() {
            tables = fetchedTables;
         });
      }
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // 互動邏輯
  // ----------------------------------------------------------------

  void _onTableTap(TableModel table) {
    if (table.status == TableStatus.occupied) {
      _showOccupiedActionMenu(table);
    } else {
      setState(() {
        if (_selectedEmptyTables.contains(table.tableName)) {
          _selectedEmptyTables.remove(table.tableName);
        } else {
          _selectedEmptyTables.add(table.tableName);
        }
      });
    }
  }
  


  // 顯示「開桌」的人數輸入視窗
  Future<void> _showPaxDialog() async {
    setState(() => _isDialogOpen = true);
    final paxController = TextEditingController();
    
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DarkStyleDialog(
        title: '入座確認: ${_selectedEmptyTables.join(", ")}',
        contentWidget: Column(
          children: [
            Text('請輸入用餐人數', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CupertinoTextField(
                controller: paxController,
                keyboardType: TextInputType.number,
                placeholder: '人數',
                autofocus: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
                decoration: null,
              ),
            ),
          ],
        ),
        onCancel: () => Navigator.pop(context),
        onConfirm: () {
          final pax = int.tryParse(paxController.text);
          if (pax != null && pax > 0) {
            Navigator.pop(context, pax);
          }
        },
      ),
    );

    if (result == null) {
      setState(() => _isDialogOpen = false);
    } else {
      await _createNewOrderGroup(result);
      setState(() => _isDialogOpen = false);
    }
  }

  Future<void> _onTableDoubleTap(TableModel table) async {
    // Only applies to Occupied Tables
    if (table.currentOrderGroupId == null || table.activeOrderGroupIds.isEmpty) return;

    final String orderId = table.currentOrderGroupId!;
    
    // Find all tables in this group
    final sameGroupTables = tables
        .where((t) => t.activeOrderGroupIds.contains(orderId))
        .map((t) => t.tableName)
        .toList();
    if (sameGroupTables.isEmpty) sameGroupTables.add(table.tableName);
    sameGroupTables.sort();

    // Navigate directly to Add Order screen
    await context.push('/order', extra: {
      'tableNumbers': sameGroupTables,
      'orderGroupId': orderId,
      'isNewOrder': false,
    });
    
    // Refresh on return
    if (selectedAreaId != null && mounted) {
      await _loadTablesForArea(selectedAreaId!);
    }
  }

  Future<void> _createNewOrderGroup(int pax) async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      
      if (shopId != null) {
        // Use Repository indirectly? Or DataSource?
        // Actually Repository submitOrder handles create logic but specifically for Order Submission.
        // We create an Empty Order Group here. Repository doesn't expose createOrderGroup strictly.
        // let's add `createEmptyOrderGroup` to Repository or use RemoteDataSource via Repo?
        // To follow refactor plan strictly, we might want to move this to Repository too.
        // For now, let's keep this as is OR move to repository.
        // To speed up, let's just fix the CLEAR TABLE and UPDATE functions first as requested.
        
        // Wait, the plan said "Refactor Screens to use Repository".
        // Let's refactor this too.
        
        // However, I didn't add createOrderGroup to Repository Interface yet.
        // Let's stick to the ones I added: clearTable, updatePax, updateNote.
        
        // Re-implement existing logic using direct Supabase for creation (unchanged for now)
        // OR add to logic.
        
        String? currentOpenId;
        try {
          final res = await Supabase.instance.client.rpc(
            'rpc_get_current_cash_status', 
            params: {'p_shop_id': shopId}
          ).maybeSingle();
          
          if (res != null && res['status'] == 'OPEN') {
             currentOpenId = res['open_id'] as String?;
          }
        } catch (e) {
          debugPrint("Error fetching open_id in TableSelection: $e");
        }

        await Supabase.instance.client.from('order_groups').insert({
          'shop_id': shopId,
          'table_names': _selectedEmptyTables.toList(),
          'pax': pax,
          'status': 'dining', // Use Constant later
          'open_id': currentOpenId,
        });
        
        _selectedEmptyTables.clear();
        if (selectedAreaId != null) {
          await _loadTablesForArea(selectedAreaId!);
        }
      }
    } catch (e) {
      debugPrint("開桌失敗: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("開桌失敗，請重試")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 🔥 [Refactored] Use Repository
  Future<void> _processClearTable(TableModel table, {String? targetGroupId}) async {
    final String groupId = targetGroupId ?? table.currentOrderGroupId!;

    // Display Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CupertinoActivityIndicator(color: Colors.white)),
    );

    try {
      if (_sessionRepo == null) await _ensureRepository();
      await _sessionRepo!.clearSession({'current_order_group_id': groupId}, targetGroupId: groupId);
      
      if (mounted) {
        Navigator.pop(context); // Close Loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("桌號 ${table.tableName} 已清桌"))
        );
        // Refresh
        if (selectedAreaId != null) _loadTablesForArea(selectedAreaId!);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close Loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("清桌失敗: $e")));
      }
    }
  }



  void _showOccupiedActionMenu(TableModel table, {String? overrideOrderGroupId}) {
    final parentContext = context; // Capture parent context for navigation
    final List<String> sortedOrderIds = List.from(table.activeOrderGroupIds);
    if (sortedOrderIds.isEmpty && table.currentOrderGroupId != null) sortedOrderIds.add(table.currentOrderGroupId!);
    
    // Default to the *First* (Main) or *Last*?
    // User said "Main 1, Split 2...". 
    // Usually "Main" is the one you want? Or "Latest"?
    // Let's default to the ONE that is currently assigned to the table (usually latest),
    // OR default to the FIRST one (Main)? 
    // Let's default to the `table.currentOrderGroupId` (which is latest/active).
    // And allow switching.
    
    // Default to the *First* (Main) order as per user request
    String currentSelectedId = overrideOrderGroupId ?? (sortedOrderIds.isNotEmpty ? sortedOrderIds.first : table.currentOrderGroupId!);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            
            // Re-calculate sameGroupTables for the selected ID
            final sameGroupTables = tables
                .where((t) => t.activeOrderGroupIds.contains(currentSelectedId))
                .map((t) => t.tableName)
                .toList();
            if (sameGroupTables.isEmpty) sameGroupTables.add(table.tableName);
            sameGroupTables.sort();

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor, 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [


                            FutureBuilder<Map<String, dynamic>>(
                              future: Supabase.instance.client
                                  .from('order_groups')
                                  .select('note')
                                  .eq('id', currentSelectedId) // Use currentSelectedId
                                  .single(),
                              builder: (context, snapshot) {
                                String noteText = "";
                                if (snapshot.hasData && snapshot.data!['note'] != null) {
                                  noteText = snapshot.data!['note'].toString();
                                }

                                return RichText(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface, 
                                      fontSize: 22, 
                                      fontWeight: FontWeight.bold,
                                      fontFamily: '.SF Pro Text'
                                    ),
                                    children: [
                                      TextSpan(text: "桌號：${sameGroupTables.join(", ")}"),
                                      if (noteText.isNotEmpty)
                                        TextSpan(
                                          text: " ($noteText)",
                                          style: const TextStyle(color: Color(0xFFFF9F0A), fontSize: 18),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "單號：...${currentSelectedId.substring(currentSelectedId.length - 6)}", // Use currentSelectedId
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(CupertinoIcons.xmark_circle_fill, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 28),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Grid Action Buttons ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,       
                    crossAxisSpacing: 16,    
                    mainAxisSpacing: 16,    
                    childAspectRatio: 0.75,  
                    children: [
                      _buildGlassActionBtn(
                        context, "點菜", CupertinoIcons.cart_fill, 
                        color: const Color(0xFF0A84FF),
                        onTap: () {
                          Navigator.pop(sheetContext); 
                          context.push('/order', extra: {
                            'tableNumbers': sameGroupTables,
                            'orderGroupId': currentSelectedId, // Use currentSelectedId
                            'isNewOrder': false,
                          }).then((_) => _loadTablesForArea(selectedAreaId!));
                        }
                      ),
                      _buildGlassActionBtn(
                        context, "調整人數", CupertinoIcons.person_2_fill, 
                        onTap: () { 
                          Navigator.pop(sheetContext); 
                          _showUpdatePaxDialog(currentSelectedId); // Use currentSelectedId
                        }
                      ),
                      _buildGlassActionBtn(
                        context, "換桌", CupertinoIcons.arrow_right_arrow_left, 
                        onTap: () async { 
                          Navigator.pop(sheetContext);
                          await context.push('/moveTable', extra: {
                            'groupKey': currentSelectedId, // Use currentSelectedId
                            'currentSeats': sameGroupTables
                          });
                          if (selectedAreaId != null && mounted) {
                            await _loadTablesForArea(selectedAreaId!);
                          }
                        }
                      ),
                      _buildGlassActionBtn(
                        context, "併桌/拆桌", CupertinoIcons.arrow_down_right_arrow_up_left, 
                        onTap: () async { 
                          Navigator.pop(sheetContext);
                          await _handleMergeOrUnmergeTap(currentSelectedId, sameGroupTables); // Use currentSelectedId
                        }
                      ),
                      _buildGlassActionBtn(
                        context, "桌位資訊", CupertinoIcons.info_circle_fill, 
                        onTap: () {
                          Navigator.pop(sheetContext); 
                          context.push('/tableInfo', extra: {
                            'tableName': sameGroupTables.join(", "),
                            'orderGroupId': currentSelectedId, // Use currentSelectedId
                          });
                        }
                      ),
                      _buildGlassActionBtn(
                        context, "拆單", CupertinoIcons.scissors, 
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await parentContext.push('/splitBill', extra: {'groupKey': currentSelectedId, 'currentSeats': sameGroupTables}); 
                          
                          if (selectedAreaId != null && mounted) {
                            await _loadTablesForArea(selectedAreaId!);
                          }
                        }
                      ),
                      _buildGlassActionBtn(
                        context, "整單備註", CupertinoIcons.doc_text_fill, 
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _showNoteDialog(currentSelectedId); // Note dialog might update note, but doesn't change structure. But refreshing is safe.
                          // Actually _showNoteDialog doesn't navigate away, it shows dialog on top.
                          // But we popped sheetContext.
                          // If _showNoteDialog is async and waits for dialog, we can refresh.
                          
                          if (selectedAreaId != null && mounted) {
                             await _loadTablesForArea(selectedAreaId!);
                          }
                        }
                      ),
                      _buildGlassActionBtn(
                        context, "列印結帳單", CupertinoIcons.printer, 
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          
                          String targetId = currentSelectedId;

                          if (sortedOrderIds.length > 1) {
                            final String? selected = await showDialog<String>(
                              context: parentContext,
                              builder: (context) => SimpleDialog(
                                title: const Text("請選擇要列印的訂單"),
                                children: List.generate(sortedOrderIds.length, (index) {
                                  final id = sortedOrderIds[index];
                                  return SimpleDialogOption(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                    onPressed: () => Navigator.pop(context, id),
                                    child: Text("訂單 ${index + 1}", style: const TextStyle(fontSize: 16)),
                                  );
                                }),
                              ),
                            );
                            if (selected == null) return; // Cancelled
                            targetId = selected;
                          }

                          if (mounted) {
                            parentContext.push('/printBill', extra: {
                              'groupKey': targetId,
                              'title': '結帳單 (預結)',
                            });
                          }
                        }
                      ),
                      _buildGlassActionBtn(
                        context, "結帳", CupertinoIcons.money_dollar_circle_fill, 
                        color: const Color(0xFF32D74B),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          
                          String targetId = currentSelectedId;

                          if (sortedOrderIds.length > 1) {
                            final String? selected = await showDialog<String>(
                              context: parentContext,
                              builder: (context) => SimpleDialog(
                                title: const Text("請選擇要結帳的訂單"),
                                children: List.generate(sortedOrderIds.length, (index) {
                                  final id = sortedOrderIds[index];
                                  return SimpleDialogOption(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                    onPressed: () => Navigator.pop(context, id),
                                    child: Text("訂單 ${index + 1}", style: const TextStyle(fontSize: 16)),
                                  );
                                }),
                              ),
                            );
                            if (selected == null) return; // Cancelled
                            targetId = selected;
                          }

                          await parentContext.push('/payment', extra: {
                            'groupKey': targetId, // Use selected targetId
                            'totalAmount': 0.0, // Calculated internally
                          });
                          
                          if (selectedAreaId != null && mounted) {
                            await _loadTablesForArea(selectedAreaId!);
                          }
                        }
                      ),
                      // Destructive
                      _buildGlassActionBtn(
                        context, 
                        "顧客離開", 
                        CupertinoIcons.person_crop_circle_badge_xmark, 
                        isDestructive: true, 
                        onTap: () async {
                          Navigator.pop(sheetContext); 

                          final targetGroupId = currentSelectedId.isNotEmpty ? currentSelectedId : table.currentOrderGroupId;
                          if (targetGroupId == null) return;

                          showDialog(
                            context: parentContext,
                            barrierDismissible: false,
                            builder: (c) => const Center(child: CupertinoActivityIndicator(color: Colors.white)),
                          );

                          try {
                            final supabase = Supabase.instance.client;
                            
                            // Check for ANY items (even cancelled ones? No, user said "no items" -> delete. "Has items" -> void.)
                            // But usually "Has items" implies "Has ACTIVE items" to worth voiding.
                            // If has only cancelled items? It's effectively empty/voided properly.
                            // The logic: "If order has no items" -> delete. "If order has items" -> void.
                            
                            // Check total count to decide if Void (keeps history) or Delete (no history)
                            final totalItemsCount = await supabase
                                .from('order_items')
                                .count(CountOption.exact)
                                .eq('order_group_id', targetGroupId);

                            if (mounted) Navigator.pop(parentContext); // Close loading

                            if (totalItemsCount > 0) {
                               // Has items (active or cancelled). 
                               // Logic: Confim Leave -> Void.
                               if (mounted) {
                                 final bool? confirm = await showDialog<bool>(
                                   context: parentContext,
                                   builder: (context) => AlertDialog(
                                     backgroundColor: Theme.of(context).cardColor,
                                     title: Text("確認顧客離開？", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                     content: Text(
                                       "此桌尚有品項 (或是已作廢品項)。\n確認離開將會把此訂單視為「已作廢」並結束。",
                                       style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                     ),
                                     actions: [
                                       TextButton(
                                         onPressed: () => Navigator.pop(context, false),
                                         child: Text("返回", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                       ),
                                       TextButton(
                                         onPressed: () => Navigator.pop(context, true),
                                         child: Text("確認離開", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                       ),
                                     ],
                                   ),
                                 );
                                 
                                 if (confirm == true) {
                                    // Execute Void
                                    // Use VoidOrderGroup from OrderingRepo
                                    if (_orderingRepo == null) await _ensureRepository();
                                    await _orderingRepo!.voidOrderGroup(targetGroupId);
                                    
                                    if (mounted) {
                                       ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(content: Text("訂單已作廢並結束")));
                                       if (selectedAreaId != null) _loadTablesForArea(selectedAreaId!);
                                    }
                                 }
                               }
                            } else {
                               // No items at all -> Delete (Don't record)
                               if (_sessionRepo == null) await _ensureRepository();
                               await _sessionRepo!.deleteOrderGroup(targetGroupId);

                               if (mounted) {
                                  ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(content: Text("已清空 (無交易紀錄)")));
                                  if (selectedAreaId != null) _loadTablesForArea(selectedAreaId!);
                               }
                            }
                          } catch (e) {
                            if (mounted && Navigator.canPop(parentContext)) Navigator.pop(parentContext); // Ensure loading closed
                            debugPrint("Check error: $e");
                            if(mounted) ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text("操作失敗: $e")));
                          }
                        }
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Refactored to match Home Screen Design
  Widget _buildGlassActionBtn(
    BuildContext context, 
    String label, 
    IconData icon, {
    Color? color, 
    required VoidCallback onTap,
    bool isDestructive = false, 
  }) {
    const double iconSize = 62.0; 
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    // Icon Color: Use passed color, or Primary, or Red if destructive
    final Color iconColor = isDestructive 
        ? const Color(0xFFFF453A) 
        : (color ?? Theme.of(context).colorScheme.primary);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              color: Theme.of(context).cardColor, // Consistent background
              boxShadow: isLight ? [
                 BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : null,
              border: isDestructive 
                  ? Border.all(color: const Color(0xFFFF453A).withOpacity(0.5)) 
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                color: iconColor,
                size: 30.0,
              ),
            ),
          ),
          
          const SizedBox(height: 4.0),
          
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDestructive ? const Color(0xFFFF453A) : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // [功能 2] 調整人數
  Future<void> _showUpdatePaxDialog(String orderGroupId) async {
    int currentPax = 0;
    try {
      final res = await Supabase.instance.client
          .from('order_groups')
          .select('pax')
          .eq('id', orderGroupId)
          .single();
      currentPax = res['pax'] ?? 0;
    } catch (e) {
      debugPrint("無法讀取目前人數: $e");
    }

    if (!mounted) return;

    final paxController = TextEditingController(text: currentPax.toString());

    await showDialog(
      context: context,
      builder: (context) => _DarkStyleDialog(
        title: "調整人數",
        contentWidget: Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(8)),
          child: CupertinoTextField(
            controller: paxController,
            keyboardType: TextInputType.number,
            placeholder: "輸入新的人數",
            padding: const EdgeInsets.all(12),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
            autofocus: true,
          ),
        ),
        onCancel: () => Navigator.pop(context),
        onConfirm: () async {
          final newPax = int.tryParse(paxController.text);
          if (newPax != null && newPax > 0) {
            try {
              if (_sessionRepo == null) await _ensureRepository();
              await _sessionRepo!.updatePax(orderGroupId, newPax);
              
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("人數已更新")));
            } catch (e) {
              debugPrint("更新人數失敗: $e");
            }
          }
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // [功能] 整單備註
  Future<void> _showNoteDialog(String orderGroupId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator(color: Colors.white)),
    );

    String currentNote = '';

    try {
      final res = await Supabase.instance.client
          .from('order_groups')
          .select('note')
          .eq('id', orderGroupId)
          .single();
      
      if (res['note'] != null) {
        currentNote = res['note'].toString();
      }
    } catch (e) {
      debugPrint("讀取備註失敗: $e");
    }

    if (!mounted) return;
    Navigator.pop(context); 

    final noteController = TextEditingController(text: currentNote);

    await showDialog(
      context: context,
      builder: (context) => _DarkStyleDialog(
        title: "整單備註",
        contentWidget: Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(8)),
          child: CupertinoTextField(
            controller: noteController,
            placeholder: "例如：VIP、壽星、不吃牛...",
            maxLines: 3,
            padding: const EdgeInsets.all(12),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
            autofocus: true,
          ),
        ),
        onCancel: () => Navigator.pop(context),
        onConfirm: () async {
          final note = noteController.text.trim();
          try {
            if (_orderingRepo == null) await _ensureRepository();
            await _orderingRepo!.updateOrderGroupNote(orderGroupId, note);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("備註已更新")));
              Navigator.pop(context); 
              if (selectedAreaId != null) {
                _loadTablesForArea(selectedAreaId!);
              }
            }
          } catch (e) {
            debugPrint("更新備註失敗: $e");
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("更新失敗")));
          }
        },
      ),
    );
  }

  // 處理「併桌/拆桌」按鈕點擊
  Future<void> _handleMergeOrUnmergeTap(String groupId, List<String> currentSeats) async {
    // 1. 檢查此 Group 是否包含合併進來的子群組
    final supabase = Supabase.instance.client;
    final mergedChildren = await supabase
        .from('order_groups')
        .select('id')
        .eq('status', 'merged')
        .eq('merged_target_id', groupId);
    
    // 2. 如果沒有子群組 -> 進入一般的併桌選擇畫面
    if (mergedChildren.isEmpty) {
      if (!mounted) return;
      await context.push('/mergeTable', extra: {
        'groupKey': groupId, 
        'currentSeats': currentSeats
      });
      if (selectedAreaId != null && mounted) {
        await _loadTablesForArea(selectedAreaId!);
      }
      return;
    }

    // 3. 如果有子群組 -> 顯示 Quick Un-merge Dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => _DarkStyleDialog(
        title: "是否回復原桌位？",
        contentWidget: Text(
          "此訂單包含了 ${mergedChildren.length} 桌合併的桌位。\n確認後將自動拆分並歸還至原本的桌號。",
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
        ),
        onCancel: () => Navigator.pop(context),
        onConfirm: () async {
          Navigator.pop(context); // Close dialog
          await _executeQuickUnmerge(groupId, currentSeats, mergedChildren);
        },
      ),
    );
  }

  // 執行快速拆桌 (還原)
  Future<void> _executeQuickUnmerge(String hostGroupId, List<String> hostSeats, List<dynamic> mergedChildrenRows) async {
    setState(() => isLoading = true);
    
    try {
      if (_sessionRepo == null) await _ensureRepository();

      final List<String> childGroupIds = mergedChildrenRows.map((r) => r['id'] as String).toList();
      
      await _sessionRepo!.unmergeOrderGroups(
        hostGroupId: hostGroupId,
        targetGroupIds: childGroupIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 已回復原桌位")));
        if (selectedAreaId != null) {
          await _loadTablesForArea(selectedAreaId!);
        }
      }

    } catch (e) {
      debugPrint("Unmerge error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("拆桌失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showFailedPrintsDialog() async {
    _ensureRepository();
    if (_orderingRepo == null) return;
    await showDialog(
      context: context,
      builder: (context) => _FailedPrintsDialog(repository: _orderingRepo!),
    );
    _checkFailedPrints(); // Refresh after dialog close
  }

  @override
  Widget build(BuildContext context) {
    final safePaddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. 桌位地圖
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: isLoading 
              ? Center(child: CupertinoActivityIndicator(color: Theme.of(context).colorScheme.onSurface))
              : InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(500),
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: Stack(
                    children: tables.map((table) => _buildSingleTable(table)).toList(),
                  ),
                ),
          ),

          // 2. Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
              padding: EdgeInsets.only(top: safePaddingTop + 10, bottom: 10, left: 16, right: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(CupertinoIcons.back, color: Theme.of(context).colorScheme.onSurface, size: 28),
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: areas.map((area) {
                          final isSelected = area.id == selectedAreaId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () => _loadTablesForArea(area.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  area.id,
                                  style: TextStyle(
                                    color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.list_bullet, color: Theme.of(context).colorScheme.onSurface, size: 28),
                    onPressed: () => context.push('/orderHistory', extra: {'currentShiftOnly': true}),
                  ),
                  const SizedBox(width: 5),
                  // Sync Button
                  if (unsyncedCount > 0)
                     IconButton(
                        icon: const Icon(CupertinoIcons.cloud_upload_fill, color: Colors.amber, size: 28),
                        onPressed: _triggerManualSync,
                        tooltip: "有 $unsyncedCount 筆未同步訂單",
                     ),
                  const SizedBox(width: 5),
                  // Printer Button with Badge
                  Badge(
                    isLabelVisible: failedPrintCount > 0,
                    label: Text("$failedPrintCount"),
                    child: IconButton(
                      icon: Icon(CupertinoIcons.printer, color: Theme.of(context).colorScheme.onSurface, size: 28),
                      onPressed: _showFailedPrintsDialog,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. 底部按鈕
          if (_selectedEmptyTables.isNotEmpty && !_isDialogOpen)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🔥 [修正] 使用 Expanded 避免 Overflow
                    Expanded(
                      child: Text(
                        "已選 ${_selectedEmptyTables.length} 桌: ${_selectedEmptyTables.join(", ")}",
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      color: Theme.of(context).colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(20),
                      minSize: 0,
                      onPressed: _showPaxDialog, 
                      child: Text("確認入座", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleTable(TableModel table) {
    // Define groupColors locally
    const List<Color> _groupColors = [
      Color(0xFF0A84FF), // Blue
      Color(0xFF32D74B), // Green
      Color(0xFFFF9F0A), // Orange
      Color(0xFFFF453A), // Red
      Color(0xFF5E5CE6), // Indigo
      Color(0xFFBF5AF2), // Purple
      Color(0xFF64D2FF), // Light Blue
      Color(0xFF30D158), // Emerald Green
      Color(0xFFD1D1D6), // Light Grey
    ];

    Color tableColor;
    
    // 4. 空桌樣式 (使用 Theme onSurface 或 disabled color，或 maintaining white for contrast if needed)
    // 但因為 Theme 可以切換，我們最好使用 Theme colors。
    tableColor = Theme.of(context).disabledColor; // Or similar
    if (_selectedEmptyTables.contains(table.tableName)) {
      tableColor = const Color(0xFF4CD964); // Selected Green (keep for visibility)
    } else {
      tableColor = Theme.of(context).colorScheme.onSurface; // Default text color (e.g. White or Black)
    }
    
    // 5. 使用群組顏色
    if (table.status == TableStatus.occupied && table.currentOrderGroupId != null) {
      if (table.colorIndex != null) {
        // Use assigned smart color
        tableColor = _groupColors[table.colorIndex! % _groupColors.length];
      } else {
        // Fallback for old data without color_index
        final int hash = table.currentOrderGroupId.hashCode;
        tableColor = _groupColors[hash.abs() % _groupColors.length];
      }
    }

    final double size = 60.0;
    Widget shapeWidget;
    
    final TextStyle textStyle = TextStyle(
      color: (table.status == TableStatus.occupied || _selectedEmptyTables.contains(table.tableName)) 
          ? Colors.white  // Occupied or Selected -> White text
          : Theme.of(context).colorScheme.surface, // Empty -> Background color text (invert against onSurface)
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    switch (table.shape) {
      case 'circle':
        shapeWidget = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            color: tableColor,
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(table.tableName, style: textStyle),
        );
        break;
      case 'rectangle':
        shapeWidget = Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: table.rotation * 3.14159265 / 180, 
              child: Container(
                width: size + 30, 
                height: size,
                decoration: BoxDecoration(
                  color: tableColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
            ),
            Text(table.tableName, style: textStyle),
          ],
        );
        break;
      case 'square':
      default:
        shapeWidget = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
          color: tableColor, // 這是背景色 (Filled)
          borderRadius: BorderRadius.circular(12),
          // 增加一個邊框讓淺色模式下的空桌可見（如果背景是白，空桌也是白）
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          ),
          alignment: Alignment.center,
          child: Text(table.tableName, style: textStyle),
        );
        break;
    }
    
    return Positioned(
      left: table.x,
      top: table.y,
      child: GestureDetector(
        onTap: () => _onTableTap(table),
        onDoubleTap: () => _onTableDoubleTap(table),
        child: shapeWidget,
      ),
    );
  }
}

// -------------------------------------------------------------------
// 2. 自定義組件
// -------------------------------------------------------------------

// 深色風格 Dialog (Now Dynamic Theme Dialog)
class _DarkStyleDialog extends StatelessWidget {
  final String title;
  final Widget contentWidget;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String? confirmText;
  final String? cancelText;

  const _DarkStyleDialog({
    required this.title,
    required this.contentWidget,
    required this.onCancel,
    required this.onConfirm,
    this.confirmText,
    this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
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
            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            contentWidget,
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: Text(cancelText ?? "取消", style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 16)),
                ),
                SizedBox(
                  width: 120, height: 40,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface, // Button fills with primary text color (Black/White)
                      foregroundColor: Theme.of(context).colorScheme.surface, // Text is surface color
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(confirmText ?? "確認", style: const TextStyle(fontWeight: FontWeight.bold)),
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

class _FailedPrintsDialog extends StatefulWidget {
  final OrderingRepository repository;
  const _FailedPrintsDialog({super.key, required this.repository});
  @override
  State<_FailedPrintsDialog> createState() => _FailedPrintsDialogState();
}

class _FailedPrintsDialogState extends State<_FailedPrintsDialog> {
  bool isLoading = true;
  List<Map<String, dynamic>> failedItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final items = await widget.repository.fetchFailedPrintItems();
      if(mounted) setState(() {
         failedItems = items;
         isLoading = false;
      });
    } catch(e) {
      if(mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadTablesForArea(String areaId) async {
    // Standard Load with Spinner
    setState(() => isLoading = true);
    await _silentRefreshTables(areaIdOverride: areaId);
    if (mounted) setState(() {
       // selectedAreaId = areaId; // This variable is not defined in _FailedPrintsDialogState
       isLoading = false;
    });
  }

  Future<void> _silentRefreshTables({String? areaIdOverride}) async {
    // final targetArea = areaIdOverride ?? selectedAreaId; // selectedAreaId is not defined
    // if (targetArea == null) return;
    
    try {
      // final fetchedTables = await _orderingRepo!.getTables(targetArea); // _orderingRepo is not defined
      // if (mounted) {
      //    setState(() {
      //       tables = fetchedTables; // tables is not defined
      //    });
      // }
    } catch (_) {}
  }
  // The following catch block and brace seem misplaced based on the context of _FailedPrintsDialogState
  // } catch(e) {
  //     if(mounted) setState(() => isLoading = false);
  //   }
  // }

  Future<void> _reprint(List<String> itemIds) async {
      setState(() => isLoading = true);
      int successCount = 0;
      
      for(var row in failedItems) {
         final item = row['item'] as OrderItem;
         if(!itemIds.contains(item.id)) continue;
         
         await widget.repository.reprintSingleItem(
             orderGroupId: row['orderGroupId'],
             item: item,
             tableName: row['tableName']
         );
         successCount++;
      }
      
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已發送 $successCount 筆補印指令"))); 
         _loadData(); 
      }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
       backgroundColor: Theme.of(context).cardColor,
       insetPadding: const EdgeInsets.all(20),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       child: Container(
         padding: const EdgeInsets.all(20),
         constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
         child: Column(children: [
            Text("列印檢測 / 補印", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            Divider(color: Theme.of(context).dividerColor),
            if(isLoading) const Expanded(child: Center(child: CupertinoActivityIndicator())),
            if(!isLoading && failedItems.isEmpty) 
               Expanded(child: Center(child: Text("目前沒有列印失敗或待處理的項目", style: TextStyle(color: Theme.of(context).disabledColor)))),
            if(!isLoading && failedItems.isNotEmpty)
               Expanded(
                 child: ListView.separated(
                    itemCount: failedItems.length,
                    separatorBuilder: (_,__) => Divider(height:1, color: Theme.of(context).dividerColor),
                    itemBuilder: (context, index) {
                       final row = failedItems[index];
                       final item = row['item'] as OrderItem;
                       final status = row['printStatus'];
                       final isPending = status == 'pending';
                       
                       return ListTile(
                          title: Text(item.itemName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          subtitle: Text("桌號: ${row['tableName']} (${isPending ? '處理中' : '失敗'})", 
                              style: TextStyle(color: isPending ? Colors.orange : Theme.of(context).colorScheme.error)),
                          trailing: IconButton(
                             icon: Icon(CupertinoIcons.printer, color: Theme.of(context).colorScheme.primary),
                             onPressed: () => _reprint([item.id]),
                          ),
                       );
                    }
                 )
               ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
               TextButton(onPressed: () => Navigator.pop(context), child: const Text("關閉")),
               const SizedBox(width: 8),
               if(failedItems.isNotEmpty) 
                  IconButton(
                    onPressed: _loadData, 
                    icon: const Icon(CupertinoIcons.refresh),
                    tooltip: "重新整理",
                  ),
               if(failedItems.isNotEmpty) ...[
                 const SizedBox(width: 8),
                  ElevatedButton(
                     onPressed: () => _reprint(List<String>.from(failedItems.map((e) => (e['item'] as OrderItem).id))),
                     style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, 
                        foregroundColor: Theme.of(context).scaffoldBackgroundColor, // User requested Home Screen Background Color
                        elevation: 0,
                        side: BorderSide(color: Theme.of(context).dividerColor),
                     ),
                     child: const Text("全部補印")
                  )
               ]
            ])
         ])
       )
    );
  }
}