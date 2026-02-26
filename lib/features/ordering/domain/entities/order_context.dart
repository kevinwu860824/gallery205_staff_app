import 'package:equatable/equatable.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';

/// Represents the operational context of an order.
/// Wraps the transaction [OrderGroup] with environmental details like tables and pax.
class OrderContext extends Equatable {
  final OrderGroup order;
  final List<String> tableNames;
  final int peopleCount;
  final int paxAdult;
  final int paxChild;
  
  // Future fields: splitInfo, mergeInfo, etc.

  const OrderContext({
    required this.order,
    required this.tableNames,
    required this.peopleCount,
    this.paxAdult = 0,
    this.paxChild = 0,
    this.staffName = '',
  });

  final String staffName;

  @override
  List<Object?> get props => [order, tableNames, peopleCount, paxAdult, paxChild, staffName];
  
  // Helper to access order ID directly
  String get id => order.id;

  OrderContext copyWith({
    OrderGroup? order,
    List<String>? tableNames,
    int? peopleCount,
    int? paxAdult,
    int? paxChild,
    String? staffName,
  }) {
    return OrderContext(
      order: order ?? this.order,
      tableNames: tableNames ?? this.tableNames,
      peopleCount: peopleCount ?? this.peopleCount,
      paxAdult: paxAdult ?? this.paxAdult,
      paxChild: paxChild ?? this.paxChild,
      staffName: staffName ?? this.staffName,
    );
  }
}
