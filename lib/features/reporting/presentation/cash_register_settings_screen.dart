// lib/features/reporting/presentation/cash_register_settings_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart'; // [新增] 引入多語言

// -------------------------------------------------------------------
// 新增的 Stateful Widget 類別：處理每個面額輸入欄位的互動邏輯
// -------------------------------------------------------------------

class _DenominationInputRow extends StatefulWidget {
  final int value;
  final TextEditingController controller;
  final NumberFormat currencyFormat;

  const _DenominationInputRow({
    required this.value,
    required this.controller,
    required this.currencyFormat,
    super.key,
  });

  @override
  State<_DenominationInputRow> createState() => _DenominationInputRowState();
}

class _DenominationInputRowState extends State<_DenominationInputRow> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    // 1. 處理數值自動清零的邏輯 (僅在獲得焦點時執行)
    if (_focusNode.hasFocus) {
      // 如果欄位內容為 '0'
      if (widget.controller.text == '0') {
        // 自動清空輸入框
        widget.controller.text = '';
        // 將游標移到最前面
        widget.controller.selection = TextSelection.fromPosition(
          const TextPosition(offset: 0),
        );
      }
    }
    
    // 2. 處理 UI 視覺更新 (隱藏/顯示面額文字)
    if (mounted) {
      setState(() {}); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final theme = Theme.of(context);
    final totalValue = widget.value * (int.tryParse(widget.controller.text) ?? 0);
    
    // ... (build 方法內部的 UI 結構保持不變) ...
    
    const double inputWidth = 208.0; 
    const double inputHeight = 38.0;
    // 靜態文字寬度保持 56.0
    const double staticTextWidth = 56.0; 

    return Padding(
      padding: const EdgeInsets.only(bottom: 13.0),
      
      // ✅ 關鍵修改：用 Center 包裹 Row，強迫 Row 置中
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 左側：靜態面額文字 (寬度 56.0)
            Container(
              width: staticTextWidth, 
              alignment: Alignment.centerRight,
              child: Text(
                widget.value.toString(),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(width: 8), 

            // 2. 右側：圓角輸入框區域 (寬度 216.0)
            Container(
              width: inputWidth, // 這裡使用了 216.0
              height: inputHeight,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Stack(
                children: [
                  // 輸入框 
                  Padding(
                    padding: const EdgeInsets.only(left: 17.0, right: 100.0), 
                    child: TextFormField(
                      controller: widget.controller,
                      focusNode: _focusNode, 
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.left, // 保持靠左對齊
                      style: TextStyle(
                        color: theme.colorScheme.onSurface, 
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(top: 10, bottom: 5), 
                        hintText: l10n.cashRegSetupInputHint, // '0'
                        hintStyle: TextStyle(color: theme.hintColor),
                      ),
                    ),
                  ),

                  // 總金額計算結果
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 17.0),
                      child: Text(
                        // 🎯 替換：'= \$${widget.currencyFormat.format(totalValue)}'
                        '= \$${widget.currencyFormat.format(totalValue)}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 主螢幕類別
// -------------------------------------------------------------------

class CashRegisterSettingsScreen extends StatefulWidget {
  const CashRegisterSettingsScreen({super.key});

  @override
  State<CashRegisterSettingsScreen> createState() => _CashRegisterSettingsScreenState();
}

class _CashRegisterSettingsScreenState extends State<CashRegisterSettingsScreen> {
  String? _shopId;
  bool _isLoading = true;
  
  final Map<int, TextEditingController> _cashCounts = {
    2000: TextEditingController(), 1000: TextEditingController(), 500: TextEditingController(), 
    200: TextEditingController(), 100: TextEditingController(), 50: TextEditingController(), 
    10: TextEditingController(), 5: TextEditingController(), 1: TextEditingController()
  };
  
  double _totalFloatAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _cashCounts.forEach((key, controller) {
      controller.addListener(_calculateTotal);
    });
  }

  @override
  void dispose() {
    _cashCounts.forEach((key, controller) {
      controller.removeListener(_calculateTotal);
      controller.dispose();
    });
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // 🎯 修正：移除頂部的 l10n 實例化
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');

    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('cash_register_settings')
          .select('*')
          .eq('shop_id', _shopId!)
          .maybeSingle(); 

      if (res != null) {
        setState(() {
          _cashCounts[2000]?.text = (res['cash_2000'] ?? 0).toString();
          _cashCounts[1000]?.text = (res['cash_1000'] ?? 0).toString();
          _cashCounts[500]?.text = (res['cash_500'] ?? 0).toString();
          _cashCounts[200]?.text = (res['cash_200'] ?? 0).toString();
          _cashCounts[100]?.text = (res['cash_100'] ?? 0).toString();
          _cashCounts[50]?.text = (res['cash_50'] ?? 0).toString();
          _cashCounts[10]?.text = (res['cash_10'] ?? 0).toString();
          _cashCounts[5]?.text = (res['cash_5'] ?? 0).toString();
          _cashCounts[1]?.text = (res['cash_1'] ?? 0).toString();
          _calculateTotal();
        });
      }
    } catch (e) {
      debugPrint("Load Settings Error: $e");
      _cashCounts.forEach((_, c) => c.text = '0');
      
      // 🎯 修正點 1: 錯誤提示 (在 catch 內部實例化 l10n)
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cashRegNoticeLoadError(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateTotal() {
    double total = 0.0;
    _cashCounts.forEach((value, controller) {
      final count = int.tryParse(controller.text) ?? 0;
      total += value * count;
    });
    setState(() {
      _totalFloatAmount = total;
    });
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!; // [新增]
    FocusScope.of(context).unfocus(); 
    
    final data = {
      'shop_id': _shopId,
      'cash_2000': int.tryParse(_cashCounts[2000]!.text) ?? 0,
      'cash_1000': int.tryParse(_cashCounts[1000]!.text) ?? 0,
      'cash_500': int.tryParse(_cashCounts[500]!.text) ?? 0,
      'cash_200': int.tryParse(_cashCounts[200]!.text) ?? 0,
      'cash_100': int.tryParse(_cashCounts[100]!.text) ?? 0,
      'cash_50': int.tryParse(_cashCounts[50]!.text) ?? 0,
      'cash_10': int.tryParse(_cashCounts[10]!.text) ?? 0,
      'cash_5': int.tryParse(_cashCounts[5]!.text) ?? 0,
      'cash_1': int.tryParse(_cashCounts[1]!.text) ?? 0,
    };
    
    try {
      await Supabase.instance.client
          .from('cash_register_settings')
          .upsert(data); 

      if (mounted) {
        // 🎯 替換：錢櫃零用金設定已儲存！
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cashRegNoticeSaveSuccess)),
        );
        context.pop(); 
      }
    } catch (e) {
      if (mounted) {
        // 🎯 替換：儲存失敗: ${e.toString()}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cashRegNoticeSaveFailure(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor, 
        body: Center(child: CupertinoActivityIndicator(color: theme.colorScheme.onSurface)),
      );
    }

    // 確定本地化貨幣格式
    final currencyFormat = NumberFormat('#,###', Localizations.localeOf(context).toString()); 
    // Figma 寬度: 393px, Group 25 寬度: 281px. 左右 padding: (393 - 281) / 2 = 56px
    const double horizontalPadding = 56.0;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, 
      resizeToAvoidBottomInset: false, 
      
      // --- [修改 1] 點擊空白處收起鍵盤 ---
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        // 我們將整個內容放在 Stack 內，以便定位返回按鈕
        child: Stack( 
          children: [
            // --- A. 捲動內容區 (原本的 SafeArea) ---
            SafeArea(
              child: SingleChildScrollView(
                // 使用 AnimatedPadding 處理鍵盤彈出動畫
                child: AnimatedPadding(
                  padding: EdgeInsets.only(
                    // 左右 padding 匹配 Figma 設計
                    left: horizontalPadding,
                    right: horizontalPadding,
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  
                  child: Column(
                    children: [
                      // --- 標題區塊 ---
                      const SizedBox(height: 50), 
                      Text(
                        l10n.cashRegSetupTitle, // 'Cashbox Setup'
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.03,
                        ),
                      ),
                      // ... (省略所有列表和按鈕內容，直到底部) ...

                      // Figma 描述 (Top 149)
                      const SizedBox(height: 5), 
                      Text(
                        l10n.cashRegSetupSubtitle, // 'Please enter the default quantity of...'
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.03,
                          height: 1.2,
                        ),
                      ),
                      
                      // 標題到底部第一個欄位的間距 (Figma: Top 196)
                      const SizedBox(height: 38), 

                      // --- 面額輸入列表 (使用新的 _DenominationInputRow) ---
                      ..._cashCounts.keys.map((value) => _DenominationInputRow(
                        key: ValueKey(value), // 必須有 key
                        value: value,
                        controller: _cashCounts[value]!,
                        currencyFormat: currencyFormat,
                      )),

                      const SizedBox(height: 25), 
                      
                      // --- Total 總金額顯示 ---
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          // 🎯 替換：Total: \$${currencyFormat.format(_totalFloatAmount)}
                          l10n.cashRegSetupTotalLabel(
                            '\$${currencyFormat.format(_totalFloatAmount)}'
                          ),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32), // Total 到按鈕間距 (Figma: Top 687)
                      
                      // --- 儲存按鈕 ---
                      SizedBox(
                        width: 161, // Figma 寬度
                        height: 38, // Figma 高度
                        child: ElevatedButton(
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary, // 主題色
                            foregroundColor: theme.colorScheme.onPrimary, // 對比色
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25), // 圓角 10
                            ),
                            padding: EdgeInsets.zero,
                            elevation: 0,
                          ),
                          child: Text(
                            l10n.commonSave, // 'Save'
                            style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 50), // 底部空間
                    ],
                  ),
                ),
              ),
            ),
            
            // --- B. 返回按鈕 (定位在左上角) ---
            Positioned(
              top: MediaQuery.of(context).padding.top + 10, // 考慮狀態列的高度 + 10px 空間
              left: 10,
              child: IconButton(
                icon: const Icon(CupertinoIcons.chevron_left), // 使用 iOS 風格的返回箭頭
                color: theme.colorScheme.onSurface, // 箭頭顏色跟隨主題
                iconSize: 30,
                onPressed: () => context.pop(), // 點擊時回到上一頁
              ),
            ),
          ],
        ),
      ),
    );
  }
}