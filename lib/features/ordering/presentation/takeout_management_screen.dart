import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';
import 'package:gallery205_staff_app/core/widgets/dark_style_dialog.dart';

class TakeoutManagementScreen extends ConsumerStatefulWidget {
  const TakeoutManagementScreen({super.key});

  @override
  ConsumerState<TakeoutManagementScreen> createState() => _TakeoutManagementScreenState();
}

class _TakeoutManagementScreenState extends ConsumerState<TakeoutManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _takeoutOrders = [];
  bool _isTakeoutInfoRequired = false;
  String _takeoutPaymentMode = 'postpay';

  @override
  void initState() {
    super.initState();
    _loadSettingsAndOrders();
  }

  Future<void> _loadSettingsAndOrders() async {
    setState(() => _isLoading = true);
    await _fetchSettings();
    await _fetchOrders();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId != null) {
        final res = await Supabase.instance.client
            .from('shops')
            .select('is_takeout_info_required, takeout_payment_mode')
            .eq('id', shopId)
            .maybeSingle();

        if (res != null) {
          _isTakeoutInfoRequired = res['is_takeout_info_required'] ?? false;
          _takeoutPaymentMode = res['takeout_payment_mode'] ?? 'postpay';
        }
      }
    } catch (e) {
      debugPrint("Takeout settings error: $e");
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      
      if (shopId == null) return;
      
      // 取得 currentOpenId
      String? currentOpenId;
      final statusRes = await Supabase.instance.client.rpc('rpc_get_current_cash_status', params: {'p_shop_id': shopId}).maybeSingle();
      if (statusRes != null && statusRes['status'] == 'OPEN') {
        currentOpenId = statusRes['open_id'] as String?;
      }

      var query = Supabase.instance.client
          .from('order_groups')
          .select('id, created_at, status, note, payment_mode, final_amount, order_items(price, quantity, status)')
          .eq('shop_id', shopId)
          .inFilter('status', ['dining']) // 僅抓取未結帳/進行中的訂單 (或者其他代表未完成的狀態)
          .isFilter('table_names', null) // FIXME: Supabase 陣列若為空，檢查方式可能不同，這裡先取回過濾或考慮使用 eq('table_names', '{}')
          .neq('status', 'merged');

      if (currentOpenId != null) {
        query = query.eq('open_id', currentOpenId);
      }

      final res = await query.order('created_at', ascending: true);
      final allOrders = List<Map<String, dynamic>>.from(res);
      
      // 在端側進一步過濾: table_names 為空陣列或為 null
      final filtredOrders = allOrders.where((o) {
        final tables = o['table_names'];
        if (tables == null) return true;
        if (tables is List && tables.isEmpty) return true;
        return false;
      }).toList();

      if (mounted) {
         setState(() {
           _takeoutOrders = filtredOrders;
         });
      }
    } catch (e) {
      debugPrint("Takeout fetch error: $e");
    }
  }

  /// 計算金額 (未結帳時可能需要即時計算)
  double _calculateTotal(Map<String, dynamic> order) {
      double total = 0.0;
      if (order['order_items'] != null) {
          final items = order['order_items'] as List;
          for (var i in items) {
              if (i['status'] != 'cancelled') {
                  final p = (i['price'] as num?)?.toDouble() ?? 0.0;
                  final q = (i['quantity'] as num?)?.toInt() ?? 1;
                  total += p * q;
              }
          }
      }
      return total;
  }

  void _showNewTakeoutDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final infoController = TextEditingController();
    bool localPaymentModePrepay = _takeoutPaymentMode == 'prepay'; // default from settings

    showDialog(
      context: context,
      barrierDismissible: !_isTakeoutInfoRequired,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return DarkStyleDialog(
            title: "建立外帶訂單",
            contentWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isTakeoutInfoRequired)
                  Text("此分店設定必須填寫顧客資訊。", style: TextStyle(color: colorScheme.error, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: infoController,
                  placeholder: _isTakeoutInfoRequired ? "請輸入顧客稱呼 / 電話 (必填)" : "顧客稱呼 / 電話 (選填)",
                  style: TextStyle(color: colorScheme.onSurface),
                  placeholderStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.onSurface.withOpacity(0.1)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('此單支付模式：', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<bool>(
                    groupValue: localPaymentModePrepay,
                    children: {
                      true: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('先結 (點餐後結帳)', style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
                      ),
                      false: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('後結 (取餐時結帳)', style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
                      ),
                    },
                    onValueChanged: (val) {
                      if (val != null) {
                        setDialogState(() => localPaymentModePrepay = val);
                      }
                    },
                  ),
                ),
              ],
            ),
            cancelText: _isTakeoutInfoRequired ? "取消" : "略過並建立",
            onCancel: () {
              if (_isTakeoutInfoRequired) {
                context.pop(); // 直接關閉對話框
              } else {
                context.pop();
                _navigateToOrder(null, localPaymentModePrepay ? 'prepay' : 'postpay');
              }
            },
            confirmText: "繼續建立",
            onConfirm: () {
              final info = infoController.text.trim();
              if (_isTakeoutInfoRequired && info.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('為了方便核對，請輸入顧客資訊')));
                return;
              }
              context.pop();
              _navigateToOrder(info.isNotEmpty ? info : null, localPaymentModePrepay ? 'prepay' : 'postpay');
            },
          );
        },
      ),
    );
  }

  void _navigateToOrder(String? note, String paymentMode) async {
    // 進入點單頁面，傳遞外帶備註與支付模式，桌號列表為空
    final result = await context.push('/order', extra: {
      'tableNumbers': <String>[],
      'takeoutNote': note,
      'paymentMode': paymentMode,
    });
    
    // 從點單回來後，重新載入列表
    if (mounted) {
       _loadSettingsAndOrders();
    }
  }
  
  void _navigateToCheckout(String orderId, double totalAmount) async {
      final bool? result = await context.push<bool>('/payment', extra: {
        'groupKey': orderId,
        'totalAmount': totalAmount,
      });

      if (mounted) {
        // 如果結帳成功，重新抓取列表
        _loadSettingsAndOrders();
      }
  }

  Future<void> _markOrderAsCompleted(String orderId) async {
     // 取餐/叫號功能：將訂單標記為 completed
     try {
       await Supabase.instance.client
          .from('order_groups')
          .update({'status': 'completed'})
          .eq('id', orderId);

       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('單據已標記為完成 (已取餐)')));
       _loadSettingsAndOrders();
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('標記失敗: $e')));
     }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
         backgroundColor: theme.cardColor,
         leading: IconButton(
           icon: Icon(CupertinoIcons.back, color: colorScheme.onSurface),
           onPressed: () => context.pop(),
         ),
         title: Text('外帶訂單管理', style: TextStyle(color: colorScheme.onSurface)),
         actions: [
            IconButton(
               icon: Icon(CupertinoIcons.refresh, color: colorScheme.primary),
               onPressed: () => _loadSettingsAndOrders(),
            ),
            TextButton.icon(
              icon: Icon(CupertinoIcons.add, color: colorScheme.primary, size: 20),
              label: Text("新增外帶", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
              onPressed: _showNewTakeoutDialog,
            ),
            const SizedBox(width: 8),
         ],
      ),
      body: _isLoading 
         ? Center(child: CupertinoActivityIndicator(color: colorScheme.primary))
         : _takeoutOrders.isEmpty
             ? Center(child: Text("目前沒有未完成的外帶單", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5))))
             : ListView.builder(
                 padding: const EdgeInsets.all(16),
                 itemCount: _takeoutOrders.length,
                 itemBuilder: (context, index) {
                   final order = _takeoutOrders[index];
                   final orderId = order['id'] as String;
                   final note = order['note'] as String? ?? "無顧客稱呼";
                   final ca = order['created_at'] != null ? DateTime.parse(order['created_at']).toLocal() : DateTime.now();
                   final timeStr = DateFormat('HH:mm').format(ca);
                   final paymentMode = order['payment_mode'] == 'prepay' ? '先結' : '後結';
                   final total = _calculateTotal(order);

                   return Card(
                     margin: const EdgeInsets.only(bottom: 12),
                     color: theme.cardColor,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     child: Padding(
                       padding: const EdgeInsets.all(16.0),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Expanded(
                                 child: Text(
                                   note.isEmpty ? "未命名顧客" : note,
                                   style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: paymentMode == '先結' ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                                   borderRadius: BorderRadius.circular(6),
                                 ),
                                 child: Text(paymentMode, style: TextStyle(color: paymentMode == '先結' ? Colors.orange : Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                               )
                             ],
                           ),
                           const SizedBox(height: 8),
                           Row(
                             children: [
                               Icon(CupertinoIcons.clock, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                               const SizedBox(width: 4),
                               Text("開單時間: $timeStr", style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 14)),
                               const Spacer(),
                               Text("\$${total.toStringAsFixed(0)}", style: TextStyle(color: colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                             ],
                           ),
                           const Divider(height: 24),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.end,
                             children: [
                               // 如果是後結且未結帳(dining)
                               if (paymentMode == '後結' && order['status'] == 'dining')
                                 OutlinedButton(
                                   onPressed: () => _navigateToCheckout(orderId, total),
                                   style: OutlinedButton.styleFrom(
                                     foregroundColor: colorScheme.primary,
                                     side: BorderSide(color: colorScheme.primary),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                   ),
                                   child: const Text('前往結帳'),
                                 ),
                               if (paymentMode == '後結' && order['status'] == 'dining')
                                 const SizedBox(width: 8),
                               
                               // 若付款完成或者先結，且餐點已做好，可標記已取餐
                               // (先結的話，通常送完單去結帳，結帳完狀態仍是dining，只是有付款紀錄，我們提供按鈕讓原塊可收納)
                               ElevatedButton(
                                 onPressed: () => _markOrderAsCompleted(orderId),
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.green,
                                   foregroundColor: Colors.white,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                 ),
                                 child: const Text('已取餐 (完成)'),
                               ),
                             ],
                           )
                         ],
                       ),
                     ),
                   );
                 },
               )
    );
  }
}
