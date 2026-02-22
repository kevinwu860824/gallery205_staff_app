import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/menu_item_recipe.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';

abstract class InventoryRepository {
  /// Fetches all inventory items for a given shop.
  /// If [categoryId] is provided, filters by category.
  Future<List<InventoryItem>> getItems(String shopId, [String? categoryId]);

  /// Adds a new inventory item.
  Future<void> addItem(InventoryItem item);

  /// Updates an existing inventory item.
  Future<void> updateItem(InventoryItem item);

  /// Deletes an inventory item.
  Future<void> deleteItem(String itemId); // Removed shopId as it's not strictly needed for delete by PK

  /// Reorders items.
  Future<void> reorderItems(List<InventoryItem> items);

  // --- Category Management (Legacy/Prep Info) ---
  Future<List<InventoryCategory>> getCategories(String shopId);
  Future<void> addCategory(String shopId, String name);
  Future<void> updateCategory(InventoryCategory category);
  Future<void> deleteCategory(String categoryId);
  Future<void> reorderCategories(List<InventoryCategory> categories);

  /// Logs a stock transaction (add/deduct) and updates current stock atomically.
  Future<void> logTransaction({
    required String shopId,
    required String inventoryItemId,
    required double changeAmount,
    required String type, // 'restock', 'sale', 'waste', 'correction', 'void_return', 'initial'
    String? relatedOrderId,
    String? note,
  });

  /// Fetches recipes for a menu item, including inventory item details.
  Future<List<MenuItemRecipe>> getRecipesForMenuItem(String menuItemId);

  /// Links an inventory item to a menu item (Create/Update).
  Future<void> saveRecipe(MenuItemRecipe recipe, String shopId);

  /// Deletes a recipe link.
  Future<void> deleteRecipe(String recipeId);

  /// Deducts stock based on recipes for the given order items.
  Future<void> deductStockForOrder(String orderId, List<OrderItem> items);

  /// Restores stock for the given order items (e.g., void).
  Future<void> restoreStockForOrder(String orderId, List<OrderItem> items, {bool isWaste = false});
}
