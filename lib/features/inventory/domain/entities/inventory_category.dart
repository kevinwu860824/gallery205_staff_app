
import 'package:equatable/equatable.dart';

class InventoryCategory extends Equatable {
  final String id;
  final String name;
  final String shopId;
  final int sortOrder;

  const InventoryCategory({
    required this.id,
    required this.name,
    required this.shopId,
    required this.sortOrder,
  });

  @override
  List<Object?> get props => [id, name, shopId, sortOrder];
}
