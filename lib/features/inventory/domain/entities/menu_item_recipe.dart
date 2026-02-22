import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';

class MenuItemRecipe {
  final String id;
  final String menuItemId;
  final String inventoryItemId;
  final double quantityRequired;
  
  // Optional: associated inventory item details for UI display
  final InventoryItem? inventoryItem;

  MenuItemRecipe({
    required this.id,
    required this.menuItemId,
    required this.inventoryItemId,
    required this.quantityRequired,
    this.inventoryItem,
  });
}
