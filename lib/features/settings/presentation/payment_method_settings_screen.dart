// lib/features/settings/presentation/payment_method_settings_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// 單個付款方式的資料模型 (保持不變)
class PaymentMethod {
  String name;
  bool isEnabled;
  bool isDefault;

  PaymentMethod({required this.name, this.isEnabled = true, this.isDefault = false});

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      name: json['name'] as String,
      isEnabled: json['enabled'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'enabled': isEnabled,
      'is_default': isDefault,
    };
  }
}

class PaymentMethodSettingsScreen extends StatefulWidget {
  const PaymentMethodSettingsScreen({super.key});

  @override
  State<PaymentMethodSettingsScreen> createState() => _PaymentMethodSettingsScreenState();
}

class _PaymentMethodSettingsScreenState extends State<PaymentMethodSettingsScreen> {
  String? _shopId;
  bool _isLoading = true;
  bool _isSaving = false;

  List<PaymentMethod> _methods = [];
  bool _enableDeposit = true;

  @override
  void initState() {
    super.initState();
    // 延遲載入以確保 AppLocalizations 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }
    
    // 確保只在開始時轉圈一次
    if (!_isLoading) setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client
          .from('shop_payment_settings')
          .select('payment_methods, enable_deposit')
          .eq('shop_id', _shopId!)
          .maybeSingle();

      if (res != null) {
        // 使用安全的檢查來確保 payment_methods 是 List<Map>
        final dynamic paymentMethodsData = res['payment_methods'];
        final List<dynamic> data = 
            (paymentMethodsData is List) ? paymentMethodsData : [];

        _methods = data.whereType<Map<String, dynamic>>()
                       .map((json) => PaymentMethod.fromJson(json))
                       .toList();

        _enableDeposit = res['enable_deposit'] as bool? ?? true;
        
        if (_methods.isEmpty) {
          _addDefaults();
        }

      } else {
        _addDefaults();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.paymentSetupLoadError(e.toString()))),
        );
      }
      _addDefaults();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _addDefaults() {
     setState(() {
      _methods = [
        PaymentMethod(name: 'Credit Card', isDefault: true),
        // PaymentMethod(name: 'LinePay', isDefault: true), // User requested only Credit Card and Cash default
        // PaymentMethod(name: 'Paper Plan', isDefault: true, isEnabled: false),
      ];
    });
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    if (_shopId == null || _isSaving) return;
    setState(() => _isSaving = true);

    final List<Map<String, dynamic>> methodsJson = _methods.map((m) => m.toJson()).toList();

    try {
      await Supabase.instance.client
          .from('shop_payment_settings')
          .upsert({
            'shop_id': _shopId!,
            'payment_methods': methodsJson,
            'enable_deposit': _enableDeposit,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.paymentSetupSaveSuccess)),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.paymentSetupSaveFailure(e.toString()))),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
      final theme = Theme.of(context);
      return InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
          filled: true,
          fillColor: theme.scaffoldBackgroundColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      );
  }
  
  void _showAddMethodDialog() {
    showDialog<PaymentMethod?>(
      context: context,
      builder: (context) {
        return const _AddMethodDialogBody();
      }
    ).then((newMethod) { 
      if (newMethod != null) {
        setState(() {
          _methods.add(newMethod);
        });
      }
    });
  }


  Widget _buildPaymentMethodTile(PaymentMethod method, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), 
          child: Row(
            children: [
              // 左側圖示：鎖頭 (預設) 或 減號 (可刪除)
              SizedBox(
                width: 22,
                child: method.isDefault
                    ? Icon(CupertinoIcons.lock_fill, size: 22, color: colorScheme.onSurface)
                    : CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
                        onPressed: () {
                          setState(() {
                            _methods.remove(method);
                          });
                        },
                      ),
              ),
              const SizedBox(width: 34), 

              // 中間標籤
              Expanded(
                child: Text(
                  method.name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // 右側開關
              CupertinoSwitch(
                value: method.isEnabled,
                onChanged: (value) {
                  setState(() {
                    method.isEnabled = value;
                  });
                },
                activeColor: colorScheme.primary,
                trackColor: Colors.grey.shade700, 
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFunctionModuleTile() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
     return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          // 左側圖示：文件圖示
          SizedBox(
            width: 22,
            child: Icon(CupertinoIcons.doc_text, size: 22, color: colorScheme.onSurface),
          ),
          const SizedBox(width: 34), 

          // 中間標籤
          Expanded(
            child: Text(
              l10n.paymentSetupFunctionDeposit,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 右側開關
          CupertinoSwitch(
            value: _enableDeposit,
            onChanged: (value) {
              setState(() {
                _enableDeposit = value;
              });
            },
            activeColor: colorScheme.primary,
            trackColor: Colors.grey.shade700, 
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
      );
    }
    
    // 列表元件，用於在 Tile 間加入分隔線
    final List<Widget> methodTilesWithSeparators = [];
    for (int i = 0; i < _methods.length; i++) {
      methodTilesWithSeparators.add(_buildPaymentMethodTile(_methods[i], i));
      // 在每個 Tile 後面添加分隔線，除了最後一個
      if (i < _methods.length - 1) {
        methodTilesWithSeparators.add(
          Padding(
            padding: const EdgeInsets.only(left: 72.0, right: 30.0),
            child: Divider(
              color: theme.dividerColor,
              height: 0,
              thickness: 1.0,
            ),
          ),
        );
      }
    }


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
          l10n.paymentSetupTitle, // 'Payment Setup'
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        // [修正] 移除頂部 padding，使用標準邊距
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), 
        children: [
          
          // 1. 啟用付款方式標題
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              l10n.paymentSetupMethodsSection, // 'Enabled Payment Methods'
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 2. 付款方式列表卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0), // 已經有 ListView 的 padding
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor, 
                borderRadius: BorderRadius.circular(25), 
              ),
              child: Column(
                children: [
                  // Tile 列表 (已包含分隔線)
                  ...methodTilesWithSeparators,
                  
                  // 分隔線
                  Padding(
                    padding: const EdgeInsets.only(left: 72.0, right: 30.0),
                    child: Divider(
                      color: theme.dividerColor,
                      height: 0,
                      thickness: 1.0,
                    ),
                  ),
                  
                  // + Add Payment Method 按鈕
                  CupertinoButton(
                    onPressed: _showAddMethodDialog, 
                    padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
                    child: Text(
                      l10n.paymentAddDialogTitle, // '+ Add Payment Method'
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 4. 功能模組標題
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0), 
            child: Text(
              l10n.paymentSetupFunctionModule, // 'Function Module'
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 5. 功能模組列表卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor, 
                borderRadius: BorderRadius.circular(25),
              ),
              child: _buildFunctionModuleTile(),
            ),
          ),
          
          const SizedBox(height: 50), 
          
          Center(
            child: SizedBox(
              width: 161, 
              height: 38, 
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary, 
                  foregroundColor: colorScheme.onPrimary, 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25), 
                  ),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                ),
                child: _isSaving
                    ? CupertinoActivityIndicator(color: colorScheme.onPrimary)
                    : Text(
                        l10n.paymentSetupSaveButton, // 'Save'
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
          
          const SizedBox(height: 50), 
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 內部使用的 Dialog Body 類別 (新增支付方式)
// -------------------------------------------------------------------

class _AddMethodDialogBody extends StatefulWidget {
  const _AddMethodDialogBody();

  @override
  State<_AddMethodDialogBody> createState() => __AddMethodDialogBodyState();
}

class __AddMethodDialogBodyState extends State<_AddMethodDialogBody> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose(); 
    super.dispose();
  }

  // 輔助方法：統一輸入框樣式
  InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
      final theme = Theme.of(context);
      return InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
          filled: true,
          fillColor: theme.scaffoldBackgroundColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25), 
              borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      );
  }
  
  void _saveNewMethod() {
    final l10n = AppLocalizations.of(context)!;
    final name = controller.text.trim();

    if (name.isEmpty) {
      FocusScope.of(context).unfocus();
      return; 
    }

    final newMethod = PaymentMethod(name: name, isDefault: false, isEnabled: true);
    
    Navigator.of(context).pop(newMethod);
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor, 
          borderRadius: BorderRadius.circular(30), 
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Title
            Text(
              l10n.paymentAddDialogTitle, // 'Add Payment Method'
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // 2. Input Field
            TextFormField(
              controller: controller, 
              autofocus: true,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: _buildInputDecoration(hintText: l10n.paymentAddDialogHintName, context: context), 
            ),
            const SizedBox(height: 30),

            // 3. Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(l10n.commonCancel, style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  )), // 'Cancel'
                ),

                // Save Button
                SizedBox(
                  width: 100,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: _saveNewMethod,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(l10n.paymentAddDialogSave, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), // 'Save'
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}