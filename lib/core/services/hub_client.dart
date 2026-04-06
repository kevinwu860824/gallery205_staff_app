// lib/core/services/hub_client.dart
//
// Client iPad 連接 Hub 的服務
// - 健康檢查 + 30 秒定期 re-check
// - 提供 isHubAvailable 狀態給全 App 使用
// - WebSocket 訂閱桌況推播
// - 偵測衝突：開啟 Hub 前先掃描 LAN 是否已有 Hub

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:gallery205_staff_app/core/constants/app_constants.dart';
import 'package:gallery205_staff_app/core/services/hub_exceptions.dart';

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final hubClientProvider = Provider<HubClient>((ref) {
  return HubClient();
});

/// 其他元件監聽此 Provider 來判斷 Hub 是否可用
final hubAvailableProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// HubClient（Singleton）
// ---------------------------------------------------------------------------

class HubClient {
  static final HubClient _instance = HubClient._internal();
  factory HubClient() => _instance;
  HubClient._internal();

  String? _hubIp;
  bool _isHubAvailable = false;
  Timer? _healthCheckTimer;
  WebSocketChannel? _wsChannel;
  StreamController<Map<String, dynamic>>? _tableUpdateController;

  /// 快取的 Hub 可用狀態（同步讀取，無需 await）
  bool get isHubAvailable => _isHubAvailable;

  /// 是否已設定 Hub IP（用於判斷是否顯示 Hub 警告 Banner）
  bool get hasHubIpConfigured => _hubIp != null && _hubIp!.isNotEmpty;

  /// 桌況更新 Stream（訂閱 Hub WebSocket 推播）
  Stream<Map<String, dynamic>> get tableUpdates =>
      (_tableUpdateController ??= StreamController.broadcast()).stream;

  String get baseUrl => 'http://$_hubIp:${AppConstants.hubServerPort}';
  String get wsUrl => 'ws://$_hubIp:${AppConstants.hubServerPort}/ws';

  // -------------------------------------------------------------------------
  // 初始化（從 SharedPreferences 載入 Hub IP）
  // -------------------------------------------------------------------------

  Future<void> init(void Function(bool) onAvailabilityChanged) async {
    final prefs = await SharedPreferences.getInstance();

    // 有外網時先從 Supabase 讀最新 Hub IP，更新本地快取
    await _tryFetchHubIpFromSupabase(prefs);

    _hubIp = prefs.getString(AppConstants.keyHubIpAddress);

    if (_hubIp != null && _hubIp!.isNotEmpty) {
      final available = await checkHealth();
      _isHubAvailable = available;
      onAvailabilityChanged(available);
      _startHealthCheckTimer(onAvailabilityChanged);
      if (available) _connectWebSocket();
    }
  }

  /// 從 Supabase 讀取 Hub IP 並存入 SharedPreferences
  /// 外網不可用時 silent fail，使用現有快取
  Future<void> _tryFetchHubIpFromSupabase(SharedPreferences prefs) async {
    try {
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) return;

      final res = await Supabase.instance.client
          .from('shops')
          .select('hub_ip')
          .eq('id', shopId)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      final hubIp = res?['hub_ip'] as String?;
      if (hubIp != null && hubIp.isNotEmpty) {
        await prefs.setString(AppConstants.keyHubIpAddress, hubIp);
        debugPrint('📡 Hub IP synced from Supabase: $hubIp');
      }
    } catch (e) {
      debugPrint('⚠️ Cannot fetch Hub IP from Supabase, using cache: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Health Check
  // -------------------------------------------------------------------------

  Future<bool> checkHealth() async {
    if (_hubIp == null || _hubIp!.isEmpty) return false;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _startHealthCheckTimer(void Function(bool) onChanged) {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final available = await checkHealth();
      _isHubAvailable = available;
      onChanged(available);
      if (available && _wsChannel == null) _connectWebSocket();
      if (!available) _disconnectWebSocket();
    });
  }

  // -------------------------------------------------------------------------
  // 更新 Hub IP（設定頁面儲存時呼叫）
  // -------------------------------------------------------------------------

  Future<void> updateHubIp(String ip, void Function(bool) onChanged) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyHubIpAddress, ip);
    _hubIp = ip;
    _disconnectWebSocket();
    final available = await checkHealth();
    _isHubAvailable = available;
    onChanged(available);
    _startHealthCheckTimer(onChanged);
    if (available) _connectWebSocket();
  }

  // -------------------------------------------------------------------------
  // 衝突偵測：掃描 LAN 是否已有 Hub 在運行
  // 回傳已存在的 Hub IP，若無則回傳 null
  // -------------------------------------------------------------------------

  Future<String?> scanForExistingHub() async {
    // 取得目前裝置的 LAN IP 前綴（如 192.168.1）
    // 掃描 .1 ~ .254，找到第一個回應 /health 的 Hub
    // 注意：此操作可能耗時，應在背景執行並顯示 loading
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString(AppConstants.keyHubIpAddress);

    // 若已有設定的 Hub IP，先快速檢查它
    if (savedIp != null && savedIp.isNotEmpty) {
      try {
        final response = await http
            .get(Uri.parse('http://$savedIp:${AppConstants.hubServerPort}/health'))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) return savedIp;
      } catch (_) {}
    }

    // 廣播掃描（限 /24 網段，平行發送）
    // 取得本機 IP 前綴
    // 此處使用已儲存的 hubIp 前綴，或預設 192.168.1
    final prefix = _getSubnetPrefix(savedIp) ?? '192.168.1';
    final futures = List.generate(254, (i) async {
      final candidate = '$prefix.${i + 1}';
      try {
        final response = await http
            .get(Uri.parse('http://$candidate:${AppConstants.hubServerPort}/health'))
            .timeout(const Duration(seconds: 1));
        if (response.statusCode == 200) return candidate;
      } catch (_) {}
      return null;
    });

    final results = await Future.wait(futures);
    return results.firstWhere((ip) => ip != null, orElse: () => null);
  }

  /// 要求現有 Hub 降為 Client
  Future<bool> requestHubResign(String hubIp) async {
    try {
      final response = await http
          .post(Uri.parse('http://$hubIp:${AppConstants.hubServerPort}/resign'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // WebSocket
  // -------------------------------------------------------------------------

  void _connectWebSocket() {
    if (_hubIp == null) return;
    _disconnectWebSocket();
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _tableUpdateController ??= StreamController.broadcast();

      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            if (data['event'] == 'table_updated') {
              _tableUpdateController?.add(data['data'] as Map<String, dynamic>);
            }
          } catch (_) {}
        },
        onDone: () {
          _wsChannel = null;
          debugPrint('📡 HubClient WS disconnected');
        },
        onError: (_) {
          _wsChannel = null;
        },
      );
      debugPrint('📡 HubClient WS connected to $wsUrl');
    } catch (e) {
      debugPrint('❌ HubClient WS connect failed: $e');
      _wsChannel = null;
    }
  }

  void _disconnectWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  // -------------------------------------------------------------------------
  // REST Helpers（Phase 4 使用）
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> get(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> post(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 409) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw HubConflictException(data['error'] as String? ?? 'conflict', data);
      }
      debugPrint('⚠️ Hub POST $path → ${response.statusCode}: ${response.body}');
    } on HubConflictException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Hub POST $path exception: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> delete(String path) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl$path'), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('⚠️ Hub DELETE $path → ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('⚠️ Hub DELETE $path exception: $e');
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Dispose
  // -------------------------------------------------------------------------

  void dispose() {
    _healthCheckTimer?.cancel();
    _disconnectWebSocket();
    _tableUpdateController?.close();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String? _getSubnetPrefix(String? ip) {
    if (ip == null || ip.isEmpty) return null;
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}
