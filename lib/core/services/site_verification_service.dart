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

  /// 驗證員工是否同時在店內 Wi-Fi 且在 GPS 範圍內（兩者皆須符合）
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
      const double radius = 150.0;

      // 2. 檢查 Wi-Fi（若有設定則必須符合）
      bool wifiPassed = true;
      String? wifiError;
      if (requiredWifi != null && requiredWifi.isNotEmpty) {
        final info = NetworkInfo();
        String? currentWifi = await info.getWifiName();
        // 去除引號 (部分手機回傳的 SSID 會帶雙引號)
        if (currentWifi != null && currentWifi.startsWith('"') && currentWifi.endsWith('"')) {
          currentWifi = currentWifi.substring(1, currentWifi.length - 1);
        }
        if (currentWifi != requiredWifi) {
          wifiPassed = false;
          wifiError = 'Wi-Fi 未連結到店內網路（需連結：$requiredWifi）';
        }
      }

      // 3. 檢查 GPS（若有設定則必須符合）
      bool gpsPassed = true;
      String? gpsError;
      if (shopLat != null && shopLng != null) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          gpsPassed = false;
          gpsError = '請開啟定位服務以驗證工作場域';
        } else {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.denied) {
            gpsPassed = false;
            gpsError = '定位權限被拒絕，無法驗證場域';
          } else if (permission == LocationPermission.deniedForever) {
            gpsPassed = false;
            gpsError = '定位權限已被永久封鎖，請至設定中開啟';
          } else {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            final distance = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              shopLat,
              shopLng,
            );
            if (distance >= radius) {
              gpsPassed = false;
              gpsError = '您目前不在店內範圍內（距離約 ${distance.toStringAsFixed(0)} 公尺）';
            }
          }
        }
      }

      // 4. 兩者皆須通過
      if (wifiPassed && gpsPassed) {
        return SiteVerificationResult(isVerified: true);
      }

      final errors = [
        if (!wifiPassed && wifiError != null) wifiError,
        if (!gpsPassed && gpsError != null) gpsError,
      ];
      return SiteVerificationResult(
        isVerified: false,
        errorMessage: errors.join('\n'),
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
