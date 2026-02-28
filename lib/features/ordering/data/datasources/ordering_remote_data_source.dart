import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/features/ordering/data/models/ordering_models.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';

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

  Future<List<Map<String, dynamic>>> fetchFailedPrintItems(String shopId);

  Future<List<Map<String, dynamic>>> getShifts(String shopId, String date);

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
  Future<List<Map<String, dynamic>>> fetchFailedPrintItems(String shopId) async {
    try {
      final res = await supabaseClient
          .from('order_items')
          .select('*, order_groups!inner(table_names, status, shop_id)') 
          .eq('order_groups.shop_id', shopId)
          .neq('order_groups.status', 'cancelled') 
          .inFilter('print_status', ['pending', 'failed'])
          .order('created_at', ascending: false)
          .limit(50); // Safety limit

      return (res as List).map((row) {
        final group = row['order_groups'];
        final tableNames = List<String>.from(group['table_names'] ?? []);
        final tableName = tableNames.join(',');
        
        return {
          'item': OrderItemMapper.fromJson(row),
          'tableName': tableName,
          'orderGroupId': row['order_group_id'],
          'printStatus': row['print_status'],
          'createdAt': row['created_at'], // Keep for debug/filering
        };
      }).where((data) {
        final status = data['printStatus'];
        if (status == 'failed') return true; // Always show failed
        
        // For pending, check grace period (20 seconds)
        if (status == 'pending') {
          final createdAtStr = data['createdAt'] as String?;
          if (createdAtStr != null) {
            final createdAt = DateTime.tryParse(createdAtStr);
            if (createdAt != null) {
              final diff = DateTime.now().difference(createdAt);
              if (diff.inSeconds < 20) {
                 return false; // Hide if within 20s
              }
            }
          }
        }
        return true;
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
          .eq('status', 'dining');

      final Set<int> allUsedColors = {};
      final Set<int> nearbyUsedColors = {}; // 鄰桌禁用的顏色
      
      const double neighborDistanceThreshold = 250.0; // 鄰居判定距離 (pixels)

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
      
      for (int i = 0; i < 20; i++) {
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
         assignedColorIndex = DateTime.now().millisecondsSinceEpoch % 20;
      }
    } catch (e) {
      // 若查詢出錯，退到原本的安全亂數
      assignedColorIndex = DateTime.now().millisecondsSinceEpoch % 20;
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
      'status': 'dining',
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
    if (status == 'cancelled') {
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
}
