
import 'package:gallery205_staff_app/features/inventory/domain/entities/inventory_category.dart';
import 'package:gallery205_staff_app/features/inventory/domain/repositories/inventory_repository.dart';

class GetInventoryCategories {
  final InventoryRepository repository;

  GetInventoryCategories(this.repository);

  Future<List<InventoryCategory>> call(String shopId) {
    return repository.getCategories(shopId);
  }
}
