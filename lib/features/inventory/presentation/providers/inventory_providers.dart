
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery205_staff_app/features/inventory/data/datasources/inventory_remote_data_source.dart';
import 'package:gallery205_staff_app/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:gallery205_staff_app/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Dependencies ---

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final inventoryDataSourceProvider = Provider<InventoryRemoteDataSourceImpl>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return InventoryRemoteDataSourceImpl(client);
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return InventoryRepositoryImpl(client);
});

// --- State Providers ---

// 1. Current Shop ID Provider (can be moved to a global core provider later)
// simplified for now: just reads from SharedPreferences but ideally should be reactive
final currentShopIdProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('savedShopId');
});

// 2. Categories Provider
final inventoryCategoriesProvider = AsyncNotifierProvider<InventoryCategoriesNotifier, List<InventoryCategory>>(() {
  return InventoryCategoriesNotifier();
});

class InventoryCategoriesNotifier extends AsyncNotifier<List<InventoryCategory>> {
  @override
  Future<List<InventoryCategory>> build() async {
    final shopId = await ref.watch(currentShopIdProvider.future);
    if (shopId == null) return [];
    
    final repository = ref.read(inventoryRepositoryProvider);
    return repository.getCategories(shopId);
  }

  Future<void> addCategory(String name) async {
    final shopId = await ref.read(currentShopIdProvider.future);
    if (shopId == null) return;
    
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(inventoryRepositoryProvider);
      await repository.addCategory(shopId, name);
      // Refresh to get updated list
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> reorder(int oldIndex, int newIndex) async {
     final currentList = state.value;
     if (currentList == null) return;
     
     if (newIndex > oldIndex) newIndex--;
     final items = List<InventoryCategory>.from(currentList);
     final item = items.removeAt(oldIndex);
     items.insert(newIndex, item);
     
     // Optimistic update
     state = AsyncValue.data(items);
     
     try {
       final repository = ref.read(inventoryRepositoryProvider);
       await repository.reorderCategories(items);
     } catch (e) {
       // Revert on error? Or just show error
       ref.invalidateSelf(); 
     }
  }

  Future<void> deleteCategory(String id) async {
    // state = const AsyncValue.loading(); // Optional: show loading or optimistic
    try {
       final repository = ref.read(inventoryRepositoryProvider);
       await repository.deleteCategory(id);
       ref.invalidateSelf();
    } catch (e, st) {
       state = AsyncValue.error(e, st);
    }
  }
}

// 3. Items Provider (Family by Category ID)
final inventoryItemsProvider = AsyncNotifierProvider.family<InventoryItemsNotifier, List<InventoryItem>, String>(() {
  return InventoryItemsNotifier();
});

class InventoryItemsNotifier extends FamilyAsyncNotifier<List<InventoryItem>, String> {
  late String _categoryId;

  @override
  Future<List<InventoryItem>> build(String arg) async {
    _categoryId = arg;
    final shopId = await ref.watch(currentShopIdProvider.future);
    if (shopId == null) return [];
    
    final repository = ref.read(inventoryRepositoryProvider);
    return repository.getItems(shopId, _categoryId);
  }
  
  Future<void> addItem(InventoryItem item) async { // In real app, might just take DTO
     state = const AsyncValue.loading();
     try {
       final repository = ref.read(inventoryRepositoryProvider);
       await repository.addItem(item);
       ref.invalidateSelf();
     } catch (e, st) {
       state = AsyncValue.error(e, st);
     }
  }
  
  Future<void> updateItem(InventoryItem item) async {
     try {
       final repository = ref.read(inventoryRepositoryProvider);
       await repository.updateItem(item);
       ref.invalidateSelf();
     } catch (e, st) {
       state = AsyncValue.error(e, st);
     }
  }
  
  Future<void> deleteItem(String id) async {
     try {
       final repository = ref.read(inventoryRepositoryProvider);
       await repository.deleteItem(id);
       ref.invalidateSelf();
     } catch (e, st) {
       state = AsyncValue.error(e, st);
     }
  }

   Future<void> reorder(int oldIndex, int newIndex) async {
     final currentList = state.value;
     if (currentList == null) return;
     
     if (newIndex > oldIndex) newIndex--;
     final items = List<InventoryItem>.from(currentList);
     final item = items.removeAt(oldIndex);
     items.insert(newIndex, item);
     
     // Optimistic update
     state = AsyncValue.data(items);
     
     try {
       final repository = ref.read(inventoryRepositoryProvider);
       await repository.reorderItems(items);
     } catch (e) {
       ref.invalidateSelf(); 
     }
  }
}
