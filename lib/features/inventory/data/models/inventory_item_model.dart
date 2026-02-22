import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';

class InventoryItemModel extends InventoryItem {
  InventoryItemModel({
    required String id,
    required String shopId,
    required String name,
    double totalUnits = 1.0,
    required double currentStock,
    String? unitLabel,
    String? unit, // Legacy
    double lowStockThreshold = 0,
    double? parLevel, // Legacy
    double costPerUnit = 0,
    double contentPerUnit = 1.0,
    String? contentUnit,
    String? categoryId,
    int sortOrder = 0,
  }) : super(
          id: id,
          shopId: shopId,
          name: name,
          totalUnits: totalUnits,
          currentStock: currentStock,
          unitLabel: unitLabel,
          unit: unit,
          lowStockThreshold: lowStockThreshold,
          parLevel: parLevel,
          costPerUnit: costPerUnit,
          contentPerUnit: contentPerUnit,
          contentUnit: contentUnit,
          categoryId: categoryId,
          sortOrder: sortOrder,
        );

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      id: json['id'],
      shopId: json['shop_id'],
      name: json['name'],
      totalUnits: (json['total_units'] as num? ?? 1).toDouble(), // Default 1 for legacy
      currentStock: (json['current_stock'] as num).toDouble(),
      unitLabel: json['unit_label'] ?? json['unit'] ?? 'ml',
      lowStockThreshold: (json['par_level'] as num? ?? json['low_stock_threshold'] as num? ?? 0).toDouble(),
      costPerUnit: (json['cost_per_unit'] as num? ?? 0).toDouble(),
      contentPerUnit: (json['content_per_unit'] as num? ?? 1.0).toDouble(),
      contentUnit: json['content_unit'],
      categoryId: json['category_id'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'total_units': totalUnits,
      'current_stock': currentStock,
      'unit_label': unitLabel,
      'unit': unitLabel, // Legacy field support
      'par_level': lowStockThreshold,
      'low_stock_threshold': lowStockThreshold, // New field support
      'cost_per_unit': costPerUnit,
      'content_per_unit': contentPerUnit,
      'content_unit': contentUnit,
      'category_id': categoryId,
      'sort_order': sortOrder,
    };
  }
}
