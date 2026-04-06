// lib/core/widgets/hub_status_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery205_staff_app/core/services/hub_client.dart';
import 'package:gallery205_staff_app/core/services/hub_server.dart';

/// Hub 離線警告 Banner
/// 當裝置已設定 Hub IP 但 Hub 無法連線時，顯示橘色警告
class HubStatusBanner extends ConsumerWidget {
  const HubStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHubAvailable = ref.watch(hubAvailableProvider);
    final isHubServer = ref.watch(hubServerProvider).isRunning;

    // Hub 可用、本裝置未設定 Hub IP、或本裝置就是 Hub → 不顯示
    if (isHubAvailable || !HubClient().hasHubIpConfigured || isHubServer) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFF6B00), // 深橘，與 OfflineBanner 區隔
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lan_outlined, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  '找不到主機，請確認主機 iPad 已開啟 App 並停留在前台',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
