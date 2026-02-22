import 'package:equatable/equatable.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';

/// Represents the operational context of an order.
/// Wraps the transaction [OrderGroup] with environmental details like tables and pax.
class OrderContext extends Equatable {
  final OrderGroup order;
  final List<String> tableNames;
  final int peopleCount;
  
  // Future fields: splitInfo, mergeInfo, etc.

  const OrderContext({
    required this.order,
    required this.tableNames,
    required this.peopleCount,
    this.staffName = '',
  });

  final String staffName;

  @override
  List<Object?> get props => [order, tableNames, peopleCount];
  
  // Helper to access order ID directly
  String get id => order.id;
}
