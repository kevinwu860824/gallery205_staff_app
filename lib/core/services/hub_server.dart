// lib/core/services/hub_server.dart
//
// Hub iPad 本地 HTTP Server
// - 監聽 port 7205
// - REST API 供 Client iPad 操作桌況、訂單
// - WebSocket 推播桌況變更給所有連線的 Client

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:gallery205_staff_app/core/constants/app_constants.dart';
import 'package:gallery205_staff_app/core/services/hub_sync_service.dart';
import 'package:gallery205_staff_app/core/services/local_db_service.dart';

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final hubServerProvider = Provider<HubServer>((ref) {
  final server = HubServer();
  ref.onDispose(() => server.stop());
  return server;
});

// ---------------------------------------------------------------------------
// HubServer
// ---------------------------------------------------------------------------

class HubServer {
  HttpServer? _httpServer;
  final Set<WebSocketChannel> _wsClients = {};
  bool _isRunning = false;
  final LocalDbService _db = LocalDbService();
  StreamSubscription<Map<String, dynamic>>? _tableUpdateSub;
  RealtimeChannel? _realtimeChannel;

  /// 收到新訂單或結帳時觸發（由 main.dart 注入，用於即時同步到 Supabase）
  VoidCallback? onOrderChanged;

  /// Client 請求立即同步時觸發（可 await，/sync/trigger 用）
  Future<void> Function()? onSyncRequested;

  bool get isRunning => _isRunning;

  // -------------------------------------------------------------------------
  // start / stop / restart
  // -------------------------------------------------------------------------

  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      final router = Router();

      _tableUpdateSub ??= _db.onTableUpdate.listen((data) {
        if (_isRunning) {
          broadcastTableUpdate(data);
          onOrderChanged?.call();
        }
      });

      router.get('/health', _handleHealth);
      router.get('/tables', _handleGetTables);
      router.post('/tables/seat', _handleSeatTable);
      router.post('/tables/clear', _handleClearTable);
      router.post('/orders', _handlePostOrder);
      router.post('/orders/<id>/items', _handleAddOrderItems);
      router.get('/orders/active', _handleGetActiveOrders);
      router.get('/orders/<id>/related', _handleGetRelatedOrders);
      router.get('/orders/<id>', _handleGetOrder);
      router.post('/orders/<id>/void_item', _handleVoidItem);
      router.post('/orders/<id>/treat_item', _handleTreatItem);
      router.post('/orders/<id>/undo_void', _handleUndoVoid);
      router.post('/orders/<id>/pax', _handleUpdatePax);
      router.post('/orders/<id>/note', _handleUpdateNote);
      router.get('/orders/<id>/merged_children', _handleGetMergedChildren);
      router.post('/orders/<id>/billing', _handleUpdateBilling);
      router.post('/orders/<id>/void_group', _handleVoidGroup);
      router.post('/orders/<id>/revert_split', _handleRevertSplit);
      router.post('/orders/<id>/split_pax', _handleSplitPax);
      router.post('/orders/<id>/split', _handleSplit);
      router.post('/orders/<id>/move', _handleMoveTable);
      router.post('/orders/<id>/merge', _handleMergeGroups);
      router.post('/orders/<id>/unmerge', _handleUnmergeGroups);
      router.post('/checkout', _handleCheckout);
      router.get('/menu', _handleGetMenu);
      router.post('/resign', _handleResign);
      router.get('/sync/pending', _handleGetSyncPending);
      router.post('/sync/ack', _handleSyncAck);
      router.post('/sync/trigger', _handleSyncTrigger);
      router.post('/debug/clear', _handleDebugClear);
      router.get('/debug/diagnose', _handleDebugDiagnose);
      router.post('/debug/run-sync', _handleDebugRunSync);
      router.get('/print/failed', _handleGetFailedPrints);
      router.post('/print/status', _handleUpdatePrintStatus);
      router.get('/receipt-prints', _handleGetReceiptPrints);
      router.post('/receipt-prints', _handleAddReceiptPrint);
      router.delete('/receipt-prints/<id>', _handleDeleteReceiptPrint);
      router.get('/ws', webSocketHandler(_handleWebSocket));

      final pipeline = const Pipeline()
          .addMiddleware(_corsMiddleware())
          .addHandler(router.call);

      _httpServer = await shelf_io.serve(
        pipeline,
        InternetAddress.anyIPv4,
        AppConstants.hubServerPort,
      );

      _isRunning = true;
      debugPrint('✅ HubServer started on port ${AppConstants.hubServerPort}');
      await _saveHubIpToSupabase();
      unawaited(_subscribeToSupabaseRealtime());
      return true;
    } catch (e) {
      debugPrint('❌ HubServer start failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    _tableUpdateSub?.cancel();
    _tableUpdateSub = null;
    if (_realtimeChannel != null) {
      await Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    await _httpServer?.close(force: true);
    _httpServer = null;
    for (final client in Set.from(_wsClients)) {
      unawaited(client.sink.close());
    }
    _wsClients.clear();
    _isRunning = false;
    debugPrint('🛑 HubServer stopped');

    // Supabase clear 在背景執行，不阻塞 UI
    unawaited(_clearHubFromSupabase());
  }

  Future<void> _subscribeToSupabaseRealtime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) return;

      _realtimeChannel = Supabase.instance.client
          .channel('hub:order_groups:$shopId')
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
              final id = (payload.newRecord['id'] ?? payload.oldRecord['id']) as String? ?? '';
              if (id.isNotEmpty && HubSyncService().recentlySynced(id)) return;
              debugPrint('📡 Realtime: external order_groups change, broadcasting');
              broadcastTableUpdate({'is_refresh': true, 'source': 'realtime'});
            },
          )
          .subscribe();

      debugPrint('✅ HubServer subscribed to Supabase Realtime for shop $shopId');
    } catch (e) {
      debugPrint('⚠️ HubServer Realtime subscription failed: $e');
    }
  }

  Future<void> _clearHubFromSupabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) return;
      await Supabase.instance.client.from('shops').update({
        'hub_ip': null,
        'hub_device_name': null,
        'hub_ip_updated_at': null,
      }).eq('id', shopId).timeout(const Duration(seconds: 5));
      debugPrint('✅ Hub info cleared from Supabase');
    } catch (e) {
      debugPrint('⚠️ Failed to clear Hub info from Supabase: $e');
    }
  }

  Future<bool> restart() async {
    await stop();
    return start();
  }

  /// Hub 啟動成功後，把自己的 LAN IP 寫入 Supabase shops.hub_ip
  /// Client 啟動時讀取，免去手動輸入
  Future<void> _saveHubIpToSupabase() async {
    try {
      final ip = await NetworkInfo().getWifiIP();
      debugPrint('🔍 Hub save - WiFi IP: $ip');
      if (ip == null || ip.isEmpty) {
        debugPrint('⚠️ Hub save aborted: WiFi IP is null/empty');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      debugPrint('🔍 Hub save - shopId: $shopId');
      if (shopId == null) {
        debugPrint('⚠️ Hub save aborted: savedShopId is null');
        return;
      }

      final deviceName = await _getDeviceName();
      debugPrint('🔍 Hub save - deviceName: $deviceName');
      // 存到本地，供 hub_settings_screen 比對自身
      await prefs.setString('hubDeviceName', deviceName);
      await Supabase.instance.client.from('shops').update({
        'hub_ip': ip,
        'hub_device_name': deviceName,
        'hub_ip_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', shopId);

      debugPrint('✅ Hub IP saved to Supabase: $ip ($deviceName)');
    } catch (e) {
      debugPrint('⚠️ Failed to save Hub IP to Supabase: $e');
    }
  }

  Future<String> _getDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        // iOS 16+ 限制自訂名稱，用型號 + identifierForVendor 後 6 碼作為唯一識別
        final id = (ios.identifierForVendor ?? '').replaceAll('-', '');
        final suffix = id.length >= 6 ? id.substring(id.length - 6).toUpperCase() : id.toUpperCase();
        return '${ios.name}-$suffix'; // e.g. "iPad-A3F2B1"
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return '${android.model}-${android.id.substring(0, 6).toUpperCase()}';
      }
    } catch (e) {
      debugPrint('⚠️ _getDeviceName failed: $e');
    }
    return Platform.localHostname;
  }

  // -------------------------------------------------------------------------
  // WebSocket
  // -------------------------------------------------------------------------

  void _handleWebSocket(WebSocketChannel channel) {
    _wsClients.add(channel);
    debugPrint('📡 WS client connected. Total: ${_wsClients.length}');

    channel.stream.listen(
      (_) {},
      onDone: () {
        _wsClients.remove(channel);
        debugPrint('📡 WS client disconnected. Total: ${_wsClients.length}');
      },
      onError: (_) => _wsClients.remove(channel),
    );
  }

  /// 廣播桌況變更給所有 WebSocket Client
  void broadcastTableUpdate(Map<String, dynamic> tableData) {
    final message = jsonEncode({
      'event': 'table_updated',
      'data': tableData,
    });
    for (final client in Set.from(_wsClients)) {
      try {
        client.sink.add(message);
      } catch (_) {
        _wsClients.remove(client);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Route Handlers
  // -------------------------------------------------------------------------

  Response _handleHealth(Request request) {
    return _jsonOk({
      'status': 'ok',
      'ws_clients': _wsClients.length,
      'port': AppConstants.hubServerPort,
    });
  }

  Future<Response> _handleGetTables(Request request) async {
    try {
      final tables = await _db.getCachedTables();
      final activeByTable = await _db.getActiveGroupIdsByTable();
      final enriched = tables.map((t) {
        final name = t['table_name'] as String? ?? '';
        return {
          ...t,
          'active_order_group_ids': activeByTable[name] ?? [],
        };
      }).toList();
      return _jsonOk({'tables': enriched});
    } catch (e) {
      return _jsonError('Failed to get tables: $e');
    }
  }

  Future<Response> _handleSeatTable(Request request) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      // ── Race condition 防護：桌位已有人則回 409 ──
      final tableName = body['table_name'] as String?;
      if (tableName != null) {
        final existing = await _db.getCachedTable(tableName);
        if (existing != null && existing['status'] == 'occupied') {
          return Response(
            409,
            body: jsonEncode({
              'error': 'table_occupied',
              'existing_group_id': existing['current_order_group_id'],
              'message': '桌位已有訂單，請重新整理',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      final tableData = {
        'table_name': tableName,
        'area_id': body['area_id'],
        'status': 'occupied',
        'current_order_group_id': body['order_group_id'],
        'color_index': body['color_index'],
        'pax_adult': body['pax_adult'] ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _db.upsertCachedTable(tableData);

      // Also ensure a pending_order_group exists with this pax
      if (body['order_group_id'] != null) {
        await _db.updatePendingOrderGroupPax(
          body['order_group_id'],
          pax: body['pax_adult'] ?? 0,
          adult: body['pax_adult'] ?? 0,
        );
      }

      broadcastTableUpdate(tableData);
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to seat table: $e');
    }
  }

  Future<Response> _handleClearTable(Request request) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      final tableName = body['table_name'] as String?;
      if (tableName == null) return _jsonError('table_name required');

      await _db.clearCachedTable(tableName);

      // 若有未結帳的 pending_order_group，標記為取消
      final orderGroupId = body['order_group_id'] as String?;
      if (orderGroupId != null) {
        final group = await _db.getPendingOrderGroup(orderGroupId);
        if (group != null) {
          final wasAlreadySynced = (group['is_synced'] as int? ?? 0) == 1;
          await _db.cancelPendingOrderGroup(orderGroupId);
          // 已同步過的 group 需要再推一次取消狀態到 Supabase
          if (wasAlreadySynced) {
            HubSyncService().syncAsync(orderGroupId);
          }
        }
      }

      broadcastTableUpdate({
        'table_name': tableName,
        'status': 'empty',
        'updated_at': DateTime.now().toIso8601String(),
      });
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to clear table: $e');
    }
  }

  Future<Response> _handlePostOrder(Request request) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      // 寫入訂單 header
      final group = Map<String, dynamic>.from(body['order_group'] as Map);

      // ── Race condition 防護：新訂單才需檢查桌位 ──
      final groupId = group['id'] as String?;
      if (groupId != null) {
        final existingGroup = await _db.getPendingOrderGroup(groupId);
        if (existingGroup == null) {
          // 全新訂單：確認桌位未被搶佔
          final rawTableNames = group['table_names'];
          List<String> tableNames = [];
          if (rawTableNames is String && rawTableNames.isNotEmpty) {
            try { tableNames = List<String>.from(jsonDecode(rawTableNames) as List); } catch (_) {}
          } else if (rawTableNames is List) {
            tableNames = List<String>.from(rawTableNames);
          }
          for (final tableName in tableNames) {
            final existing = await _db.getCachedTable(tableName);
            if (existing != null && existing['status'] == 'occupied') {
              return Response(
                409,
                body: jsonEncode({
                  'error': 'table_occupied',
                  'table_name': tableName,
                  'existing_group_id': existing['current_order_group_id'],
                  'message': '桌位已有訂單，請重新整理',
                }),
                headers: {'Content-Type': 'application/json'},
              );
            }
          }
        }
      }

      await _db.insertPendingOrderGroup(group);

      // 寫入訂單明細
      final items = (body['order_items'] as List?)?.cast<Map<String, dynamic>>();
      if (items != null) {
        for (final item in items) {
          await _db.insertPendingOrderItem(item);
        }
      }

      HubSyncService().syncAsync(group['id'] as String);
      onOrderChanged?.call();
      return _jsonOk({'success': true, 'order_group_id': group['id']});
    } catch (e) {
      return _jsonError('Failed to post order: $e');
    }
  }

  Future<Response> _handleAddOrderItems(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      final items =
          (body['order_items'] as List?)?.cast<Map<String, dynamic>>();
      if (items == null) return _jsonError('order_items required');

      final group = await _db.getPendingOrderGroup(id);
      if (group == null) {
        return Response.notFound(
          jsonEncode({'error': 'Order not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      for (final item in items) {
        await _db.insertPendingOrderItem(item);
      }
      HubSyncService().syncAsync(id);
      return _jsonOk({'success': true, 'order_group_id': id});
    } catch (e) {
      return _jsonError('Failed to add order items: $e');
    }
  }

  Future<Response> _handleGetActiveOrders(Request request) async {
    try {
      final orders = await _db.getAllActivePendingOrderGroupsWithItems();
      return _jsonOk({'orders': orders});
    } catch (e) {
      return _jsonError('Failed to get active orders: $e');
    }
  }

  Future<Response> _handleGetRelatedOrders(Request request, String id) async {
    try {
      final activeByTable = await _db.getActiveGroupIdsByTable();
      // Find tables that contain this group ID
      final relatedTables = activeByTable.entries
          .where((e) => e.value.contains(id))
          .map((e) => e.key)
          .toSet();
      // Collect all group IDs from those tables
      final relatedGroupIds = <String>{};
      for (final table in relatedTables) {
        relatedGroupIds.addAll(activeByTable[table] ?? []);
      }
      // Return full order data for related groups
      final allActive = await _db.getAllActivePendingOrderGroupsWithItems();
      final related = allActive.where((o) => relatedGroupIds.contains(o['id'] as String? ?? '')).toList();
      return _jsonOk({'orders': related});
    } catch (e) {
      return _jsonError('Failed to get related orders: $e');
    }
  }

  Future<Response> _handleGetOrder(Request request, String id) async {
    try {
      final group = await _db.getPendingOrderGroup(id);
      if (group == null) {
        return Response.notFound(
          jsonEncode({'error': 'Order not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      final items = await _db.getPendingOrderItems(id);
      return _jsonOk({'order_group': group, 'order_items': items});
    } catch (e) {
      return _jsonError('Failed to get order: $e');
    }
  }

  Future<Response> _handleVoidItem(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');
      
      final itemId = body['item_id'] as String?;
      if (itemId == null) return _jsonError('item_id required');
      
      await _db.updatePendingOrderItemStatus(itemId, 'cancelled');
      HubSyncService().syncAsync(id);

      // Broadcast update
      final group = await _db.getPendingOrderGroup(id);
      if (group != null) {
         broadcastTableUpdate({
           'table_name': group['table_names'],
           'status': group['status'],
           'updated_at': DateTime.now().toIso8601String(),
         });
      }

      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to void item: $e');
    }
  }

  Future<Response> _handleTreatItem(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      final itemIds = List<String>.from(body['item_ids'] ?? []);
      if (itemIds.isEmpty) return _jsonError('item_ids required');
      final price = (body['price'] as num?)?.toDouble();
      if (price == null) return _jsonError('price required');
      final originalPrice = (body['original_price'] as num?)?.toDouble();

      for (final itemId in itemIds) {
        await _db.updatePendingOrderItemPrice(itemId, price: price, originalPrice: originalPrice);
      }
      HubSyncService().syncAsync(id);

      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to treat item: $e');
    }
  }

  Future<Response> _handleUndoVoid(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');
      
      final itemIds = List<String>.from(body['item_ids'] ?? []);
      if (itemIds.isEmpty) return _jsonError('item_ids required');
      
      for (final itemId in itemIds) {
        await _db.updatePendingOrderItemStatus(itemId, 'submitted');
      }
      HubSyncService().syncAsync(id);

      // Broadcast update
      final group = await _db.getPendingOrderGroup(id);
      if (group != null) {
         broadcastTableUpdate({
           'table_name': group['table_names'],
           'status': group['status'],
           'updated_at': DateTime.now().toIso8601String(),
         });
      }

      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to undo void: $e');
    }
  }

  Future<Response> _handleUpdatePax(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      final pax = body['pax'] as int?;
      final adult = body['pax_adult'] as int?;
      final child = body['pax_child'] as int?;

      await _db.updatePendingOrderGroupPax(id,
          pax: pax, adult: adult, child: child);

      HubSyncService().syncAsync(id);
      broadcastTableUpdate({'order_group_id': id, 'pax': pax});

      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to update pax: $e');
    }
  }

  Future<Response> _handleUpdateBilling(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');
      
      await _db.updatePendingOrderGroupBilling(
        id,
        serviceFeeRate: body['service_fee_rate'] != null ? (body['service_fee_rate'] as num).toDouble() : null,
        discountAmount: body['discount_amount'] != null ? (body['discount_amount'] as num).toDouble() : null,
        finalAmount: body['final_amount'] != null ? (body['final_amount'] as num).toDouble() : null,
      );

      HubSyncService().syncAsync(id);

      // Update the table status to trigger broadcast
      final group = await _db.getPendingOrderGroup(id);
      if (group != null) {
        broadcastTableUpdate({
          'table_name': group['table_names'],
          'status': group['status'],
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to update billing: $e');
    }
  }
  
  Future<Response> _handleUpdateNote(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');
      
      final note = body['note'] as String?;
      if (note == null) return _jsonError('note required');
      
      await _db.updatePendingOrderGroupNote(id, note);

      HubSyncService().syncAsync(id);

      // Update the table status to trigger broadcast
      final group = await _db.getPendingOrderGroup(id);
      if (group != null) {
        broadcastTableUpdate({
          'table_name': group['table_names'],
          'status': group['status'],
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to update note: $e');
    }
  }

  Future<Response> _handleGetMergedChildren(Request request, String id) async {
    try {
      final children = await _db.getMergedChildGroupIds(id);
      final childGroups = await _db.getMergedChildGroups(id);
      return _jsonOk({
        'child_group_ids': children,
        'child_groups': childGroups,
      });
    } catch (e) {
      return _jsonError('Failed to get merged children: $e');
    }
  }


  Future<Response> _handleVoidGroup(Request request, String id) async {
    try {
      final group = await _db.getPendingOrderGroup(id);
      await _db.cancelPendingOrderGroup(id);
      // 直接 await 更新 Supabase，確保 Hub Client 刷新交易紀錄時已反映作廢狀態
      try {
        await Supabase.instance.client.from('order_groups').update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', id);
      } catch (e) {
        debugPrint('⚠️ _handleVoidGroup: Supabase update failed: $e');
        HubSyncService().syncAsync(id); // 網路失敗時仍嘗試背景同步
      }

      if (group != null) {
        final rawTableNames = group['table_names'];
        List<String> tableNames = [];
        if (rawTableNames is String) {
          tableNames = List<String>.from(jsonDecode(rawTableNames));
        } else if (rawTableNames is List) {
          tableNames = List<String>.from(rawTableNames);
        }
        for (final tableName in tableNames) {
          await _db.clearCachedTable(tableName);
          broadcastTableUpdate({
            'table_name': tableName,
            'status': 'empty',
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to void group: $e');
    }
  }

  Future<Response> _handleRevertSplit(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      final targetId = body['target_id'] as String?;
      if (targetId == null) return _jsonError('target_id required');

      await _db.revertSplitLocal(
        sourceGroupId: id,
        targetGroupId: targetId,
      );

      HubSyncService().syncAsync(id);
      broadcastTableUpdate({'is_refresh': true, 'source_group_id': id});
      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to revert split: $e');
    }
  }

  Future<Response> _handleSplitPax(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      final pax = body['pax'] as int?;
      final totalAmount = (body['total_amount'] as num?)?.toDouble();
      if (pax == null || totalAmount == null) {
        return _jsonError('pax and total_amount required');
      }

      await _db.splitByPaxLocal(
        sourceGroupId: id,
        pax: pax,
        totalAmount: totalAmount,
      );

      HubSyncService().syncAsync(id);
      broadcastTableUpdate({'is_refresh': true, 'source_group_id': id});
      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to split by pax: $e');
    }
  }

  Future<Response> _handleSplit(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');
      
      final targetTables = List<String>.from(body['target_tables'] ?? []);
      final targetGroupId = body['target_group_id'] as String?;
      final Map<String, int> itemQuantitiesToMove = {};
      final rawQty = body['item_quantities'];
      if (rawQty is Map) {
        rawQty.forEach((k, v) {
          if (k is String && v is num) itemQuantitiesToMove[k] = v.toInt();
        });
      }

      await _db.splitOrderGroupLocal(
        sourceGroupId: id,
        itemQuantitiesToMove: itemQuantitiesToMove,
        targetTables: targetTables,
        targetGroupId: targetGroupId,
      );

      HubSyncService().syncAsync(id);
      broadcastTableUpdate({'is_refresh': true, 'source_group_id': id, 'target_group_id': targetGroupId});
      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to split: $e');
    }
  }

  Future<Response> _handleMoveTable(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');
      
      final oldTables = List<String>.from(body['old_tables'] ?? []);
      final newTables = List<String>.from(body['new_tables'] ?? []);
      final int? colorIndex = body['color_index'] as int?;

      await _db.moveTableLocal(
        hostGroupId: id,
        oldTables: oldTables,
        newTables: newTables,
        colorIndex: colorIndex,
      );

      HubSyncService().syncAsync(id);
      broadcastTableUpdate({'is_refresh': true, 'host_group_id': id});
      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to move table: $e');
    }
  }

  Future<Response> _handleMergeGroups(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      final targetGroupIds = List<String>.from(body['target_group_ids'] ?? []);
      final int? colorIndex = body['color_index'] as int?;

      await _db.mergeOrderGroupsLocal(
        hostGroupId: id,
        targetGroupIds: targetGroupIds,
        colorIndex: colorIndex,
      );

      HubSyncService().syncAsync(id);
      broadcastTableUpdate({'is_refresh': true, 'host_group_id': id});
      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to merge groups: $e');
    }
  }

  Future<Response> _handleUnmergeGroups(Request request, String id) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      final targetGroupIds = List<String>.from(body['target_group_ids'] ?? []);
      final rawOverrides = body['table_overrides'] as Map<String, dynamic>?;
      final tableOverrides = rawOverrides?.map((k, v) => MapEntry(k, v as String));

      await _db.unmergeOrderGroupsLocal(
        hostGroupId: id,
        targetGroupIds: targetGroupIds,
        tableOverrides: tableOverrides,
      );

      HubSyncService().syncAsync(id);
      broadcastTableUpdate({'is_refresh': true, 'host_group_id': id});
      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to unmerge groups: $e');
    }
  }

  Future<Response> _handleCheckout(Request request) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');
      final checkoutMap = body['checkout'] as Map?;
      debugPrint('💳 Hub received /checkout: group=${checkoutMap?['order_group_id']} amount=${checkoutMap?['final_amount']}');
      debugPrint('💳 table_names=${body['table_names']}');

      final checkoutData = Map<String, dynamic>.from(body['checkout'] as Map);
      await _db.insertPendingCheckout(checkoutData);

      // 標記 order_group 為已結帳，讓交易紀錄可正確顯示並導航
      final groupId = checkoutData['order_group_id'] as String?;
      if (groupId != null) {
        await _db.updatePendingOrderGroupStatus(groupId, 'completed');
      }

      // 清桌 + 廣播（支援多桌）
      final rawTableNames = body['table_names'];
      final List<String> tableNames;
      if (rawTableNames is List && rawTableNames.isNotEmpty) {
        tableNames = List<String>.from(rawTableNames);
      } else {
        final singleName = body['table_name'] as String?;
        tableNames = singleName != null ? [singleName] : [];
      }
      for (final tn in tableNames) {
        await _db.clearCachedTable(tn);
        broadcastTableUpdate({
          'table_name': tn,
          'status': 'empty',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to checkout: $e');
    }
  }

  Future<Response> _handleGetMenu(Request request) async {
    try {
      final items = await _db.getCachedMenuItems();
      return _jsonOk({'menu': items});
    } catch (e) {
      return _jsonError('Failed to get menu: $e');
    }
  }

  Future<Response> _handleGetFailedPrints(Request request) async {
    try {
      final rows = await _db.fetchFailedPrintItemsLocal();
      final items = rows.map((row) => {
        'item': {
          'id': row['id'],
          'item_id': row['item_id'],
          'item_name': row['item_name'],
          'quantity': row['quantity'],
          'price': row['price'],
          'modifiers': row['modifiers'],
          'note': row['note'] ?? '',
          'target_print_category_ids': row['target_print_category_ids'],
          'status': row['status'],
          'print_status': row['print_status'],
        },
        'tableName': row['_table_name_str'] ?? '',
        'orderGroupId': row['order_group_id'] ?? '',
        'printStatus': row['print_status'] ?? 'failed',
        'printJobs': row['print_jobs'] is Map ? row['print_jobs'] : <String, dynamic>{},
      }).toList();
      return _jsonOk({'items': items});
    } catch (e) {
      return _jsonError('Failed to fetch failed prints: $e');
    }
  }

  Future<Response> _handleUpdatePrintStatus(Request request) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');
      final itemIds = List<String>.from(body['item_ids'] ?? []);
      final status = body['status'] as String? ?? 'pending';
      await _db.updatePrintStatusLocal(itemIds, status);
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to update print status: $e');
    }
  }

  Future<Response> _handleGetReceiptPrints(Request request) async {
    try {
      final rows = await _db.getPendingReceiptPrints();
      return _jsonOk({'items': rows});
    } catch (e) {
      return _jsonError('Failed to get receipt prints: $e');
    }
  }

  Future<Response> _handleAddReceiptPrint(Request request) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');
      await _db.addPendingReceiptPrint(Map<String, dynamic>.from(body));
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to add receipt print: $e');
    }
  }

  Future<Response> _handleDeleteReceiptPrint(Request request, String id) async {
    try {
      await _db.removePendingReceiptPrint(id);
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to delete receipt print: $e');
    }
  }

  Future<Response> _handleGetSyncPending(Request request) async {
    try {
      // 只回傳已結帳但未同步的訂單（dining 中的訂單由 Hub 管，不需提示 Client）
      final allOrders = await _db.getUnsyncedOrderGroupsWithCheckout();
      final completedOrders = allOrders.where((o) => o['checkout'] != null).toList();
      return _jsonOk({'orders': completedOrders});
    } catch (e) {
      return _jsonError('Failed to get pending sync data: $e');
    }
  }

  Future<Response> _handleSyncAck(Request request) async {
    try {
      final body = await _parseBody(request);
      if (body == null) return _jsonError('Invalid body');

      final ids = (body['order_group_ids'] as List?)?.cast<String>();
      if (ids == null) return _jsonError('order_group_ids required');

      for (final id in ids) {
        await _db.markOrderGroupAndCheckoutSynced(id);
      }
      return _jsonOk({'success': true, 'synced': ids.length});
    } catch (e) {
      return _jsonError('Failed to ack sync: $e');
    }
  }

  Future<Response> _handleSyncTrigger(Request request) async {
    onOrderChanged?.call();
    try {
      await onSyncRequested?.call();
    } catch (e) {
      debugPrint('⚠️ Sync trigger error: $e');
    }
    return _jsonOk({'success': true});
  }

  Future<Response> _handleDebugClear(Request request) async {
    try {
      await _db.clearAllOrderData();
      onOrderChanged?.call();
      return _jsonOk({'success': true});
    } catch (e) {
      return _jsonError('Failed to clear data: $e');
    }
  }

  Future<Response> _handleDebugDiagnose(Request request) async {
    try {
      final db = await _db.database;

      final groups = await db.query('pending_order_groups',
          columns: ['id', 'status', 'is_synced', 'table_names', 'created_at'],
          orderBy: 'created_at ASC');

      final checkouts = await db.query('pending_checkouts',
          columns: ['id', 'order_group_id', 'is_synced', 'checkout_time'],
          orderBy: 'checkout_time ASC');

      final readyToSync = await _db.getUnsyncedOrderGroupsWithCheckout();
      final readySummary = readyToSync.map((o) {
        final g = o['group'] as Map;
        return {
          'group_id': g['id'],
          'status': g['status'],
          'is_synced': g['is_synced'],
          'has_checkout': o['checkout'] != null,
          'item_count': (o['items'] as List).length,
        };
      }).toList();

      return _jsonOk({
        'pending_groups': groups.map((r) => Map<String, dynamic>.from(r)).toList(),
        'pending_checkouts': checkouts.map((r) => Map<String, dynamic>.from(r)).toList(),
        'ready_to_sync': readySummary,
      });
    } catch (e) {
      return _jsonError('Diagnose failed: $e');
    }
  }

  Future<Response> _handleDebugRunSync(Request request) async {
    try {
      await onSyncRequested?.call();
      return _jsonOk({'success': true, 'message': 'Sync completed'});
    } catch (e) {
      return _jsonError('Sync failed: $e');
    }
  }

  Future<Response> _handleResign(Request request) async {
    unawaited(Future.delayed(const Duration(milliseconds: 500), () => stop()));
    return _jsonOk({'success': true, 'message': 'Hub resigning'});
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _parseBody(Request request) async {
    try {
      final body = await request.readAsString();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Response _jsonOk(Map<String, dynamic> data) {
    return Response.ok(
      jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Response _jsonError(String message, {int statusCode = 500}) {
    return Response(
      statusCode,
      body: jsonEncode({'error': message}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Middleware _corsMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await inner(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}
