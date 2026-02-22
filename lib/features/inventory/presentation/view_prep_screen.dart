// lib/features/inventory/presentation/view_prep_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // ✅ 導入 Material
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// 輔助方法：統一輸入框樣式
InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
    filled: true,
    fillColor: theme.cardColor, 
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25), // 高度圓角
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  );
}

// -------------------------------------------------------------------
// 2. 頁面一: 備料類別 (ViewPrepScreen)
// -------------------------------------------------------------------

class ViewPrepScreen extends StatefulWidget {
  const ViewPrepScreen({super.key});

  @override
  State<ViewPrepScreen> createState() => _ViewPrepScreenState();
}

class _ViewPrepScreenState extends State<ViewPrepScreen> {
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    final res = await Supabase.instance.client
        .from('stock_categories')
        .select('id, name')
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);

    setState(() {
      categories = List<Map<String, dynamic>>.from(res);
      isLoading = false;
    });
  }

  void _navigateToItems(Map<String, dynamic> category) {
    context.push(
      '/prepItemSelection',
      extra: {
        'categoryId': category['id'],
        'categoryName': category['name'],
      },
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
          l10n.prepViewTitle,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // 卡片內容
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: categories.length,
                    itemBuilder: (_, index) {
                      final category = categories[index];
                      return _CustomNavTile(
                        title: category['name'],
                        onTap: () => _navigateToItems(category),
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
// 3. 頁面二: 備料品項 (ItemSelectionScreen)
// -------------------------------------------------------------------

class ItemSelectionScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const ItemSelectionScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ItemSelectionScreen> createState() => _ItemSelectionScreenState();
}

class _ItemSelectionScreenState extends State<ItemSelectionScreen> {
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    final res = await Supabase.instance.client
        .from('stock_items')
        .select('id, title, details, created_at')
        .eq('category_id', widget.categoryId)
        .eq('shop_id', shopId) 
        .order('sort_order', ascending: true);

    setState(() {
      items = List<Map<String, dynamic>>.from(res);
      isLoading = false;
    });
  }

  void _goToDetail(Map<String, dynamic> item) {
    context.push('/prepItemDetail', extra: item);
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
          widget.categoryName,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // 卡片內容
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return _CustomNavTile(
                        title: item['title'] ?? l10n.prepViewItemUntitled, 
                        onTap: () => _goToDetail(item),
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
// 4. 頁面三: 備料詳情 (ViewItemDetailScreen)
// -------------------------------------------------------------------

class ViewItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const ViewItemDetailScreen({super.key, required this.item});

  @override
  State<ViewItemDetailScreen> createState() => _ViewItemDetailScreenState();
}

class _ViewItemDetailScreenState extends State<ViewItemDetailScreen> {
  List<Map<String, dynamic>> mainDetails = [];
  Map<String, List<Map<String, dynamic>>> groupedSub = {};
  List<Map<String, dynamic>> otherNotes = [];
  
  // Controllers
  List<TextEditingController> quantityControllers = [];
  List<List<TextEditingController>> subControllers = [];
  TextEditingController totalQuantityController = TextEditingController(); // ✅ Added

  // State
  List<bool> mainChecked = [];
  Map<String, List<bool>> subChecked = {};
  double baseTotalQty = 0; // ✅ Added

  @override
  void initState() {
    super.initState();
    _parseDetails();
  }
  
  void _parseDetails() {
    final raw = List<Map<String, dynamic>>.from(widget.item['details'] ?? []);

    // 1. 處理主材料
    mainDetails = raw.where((e) => e['type'] == 'main').toList();
    quantityControllers = mainDetails
        .map((e) => TextEditingController(text: e['quantity']?.toString() ?? ''))
        .toList();
    mainChecked = List.generate(mainDetails.length, (_) => false);

    // ✅ Calculate Base Total (Sum of Main Ingredients)
    baseTotalQty = mainDetails.fold(0, (sum, item) {
       return sum + (double.tryParse(item['quantity']?.toString() ?? '0') ?? 0);
    });
    totalQuantityController.text = baseTotalQty > 0 ? baseTotalQty.toStringAsFixed(1) : '';

    // 2. 處理副材料
    final subDetails = raw.where((e) => e['type'] == 'sub' && e['label'] != null).toList();
    for (var item in subDetails) {
      final label = item['label']!;
      groupedSub.putIfAbsent(label, () => []).add(item);
    }
    
    subControllers = [];
    subChecked = {};
    for (var label in groupedSub.keys) {
      final group = groupedSub[label]!;
      subControllers.add(group
          .map((e) => TextEditingController(text: e['quantity']?.toString() ?? ''))
          .toList());
      subChecked[label] = List.generate(group.length, (_) => false);
    }

    // 3. 處理備註
    otherNotes = raw.where((e) => e['type'] == 'note').toList();
  }

  // ✅ Total Quantity Changed Logic
  void _onTotalQuantityChanged() {
    final input = double.tryParse(totalQuantityController.text);
    if (input == null || baseTotalQty == 0) return;

    final ratio = input / baseTotalQty;

    // Update Main Ingredients ONLY
    for (int i = 0; i < mainDetails.length; i++) {
        final refQty = double.tryParse(mainDetails[i]['quantity'].toString()) ?? 0;
        quantityControllers[i].text = (refQty * ratio).toStringAsFixed(1);
    }
    setState(() {});
  }

  void _onQuantityChanged(int index) {
    final baseQty = double.tryParse(mainDetails[index]['quantity'].toString()) ?? 0;
    final input = double.tryParse(quantityControllers[index].text);
    if (input == null || baseQty == 0) return;

    final ratio = input / baseQty;

    // Update other Main Ingredients ONLY
    for (int i = 0; i < mainDetails.length; i++) {
      if (i == index) continue;
      final refQty = double.tryParse(mainDetails[i]['quantity'].toString()) ?? 0;
      quantityControllers[i].text = (refQty * ratio).toStringAsFixed(1);
    }
    
    // ✅ Update Total Quantity
    totalQuantityController.text = (baseTotalQty * ratio).toStringAsFixed(1);

    setState(() {});
  }

  void _onSubChanged(String label, int changedIndex) {
    final labelIndex = groupedSub.keys.toList().indexOf(label);
    final group = groupedSub[label]!;
    
    final baseQty = double.tryParse(group[changedIndex]['quantity'].toString()) ?? 0;
    final input = double.tryParse(subControllers[labelIndex][changedIndex].text);
    if (input == null || baseQty == 0) return;

    final ratio = input / baseQty;
    
    // Update other Sub Ingredients (in the same group) ONLY
    for (int i = 0; i < group.length; i++) {
      if (i == changedIndex) continue;
      final refQty = double.tryParse(group[i]['quantity'].toString()) ?? 0;
      subControllers[labelIndex][i].text = (refQty * ratio).toStringAsFixed(1);
    }
    setState(() {});
  }
  
  // ✅ [Refactor] _buildRow with wider input
  Widget _buildRow({
    required String name,
    required TextEditingController controller,
    String? unit,
    bool enabled = true,
    void Function()? onChanged,
    bool? checked,
    VoidCallback? onCheckToggle,
    bool showCheckboxPlaceholder = true, // ✅ Custom flag
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 勾選框 (Optional)
          if (checked != null && onCheckToggle != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onCheckToggle,
              child: Icon(
                checked ? CupertinoIcons.checkmark_square_fill : CupertinoIcons.square,
                color: colorScheme.onSurface,
                size: 20,
              ),
            )
          else if (showCheckboxPlaceholder) // ✅ Check flag
            const SizedBox(width: 30), 

          const SizedBox(width: 10),
          // 名稱
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withOpacity(0.8)),
            ),
          ),
          const SizedBox(width: 10),
          // 數量 (白色輸入框)
          SizedBox(
            width: 140, // ✅ Widened 1.5x (was 93)
            height: 38,
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => onChanged?.call(),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              textAlign: TextAlign.center,
              decoration: _buildInputDecoration(hintText: '', context: context), 
            ),
          ),
          const SizedBox(width: 10),
          // 單位
          SizedBox(
            width: 40, 
            child: Text(
              unit ?? '',
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withOpacity(0.8)),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  // ... _buildSectionHeader ...

  @override
  Widget build(BuildContext context) {
    // ... setup ...
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      // ... appBar ...
      appBar: AppBar(
        // ...
        title: Text(widget.item['title'] ?? l10n.prepViewItemUntitled, style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface), onPressed: () => context.pop()),
        backgroundColor: theme.scaffoldBackgroundColor, elevation: 0, centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // ✅ Reduced top vertical padding from 20 to 10
          children: [
             // ✅ Total Quantity Row
             if (mainDetails.isNotEmpty) ...[
                // ✅ Use 0 top padding for the first header
                _buildSectionHeader(l10n.prepViewMainIngredients, topPadding: 0),
                _buildRow(
                  name: "總量 (Total Quantity)", 
                  controller: totalQuantityController,
                  unit: "", 
                  onChanged: _onTotalQuantityChanged,
                  checked: null, 
                  onCheckToggle: null,
                  showCheckboxPlaceholder: false, // ✅ Move to left
                ),
                const SizedBox(height: 10),
                Divider(color: theme.dividerColor),
             ],

             // --- Main Ingredients ---
             // _buildSectionHeader(l10n.prepViewMainIngredients) - Already put above? 
             // Ideally: Header -> Total -> Ingredients.
             // Actually user said: "Above Main Ingredients add a Total Quantity". 
             // So: 
             // Header: Main Ingredients
             // Row: 總量
             // List: Ingredients
             
            ...List.generate(mainDetails.length, (i) {
              final item = mainDetails[i];
              return _buildRow(
                name: item['name'] ?? '',
                controller: quantityControllers[i],
                unit: item['unit'] ?? '',
                onChanged: () => _onQuantityChanged(i),
                checked: mainChecked[i],
                onCheckToggle: () => setState(() => mainChecked[i] = !mainChecked[i]),
              );
            }),
            
            // --- 副材料 ---
            ...groupedSub.entries.map((entry) {
              final label = entry.key;
              final items = entry.value;
              final labelIndex = groupedSub.keys.toList().indexOf(label);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(label),
                  ...List.generate(items.length, (i) {
                    final item = items[i];
                    return _buildRow(
                      name: item['name'] ?? '',
                      controller: subControllers[labelIndex][i],
                      unit: item['unit'] ?? '',
                      onChanged: () => _onSubChanged(label, i),
                      checked: subChecked[label]![i],
                      onCheckToggle: () => setState(() => subChecked[label]![i] = !subChecked[label]![i]),
                    );
                  }),
                  // 副材料備註
                  if ((items.first['note'] ?? '').toString().trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 4),
                      child: Text(
                        l10n.prepViewNote(items.first['note']), 
                        style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                      ),
                    ),
                ],
              );
            }).toList(),
            
            // --- 總備註 (Detail) ---
            if (otherNotes.isNotEmpty)
              ...otherNotes.map((note) {
                final label = note['label'] ?? l10n.prepViewDetailLabel; 
                final text = note['name']?.toString().trim() ?? '';
                if (text.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(label),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        text,
                        style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
  
  // ✅ [新增] 標題 Widget (移入類別內)
  Widget _buildSectionHeader(String title, {double topPadding = 24}) {
    final theme = Theme.of(context);
    return Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
  }
}

// -------------------------------------------------------------------
// 5. 輔助 Widget
// -------------------------------------------------------------------

// ✅ [新增] 統一的列表項目 (用於頁面 1 和 2)
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

// ✅ [新增] 統一的頁面頂部 (Header)
// ✅ 修正 1: 移除 title 參數和 Text Widget
Widget _buildHeader(BuildContext context, double safeAreaTop) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: Container(
      color: theme.scaffoldBackgroundColor,
      // 調整 Padding，使其只包含返回按鈕
      padding: EdgeInsets.only(top: safeAreaTop, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // 只需靠左
        children: [
          // 返回按鈕
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_left),
            color: colorScheme.onSurface,
            iconSize: 30,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    ),
  );
}