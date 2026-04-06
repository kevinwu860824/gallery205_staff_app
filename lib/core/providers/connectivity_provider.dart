// lib/core/providers/connectivity_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery205_staff_app/core/services/connectivity_service.dart';

/// 全域 ConnectivityService provider（Singleton）
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// 網路狀態 Stream — true = 有網路，false = 斷線
/// 預設 true（避免初始化前閃出離線 Banner）
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  await service.init();
  yield service.isOnline; // 立刻發出目前狀態
  yield* service.onlineStream;
});
