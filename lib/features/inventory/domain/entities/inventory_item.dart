class InventoryItem {
  final String id;
  final String shopId;
  final String name;
  final double totalUnits;
  final double currentStock;
  final String unitLabel;
  final double lowStockThreshold;
  final double costPerUnit;
  final double contentPerUnit;
  final String? contentUnit;
  
  // Legacy fields for backward compatibility
  final String? categoryId;
  final int sortOrder;

  // Getters for legacy compatibility
  String get unit => unitLabel;
  double get parLevel => lowStockThreshold;

  InventoryItem({
    required this.id,
    required this.shopId,
    required this.name,
    required this.currentStock,
    this.totalUnits = 1.0, 
    String? unitLabel,
    String? unit,    
    double lowStockThreshold = 0,
    double? parLevel,
    this.costPerUnit = 0,
    this.contentPerUnit = 1.0,
    this.contentUnit,
    this.categoryId,
    this.sortOrder = 0,
  }) : unitLabel = unitLabel ?? unit ?? 'ml',
       lowStockThreshold = parLevel ?? lowStockThreshold;
}
