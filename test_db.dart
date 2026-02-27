import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://olqqtmfokvnzrinmqmfy.supabase.co';
  final key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9scXF0bWZva3ZuenJpbm1xbWZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc1NTY4ODQsImV4cCI6MjA2MzEzMjg4NH0.ZsFmoAl26m4cRXKjaHHnVANgLaY8NHOB8GOsoJWa47Y';
  
  final client = SupabaseClient(url, key);
  
  // Get latest order items exactly
  final res = await client.from('order_items').select('*').order('created_at', ascending: false).limit(10);
  
  for (var item in res) {
     print("ID: \${item['id']} | Group: \${item['order_group_id']}");
     print("  Name: \${item['item_name']} | Qty: \${item['quantity']}");
     print("  Created: \${item['created_at']}");
     print("  Mods: \${item['modifiers']} | Modifiers_selected: \${item['selected_modifiers']}");
     print("  Status: \${item['status']} | Note: \${item['note']}");
     print("-----------------");
  }
}
