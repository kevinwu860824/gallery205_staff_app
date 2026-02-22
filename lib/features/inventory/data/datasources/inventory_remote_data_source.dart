
import 'package:gallery205_staff_app/core/constants/app_constants.dart';
import 'package:gallery205_staff_app/features/inventory/data/datasources/inventory_data_source.dart';
import 'package:gallery205_staff_app/features/inventory/data/models/inventory_category_model.dart';
import 'package:gallery205_staff_app/features/inventory/data/models/inventory_item_model.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryRemoteDataSourceImpl implements InventoryDataSource {
  final SupabaseClient supabaseClient;

  InventoryRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<List<InventoryCategory>> getCategories(String shopId) async {
    final response = await supabaseClient
        .from(AppConstants.tableInventoryCategories)
        .select()
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);
    
    return (response as List).map((e) => InventoryCategoryModel.fromJson(e)).toList();
  }

  @override
  Future<void> addCategory(InventoryCategory category) async {
    final model = category as InventoryCategoryModel; // Ensure it's a model
    await supabaseClient.from(AppConstants.tableInventoryCategories).insert(model.toJson());
  }

  @override
  Future<void> updateCategory(InventoryCategory category) async {
    final model = category as InventoryCategoryModel;
    await supabaseClient
        .from(AppConstants.tableInventoryCategories)
        .update(model.toJson())
        .eq('id', category.id);
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    await supabaseClient.from(AppConstants.tableInventoryCategories).delete().eq('id', categoryId);
  }

  @override
  Future<void> reorderCategories(List<InventoryCategory> categories) async {
    // Optimization: Batch Update using Upsert
    // We send the full objects with updated sort_order to ensure safe upsert
    final updates = categories.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        // Create model with updated sortOrder
        final model = InventoryCategoryModel(
            id: item.id,
            name: item.name,
            shopId: item.shopId,
            sortOrder: index
        );
        return model.toJson();
    }).toList();
    
    await supabaseClient.from(AppConstants.tableInventoryCategories).upsert(updates);
  }

  @override
  Future<List<InventoryItem>> getItems(String shopId, String categoryId) async {
    final response = await supabaseClient
        .from(AppConstants.tableInventoryItems)
        .select()
        .eq('shop_id', shopId)
        .eq('category_id', categoryId)
        .order('sort_order', ascending: true);

    return (response as List).map((e) => InventoryItemModel.fromJson(e)).toList();
  }

  @override
  Future<void> addItem(InventoryItem item) async {
    final model = item as InventoryItemModel;
    await supabaseClient.from(AppConstants.tableInventoryItems).insert(model.toJson());
  }

  @override
  Future<void> updateItem(InventoryItem item) async {
    final model = item as InventoryItemModel;
    await supabaseClient
        .from(AppConstants.tableInventoryItems)
        .update(model.toJson())
        .eq('id', item.id);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await supabaseClient.from(AppConstants.tableInventoryItems).delete().eq('id', itemId);
  }

  @override
  Future<void> reorderItems(List<InventoryItem> items) async {
     final updates = items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final model = InventoryItemModel(
            id: item.id,
            name: item.name,
            unit: item.unit,
            currentStock: item.currentStock,
            parLevel: item.parLevel,
            categoryId: item.categoryId,
            shopId: item.shopId, 
            sortOrder: index
        );
        return model.toJson();
    }).toList();

    await supabaseClient.from(AppConstants.tableInventoryItems).upsert(updates);
  }
}
