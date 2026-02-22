// lib/features/inventory/presentation/add_inventory_item_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // 需要 Material 才能用 Colors, SnackBar
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../build/bordered_cupertino_button.dart';

class AddInventoryItemScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final Map<String, dynamic>? initialData;
  final String? itemId;

  const AddInventoryItemScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.initialData,
    this.itemId,
  });

  @override
  State<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends State<AddInventoryItemScreen> {
  final nameController = TextEditingController();
  final unitController = TextEditingController();
  final stockController = TextEditingController();
  final parController = TextEditingController();
  bool isEditing = false;
  String? _shopId;

  // ... initState, _loadShopId 保持不變 ...
  @override
  void initState() {
    super.initState();
    isEditing = widget.itemId != null;
    
    final currentStock = (widget.initialData?['current_stock'] as num?)?.toDouble() ?? 0;
    final parLevel = (widget.initialData?['par_level'] as num? ?? widget.initialData?['low_stock_threshold'] as num? ?? 0).toDouble();

    if (widget.initialData != null) {
      nameController.text = widget.initialData!['name'] ?? '';
      unitController.text = widget.initialData!['unit'] ?? '';
      stockController.text = currentStock.toString();
      parController.text = parLevel.toString();
    } else {
      stockController.text = '0';
      parController.text = '0';
    }
    _loadShopId();
  }
  
  Future<void> _loadShopId() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
  }

  Future<void> _showErrorDialog(String content) async {
     await showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('資訊不齊全'),
          content: Text(content),
          actions: [
            CupertinoDialogAction(
              child: const Text('確定'),
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
  }

  Future<void> _save() async {
    // 檢查名稱
    if (nameController.text.trim().isEmpty) {
      await _showErrorDialog('請填寫原料品項名稱');
      return; 
    }
    // 檢查單位
    if (unitController.text.trim().isEmpty) {
      await _showErrorDialog('請填寫單位 (如: ml, 顆, g)');
      return; 
    }
    
    // ✅ 修正：強制檢查庫存欄位 (即使是 0 也必須填寫)
    if (stockController.text.trim().isEmpty) {
      await _showErrorDialog('請填寫目前庫存數量。如果為零，請明確輸入 "0"。');
      return;
    }
    // ✅ 修正：強制檢查安全庫存欄位
    if (parController.text.trim().isEmpty) {
      await _showErrorDialog('請填寫安全庫存線。如果為零，請明確輸入 "0"。');
      return;
    }

    // 嘗試解析數值 (現在因為上面已經檢查過，這裡不會是空字串)
    final currentStock = double.tryParse(stockController.text.trim()) ?? 0.0;
    final parLevel = double.tryParse(parController.text.trim()) ?? 0.0;
    
    if (_shopId == null) {
        await _showErrorDialog('無法取得商店 ID，請重新登入');
        return;
    }

    // ... (後續儲存邏輯不變)

    final itemData = {
      'name': nameController.text.trim(),
      'unit': unitController.text.trim(),
      'unit_label': unitController.text.trim(),
      'current_stock': currentStock,
      'par_level': parLevel,
      'low_stock_threshold': parLevel,
      'category_id': widget.categoryId,
    };
    
    try {
      if (isEditing) {
        // UPDATE
        await Supabase.instance.client
            .from('inventory_items')
            .update(itemData)
            .eq('id', widget.itemId!);
      } else {
        // INSERT
        await Supabase.instance.client.from('inventory_items').insert({
          'id': const Uuid().v4(),
          'created_at': DateTime.now().toIso8601String(),
          'shop_id': _shopId,
          'sort_order': 0, 
          ...itemData,
        });
      }

      context.pop(); 
    } catch (e) {
      print('❌ 庫存品項儲存失敗: $e');
      await _showErrorDialog('儲存失敗：${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isEditing ? '編輯原料：${widget.initialData!['name']}' : '新增原料品項'),
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 修正 1：移除紅字和底線
                const Text(
                  '基本資訊', 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.systemGrey,
                    decoration: TextDecoration.none, // 移除底線
                  )
                ),
                const SizedBox(height: 8),
                CupertinoTextField(controller: nameController, placeholder: '原料品項名稱'),
                const SizedBox(height: 12),
                CupertinoTextField(controller: unitController, placeholder: '單位 (如: ml, 顆, g)'),
                const SizedBox(height: 24),
                
                // ✅ 修正 1：移除紅字和底線
                const Text(
                  '庫存與安全線', 
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.systemGrey,
                    decoration: TextDecoration.none, // 移除底線
                  )
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: stockController,
                  placeholder: '目前庫存數量',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: parController,
                  placeholder: '安全庫存線 (建議補貨數量)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: BorderedCupertinoButton(
                    text: isEditing ? '儲存更新' : '新增品項',
                    onPressed: _save,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: BorderedCupertinoButton(
                    text: '取消',
                    onPressed: () => context.pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}