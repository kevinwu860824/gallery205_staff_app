// lib/features/inventory/presentation/add_stock_item_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // ✅ 引入 Material
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ 引入 SharedPreferences
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// 輔助方法：統一輸入框樣式
InputDecoration _buildInputDecoration({required String hintText, required BuildContext context, Color? fillColor}) {
    final theme = Theme.of(context);
    return InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: fillColor ?? theme.cardColor, // Default to card color (for use on scaffold)
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25), // 高度圓角
            borderSide: BorderSide.none,
        ),
        // 調整垂直 padding 以匹配 Figma 的 38px 高度
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
    );
}

class AddStockItemScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final Map<String, dynamic>? initialData;
  final String? itemId;

  const AddStockItemScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.initialData,
    this.itemId,
  });

  @override
  State<AddStockItemScreen> createState() => _AddStockItemScreenState();
}

class _AddStockItemScreenState extends State<AddStockItemScreen> {
  final nameController = TextEditingController();
  final List<List<TextEditingController>> mainMaterials = [];
  final List<Map<String, dynamic>> subMaterials = [];
  final List<TextEditingController> notes = [];
  bool isEditingSub = false;
  String? _shopId; // ✅ 儲存 ShopId

  @override
  void initState() {
    super.initState();
    _loadShopId(); // 載入 ShopId
    
    if (widget.initialData != null) {
      nameController.text = widget.initialData!['title'] ?? '';
      final List details = widget.initialData!['details'] ?? [];
      for (var detail in details) {
        if (detail['type'] == 'main') {
          mainMaterials.add([
            TextEditingController(text: detail['name'] ?? ''),
            TextEditingController(text: detail['quantity'] ?? ''),
            TextEditingController(text: detail['unit'] ?? ''),
          ]);
        } else if (detail['type'] == 'sub') {
          // [修正] 使用實際翻譯鍵
          final label = detail['label'] ?? '副材料'; 
          final existing = subMaterials.firstWhere(
            (s) => s['label'] == label,
            orElse: () {
              final entry = {
                'label': label,
                'controllers': <List<TextEditingController>>[],
                'noteController': TextEditingController(), // 確保 noteController 存在
              };
              subMaterials.add(entry);
              return entry;
            },
          );
          (existing['controllers'] as List).add([
            TextEditingController(text: detail['name'] ?? ''),
            TextEditingController(text: detail['quantity'] ?? ''),
            TextEditingController(text: detail['unit'] ?? ''),
          ]);
          // 確保 noteController 被正確賦值
          existing['noteController'] = TextEditingController(text: detail['note'] ?? '');
        } else if (detail['type'] == 'note') {
          notes.add(TextEditingController(text: detail['name'] ?? ''));
        }
      }
    }
    // 確保至少有一行主材料
    if (mainMaterials.isEmpty) {
      _addMainMaterialRow();
    }
  }

  Future<void> _loadShopId() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
  }

  void _addMainMaterialRow() {
    mainMaterials.add([
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ]);
  }

  void _addNoteRow() {
    notes.add(TextEditingController());
    setState(() {});
  }

  Future<void> _addSubMaterialRow() async {
    final l10n = AppLocalizations.of(context)!;
    // ✅ [修正] 使用自訂 Dialog
    final confirmed = await showDialog<String>(
      context: context,
      builder: (_) => _AddEditDialog( // 假設 _AddEditDialog 在此檔案或已匯入
        title: l10n.stockItemAddSubDialogTitle, 
        hintText: l10n.stockItemAddSubHintGroupName, 
        existingNames: subMaterials.map((s) => s['label'] as String).toList(),
      ),
    );
    if (confirmed != null && confirmed.isNotEmpty) {
      subMaterials.add({
        'label': confirmed,
        'controllers': [
          [TextEditingController(), TextEditingController(), TextEditingController()]
        ],
        'noteController': TextEditingController(),
      });
      setState(() {});
    }
  }

  // ✅ [修正] 彈出 Figma 樣式的 ActionSheet
  void _showAddOptions() {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(l10n.stockItemAddOptionTitle), 
        actions: [
          CupertinoActionSheetAction(
            child: Text(l10n.stockItemAddOptionSub), 
            onPressed: () {
              context.pop();
              _addSubMaterialRow();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(l10n.stockItemAddOptionDetail), 
            onPressed: () {
              context.pop();
              _addNoteRow();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(l10n.commonCancel), 
          onPressed: () => context.pop(),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final itemName = nameController.text.trim();
    if (itemName.isEmpty) return;
    List<Map<String, dynamic>> details = [];
    for (var row in mainMaterials) {
      if (row.any((c) => c.text.trim().isNotEmpty)) {
        details.add({
          'name': row[0].text.trim(),
          'quantity': row[1].text.trim(),
          'unit': row[2].text.trim(),
          'type': 'main',
        });
      }
    }
    for (var sub in subMaterials) {
      final rows = sub['controllers'] as List<List<TextEditingController>>;
      final label = sub['label'];
      final note = (sub['noteController'] as TextEditingController).text.trim();
      for (var row in rows) {
        if (row.any((c) => c.text.trim().isNotEmpty)) {
          details.add({
            'name': row[0].text.trim(),
            'quantity': row[1].text.trim(),
            'unit': row[2].text.trim(),
            'type': 'sub',
            'label': label,
            if (note.isNotEmpty) 'note': note,
          });
        }
      }
    }
    for (int i = 0; i < notes.length; i++) {
      final note = notes[i].text.trim();
      if (note.isNotEmpty) {
        details.add({
          'name': note,
          'type': 'note',
          'label': l10n.stockItemLabelDetails(i + 1), // 'Details {i + 1}'
        });
      }
    }
    final itemData = {
      'title': itemName,
      'details': details,
      'category_id': widget.categoryId,
      'shop_id': _shopId,
    };
    if (widget.itemId != null) {
      await Supabase.instance.client.from('stock_items').update(itemData).eq('id', widget.itemId!);
    } else {
      await Supabase.instance.client.from('stock_items').insert({
        'id': const Uuid().v4(),
        'created_at': DateTime.now().toIso8601String(),
        'sort_order': 0, // 假設新項目在詳細頁面排序
        ...itemData,
      });
    }
    context.pop();
  }
  
  void _checkAndExpandMain() {
    final last = mainMaterials.last;
    if (last.any((c) => c.text.trim().isNotEmpty)) {
      _addMainMaterialRow();
      setState(() {});
    }
  }
  void _checkAndExpandSub(int i, int j) {
    final rows = subMaterials[i]['controllers'] as List<List<TextEditingController>>;
    final row = rows[j];
    if (row.any((c) => c.text.trim().isNotEmpty) && j == rows.length - 1) {
      rows.add([TextEditingController(), TextEditingController(), TextEditingController()]);
      setState(() {});
    }
  }

  // ✅ [修正] 改造 _buildMaterialRow 以匹配 Figma
  Widget _buildMaterialRow(List<TextEditingController> row, VoidCallback onChanged) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        children: [
          // 品名
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: row[0], 
              decoration: _buildInputDecoration(hintText: l10n.stockItemHintIngredient, context: context), 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 7),
          // 數量
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row[1], 
              decoration: _buildInputDecoration(hintText: l10n.stockItemHintQty, context: context), 
              keyboardType: const TextInputType.numberWithOptions(decimal: true), 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 7),
          // 單位
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row[2], 
              decoration: _buildInputDecoration(hintText: l10n.stockItemHintUnit, context: context), 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ [修正] 改造 _buildNoteRow 以匹配 Figma
  Widget _buildNoteRow(TextEditingController controller) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: TextFormField(
        controller: controller,
        decoration: _buildInputDecoration(hintText: l10n.stockItemHintInstructionsNote, context: context), 
        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        maxLines: 3,
        minLines: 1,
        keyboardType: TextInputType.multiline,
      ),
    );
  }

  Future<void> _confirmDeleteSubMaterial(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(l10n.stockItemDeleteSubTitle), 
        content: Text(l10n.stockItemDeleteSubContent), 
        actions: [
          CupertinoDialogAction(child: Text(l10n.commonCancel), onPressed: () => context.pop(false)), 
          CupertinoDialogAction(isDestructiveAction: true, child: Text(l10n.commonDelete), onPressed: () => context.pop(true)), 
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        subMaterials.removeAt(index);
      });
    }
  }
  Future<void> _confirmDeleteNote(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(l10n.stockItemDeleteNoteTitle), 
        content: Text(l10n.stockItemDeleteNoteContent), 
        actions: [
          CupertinoDialogAction(child: Text(l10n.commonCancel), onPressed: () => context.pop(false)), 
          CupertinoDialogAction(isDestructiveAction: true, child: Text(l10n.commonDelete), onPressed: () => context.pop(true)), 
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        notes.removeAt(index);
      });
    }
  }


  Future<void> _editSubMaterialLabel(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final currentLabel = subMaterials[index]['label'] as String;
    
    final newLabel = await showDialog<String>(
      context: context,
      builder: (_) => _AddEditDialog(
        title: l10n.stockItemEditSubDialogTitle, // You might need to add this key or use a generic "Edit Name"
        hintText: l10n.stockItemAddSubHintGroupName, 
        initialName: currentLabel,
        existingNames: subMaterials.map((s) => s['label'] as String).toList(),
      ),
    );

    if (newLabel != null && newLabel.isNotEmpty && newLabel != currentLabel) {
      setState(() {
        subMaterials[index]['label'] = newLabel;
      });
    }
  }

  void _moveSubMaterial(int index, int step) {
    final newIndex = index + step;
    if (newIndex < 0 || newIndex >= subMaterials.length) return;
    
    setState(() {
      final item = subMaterials.removeAt(index);
      subMaterials.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // --- 內容區 (ListView) ---
          ListView(
            padding: EdgeInsets.only(top: safeAreaTop + 80, left: 16, right: 16, bottom: 90), 
            children: [
              // Product Name
              TextFormField(
                controller: nameController,
                decoration: _buildInputDecoration(hintText: l10n.stockItemLabelName, context: context), 
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              ),
              
              // Main Ingredients
              Padding(
                padding: const EdgeInsets.only(top: 24.0, left: 10.0, bottom: 8.0),
                child: Text(l10n.stockItemLabelMainIngredients, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)), // 'Main Ingredients'
              ),
              ...mainMaterials.map((row) => _buildMaterialRow(row, _checkAndExpandMain)).toList(),

              // Subsidiary Ingredients
              for (int i = 0; i < subMaterials.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 24.0, left: 10.0, bottom: 8.0),
                  child: Row(
                    children: [
                      if (isEditingSub) ...[
                        // 刪除
                        CupertinoButton(
                          padding: const EdgeInsets.only(right: 8),
                          minSize: 0,
                          child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed, size: 22),
                          onPressed: () => _confirmDeleteSubMaterial(i),
                        ),
                        // 編輯名稱
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minSize: 0,
                          child: Icon(CupertinoIcons.pencil, color: colorScheme.primary, size: 22),
                          onPressed: () => _editSubMaterialLabel(i),
                        ),
                        // 往上
                        if (i > 0)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minSize: 0,
                            child: Icon(CupertinoIcons.arrow_up_circle, color: colorScheme.onSurface, size: 22),
                            onPressed: () => _moveSubMaterial(i, -1),
                          ),
                        // 往下
                        if (i < subMaterials.length - 1)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minSize: 0,
                            child: Icon(CupertinoIcons.arrow_down_circle, color: colorScheme.onSurface, size: 22),
                            onPressed: () => _moveSubMaterial(i, 1),
                          ),
                         const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          subMaterials[i]['label'], 
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // 該副材料的品項
                for (int j = 0; j < (subMaterials[i]['controllers'] as List).length; j++)
                  _buildMaterialRow(
                    subMaterials[i]['controllers'][j],
                    () => _checkAndExpandSub(i, j),
                  ),
                // 該副材料的備註
                Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: TextFormField(
                    controller: subMaterials[i]['noteController'],
                    decoration: _buildInputDecoration(hintText: l10n.stockItemHintInstructionsSub, context: context), 
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
              ],
              
              // Details
              for (int i = 0; i < notes.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 24.0, left: 10.0, bottom: 8.0),
                  child: Row(
                    children: [
                      if (isEditingSub)
                        CupertinoButton(
                          padding: const EdgeInsets.only(right: 8),
                          child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed, size: 22),
                          onPressed: () => _confirmDeleteNote(i),
                        ),
                      Text(l10n.stockItemLabelDetails(i + 1), style: TextStyle(color: colorScheme.onSurface, fontSize: 16)), // 'Details {i + 1}'
                    ],
                  ),
                ),
                _buildNoteRow(notes[i]),
              ],
            ],
          ),

          // --- 頂部標題和按鈕 (固定) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.only(top: safeAreaTop, bottom: 10, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 返回按鈕
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_left),
                    color: colorScheme.onSurface,
                    iconSize: 30,
                    onPressed: () => context.pop(),
                  ),
                  // 標題
                  Text(
                    l10n.stockItemTitle, 
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.03,
                    ),
                  ),
                  // 右側按鈕 (編輯/新增)
                  Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(isEditingSub ? CupertinoIcons.check_mark_circled : CupertinoIcons.gear_solid, color: colorScheme.onSurface, size: 30),
                        onPressed: () => setState(() => isEditingSub = !isEditingSub),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(CupertinoIcons.add_circled_solid, color: colorScheme.onSurface, size: 30),
                        onPressed: _showAddOptions,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- 底部儲存按鈕 (固定) ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.only(bottom: 30.0, top: 16.0),
              child: Center(
                child: SizedBox(
                  width: 109.6, // Figma 寬度
                  height: 38,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary, 
                      foregroundColor: colorScheme.onPrimary, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(
                      l10n.commonSave, 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 5. 輔助 Dialog 類別 (新增/編輯 類別) - (從 manage_inventory_screen 複製)
// -------------------------------------------------------------------

class _AddEditDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String? initialName;
  final List<String> existingNames;

  const _AddEditDialog({
    required this.title,
    required this.hintText,
    required this.existingNames,
    this.initialName,
  });

  @override
  State<_AddEditDialog> createState() => _AddEditDialogState();
}

class _AddEditDialogState extends State<_AddEditDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    if (widget.initialName == null && widget.existingNames.contains(name)) {
      return; 
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditMode = widget.initialName != null;
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
              widget.title,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: controller,
              decoration: _buildInputDecoration(hintText: widget.hintText, context: context, fillColor: theme.scaffoldBackgroundColor),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null), 
                  child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16))
                ),
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary, 
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                    ),
                    child: Text(
                      isEditMode ? l10n.commonSave : l10n.commonAdd, 
                      style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)
                    ),
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