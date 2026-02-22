import '../entities/order_item.dart';
import '../../../../core/models/tax_profile.dart';

class OrderPrice {
  final double subtotal;
  final double serviceFee;
  final double discount;
  final double taxAmount;
  final double finalTotal;

  OrderPrice({
    required this.subtotal,
    required this.serviceFee,
    required this.discount,
    required this.taxAmount,
    required this.finalTotal,
  });
}

class OrderCalculator {
  static OrderPrice calculate({
    required List<dynamic> items, // Accepts List<OrderItem> or List<Map>
    required double serviceFeeRate,
    required double discountAmount,
    required TaxProfile taxProfile,
  }) {
    double subtotal = 0.0;
    
    // Compatible with Map (from Supabase raw) or OrderItem (from Entity)
    for (var item in items) {
      double price = 0;
      int quantity = 0;
      
      if (item is Map) {
         if (item['status'] == 'cancelled') continue;
         
         double base = (item['price'] as num).toDouble();
         // Handle modifiers in Map if present
         // Assuming item['modifiers'] or item['selected_modifiers'] exists as List
         // If not commonly available in simple map, we iterate cautiously.
         // But OrderItem entity logic standardizes this. 
         // For now, if Map, we assume `price` is base. 
         // TODO: Ensure Map logic includes modifiers if they are stored separately. 
         // Usually `unitPriceWithModifiers` handles it.
         // If item is Map, it might just be the row from DB.
         // Let's check how modifiers are stored in DB `order_items`. 
         // `selected_modifiers` jsonb column.
         
         // Simplified Map handling
         // FIX: Use original_price presence to detect "Treat" status where price is 0.
         // If treated, the entire item (including keys) should be 0.
         bool isTreated = item['original_price'] != null && base == 0;
         
         if (isTreated) {
            price = 0;
         } else {
            price = base; 
            final mods = item['modifiers'] ?? item['selected_modifiers'];
            if (mods != null && mods is List) {
                for (var m in mods) {
                   if (m is Map) {
                     price += (m['price'] as num? ?? 0).toDouble();
                   }
                }
            }
         }

         quantity = (item['quantity'] as num).toInt();
      } else if (item is OrderItem) {
         if (item.status == 'cancelled') continue;
         price = item.unitPriceWithModifiers; 
         quantity = item.quantity;
      }
      subtotal += price * quantity;
    }

    double serviceFee = subtotal * (serviceFeeRate / 100);
    double baseForTax = subtotal + serviceFee;
    double taxAmount = 0;

    if (taxProfile.rate > 0) {
      if (taxProfile.isTaxIncluded) {
        // Inclusive: Back-calculate
        // Total = Base + Tax = Base * (1 + rate)
        // Tax = Total - Base = Total - (Total / (1+rate))
        taxAmount = baseForTax - (baseForTax / (1 + (taxProfile.rate / 100)));
      } else {
        // Exclusive: Add
        taxAmount = baseForTax * (taxProfile.rate / 100);
      }
    }

    double finalTotal = 0;
    if (taxProfile.isTaxIncluded) {
      // If tax is included, it's already in subtotal+fee. 
      // But we just calculated taxAmount separately for display/invoice.
      // So final total is just (Subtotal + Fee) - Discount.
      finalTotal = subtotal + serviceFee - discountAmount;
    } else {
      // If tax is excluded, we add it.
      finalTotal = subtotal + serviceFee + taxAmount - discountAmount;
    }

    return OrderPrice(
      subtotal: subtotal,
      serviceFee: serviceFee,
      discount: discountAmount,
      taxAmount: taxAmount,
      finalTotal: finalTotal < 0 ? 0 : finalTotal,
    );
  }
}
