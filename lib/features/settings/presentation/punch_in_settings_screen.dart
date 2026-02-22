// lib/features/settings/presentation/punch_in_settings_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';


class PunchInSettingsScreen extends StatefulWidget {
  const PunchInSettingsScreen({super.key});

  @override
  State<PunchInSettingsScreen> createState() => _PunchInSettingsScreenState();
}

class _PunchInSettingsScreenState extends State<PunchInSettingsScreen> {
  // Current detected info
  String? currentWifiName;
  Position? currentPosition;
  
  // Saved info from DB
  String? savedWifiName;
  double? savedLat;
  double? savedLng;

  String? shopId;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => isLoading = true);
    
    // 檢查權限
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.denied || result == LocationPermission.deniedForever) {
        if (mounted) {
          // 翻譯權限錯誤
          await _showAlert(l10n.punchInErrorPermissionTitle, l10n.punchInErrorPermissionContent); 
          context.pop();
        }
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getString('savedShopId');
    if (shopId != null) {
      // 讀取已儲存的設定
      try {
        final savedData = await Supabase.instance.client
            .from('shop_punch_in_data')
            .select()
            .eq('shop_id', shopId!)
            .maybeSingle();

        if (savedData != null) {
            savedWifiName = savedData['wifi_name'];
            savedLat = savedData['latitude'];
            savedLng = savedData['longitude'];
        }
      } catch (e) {
        debugPrint("Load saved data error: $e");
      }
    }

    try {
      final info = NetworkInfo();
      // On iOS 13+, location permission is required to get Wi-Fi info
      final name = await info.getWifiName();
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation, // 使用最佳精度
        timeLimit: const Duration(seconds: 10), // 設置超時
      );

      setState(() {
        currentWifiName = name;
        currentPosition = position;
      });
    } catch (e) {
      debugPrint("Location/WiFi Error: $e");
      // 保持 currentPosition / wifiName 為 null，由 UI 顯示讀取錯誤
      if (mounted) {
         // 翻譯取得資訊失敗
         _showAlert(l10n.punchInErrorFetchTitle, l10n.punchInErrorFetchContent);
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _savePunchInSettings() async {
    final l10n = AppLocalizations.of(context)!;
    
    if (shopId == null || currentWifiName == null || currentPosition == null) {
      _showAlert(l10n.punchInSaveFailureTitle, l10n.punchInSaveFailureContent);
      return;
    }

    setState(() => isLoading = true);

    // 檢查是否已有該 shop_id 的紀錄 (for overwrite prompt logic)
    // 雖然前面已經讀取過了，但再確認一次比較保險，或者直接用 savedWifiName != null 判斷
    if (savedWifiName != null) {
      setState(() => isLoading = false);

      // 顯示覆蓋確認對話框 (使用多語言)
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.punchInConfirmOverwriteTitle), // '確認覆蓋'
          content: Text(l10n.punchInConfirmOverwriteContent), // '此商店已存在打卡資訊...'
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: Text(l10n.commonCancel), // '取消'
            ),
            TextButton(
              onPressed: () => context.pop(true),
              child: Text(l10n.commonOverwrite), // '覆蓋'
            ),
          ],
        ),
      );

      if (confirm != true) return;
      setState(() => isLoading = true);
    }

    // 使用 upsert (如果已存在會覆蓋，否則新增)
    final error = await Supabase.instance.client
        .from('shop_punch_in_data')
        .upsert({
          'shop_id': shopId,
          'wifi_name': currentWifiName,
          'latitude': currentPosition!.latitude,
          'longitude': currentPosition!.longitude,
        })
        .then((_) => null) // 成功則返回 null
        .catchError((e) => e); // 失敗則返回錯誤對象

    if (error != null) {
      _showAlert(l10n.punchInSaveFailureTitle, error.toString()); // 儲存失敗
    } else {
      // Update Saved UI
      setState(() {
        savedWifiName = currentWifiName;
        savedLat = currentPosition!.latitude;
        savedLng = currentPosition!.longitude;
      });
      _showAlert(l10n.punchInSaveSuccessTitle, l10n.punchInSaveSuccessContent); // 儲存成功
    }
    
    setState(() => isLoading = false);
  }


  Future<void> _showAlert(String title, String content) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => context.pop(), child: Text(l10n.commonOK)), // 'OK'
        ],
      ),
    );
  }

  // 輔助方法：建構深色圓角資訊卡片
  Widget _buildInfoCard(IconData icon, String title, String value, {bool isSaved = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      // Figma 寬度: 361px, 左右 padding: 16px
      margin: const EdgeInsets.only(top: 8.0, bottom: 8.0), 
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isSaved ? theme.cardColor.withOpacity(0.5) : theme.cardColor, 
        borderRadius: BorderRadius.circular(25), // 圓角 25px
        border: isSaved ? Border.all(color: colorScheme.outline.withOpacity(0.2)) : null,
      ),
      child: Row(
        children: [
          // 圖示
          Icon(
            icon,
            color: colorScheme.onSurface.withOpacity(isSaved ? 0.7 : 1.0), 
            size: 22,
          ),
          const SizedBox(width: 18), // 圖示和文字間距
          
          // 數值
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(isSaved ? 0.7 : 1.0), 
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          ),
        ],
      ),
    );
  }

  // 輔助方法：建構白色圓角按鈕
  Widget _buildActionButton(String text, VoidCallback onPressed) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Figma 寬度: 237.62px, 高度: 38px
    const double buttonWidth = 245.0; 
    const double buttonHeight = 38.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0), // 按鈕之間的間距
      width: buttonWidth,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary, // 使用的主題色
          foregroundColor: colorScheme.onPrimary, // 使用的主題對比色
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25), // 圓角 25px
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, 
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.punchInSetupTitle, // 'Clock-in Info'
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 已儲存的資訊區域
                Text("Saved Configuration", style: TextStyle(color: colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildInfoCard(
                  CupertinoIcons.wifi,
                  l10n.punchInWifiSection,
                  savedWifiName ?? "Not Set",
                  isSaved: true,
                ),
                _buildInfoCard(
                  CupertinoIcons.map_pin,
                  l10n.punchInLocationSection,
                  savedLat != null ? 'Lat: ${savedLat!.toStringAsFixed(6)}\nLng: ${savedLng!.toStringAsFixed(6)}' : "Not Set",
                  isSaved: true,
                ),

                const SizedBox(height: 20),
                Divider(color: Colors.grey.withOpacity(0.3)),
                const SizedBox(height: 20),

                // 2. 目前偵測資訊區域
                Text("Current Detection", style: TextStyle(color: colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildInfoCard(
                  CupertinoIcons.wifi,
                  l10n.punchInWifiSection,
                  currentWifiName ?? l10n.punchInLoading 
                ),
                _buildInfoCard(
                  CupertinoIcons.map_pin,
                  l10n.punchInLocationSection,
                  currentPosition != null
                      ? 'Lat: ${currentPosition!.latitude.toStringAsFixed(6)}\nLng: ${currentPosition!.longitude.toStringAsFixed(6)}'
                      : l10n.punchInLoading, 
                ),

                const SizedBox(height: 40),
                
                // 3. 按鈕區塊
                Center(
                  child: Column(
                    children: [
                      // Regain Wi-Fi & Location
                      _buildActionButton(l10n.punchInRegainButton, _loadInitialData),
                      // Save Clock-in Info
                      _buildActionButton(l10n.punchInSaveButton, _savePunchInSettings),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // --- 載入指示器 (覆蓋在最上層) ---
          if (isLoading)
            Container(
              color: theme.scaffoldBackgroundColor.withOpacity(0.7),
              child: Center(
                child: CupertinoActivityIndicator(radius: 15, color: colorScheme.onSurface),
              ),
            ),
        ],
      ),
    );
  }
}