import 'package:gallery205_staff_app/core/events/order_events.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service responsible for "Post-Payment" financial logic.
/// Handles: E-Invoice Issuance, Customer Receipt Printing (if decoupled).
abstract class InvoiceService {
  Future<bool> onPaymentCompleted(PaymentCompletedEvent event);
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
        throw errorMsg;
      } else {
        if (response.data != null && response.data['data'] != null) {
           return response.data['data']['InvoiceNumber']?.toString();
        }
        return null;
      }
    } catch (e) {
      print("InvoiceService: Exception during ezPay invocation: $e");
      rethrow;
    }
  }

  @override
  Future<bool> onPaymentCompleted(PaymentCompletedEvent event) async {
    print("InvoiceService: Processing PaymentCompletedEvent for ${event.orderGroupId}");
    
    try {
      // Trigger ezPay E-Invoice Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'ezpay-invoice',
        body: {'order_id': event.orderGroupId},
      );

      if (response.status != 200) {
        print("InvoiceService: Error triggering ezPay function: ${response.data}");
        return false;
      } else {
        print("InvoiceService: Success triggering ezPay function: ${response.data}");
        return true;
      }
    } catch (e) {
      print("InvoiceService: Exception during ezPay invocation: $e");
      return false;
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
