import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/core/services/local_db_service.dart';
import 'package:gallery205_staff_app/features/ordering/domain/ordering_constants.dart';

/// 集中管理 Hub Device → Supabase 的同步邏輯。
/// - 只在 Hub Device 上使用（Hub Client 不直接同步 Supabase）
/// - `syncAsync(groupId)` fire-and-forget：寫完 SQLite 後立即呼叫
/// - 若同步失敗（斷網），is_synced=0 確保之後 syncOfflineOrders() 補同步
/// - `recentlySynced(id)` 供 Realtime callback 過濾自己觸發的事件
class HubSyncService {
  static final HubSyncService _instance = HubSyncService._internal();
  factory HubSyncService() => _instance;
  HubSyncService._internal();

  /// 最近 2 秒內由本機同步過的 groupId，用於防止 Realtime 雙重 broadcast
  final Set<String> _recentlySyncedIds = {};

  bool recentlySynced(String groupId) => _recentlySyncedIds.contains(groupId);

  /// Fire-and-forget 同步：呼叫後立即返回，背景同步到 Supabase
  void syncAsync(String groupId) {
    _sync(groupId).catchError((e) {
      debugPrint('⚠️ HubSyncService: Supabase sync failed for $groupId: $e');
      // 靜默失敗，is_synced=0 確保 syncOfflineOrders() 之後補上
    });
  }

  Future<void> _sync(String groupId) async {
    final db = LocalDbService();
    final group = await db.getPendingOrderGroup(groupId);
    if (group == null) return;

    final items = await db.getPendingOrderItems(groupId);
    final supabase = Supabase.instance.client;

    // ── 1. Upsert order_group ──────────────────────────────────
    List<String> tableNames = [];
    final rawTables = group['table_names'];
    if (rawTables is List) {
      tableNames = List<String>.from(rawTables);
    } else if (rawTables is String && rawTables.isNotEmpty) {
      try { tableNames = List<String>.from(jsonDecode(rawTables) as List); } catch (_) {}
    }

    Map<String, dynamic>? taxSnapshot;
    final rawTax = group['tax_snapshot'];
    if (rawTax is Map) {
      taxSnapshot = Map<String, dynamic>.from(rawTax);
    } else if (rawTax is String && rawTax.isNotEmpty) {
      try { taxSnapshot = jsonDecode(rawTax) as Map<String, dynamic>; } catch (_) {}
    }

    await supabase.from('order_groups').upsert({
      'id': group['id'],
      'shop_id': _uuidOrNull(group['shop_id']),
      'table_names': tableNames,
      'pax_adult': group['pax_adult'] ?? 0,
      'staff_name': group['staff_name'],
      'tax_snapshot': taxSnapshot,
      'color_index': group['color_index'] ?? 0,
      'created_at': group['created_at'],
      'status': group['status'] ?? OrderingConstants.orderStatusDining,
      'note': group['note'] ?? '',
      'service_fee_rate': group['service_fee_rate'] ?? 0,
      'discount_amount': group['discount_amount'] ?? 0,
      'final_amount': group['final_amount'],
      'open_id': _uuidOrNull(group['open_id']),
    });

    // ── 2. Upsert order_items ──────────────────────────────────
    for (final item in items) {
      List<dynamic> modifiers = [];
      final rawMod = item['modifiers'];
      if (rawMod is List) {
        modifiers = rawMod;
      } else if (rawMod is String && rawMod.isNotEmpty) {
        try { modifiers = jsonDecode(rawMod) as List; } catch (_) {}
      }

      List<String> printCatIds = [];
      final rawCat = item['target_print_category_ids'];
      if (rawCat is List) {
        printCatIds = List<String>.from(rawCat);
      } else if (rawCat is String && rawCat.isNotEmpty) {
        try { printCatIds = List<String>.from(jsonDecode(rawCat) as List); } catch (_) {}
      }
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
        'original_price': item['original_price'],
      });
    }

    // ── 3. 標記已同步 ──────────────────────────────────────────
    await db.markOrderGroupSynced(groupId);
    await db.markOrderItemsSynced(groupId);

    // ── 4. 記錄 recentlySynced（防 Realtime double-broadcast）──
    _recentlySyncedIds.add(groupId);
    Future.delayed(const Duration(seconds: 2), () => _recentlySyncedIds.remove(groupId));
  }

  /// 空字串轉 null，避免 Supabase UUID 欄位收到 "" 報 22P02
  String? _uuidOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : s;
  }
}
