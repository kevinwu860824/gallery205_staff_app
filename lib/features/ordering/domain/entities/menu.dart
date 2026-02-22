import 'package:equatable/equatable.dart';

class MenuCategory extends Equatable {
  final String id;
  final String name;
  final int sortOrder;
  final List<String> targetPrintCategoryIds;
  final bool isVisible;
  
  const MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.targetPrintCategoryIds = const [],
    this.isVisible = true,
  });
  
  @override
  List<Object?> get props => [id, name, sortOrder, targetPrintCategoryIds, isVisible];
}

class MenuItem extends Equatable {
  final String id;
  final String name;
  final double price;
  final bool isMarketPrice;
  final int sortOrder;
  final String categoryId;
  final List<String> targetPrintCategoryIds;
  final bool isAvailable;
  final bool isVisible;
  
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.isMarketPrice,
    required this.sortOrder,
    required this.categoryId,
    this.targetPrintCategoryIds = const [],
    this.isAvailable = true,
    this.isVisible = true,
  });

  @override
  List<Object?> get props => [id, name, price, isMarketPrice, sortOrder, categoryId, targetPrintCategoryIds, isAvailable, isVisible];
}
