// lib/features/inventory/presentation/inventory_log_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // ✅ 修正1：正確匯入 material.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// 輔助方法：統一輸入框樣式
InputDecoration _buildInputDecoration({required String hintText, Widget? prefixIcon, required BuildContext context}) {
    final theme = Theme.of(context);
    return InputDecoration(
        prefixIcon: prefixIcon,
        hintText: hintText,
        hintStyle: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25), // 高度圓角
            borderSide: BorderSide.none,
        ),
        // 調整垂直 padding 以匹配 Figma 的 38px 高度
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9), 
    );
}

// -------------------------------------------------------------------
// 1. 庫存日誌主頁面 (InventoryLogScreen)
// -------------------------------------------------------------------

class InventoryLogScreen extends StatefulWidget {
  const InventoryLogScreen({super.key});

  @override
  State<InventoryLogScreen> createState() => _InventoryLogScreenState();
}

class _InventoryLogScreenState extends State<InventoryLogScreen> {
  String? _shopId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = []; // 儲存從 DB 來的原始資料
  List<Map<String, dynamic>> _filteredLogs = []; // 用於 UI 顯示的資料
  
  // 篩選狀態
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _selectedReason = 'all'; 
  // [修正] Reason Options 保持 Key 值，但在 Dropdown 顯示翻譯
  final List<String> _reasonOptions = ['all', 'Add', 'Inventory Adjustment', 'Waste']; 
  bool _showAllDates = true; // Figma 上的核取方塊

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _searchController.addListener(_filterLogs);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterLogs);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');

    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    await _loadLogs();
    setState(() => _isLoading = false);
  }

  // ✅ 輔助方法：將原因 Key 翻譯成顯示文字
  String _translateReasonKey(String key, AppLocalizations l10n) {
    return switch (key) {
      'all' => l10n.inventoryLogReasonAll,
      'Add' => l10n.inventoryLogReasonAdd,
      'Inventory Adjustment' => l10n.inventoryLogReasonAdjustment,
      'Waste' => l10n.inventoryLogReasonWaste,
      _ => key,
    };
  }


  // ✅ 修正2：調整 Supabase 查詢順序
  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    
    // 建立查詢
    var query = Supabase.instance.client
        .from('inventory_logs_view') 
        .select('*')
        .eq('shop_id', _shopId!); // 篩選 1: shop_id
        
    // 篩選 2: 原因
    if (_selectedReason != 'all') {
      query = query.eq('reason', _selectedReason);
    }
    
    // 篩選 3: 日期 (範圍查詢必須在 eq 之後)
    if (!_showAllDates) {
      // 確保使用 UTC 比較
      final startOfDay = _selectedDate.toUtc().toIso8601String();
      final endOfDay = _selectedDate.add(const Duration(days: 1)).toUtc().toIso8601String();
      query = query
          .gte('created_at', startOfDay) 
          .lt('created_at', endOfDay);
    }

    // 最後才排序
    final res = await query.order('created_at', ascending: false);

    setState(() {
      _logs = List<Map<String, dynamic>>.from(res);
      _filterLogs(); // 載入後立即執行一次本地搜尋篩選
      _isLoading = false;
    });
  }
  
  // 本地篩選 (僅搜尋名稱)
  void _filterLogs() {
    final searchItemName = _searchController.text.toLowerCase();
    
    if (searchItemName.isEmpty) {
      setState(() => _filteredLogs = _logs);
      return;
    }
    
    final filtered = _logs.where((log) {
      final itemName = (log['item_name'] as String? ?? '').toLowerCase();
      return itemName.contains(searchItemName);
    }).toList();
    
    setState(() => _filteredLogs = filtered);
  }
  
  void _showDatePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    showCupertinoModalPopup(
      context: context,
      builder: (_) => SizedBox(
        height: 320,
        child: CupertinoPopupSurface(
child: Container(
            color: theme.scaffoldBackgroundColor,
            child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _selectedDate,
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (DateTime newDate) {
                      _selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
                    },
                  ),
                ),
                CupertinoButton(
                  child: Text(l10n.inventoryLogDatePickerConfirm, style: TextStyle(color: theme.colorScheme.primary)), 
                  onPressed: () async {
                    context.pop();
                    setState(() {}); // 更新日期顯示
                    await _loadLogs(); // 重新載入數據
                  },
                )
              ],
            ),
          ),
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
          l10n.inventoryLogTitle,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 0, left: 16, right: 16, bottom: 20),
        children: [
          // 篩選工具區
          
          // 1. 日期 & 原因篩選
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 日期選擇
              Row(
                children: [
                  Theme(
                    data: ThemeData(
                      unselectedWidgetColor: colorScheme.onSurface,
                      checkboxTheme: CheckboxThemeData(
                        fillColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) {
                            return colorScheme.primary;
                          }
                          return null;
                        }),
                        checkColor: MaterialStateProperty.all(colorScheme.onPrimary),
                      )
                    ),
                    child: Checkbox(
                      value: _showAllDates,
                      activeColor: colorScheme.primary,
                      checkColor: colorScheme.onPrimary,
                      onChanged: (value) async {
                        setState(() => _showAllDates = value ?? false);
                        await _loadLogs();
                      },
                    ),
                  ),
                  // 日期按鈕
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showAllDates ? null : () => _showDatePicker(context),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.calendar, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _showAllDates ? l10n.inventoryLogAllDates : DateFormat('yyyy/MM/dd').format(_selectedDate), 
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // 原因篩選 (Dropdown)
              DropdownButton<String>(
                value: _selectedReason,
                dropdownColor: theme.cardColor,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                underline: Container(),
                icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurface), 
                onChanged: (value) async {
                  if (value != null) {
                    setState(() => _selectedReason = value);
                    await _loadLogs(); 
                  }
                },
                items: _reasonOptions.map((r) => DropdownMenuItem(
                  value: r, 
                  child: Text(_translateReasonKey(r, l10n)) // 顯示翻譯後的文字
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 2. 名稱搜尋
          TextFormField(
            controller: _searchController,
            decoration: _buildInputDecoration(
              hintText: l10n.inventoryLogSearchHint, 
              prefixIcon: Icon(CupertinoIcons.search, color: colorScheme.onSurface),
              context: context,
            ),
            style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          
          const SizedBox(height: 10), // Add some spacing before the list

          Column( 
            children: [
              // 3. 日誌列表
              if (_isLoading)
                Center(child: Padding(padding: const EdgeInsets.only(top: 20.0), child: CupertinoActivityIndicator(color: colorScheme.onSurface)))
              else if (_filteredLogs.isEmpty)
                Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50.0),
                      child: Text(
                        l10n.inventoryLogNoRecords, 
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = _filteredLogs[index];
                      return _LogCard(log: log); // 使用自訂卡片
                    },
                  ),
              ],
            ),

        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 2. 自訂日誌卡片元件 (_LogCard)
// -------------------------------------------------------------------

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final itemName = log['item_name'] as String? ?? l10n.inventoryLogCardUnknownItem; 
    final userName = log['user_name'] as String? ?? l10n.inventoryLogCardUnknownUser; 
    final itemUnit = log['item_unit'] as String? ?? '';
    
    final oldStock = (log['old_stock'] as num).toStringAsFixed(0);
    final newStock = (log['new_stock'] as num).toStringAsFixed(0);
    final adjustment = (log['adjustment'] as num).toStringAsFixed(0);
    final reasonKey = log['reason'] as String? ?? 'Other';
    final timestamp = DateTime.tryParse(log['created_at'])?.toLocal() ?? DateTime.now();

    // 決定原因的顏色
    final Color reasonColor = switch(reasonKey) {
      'Add' => Colors.green,
      'Inventory Adjustment' => colorScheme.error,
      'Waste' => Colors.orange, 
      _ => colorScheme.onSurface.withOpacity(0.7),
    };
    
    // 翻譯原因 Key
    final translatedReason = switch (reasonKey) {
      'Add' => l10n.inventoryLogReasonAdd,
      'Inventory Adjustment' => l10n.inventoryLogReasonAdjustment,
      'Waste' => l10n.inventoryLogReasonWaste,
      _ => reasonKey,
    };

    // 格式化右側文字
    final List<TextSpan> detailSpans = [
      TextSpan(text: '$translatedReason\n', style: TextStyle(color: reasonColor, fontWeight: FontWeight.bold)),
      
      // 變更數量
      TextSpan(text: l10n.inventoryLogCardLabelChange(adjustment, itemUnit)), 
      
      // 數量變化
      TextSpan(text: '\n${l10n.inventoryLogCardLabelStock(oldStock, newStock)}'),
      
      // 時間
      TextSpan(text: '\n${DateFormat('HH:mm:ss').format(timestamp)}'),
    ];

    return Container(
      // Figma 樣式
      margin: const EdgeInsets.only(bottom: 16.0), 
      padding: const EdgeInsets.all(16.0),
      height: 120, 
      decoration: BoxDecoration(
        color: theme.cardColor, 
        borderRadius: BorderRadius.circular(25), 
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左側：名稱與操作者
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  itemName,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  l10n.inventoryLogCardLabelName(userName), 
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // 右側：調整詳情
          RichText(
            textAlign: TextAlign.right,
            text: TextSpan(
              style: TextStyle(
                color: colorScheme.onSurface, 
                fontSize: 10, 
                height: 1.4 // 調整行高
              ),
              children: detailSpans,
            ),
          ),
        ],
      ),
    );
  }
}