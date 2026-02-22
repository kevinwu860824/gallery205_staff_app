
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';

abstract class InventoryDataSource {
  // Categories
  Future<List<InventoryCategory>> getCategories(String shopId);
  Future<void> addCategory(InventoryCategory category);
  Future<void> updateCategory(InventoryCategory category);
  Future<void> deleteCategory(String categoryId);
  Future<void> reorderCategories(List<InventoryCategory> categories);

  // Items
  Future<List<InventoryItem>> getItems(String shopId, String categoryId);
  Future<void> addItem(InventoryItem item);
  Future<void> updateItem(InventoryItem item);
  Future<void> deleteItem(String itemId);
  Future<void> reorderItems(List<InventoryItem> items);
}
