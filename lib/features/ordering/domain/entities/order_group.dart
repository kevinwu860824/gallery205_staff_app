import 'package:equatable/equatable.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';

enum OrderStatus { dining, completed, cancelled }

class OrderGroup extends Equatable {
  final String id;
  // Operational fields (tableNames, peopleCount) moved to OrderContext
  final OrderStatus status;
  final List<OrderItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? shopId;
  final Map<String, dynamic>? taxSnapshot;
  final String? staffName; 
  final DateTime? checkoutTime;
  final String? ezpayInvoiceNumber;
  final String? ezpayRandomNum;
  final String? ezpayQrLeft;
  final String? ezpayQrRight;
  final double? finalAmount;
  final String? buyerUbn;
  
  const OrderGroup({
    required this.id,
    required this.status,
    required this.items,
    this.createdAt,
    this.updatedAt,
    this.shopId,
    this.taxSnapshot,
    this.staffName,
    this.checkoutTime,
    this.ezpayInvoiceNumber,
    this.ezpayRandomNum,
    this.ezpayQrLeft,
    this.ezpayQrRight,
    this.finalAmount,
    this.buyerUbn,
  });

  @override
  List<Object?> get props => [
    id, 
    status, 
    items, 
    createdAt, 
    updatedAt, 
    shopId, 
    taxSnapshot, 
    staffName,
    checkoutTime,
    ezpayInvoiceNumber,
    ezpayRandomNum,
    ezpayQrLeft,
    ezpayQrRight,
    finalAmount,
    buyerUbn,
  ];
}
