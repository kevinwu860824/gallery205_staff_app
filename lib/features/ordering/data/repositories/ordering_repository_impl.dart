import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:gallery205_staff_app/core/services/local_db_service.dart';
import 'package:gallery205_staff_app/core/services/hub_client.dart';
import 'package:gallery205_staff_app/core/services/hub_sync_service.dart';
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
import 'package:gallery205_staff_app/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/session_repository.dart';
import 'package:gallery205_staff_app/core/models/tax_profile.dart';
import 'package:gallery205_staff_app/core/events/order_events.dart';
import 'package:gallery205_staff_app/features/ordering/domain/ordering_constants.dart';
import 'package:gallery205_staff_app/core/services/invoice_service.dart';

class OrderingRepositoryImpl implements OrderingRepository, SessionRepository {
  final OrderingRemoteDataSource remoteDataSource;
  final SharedPreferences _prefs;
  final PrinterService printerService = PrinterService();
  final LocalDbService _localDb = LocalDbService();
  final OrderEventBus? eventBus;
  final InventoryRepository? inventoryRepo;
  final HubClient? _hubClient;
  HubClient get hubClient => _hubClient ?? HubClient();
  // Not holding a direct HubServer reference here. We check via prefs.

  OrderingRepositoryImpl(
    this.remoteDataSource,
    this._prefs, [
    this.eventBus,
    this.inventoryRepo,
    this._hubClient,
  ]);

  bool _isHubServer() {
    return _prefs.getBool('isHubDevice') ?? false;
  }

  String? get _currentShopId => _prefs.getString('savedShopId');

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
   debugPrint('Submit Order: isNewOrder=$isNewOrder, tableNumbers=$tableNumbers, staff=$staffName');
    final shopId = _currentShopId;
    if (shopId == null) throw Exception('No Shop ID found');

    String finalGroupId;
    bool isOffline = false;
    List<OrderItem> createdItems = []; // Moved outside try-catch

    // ── 路由判斷：Hub Device → Hub Client → Supabase ─────────
    if (_isHubServer()) {
      // ── A. Hub Device：直接寫本地 SQLite + 背景同步 Supabase ─
      Map<String, dynamic>? taxSnapshot;
      try {
        final profile = await getTaxProfile();
        taxSnapshot = {
          'rate': profile.rate,
          'is_tax_included': profile.isTaxIncluded,
          'shop_id': profile.shopId,
          'captured_at': DateTime.now().toIso8601String(),
        };
      } catch (_) {}

      finalGroupId = orderGroupId ?? const Uuid().v4();

      final groupData = {
        'id': finalGroupId,
        'shop_id': shopId,
        'table_names': jsonEncode(tableNumbers),
        'pax_adult': 0,
        'staff_name': staffName ?? '',
        'tax_snapshot': taxSnapshot != null ? jsonEncode(taxSnapshot) : null,
        'color_index': 0,
        'status': OrderingConstants.orderStatusDining,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      };

      final itemsData = items.map((item) => {
            'id': const Uuid().v4(),
            'order_group_id': finalGroupId,
            'item_id': item.menuItemId,
            'item_name': item.itemName,
            'quantity': item.quantity,
            'price': item.price,
            'modifiers': jsonEncode(item.selectedModifiers),
            'note': item.note,
            'target_print_category_ids': jsonEncode(item.targetPrintCategoryIds),
            'status': 'new',
            'created_at': DateTime.now().toIso8601String(),
            'is_synced': 0,
          }).toList();

      if (isNewOrder) {
        await _localDb.insertPendingOrderGroup(groupData);
      }
      await _localDb.addItemsToOrder(finalGroupId, itemsData);
      HubSyncService().syncAsync(finalGroupId);
      createdItems = List.generate(items.length, (i) => items[i].copyWith(id: itemsData[i]['id'] as String));
    } else if (hubClient.isHubAvailable) {
      // ── B. Hub Client（透過 LAN 發送到 Hub iPad）────────────
      Map<String, dynamic>? taxSnapshot;
      try {
        final profile = await getTaxProfile();
        taxSnapshot = {
          'rate': profile.rate,
          'is_tax_included': profile.isTaxIncluded,
          'shop_id': profile.shopId,
          'captured_at': DateTime.now().toIso8601String(),
        };
      } catch (_) {}

      finalGroupId = orderGroupId ?? const Uuid().v4();

      final groupData = {
        'id': finalGroupId,
        'shop_id': shopId,
        'table_names': jsonEncode(tableNumbers),
        'pax_adult': 0,
        'staff_name': staffName ?? '',
        'tax_snapshot': taxSnapshot != null ? jsonEncode(taxSnapshot) : null,
        'color_index': 0,
        'status': OrderingConstants.orderStatusDining,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      };

      final itemsData = items.map((item) => {
            'id': const Uuid().v4(),
            'order_group_id': finalGroupId,
            'item_id': item.menuItemId,
            'item_name': item.itemName,
            'quantity': item.quantity,
            'price': item.price,
            'modifiers': jsonEncode(item.selectedModifiers),
            'note': item.note,
            'target_print_category_ids': jsonEncode(item.targetPrintCategoryIds),
            'status': 'new',
            'created_at': DateTime.now().toIso8601String(),
            'is_synced': 0,
          }).toList();

      Map<String, dynamic>? result;
      if (isNewOrder) {
        result = await hubClient.post('/orders', {
          'order_group': groupData,
          'order_items': itemsData,
        });
      } else {
        result = await hubClient.post('/orders/$finalGroupId/items', {'order_items': itemsData});
      }
      if (result == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
      createdItems = List.generate(items.length, (i) => items[i].copyWith(id: itemsData[i]['id'] as String));
    } else {
      // ── B. 直連 Supabase（原有邏輯）─────────────────────────
      try {
        if (isNewOrder) {
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
            debugPrint('Warning: Failed to capture tax snapshot: $e');
          }

          finalGroupId = await remoteDataSource.createOrderGroup(
            shopId: shopId,
            tableNames: tableNumbers,
            taxSnapshot: taxSnapshot,
            staffName: staffName,
          );
        } else {
          if (orderGroupId == null) {
            throw Exception('Order Group ID required for existing order');
          }
          finalGroupId = orderGroupId;
          await remoteDataSource.updateOrderGroupTimestamp(finalGroupId);
        }

        createdItems = await remoteDataSource.createOrderItems(finalGroupId, items);
      } catch (e) {
        // Supabase 失敗：存本地 pending_order_groups / pending_order_items
        debugPrint('Network/Remote error during order submission: $e');
        isOffline = true;
        finalGroupId = orderGroupId ?? const Uuid().v4();

        if (isNewOrder) {
          Map<String, dynamic>? localTax;
          try {
            final profile = await getTaxProfile();
            localTax = {
              'rate': profile.rate,
              'is_tax_included': profile.isTaxIncluded,
              'shop_id': profile.shopId,
              'captured_at': DateTime.now().toIso8601String(),
            };
          } catch (_) {}
          await _localDb.insertPendingOrderGroup({
            'id': finalGroupId,
            'shop_id': shopId,
            'table_names': jsonEncode(tableNumbers),
            'pax_adult': 0,
            'staff_name': staffName ?? '',
            'tax_snapshot': localTax != null ? jsonEncode(localTax) : null,
            'color_index': 0,
            'status': OrderingConstants.orderStatusDining,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'is_synced': 0,
          });
        }

        final localItems = items.map((item) => {
              'id': const Uuid().v4(),
              'order_group_id': finalGroupId,
              'item_id': item.menuItemId,
              'item_name': item.itemName,
              'quantity': item.quantity,
              'price': item.price,
              'modifiers': jsonEncode(item.selectedModifiers),
              'note': item.note,
              'target_print_category_ids':
                  jsonEncode(item.targetPrintCategoryIds),
              'status': 'new',
              'created_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            }).toList();
        await _localDb.addItemsToOrder(finalGroupId, localItems);
        createdItems = List.generate(items.length, (i) => items[i].copyWith(id: localItems[i]['id'] as String));
      }
    }

    // 2a. Deduct Stock (Inventory Integration)
    if (inventoryRepo != null) {
      try {
        // Use createdItems to ensure we have IDs if needed, but for deduction we need menuItemId which both have.
        // We use createdItems (or original items)
         await inventoryRepo!.deductStockForOrder(finalGroupId, items);
      } catch (e) {
       debugPrint("Warning: Inventory deduction failed: $e");
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
      debugPrint("Warning: No EventBus injected. Invoice/Printing will be skipped.");
    }
    
    /* 
    Legacy Printing Logic Removed due to Architectural Refactor (InvoiceService).
    ...
    */

  }


  @override
  Future<List<OrderItem>> getOrderItems(String orderGroupId) async {
    final isHubDevice = _prefs.getBool('isHubDevice') ?? false;

    // 1. Hub Device: 從本地資料庫撈取尚未結帳的訂單明細
    if (isHubDevice) {
      final localItems = await _localDb.getPendingOrderItems(orderGroupId);
      if (localItems.isNotEmpty) {
        return localItems.map((e) {
          final map = Map<String, dynamic>.from(e);
          if (map['modifiers'] is String) {
            try { map['modifiers'] = jsonDecode(map['modifiers']); } catch (_) {}
          }
          if (map['target_print_category_ids'] is String) {
            try { map['target_print_category_ids'] = jsonDecode(map['target_print_category_ids']); } catch (_) {}
          }
          return OrderItemMapper.fromJson(map);
        }).toList();
      }
    } 
    // 2. Hub Client: 透過 API 跟 Hub 索取尚未結帳的訂單明細
    else if (hubClient.isHubAvailable) {
      final res = await hubClient.get('/orders/$orderGroupId');
      if (res != null && res['order_items'] != null) {
        final hubItems = res['order_items'] as List<dynamic>;
        if (hubItems.isNotEmpty) {
          return hubItems.map((e) {
            final map = Map<String, dynamic>.from(e as Map<String, dynamic>);
            if (map['modifiers'] is String) {
              try {
                map['modifiers'] = jsonDecode(map['modifiers']);
              } catch (_) {}
            }
            if (map['target_print_category_ids'] is String) {
              try {
                map['target_print_category_ids'] =
                    jsonDecode(map['target_print_category_ids']);
              } catch (_) {}
            }
            return OrderItemMapper.fromJson(map);
          }).toList();
        }
      }
    }

    // 3. 非 Hub 模式 或 找不到未結帳資料：從 Supabase 以一般流程獲取
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
    
    // 1. Update Status in DB (Hub Aware)
    if (_isHubServer()) {
      await _localDb.updatePendingOrderItemStatus(item.id, OrderingConstants.orderStatusCancelled);
      HubSyncService().syncAsync(orderGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': orderGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$orderGroupId/void_item', {'item_id': item.id});
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await updateOrderItemStatus(item.id, OrderingConstants.orderStatusCancelled);
    }

    // 1b. Restore Stock (Inventory Integration)
    if (inventoryRepo != null) {
      try {
        await inventoryRepo!.restoreStockForOrder(orderGroupId, [item]);
      } catch (e) {
       debugPrint("Warning: Inventory restoration failed for item ${item.id}: $e");
      }
    }

    // 2. Print Deletion Ticket
    try {
      final printerSettings = await remoteDataSource.getPrinterSettings(shopId);
      final allPrintCategories = await remoteDataSource.getPrintCategories(shopId);
      final orderSeq = await remoteDataSource.getOrderSequenceNumber(shopId);

      OrderContext? realContext;
      try {
         realContext = await getOrderContext(orderGroupId);
      } catch (e) {
        debugPrint("Failed to fetch real order context for void ticket: $e");
      }

      late OrderContext orderContext;
      if (realContext != null) {
        orderContext = realContext.copyWith(
           order: realContext.order.copyWith(items: []),
           staffName: (staffName != null && staffName.isNotEmpty) ? staffName : realContext.staffName,
        );
      } else {
        // Construct entities for printing fallback
        final orderGroup = OrderGroup(
          id: orderGroupId,
          status: OrderStatus.dining,
          items: [], // Not needed for deletion call
        );
        
        orderContext = OrderContext(
           order: orderGroup,
           tableNames: [tableName],
           peopleCount: orderGroupPax,
           staffName: staffName ?? '',
        );
      }

      // OrderItem needs to be 'cancelled' status but we already passed it.
      // Ensure the passed 'item' has the correct structure for printing if needed, 
      // but 'processDeletionPrinting' takes the item directly.
      // We might need to ensure Modifiers are passed correctly (Entity already has them).

      await printerService.processDeletionPrinting(
        orderContext,
        item.copyWith(status: OrderingConstants.orderStatusCancelled),
        printerSettings,
        allPrintCategories,
        orderSeq
      );
    } catch (e) {
     debugPrint("Printing deletion ticket failed: $e");
      // Don't rethrow, as DB update succeeded.
    }
  }

  @override
  Future<void> updateOrderGroupBilling(String orderGroupId, {
    double? serviceFeeRate,
    double? discountAmount,
    double? finalAmount,
  }) async {
    final shopId = _currentShopId;
    if (shopId == null) return;

    if (_isHubServer()) {
      await _localDb.updatePendingOrderGroupBilling(
        orderGroupId,
        serviceFeeRate: serviceFeeRate,
        discountAmount: discountAmount,
        finalAmount: finalAmount,
      );
      HubSyncService().syncAsync(orderGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': orderGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$orderGroupId/billing', {
        'service_fee_rate': serviceFeeRate,
        'discount_amount': discountAmount,
        'final_amount': finalAmount,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      final Map<String, dynamic> updates = {};
      if (serviceFeeRate != null) updates['service_fee_rate'] = serviceFeeRate;
      if (discountAmount != null) updates['discount_amount'] = discountAmount;
      if (finalAmount != null) updates['final_amount'] = finalAmount;
      if (updates.isNotEmpty) {
        await remoteDataSource.supabaseClient.from('order_groups').update(updates).eq('id', orderGroupId);
      }
    }
  }

  @override
  Future<void> undoVoidOrderItem(String orderGroupId, List<String> itemIds) async {
    if (_isHubServer()) {
      for (final id in itemIds) {
        await _localDb.updatePendingOrderItemStatus(id, 'submitted');
      }
      HubSyncService().syncAsync(orderGroupId);
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$orderGroupId/undo_void', {'item_ids': itemIds});
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await remoteDataSource.supabaseClient
          .from('order_items')
          .update({'status': 'submitted'})
          .inFilter('id', itemIds);
    }
  }

  @override
  Future<void> treatOrderItem({
    required String orderGroupId,
    required List<String> itemIds,
    required double price,
    double? originalPrice,
  }) async {
    if (_isHubServer()) {
      for (final id in itemIds) {
        await _localDb.updatePendingOrderItemPrice(id, price: price, originalPrice: originalPrice);
      }
      HubSyncService().syncAsync(orderGroupId);
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$orderGroupId/treat_item', {
        'item_ids': itemIds,
        'price': price,
        'original_price': originalPrice,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      final updates = <String, dynamic>{'price': price};
      if (originalPrice != null) updates['original_price'] = originalPrice;
      await remoteDataSource.supabaseClient
          .from('order_items')
          .update(updates)
          .inFilter('id', itemIds);
    }
  }

  @override
  Future<void> reprintSingleItem({
    required String orderGroupId,
    required OrderItem item,
    required String tableName,
    String? staffName,
    Map<String, dynamic>? printJobs,
  }) async {
    final shopId = _currentShopId;
    if (shopId == null) return;

    final printerSettings = await remoteDataSource.getPrinterSettings(shopId);
    final allPrintCategories = await remoteDataSource.getPrintCategories(shopId);

    // Create "Reprint" Item with prefix "補 "
    final reprintItem = item.copyWith(
      itemName: "補 ${item.itemName}",
      status: 'submitted',
    );

    // Fetch actual full context to preserve pax/staff info
    OrderContext? realContext;
    try {
      realContext = await getOrderContext(orderGroupId);
    } catch (e) {
     debugPrint("Failed to fetch real order context for reprint: $e");
    }

    late OrderContext orderContext;
    if (realContext != null) {
      orderContext = realContext.copyWith(
        order: realContext.order.copyWith(items: [reprintItem]),
        staffName: realContext.staffName.isNotEmpty ? realContext.staffName : (staffName ?? ''),
      );
    } else {
      final orderGroup = OrderGroup(
        id: orderGroupId,
        status: OrderStatus.dining,
        items: [reprintItem],
      );
      orderContext = OrderContext(
        order: orderGroup,
        tableNames: [tableName],
        peopleCount: 0,
        staffName: staffName ?? '',
      );
    }

    // 從 print_jobs 取出 failed 的 IP，只送那幾台
    Set<String>? targetIps;
    if (printJobs != null && printJobs.isNotEmpty) {
      targetIps = printJobs.entries
          .where((e) => (e.value as Map<String, dynamic>?)?['status'] == 'failed')
          .map((e) => e.key)
          .toSet();
    }

    await updatePrintStatus([item.id], 'pending');

    final failedMap = await printerService.processOrderPrinting(
      orderContext,
      printerSettings,
      allPrintCategories,
      0,
      targetPrinterIps: targetIps,
    );

    // 合併 print_jobs：把這次結果 merge 回舊的 print_jobs
    final Map<String, dynamic> mergedJobs = Map<String, dynamic>.from(printJobs ?? {});
    // 先把這次嘗試的 IP 全標 success
    final attemptedIps = targetIps ?? printerSettings.map((p) => p['ip'] as String).where((ip) => ip.isNotEmpty).toSet();
    for (final ip in attemptedIps) {
      mergedJobs[ip] = {'status': 'success'};
    }
    // 再把真正失敗的蓋回 failed
    for (final entry in failedMap.entries) {
      if (entry.value.contains(item.id)) {
        mergedJobs[entry.key] = {'status': 'failed'};
      }
    }

    if (mergedJobs.isNotEmpty) {
      await updatePrintJobs({item.id: mergedJobs});
    }

    final anyFailed = failedMap.values.any((ids) => ids.contains(item.id));
    await updatePrintStatus([item.id], anyFailed ? 'failed' : 'success');
  }

  @override
  Future<void> updateOrderGroupPax(String orderGroupId, int newPax,
      {int adult = 0, int child = 0}) async {
    if (_isHubServer()) {
      await _localDb.updatePendingOrderGroupPax(orderGroupId,
          pax: newPax, adult: adult, child: child);
      HubSyncService().syncAsync(orderGroupId);
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$orderGroupId/pax', {
        'pax': newPax,
        'pax_adult': adult,
        'pax_child': child,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await remoteDataSource.supabaseClient
          .from('order_groups')
          .update({'pax': newPax, 'pax_adult': adult, 'pax_child': child})
          .eq('id', orderGroupId);
    }
  }

  @override
  Future<void> updateOrderGroupNote(String orderGroupId, String note) async {
    if (_isHubServer()) {
      await _localDb.updatePendingOrderGroupNote(orderGroupId, note);
      HubSyncService().syncAsync(orderGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': orderGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$orderGroupId/note', {'note': note});
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await remoteDataSource.supabaseClient
          .from('order_groups')
          .update({'note': note})
          .eq('id', orderGroupId);
    }
  }

  @override
  Future<void> clearTable(Map<String, dynamic> tableData,
      {String? targetGroupId}) async {
    final groupId = targetGroupId ?? tableData['current_order_group_id'];
    if (groupId == null) return;

    if (_isHubServer()) {
      await _localDb.clearCachedTable(tableData['table_name']);
      // If it's a pending group, we might want to cancel it if it's not synced
      final group = await _localDb.getPendingOrderGroup(groupId);
      if (group != null && group['is_synced'] == 0) {
        await _localDb.cancelPendingOrderGroup(groupId);
      }
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': groupId});
    } else if (hubClient.isHubAvailable) {
      await hubClient.post('/tables/clear', {
        'table_name': tableData['table_name'],
        'order_group_id': groupId,
      });
    } else {
      // Safety Check: Ensure Paid
      final orderRes = await remoteDataSource.supabaseClient
          .from('order_groups')
          .select('final_amount, payment_method')
          .eq('id', groupId)
          .single();

      final double amount =
          (orderRes['final_amount'] as num?)?.toDouble() ?? 0.0;
      final String? method = orderRes['payment_method'] as String?;

      if (amount > 0 && method == null) {
        throw Exception("此桌尚有未結帳金額，請先進行結帳或作廢訂單。");
      }

      await remoteDataSource.supabaseClient
          .from('order_groups')
          .update({
            'status': OrderingConstants.orderStatusCompleted,
            'checkout_time': DateTime.now().toIso8601String()
          })
          .eq('id', groupId);
    }
  }

  @override
  Future<void> voidOrderGroup(String orderGroupId, {String? staffName}) async {
    if (_isHubServer()) {
      await _localDb.cancelPendingOrderGroup(orderGroupId);
      // Also clear any tables associated with this group
      final group = await _localDb.getPendingOrderGroup(orderGroupId);
      if (group != null && group['table_names'] is List) {
        for (final tableName in group['table_names']) {
          await _localDb.clearCachedTable(tableName);
        }
      }
      // cancelPendingOrderGroup 設 is_synced=1，syncAsync 可能來不及在 refresh 前更新 Supabase。
      // 直接 await 更新 Supabase，確保 order_history 刷新時已反映作廢狀態。
      try {
        await remoteDataSource.supabaseClient.from('order_groups').update({
          'status': OrderingConstants.orderStatusCancelled,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', orderGroupId);
      } catch (e) {
        debugPrint('⚠️ voidOrderGroup: Supabase update failed: $e');
      }
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': orderGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$orderGroupId/void_group', {});
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      // 1. Update Status
      await remoteDataSource.supabaseClient.from('order_groups').update({
        'status': OrderingConstants.orderStatusCancelled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orderGroupId);
    }

    // 2. Restore Stock (Inventory Integration)
    // We need to fetch items first because we need their quantities and IDs.
    if (inventoryRepo != null) {
      try {
        final items = await getOrderItems(orderGroupId);
        if (items.isNotEmpty) {
           await inventoryRepo!.restoreStockForOrder(orderGroupId, items);
        }
      } catch (e) {
       debugPrint("Warning: Inventory restoration failed for group $orderGroupId: $e");
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
    // Using `status` == OrderingConstants.orderStatusCancelled for Deletion Check is safer if we trust data.
    // In TransactionDetail, we explicitly marked them.
    // Let's assume the caller filters or we handle 'cancelled' as deletion printing.
    
    final List<OrderItem> itemsToPrint = [];
    final List<OrderItem> itemsToDelete = [];

    for (var item in items) {
       if (item.status == OrderingConstants.orderStatusCancelled) {
         itemsToDelete.add(item);
       } else {
         itemsToPrint.add(item);
       }
    }

    OrderContext? realContext;
    try {
       realContext = await getOrderContext(orderGroupId);
    } catch (e) {
      debugPrint("Failed to fetch real order context for reprintBatch: $e");
    }

    late OrderContext printContext;
    late OrderContext deleteContext;

    if (realContext != null) {
      printContext = realContext.copyWith(
         order: realContext.order.copyWith(items: itemsToPrint),
         staffName: realContext.staffName.isNotEmpty ? realContext.staffName : (staffName ?? ''),
      );
      deleteContext = realContext.copyWith(
         order: realContext.order.copyWith(items: itemsToDelete), // Not strictly needed for deletion, but keeps format
         staffName: realContext.staffName.isNotEmpty ? realContext.staffName : (staffName ?? ''),
      );
    } else {
      // Fallback
      printContext = OrderContext(
        order: OrderGroup(id: orderGroupId, status: OrderStatus.dining, items: itemsToPrint),
        tableNames: tableNames,
        peopleCount: pax,
        staffName: staffName ?? '',
      );
      deleteContext = OrderContext(
        order: OrderGroup(id: orderGroupId, status: OrderStatus.dining, items: itemsToDelete),
        tableNames: tableNames,
        peopleCount: pax,
        staffName: staffName ?? '',
      );
    }

    if (itemsToPrint.isNotEmpty) {
      // 1. Mark as Pending
      await updatePrintStatus(itemsToPrint.map((e) => e.id).toList(), 'pending');

      // 2. Execute — returns Map<printerIp, Set<failedItemId>>
      final failedMap = await printerService.processOrderPrinting(
        printContext,
        printerSettings,
        allPrintCategories,
        batchIndex,
      );

      // 3. Collect all failed item IDs across all printers
      final Set<String> allFailedIds = {};
      for (final ids in failedMap.values) {
        allFailedIds.addAll(ids);
      }

      // 4. Update Results
      final successIds = itemsToPrint.map((e) => e.id).where((id) => !allFailedIds.contains(id)).toList();
      if (successIds.isNotEmpty) await updatePrintStatus(successIds, 'success');
      if (allFailedIds.isNotEmpty) await updatePrintStatus(allFailedIds.toList(), 'failed');
    }

    if (itemsToDelete.isNotEmpty) {
       final orderSeq = await remoteDataSource.getOrderSequenceNumber(shopId);
       for (var delItem in itemsToDelete) {
          try {
             final failedDel = await printerService.processDeletionPrinting(
                 deleteContext, // Group info
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

    // A. 讀取桌位設定（Supabase，永遠讀設定）
    final tableRes = await remoteDataSource.supabaseClient
        .from('tables')
        .select()
        .eq('shop_id', shopId)
        .eq('area_id', areaId)
        .order('table_name');

    // B. 讀取桌況：Hub 裝置讀本地 SQLite，Hub Client 讀 Hub API，否則讀 Supabase
    final Map<String, String> hubTableStatus = {};    // tableName → 'occupied'/'empty'
    final Map<String, String> hubTableOrderId = {};   // tableName → order_group_id
    final Map<String, int> tableColors = {};

    final isHubDevice = _prefs.getBool('isHubDevice') ?? false;

    if (isHubDevice) {
      // Hub 裝置本身：直接讀本地 cached_tables SQLite
      final cachedTables = await _localDb.getCachedTables();
      for (final t in cachedTables) {
        final tName = t['table_name'] as String? ?? '';
        if (tName.isEmpty) continue;
        hubTableStatus[tName] = t['status'] as String? ?? 'empty';
        final orderId = t['current_order_group_id'] as String?;
        if (orderId != null && orderId.isNotEmpty) hubTableOrderId[tName] = orderId;
        final colorIdx = t['color_index'];
        if (colorIdx != null) tableColors[tName] = colorIdx as int;
      }

      // 取得每桌所有進行中訂單（支援拆單後多訂單選擇）
      final activeByTable = await _localDb.getActiveGroupIdsByTable();

      return List<Map<String, dynamic>>.from(tableRes).map((row) {
        final tableName = row['table_name'] as String;
        final occupied = (hubTableStatus[tableName] ?? 'empty') == 'occupied';
        final orderId = hubTableOrderId[tableName];
        final activeIds = activeByTable[tableName] ?? (orderId != null ? [orderId] : []);
        return TableModel.fromMap(
          row,
          status: occupied ? TableStatus.occupied : TableStatus.empty,
          currentOrderGroupId: orderId ?? (activeIds.isNotEmpty ? activeIds.last : null),
          activeOrderGroupIds: activeIds,
          colorIndex: tableColors[tableName],
        );
      }).toList();
    }

    if (HubClient().isHubAvailable) {
      // Hub Client：從 Hub /tables 讀取即時快照
      final hubRes = await HubClient().get('/tables');
      final tables = hubRes?['tables'] as List<dynamic>? ?? [];
      final Map<String, List<String>> hubActiveByTable = {};
      for (final t in tables) {
        final tMap = t as Map<String, dynamic>;
        final tName = tMap['table_name'] as String? ?? '';
        if (tName.isEmpty) continue;
        hubTableStatus[tName] = tMap['status'] as String? ?? 'empty';
        final orderId = tMap['current_order_group_id'] as String?;
        if (orderId != null && orderId.isNotEmpty) {
          hubTableOrderId[tName] = orderId;
        }
        final colorIdx = tMap['color_index'];
        if (colorIdx != null) {
          tableColors[tName] = colorIdx as int;
        }
        final activeIds = tMap['active_order_group_ids'];
        if (activeIds is List) {
          hubActiveByTable[tName] = List<String>.from(activeIds);
        }
      }

      return List<Map<String, dynamic>>.from(tableRes).map((row) {
        final tableName = row['table_name'] as String;
        final occupied = (hubTableStatus[tableName] ?? 'empty') == 'occupied';
        final orderId = hubTableOrderId[tableName];
        final activeIds = hubActiveByTable[tableName] ?? (orderId != null ? [orderId] : []);

        return TableModel.fromMap(
          row,
          status: occupied ? TableStatus.occupied : TableStatus.empty,
          currentOrderGroupId: orderId ?? (activeIds.isNotEmpty ? activeIds.last : null),
          activeOrderGroupIds: activeIds,
          colorIndex: tableColors[tableName],
        );
      }).toList();
    }

    // 非 Hub 模式：從 Supabase order_groups 讀取
    final activeOrdersRes = await remoteDataSource.supabaseClient
        .from('order_groups')
        .select('id, table_names, color_index')
        .eq('shop_id', shopId)
        .eq('status', OrderingConstants.orderStatusDining)
        .order('created_at', ascending: true);

    final Map<String, List<String>> activeOrdersMap = {};

    for (var order in activeOrdersRes) {
      final String orderId = order['id'];
      final int? colorIdx = order['color_index'] as int?;

      final List<dynamic> tables = order['table_names'] ?? [];
      for (var t in tables) {
        final tName = t.toString();
        activeOrdersMap.putIfAbsent(tName, () => []).add(orderId);
        if (colorIdx != null) tableColors[tName] = colorIdx;
      }
    }

    return List<Map<String, dynamic>>.from(tableRes).map((row) {
      final tableName = row['table_name'] as String;
      final activeOrders = activeOrdersMap[tableName] ?? [];
      final hasOrder = activeOrders.isNotEmpty;

      return TableModel.fromMap(
        row,
        status: hasOrder ? TableStatus.occupied : TableStatus.empty,
        currentOrderGroupId: hasOrder ? activeOrders.last : null,
        activeOrderGroupIds: activeOrders,
        colorIndex: tableColors[tableName],
      );
    }).toList();
  }
  @override
  Future<void> cleanupStalePendingItems({int thresholdMinutes = 2}) async {
    // Hub client：order_items 由 Hub 管理
    if (HubClient().hasHubIpConfigured) return;
    // Hub 裝置本身：order_items 先存本地再由 sync 推上 Supabase
    final isHubDevice = _prefs.getBool('isHubDevice') ?? false;
    if (isHubDevice) return;
    final shopId = _currentShopId;
    if (shopId == null) return;
    await remoteDataSource.cleanupStalePendingItems(shopId, thresholdMinutes: thresholdMinutes);
  }

  @override
  Future<void> updatePrintStatus(List<String> itemIds, String status) async {
    if (itemIds.isEmpty) return;
    if (_isHubServer()) {
      await _localDb.updatePrintStatusLocal(itemIds, status);
    } else if (hubClient.isHubAvailable) {
      await hubClient.post('/print/status', {'item_ids': itemIds, 'status': status});
    } else {
      await remoteDataSource.updatePrintStatus(itemIds, status);
    }
  }

  @override
  Future<void> updatePrintJobs(Map<String, Map<String, dynamic>> itemPrintJobs) async {
    if (_isHubServer()) {
      await _localDb.updatePrintJobsLocal(itemPrintJobs);
      return;
    }
    if (hubClient.isHubAvailable) return; // Hub Client: Hub Device 端負責儲存
    await remoteDataSource.updatePrintJobs(itemPrintJobs);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFailedPrintItems() async {
    if (_isHubServer()) {
      final rows = await _localDb.fetchFailedPrintItemsLocal();
      return rows.map((map) => {
        'item': OrderItemMapper.fromJson(map),
        'tableName': map['_table_name_str'] ?? '',
        'orderGroupId': map['order_group_id'] ?? '',
        'printStatus': map['print_status'] ?? 'failed',
        'printJobs': (map['print_jobs'] is Map ? map['print_jobs'] : <String, dynamic>{}) as Map<String, dynamic>,
      }).toList();
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.get('/print/failed');
      if (res == null || res['items'] == null) return [];
      return (res['items'] as List).map((row) {
        final itemJson = Map<String, dynamic>.from(row['item'] as Map);
        return {
          'item': OrderItemMapper.fromJson(itemJson),
          'tableName': row['tableName'] ?? '',
          'orderGroupId': row['orderGroupId'] ?? '',
          'printStatus': row['printStatus'] ?? 'failed',
          'printJobs': row['printJobs'] ?? <String, dynamic>{},
        };
      }).toList();
    } else {
      final shopId = _currentShopId;
      if (shopId == null) return [];
      return remoteDataSource.fetchFailedPrintItems(shopId);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUnsyncedOrdersDetail() async {
    final result = <Map<String, dynamic>>[];

    // 本機 SQLite 離線訂單
    final localOrders = await _localDb.getUnsyncedOrders();
    for (final o in localOrders) {
      List<String> tables = [];
      try { tables = List<String>.from(jsonDecode(o['table_names'] ?? '[]')); } catch (_) {}
      result.add({
        'id': o['id'],
        'table_names': tables,
        'created_at': o['created_at'],
        'final_amount': null,
        'source': 'local',
      });
    }

    // Hub 待同步訂單
    if (hubClient.isHubAvailable) {
      try {
        final pendingData = await hubClient.get('/sync/pending');
        final orders = (pendingData?['orders'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final order in orders) {
          final group = order['group'] as Map<String, dynamic>;
          final checkout = order['checkout'] as Map<String, dynamic>?;
          List<String> tables = [];
          final rawTables = group['table_names'];
          if (rawTables is String) {
            try { tables = List<String>.from(jsonDecode(rawTables)); } catch (_) {}
          } else if (rawTables is List) {
            tables = List<String>.from(rawTables);
          }
          result.add({
            'id': group['id'],
            'table_names': tables,
            'created_at': group['created_at'],
            'final_amount': (checkout?['final_amount'] as num?)?.toDouble(),
            'source': 'hub',
          });
        }
      } catch (_) {}
    }

    return result;
  }

  @override
  Future<int> getUnsyncedOrdersCount() async {
    final detail = await getUnsyncedOrdersDetail();
    return detail.length;
  }

  @override
  Future<void> syncOfflineOrders() async {
    // ── A. 傳統離線佇列（local_orders）────────────────────────
    final offlineOrders = await _localDb.getUnsyncedOrders();
    for (var row in offlineOrders) {
      try {
        final String orderId = row['id'];
        final String shopId = row['shop_id'];
        final List<String> tableNames =
            (row['table_names'] as String).split(',');
        final List<dynamic> itemsJson = jsonDecode(row['items_json']);
        final List<OrderItem> items =
            itemsJson.map((j) => OrderItemMapper.fromJson(j)).toList();

        await remoteDataSource.supabaseClient.from('order_groups').upsert({
          'id': orderId,
          'shop_id': shopId,
          'table_names': tableNames,
          'people_count': row['people_count'],
          'status': row['status'],
          'created_at': row['created_at'],
          'updated_at': DateTime.now().toIso8601String(),
        });
        await remoteDataSource.supabaseClient.from('order_items').upsert(
            items.map((item) => OrderItemMapper.toJson(item, orderId)).toList());
        await _localDb.markOrderAsSynced(orderId);
      } catch (e) {
       debugPrint("Sync failed for order ${row['id']}: $e");
      }
    }

    // ── B. Hub 模式離線訂單（pending_order_groups）────────────
    debugPrint('🔍 syncOfflineOrders: isHubAvailable=${hubClient.isHubAvailable}, hasHubIp=${hubClient.hasHubIpConfigured}');
    if (!hubClient.isHubAvailable) {
      // ── C. Hub 已設定 IP 但斷線：保留本地佇列，等 Hub 重連 ──
      if (hubClient.hasHubIpConfigured) {
        debugPrint('⏳ Hub offline — keeping orders in local queue until Hub reconnects');
        return;
      }
      // ── D. 無 Hub 模式（Hub 裝置本身或純 Supabase 模式）：直接同步 ──
      // 只同步已結帳的訂單（dining 中訂單由 Hub 管理，結帳後再推 Supabase）
      final pendingGroups = await _localDb.getUnsyncedOrderGroupsWithCheckout();
      debugPrint('🔄 syncOfflineOrders D path: ${pendingGroups.length} groups total, ${pendingGroups.where((o) => o['checkout'] != null).length} with checkout');
      for (final order in pendingGroups) {
        final groupId = (order['group'] as Map)['id'] as String;
        final groupStatus = (order['group'] as Map)['status'];
        final groupIsSynced = (order['group'] as Map)['is_synced'];
        debugPrint('  📦 group=$groupId status=$groupStatus is_synced=$groupIsSynced has_checkout=${order['checkout'] != null}');
        if (order['checkout'] == null) continue; // 跳過未結帳訂單
        try {
          debugPrint('  ➡️ syncing $groupId to Supabase...');
          await _syncHubOrderToSupabase(order);
          await _localDb.markOrderGroupAndCheckoutSynced(groupId);
          debugPrint('  ✅ synced $groupId');
        } catch (e) {
          debugPrint('  ❌ sync failed for $groupId: $e');
        }
      }

      // 孤立 items（加點時兩端都斷，group 已在 Supabase）
      final orphanItems = await _localDb.getUnsyncedOrphanItems();
      for (final item in orphanItems) {
        try {
          List<dynamic> modifiers = [];
          final rawMod = item['modifiers'];
          if (rawMod is String && rawMod.isNotEmpty) {
            modifiers = jsonDecode(rawMod) as List;
          }
          List<String> printCatIds = [];
          final rawCat = item['target_print_category_ids'];
          if (rawCat is String && rawCat.isNotEmpty) {
            printCatIds = List<String>.from(jsonDecode(rawCat) as List);
          }
          printCatIds = printCatIds.where((id) => id.isNotEmpty).toList();
          await remoteDataSource.supabaseClient.from('order_items').upsert({
            'id': item['id'],
            'order_group_id': item['order_group_id'],
            'item_id': _uuidOrNull(item['item_id']),
            'item_name': item['item_name'],
            'quantity': item['quantity'],
            'price': item['price'],
            'modifiers': modifiers,
            'note': item['note'] ?? '',
            'target_print_category_ids': printCatIds,
            'created_at': item['created_at'],
            'status': item['status'] ?? 'new',
          });
          await _localDb.markSingleItemSynced(item['id'] as String);
        } catch (e) {
          debugPrint('Orphan item sync failed: $e');
        }
      }
      await _issuePendingInvoices();
      return;
    }

    // ── B1. 把手機本地 pending 推給 Hub（Hub 離線期間存的訂單）──
    try {
      // B1a. 新開桌的訂單（group + items 都在本地）
      final localGroups = await _localDb.getUnsyncedOrderGroups();
      for (final group in localGroups) {
        final groupId = group['id'] as String;
        final status = group['status'] as String?;
        if (status == 'cancelled') {
          await _localDb.markOrderGroupSynced(groupId);
          continue;
        }
        final items = await _localDb.getPendingOrderItems(groupId);
        try {
          final result = await hubClient.post('/orders', {
            'order_group': Map<String, dynamic>.from(group),
            'order_items': items.map((e) => Map<String, dynamic>.from(e)).toList(),
          });
          if (result != null) {
            await _localDb.markOrderGroupSynced(groupId);
            await _localDb.markOrderItemsSynced(groupId);
            debugPrint('📤 Pushed local pending order $groupId to Hub');
          }
        } catch (e) {
          debugPrint('⚠️ Push pending order $groupId to Hub failed: $e');
        }
      }

      // B1b. 加點的孤立 items（group 已在 Hub，只有 items 在本地）
      // 依 order_group_id 分組，再用 POST /orders/<id>/items 推給 Hub
      final orphanItems = await _localDb.getUnsyncedOrphanItems();
      if (orphanItems.isNotEmpty) {
        final itemsByGroup = <String, List<Map<String, dynamic>>>{};
        for (final item in orphanItems) {
          final gid = item['order_group_id'] as String;
          itemsByGroup.putIfAbsent(gid, () => []).add(Map<String, dynamic>.from(item));
        }
        for (final entry in itemsByGroup.entries) {
          final gid = entry.key;
          try {
            final result = await hubClient.post('/orders/$gid/items', {
              'order_items': entry.value,
            });
            if (result != null) {
              for (final item in entry.value) {
                await _localDb.markSingleItemSynced(item['id'] as String);
              }
              debugPrint('📤 Pushed ${entry.value.length} orphan items for $gid to Hub');
            }
          } catch (e) {
            debugPrint('⚠️ Push orphan items for $gid to Hub failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Local pending push to Hub failed: $e');
    }

    // B2 移除：Hub 自己負責同步到 Supabase（path D），Client 不代 Hub 寫 Supabase
    // 通知 Hub 立即同步其 SQLite → Supabase
    try {
      await hubClient.post('/sync/trigger', {});
    } catch (_) {}

    await _issuePendingInvoices();
  }

  /// Hub 離線訂單同步至 Supabase（order_group + items + checkout）
  Future<void> _syncHubOrderToSupabase(Map<String, dynamic> orderData) async {
    final supabase = remoteDataSource.supabaseClient;
    final group = orderData['group'] as Map<String, dynamic>;
    final items =
        (orderData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final checkout = orderData['checkout'] as Map<String, dynamic>?;

    // table_names: JSON string → List<String>
    List<String> tableNames = [];
    final rawTables = group['table_names'];
    if (rawTables is String) {
      tableNames = List<String>.from(jsonDecode(rawTables) as List);
    } else if (rawTables is List) {
      tableNames = List<String>.from(rawTables);
    }

    // tax_snapshot: JSON string → Map
    Map<String, dynamic>? taxSnapshot;
    final rawTax = group['tax_snapshot'];
    if (rawTax is String && rawTax.isNotEmpty) {
      taxSnapshot = jsonDecode(rawTax) as Map<String, dynamic>;
    } else if (rawTax is Map) {
      taxSnapshot = Map<String, dynamic>.from(rawTax);
    }

    // 1. Upsert order_group
    final groupPayload = {
      'id': group['id'],
      'shop_id': _uuidOrNull(group['shop_id']),
      'table_names': tableNames,
      'pax_adult': group['pax_adult'] ?? 0,
      'staff_name': group['staff_name'],
      'tax_snapshot': taxSnapshot,
      'color_index': group['color_index'] ?? 0,
      'created_at': group['created_at'],
      'status': checkout != null ? OrderingConstants.orderStatusCompleted : OrderingConstants.orderStatusDining,
      'open_id': _uuidOrNull(group['open_id']),
    };
    debugPrint('  🔸 upsert order_groups: id=${group['id']} status=${groupPayload['status']} shop=${groupPayload['shop_id']}');
    try {
      await supabase.from('order_groups').upsert(groupPayload);
      debugPrint('  🔸 order_groups upsert OK');
    } catch (e) {
      debugPrint('  🔸 order_groups upsert FAILED: $e');
      rethrow;
    }

    // 2. Upsert order_items
    debugPrint('  🔸 upserting ${items.length} order_items...');
    for (final item in items) {
      List<dynamic> modifiers = [];
      final rawMod = item['modifiers'];
      if (rawMod is String && rawMod.isNotEmpty) {
        modifiers = jsonDecode(rawMod) as List;
      }
      List<String> printCatIds = [];
      final rawCat = item['target_print_category_ids'];
      if (rawCat is String && rawCat.isNotEmpty) {
        printCatIds = List<String>.from(jsonDecode(rawCat) as List);
      } else if (rawCat is List) {
        printCatIds = List<String>.from(rawCat);
      }
      // uuid[] 欄位不能含空字串
      printCatIds = printCatIds.where((id) => id.isNotEmpty).toList();
      await supabase.from('order_items').upsert({
        'id': _uuidOrNull(item['id']),
        'order_group_id': _uuidOrNull(item['order_group_id']),
        'item_id': _uuidOrNull(item['item_id']),
        'item_name': item['item_name'],
        'quantity': item['quantity'],
        'price': item['price'],
        'modifiers': modifiers,
        'note': item['note'] ?? '',
        'target_print_category_ids': printCatIds,
        'created_at': item['created_at'],
        'status': item['status'] ?? 'new',
      });
    }

    // 3. 套用結帳記錄
    debugPrint('  🔸 checkout=${checkout == null ? 'null (skip)' : 'present, inserting payments + updating status'}');
    if (checkout != null) {
      List<dynamic> paymentsData = [];
      final rawPayments = checkout['payments_json'];
      if (rawPayments is String && rawPayments.isNotEmpty) {
        paymentsData = jsonDecode(rawPayments) as List;
      }

      for (final payment in paymentsData) {
        final p = payment as Map<String, dynamic>;
        await supabase.from('order_payments').insert({
          'order_group_id': group['id'],
          'payment_method': p['method'],
          'amount': p['amount'],
          'reference':
              (p['ref'] as String?)?.isEmpty == true ? null : p['ref'],
          'open_id': _uuidOrNull(checkout['open_id']),
        });
      }

      try {
        await supabase.from('order_groups').update({
          'status': OrderingConstants.orderStatusCompleted,
          'checkout_time': checkout['checkout_time'],
          'payment_method': checkout['payment_method'],
          'final_amount': checkout['final_amount'],
          'service_fee_rate': checkout['service_fee_rate'] ?? 0,
          'discount_amount': checkout['discount_amount'] ?? 0,
          'open_id': _uuidOrNull(checkout['open_id']),
          'buyer_ubn': checkout['buyer_ubn'],
          'carrier_type': checkout['carrier_type'],
          'carrier_num': checkout['carrier_num'],
        }).eq('id', group['id']);
        debugPrint('  🔸 order_groups status→completed OK');
      } catch (e) {
        debugPrint('  🔸 order_groups status update FAILED: $e');
        rethrow;
      }
    }
  }

  /// 空字串轉 null，避免 Supabase UUID 欄位收到 "" 報 22P02
  String? _uuidOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : s;
  }

  @override
  Future<OrderContext?> getOrderContext(String orderGroupId) async {
    final shopId = _currentShopId;
    if (shopId == null) return null;

    // Hub 裝置：直接讀本地 SQLite
    final isHubDevice = _prefs.getBool('isHubDevice') ?? false;
    if (isHubDevice) {
      return _getOrderContextFromLocalDb(orderGroupId);
    }

    // Hub Client：從 Hub API 讀
    if (hubClient.isHubAvailable) {
      final res = await hubClient.get('/orders/$orderGroupId');
      if (res != null && res['order_group'] != null) {
        final groupMap = Map<String, dynamic>.from(res['order_group'] as Map);
        final itemsList = (res['order_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        final items = itemsList.map((e) {
          final map = Map<String, dynamic>.from(e);
          if (map['modifiers'] is String) {
            try { map['modifiers'] = jsonDecode(map['modifiers']); } catch (_) {}
          }
          if (map['target_print_category_ids'] is String) {
            try { map['target_print_category_ids'] = jsonDecode(map['target_print_category_ids']); } catch (_) {}
          }
          return OrderItemMapper.fromJson(map);
        }).toList();

        return OrderContextMapper.fromJson(groupMap, items);
      }
    }

    // Supabase fallback
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
      debugPrint("Error fetching order context: $e");
      return null;
    }
  }

  Future<OrderContext?> _getOrderContextFromLocalDb(String orderGroupId) async {
    try {
      final group = await _localDb.getPendingOrderGroup(orderGroupId);
      if (group == null) {
        // fallback Supabase（已結帳同步的訂單）
        final groupRes = await remoteDataSource.supabaseClient
            .from('order_groups').select().eq('id', orderGroupId).maybeSingle();
        if (groupRes == null) return null;
        final items = await getOrderItems(orderGroupId);
        return OrderContextMapper.fromJson(groupRes, items);
      }
      final rawItems = await _localDb.getPendingOrderItems(orderGroupId);
      final items = rawItems.map((e) {
        final map = Map<String, dynamic>.from(e);
        if (map['modifiers'] is String) {
          try { map['modifiers'] = jsonDecode(map['modifiers']); } catch (_) {}
        }
        if (map['target_print_category_ids'] is String) {
          try { map['target_print_category_ids'] = jsonDecode(map['target_print_category_ids']); } catch (_) {}
        }
        return OrderItemMapper.fromJson(map);
      }).toList();
      return OrderContextMapper.fromJson(Map<String, dynamic>.from(group), items);
    } catch (e) {
      debugPrint("Error fetching order context from local DB: $e");
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
     debugPrint("Get Tax Profile Error: $e");
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
      debugPrint("Save Tax Profile Error: $e");
      rethrow;
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
  Future<void> deleteOrderGroup(String orderGroupId) {
    return voidOrderGroup(orderGroupId);
  }

  @override
  Future<OrderContext?> getSessionContext(String orderGroupId) {
    return getOrderContext(orderGroupId);
  }

  @override
  Future<void> mergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
    int? colorIndex,
  }) async {
    if (_isHubServer()) {
      await _localDb.mergeOrderGroupsLocal(
        hostGroupId: hostGroupId,
        targetGroupIds: targetGroupIds,
        colorIndex: colorIndex,
      );
      HubSyncService().syncAsync(hostGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': hostGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$hostGroupId/merge', {
        'target_group_ids': targetGroupIds,
        if (colorIndex != null) 'color_index': colorIndex,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await remoteDataSource.mergeOrderGroups(
        hostGroupId: hostGroupId,
        targetGroupIds: targetGroupIds,
        colorIndex: colorIndex,
      );
    }
  }

  @override
  Future<void> unmergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
    Map<String, String>? tableOverrides,
  }) async {
    if (_isHubServer()) {
      await _localDb.unmergeOrderGroupsLocal(
        hostGroupId: hostGroupId,
        targetGroupIds: targetGroupIds,
        tableOverrides: tableOverrides,
      );
      HubSyncService().syncAsync(hostGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': hostGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$hostGroupId/unmerge', {
        'target_group_ids': targetGroupIds,
        if (tableOverrides != null) 'table_overrides': tableOverrides,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await remoteDataSource.unmergeOrderGroups(
        hostGroupId: hostGroupId,
        targetGroupIds: targetGroupIds,
        tableOverrides: tableOverrides,
      );
    }
  }

  @override
  Future<void> moveTable({
    required String hostGroupId,
    required List<String> oldTables,
    required List<String> newTables,
    int? colorIndex,
  }) async {
    if (_isHubServer()) {
      await _localDb.moveTableLocal(
        hostGroupId: hostGroupId,
        oldTables: oldTables,
        newTables: newTables,
        colorIndex: colorIndex,
      );
      HubSyncService().syncAsync(hostGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': hostGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$hostGroupId/move', {
        'old_tables': oldTables,
        'new_tables': newTables,
        if (colorIndex != null) 'color_index': colorIndex,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await remoteDataSource.moveTable(
        hostGroupId: hostGroupId,
        oldTables: oldTables,
        newTables: newTables,
        colorIndex: colorIndex,
      );
    }
  }

  @override
  Future<int> pickColorForTables(List<String> tableNames) async {
    final shopId = _currentShopId ?? '';
    final primaryTable = tableNames.isNotEmpty ? tableNames.first : '';
    const double threshold = 150.0;
    const Set<int> reservedColors = {1};

    try {
      // 取得桌位座標
      final tablesRes = await remoteDataSource.supabaseClient
          .from('tables')
          .select('table_name, x, y')
          .eq('shop_id', shopId);
      final Map<String, Map<String, double>> tableCoords = {
        for (final r in tablesRes as List)
          r['table_name'] as String: {
            'x': (r['x'] as num?)?.toDouble() ?? 0.0,
            'y': (r['y'] as num?)?.toDouble() ?? 0.0,
          }
      };
      final myCoords = tableCoords[primaryTable];

      final Set<int> allUsedColors = {};
      final Set<int> nearbyUsedColors = {};

      if (_isHubServer()) {
        final occupiedTables = await _localDb.getCachedTables();
        for (final ct in occupiedTables) {
          if (ct['status'] != 'occupied') continue;
          final ci = ct['color_index'] as int?;
          if (ci == null) continue;
          allUsedColors.add(ci);
          if (myCoords != null) {
            final oc = tableCoords[ct['table_name'] as String?];
            if (oc != null) {
              final dx = myCoords['x']! - oc['x']!;
              final dy = myCoords['y']! - oc['y']!;
              if (dx * dx + dy * dy <= threshold * threshold) nearbyUsedColors.add(ci);
            }
          }
        }
      } else if (hubClient.isHubAvailable) {
        final res = await hubClient.get('/tables');
        final hubTables = List<Map<String, dynamic>>.from(res?['tables'] ?? []);
        for (final ct in hubTables) {
          if (ct['status'] != 'occupied') continue;
          final ci = ct['color_index'] as int?;
          if (ci == null) continue;
          allUsedColors.add(ci);
          if (myCoords != null) {
            final oc = tableCoords[ct['table_name'] as String?];
            if (oc != null) {
              final dx = myCoords['x']! - oc['x']!;
              final dy = myCoords['y']! - oc['y']!;
              if (dx * dx + dy * dy <= threshold * threshold) nearbyUsedColors.add(ci);
            }
          }
        }
      } else {
        final activeRes = await remoteDataSource.supabaseClient
            .from('order_groups')
            .select('table_names, color_index')
            .eq('shop_id', shopId)
            .eq('status', OrderingConstants.orderStatusDining);
        for (final row in activeRes as List) {
          final ci = row['color_index'] as int?;
          if (ci == null) continue;
          allUsedColors.add(ci);
          if (myCoords != null) {
            for (final tName in List<String>.from(row['table_names'] ?? [])) {
              final oc = tableCoords[tName];
              if (oc != null) {
                final dx = myCoords['x']! - oc['x']!;
                final dy = myCoords['y']! - oc['y']!;
                if (dx * dx + dy * dy <= threshold * threshold) {
                  nearbyUsedColors.add(ci);
                  break;
                }
              }
            }
          }
        }
      }

      final List<int> p1 = [], p2 = [];
      for (int i = 0; i < 9; i++) {
        if (reservedColors.contains(i)) continue;
        if (!allUsedColors.contains(i)) {
          p1.add(i);
        } else if (!nearbyUsedColors.contains(i)) {
          p2.add(i);
        }
      }
      p1.shuffle();
      p2.shuffle();
      if (p1.isNotEmpty) return p1.first;
      if (p2.isNotEmpty) return p2.first;
      final fallback = List.generate(9, (i) => i).where((i) => !reservedColors.contains(i)).toList();
      return fallback[DateTime.now().millisecondsSinceEpoch % fallback.length];
    } catch (e) {
      debugPrint('⚠️ pickColorForTables fallback: $e');
      return DateTime.now().millisecondsSinceEpoch % 9;
    }
  }

  @override
  Future<Map<String, List<String>>> fetchMergedChildGroupsWithTables(String hostGroupId) async {
    if (_isHubServer()) {
      return await _localDb.getMergedChildGroups(hostGroupId);
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.get('/orders/$hostGroupId/merged_children');
      final raw = res?['child_groups'] as Map<String, dynamic>? ?? {};
      return raw.map((k, v) => MapEntry(k, List<String>.from(v as List)));
    } else {
      final supabase = remoteDataSource.supabaseClient;
      final res = await supabase
          .from('order_groups')
          .select('id, table_names')
          .eq('status', OrderingConstants.orderStatusMerged)
          .eq('merged_target_id', hostGroupId);
      return {
        for (final row in (res as List))
          row['id'] as String: List<String>.from(row['table_names'] as List? ?? [])
      };
    }
  }

  @override
  Future<List<String>> fetchMergedChildGroups(String hostGroupId) async {
    debugPrint('🔍 fetchMergedChildGroups: isHubServer=${_isHubServer()}, isHubAvailable=${hubClient.isHubAvailable}, groupId=$hostGroupId');
    if (_isHubServer()) {
      final result = await _localDb.getMergedChildGroupIds(hostGroupId);
      debugPrint('🔍 fetchMergedChildGroups (HubServer local): $result');
      return result;
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.get('/orders/$hostGroupId/merged_children');
      debugPrint('🔍 fetchMergedChildGroups (HubClient API): res=$res');
      return List<String>.from(res?['child_group_ids'] ?? []);
    } else {
      final supabase = remoteDataSource.supabaseClient;
      final res = await supabase
          .from('order_groups')
          .select('id')
          .eq('status', OrderingConstants.orderStatusMerged)
          .eq('merged_target_id', hostGroupId);
      debugPrint('🔍 fetchMergedChildGroups (Supabase): len=${(res as List).length}');
      return (res as List).map((row) => row['id'] as String).toList();
    }
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
     debugPrint("Error toggling item availability: $e");
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
     debugPrint("Error toggling category visibility: $e");
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
     debugPrint("Error toggling item visibility: $e");
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 待補印結帳（v4）
  // ─────────────────────────────────────────────────────────────

  @override
  Future<void> addPendingReceiptPrint(Map<String, dynamic> data) async {
    if (_isHubServer()) {
      await _localDb.addPendingReceiptPrint(data);
    } else if (hubClient.isHubAvailable) {
      await hubClient.post('/receipt-prints', data);
    } else {
      await _localDb.addPendingReceiptPrint(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingReceiptPrints() async {
    if (_isHubServer()) {
      return _localDb.getPendingReceiptPrints();
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.get('/receipt-prints');
      if (res == null || res['items'] == null) return [];
      return List<Map<String, dynamic>>.from(
          (res['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    } else {
      return _localDb.getPendingReceiptPrints();
    }
  }

  @override
  Future<void> removePendingReceiptPrint(String orderGroupId) async {
    if (_isHubServer()) {
      await _localDb.removePendingReceiptPrint(orderGroupId);
    } else if (hubClient.isHubAvailable) {
      await hubClient.delete('/receipt-prints/$orderGroupId');
    } else {
      await _localDb.removePendingReceiptPrint(orderGroupId);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 補開發票（在 syncOfflineOrders 末段呼叫）
  // ─────────────────────────────────────────────────────────────

  Future<void> _issuePendingInvoices() async {
    try {
      final shopId = _currentShopId;
      if (shopId == null) return;

      final res = await remoteDataSource.supabaseClient
          .from('order_groups')
          .select('id, tax_snapshot')
          .eq('shop_id', shopId)
          .eq('status', OrderingConstants.orderStatusCompleted)
          .isFilter('ezpay_invoice_number', null)
          .not('final_amount', 'is', null);

      final invoiceService = InvoiceServiceImpl();
      for (final order in (res as List)) {
        final rawTax = order['tax_snapshot'];
        double? rate;
        if (rawTax is String && rawTax.isNotEmpty) {
          rate = ((jsonDecode(rawTax) as Map)['rate'] as num?)?.toDouble();
        } else if (rawTax is Map) {
          rate = (rawTax['rate'] as num?)?.toDouble();
        }
        if (rate != 5.0) continue;

        final orderId = order['id'] as String;
        final err = await invoiceService.issueInvoice(orderId);
        if (err == null) {
          debugPrint('✅ Pending invoice issued: $orderId');
          await _localDb.removePendingReceiptPrint(orderId);
        } else {
          debugPrint('⚠️ Pending invoice failed: $orderId — $err');
        }
      }
    } catch (e) {
      debugPrint('⚠️ _issuePendingInvoices error (non-critical): $e');
    }
  }


  @override
  Future<void> splitOrderGroup({
    required String sourceGroupId,
    required Map<String, int> itemQuantitiesToMove,
    required List<String> targetTableNames,
    String? existingTargetGroupId,
  }) async {
    if (_isHubServer()) {
      await _localDb.splitOrderGroupLocal(
        sourceGroupId: sourceGroupId,
        itemQuantitiesToMove: itemQuantitiesToMove,
        targetTables: targetTableNames,
        targetGroupId: existingTargetGroupId,
      );
      HubSyncService().syncAsync(sourceGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': sourceGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$sourceGroupId/split', {
        'item_quantities': itemQuantitiesToMove,
        'target_tables': targetTableNames,
        'target_group_id': existingTargetGroupId,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await remoteDataSource.splitOrderGroup(
        sourceGroupId: sourceGroupId,
        itemQuantitiesToMove: itemQuantitiesToMove,
        targetTableNames: targetTableNames,
        existingTargetGroupId: existingTargetGroupId,
      );
    }
  }

  @override
  Future<void> splitByPax({
    required String sourceGroupId,
    required int pax,
    required double totalAmount,
  }) async {
    if (_isHubServer()) {
      await _localDb.splitByPaxLocal(
        sourceGroupId: sourceGroupId,
        pax: pax,
        totalAmount: totalAmount,
      );
      HubSyncService().syncAsync(sourceGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': sourceGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$sourceGroupId/split_pax', {
        'pax': pax,
        'total_amount': totalAmount,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      // Supabase path
      final supabase = remoteDataSource.supabaseClient;
      final sourceGroup = await supabase
          .from('order_groups')
          .select()
          .eq('id', sourceGroupId)
          .single();
      final List tableNames = sourceGroup['table_names'];
      final double perPerson = totalAmount / pax;

      for (int i = 2; i <= pax; i++) {
        final newGroupRes = await supabase.from('order_groups').insert({
          'shop_id': sourceGroup['shop_id'],
          'table_names': tableNames,
          'status': OrderingConstants.orderStatusDining,
          'pax': 1,
          'note': '均分 ($i/$pax)',
          'color_index': (DateTime.now().millisecondsSinceEpoch + i) % 20,
          'open_id': sourceGroup['open_id'],
        }).select('id').single();
        final String newGroupId = newGroupRes['id'];
        await supabase.from('order_items').insert({
          'order_group_id': newGroupId,
          'item_name': '分攤餐費 (Split Share)',
          'price': perPerson,
          'quantity': 1,
          'status': 'served',
        });
      }

      final double deduction = -(totalAmount - perPerson);
      await supabase.from('order_items').insert({
        'order_group_id': sourceGroupId,
        'item_name': '拆單扣除 (Split Deduction)',
        'price': deduction,
        'quantity': 1,
        'status': 'served',
      });

      final String oldNote = sourceGroup['note'] ?? '';
      final String newNote =
          oldNote.isEmpty ? '均分 (1/$pax)' : '$oldNote | 均分 (1/$pax)';
      await supabase
          .from('order_groups')
          .update({'note': newNote})
          .eq('id', sourceGroupId);
    }
  }

  @override
  Future<void> revertSplit({
    required String sourceGroupId,
    required String targetGroupId,
  }) async {
    if (_isHubServer()) {
      await _localDb.revertSplitLocal(
        sourceGroupId: sourceGroupId,
        targetGroupId: targetGroupId,
      );
      HubSyncService().syncAsync(sourceGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': sourceGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$sourceGroupId/revert_split', {
        'target_id': targetGroupId,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await remoteDataSource.revertSplit(
        sourceGroupId: sourceGroupId,
        targetGroupId: targetGroupId,
      );
    }
  }

  @override
  Future<void> updateBillingInfo({
    required String orderGroupId,
    required double serviceFeeRate,
    required double discountAmount,
    required double finalAmount,
  }) async {
    if (_isHubServer()) {
      await _localDb.updatePendingOrderGroupBilling(
        orderGroupId,
        serviceFeeRate: serviceFeeRate,
        discountAmount: discountAmount,
        finalAmount: finalAmount,
      );
      HubSyncService().syncAsync(orderGroupId);
      _localDb.notifyTableUpdate({'is_refresh': true, 'host_group_id': orderGroupId});
    } else if (hubClient.isHubAvailable) {
      final res = await hubClient.post('/orders/$orderGroupId/billing', {
        'service_fee_rate': serviceFeeRate,
        'discount_amount': discountAmount,
        'final_amount': finalAmount,
      });
      if (res == null) throw Exception('無法連線到 Hub 設備，請確認 Hub 已開啟');
    } else {
      await remoteDataSource.updateBillingInfo(
        orderGroupId: orderGroupId,
        serviceFeeRate: serviceFeeRate,
        discountAmount: discountAmount,
        finalAmount: finalAmount,
      );
    }
  }
}

