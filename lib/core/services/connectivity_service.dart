// lib/core/services/connectivity_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 監測網路連線狀態的 Singleton Service
/// - 對外提供 [onlineStream] (可廣播的 bool Stream)
/// - 提供同步讀取的 [isOnline] getter
/// - 偵測到「斷線 → 上線」時觸發 [onReconnected] callback
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  Stream<bool> get onlineStream => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// App 重新連線時的 callback（由外部注入，例如觸發 syncOfflineOrders）
  VoidCallback? onReconnected;

  /// 初始化：查詢目前狀態，並開始監聽變化
  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _applyResults(results, initialCheck: true);

    _sub = _connectivity.onConnectivityChanged.listen(_applyResults);
  }

  void _applyResults(List<ConnectivityResult> results, {bool initialCheck = false}) {
    final online = results.any((r) => r != ConnectivityResult.none);

    if (!initialCheck && online && !_isOnline) {
      // 斷線 → 上線：通知外部執行同步
      debugPrint('🌐 Network reconnected — triggering offline sync');
      onReconnected?.call();
    }

    _isOnline = online;
    if (!_controller.isClosed) {
      _controller.add(online);
    }
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
