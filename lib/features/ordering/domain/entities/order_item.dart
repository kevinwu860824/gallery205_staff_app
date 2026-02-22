import 'package:equatable/equatable.dart';

class OrderItem extends Equatable {
  final String id; // DB Row ID (UUID)
  final String menuItemId; // Menu Item ID (Reference)
  final String itemName;
  final int quantity;
  final double price; // Base price (per unit)
  final String note;
  final List<String> targetPrintCategoryIds;
  final String status;
  
  // NEW: List of selected modifiers
  final List<Map<String, dynamic>> selectedModifiers; 
  final DateTime? updatedAt;
  final String printStatus;

  const OrderItem({
    required this.id,
    required this.menuItemId, // NEW
    required this.itemName,
    required this.quantity,
    required this.price,
    this.note = '',
    this.targetPrintCategoryIds = const [],
    this.status = 'submitted',
    this.selectedModifiers = const [],
    this.updatedAt,
    this.printStatus = 'pending',
  });

  // Calculate total price for ONE unit (Base + Modifiers)
  double get unitPriceWithModifiers {
    double modsTotal = 0;
    for (var m in selectedModifiers) {
      modsTotal += (m['price'] as num? ?? 0).toDouble();
    }
    return price + modsTotal;
  }

  // Calculate total line item price
  double get totalPrice => unitPriceWithModifiers * quantity;

  @override
  List<Object?> get props => [id, menuItemId, itemName, quantity, price, note, targetPrintCategoryIds, status, selectedModifiers, updatedAt, printStatus];
  
  OrderItem copyWith({
    String? id,
    String? menuItemId,
    String? itemName,
    int? quantity,
    double? price,
    String? note,
    List<String>? targetPrintCategoryIds,
    String? status,
    List<Map<String, dynamic>>? selectedModifiers,
    DateTime? updatedAt,
    String? printStatus,
  }) {
    return OrderItem(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      note: note ?? this.note,
      targetPrintCategoryIds: targetPrintCategoryIds ?? this.targetPrintCategoryIds,
      status: status ?? this.status,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      updatedAt: updatedAt ?? this.updatedAt,
      printStatus: printStatus ?? this.printStatus,
    );
  }
}
