import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/ordering/data/repositories/ordering_repository_impl.dart';
import 'package:gallery205_staff_app/features/ordering/data/datasources/ordering_remote_data_source.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/ordering_repository.dart';
import 'package:gallery205_staff_app/core/models/tax_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  bool isLoading = true;
  TaxProfile? taxProfile;
  late OrderingRepository _repository;
  
  // Local state for the selected values before saving
  double _selectedRate = 0.0;
  bool _selectedIsIncluded = true;
  String? shopId;

  @override
  void initState() {
    super.initState();
    _initRepository();
    _loadSettings();
  }

  Future<void> _initRepository() async {
    final client = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final dataSource = OrderingRemoteDataSourceImpl(client);
    _repository = OrderingRepositoryImpl(dataSource, prefs);
  }

  Future<void> _loadSettings() async {
    setState(() => isLoading = true);
    // Wait for repo init if needed, usually fast enough or await in initState not ideal.
    // Better pattern: ensure initialized.
    await Future.delayed(Duration.zero); 
    
    try {
      final profile = await _repository.getTaxProfile();
      final prefs = await SharedPreferences.getInstance();
      shopId = prefs.getString('savedShopId');
      
      setState(() {
        taxProfile = profile;
        _selectedRate = profile.rate;
        _selectedIsIncluded = profile.isTaxIncluded;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading tax settings: $e");
      if (mounted) {
         setState(() => isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("載入失敗: $e")));
      }
    }
  }

  Future<void> _saveSettings() async {
    if (taxProfile == null) return;
    
    // Verifying ezPay configuration if selecting 5% Tax
    if (_selectedRate == 5.0 && shopId != null) {
      setState(() => isLoading = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? token = prefs.getString('supabase_session_token') ?? Supabase.instance.client.auth.currentSession?.accessToken;
        
        // Use the existing Next.js admin web API which securely tests the AES encryption
        // Requires knowing the backend URL, assuming standard dev/prod setup for mobile app
        // We will hit the admin web URL, typically defined in env or a constant. 
        // For standard local dev / prod, we'll try a generic fetch via a helper if it exists,
        // or just construct it.
        // ACTUALLY, the staff app might not know the admin web URL directly.
        // A better fallback since Edge Function failed is to put the validation logic in a 
        // Supabase RPC (database function) that just checks if the row exists and is not null.
        
        final client = Supabase.instance.client;
        final res = await client
            .from('shop_ezpay_settings')
            .select('merchant_id, hash_key, hash_iv')
            .eq('shop_id', shopId!)
            .maybeSingle();

        if (res == null || res['merchant_id'] == null || res['hash_key'] == null || res['hash_iv'] == null) {
          throw "無法連線至電子發票服務，請至網頁版管理後台完成 ezPay 金鑰設定後再試。";
        }
        
      } catch (e) {
        if (mounted) setState(() => isLoading = false);
        _showErrorDialog(e.toString());
        return; // Block saving
      }
    }
    
    setState(() => isLoading = true);
    try {
      final newProfile = taxProfile!.copyWith(
        rate: _selectedRate,
        isTaxIncluded: _selectedIsIncluded,
      );
      
      await _repository.saveTaxProfile(newProfile);
      
      setState(() {
        taxProfile = newProfile;
      });
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已儲存設定")));
      
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("儲存失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showErrorDialog(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("設定失敗", style: TextStyle(color: Colors.red)),
        content: Text(msg.replaceAll("Exception: ", "").replaceAll("EdgeFunctionException: ", "")),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(ctx),
             child: const Text("我知道了")
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("稅務設定"),
        backgroundColor: theme.cardColor,
      ),
      body: isLoading 
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle("稅率設定"),
                
                // Rate Selection
                Card(
                  elevation: 0,
                  color: theme.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      RadioListTile<double>(
                        title: const Text("免稅 (0%)"),
                        value: 0.0,
                        groupValue: _selectedRate,
                        onChanged: (val) => setState(() => _selectedRate = val!),
                      ),
                      const Divider(height: 1),
                      RadioListTile<double>(
                        title: const Text("核定課稅 (1%)"),
                        value: 1.0,
                        groupValue: _selectedRate,
                        onChanged: (val) => setState(() => _selectedRate = val!),
                      ),
                      const Divider(height: 1),
                      RadioListTile<double>(
                        title: const Text("統一發票 (5%)"),
                        value: 5.0,
                        groupValue: _selectedRate,
                        onChanged: (val) => setState(() => _selectedRate = val!),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                _buildSectionTitle("計算方式"),
                
                Card(
                  elevation: 0,
                  color: theme.cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                       SwitchListTile.adaptive(
                         title: const Text("稅額內含"),
                         subtitle: const Text("商品價格已包含稅金"),
                         value: _selectedIsIncluded,
                         onChanged: (val) => setState(() => _selectedIsIncluded = val),
                       ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "說明：\n• 內含：商品 \$100，稅率 5%，則 銷售額 \$95 + 稅 \$5。\n• 外加：商品 \$100，稅率 5%，則 總金額 \$105 (銷售額 \$100 + 稅 \$5)。",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saveSettings,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text("儲存設定", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title, style: TextStyle(
        fontSize: 14, 
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary
      )),
    );
  }
}
