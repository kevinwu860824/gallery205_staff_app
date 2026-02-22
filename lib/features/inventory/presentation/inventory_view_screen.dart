import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// 輔助方法：搜尋框樣式 (修改為接收 hintText)
InputDecoration _buildSearchDecoration(String hintText, BuildContext context) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: theme.cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
    prefixIcon: Icon(CupertinoIcons.search, color: theme.colorScheme.onSurface),
  );
}

// 輔助方法：庫存輸入框樣式
InputDecoration _buildStockInputDecoration(BuildContext context) {
  return InputDecoration(
    filled: true,
    fillColor: Theme.of(context).scaffoldBackgroundColor, // Use scaffold background for contrast inside card
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    isDense: true,
  );
}

// -------------------------------------------------------------------
// 2. 第一層：庫存類別列表 (InventoryViewScreen)
// -------------------------------------------------------------------

class InventoryViewScreen extends StatefulWidget {
  const InventoryViewScreen({super.key});

  @override
  State<InventoryViewScreen> createState() => _InventoryViewScreenState();
}

class _InventoryViewScreenState extends State<InventoryViewScreen> {
  String? _shopId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    // 只讀取類別
    final res = await Supabase.instance.client
        .from('inventory_categories')
        .select('id, name')
        .eq('shop_id', _shopId!)
        .order('sort_order', ascending: true);

    if (mounted) {
      setState(() {
        _categories = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    }
  }

  void _navigateToDetail(Map<String, dynamic> category) {
    // 使用 Navigator.push 進入下一層，傳遞 categoryId 和 Name
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewStockCategoryDetailScreen(
          categoryId: category['id'],
          categoryName: category['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // 這裡的 AppBar 只需顯示標題
      appBar: _buildSimpleAppBar(context, l10n.inventoryViewTitle), 
      body: _isLoading
          ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
          : ListView(
              padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 40),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _categories.length,
                    itemBuilder: (_, index) {
                      final category = _categories[index];
                      return _CustomNavTile(
                        title: category['name'],
                        onTap: () => _navigateToDetail(category),
                      );
                    },
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Divider(color: theme.dividerColor, height: 1, thickness: 0.5),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 第二層：類別內的品項列表 (InventoryCategoryDetailScreen)
//    包含原本的編輯、計算與儲存邏輯
// -------------------------------------------------------------------

class ViewStockCategoryDetailScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const ViewStockCategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ViewStockCategoryDetailScreen> createState() => _ViewStockCategoryDetailScreenState();
}

class _ViewStockCategoryDetailScreenState extends State<ViewStockCategoryDetailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // 狀態管理 (保留原本邏輯)
  final Map<String, TextEditingController> _stockControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, double> _initialStockValues = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stockControllers.forEach((_, controller) => controller.dispose());
    _focusNodes.forEach((_, node) => node.dispose());
    super.dispose();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    // 讀取該類別下的 items
    final res = await Supabase.instance.client
        .from('inventory_items')
        .select()
        .eq('shop_id', shopId)
        .eq('category_id', widget.categoryId)
        .order('sort_order', ascending: true);

    _focusNodes.forEach((_, node) => node.dispose());
    _focusNodes.clear();

    final List<Map<String, dynamic>> loadedItems = [];

    for (var item in res) {
      final itemId = item['id'] as String;
      final currentStock = (item['current_stock'] as num?)?.toDouble() ?? 0.0;
      final currentStockStr = currentStock.toStringAsFixed(0);

      loadedItems.add(item);

      // 初始化控制器
      if (!_stockControllers.containsKey(itemId)) {
        _stockControllers[itemId] = TextEditingController(text: currentStockStr);
      } else {
        // 如果使用者沒在編輯，才更新數值
        if ((_initialStockValues[itemId] ?? 0) != currentStock) {
           _stockControllers[itemId]!.text = currentStockStr;
        }
      }
      
      _focusNodes[itemId] = FocusNode();
      _initialStockValues[itemId] = currentStock;
    }

    // ✅ 新增：排序邏輯 (庫存不足的排在最前面，其餘依 sort_order)
    loadedItems.sort((a, b) {
      final aStock = (a['current_stock'] as num?)?.toDouble() ?? 0.0;
      final aPar = (a['par_level'] as num? ?? a['low_stock_threshold'] as num? ?? 0.0).toDouble();
      final aIsLow = aStock < aPar;

      final bStock = (b['current_stock'] as num?)?.toDouble() ?? 0.0;
      final bPar = (b['par_level'] as num? ?? b['low_stock_threshold'] as num? ?? 0.0).toDouble();
      final bIsLow = bStock < bPar;

      // 如果 a 是低庫存，b 不是，a 排前面
      if (aIsLow && !bIsLow) return -1;
      // 如果 b 是低庫存，a 不是，b 排前面
      if (!aIsLow && bIsLow) return 1;
      
      // 如果狀態相同，則依照原始 sort_order 排序
      final aSort = (a['sort_order'] as num?)?.toInt() ?? 0;
      final bSort = (b['sort_order'] as num?)?.toInt() ?? 0;
      return aSort.compareTo(bSort);
    });

    if (mounted) {
      setState(() {
        _items = loadedItems;
        _isLoading = false;
      });
    }
  }

  // 取得未儲存的變更
  List<Map<String, dynamic>> _getUnsavedChanges() {
    List<Map<String, dynamic>> changes = [];
    for (var entry in _stockControllers.entries) {
      final itemId = entry.key;
      final controller = entry.value;
      final currentInput = double.tryParse(controller.text.trim()) ?? 0.0;
      final initialValue = _initialStockValues[itemId] ?? 0.0;
      
      if ((currentInput - initialValue).abs() > 0.001) {
        final item = _items.firstWhere((e) => e['id'] == itemId, orElse: () => {});
        if (item.isNotEmpty) {
          changes.add({
            'id': itemId,
            'name': item['name'],
            'unit': item['unit'],
            'old': initialValue,
            'new': currentInput,
          });
        }
      }
    }
    return changes;
  }

  // 單筆更新
  Future<bool> _handleSingleUpdate({required String itemId, required double newStock, required double oldStock}) async {
    final l10n = AppLocalizations.of(context)!;
    final adjustment = newStock - oldStock;
    final item = _items.firstWhere((e) => e['id'] == itemId, orElse: () => {});
    try {
      await Supabase.instance.client.rpc(
        'rpc_update_inventory',
        params: {
          'item_id': itemId,
          'new_stock': newStock,
          'reason': adjustment > 0 ? l10n.inventoryReasonStockIn : l10n.inventoryReasonAudit,
        },
      );
      _initialStockValues[itemId] = newStock;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.inventoryUpdateSuccess(item['name'])), 
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return true;
    } catch (e) {
      await _showAlert(l10n.inventoryUpdateFailedTitle, l10n.inventoryUpdateFailedMsg); 
      return false;
    }
  }

  Future<void> _onPressUpdate(Map<String, dynamic> item) async {
    final l10n = AppLocalizations.of(context)!;
    final itemId = item['id'] as String;
    final oldStock = _initialStockValues[itemId] ?? (item['current_stock'] as num?)?.toDouble() ?? 0.0;
    final newStockStr = _stockControllers[itemId]?.text.trim() ?? '';

    if (newStockStr.isEmpty) {
      FocusScope.of(context).unfocus();
      return;
    }
    final newStock = double.tryParse(newStockStr);
    if (newStock == null) {
      FocusScope.of(context).unfocus();
      await _showAlert(l10n.inventoryErrorTitle, l10n.inventoryErrorInvalidNumber); 
      return;
    }

    if ((newStock - oldStock).abs() < 0.001) {
      FocusScope.of(context).unfocus();
      // 數值沒變，不需動作
      return;
    }

    final adjustment = newStock - oldStock;

    final confirmation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmUpdateDialog(
        unit: item['unit'] ?? '',
        oldStock: oldStock,
        newStock: newStock,
        adjustment: adjustment,
      ),
    ) ?? false;

    FocusScope.of(context).unfocus();
    if (!confirmation) return;

    final success = await _handleSingleUpdate(itemId: itemId, newStock: newStock, oldStock: oldStock);
    if (success) {
      // 更新成功後，重新載入該頁面資料 (保持 sync)
      await _loadItems();
    }
  }

  Future<bool> _saveAllChanges(List<Map<String, dynamic>> changes) async {
    final l10n = AppLocalizations.of(context)!;
    for (var item in changes) {
      final newStock = item['new'] as double;
      final oldStock = item['old'] as double;
      final itemId = item['id'] as String;
      final adjustment = newStock - oldStock;
      try {
        await Supabase.instance.client.rpc(
          'rpc_update_inventory',
          params: {
            'item_id': itemId,
            'new_stock': newStock,
            'reason': '批量更新: ' + (adjustment > 0 ? l10n.inventoryReasonStockIn : l10n.inventoryReasonAudit),
          },
        );
        _initialStockValues[itemId] = newStock;
      } catch (e) {
        await _showAlert(l10n.inventoryBatchSaveFailedTitle, l10n.inventoryBatchSaveFailedMsg(item['name'])); 
        return false;
      }
    }
    await _loadItems();
    return true;
  }

  Future<void> _showAlert(String title, String content) async {
    await showDialog(
      context: context,
      builder: (_) => _NoticeDialog(
        title: title,
        content: content,
      ),
    );
  }

  Future<String?> _showUnsavedChangesDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final contentWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.inventoryUnsavedContent, 
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
      ],
    );

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UnsavedChangesDialog(
        content: contentWidget,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final changes = _getUnsavedChanges();
    if (changes.isEmpty) {
      return true;
    }
    FocusScope.of(context).unfocus();
    final result = await _showUnsavedChangesDialog();
    if (result == 'discard') {
      return true; // 放棄變更，直接退出
    }
    if (result == 'save_all') {
      final success = await _saveAllChanges(changes);
      return success; // 儲存成功後退出
    }
    return false; // 取消退出
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _buildSimpleAppBar(context, widget.categoryName),
        body: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
      );
    }

    final filteredItems = _items.where((item) {
      final name = item['name'] as String;
      final query = _searchQuery.toLowerCase();
      return name.toLowerCase().contains(query);
    }).toList();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: _buildHeaderWithBack(context, widget.categoryName),
          body: Column(
            children: [
              // 搜尋框
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextFormField(
                  controller: _searchController,
                  decoration: _buildSearchDecoration(l10n.inventorySearchHint, context), 
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              
              // 品項列表
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: filteredItems.isNotEmpty
                      ? filteredItems.map((item) {
                          final itemId = item['id'] as String;
                          final currentStock = _initialStockValues[itemId] ?? (item['current_stock'] as num?)?.toDouble() ?? 0;
                          final parLevel = (item['par_level'] as num? ?? item['low_stock_threshold'] as num? ?? 0).toDouble();
                          final isLow = currentStock < parLevel;

                          return _buildInventoryItemTile(
                            item: item,
                            isLow: isLow,
                            controller: _stockControllers[itemId]!,
                            focusNode: _focusNodes[itemId]!,
                          );
                        }).toList()
                      : [
                          Padding(
                            padding: const EdgeInsets.only(top: 50.0),
                            child: Center(child: Text(l10n.inventoryNoItems, style: TextStyle(color: colorScheme.onSurface))), 
                          )
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeaderWithBack(BuildContext context, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PreferredSize(
      preferredSize: const Size.fromHeight(100.0),
      child: Container(
        color: theme.scaffoldBackgroundColor,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
                onPressed: () async {
                  final shouldPop = await _onWillPop();
                  if (shouldPop) {
                    if (mounted) Navigator.pop(context);
                  }
                },
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24, // 稍微縮小字體以適應長標題
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 58), // 平衡返回按鈕的空間
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryItemTile({
    required Map<String, dynamic> item,
    required bool isLow,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = item['name'] as String;
    final parLevelValue = (item['par_level'] as num? ?? item['low_stock_threshold'] as num? ?? 0);
    final parLevel = parLevelValue.toStringAsFixed(0);
    final itemColor = isLow ? const Color(0xFFCC0000) : colorScheme.onSurface;
    final safetyColor = isLow ? const Color(0xFFCC0000) : colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      height: 75,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: itemColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.inventorySafetyQuantity(parLevel), 
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: safetyColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 93,
            height: 50,
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: _buildStockInputDecoration(context),
              onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
            ),
          ),
          const SizedBox(width: 10),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minSize: 22,
            onPressed: () => _onPressUpdate(item),
            child: Icon(
              CupertinoIcons.refresh,
              color: colorScheme.onSurface,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 4. 輔助 Widget
// -------------------------------------------------------------------

// 頁面 1 的簡單 AppBar
PreferredSizeWidget _buildSimpleAppBar(BuildContext context, String title) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return PreferredSize(
    preferredSize: const Size.fromHeight(100.0),
    child: Container(
      color: theme.scaffoldBackgroundColor,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 58), // 平衡空間
          ],
        ),
      ),
    ),
  );
}

// 導航列表項目
class _CustomNavTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _CustomNavTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface, size: 20),
        ],
      ),
    );
  }
}

// --- Dialog 相關 ---

class _WhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const _WhiteButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: 109.6,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TextCancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _TextCancelButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextButton(
      onPressed: onPressed,
      child: Text(
        l10n.commonCancel, 
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _TextDiscardButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _TextDiscardButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextButton(
      onPressed: onPressed,
      child: Text(
        l10n.inventoryUnsavedDiscard, 
        style: TextStyle(
          color: colorScheme.error,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NoticeDialog extends StatelessWidget {
  final String title;
  final String content;

  const _NoticeDialog({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _WhiteButton(
              text: l10n.commonOk,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmUpdateDialog extends StatelessWidget {
  final String unit;
  final double oldStock;
  final double newStock;
  final double adjustment;

  const _ConfirmUpdateDialog({
    required this.unit,
    required this.oldStock,
    required this.newStock,
    required this.adjustment,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.inventoryConfirmUpdateTitle, 
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.inventoryConfirmUpdateOriginal(oldStock.toStringAsFixed(0), unit)}\n'
              '${l10n.inventoryConfirmUpdateNew(newStock.toStringAsFixed(0), unit)}\n'
              '${l10n.inventoryConfirmUpdateChange(adjustment.toStringAsFixed(0))}', 
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TextCancelButton(
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                _WhiteButton(
                  text: l10n.commonSave, 
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsavedChangesDialog extends StatelessWidget {
  final Widget content;
  const _UnsavedChangesDialog({required this.content});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.inventoryUnsavedTitle, 
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 24),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _TextDiscardButton(
                  onPressed: () => Navigator.of(context).pop('discard'),
                ),
                _TextCancelButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                ),
                const SizedBox(height: 15),
                _WhiteButton(
                  text: l10n.commonSave, 
                  onPressed: () => Navigator.of(context).pop('save_all'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}