import 'package:gallery205_staff_app/features/ordering/domain/entities/menu.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart';

// --- Menu Models ---

class MenuCategoryModel extends MenuCategory {
  const MenuCategoryModel({
    required super.id,
    required super.name,
    required super.sortOrder,
    super.targetPrintCategoryIds,
    super.isVisible,
  });

  factory MenuCategoryModel.fromJson(Map<String, dynamic> json) {
    return MenuCategoryModel(
      id: json['id'],
      name: json['name'],
      sortOrder: json['sort_order'] ?? 0,
      targetPrintCategoryIds: json['target_print_category_ids'] != null 
          ? List<String>.from(json['target_print_category_ids']) 
          : [],
      isVisible: json['is_visible'] ?? true,
    );
  }
}

class MenuItemModel extends MenuItem {
  const MenuItemModel({
    required super.id,
    required super.name,
    required super.price,
    required super.isMarketPrice,
    required super.sortOrder,
    required super.categoryId,
    super.targetPrintCategoryIds,
    super.isAvailable,
    super.isVisible,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isMarketPrice: json['market_price'] == true,
      sortOrder: json['sort_order'] ?? 0,
      categoryId: json['category_id'],
      targetPrintCategoryIds: json['target_print_category_ids'] != null 
          ? List<String>.from(json['target_print_category_ids']) 
          : [],
      isAvailable: json['is_available'] ?? true,
      isVisible: json['is_visible'] ?? true,
    );
  }
}

// --- Order Models ---

// NOTE: We generally map OrderItem to database format in Repository/DataSource. 
// But if we need to read it back, here is the helper.
class OrderItemMapper {
  static Map<String, dynamic> toJson(OrderItem item, String orderGroupId) {
     return {
        'order_group_id': orderGroupId,
        'item_id': item.menuItemId, // This is the Menu Item ID (Foreign Key)
        'item_name': item.itemName,
        'quantity': item.quantity,
        'price': item.price,
        'note': item.note,
        'target_print_category_ids': item.targetPrintCategoryIds,
        'status': item.status,
        'modifiers': item.selectedModifiers, // Save modifiers snapshot to JSONB
        'print_status': item.printStatus,
        if (item.updatedAt != null) 'updated_at': item.updatedAt!.toIso8601String(),
        // Note: We don't save 'id' here usually, as DB generates it on insert.
        // If we were updating, we might need it, but toJson is mostly for INSERT.
      };
  }

  static OrderItem fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '', // DB Row ID
      menuItemId: json['item_id'] ?? '', // Menu Item ID
      itemName: json['item_name'] ?? json['name'] ?? 'Unknown',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] ?? 1,
      selectedModifiers: json['modifiers'] != null 
          ? List<Map<String, dynamic>>.from(json['modifiers'])
          : [],
      note: json['note'] ?? '',
      targetPrintCategoryIds: json['target_print_category_ids'] != null
          ? List<String>.from(json['target_print_category_ids'])
          : [],
      status: json['status'],
      printStatus: json['print_status'] ?? 'pending',
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }
}

class OrderContextMapper {
  /// Maps a raw DB row from `order_groups` table (joined with items preferably) to OrderContext.
  /// [groupRow] is the `order_groups` row.
  /// [items] is the list of OrderItems belonging to this group.
  static OrderContext fromJson(Map<String, dynamic> groupRow, List<OrderItem> items) {
    // 1. Construct OrderGroup (Transaction)
    final order = OrderGroup(
      id: groupRow['id'],
      status: _parseStatus(groupRow['status']),
      items: items,
      createdAt: groupRow['created_at'] != null ? DateTime.parse(groupRow['created_at']) : null,
      updatedAt: groupRow['updated_at'] != null ? DateTime.parse(groupRow['updated_at']) : null,
      shopId: groupRow['shop_id'],
      taxSnapshot: groupRow['tax_snapshot'] != null ? Map<String, dynamic>.from(groupRow['tax_snapshot']) : null,
      staffName: groupRow['staff_name'],
      checkoutTime: groupRow['checkout_time'] != null ? DateTime.parse(groupRow['checkout_time']) : null,
      ezpayInvoiceNumber: groupRow['ezpay_invoice_number'],
      ezpayRandomNum: groupRow['ezpay_random_num'],
      ezpayQrLeft: groupRow['ezpay_qr_left'],
      ezpayQrRight: groupRow['ezpay_qr_right'],
      finalAmount: (groupRow['final_amount'] as num?)?.toDouble(),
      buyerUbn: groupRow['buyer_ubn']?.toString(),
      paxAdult: groupRow['pax_adult'] ?? 0,
      paxChild: groupRow['pax_child'] ?? 0,
    );

    // 2. Construct OrderContext (Operations)
    return OrderContext(
      order: order,
      tableNames: List<String>.from(groupRow['table_names'] ?? []),
      peopleCount: groupRow['pax'] ?? 0,
      paxAdult: groupRow['pax_adult'] ?? 0,
      paxChild: groupRow['pax_child'] ?? 0,
      staffName: groupRow['staff_name'] ?? '',
    );
  }

  static OrderStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed': return OrderStatus.completed;
      case 'cancelled': return OrderStatus.cancelled;
      default: return OrderStatus.dining;
    }
  }
}
