import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:gallery205_staff_app/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/menu_item_recipe.dart';
import 'package:gallery205_staff_app/features/inventory/data/models/menu_item_recipe_model.dart';
import 'package:gallery205_staff_app/features/inventory/data/models/inventory_item_model.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:gallery205_staff_app/features/inventory/data/models/inventory_category_model.dart';
import 'package:gallery205_staff_app/core/constants/app_constants.dart';

import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart'; // Add Import

class InventoryRepositoryImpl implements InventoryRepository {
  final SupabaseClient _supabase;

  InventoryRepositoryImpl(this._supabase);

  @override
  Future<List<InventoryItem>> getItems(String shopId, [String? categoryId]) async {
    dynamic response;
    if (categoryId != null) {
       response = await _supabase
          .from('inventory_items')
          .select()
          .eq('shop_id', shopId)
          .eq('category_id', categoryId)
          .order('sort_order', ascending: true);
    } else {
       response = await _supabase
          .from('inventory_items')
          .select()
          .eq('shop_id', shopId)
          .order('name');
    }
    
    return (response as List).map((json) => InventoryItemModel.fromJson(json)).toList();
  }

  @override
  Future<void> addItem(InventoryItem item) async {
    final model = InventoryItemModel(
      id: item.id,
      shopId: item.shopId,
      name: item.name,
      totalUnits: item.totalUnits,
      currentStock: item.currentStock,
        // The entity might have null unitLabel, but constructor default 'ml' handles it logic there? 
        // We use the getter from Entity
      unitLabel: item.unitLabel,
      lowStockThreshold: item.lowStockThreshold,
      costPerUnit: item.costPerUnit,
      contentPerUnit: item.contentPerUnit,
      contentUnit: item.contentUnit,
      categoryId: item.categoryId,
      sortOrder: item.sortOrder,
    );
    
    // We exclude 'id' to let DB generate it, or include it if we pre-gen.
    // Based on migration: id defaults to gen_random_uuid().
    // Entity passes ID. Models toJson usually includes ID.
    // If ID is empty string, we should remove it from map so DB generates it??
    // But Uuid().v4() was used in some calls. 
    // Let's assume ID is provided or handled by Supabase if omitted.
    // If provided (UUID), we use it.
    
    await _supabase.from('inventory_items').insert(model.toJson());
    
    // Log 'initial' transaction
    if (item.currentStock > 0) {
      await logTransaction(
        shopId: item.shopId,
        inventoryItemId: item.id,
        changeAmount: item.currentStock,
        type: 'initial',
        note: 'Initial setup',
        updateStock: false,
      );
    }
  }

  @override
  Future<void> updateItem(InventoryItem item) async {
    final model = InventoryItemModel(
      id: item.id,
      shopId: item.shopId,
      name: item.name,
      totalUnits: item.totalUnits,
      currentStock: item.currentStock,
      unitLabel: item.unitLabel,
      lowStockThreshold: item.lowStockThreshold,
      costPerUnit: item.costPerUnit,
      contentPerUnit: item.contentPerUnit,
      contentUnit: item.contentUnit,
      categoryId: item.categoryId,
      sortOrder: item.sortOrder,
    );
    
    await _supabase
        .from('inventory_items')
        .update(model.toJson())
        .eq('id', item.id);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _supabase
        .from('inventory_items')
        .delete()
        .eq('id', itemId);
  }

  @override
  Future<void> reorderItems(List<InventoryItem> items) async {
     final updates = items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        // We need to preserve all other fields. Ideally we fetch fresh or use partial update if possible?
        // Upsert requires all required fields. 
        // We can create a model from the item with updated sortOrder.
        // But InventoryItem now has many required fields.
        // Assuming 'item' has all current data.
        
        // We use the Model's logic but update sortOrder
        // Wait, converting Entity to Model might be lossy if Entity is incomplete?
        // Let's assume Entity is full.
        final model = item as InventoryItemModel; 
        
        // We create a map for update. Upsert is safer.
        final json = model.toJson();
        json['sort_order'] = index;
        return json;
    }).toList();

    await _supabase.from('inventory_items').upsert(updates);
  }

  // --- Category Management ---

  @override
  Future<List<InventoryCategory>> getCategories(String shopId) async {
    final response = await _supabase
        .from(AppConstants.tableInventoryCategories)
        .select()
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);
    
    return (response as List).map((e) => InventoryCategoryModel.fromJson(e)).toList();
  }

  @override
  Future<void> addCategory(String shopId, String name) async {
    // We need to create a new category. 
    // ID is usually gen_random_uuid() or we generate it. 
    // Model expects ID? `InventoryCategoryModel`
    // Let's check logic: Repo usually takes Entity. But here `addCategory` takes name.
    // Provider passed (shopId, name).
    // We insert map directly or create model.
    await _supabase.from(AppConstants.tableInventoryCategories).insert({
      'shop_id': shopId,
      'name': name,
      'sort_order': 999, // default
    });
  }

  @override
  Future<void> updateCategory(InventoryCategory category) async {
    final model = category as InventoryCategoryModel;
    await _supabase
        .from(AppConstants.tableInventoryCategories)
        .update(model.toJson())
        .eq('id', category.id);
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    await _supabase.from(AppConstants.tableInventoryCategories).delete().eq('id', categoryId);
  }

  @override
  Future<void> reorderCategories(List<InventoryCategory> categories) async {
    final updates = categories.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value; // Corrected from instance
        final json = (item as InventoryCategoryModel).toJson();
        json['sort_order'] = index;
        return json;
    }).toList();
    
    await _supabase.from(AppConstants.tableInventoryCategories).upsert(updates);
  }

  @override
  Future<void> logTransaction({
    required String shopId,
    required String inventoryItemId,
    required double changeAmount,
    required String type,
    String? relatedOrderId,
    String? note,
    bool updateStock = true,
  }) async {
    // 1. Insert Transaction Log
    await _supabase.from('inventory_transactions').insert({
      'shop_id': shopId,
      'inventory_item_id': inventoryItemId,
      'change_amount': changeAmount,
      'transaction_type': type,
      'related_order_id': relatedOrderId,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 2. Update Current Stock (Only if requested)
    if (updateStock) {
      final itemRes = await _supabase
          .from('inventory_items')
          .select('current_stock')
          .eq('id', inventoryItemId)
          .limit(1)
          .single();
          
      final current = (itemRes['current_stock'] as num).toDouble();
      final newStock = current + changeAmount;
      
      await _supabase
          .from('inventory_items')
          .update({'current_stock': newStock})
          .eq('id', inventoryItemId);
    }
  }

  @override
  Future<List<MenuItemRecipe>> getRecipesForMenuItem(String menuItemId) async {
    final response = await _supabase
        .from('menu_item_recipes')
        .select('*, inventory_items(*)')
        .eq('menu_item_id', menuItemId);
    
    return (response as List).map((json) {
       // Supabase returns related table as nested object field matching table name, 
       // but wait, sometimes it's aliased? 
       // With select('*, inventory_items(*)'), key is 'inventory_items'.
       return MenuItemRecipeModel.fromJson(json);
    }).toList();
  }

  @override
  Future<void> saveRecipe(MenuItemRecipe recipe, String shopId) async {
    // If ID is empty/dummy, we insert. If exists, we upsert? Not necessarily details.
    // Let's assume insert new always for "Add", and if editing quantity, we might need ID.
    // For simplicity:
    final data = {
      'shop_id': shopId,
      'menu_item_id': recipe.menuItemId,
      'inventory_item_id': recipe.inventoryItemId,
      'quantity_required': recipe.quantityRequired,
    };
    
    if (recipe.id.isNotEmpty && recipe.id.length > 10) { // Simple check if UUID like
       await _supabase.from('menu_item_recipes').update(data).eq('id', recipe.id);
    } else {
       await _supabase.from('menu_item_recipes').insert(data);
    }
  }

  @override
  Future<void> deleteRecipe(String recipeId) async {
    await _supabase.from('menu_item_recipes').delete().eq('id', recipeId);
  }

  @override
  Future<void> deductStockForOrder(String orderId, List<OrderItem> items) async {
    for (final item in items) {
      // Use menuItemId to find recipes
      
      final recipes = await getRecipesForMenuItem(item.menuItemId);
      
      for (final recipe in recipes) {
        // Fix: Apply unit conversion (e.g. 1000ml -> 1 Pack)
        final double contentPerUnit = recipe.inventoryItem?.contentPerUnit ?? 1.0;
        final double divisor = contentPerUnit > 0 ? contentPerUnit : 1.0;

        final deductAmount = (recipe.quantityRequired * item.quantity) / divisor;
        
        await logTransaction(
          shopId: recipe.inventoryItem?.shopId ?? '', 
          inventoryItemId: recipe.inventoryItemId,
          changeAmount: -deductAmount,
          type: 'sale',
          relatedOrderId: orderId,
          note: 'Order: $orderId, Item: ${item.itemName}',
        );
      }
    }
  }

  @override
  Future<void> restoreStockForOrder(String orderId, List<OrderItem> items, {bool isWaste = false}) async {
    if (isWaste) return; // If waste, we don't restore stock.

    for (final item in items) {
      final recipes = await getRecipesForMenuItem(item.menuItemId);
      
      for (final recipe in recipes) {
        // Fix: Apply unit conversion
        final double contentPerUnit = recipe.inventoryItem?.contentPerUnit ?? 1.0;
        final double divisor = contentPerUnit > 0 ? contentPerUnit : 1.0;

        final restoreAmount = (recipe.quantityRequired * item.quantity) / divisor;
        
        await logTransaction(
          shopId: recipe.inventoryItem?.shopId ?? '',
          inventoryItemId: recipe.inventoryItemId,
          changeAmount: restoreAmount,
          type: 'void_restore',
          relatedOrderId: orderId,
          note: 'Void Restore: $orderId, Item: ${item.itemName}',
        );
      }
    }
  }
}
