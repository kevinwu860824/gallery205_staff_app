// lib/core/services/site_verification_service.dart

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SiteVerificationResult {
  final bool isVerified;
  final String? errorMessage;

  SiteVerificationResult({required this.isVerified, this.errorMessage});
}

class SiteVerificationService {
  static final SiteVerificationService _instance = SiteVerificationService._internal();
  factory SiteVerificationService() => _instance;
  SiteVerificationService._internal();

  /// 驗證員工是否在店內 Wi-Fi 或 GPS 範圍內
  Future<SiteVerificationResult> verifySite(String shopId) async {
    try {
      final supabase = Supabase.instance.client;
      
      // 1. 取得店家設定
      final shopData = await supabase
          .from('shop_punch_in_data')
          .select()
          .eq('shop_id', shopId)
          .maybeSingle();

      if (shopData == null) {
        return SiteVerificationResult(
          isVerified: false, 
          errorMessage: '找不到店家場域設定資訊，請聯繫管理員。'
        );
      }

      final String? requiredWifi = shopData['wifi_name'] as String?;
      final double? shopLat = shopData['latitude'] as double?;
      final double? shopLng = shopData['longitude'] as double?;
      const double radius = 150.0; // 點餐驗證範圍可稍微放寬（比打卡 100m 寬一點點）

      // 2. 優先檢查 Wi-Fi (如果有設定)
      final info = NetworkInfo();
      String? currentWifi = await info.getWifiName();
      
      // 去除引號 (部分手機回傳的 SSID 會帶雙引號)
      if (currentWifi != null && currentWifi.startsWith('"') && currentWifi.endsWith('"')) {
        currentWifi = currentWifi.substring(1, currentWifi.length - 1);
      }

      if (requiredWifi != null && requiredWifi.isNotEmpty) {
        if (currentWifi == requiredWifi) {
          return SiteVerificationResult(isVerified: true);
        }
      }

      // 3. 檢查 GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return SiteVerificationResult(
          isVerified: false, 
          errorMessage: '請開啟定位服務以驗證工作場域。'
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return SiteVerificationResult(
            isVerified: false, 
            errorMessage: '定位權限被拒絕，無法驗證場域。'
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return SiteVerificationResult(
          isVerified: false, 
          errorMessage: '定位權限已被永久封鎖，請至設定中開啟。'
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (shopLat != null && shopLng != null) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          shopLat,
          shopLng,
        );

        if (distance < radius) {
          return SiteVerificationResult(isVerified: true);
        } else {
          String msg = '您目前不在店內範圍內（距離約 ${distance.toStringAsFixed(0)} 公尺）。';
          if (requiredWifi != null && requiredWifi.isNotEmpty) {
            msg += '\n請嘗試連結店內 Wi-Fi: $requiredWifi';
          }
          return SiteVerificationResult(isVerified: false, errorMessage: msg);
        }
      }

      // 若都沒設定 GPS 且 Wi-Fi 也沒對上
      return SiteVerificationResult(
        isVerified: false, 
        errorMessage: '無法驗證店內環境，請連結正確 Wi-Fi。'
      );

    } catch (e) {
      debugPrint('Site Verification Error: $e');
      return SiteVerificationResult(
        isVerified: false, 
        errorMessage: '場域驗證發生錯誤: $e'
      );
    }
  }
}
