import 'package:gallery205_staff_app/features/ordering/domain/entities/menu.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart';
import 'package:gallery205_staff_app/features/ordering/domain/models/table_model.dart';
import 'package:gallery205_staff_app/core/models/tax_profile.dart';

abstract class OrderingRepository {
  /// Fetches all menu categories and items for the current shop.
  Future<({List<MenuCategory> categories, List<MenuItem> items})> getMenu({bool onlyVisible = true});
  
  /// Fetches all Print Station settings (for mapping print IDs).
  Future<List<Map<String, dynamic>>> getPrintCategories();
  
  /// Fetches the rank of the order within its shift (e.g. 5th order).
  Future<int> getOrderRank(String orderGroupId);

  /// Submits a new order or updates an existing one.
  Future<void> submitOrder({
    required List<OrderItem> items,
    required List<String> tableNumbers,
    String? orderGroupId,
    bool isNewOrder,
    String? staffName,
  });

  // Stream for Print Task Updates (Failed/Success)
  Stream<void> get onPrintTaskUpdate;

  /// Fetches items already ordered for a specific order group.
  Future<List<OrderItem>> getOrderItems(String orderGroupId);

  Future<void> updateOrderItemStatus(String itemId, String status);

  /// Voids (cancels) an order item logic.
  /// Handles updating DB and printing deletion ticket.
  Future<void> voidOrderItem({
    required String orderGroupId,
    required OrderItem item,
    required String tableName, // For printing
    required int orderGroupPax, // For printing
    String? staffName,
  });

  /// Reprints a single item with "補" prefix.
  Future<void> reprintSingleItem({
    required String orderGroupId,
    required OrderItem item,
    required String tableName,
    String? staffName,
  });

  /// Updates the pax count for an order group.
  Future<void> updateOrderGroupPax(String orderGroupId, int newPax, {int adult = 0, int child = 0});

  /// Updates the note for an order group.
  Future<void> updateOrderGroupNote(String orderGroupId, String note);

  /// Clears a table (marks order as completed).
  /// If [targetGroupId] is null, use logic to find active group if possible, or error.
  Future<void> clearTable(Map<String, dynamic> tableData, {String? targetGroupId});

  /// Voids the entire order group.
  Future<void> voidOrderGroup(String orderGroupId, {String? staffName});

  /// Reprints a batch of items.
  Future<void> reprintBatch({
    required String orderGroupId,
    required List<OrderItem> items,
    required List<String> tableNames,
    required int pax,
    required int batchIndex,
    String? staffName,
  });

  /// Fetches all table areas (Legacy support).
  Future<List<AreaModel>> fetchAreas();

  /// Fetches tables in an area with status (Legacy support).
  Future<List<TableModel>> fetchTablesInArea(String areaId);

  /// Updates the print status of items.
  Future<void> updatePrintStatus(List<String> itemIds, String status);

  /// Fetches items that failed to print or are pending.
  /// Returns List of { 'item': OrderItem, 'tableName': String, 'orderGroupId': String }
  Future<List<Map<String, dynamic>>> fetchFailedPrintItems();

  /// Attempts to sync offline orders to remote DB.
  Future<void> syncOfflineOrders();

  /// Returns total count of unsynced offline orders.
  Future<int> getUnsyncedOrdersCount();

  /// Fetches the full order context (Group + Table Info).
  Future<OrderContext?> getOrderContext(String orderGroupId);

  // Tax Settings
  Future<TaxProfile> getTaxProfile();
  Future<void> saveTaxProfile(TaxProfile profile);

  Future<List<Map<String, dynamic>>> getShifts(String date);

  /// Toggles the availability status of a menu item.
  Future<void> toggleMenuItemAvailability(String itemId, bool currentStatus);

  Future<void> toggleCategoryVisibility(String categoryId, bool currentStatus);
  Future<void> toggleItemVisibility(String itemId, bool currentStatus);
}

