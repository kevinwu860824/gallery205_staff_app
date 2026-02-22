import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';

class AddEditInventoryItemDialog extends StatefulWidget {
  final InventoryItem? item;
  final Function(String name, double totalUnits, double currentStock, String unitLabel, double lowStock, double cost, double contentPerUnit, String? contentUnit) onSave;

  const AddEditInventoryItemDialog({
    Key? key,
    this.item,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AddEditInventoryItemDialog> createState() => _AddEditInventoryItemDialogState();
}

class _AddEditInventoryItemDialogState extends State<AddEditInventoryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _totalUnitsCtrl;
  late TextEditingController _currentStockCtrl;
  late TextEditingController _unitLabelCtrl;
  late TextEditingController _lowStockCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _contentPerUnitCtrl;
  late TextEditingController _contentUnitCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _totalUnitsCtrl = TextEditingController(text: widget.item?.totalUnits.toString() ?? '');
    _currentStockCtrl = TextEditingController(text: widget.item?.currentStock.toString() ?? '');
    _unitLabelCtrl = TextEditingController(text: widget.item?.unitLabel ?? 'ml');
    _lowStockCtrl = TextEditingController(text: widget.item?.lowStockThreshold.toString() ?? '0');
    _costCtrl = TextEditingController(text: widget.item?.costPerUnit.toString() ?? '0');
    _contentPerUnitCtrl = TextEditingController(text: widget.item?.contentPerUnit.toString() ?? '1');
    _contentUnitCtrl = TextEditingController(text: widget.item?.contentUnit ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _totalUnitsCtrl.dispose();
    _currentStockCtrl.dispose();
    _unitLabelCtrl.dispose();
    _lowStockCtrl.dispose();
    _costCtrl.dispose();
    _contentPerUnitCtrl.dispose();
    _contentUnitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    
    return AlertDialog(
      title: Text(isEditing ? '編輯庫存品項' : '新增庫存品項'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '品項名稱 (例: A威士忌-瓶)'),
                validator: (v) => v == null || v.isEmpty ? '請輸入名稱' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalUnitsCtrl,
                      decoration: const InputDecoration(labelText: '總容量/單位 (Max HP)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      validator: (v) => v == null || v.isEmpty ? '必填' : null,
                      onChanged: (val) {
                        // Auto-fill current stock if adding new
                        if (!isEditing && _currentStockCtrl.text.isEmpty) {
                          _currentStockCtrl.text = val;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _unitLabelCtrl,
                      decoration: const InputDecoration(labelText: '單位'),
                      validator: (v) => v == null || v.isEmpty ? '必填' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                    child: TextFormField(
                      controller: _lowStockCtrl,
                      decoration: const InputDecoration(labelText: '安全庫存 (低於此數警示)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      decoration: const InputDecoration(labelText: '單位成本 (選填)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Unit Conversion
              Row(
                 children: [
                    Expanded(
                       flex: 3,
                       child: TextFormField(
                         controller: _contentPerUnitCtrl,
                         decoration: const InputDecoration(labelText: '內含容量 (例: 700)'),
                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
                       ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _contentUnitCtrl,
                        decoration: const InputDecoration(labelText: '容量單位 (例: ml)'),
                      ),
                    ),
                 ],
              ),
              if (_unitLabelCtrl.text.isNotEmpty && _contentUnitCtrl.text.isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.only(top: 4, left: 4),
                   child: Align(
                     alignment: Alignment.centerLeft,
                     child: Text(
                        "1 ${_unitLabelCtrl.text} = ${_contentPerUnitCtrl.text} ${_contentUnitCtrl.text}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                     ),
                   ),
                 ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentStockCtrl,
                decoration: const InputDecoration(
                  labelText: '目前庫存 (Current HP)',
                  hintText: '預設等於總量',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                validator: (v) => v == null || v.isEmpty ? '必填' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                    child: TextFormField(
                      controller: _lowStockCtrl,
                      decoration: const InputDecoration(labelText: '安全庫存 (低於此數警示)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      decoration: const InputDecoration(labelText: '單位成本 (選填)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final name = _nameCtrl.text;
              final total = double.parse(_totalUnitsCtrl.text);
              final current = double.parse(_currentStockCtrl.text);
              final unit = _unitLabelCtrl.text;
              final low = double.tryParse(_lowStockCtrl.text) ?? 0;
              final cost = double.tryParse(_costCtrl.text) ?? 0;
              
              final contentPerUnit = double.tryParse(_contentPerUnitCtrl.text) ?? 1;
              final contentUnit = _contentUnitCtrl.text.isEmpty ? null : _contentUnitCtrl.text;
              
              widget.onSave(name, total, current, unit, low, cost, contentPerUnit, contentUnit);
              Navigator.pop(context);
            }
          },
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
