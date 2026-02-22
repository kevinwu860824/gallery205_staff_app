import 'dart:async';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';

abstract class OrderEvent {}

class OrderSubmittedEvent extends OrderEvent {
  final String orderGroupId;
  final List<OrderItem> items;
  final List<String> tableNumbers;
  final bool isNewOrder;
  final bool isOffline;
  
  OrderSubmittedEvent({
    required this.orderGroupId,
    required this.items,
    required this.tableNumbers,
    required this.isNewOrder,
    required this.isOffline,
    this.staffName,
  });

  final String? staffName;
}

class OrderVoidedEvent extends OrderEvent {
  final String orderGroupId;
  
  OrderVoidedEvent({required this.orderGroupId});
}

class PaymentCompletedEvent extends OrderEvent {
  final String orderGroupId;
  final double finalAmount;
  final double taxAmount;
  
  PaymentCompletedEvent({
    required this.orderGroupId,
    required this.finalAmount,
    required this.taxAmount,
  });
}

class OrderEventBus {
  final _controller = StreamController<OrderEvent>.broadcast();
  
  Stream<OrderEvent> get stream => _controller.stream;
  
  void fire(OrderEvent event) {
    _controller.add(event);
  }
  
  void dispose() {
    _controller.close();
  }
}
