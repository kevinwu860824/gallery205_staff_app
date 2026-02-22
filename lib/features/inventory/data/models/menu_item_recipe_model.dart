import 'package:gallery205_staff_app/features/inventory/domain/entities/menu_item_recipe.dart';
import 'package:gallery205_staff_app/features/inventory/data/models/inventory_item_model.dart';

class MenuItemRecipeModel extends MenuItemRecipe {
  MenuItemRecipeModel({
    required String id,
    required String menuItemId,
    required String inventoryItemId,
    required double quantityRequired,
    InventoryItemModel? inventoryItem,
  }) : super(
          id: id,
          menuItemId: menuItemId,
          inventoryItemId: inventoryItemId,
          quantityRequired: quantityRequired,
          inventoryItem: inventoryItem,
        );

  factory MenuItemRecipeModel.fromJson(Map<String, dynamic> json) {
    return MenuItemRecipeModel(
      id: json['id'],
      menuItemId: json['menu_item_id'],
      inventoryItemId: json['inventory_item_id'],
      quantityRequired: (json['quantity_required'] as num).toDouble(),
      inventoryItem: json['inventory_items'] != null
          ? InventoryItemModel.fromJson(json['inventory_items'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'inventory_item_id': inventoryItemId,
      'quantity_required': quantityRequired,
    };
  }
}
