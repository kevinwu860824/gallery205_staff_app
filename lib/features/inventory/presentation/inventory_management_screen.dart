import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:gallery205_staff_app/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:gallery205_staff_app/features/inventory/presentation/add_edit_inventory_item_dialog.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  late InventoryRepository _repository;
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _repository = InventoryRepositoryImpl(Supabase.instance.client); // Direct instantiation
    _loadShopAndItems();
  }

  Future<void> _loadShopAndItems() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    if (_shopId == null) {
      // Handle error or redirect
      setState(() { _isLoading = false; });
      return;
    }
    await _refreshItems();
  }

  Future<void> _refreshItems() async {
    if (_shopId == null) return;
    setState(() { _isLoading = true; });
    try {
      final items = await _repository.getItems(_shopId!);
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading inventory: $e');
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _showAddEditDialog([InventoryItem? item]) async {
    if (_shopId == null) return;
    
    await showDialog(
      context: context,
      builder: (context) => AddEditInventoryItemDialog(
        item: item,
        onSave: (name, total, current, unit, low, cost, contentPerUnit, contentUnit) async {
          final newItem = InventoryItem(
            id: item?.id ?? '', // ID handled by Repo/DB for new items
            shopId: _shopId!,
            name: name,
            totalUnits: total,
            currentStock: current,
            unitLabel: unit,
            lowStockThreshold: low,
            costPerUnit: cost,
            contentPerUnit: contentPerUnit,
            contentUnit: contentUnit,
          );
          
          if (item == null) {
            await _repository.addItem(newItem);
          } else {
            await _repository.updateItem(newItem);
          }
          _refreshItems();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('庫存管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshItems,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('尚無庫存品項，請點選 + 新增'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _buildInventoryCard(item);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    final progress = (item.currentStock / item.totalUnits).clamp(0.0, 1.0);
    final isLow = item.currentStock <= item.lowStockThreshold;
    final color = isLow ? Colors.red : (progress < 0.2 ? Colors.orange : Colors.green);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showAddEditDialog(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (item.costPerUnit > 0)
                    Text('\$${item.costPerUnit}/${item.unitLabel}', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '剩餘: ${item.currentStock.toStringAsFixed(1)} / ${item.totalUnits.toStringAsFixed(1)} ${item.unitLabel}',
                    style: TextStyle(
                      color: isLow ? Colors.red : Colors.grey[800],
                      fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isLow)
                    const Chip(
                      label: Text('低庫存', style: TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
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
