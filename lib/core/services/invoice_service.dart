import 'package:gallery205_staff_app/core/events/order_events.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service responsible for "Post-Payment" financial logic.
/// Handles: E-Invoice Issuance, Customer Receipt Printing (if decoupled).
abstract class InvoiceService {
  void onPaymentCompleted(PaymentCompletedEvent event);
}

class InvoiceServiceImpl implements InvoiceService {
  InvoiceServiceImpl();

  @override
  Future<void> onPaymentCompleted(PaymentCompletedEvent event) async {
    print("InvoiceService: Processing PaymentCompletedEvent for ${event.orderGroupId}");
    print("Final Amount: ${event.finalAmount}, Tax: ${event.taxAmount}");

    try {
      // Trigger ezPay E-Invoice Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'ezpay-invoice',
        body: {'order_id': event.orderGroupId},
      );

      if (response.status != 200) {
        print("InvoiceService: Error triggering ezPay function: ${response.data}");
      } else {
        print("InvoiceService: Success triggering ezPay function: ${response.data}");
      }
    } catch (e) {
      print("InvoiceService: Exception during ezPay invocation: $e");
    }

    // TODO: If Receipt Printing moves here from PrintBillScreen, implement it here.
  }
}
