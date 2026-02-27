void main() {
  List<Map<String, dynamic>> raw = [
    {
      "id": "c17a44e0-bac5-4ba5-8cd4-414ebb888af7",
      "price": 350.00,
      "item_name": "香菇處方簽",
      "quantity": 1,
      "created_at": "2026-02-26T20:23:49.509061+00:00"
    },
    {
      "id": "f099c3f9-2e75-4997-83cf-2b3659695028",
      "price": 350.00,
      "item_name": "香菇處方簽",
      "quantity": 1,
      "created_at": "2026-02-26T20:23:49.509061+00:00"
    },
    {
      "id": "4df94447-b18a-4817-9e78-4bc57a4e375a",
      "price": 350.00,
      "item_name": "香菇處方簽",
      "quantity": 1,
      "created_at": "2026-02-26T20:23:43.357894+00:00"
    }
  ];

  String getVisualIdentity(Map<String, dynamic> item) {
       final String name = (item['item_name'] ?? '').toString().trim();
       final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
       
       final String note = (item['note'] ?? '').toString()
           .replaceAll(RegExp(r'\| 刪除:.*'), '')
           .trim();
           
       final List<dynamic> mods = item['modifiers'] ?? item['selected_modifiers'] ?? [];
       final List<String> modNames = mods
           .map((m) => (m is Map ? m['name']?.toString() ?? '' : m.toString()).trim())
           .where((n) => n.isNotEmpty)
           .toList()
           ..sort();
       final String modStr = modNames.join('|');
       
       final bool isDeletion = item['_is_deletion_record'] == true;
       
       return "\$name|\$price|\$note|\$modStr|\$isDeletion";
  }

  List<Map<String, dynamic>> consolidated = [];
    
  for (var item in raw) {
      bool found = false;
      final String identity = getVisualIdentity(item);

      for (var c in consolidated) {
        if (identity == getVisualIdentity(c)) {
          c['quantity'] = (c['quantity'] as num).toInt() + (item['quantity'] as num).toInt();
          found = true;
          break;
        }
      }

      if (!found) {
        consolidated.add(Map<String, dynamic>.from(item));
      }
  }

  print(consolidated);
}
