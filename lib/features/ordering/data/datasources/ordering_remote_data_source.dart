import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/features/ordering/data/models/ordering_models.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/features/ordering/domain/ordering_constants.dart';

abstract class OrderingRemoteDataSource {
  Future<List<MenuCategoryModel>> getMenuCategories(String shopId);
  Future<List<MenuItemModel>> getMenuItems(String shopId);
  Future<List<Map<String, dynamic>>> getPrintCategories(String shopId);
  
  Future<String> createOrderGroup({
    required String shopId, 
    required List<String> tableNames,
    Map<String, dynamic>? taxSnapshot,
    String? staffName, // NEW
  });
  Future<void> updateOrderGroupTimestamp(String groupId);
  Future<List<OrderItem>> createOrderItems(String orderGroupId, List<OrderItem> items);
  Future<List<Map<String, dynamic>>> getPrinterSettings(String shopId);
  Future<int> getOrderSequenceNumber(String shopId);
  Future<int> getOrderRank(String orderGroupId); // NEW
  Future<List<OrderItem>> getOrderItems(String orderGroupId);

  /// Updates the status of a specific order item.
  Future<void> updateOrderItemStatus(String itemId, String status);

  /// Updates print status for multiple items.
  Future<void> updatePrintStatus(List<String> itemIds, String status);

  /// Updates print_jobs JSON per item. Map<itemId, print_jobs object>
  Future<void> updatePrintJobs(Map<String, Map<String, dynamic>> itemPrintJobs);

  /// 把超過 [thresholdMinutes] 分鐘仍是 pending 的品項標為 failed
  Future<void> cleanupStalePendingItems(String shopId, {int thresholdMinutes = 2});

  Future<List<Map<String, dynamic>>> fetchFailedPrintItems(String shopId);

  Future<List<Map<String, dynamic>>> getShifts(String shopId, String date);

  Future<void> splitOrderGroup({
    required String sourceGroupId,
    required Map<String, int> itemQuantitiesToMove,
    required List<String> targetTableNames,
    String? existingTargetGroupId,
  });

  Future<void> revertSplit({
    required String sourceGroupId,
    required String targetGroupId,
  });

  Future<void> updateBillingInfo({
    required String orderGroupId,
    required double serviceFeeRate,
    required double discountAmount,
    required double finalAmount,
  });

  Future<void> moveTable({
    required String hostGroupId,
    required List<String> oldTables,
    required List<String> newTables,
    int? colorIndex,
  });

  Future<void> mergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
    int? colorIndex,
  });

  Future<void> unmergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
    Map<String, String>? tableOverrides,
  });

  SupabaseClient get supabaseClient;
}

class OrderingRemoteDataSourceImpl implements OrderingRemoteDataSource {
// ...
// ...
  @override
  Future<void> updatePrintStatus(List<String> itemIds, String status) async {
    if (itemIds.isEmpty) return;
    await supabaseClient
        .from('order_items')
        .update({'print_status': status})
        .inFilter('id', itemIds);
  }

  @override
  Future<void> updatePrintJobs(Map<String, Map<String, dynamic>> itemPrintJobs) async {
    if (itemPrintJobs.isEmpty) return;
    await Future.wait(itemPrintJobs.entries.map((entry) async {
      await supabaseClient
          .from('order_items')
          .update({'print_jobs': entry.value})
          .eq('id', entry.key);
    }));
  }

  @override
  Future<void> cleanupStalePendingItems(String shopId, {int thresholdMinutes = 2}) async {
    try {
      // 1. 取出這個店所有進行中的 order_group IDs
      final groupRes = await supabaseClient
          .from('order_groups')
          .select('id')
          .eq('shop_id', shopId)
          .neq('status', OrderingConstants.orderStatusCancelled);
      final groupIds = (groupRes as List).map((r) => r['id'] as String).toList();
      if (groupIds.isEmpty) return;

      // 2. 把超過 thresholdMinutes 分鐘仍是 pending 的品項標為 failed
      final threshold = DateTime.now()
          .subtract(Duration(minutes: thresholdMinutes))
          .toUtc()
          .toIso8601String();
      // .inFilter() on UPDATE causes 400 in some PostgREST versions;
      // use explicit filter string instead
      final inClause = groupIds.map((id) => '"$id"').join(',');
      await supabaseClient
          .from('order_items')
          .update({'print_status': 'failed'})
          .eq('print_status', 'pending')
          .lt('created_at', threshold)
          .filter('order_group_id', 'in', '($inClause)');
    } catch (e) {
      debugPrint('cleanupStalePendingItems error: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFailedPrintItems(String shopId) async {
    try {
      final res = await supabaseClient
          .from('order_items')
          .select('*, order_groups!inner(table_names, status, shop_id)')
          .eq('order_groups.shop_id', shopId)
          .neq('order_groups.status', OrderingConstants.orderStatusCancelled)
          .eq('print_status', 'failed')
          .order('created_at', ascending: false)
          .limit(50);

      return (res as List).map((row) {
        final group = row['order_groups'];
        final tableNames = List<String>.from(group['table_names'] ?? []);
        return {
          'item': OrderItemMapper.fromJson(row),
          'tableName': tableNames.join(','),
          'orderGroupId': row['order_group_id'],
          'printStatus': row['print_status'],
          'printJobs': row['print_jobs'] ?? {},
        };
      }).toList();
    } catch (e) {
      print("Error fetching failed print items: $e");
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getShifts(String shopId, String date) async {
    try {
      final res = await supabaseClient
          .from('cash_opening')
          .select('id, open_count, open_date')
          .eq('shop_id', shopId)
          .eq('open_date', date)
          .order('open_count', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print("Error fetching shifts: $e");
      return [];
    }
  }

  final SupabaseClient supabaseClient;

  OrderingRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<List<MenuCategoryModel>> getMenuCategories(String shopId) async {
    final res = await supabaseClient
        .from('menu_categories')
        .select('id, name, sort_order, target_print_category_ids, is_visible') 
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);
        
    return (res as List).map((e) => MenuCategoryModel.fromJson(e)).toList();
  }

  @override
  Future<List<MenuItemModel>> getMenuItems(String shopId) async {
    final res = await supabaseClient
        .from('menu_items')
        .select('id, name, price, market_price, sort_order, category_id, target_print_category_ids, is_available, is_visible') 
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);
        
    return (res as List).map((e) => MenuItemModel.fromJson(e)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getPrintCategories(String shopId) async {
    final res = await supabaseClient
        .from('print_categories')
        .select()
        .eq('shop_id', shopId);
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<List<Map<String, dynamic>>> getPrinterSettings(String shopId) async {
    final res = await supabaseClient
        .from('printer_settings')
        .select()
        .eq('shop_id', shopId);
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<String> createOrderGroup({
    required String shopId, 
    required List<String> tableNames,
    Map<String, dynamic>? taxSnapshot,
    String? staffName,
  }) async {
    // 1. Smart Distance-Aware Color Assignment Logic
    int assignedColorIndex = 0;
    try {
      final String primaryTableName = tableNames.isNotEmpty ? tableNames.first : '';
      
      // 1.1 取得全店所有桌位座標
      final tablesRes = await supabaseClient
          .from('tables')
          .select('table_name, x, y')
          .eq('shop_id', shopId);
          
      final Map<String, Map<String, double>> tableCoords = {};
      for (var row in tablesRes) {
         tableCoords[row['table_name'] as String] = {
            'x': (row['x'] as num?)?.toDouble() ?? 0.0,
            'y': (row['y'] as num?)?.toDouble() ?? 0.0,
         };
      }
      
      // 1.2 取得我的桌位座標
      final myCoords = tableCoords[primaryTableName];
      
      // 1.3 取得現有正在用餐的訂單與所屬桌位
      final activeOrdersRes = await supabaseClient
          .from('order_groups')
          .select('id, table_names, color_index')
          .eq('shop_id', shopId)
          .eq('status', OrderingConstants.orderStatusDining);

      final Set<int> allUsedColors = {};
      final Set<int> nearbyUsedColors = {}; // 鄰桌禁用的顏色
      
      const double neighborDistanceThreshold = 150.0; // 鄰居判定距離 (pixels)

      for (var row in activeOrdersRes) {
         if (row['color_index'] == null) continue;
         final int colorUsed = row['color_index'] as int;
         allUsedColors.add(colorUsed);
         
         // 如果我有座標，檢查別人是不是鄰桌
         if (myCoords != null) {
            final List<String> groupTables = List<String>.from(row['table_names'] ?? []);
            bool isNeighbor = false;
            
            for (String otherTableName in groupTables) {
               final otherCoords = tableCoords[otherTableName];
               if (otherCoords != null) {
                  final dx = myCoords['x']! - otherCoords['x']!;
                  final dy = myCoords['y']! - otherCoords['y']!;
                  final distanceSq = dx * dx + dy * dy;
                  
                  if (distanceSq <= neighborDistanceThreshold * neighborDistanceThreshold) {
                     isNeighbor = true;
                     break;
                  }
               }
            }
            if (isNeighbor) {
               nearbyUsedColors.add(colorUsed);
            }
         }
      }

      // 1.4 三層優先級選色
      List<int> availableP1 = []; // P1: 全店完全沒人用過
      List<int> availableP2 = []; // P2: 有人過，但絕對不在鄰桌禁用名單 (非鄰居)
      
      for (int i = 0; i < 9; i++) {
         if (!allUsedColors.contains(i)) {
            availableP1.add(i);
         } else if (!nearbyUsedColors.contains(i)) {
            availableP2.add(i);
         }
      }
      
      // 為了不要每次都總是按照 0,1,2 順序 (大家顏色會太相似)，我們加入隨機洗牌
      availableP1.shuffle();
      availableP2.shuffle();

      if (availableP1.isNotEmpty) {
         assignedColorIndex = availableP1.first;
      } else if (availableP2.isNotEmpty) {
         assignedColorIndex = availableP2.first;
      } else {
         // P3: 極端情況 (整間店完全塞滿，且所有 20 個顏色都在鄰座出現...) -> Fallback 隨機
         assignedColorIndex = DateTime.now().millisecondsSinceEpoch % 9;
      }
    } catch (e) {
      // 若查詢出錯，退到原本的安全亂數
      assignedColorIndex = DateTime.now().millisecondsSinceEpoch % 9;
      print("Color assignment fallback error: $e");
    }

    // 1.5 Get Active Open ID
    String? currentOpenId;
    try {
      print("Fetching open_id for shop: $shopId");
      final dynamic response = await supabaseClient.rpc(
        'rpc_get_current_cash_status', 
        params: {'p_shop_id': shopId}
      );
      
      print("RPC Response: $response");

      Map<String, dynamic>? statusData;
      if (response is List) {
        if (response.isNotEmpty) {
           statusData = response.first as Map<String, dynamic>;
        }
      } else if (response is Map) {
         statusData = response as Map<String, dynamic>;
      }

      if (statusData != null && statusData['status'] == 'OPEN') {
         currentOpenId = statusData['open_id'] as String?;
         print("Found Open ID: $currentOpenId");
      } else {
         print("No active open shift found. Status: ${statusData?['status']}");
      }
    } catch (e) {
      print("Error fetching open_id during order creation: $e");
    }

    // 2. Insert with color_index and open_id
    print("Inserting order with open_id: $currentOpenId");
    final res = await supabaseClient.from('order_groups').insert({
      'shop_id': shopId,
      'table_names': tableNames,
      'status': OrderingConstants.orderStatusDining,
      'color_index': assignedColorIndex,
      'open_id': currentOpenId,
      'tax_snapshot': taxSnapshot,
      'staff_name': staffName, // Insert staff name
    }).select('id').single();
    
    return res['id'] as String;
  }
  
  @override
  Future<void> updateOrderGroupTimestamp(String groupId) async {
    await supabaseClient.from('order_groups').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', groupId);
  }

  @override
  Future<List<OrderItem>> createOrderItems(String orderGroupId, List<OrderItem> items) async {
    final List<Map<String, dynamic>> data = items.map((item) {
      return OrderItemMapper.toJson(item, orderGroupId);
    }).toList();

    final res = await supabaseClient
        .from('order_items')
        .insert(data)
        .select();

    return res.map((json) => OrderItemMapper.fromJson(json)).toList();
  }

  @override
  Future<int> getOrderSequenceNumber(String shopId) async {
    try {
      // 1. Get Open ID
      final dynamic response = await supabaseClient.rpc(
        'rpc_get_current_cash_status', 
        params: {'p_shop_id': shopId}
      );
      
      String? currentOpenId;
      Map<String, dynamic>? statusData;
      
      if (response is List && response.isNotEmpty) {
           statusData = response.first as Map<String, dynamic>;
      } else if (response is Map) {
           statusData = response as Map<String, dynamic>;
      }

      if (statusData != null && statusData['status'] == 'OPEN') {
         currentOpenId = statusData['open_id'] as String?;
      }

      if (currentOpenId == null) return 1;

      // 2. Count orders
      final countRes = await supabaseClient
          .from('order_groups')
          .count(CountOption.exact)
          .eq('open_id', currentOpenId);
      
      return countRes;
    } catch (e) {
      print("Error getting order sequence number: $e");
      return 1;
    }
  }

  @override
  Future<int> getOrderRank(String orderGroupId) async {
    try {
      // 1. Get This Order
      final orderRes = await supabaseClient
          .from('order_groups')
          .select('open_id, created_at')
          .eq('id', orderGroupId)
          .single();
      
      final String? openId = orderRes['open_id'];
      final String createdAt = orderRes['created_at'];

      if (openId == null) return 0; // No shift context

      // 2. Count orders in same shift created on or before
      final count = await supabaseClient
          .from('order_groups')
          .count(CountOption.exact)
          .eq('open_id', openId)
          .lte('created_at', createdAt);
      
      return count;
    } catch (e) {
      print("Error getting order rank: $e");
      return 0; // Fallback
    }
  }

  @override
  Future<List<OrderItem>> getOrderItems(String orderGroupId) async {
    final res = await supabaseClient
        .from('order_items')
        .select()
        .eq('order_group_id', orderGroupId);
    
    return (res as List).map((e) => OrderItemMapper.fromJson(e)).toList();
  }

  @override
  Future<void> updateOrderItemStatus(String itemId, String status) async {
    // 1. If cancelling, try to append timestamp to Note (Fallback for Schema Cache issue)
    String? newNote;
    if (status == OrderingConstants.orderStatusCancelled) {
        // ... (note fetching logic skipped for brevity, assumed context is enough?) 
        // No, I must include full logic if I replace the whole block.
        // Wait, replace_content requires full replacement of the range.
        try {
          // Try to fetch current note using ID first
          final itemRes = await supabaseClient
              .from('order_items')
              .select('note')
              .eq('id', itemId) // Prefer 'id'
              .maybeSingle();
              
          // If not found, try item_id? No, maybeSingle returns null.
          if (itemRes != null) {
            final oldNote = itemRes['note'] as String? ?? '';
            final timeStr = DateTime.now().toUtc().toIso8601String();
            newNote = "$oldNote | 刪除:$timeStr"; 
          }
        } catch (e) {
          print("Error fetching note: $e");
        }
    }

    final Map<String, dynamic> updateData = {
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (newNote != null) {
      updateData['note'] = newNote;
    }

    try {
      // 2. Try Update using 'id'
      final res = await supabaseClient
          .from('order_items')
          .update(updateData)
          .eq('id', itemId)
          .select();
      
      if (res.isEmpty) {
         print("Warning: Update with id=$itemId returned 0 rows. Trying item_id fallback...");
         throw Exception("Zero rows updated with id");
      }
    } catch (e) {
       // Fallback: Try 'item_id'
       print("Update failed with id ($e). Trying item_id...");
       try {
         await supabaseClient
            .from('order_items')
            .update(updateData)
            .eq('item_id', itemId); // No select needed, just fire and hope.
       } catch (e2) {
          print("Critical Error: Update failed with item_id too: $e2");
       }
    }
  }

  @override
  Future<void> splitOrderGroup({
    required String sourceGroupId,
    required Map<String, int> itemQuantitiesToMove,
    required List<String> targetTableNames,
    String? existingTargetGroupId,
  }) async {
    String newGroupId;

    if (existingTargetGroupId != null && existingTargetGroupId.isNotEmpty) {
      newGroupId = existingTargetGroupId;
    } else {
      // 1. Create New Group matching Source
      final sourceGroup = await supabaseClient.from('order_groups').select().eq('id', sourceGroupId).single();

      final newGroupRes = await supabaseClient.from('order_groups').insert({
        'shop_id': sourceGroup['shop_id'],
        'table_names': targetTableNames,
        'status': OrderingConstants.orderStatusDining,
        'pax': 1,
        'note': '拆單 (來自 ${sourceGroupId.substring(0,4)})',
        'color_index': DateTime.now().millisecondsSinceEpoch % 9,
        'open_id': sourceGroup['open_id'],
      }).select('id').single();

      newGroupId = newGroupRes['id'];
    }

    // Pre-validate all items before any mutation to prevent partial splits
    for (final entry in itemQuantitiesToMove.entries) {
      final row = await supabaseClient
          .from('order_items')
          .select('quantity')
          .eq('id', entry.key)
          .maybeSingle();
      if (row == null) throw Exception('品項 ${entry.key} 不存在，無法拆單');
      final existing = (row['quantity'] as num).toInt();
      if (entry.value > existing) throw Exception('拆出數量 (${entry.value}) 超過現有數量 ($existing)');
    }

    for (final entry in itemQuantitiesToMove.entries) {
      final rawId = entry.key;
      final qtyToMove = entry.value;

      // Fetch actual item to check existing qty
      final rows = await supabaseClient
          .from('order_items')
          .select('quantity')
          .eq('id', rawId)
          .maybeSingle();
      if (rows == null) continue;
      final existingQty = (rows['quantity'] as num).toInt();

      if (qtyToMove >= existingQty) {
        // Move whole row
        await supabaseClient
            .from('order_items')
            .update({'order_group_id': newGroupId})
            .eq('id', rawId);
      } else {
        // Partial split: reduce original, insert new row with moved qty
        await supabaseClient
            .from('order_items')
            .update({'quantity': existingQty - qtyToMove})
            .eq('id', rawId);
        final original = await supabaseClient
            .from('order_items')
            .select()
            .eq('id', rawId)
            .single();
        final newRow = Map<String, dynamic>.from(original);
        newRow.remove('id');
        newRow['quantity'] = qtyToMove;
        newRow['order_group_id'] = newGroupId;
        await supabaseClient.from('order_items').insert(newRow);
      }
    }
  }

  @override
  Future<void> revertSplit({
    required String sourceGroupId,
    required String targetGroupId,
  }) async {
    // Move items back
    await supabaseClient
        .from('order_items')
        .update({'order_group_id': targetGroupId})
        .eq('order_group_id', sourceGroupId)
        .neq('status', OrderingConstants.orderStatusCancelled);

    // Cancel source group
    await supabaseClient
        .from('order_groups')
        .update({'status': OrderingConstants.orderStatusCancelled})
        .eq('id', sourceGroupId);
  }

  @override
  Future<void> updateBillingInfo({
    required String orderGroupId,
    required double serviceFeeRate,
    required double discountAmount,
    required double finalAmount,
  }) async {
    await supabaseClient.from('order_groups').update({
      'service_fee_rate': serviceFeeRate,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
    }).eq('id', orderGroupId);
  }

  @override
  Future<void> moveTable({
    required String hostGroupId,
    required List<String> oldTables,
    required List<String> newTables,
    int? colorIndex,
  }) async {
    final removedTables = oldTables.where((t) => !newTables.contains(t)).toList();
    final addedTables = newTables.where((t) => !oldTables.contains(t)).toList();
    
    if (removedTables.isEmpty) {
      await supabaseClient
          .from('order_groups')
          .update({'table_names': newTables})
          .eq('id', hostGroupId);
      return;
    }

    String targetForTransfer;
    if (addedTables.isNotEmpty) {
      targetForTransfer = addedTables.first;
    } else if (newTables.isNotEmpty) {
      targetForTransfer = newTables.first;
    } else {
       await supabaseClient
          .from('order_groups')
          .update({'table_names': newTables})
          .eq('id', hostGroupId);
       return;
    }

    // Collect merged child group tables
    final mergedChildRes = await supabaseClient
        .from('order_groups')
        .select('table_names')
        .eq('status', OrderingConstants.orderStatusMerged)
        .eq('merged_target_id', hostGroupId);
    final mergedChildTables = <String>{};
    for (final group in mergedChildRes) {
      final tables = group['table_names'];
      if (tables is List) {
        mergedChildTables.addAll(tables.cast<String>());
      }
    }

    // Guard: prevent moving host to a merged child's original table
    final conflicting = newTables.toSet().intersection(mergedChildTables);
    if (conflicting.isNotEmpty) {
      throw Exception('無法移動至 ${conflicting.join("、")}，該桌號為已併入子桌。請先拆桌再移動。');
    }

    for (final removedTable in removedTables) {
      // Skip tables belonging to merged child groups — preserve their original_table_name
      if (mergedChildTables.contains(removedTable)) continue;

      await supabaseClient
          .from('order_items')
          .update({'original_table_name': targetForTransfer})
          .eq('order_group_id', hostGroupId)
          .eq('original_table_name', removedTable);
    }

    // Handle NULL original_table_name (host's own items inserted before first move)
    // Mirrors SQLite path: local_db_service.dart moveTableLocal() L1082-1087
    await supabaseClient
        .from('order_items')
        .update({'original_table_name': targetForTransfer})
        .eq('order_group_id', hostGroupId)
        .isFilter('original_table_name', null);

    await supabaseClient
        .from('order_groups')
        .update({'table_names': newTables})
        .eq('id', hostGroupId);
  }

  @override
  Future<void> mergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
    int? colorIndex,
  }) async {
    final hostRes = await supabaseClient
        .from('order_groups')
        .select('table_names')
        .eq('id', hostGroupId)
        .single();
    final List<String> currentHostTables = List<String>.from(hostRes['table_names'] ?? []);
    final Set<String> newHostTables = currentHostTables.toSet();

    for (final targetGroupId in targetGroupIds) {
      String targetGroupName = 'Unknown';
      List<String> targetTables = [];
      try {
        final groupInfo = await supabaseClient
            .from('order_groups')
            .select('table_names')
            .eq('id', targetGroupId)
            .single();
        final List names = groupInfo['table_names'] as List;
        targetTables = names.map((e) => e.toString()).toList();
        if (targetTables.isNotEmpty) targetGroupName = targetTables.first;
      } catch (_) {}

      newHostTables.addAll(targetTables);

      await supabaseClient
          .from('order_items')
          .update({'original_table_name': targetGroupName}) 
          .eq('order_group_id', targetGroupId)
          .isFilter('original_table_name', null);

      await supabaseClient
          .from('order_items')
          .update({'order_group_id': hostGroupId})
          .eq('order_group_id', targetGroupId);
      
      await supabaseClient
          .from('order_groups')
          .update({
            'status': OrderingConstants.orderStatusMerged, 
            'note': '已併入主單',
            'merged_target_id': hostGroupId
          })
          .eq('id', targetGroupId);
    }
    
    await supabaseClient
        .from('order_groups')
        .update({
          'table_names': newHostTables.toList(),
          if (colorIndex != null) 'color_index': colorIndex,
        })
        .eq('id', hostGroupId);
  }

  @override
  Future<void> unmergeOrderGroups({
    required String hostGroupId,
    required List<String> targetGroupIds,
    Map<String, String>? tableOverrides,
  }) async {
    final hostRes = await supabaseClient
        .from('order_groups')
        .select('table_names')
        .eq('id', hostGroupId)
        .single();
    final List<String> currentHostTables = List<String>.from(hostRes['table_names'] ?? []);
    final Set<String> newHostTables = currentHostTables.toSet();

    for (final childGroupId in targetGroupIds) {
      await supabaseClient
          .from('order_groups')
          .update({
            'status': OrderingConstants.orderStatusDining, 
            'note': null,
            'merged_target_id': null
          })
          .eq('id', childGroupId);
      
      final childInfo = await supabaseClient.from('order_groups').select('table_names').eq('id', childGroupId).single();
      final List names = childInfo['table_names'] as List;
      final List<String> childTables = names.map((e) => e.toString()).toList();

      newHostTables.removeAll(childTables);

      if (childTables.isNotEmpty) {
         await supabaseClient
            .from('order_items')
            .update({'order_group_id': childGroupId})
            .eq('order_group_id', hostGroupId)
            .inFilter('original_table_name', childTables);
      }

      // If an override table is provided, update child group's table_names
      final overrideTable = tableOverrides?[childGroupId];
      if (overrideTable != null) {
        await supabaseClient
            .from('order_groups')
            .update({'table_names': [overrideTable]})
            .eq('id', childGroupId);
      }
    }

    await supabaseClient
        .from('order_groups')
        .update({'table_names': newHostTables.toList()})
        .eq('id', hostGroupId);
  }
}
