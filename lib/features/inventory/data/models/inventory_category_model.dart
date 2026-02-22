
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_category.dart';

class InventoryCategoryModel extends InventoryCategory {
  const InventoryCategoryModel({
    required super.id,
    required super.name,
    required super.shopId,
    required super.sortOrder,
  });

  factory InventoryCategoryModel.fromJson(Map<String, dynamic> json) {
    return InventoryCategoryModel(
      id: json['id'],
      name: json['name'],
      shopId: json['shop_id'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shop_id': shopId,
      'sort_order': sortOrder,
    };
  }
}
