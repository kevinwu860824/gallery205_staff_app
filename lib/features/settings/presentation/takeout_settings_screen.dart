import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TakeoutSettingsScreen extends ConsumerStatefulWidget {
  const TakeoutSettingsScreen({super.key});

  @override
  ConsumerState<TakeoutSettingsScreen> createState() => _TakeoutSettingsScreenState();
}

class _TakeoutSettingsScreenState extends ConsumerState<TakeoutSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  bool _isTakeoutEnabled = false;
  bool _isTakeoutInfoRequired = false;
  String _takeoutPaymentMode = 'postpay'; // NEW: 'prepay' or 'postpay'

  String? _shopId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _shopId = prefs.getString('savedShopId');
      
      if (_shopId == null) {
        final user = ref.read(authStateProvider).value;
        _shopId = user?.shopId;
      }

      debugPrint("TakeoutSettings: Loading for shopId: $_shopId");

      if (_shopId != null) {
        final res = await Supabase.instance.client
            .from('shops')
            .select('is_takeout_enabled, is_takeout_info_required, takeout_payment_mode')
            .eq('id', _shopId!)
            .maybeSingle();

        debugPrint("TakeoutSettings: Load result: $res");
        if (res != null && mounted) {
          setState(() {
            _isTakeoutEnabled = res['is_takeout_enabled'] ?? false;
            _isTakeoutInfoRequired = res['is_takeout_info_required'] ?? false;
            _takeoutPaymentMode = res['takeout_payment_mode'] ?? 'postpay';
          });
        }
      } else {
        debugPrint("TakeoutSettings: No shopId found");
      }
    } catch (e) {
      debugPrint("TakeoutSettings: Load error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_shopId == null) {
      debugPrint("Cannot save: _shopId is null");
      return;
    }
    setState(() => _isSaving = true);
    debugPrint("Saving settings: enabled=$_isTakeoutEnabled, info=$_isTakeoutInfoRequired, mode=$_takeoutPaymentMode");
    try {
      await Supabase.instance.client.from('shops').update({
        'is_takeout_enabled': _isTakeoutEnabled,
        'is_takeout_info_required': _isTakeoutInfoRequired,
        'takeout_payment_mode': _takeoutPaymentMode,
      }).eq('id', _shopId!);

      debugPrint("Save settings success");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('外帶設定已儲存'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugPrint("Save takeout settings error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '外帶功能設定',
          style: AppTextStyles.settingsPageTitle.copyWith(
            fontSize: 20,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: CupertinoActivityIndicator(),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: Text('儲存', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '開啟外帶功能後，地圖畫面右上方將會出現外帶按鈕，允許員工建立未綁定桌位的外帶訂單。這項設定套用於整間分店。',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: Text('開啟外帶功能', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                        subtitle: Text('啟用此分店的外帶點餐流程', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
                        value: _isTakeoutEnabled,
                        activeColor: colorScheme.primary,
                        onChanged: (val) {
                          setState(() {
                            _isTakeoutEnabled = val;
                            if (!val) {
                              // 若關閉外帶功能，連同強制輸入的開關也預設關閉
                              _isTakeoutInfoRequired = false;
                            }
                          });
                          _saveSettings();
                        },
                      ),
                      if (_isTakeoutEnabled) ...[
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text('強制輸入顧客資訊', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                          subtitle: Text('點選外帶時，必須輸入顧客稱呼或電話才能繼續', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
                          value: _isTakeoutInfoRequired,
                          activeColor: colorScheme.primary,
                          onChanged: (val) {
                            setState(() => _isTakeoutInfoRequired = val);
                            _saveSettings();
                          },
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('預設外帶支付模式', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: CupertinoSlidingSegmentedControl<String>(
                                  groupValue: _takeoutPaymentMode,
                                  children: {
                                    'prepay': Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text('先結 (Pre-payment)', style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
                                    ),
                                    'postpay': Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text('後結 (Post-payment)', style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
                                    ),
                                  },
                                  onValueChanged: (val) {
                                    if (val != null) {
                                      setState(() => _takeoutPaymentMode = val);
                                      _saveSettings();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _takeoutPaymentMode == 'prepay' ? '送單成功後，系統將自動導向結帳畫面。' : '送單成功後，訂單將保留於系統中，待稍後結帳。',
                                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
