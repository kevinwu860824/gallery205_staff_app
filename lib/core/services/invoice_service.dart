import 'package:gallery205_staff_app/core/events/order_events.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service responsible for "Post-Payment" financial logic.
/// Handles: E-Invoice Issuance, Customer Receipt Printing (if decoupled).
abstract class InvoiceService {
  /// Triggers invoice issuance during checkout.
  /// Returns null if successful, or an error message if failed.
  Future<String?> onPaymentCompleted(PaymentCompletedEvent event);
  Future<String?> issueInvoice(String orderGroupId);
  Future<bool> invalidateInvoice(String orderGroupId);
}

class InvoiceServiceImpl implements InvoiceService {
  InvoiceServiceImpl();

  @override
  Future<String?> issueInvoice(String orderGroupId) async {
    print("InvoiceService: Manually issuing invoice for Order $orderGroupId");
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ezpay-invoice',
        body: {'order_id': orderGroupId},
      );

      if (response.status != 200) {
        final errorMsg = response.data['error'] ?? response.data['message'] ?? '開立失敗 (${response.status})';
        return errorMsg;
      } else {
        if (response.data != null && response.data['data'] != null) {
           return null; // Success (number is in DB now)
        }
        return null; 
      }
    } catch (e) {
      print("InvoiceService: Exception during ezPay invocation: $e");
      return e.toString();
    }
  }

  @override
  Future<String?> onPaymentCompleted(PaymentCompletedEvent event) async {
    print("InvoiceService: Processing PaymentCompletedEvent for ${event.orderGroupId}");
    
    try {
      // Trigger ezPay E-Invoice Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'ezpay-invoice',
        body: {'order_id': event.orderGroupId},
      );

      if (response.status != 200) {
        final errorMsg = response.data['error'] ?? response.data['message'] ?? '開立失敗 (${response.status})';
        print("InvoiceService: Error triggering ezPay function: $errorMsg");
        return errorMsg;
      } else {
        print("InvoiceService: Success triggering ezPay function");
        return null; // Success
      }
    } catch (e) {
      print("InvoiceService: Exception during ezPay invocation: $e");
      return e.toString();
    }
  }

  @override
  Future<bool> invalidateInvoice(String orderGroupId) async {
    print("InvoiceService: Invalidating Invoice for Order $orderGroupId");
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'ezpay-invoice-invalid',
        body: {'order_id': orderGroupId},
      );

      if (response.status != 200) {
        print("InvoiceService: Error invalidating invoice: ${response.data}");
        return false;
      } else {
        print("InvoiceService: Success invalidating invoice: ${response.data}");
        return true;
      }
    } catch (e) {
      print("InvoiceService: Exception during invoice invalidation: $e");
      return false;
    }
  }
}
