// lib/core/widgets/offline_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery205_staff_app/core/providers/connectivity_provider.dart';

/// 全域離線提示 Banner
/// 當網路斷線時顯示於畫面頂部，恢復後自動消失
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(isOnlineProvider);

    // 還在初始化中、或已上線時不顯示
    final isOnline = isOnlineAsync.value ?? true;
    if (isOnline) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFF9F0A), // iOS warning orange
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '離線模式 — 訂單已暫存，網路恢復後自動同步',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
