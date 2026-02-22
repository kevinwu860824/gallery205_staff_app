// lib/features/ordering/data/repositories/ordering_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/table_model.dart';

class OrderingRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _getShopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('savedShopId');
  }

  // 1. 取得所有區域
  Future<List<AreaModel>> fetchAreas() async {
    final shopId = await _getShopId();
    if (shopId == null) return [];

    final response = await _supabase
        .from('table_area')
        .select()
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => AreaModel.fromMap(e))
        .toList();
  }

  // 2. 取得特定區域的桌位 (包含狀態)
  Future<List<TableModel>> fetchTablesInArea(String areaId) async {
    final shopId = await _getShopId();
    if (shopId == null) return [];

    // A. 讀取桌位設定
    final tableRes = await _supabase
        .from('tables')
        .select()
        .eq('shop_id', shopId)
        .eq('area_id', areaId)
        .order('table_name'); // 或依 sort_order

    // B. 讀取該店鋪所有 "用餐中" 的訂單
    // 注意：這裡假設 order_groups 有 'table_names' (Array) 欄位
    final activeOrdersRes = await _supabase
        .from('order_groups')
        .select('id, table_names, color_index')
        .eq('shop_id', shopId)
        .eq('status', 'dining')
        .order('created_at', ascending: true); // Sort by time so last one is "current"

    // C. 整合狀態 (Mapping)
    // 建立一個 Map: TableName -> List<OrderId>
    final Map<String, List<String>> activeOrdersMap = {};
    final Map<String, int> tableColors = {}; // Map TableName -> ColorIndex
    
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
}