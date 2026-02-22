
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// --- Common Input Decoration ---
InputDecoration buildInventoryInputDecoration({required String hintText, required BuildContext context}) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w500),
    filled: false, // Changed to false as container handles color
    border: InputBorder.none, // Remove border
    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10), // Remove padding
    isDense: true,
  );
}

class _LabeledInput extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledInput({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Text(
            "$label：",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}


// --- 3. 區域/桌位卡片元件 (_CustomTile) ---
class InventoryCustomTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool isEditing;
  final int? reorderIndex;

  const InventoryCustomTile({
    required this.title,
    required this.isEditing,
    this.onTap,
    this.onDelete,
    this.onEdit,
    this.reorderIndex,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (isEditing) {
      // 編輯模式
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 刪除按鈕
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
              onPressed: onDelete,
            ),
            const SizedBox(width: 10),
            // 名稱 (點擊編輯)
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: onEdit, 
                child: Text(
                  title,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
              ),
            ),
            // 排序手柄
            if (reorderIndex != null) // 僅在需要排序時顯示
              ReorderableDragStartListener(
                index: reorderIndex!, 
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(CupertinoIcons.bars, color: colorScheme.onSurface),
                ),
              ),
          ],
        ),
      );
    } else {
      // 正常模式
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
        onPressed: onTap, // 正常模式點擊是進入下一頁
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface, size: 20),
          ],
        ),
      );
    }
  }
}

// --- 4. 輔助 Dialog 類別 (新增/編輯 類別) ---
class InventoryAddEditDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String? initialName;
  final List<String> existingNames;

  const InventoryAddEditDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.existingNames,
    this.initialName,
  });

  @override
  State<InventoryAddEditDialog> createState() => _InventoryAddEditDialogState();
}

class _InventoryAddEditDialogState extends State<InventoryAddEditDialog> {
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
              decoration: buildInventoryInputDecoration(hintText: widget.hintText, context: context),
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

// --- 5. 輔助 Dialog 類別 (刪除確認) ---
class InventoryDeleteDialog extends StatelessWidget {
  final String title;
  final String content;

  const InventoryDeleteDialog({super.key, required this.title, required this.content});

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
        height: 183, 
        decoration: BoxDecoration(
          color: theme.cardColor, 
          borderRadius: BorderRadius.circular(25), 
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 標題
            Text(
              title, 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500)
            ),
            
            // 內容
            Text(
              content, 
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16)
            ),
            
            // 按鈕區塊
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16))
                ),
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary, 
                      foregroundColor: colorScheme.onPrimary, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(l10n.commonDelete, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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

// --- 6. 輔助 Dialog 類別 (新增/編輯 庫存品項) ---
// Returns a Map with keys: name, unit, current_stock, par_level
class InventoryAddEditItemDialog extends StatefulWidget {
  final bool isEditing;
  final String? initialName;
  final String? initialUnit;
  final double initialStock;
  final double initialPar;
  final double initialContentPerUnit;
  final String? initialContentUnit;

  const InventoryAddEditItemDialog({
    super.key,
    required this.isEditing,
    this.initialName,
    this.initialUnit,
    this.initialStock = 0,
    this.initialPar = 0,
    this.initialContentPerUnit = 1.0,
    this.initialContentUnit,
  });

  @override
  State<InventoryAddEditItemDialog> createState() => _InventoryAddEditItemDialogState();
}

class _InventoryAddEditItemDialogState extends State<InventoryAddEditItemDialog> {
  late final TextEditingController nameController;
  late final TextEditingController unitController;
  late final TextEditingController stockController;
  late final TextEditingController parController;
  late final TextEditingController contentPerUnitController;
  late final TextEditingController contentUnitController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName ?? '');
    unitController = TextEditingController(text: widget.initialUnit ?? '');
    stockController = TextEditingController(text: widget.initialStock.toString());
    parController = TextEditingController(text: widget.initialPar.toString());
    contentPerUnitController = TextEditingController(text: widget.initialContentPerUnit.toString());
    contentUnitController = TextEditingController(text: widget.initialContentUnit ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    unitController.dispose();
    stockController.dispose();
    parController.dispose();
    contentPerUnitController.dispose();
    contentUnitController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();
    final unit = unitController.text.trim();
    final stock = double.tryParse(stockController.text.trim()) ?? 0.0;
    final par = double.tryParse(parController.text.trim()) ?? 0.0;
    final contentPerUnit = double.tryParse(contentPerUnitController.text.trim()) ?? 1.0;
    final contentUnit = contentUnitController.text.trim();
    
    if (name.isEmpty || unit.isEmpty) {
      return;
    }

    final updateData = {
      'name': name,
      'unit': unit,
      'unit_label': unit,
      'current_stock': stock,
      'par_level': par,
      'low_stock_threshold': par,
      'content_per_unit': contentPerUnit,
      'content_unit': contentUnit.isEmpty ? null : contentUnit,
    };
    
    Navigator.of(context).pop(updateData);
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(
              widget.isEditing ? l10n.inventoryItemEditDialogTitle : l10n.inventoryItemAddDialogTitle,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 20),
            
            _LabeledInput(
              label: l10n.inventoryItemHintName,
              child: TextFormField(
                controller: nameController,
                decoration: buildInventoryInputDecoration(hintText: '', context: context),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            _LabeledInput(
              label: l10n.inventoryItemHintUnit,
              child: TextFormField(
                controller: unitController,
                decoration: buildInventoryInputDecoration(hintText: '', context: context),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            _LabeledInput(
              label: l10n.inventoryItemHintStock,
              child: TextFormField(
                controller: stockController,
                decoration: buildInventoryInputDecoration(hintText: '', context: context),
                keyboardType: TextInputType.number,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            _LabeledInput(
              label: l10n.inventoryItemHintPar,
              child: TextFormField(
                  controller: parController,
                  decoration: buildInventoryInputDecoration(hintText: '', context: context),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),

             _LabeledInput(
               label: "每單位含量", // Hardcoded per user request or use l10n if available, effectively 'Content'
               child: Row(
                 children: [
                   Expanded(
                     flex: 3,
                     child: TextFormField(
                       controller: contentPerUnitController,
                       decoration: buildInventoryInputDecoration(hintText: '', context: context),
                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
                       style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                     ),
                   ),
                   const Text(" "), // Spacer
                   Expanded(
                     flex: 2,
                     child: TextFormField(
                       controller: contentUnitController,
                       decoration: buildInventoryInputDecoration(hintText: '單位', context: context), // Keep hint for unit part? Or just leave blank. 
                       // User wanted "Label: ____". 
                       // Let's assume the label covers both or the second input is just auxiliary.
                       // For "Content Per Unit", usually it's "700 ml".
                       // I will make the second field just a simple input without extra label inside the row.
                       style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                     ),
                   ),
                 ],
               ),
             ),
             Padding(
               padding: const EdgeInsets.only(top: 4, left: 4),
               child: Align(
                 alignment: Alignment.centerLeft,
                 child: Text(
                    "例如: 1 瓶 (Unit) = 700 ml (Content)",
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                 ),
               ),
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
                      widget.isEditing ? l10n.commonSave : l10n.commonAdd, 
                      style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
