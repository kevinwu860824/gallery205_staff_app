import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:gallery205_staff_app/core/services/local_db_service.dart';
import 'package:gallery205_staff_app/features/ordering/data/models/ordering_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/features/ordering/data/datasources/ordering_remote_data_source.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/menu.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/features/ordering/domain/models/table_model.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/ordering_repository.dart';
import 'package:gallery205_staff_app/features/inventory/domain/repositories/inventory_repository.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/domain/repositories/session_repository.dart';
import 'package:gallery205_staff_app/core/models/tax_profile.dart';
import 'package:gallery205_staff_app/core/events/order_events.dart';

class OrderingRepositoryImpl implements OrderingRepository, SessionRepository {
  final OrderingRemoteDataSource remoteDataSource;
  final SharedPreferences sharedPreferences;
  final PrinterService printerService = PrinterService(); 
  final LocalDbService _localDb = LocalDbService();
  final OrderEventBus? eventBus;
  final InventoryRepository? inventoryRepo; // NEW: Optional to avoid breaking tests if any

  OrderingRepositoryImpl(this.remoteDataSource, this.sharedPreferences, [this.eventBus, this.inventoryRepo]);

  String? get _currentShopId => sharedPreferences.getString('savedShopId');

  @override
  Stream<void> get onPrintTaskUpdate => _localDb.onPrintTaskUpdate;

  @override
  Future<({List<MenuCategory> categories, List<MenuItem> items})> getMenu({bool onlyVisible = true}) async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception('No Shop ID found');

    final categories = await remoteDataSource.getMenuCategories(shopId);
    final items = await remoteDataSource.getMenuItems(shopId);

    if (onlyVisible) {
      final visibleCategories = categories.where((c) => c.isVisible).toList();
      final visibleCatIds = visibleCategories.map((c) => c.id).toSet();
      
      final visibleItems = items.where((i) => i.isVisible && visibleCatIds.contains(i.categoryId)).toList();
      
      return (categories: visibleCategories, items: visibleItems);
    }
    
    return (categories: categories, items: items);
  }

  @override
  Future<List<Map<String, dynamic>>> getPrintCategories() async {
    final shopId = _currentShopId;
    if (shopId == null) return [];
    return remoteDataSource.getPrintCategories(shopId);
  }

  // Not strictly in Interface but Caller can use impl or I should add to Interface
  // Since I'm using OrderingRepositoryImpl directly in screens often (via Riverpod provider which returns Impl or Interface?)
  // Provider returns OrderingRepository.
  // I need to add to OrderingRepository Interface too.
  @override
  Future<int> getOrderRank(String orderGroupId) {
    return remoteDataSource.getOrderRank(orderGroupId);
  }

  @override
  Future<void> submitOrder({
    required List<OrderItem> items,
    required List<String> tableNumbers,
    String? orderGroupId,
    bool isNewOrder = true,
    String? staffName,
  }) async {
    print('Submit Order: isNewOrder=$isNewOrder, tableNumbers=$tableNumbers, staff=$staffName');
    final shopId = _currentShopId;
    if (shopId == null) throw Exception('No Shop ID found');

    String finalGroupId;
    bool isOffline = false;
    List<OrderItem> createdItems = []; // Moved outside try-catch

    try {
      // 1. Create or Update Order Group (Remote)
      if (isNewOrder) {
        // Capture Tax Snapshot
        Map<String, dynamic>? taxSnapshot;
        try {
           final profile = await getTaxProfile();
           taxSnapshot = {
             'rate': profile.rate,
             'is_tax_included': profile.isTaxIncluded,
             'shop_id': profile.shopId,
             'captured_at': DateTime.now().toIso8601String(),
           };
        } catch (e) {
           print("Warning: Failed to capture tax snapshot: $e");
        }

        finalGroupId = await remoteDataSource.createOrderGroup(
          shopId: shopId, 
          tableNames: tableNumbers,
          taxSnapshot: taxSnapshot,
          staffName: staffName,
        );
      } else {
        if (orderGroupId == null) throw Exception('Order Group ID required for existing order');
        finalGroupId = orderGroupId;
        await remoteDataSource.updateOrderGroupTimestamp(finalGroupId);
      }

      // 2. Create Order Items (Remote)
      // Fix: Capture created items to get their generated IDs
      createdItems = await remoteDataSource.createOrderItems(finalGroupId, items);

    } catch (e) {
      print("Network/Remote error during order submission: $e");
      
      // Fallback: Save to Local DB (Offline Mode)
      isOffline = true;
      finalGroupId = orderGroupId ?? const Uuid().v4();
      
      // For offline, we keep using the original items (ids might be menu ids, but offline logic handles it differently or we generate uuid?)
      // Actually, standard practice for offline is to generate UUIDs locally.
      // But for now, let's just proceed with original items.
      
      await _localDb.insertOfflineOrder({
         'id': finalGroupId,
         'shop_id': shopId,
         'table_names': tableNumbers.join(','),
         'people_count': 1,
         'items_json': jsonEncode(items.map((e) => OrderItemMapper.toJson(e, finalGroupId)).toList()),
         'status': 'dining',
         'created_at': DateTime.now().toIso8601String(),
         'is_synced': 0
      });
      // In offline case, we use original items
      createdItems = items; 
    }

    // 2a. Deduct Stock (Inventory Integration)
    if (inventoryRepo != null) {
      try {
        // Use createdItems to ensure we have IDs if needed, but for deduction we need menuItemId which both have.
        // We use createdItems (or original items)
         await inventoryRepo!.deductStockForOrder(finalGroupId, items);
      } catch (e) {
        print("Warning: Inventory deduction failed: $e");
      }
    }

    // 3. Post-Processing (Event Trigger)
    // Decoupled: Fire event for InvoiceService to handle printing/invoice.
    if (eventBus != null) {
       eventBus!.fire(OrderSubmittedEvent(
         orderGroupId: finalGroupId,
         items: createdItems.isNotEmpty ? createdItems : items, // Use items with correct IDs
         tableNumbers: tableNumbers,
         isNewOrder: isNewOrder,
         isOffline: isOffline,
         staffName: staffName,
       ));
    } else {
       print("Warning: No EventBus injected. Invoice/Printing will be skipped.");
    }
    
    /* 
    Legacy Printing Logic Removed due to Architectural Refactor (InvoiceService).
    ...
    */

  }


  @override
  Future<List<OrderItem>> getOrderItems(String orderGroupId) async {
    return remoteDataSource.getOrderItems(orderGroupId);
  }

  @override
  Future<void> updateOrderItemStatus(String itemId, String status) async {
    return remoteDataSource.updateOrderItemStatus(itemId, status);
  }

  @override
  Future<void> voidOrderItem({
    required String orderGroupId,
    required OrderItem item,
    required String tableName,
    required int orderGroupPax,
    String? staffName,
  }) async {
    final shopId = _currentShopId;
    if (shopId == null) return;
    if (shopId == null) return;
    
    // 1. Update Status in DB
    await updateOrderItemStatus(item.id, 'cancelled');

    // 1b. Restore Stock (Inventory Integration)
    if (inventoryRepo != null) {
      try {
        await inventoryRepo!.restoreStockForOrder(orderGroupId, [item]);
      } catch (e) {
        print("Warning: Inventory restoration failed for item ${item.id}: $e");
      }
    }

    // 2. Print Deletion Ticket
    try {
      final printerSettings = await remoteDataSource.getPrinterSettings(shopId);
      final allPrintCategories = await remoteDataSource.getPrintCategories(shopId);
      final orderSeq = await remoteDataSource.getOrderSequenceNumber(shopId);

      // Construct entities for printing
      final orderGroup = OrderGroup(
        id: orderGroupId,
        status: OrderStatus.dining,
        items: [], // Not needed for deletion call
      );
      
      final orderContext = OrderContext(
         order: orderGroup,
         tableNames: [tableName],
         peopleCount: orderGroupPax,
         staffName: staffName ?? '',
      );

      // OrderItem needs to be 'cancelled' status but we already passed it.
      // Ensure the passed 'item' has the correct structure for printing if needed, 
      // but 'processDeletionPrinting' takes the item directly.
      // We might need to ensure Modifiers are passed correctly (Entity already has them).

      await printerService.processDeletionPrinting(
        orderContext,
        item.copyWith(status: 'cancelled'),
        printerSettings,
        allPrintCategories,
        orderSeq
      );
    } catch (e) {
      print("Printing deletion ticket failed: $e");
      // Don't rethrow, as DB update succeeded.
    }
  }

  @override
  Future<void> reprintSingleItem({
    required String orderGroupId,
    required OrderItem item,
    required String tableName,
    String? staffName,
  }) async {
    final shopId = _currentShopId;
    if (shopId == null) return;

    final printerSettings = await remoteDataSource.getPrinterSettings(shopId);
    final allPrintCategories = await remoteDataSource.getPrintCategories(shopId);

    // Create "Reprint" Item with prefix "補 "
    final reprintItem = item.copyWith(
      itemName: "補 ${item.itemName}",
      status: 'submitted', // Ensure status is submitted so it prints
    );

    final orderGroup = OrderGroup(
      id: orderGroupId,
      status: OrderStatus.dining,
      items: [reprintItem],
    );
    
    final orderContext = OrderContext(
      order: orderGroup,
      tableNames: [tableName],
      peopleCount: 0,
      staffName: staffName ?? '',
    );

    // Use batch index 0
    await updatePrintStatus([item.id], 'pending');

    final failedIds = await printerService.processOrderPrinting(
      orderContext,
      printerSettings,
      allPrintCategories,
      0
    );

    if (failedIds.isNotEmpty) {
      // Since we only sent one item with this ID
      await updatePrintStatus([item.id], 'failed');
    } else {
      await updatePrintStatus([item.id], 'success');
    }
  }

  @override
  Future<void> updateOrderGroupPax(String orderGroupId, int newPax, {int adult = 0, int child = 0}) async {
    // Direct DB call or DataSource? Use DataSource if possible, but simple update is fine here too.
    // Let's iterate: move DB logic to DataSource later if strict. For now, keep Repository as the Logic Hub.
    await remoteDataSource.supabaseClient
        .from('order_groups')
        .update({'pax': newPax, 'pax_adult': adult, 'pax_child': child})
        .eq('id', orderGroupId);
  }

  @override
  Future<void> updateOrderGroupNote(String orderGroupId, String note) async {
    await remoteDataSource.supabaseClient
        .from('order_groups')
        .update({'note': note})
        .eq('id', orderGroupId);
  }

  @override
  Future<void> clearTable(Map<String, dynamic> tableData, {String? targetGroupId}) async {
    final groupId = targetGroupId ?? tableData['current_order_group_id'];
    if (groupId == null) return;

    // Safety Check: Ensure Paid
    final orderRes = await remoteDataSource.supabaseClient
          .from('order_groups')
          .select('final_amount, payment_method')
          .eq('id', groupId)
          .single();
    
    final double amount = (orderRes['final_amount'] as num?)?.toDouble() ?? 0.0;
    final String? method = orderRes['payment_method'] as String?;

    if (amount > 0 && method == null) {
       throw Exception("此桌尚有未結帳金額，請先進行結帳或作廢訂單。");
    }

    await remoteDataSource.supabaseClient
        .from('order_groups')
        .update({
          'status': 'completed',
          'checkout_time': DateTime.now().toIso8601String()
        })
        .eq('id', groupId);
  }

  @override
  Future<void> voidOrderGroup(String orderGroupId, {String? staffName}) async {
    // 1. Update Status
    await remoteDataSource.supabaseClient.from('order_groups').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderGroupId);

    // 2. Restore Stock (Inventory Integration)
    // We need to fetch items first because we need their quantities and IDs.
    if (inventoryRepo != null) {
      try {
        final items = await getOrderItems(orderGroupId);
        if (items.isNotEmpty) {
           await inventoryRepo!.restoreStockForOrder(orderGroupId, items);
        }
      } catch (e) {
        print("Warning: Inventory restoration failed for group $orderGroupId: $e");
      }
    }
    
    // 3. Optional: Print Void Ticket for Group?
    // User complaint "刪菜單" might mean whole order. 
    // If so, we should probably print a VOID ticket summary.
    // For now, let's assume the user meant individual items as that has explicit print logic.
    // But if we wanted to support it, we'd do it here using staffName.
  }

  @override
  Future<void> reprintBatch({
    required String orderGroupId,
    required List<OrderItem> items,
    required List<String> tableNames,
    required int pax,
    required int batchIndex,
    String? staffName,
  }) async {
    final shopId = _currentShopId;
    if (shopId == null) return;

    final printerSettings = await remoteDataSource.getPrinterSettings(shopId);
    final allPrintCategories = await remoteDataSource.getPrintCategories(shopId);

    // Separate items into Print vs Delete
    // Logic: if status is 'cancelled', it might be a deletion reprint?
    // But TransactionDetail logic used `_is_deletion_record`. 
    // The entity passed here should relying on properties.
    // However, OrderItem entity doesn't have `isDeletionRecord` property.
    // Using `status` == 'cancelled' for Deletion Check is safer if we trust data.
    // In TransactionDetail, we explicitly marked them.
    // Let's assume the caller filters or we handle 'cancelled' as deletion printing.
    
    final List<OrderItem> itemsToPrint = [];
    final List<OrderItem> itemsToDelete = [];

    for (var item in items) {
       if (item.status == 'cancelled') {
         itemsToDelete.add(item);
       } else {
         itemsToPrint.add(item);
       }
    }

    final orderGroup = OrderGroup(
      id: orderGroupId,
      status: OrderStatus.dining,
      items: itemsToPrint,
    );
    
    final orderContext = OrderContext(
      order: orderGroup,
      tableNames: tableNames,
      peopleCount: pax,
      staffName: staffName ?? '',
    );

    if (itemsToPrint.isNotEmpty) {
      // 1. Mark as Pending
      await updatePrintStatus(itemsToPrint.map((e) => e.id).toList(), 'pending');

      // 2. Execute
      final failedIds = await printerService.processOrderPrinting(
        orderContext,
        printerSettings,
        allPrintCategories,
        batchIndex
      );
      
      // 3. Update Results
      final successIds = itemsToPrint.map((e) => e.id).where((id) => !failedIds.contains(id)).toList();
      if (successIds.isNotEmpty) await updatePrintStatus(successIds, 'success');
      if (failedIds.isNotEmpty) await updatePrintStatus(failedIds, 'failed');
    }

    if (itemsToDelete.isNotEmpty) {
       final orderSeq = await remoteDataSource.getOrderSequenceNumber(shopId);
       for (var delItem in itemsToDelete) {
          try {
             final failedDel = await printerService.processDeletionPrinting(
                 orderContext, // Group info
                 delItem,
                 printerSettings,
                 allPrintCategories,
                 orderSeq
             );
             // Optionally track deletion receipt status?
             // Since item status is 'cancelled', 'print_status' can reflect ticket status.
             if (failedDel.isNotEmpty) {
                await updatePrintStatus([delItem.id], 'failed');
             } else {
                await updatePrintStatus([delItem.id], 'success');
             }
          } catch (_) {
             await updatePrintStatus([delItem.id], 'failed');
          }
       }
    }
  }

  @override
  Future<List<AreaModel>> fetchAreas() async {
    final shopId = _currentShopId;
    if (shopId == null) return [];

    final response = await remoteDataSource.supabaseClient
        .from('table_area')
        .select()
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => AreaModel.fromMap(e))
        .toList();
  }

  @override
  Future<List<TableModel>> fetchTablesInArea(String areaId) async {
    final shopId = _currentShopId;
    if (shopId == null) return [];

    // A. 讀取桌位設定
    final tableRes = await remoteDataSource.supabaseClient
        .from('tables')
        .select()
        .eq('shop_id', shopId)
        .eq('area_id', areaId)
        .order('table_name');

    // B. 讀取該店鋪所有 "用餐中" 的訂單
    final activeOrdersRes = await remoteDataSource.supabaseClient
        .from('order_groups')
        .select('id, table_names, color_index')
        .eq('shop_id', shopId)
        .eq('status', 'dining')
        .order('created_at', ascending: true);

    // C. 整合狀態 (Mapping)
    final Map<String, List<String>> activeOrdersMap = {};
    final Map<String, int> tableColors = {}; 
    
    for (var order in activeOrdersRes) {
      final String orderId = order['id'];
      final int? colorIdx = order['color_index'] as int?; 
      
      final List<dynamic> tables = order['table_names'] ?? [];
      for (var t in tables) {
        final tName = t.toString();
        
        if (!activeOrdersMap.containsKey(tName)) {
          activeOrdersMap[tName] = [];
        }
        activeOrdersMap[tName]!.add(orderId);

        if (colorIdx != null) {
          tableColors[tName] = colorIdx;
        }
      }
    }

    return List<Map<String, dynamic>>.from(tableRes).map((row) {
      final tableName = row['table_name'] as String;
      final activeOrders = activeOrdersMap[tableName] ?? [];
      final hasOrder = activeOrders.isNotEmpty;

      return TableModel.fromMap(
        row,
        status: hasOrder ? TableStatus.occupied : TableStatus.empty,
        currentOrderGroupId: hasOrder ? activeOrders.last : null, // Default to latest
        activeOrderGroupIds: activeOrders,
        colorIndex: tableColors[tableName],
      );
    }).toList();
  }
  @override
  Future<void> updatePrintStatus(List<String> itemIds, String status) async {
    await remoteDataSource.updatePrintStatus(itemIds, status);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFailedPrintItems() async {
    final shopId = _currentShopId;
    if (shopId == null) return [];
    return remoteDataSource.fetchFailedPrintItems(shopId);
  }

  @override
  Future<int> getUnsyncedOrdersCount() async {
    final rows = await _localDb.getUnsyncedOrders();
    return rows.length;
  }

  @override
  Future<void> syncOfflineOrders() async {
     final offlineOrders = await _localDb.getUnsyncedOrders();
     if (offlineOrders.isEmpty) return;

     for (var row in offlineOrders) {
       try {
          final String orderId = row['id'];
          final String shopId = row['shop_id'];
          final String tableNamesStr = row['table_names'];
          final List<String> tableNames = tableNamesStr.split(',');
          
          final List<dynamic> itemsJson = jsonDecode(row['items_json']);
          final List<OrderItem> items = itemsJson.map((j) => OrderItemMapper.fromJson(j)).toList();
          
          // 1. Recover Order Group (Upsert)
          await remoteDataSource.supabaseClient.from('order_groups').upsert({
             'id': orderId,
             'shop_id': shopId,
             'table_names': tableNames,
             'people_count': row['people_count'],
             'status': row['status'],
             'created_at': row['created_at'],
             'updated_at': DateTime.now().toIso8601String(),
          });

          // 2. Recover Items (Upsert)
          await remoteDataSource.supabaseClient.from('order_items').upsert(
             items.map((item) => OrderItemMapper.toJson(item, orderId)).toList()
          );

          // 3. Mark Synced Locally
          await _localDb.markOrderAsSynced(orderId);
          
       } catch (e) {
          print("Sync failed for order ${row['id']}: $e");
          // Keep as unsynced to retry later
       }
     }
  }

  @override
  Future<OrderContext?> getOrderContext(String orderGroupId) async {
    final shopId = _currentShopId;
    if (shopId == null) return null;

    try {
      final groupRes = await remoteDataSource.supabaseClient
          .from('order_groups')
          .select()
          .eq('id', orderGroupId)
          .maybeSingle();

      if (groupRes == null) return null;
      
      final items = await getOrderItems(orderGroupId);
      return OrderContextMapper.fromJson(groupRes, items);
    } catch (e) {
      print("Error fetching order context: $e");
      return null;
    }
  }


  @override
  Future<TaxProfile> getTaxProfile() async {
    final shopId = _currentShopId;
    if (shopId == null) throw Exception("Shop ID not found");

    try {
      final res = await remoteDataSource.supabaseClient
          .from('tax_settings')
          .select()
          .eq('shop_id', shopId)
          .maybeSingle();

      if (res == null) {
         // Return default
         return TaxProfile(
           id: '', // Will be generated on insert if we were to insert, or we handle empty
           shopId: shopId,
           updatedAt: DateTime.now()
         );
      }
      return TaxProfile.fromJson(res);
    } catch (e) {
      print("Get Tax Profile Error: $e");
      // Return default on error
      return TaxProfile(id: '', shopId: shopId, updatedAt: DateTime.now());
    }
  }

  @override
  Future<void> saveTaxProfile(TaxProfile profile) async {
    final shopId = _currentShopId;
    if (shopId == null) return;
    
    try {
      // Check if exists
      final existing = await remoteDataSource.supabaseClient
          .from('tax_settings')
          .select('id')
          .eq('shop_id', shopId)
          .maybeSingle();

      if (existing == null) {
        // Insert
        await remoteDataSource.supabaseClient.from('tax_settings').insert({
           'shop_id': shopId,
           'rate': profile.rate,
           'is_tax_included': profile.isTaxIncluded,
        });
      } else {
        // Update
        await remoteDataSource.supabaseClient.from('tax_settings').update({
           'rate': profile.rate,
           'is_tax_included': profile.isTaxIncluded,
           'updated_at': DateTime.now().toIso8601String(),
        }).eq('shop_id', shopId);
      }
    } catch (e) {
       print("Save Tax Profile Error: $e");
       throw e;
    }
  }




  @override
  Future<List<Map<String, dynamic>>> getShifts(String date) async {
    final shopId = _currentShopId;
    if (shopId == null) return [];
    return remoteDataSource.getShifts(shopId, date);
  }

  // --- SessionRepository Implementation (Redirects) ---

  @override
  Future<void> updatePax(String orderGroupId, int newPax, {int adult = 0, int child = 0}) {
    return updateOrderGroupPax(orderGroupId, newPax, adult: adult, child: child);
  }

  @override
  Future<void> clearSession(Map<String, dynamic> tableData, {String? targetGroupId}) {
    return clearTable(tableData, targetGroupId: targetGroupId);
  }

  @override
  Future<OrderContext?> getSessionContext(String orderGroupId) {
    return getOrderContext(orderGroupId);
  }

  @override
  Future<void> mergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
  }) async {
    final supabase = remoteDataSource.supabaseClient;
    
    // 1. Fetch Host's current tables
    final hostRes = await supabase
        .from('order_groups')
        .select('table_names')
        .eq('id', hostGroupId)
        .single();
    final List<String> currentHostTables = List<String>.from(hostRes['table_names'] ?? []);
    final Set<String> newHostTables = currentHostTables.toSet();

    for (final targetGroupId in targetGroupIds) {
      // 2. Find target group info
      String targetGroupName = 'Unknown';
      List<String> targetTables = [];
      try {
        final groupInfo = await supabase
            .from('order_groups')
            .select('table_names')
            .eq('id', targetGroupId)
            .single();
        final List names = groupInfo['table_names'] as List;
        targetTables = names.map((e) => e.toString()).toList();
        if (targetTables.isNotEmpty) targetGroupName = targetTables.first;
      } catch (_) {}

      // Add to Host
      newHostTables.addAll(targetTables);

      // 3. Transfer Items (set original_table_name)
      await supabase
          .from('order_items')
          .update({'original_table_name': targetGroupName}) 
          .eq('order_group_id', targetGroupId)
          .isFilter('original_table_name', null); // Only touch those without original name

      // Change owner to Host
      await supabase
          .from('order_items')
          .update({'order_group_id': hostGroupId})
          .eq('order_group_id', targetGroupId);
      
      // 4. Close Target Group (merged)
      await supabase
          .from('order_groups')
          .update({
            'status': 'merged', 
            'note': '已併入主單',
            'merged_target_id': hostGroupId
          })
          .eq('id', targetGroupId);
    }
    
    // 5. Update Host
    await supabase
        .from('order_groups')
        .update({'table_names': newHostTables.toList()})
        .eq('id', hostGroupId);
  }

  @override
  Future<void> unmergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
  }) async {
    final supabase = remoteDataSource.supabaseClient;

    // 1. Fetch Host's current tables
    final hostRes = await supabase
        .from('order_groups')
        .select('table_names')
        .eq('id', hostGroupId)
        .single();
    final List<String> currentHostTables = List<String>.from(hostRes['table_names'] ?? []);
    final Set<String> newHostTables = currentHostTables.toSet();

    for (final childGroupId in targetGroupIds) {
      // 2. Restore Child Group Status
      await supabase
          .from('order_groups')
          .update({
            'status': 'dining', 
            'note': null,
            'merged_target_id': null
          })
          .eq('id', childGroupId);
      
      // 3. Find child tables
      final childInfo = await supabase.from('order_groups').select('table_names').eq('id', childGroupId).single();
      final List names = childInfo['table_names'] as List;
      final List<String> childTables = names.map((e) => e.toString()).toList();

      // Remove from Host
      newHostTables.removeAll(childTables);

      // 4. Return Items
      if (childTables.isNotEmpty) {
         await supabase
            .from('order_items')
            .update({'order_group_id': childGroupId})
            .eq('order_group_id', hostGroupId)
            .inFilter('original_table_name', childTables);
      }
    }

    // 5. Update Host
    await supabase
        .from('order_groups')
        .update({'table_names': newHostTables.toList()})
        .eq('id', hostGroupId);
  }

  @override
  Future<void> moveTable({
    required String hostGroupId,
    required List<String> oldTables,
    required List<String> newTables,
  }) async {
    final supabase = remoteDataSource.supabaseClient;

    // 1. Calculate removed and added
    final removedTables = oldTables.where((t) => !newTables.contains(t)).toList();
    final addedTables = newTables.where((t) => !oldTables.contains(t)).toList();
    
    if (removedTables.isEmpty) {
      // Just update names (e.g. adding tables without removing any)
      await supabase
          .from('order_groups')
          .update({'table_names': newTables})
          .eq('id', hostGroupId);
      return;
    }

    // 2. Smart Item Transfer
    // Target: First added table, or if none added, first new table
    String targetForTransfer;
    if (addedTables.isNotEmpty) {
      targetForTransfer = addedTables.first;
    } else if (newTables.isNotEmpty) {
      targetForTransfer = newTables.first;
    } else {
      // Logic error: moving to NO tables? Should ideally be blocked by UI, but safe fallback:
      // If we removing all tables with no replacement, items might be orphaned effectively.
      // We'll skip transfer and just update names (clearing them).
       await supabase
          .from('order_groups')
          .update({'table_names': newTables})
          .eq('id', hostGroupId);
       return;
    }

    for (final removedTable in removedTables) {
      // A. Transfer Items
      await supabase
          .from('order_items')
          .update({'original_table_name': targetForTransfer}) 
          .eq('order_group_id', hostGroupId)
          .eq('original_table_name', removedTable);

      // B. Transfer Merged Groups (Hidden children)
      // Check for children attached to this removedTable
      // Note: Supabase filter `contains` on array
      final mergedRes = await supabase
          .from('order_groups')
          .select('id')
          .eq('status', 'merged')
          .eq('merged_target_id', hostGroupId)
          .contains('table_names', [removedTable]);

      for (final group in mergedRes) {
        final String mergedGroupId = group['id'];
        await supabase
            .from('order_groups')
            .update({
              'table_names': [targetForTransfer], 
              'note': '已換桌 ($removedTable -> $targetForTransfer)'
            })
            .eq('id', mergedGroupId);
      }
    }

    // 3. Update Host table_names
    await supabase
        .from('order_groups')
        .update({'table_names': newTables})
        .eq('id', hostGroupId);
  }

  @override
  Future<List<String>> fetchMergedChildGroups(String hostGroupId) async {
    final supabase = remoteDataSource.supabaseClient;
    final res = await supabase
        .from('order_groups')
        .select('id')
        .eq('status', 'merged')
        .eq('merged_target_id', hostGroupId);
    
    return (res as List).map((row) => row['id'] as String).toList();
  }

  @override
  Future<void> toggleMenuItemAvailability(String itemId, bool currentStatus) async {
    final newStatus = !currentStatus;
    try {
      await remoteDataSource.supabaseClient
          .from('menu_items')
          .update({'is_available': newStatus})
          .eq('id', itemId);
    } catch (e) {
      print("Error toggling item availability: $e");
      rethrow;
    }
  }

  @override
  Future<void> toggleCategoryVisibility(String categoryId, bool currentStatus) async {
    final newStatus = !currentStatus;
    try {
      await remoteDataSource.supabaseClient
          .from('menu_categories')
          .update({'is_visible': newStatus})
          .eq('id', categoryId);
    } catch (e) {
      print("Error toggling category visibility: $e");
      rethrow;
    }
  }

  @override
  Future<void> toggleItemVisibility(String itemId, bool currentStatus) async {
     final newStatus = !currentStatus;
    try {
      await remoteDataSource.supabaseClient
          .from('menu_items')
          .update({'is_visible': newStatus})
          .eq('id', itemId);
    } catch (e) {
      print("Error toggling item visibility: $e");
      rethrow;
    }
  }

  @override
  Future<void> deleteOrderGroup(String orderGroupId) async {
    final supabase = remoteDataSource.supabaseClient;
    // Hard delete
    await supabase.from('order_groups').delete().eq('id', orderGroupId);
  }
}

