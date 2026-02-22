
enum TaxType {
  vat, // Value Added Tax (e.g., 5%)
  none, // No tax
}

class TaxProfile {
  final String id;
  final String shopId;
  final double rate; // Percentage, e.g., 5.0 for 5%
  final bool isTaxIncluded; // True = 內含, False = 外加
  final DateTime updatedAt;

  const TaxProfile({
    required this.id,
    required this.shopId,
    this.rate = 0.0,
    this.isTaxIncluded = true,
    required this.updatedAt,
  });

  factory TaxProfile.fromJson(Map<String, dynamic> json) {
    return TaxProfile(
      id: json['id'],
      shopId: json['shop_id'],
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      isTaxIncluded: json['is_tax_included'] ?? true,
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'rate': rate,
      'is_tax_included': isTaxIncluded,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  TaxProfile copyWith({
    double? rate,
    bool? isTaxIncluded,
  }) {
    return TaxProfile(
      id: id,
      shopId: shopId,
      rate: rate ?? this.rate,
      isTaxIncluded: isTaxIncluded ?? this.isTaxIncluded,
      updatedAt: DateTime.now(),
    );
  }
}
