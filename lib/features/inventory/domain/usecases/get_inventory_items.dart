
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_item.dart';
import 'package:gallery205_staff_app/features/inventory/domain/repositories/inventory_repository.dart';

class GetInventoryItems {
  final InventoryRepository repository;

  GetInventoryItems(this.repository);

  Future<List<InventoryItem>> call(String shopId, String categoryId) {
    return repository.getItems(shopId, categoryId);
  }
}
