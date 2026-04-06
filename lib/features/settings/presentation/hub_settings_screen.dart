// lib/features/settings/presentation/hub_settings_screen.dart
//
// Hub 設定頁面
// - 切換此裝置為 Hub（啟動 HubServer + wakelock）
// - 顯示目前 Hub IP
// - 輸入連接的 Hub IP（Client 裝置）
// - 開啟 Hub 前偵測 LAN 是否已有衝突 Hub

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:gallery205_staff_app/core/constants/app_constants.dart';
import 'package:gallery205_staff_app/core/services/hub_server.dart';
import 'package:gallery205_staff_app/core/services/hub_client.dart';

class HubSettingsScreen extends ConsumerStatefulWidget {
  const HubSettingsScreen({super.key});

  @override
  ConsumerState<HubSettingsScreen> createState() => _HubSettingsScreenState();
}

class _HubSettingsScreenState extends ConsumerState<HubSettingsScreen> {
  bool _isHubDevice = false;
  String _deviceIp = '—';
  final TextEditingController _hubIpController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;
  bool _isFetching = false;
  String? _testResult;
  bool _isShiftOpen = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _hubIpController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isHub = prefs.getBool(AppConstants.keyIsHubDevice) ?? false;
    final hubIp = prefs.getString(AppConstants.keyHubIpAddress) ?? '';
    final deviceIp = await NetworkInfo().getWifiIP() ?? '—';

    if (mounted) {
      setState(() {
        _isHubDevice = isHub;
        _deviceIp = deviceIp;
        _hubIpController.text = hubIp;
      });
    }

    await _checkShiftStatus();
  }

  Future<void> _checkShiftStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) return;

      final dynamic response = await Supabase.instance.client.rpc(
        'rpc_get_current_cash_status',
        params: {'p_shop_id': shopId},
      );

      Map<String, dynamic>? statusData;
      if (response is List && response.isNotEmpty) {
        statusData = response.first as Map<String, dynamic>;
      } else if (response is Map) {
        statusData = Map<String, dynamic>.from(response);
      }

      if (mounted) {
        setState(() {
          _isShiftOpen = statusData?['status'] == 'OPEN';
        });
      }
    } catch (e) {
      debugPrint('Error checking shift status: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Hub Mode 切換
  // -------------------------------------------------------------------------

  Future<void> _onHubToggleChanged(bool value) async {
    if (value) {
      await _enableHubMode();
    } else {
      await _disableHubMode();
    }
  }

  Future<void> _enableHubMode() async {
    setState(() => _isLoading = true);

    // 1. 查 Supabase 是否有其他裝置已登記為 Hub
    final conflict = await _checkExistingHubOnSupabase();

    if (!mounted) return;

    if (conflict != null) {
      setState(() => _isLoading = false);
      await showDialog(
        context: context,
        builder: (_) => _HubBlockedDialog(
          deviceName: conflict['deviceName']!,
          hubIp: conflict['hubIp']!,
        ),
      );
      return;
    }

    // 2. 啟動 HubServer
    final success = await ref.read(hubServerProvider).start();

    if (!mounted) return;

    if (!success) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('啟動 Hub 失敗，請重試')),
      );
      return;
    }

    // 3. 儲存設定 + 啟動 wakelock
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsHubDevice, true);
    await WakelockPlus.enable();

    ref.read(hubAvailableProvider.notifier).state = true;

    if (mounted) {
      setState(() {
        _isHubDevice = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _disableHubMode() async {
    setState(() => _isLoading = true);

    await ref.read(hubServerProvider).stop();
    await WakelockPlus.disable();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsHubDevice, false);

    ref.read(hubAvailableProvider.notifier).state = false;

    if (mounted) {
      setState(() {
        _isHubDevice = false;
        _isLoading = false;
      });
    }
  }

  // -------------------------------------------------------------------------
  // Hub 衝突檢查（Supabase）
  // -------------------------------------------------------------------------

  /// 查 Supabase 是否有其他裝置已登記為 Hub。
  /// 若登記的 IP 是自己（App 閃退殘留），自動清除後放行。
  /// 若是其他裝置，強制要求先去關閉。
  Future<Map<String, String>?> _checkExistingHubOnSupabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) return null;

      final res = await Supabase.instance.client
          .from('shops')
          .select('hub_ip, hub_device_name')
          .eq('id', shopId)
          .maybeSingle();

      final hubIp = res?['hub_ip'] as String?;
      if (hubIp == null || hubIp.isEmpty) return null;

      // 若登記的 IP 或裝置名稱跟自己一樣，是 App 閃退/換網路殘留的舊資料，清掉放行
      final myIp = await NetworkInfo().getWifiIP();
      final myDeviceName = prefs.getString('hubDeviceName'); // hub_server 啟動時存入
      final storedName = res?['hub_device_name'] as String?;
      final isSelf = (myIp != null && myIp == hubIp) ||
          (myDeviceName != null && myDeviceName == storedName);
      if (isSelf) {
        await Supabase.instance.client.from('shops').update({
          'hub_ip': null,
          'hub_device_name': null,
          'hub_ip_updated_at': null,
        }).eq('id', shopId);
        return null;
      }

      final deviceName = (res?['hub_device_name'] as String?)?.isNotEmpty == true
          ? res!['hub_device_name'] as String
          : hubIp;

      return {'deviceName': deviceName, 'hubIp': hubIp};
    } catch (_) {
      return null; // 查不到 Supabase 時不擋
    }
  }

  // -------------------------------------------------------------------------
  // Client 端：儲存 Hub IP
  // -------------------------------------------------------------------------

  Future<void> _saveHubIp() async {
    final ip = _hubIpController.text.trim();
    if (ip.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyHubIpAddress, ip);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hub IP 已儲存')),
      );
    }
  }

  Future<void> _fetchHubIpFromSupabase() async {
    setState(() => _isFetching = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('找不到店家資料，請重新登入')),
        );
        return;
      }

      final res = await Supabase.instance.client
          .from('shops')
          .select('hub_ip')
          .eq('id', shopId)
          .maybeSingle();

      final ip = res?['hub_ip'] as String?;
      if (ip == null || ip.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目前沒有主機 IP 紀錄，請確認主機 iPad 已開啟 App')),
        );
        return;
      }

      _hubIpController.text = ip;
      await prefs.setString(AppConstants.keyHubIpAddress, ip);

      // 取得 IP 後立即做一次連線測試，更新 banner 狀態
      final client = ref.read(hubClientProvider);
      await client.updateHubIp(ip, (available) {
        if (mounted) {
          ref.read(hubAvailableProvider.notifier).state = available;
        }
      });

      if (mounted) {
        setState(() => _testResult = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已取得主機 IP：$ip')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取得失敗，請確認網路連線')),
      );
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _testHubConnection() async {
    final ip = _hubIpController.text.trim();
    if (ip.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final client = ref.read(hubClientProvider);
    await client.updateHubIp(ip, (available) {
      if (mounted) {
        ref.read(hubAvailableProvider.notifier).state = available;
        setState(() {
          _testResult = available ? '✅ 連線成功' : '❌ 無法連線，請確認 Hub IP 和 Hub App 狀態';
          _isTesting = false;
        });
      }
    });
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double hPadding = isTablet ? (screenWidth - 600) / 2 : 16.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Hub 設定', style: TextStyle(color: colorScheme.onSurface)),
      ),
      body: _isLoading
          ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 24),
              children: [
                // ── Hub 模式區塊 ──────────────────────────────────────
                _sectionHeader(context, 'Hub 裝置設定'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        title: Text(
                          '此裝置為 Hub',
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                        ),
                        subtitle: Text(
                          _isHubDevice
                              ? '正在運行中，請保持 App 在前台'
                              : _isShiftOpen
                                  ? '關閉'
                                  : '請先開班才能開關 Hub',
                          style: TextStyle(
                            color: _isHubDevice
                                ? CupertinoColors.systemGreen
                                : _isShiftOpen
                                    ? colorScheme.onSurfaceVariant
                                    : CupertinoColors.systemOrange,
                            fontSize: 13,
                          ),
                        ),
                        value: _isHubDevice,
                        activeTrackColor: colorScheme.primary,
                        onChanged: _isShiftOpen ? _onHubToggleChanged : null,
                      ),
                      if (_isHubDevice) ...[
                        Divider(height: 1, color: theme.dividerColor, indent: 16, endIndent: 16),
                        ListTile(
                          title: Text(
                            '此裝置 IP',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _deviceIp,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _deviceIp));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('IP 已複製')),
                                  );
                                },
                                child: Icon(CupertinoIcons.doc_on_clipboard,
                                    size: 18, color: colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: theme.dividerColor, indent: 16, endIndent: 16),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.info_circle,
                                  size: 16, color: CupertinoColors.systemOrange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '請將此 iPad 接有線網路並保持 App 在前台，其他裝置輸入此 IP 即可連線',
                                  style: TextStyle(
                                      color: colorScheme.onSurfaceVariant, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (!_isHubDevice) ...[
                const SizedBox(height: 32),

                // ── Client 連線設定區塊 ───────────────────────────────
                _sectionHeader(context, '連接 Hub（此裝置為子機）'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hub IP 位址',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: _hubIpController,
                        placeholder: '例：192.168.1.100',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                        placeholderStyle:
                            TextStyle(color: colorScheme.onSurfaceVariant),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          onPressed: _isFetching ? null : _fetchHubIpFromSupabase,
                          child: _isFetching
                              ? CupertinoActivityIndicator(color: colorScheme.onSurface)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.cloud_download,
                                        size: 16, color: colorScheme.primary),
                                    const SizedBox(width: 6),
                                    Text('從主機自動取得 IP',
                                        style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_testResult != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _testResult!,
                            style: TextStyle(
                              color: _testResult!.startsWith('✅')
                                  ? CupertinoColors.systemGreen
                                  : colorScheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              onPressed: _isTesting ? null : _testHubConnection,
                              child: _isTesting
                                  ? CupertinoActivityIndicator(color: colorScheme.onSurface)
                                  : Text('測試連線',
                                      style: TextStyle(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CupertinoButton(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              onPressed: _saveHubIp,
                              child: Text('儲存',
                                  style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ], // if (!_isHubDevice)
              ],
            ),
    ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hub 衝突封鎖 Dialog（只告知，不提供強制接管）
// ---------------------------------------------------------------------------

class _HubBlockedDialog extends StatelessWidget {
  final String deviceName;
  final String hubIp;

  const _HubBlockedDialog({required this.deviceName, required this.hubIp});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.lock_shield_fill,
                color: CupertinoColors.systemOrange, size: 44),
            const SizedBox(height: 16),
            Text(
              '無法開啟 Hub',
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '「$deviceName」（$hubIp）目前正在執行 Hub 模式。\n\n每間店只能有一台主機，請先前往該裝置將 Hub 關閉，再回來開啟。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('知道了',
                    style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
