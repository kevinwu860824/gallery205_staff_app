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
  final String? buyerUbn;
  final double? finalAmount;
  final int paxAdult;
  final int paxChild;
  
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
    this.paxAdult = 0,
    this.paxChild = 0,
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
    paxAdult,
    paxChild,
  ];

  OrderGroup copyWith({
    String? id,
    OrderStatus? status,
    List<OrderItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? shopId,
    Map<String, dynamic>? taxSnapshot,
    String? staffName,
    DateTime? checkoutTime,
    String? ezpayInvoiceNumber,
    String? ezpayRandomNum,
    String? ezpayQrLeft,
    String? ezpayQrRight,
    double? finalAmount,
    String? buyerUbn,
    int? paxAdult,
    int? paxChild,
  }) {
    return OrderGroup(
      id: id ?? this.id,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      shopId: shopId ?? this.shopId,
      taxSnapshot: taxSnapshot ?? this.taxSnapshot,
      staffName: staffName ?? this.staffName,
      checkoutTime: checkoutTime ?? this.checkoutTime,
      ezpayInvoiceNumber: ezpayInvoiceNumber ?? this.ezpayInvoiceNumber,
      ezpayRandomNum: ezpayRandomNum ?? this.ezpayRandomNum,
      ezpayQrLeft: ezpayQrLeft ?? this.ezpayQrLeft,
      ezpayQrRight: ezpayQrRight ?? this.ezpayQrRight,
      finalAmount: finalAmount ?? this.finalAmount,
      buyerUbn: buyerUbn ?? this.buyerUbn,
      paxAdult: paxAdult ?? this.paxAdult,
      paxChild: paxChild ?? this.paxChild,
    );
  }
}
