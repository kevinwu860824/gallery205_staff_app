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
      setState(() {
        taxProfile = profile;
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

  Future<void> _saveSettings(double newRate, bool newInclude) async {
    if (taxProfile == null) return;
    
    setState(() => isLoading = true);
    try {
      final newProfile = taxProfile!.copyWith(
        rate: newRate,
        isTaxIncluded: newInclude,
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
                        groupValue: taxProfile?.rate,
                        onChanged: (val) => _saveSettings(val!, taxProfile?.isTaxIncluded ?? true),
                      ),
                      const Divider(height: 1),
                      RadioListTile<double>(
                        title: const Text("核定課稅 (1%)"),
                        value: 1.0,
                        groupValue: taxProfile?.rate,
                        onChanged: (val) => _saveSettings(val!, taxProfile?.isTaxIncluded ?? true),
                      ),
                      const Divider(height: 1),
                      RadioListTile<double>(
                        title: const Text("統一發票 (5%)"),
                        value: 5.0,
                        groupValue: taxProfile?.rate,
                        onChanged: (val) => _saveSettings(val!, taxProfile?.isTaxIncluded ?? true),
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
                         value: taxProfile?.isTaxIncluded ?? true,
                         onChanged: (val) => _saveSettings(taxProfile?.rate ?? 0, val),
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
