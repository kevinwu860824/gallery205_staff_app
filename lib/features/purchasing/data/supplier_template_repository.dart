// lib/features/purchasing/data/supplier_template_repository.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class SupplierTemplate {
  final String? id;
  final String shopId;
  final String supplierName;
  final String? dateKeyword;
  final String? itemKeyword;
  final String? quantityKeyword;
  final String? unitPriceKeyword;
  final String? subtotalKeyword;
  final String? sampleOcrText;
  final bool isHidden;

  const SupplierTemplate({
    this.id,
    required this.shopId,
    required this.supplierName,
    this.dateKeyword,
    this.itemKeyword,
    this.quantityKeyword,
    this.unitPriceKeyword,
    this.subtotalKeyword,
    this.sampleOcrText,
    this.isHidden = false,
  });

  factory SupplierTemplate.fromJson(Map<String, dynamic> json) {
    return SupplierTemplate(
      id: json['id'] as String?,
      shopId: json['shop_id'] as String,
      supplierName: json['supplier_name'] as String,
      dateKeyword: json['date_keyword'] as String?,
      itemKeyword: json['item_keyword'] as String?,
      quantityKeyword: json['quantity_keyword'] as String?,
      unitPriceKeyword: json['unit_price_keyword'] as String?,
      subtotalKeyword: json['subtotal_keyword'] as String?,
      sampleOcrText: json['sample_ocr_text'] as String?,
      isHidden: json['is_hidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'shop_id': shopId,
        'supplier_name': supplierName,
        if (dateKeyword != null) 'date_keyword': dateKeyword,
        if (itemKeyword != null) 'item_keyword': itemKeyword,
        if (quantityKeyword != null) 'quantity_keyword': quantityKeyword,
        if (unitPriceKeyword != null) 'unit_price_keyword': unitPriceKeyword,
        if (subtotalKeyword != null) 'subtotal_keyword': subtotalKeyword,
        if (sampleOcrText != null) 'sample_ocr_text': sampleOcrText,
        'is_hidden': isHidden,
      };
}

class PurchaseItem {
  final String name;
  final num quantity;
  final num? unitPrice;
  final num subtotal;

  const PurchaseItem({
    required this.name,
    required this.quantity,
    this.unitPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        if (unitPrice != null) 'unit_price': unitPrice,
        'subtotal': subtotal,
      };
}

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

class SupplierTemplateRepository {
  final _client = Supabase.instance.client;

  Future<String?> _shopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('savedShopId');
  }

  Future<List<SupplierTemplate>> fetchAll() async {
    final shopId = await _shopId();
    if (shopId == null) return [];
    try {
      final res = await _client
          .from('supplier_templates')
          .select()
          .eq('shop_id', shopId)
          .eq('is_hidden', false)
          .order('supplier_name');
      return (res as List).map((e) => SupplierTemplate.fromJson(e)).toList();
    } catch (e) {
      debugPrint('⚠️ fetchAll supplier_templates: $e');
      return [];
    }
  }

  Future<void> upsert(SupplierTemplate template) async {
    try {
      debugPrint('🛒 upsert supplier_template: shopId=${template.shopId}, supplier=${template.supplierName}');
      debugPrint('🛒 auth.uid=${_client.auth.currentUser?.id}');
      await _client
          .from('supplier_templates')
          .upsert(template.toJson(), onConflict: 'shop_id,supplier_name');
    } catch (e) {
      debugPrint('⚠️ upsert supplier_template: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('supplier_templates').delete().eq('id', id);
    } catch (e) {
      debugPrint('⚠️ delete supplier_template: $e');
    }
  }

  Future<void> savePurchaseRecord({
    required String supplierTemplateId,
    required String shopId,
    required String? deliveryDate,
    required List<PurchaseItem> items,
    required num totalAmount,
  }) async {
    try {
      await _client.from('purchase_records').insert({
        'shop_id': shopId,
        'supplier_template_id': supplierTemplateId,
        'delivery_date': deliveryDate,
        'items': items.map((e) => e.toJson()).toList(),
        'total_amount': totalAmount,
      });
      debugPrint('✅ purchase_record saved');
    } catch (e) {
      debugPrint('⚠️ savePurchaseRecord: $e');
      rethrow;
    }
  }
}
