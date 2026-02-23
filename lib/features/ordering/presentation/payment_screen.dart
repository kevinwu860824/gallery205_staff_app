import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart';
import 'package:gallery205_staff_app/core/events/order_events.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/ordering/domain/logic/order_calculator.dart';
import 'package:gallery205_staff_app/core/models/tax_profile.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart'; // NEW

class PaymentScreen extends ConsumerStatefulWidget {
  final String groupKey;
  final double totalAmount;

  const PaymentScreen({
    super.key, 
    required this.groupKey,
    required this.totalAmount,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool isLoading = true;
  List<String> availableMethods = ['Cash']; // Fallback
  
  // Payment Entries
  List<Map<String, dynamic>> payments = [];
  
  // Billing State
  double _totalAmount = 0.0;
  double _taxAmount = 0.0;
  bool _isLoaded = false;
  
  // Form State
  String? selectedMethod;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController refController = TextEditingController(); // For Last 4
  
  // Invoice Information
  String selectedCarrierType = 'none'; // 'none', '0' (Mobile), '1' (Citizen), '2' (ezPay)
  final TextEditingController carrierNumController = TextEditingController();
  final TextEditingController ubnController = TextEditingController();
  
  // Printing Data
  List<Map<String, dynamic>> _itemDetails = [];
  List<String> _tableNames = [];
  int _pax = 0;
  DateTime? _createdAt;
  int _orderRank = 0;
  TaxProfile? _taxProfile;
  double _serviceFeeAmount = 0;
  double _discountAmount = 0;
  double _subtotal = 0;
  
  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  Future<void> _initData() async {
    await Future.wait([
      _loadPaymentSettings(),
      _loadOrderDetails(),
    ]);
    
    // Default amount to remaining
    amountController.text = _totalAmount.toStringAsFixed(0);
    if (mounted) setState(() {
      _isLoaded = true;
      isLoading = false;
    });
  }
  
  @override
  void dispose() {
    amountController.dispose();
    refController.dispose();
    carrierNumController.dispose();
    ubnController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('shop_payment_settings')
          .select('payment_methods')
          .eq('shop_id', shopId)
          .maybeSingle();

      if (res != null && res['payment_methods'] != null) {
        final List<dynamic> data = res['payment_methods'];
        final methods = data
            .where((m) => m['enabled'] == true)
            .map<String>((m) => m['name'].toString())
            .toList();
        
        if (mounted) setState(() {
          // Ensure Cash is always available and first
          final Set<String> distinctMethods = {'Cash', ...methods};
          availableMethods = distinctMethods.toList();
          if (selectedMethod == null || !availableMethods.contains(selectedMethod)) {
             selectedMethod = availableMethods.first;
          }
        });
      }
    } catch (e) {
      debugPrint("Load settings error: $e");
    }
  }

  Future<void> _loadOrderDetails() async {
     try {
       final supabase = Supabase.instance.client;
       
       // 1. Get Group Settings
       final groupRes = await supabase.from('order_groups').select().eq('id', widget.groupKey).single();
       int serviceFeeRate = groupRes['service_fee_rate'] ?? 10;
       double discount = (groupRes['discount_amount'] as num?)?.toDouble() ?? 0;
       
       // Tax Logic (Using Calculator)
       final snapshot = groupRes['tax_snapshot'];
       final taxProfile = TaxProfile(
           id: 'temp', 
           shopId: '', 
           rate: (snapshot != null) ? (snapshot['rate'] as num?)?.toDouble() ?? 0.0 : 0.0,
           isTaxIncluded: (snapshot != null) ? (snapshot['is_tax_included'] ?? true) : true,
           updatedAt: DateTime.now()
       );

       // 2. Get Active Items
       final itemsRes = await supabase.from('order_items')
           .select()
           .eq('order_group_id', widget.groupKey)
           .neq('status', 'cancelled');
           
       final price = OrderCalculator.calculate(
          items: itemsRes,
          serviceFeeRate: (groupRes['service_fee_rate'] as num?)?.toDouble() ?? 10.0,
          discountAmount: (groupRes['discount_amount'] as num?)?.toDouble() ?? 0.0,
          taxProfile: taxProfile,
       );
       
       if (mounted) setState(() {
         _totalAmount = price.finalTotal;
         _taxAmount = price.taxAmount;
         
         // Store Info for Printing
         _itemDetails = List<Map<String, dynamic>>.from(itemsRes);
         _tableNames = List<String>.from(groupRes['table_names'] ?? []);
         _pax = groupRes['pax'] ?? 0;
         _createdAt = DateTime.parse(groupRes['created_at']);
         _taxProfile = taxProfile;
         _serviceFeeAmount = price.serviceFee;
         _discountAmount = (groupRes['discount_amount'] as num?)?.toDouble() ?? 0;
         _subtotal = price.subtotal;
       });

       // Fetch Order Rank (Async)
       try {
          if (groupRes['open_id'] != null) {
            final count = await supabase.from('order_groups')
                .count(CountOption.exact)
                .eq('open_id', groupRes['open_id'])
                .lte('created_at', groupRes['created_at']);
            if (mounted) setState(() => _orderRank = count);
          }
       } catch (e) { print("Rank error: $e"); }

     } catch (e) {
       debugPrint("Load order error: $e");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("載入訂單失敗: $e")));
     }
  }

  double get _paidTotal {
    return payments.fold(0, (sum, p) => sum + (p['amount'] as double));
  }

  double get _remaining => _totalAmount - _paidTotal;

  void _addPayment() {
    final amt = double.tryParse(amountController.text);
    if (amt == null || amt <= 0) return;

    final isCash = (selectedMethod == 'Cash');
    // Allow slight float precision error? Use epsilon? 
    // Standard double comparison is fine for basic check but converting to int/cents is safer. 
    // For now check: amt > _remaining + 0.01
    
    // Only check if remaining is positive. If remaining is 0 (already paid), user shouldn't be adding payment anyway?
    // But check button state covers that.
    
    if (!isCash && amt > _remaining + 0.01) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$selectedMethod 不能大於剩餘金額 (\$${_remaining.toStringAsFixed(0)})")));
       return;
    }
    
    setState(() {
      payments.add({
        'method': selectedMethod ?? 'Cash',
        'amount': amt,
        'ref': refController.text.trim(),
      });
      
      // Reset form
      refController.clear();
      // Auto-fill next remaining
      final nextRemaining = _totalAmount - (payments.fold(0, (sum, p) => sum + (p['amount'] as double)));
      amountController.text = nextRemaining > 0 ? nextRemaining.toStringAsFixed(0) : '';
    });
  }

  void _removePayment(int index) {
    setState(() {
      payments.removeAt(index);
      final nextRemaining = _totalAmount - (payments.fold(0, (sum, p) => sum + (p['amount'] as double)));
       amountController.text = nextRemaining > 0 ? nextRemaining.toStringAsFixed(0) : '';
    });
  }

  Future<void> _processPayment() async {
    if (_remaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("尚有餘額未結清")));
      return;
    }

    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');

    try {
      // 0. Get Open ID (Shift)
      String? openId;
      try {
        if (shopId != null) {
          final statusRes = await supabase.rpc('rpc_get_current_cash_status', params: {'p_shop_id': shopId}).single();
          if (statusRes['status'] == 'OPEN') {
            openId = statusRes['open_id'] as String?;
          }
        }
      } catch (e) {
        debugPrint("Failed to fetch open_id: $e");
        // Proceed without open_id (User requested to not block)
      }

      // 1. Insert Payments
      try {
        for (var p in payments) {
          await supabase.from('order_payments').insert({
            'order_group_id': widget.groupKey,
            'payment_method': p['method'],
            'amount': p['amount'],
            'reference': (p['ref'] as String).isEmpty ? null : p['ref'],
            'open_id': openId, // Link to shift
          });
        }
      } catch (e) {
        throw "儲存付款紀錄失敗: $e";
      }
      
      // Calculate Tax Amount (Re-calculate mostly for event)
      // Ideally we should have stored it?
      // Re-fetch logic or use what we computed in _loadOrderDetails?
      // I forgot to store taxAmount as state in _loadOrderDetails.
      // I should modify _loadOrderDetails to store taxAmount in a class variable.
      
      // 2. Update Order Group Status
      try {
        final ubn = ubnController.text.trim();
        final carrierNum = carrierNumController.text.trim();
        
        await supabase.from('order_groups').update({
          'status': 'completed',
          'checkout_time': DateTime.now().toUtc().toIso8601String(),
          'payment_method': payments.map((p) => p['method']).toSet().join(','), 
          'final_amount': _totalAmount,
          'open_id': openId, // Link to shift
          'buyer_ubn': ubn.isNotEmpty ? ubn : null,
          'carrier_type': selectedCarrierType != 'none' ? selectedCarrierType : null,
          'carrier_num': carrierNum.isNotEmpty ? carrierNum : null,
        }).eq('id', widget.groupKey);
      } catch (e) {
        throw "更新訂單狀態失敗: $e";
      }
      
      // 3. Fire Payment Completed Event
      final bus = ref.read(orderEventBusProvider);
      bus.fire(PaymentCompletedEvent(
         orderGroupId: widget.groupKey,
         finalAmount: _totalAmount,
         taxAmount: _taxAmount, // Will be 0 if not captured, see below
      ));

      // 4. Print Receipt (Sync)
      try {
         final printerService = PrinterService();
         // Removed redundant single() call that causes crash if multiple printers exist
         final allSettings = await supabase.from('printer_settings').select().eq('shop_id', shopId!);
         final printerSettings = List<Map<String, dynamic>>.from(allSettings);

         final orderGroup = OrderGroup(
           id: widget.groupKey,
           status: OrderStatus.completed,
           items: [],
           shopId: shopId,
           createdAt: _createdAt,
         );
         
         final orderContext = OrderContext(
            order: orderGroup,
            tableNames: _tableNames,
            peopleCount: _pax,
            staffName: (ref.read(authStateProvider).value?.name != null && ref.read(authStateProvider).value!.name.trim().isNotEmpty) 
                  ? ref.read(authStateProvider).value!.name 
                  : (ref.read(authStateProvider).value?.email ?? ''),
         );
         
         // Tax Logic
         final bool isIncluded = _taxProfile?.isTaxIncluded ?? true;
         final double taxToPrint = isIncluded ? 0 : _taxAmount;
         final String? taxLabel = isIncluded ? null : "稅額 (${(_taxProfile?.rate ?? 0).toStringAsFixed(0)}%)";

         await printerService.printBill(
            context: orderContext,
            items: _itemDetails,
            printerSettings: printerSettings,
            subtotal: _subtotal,
            serviceFee: _serviceFeeAmount,
            discount: _discountAmount,
            finalTotal: _totalAmount,
            taxAmount: taxToPrint,
            taxLabel: taxLabel,
            orderSequenceNumber: _orderRank,
            payments: payments, // Pass the payments list!
         );
      } catch (e) {
         debugPrint("Payment Print Error: $e");
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("列印失敗: $e")));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("結帳完成 🎉")));
        context.pop(true); // Return true to signal refresh 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("結帳失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }




  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    final isComplete = remaining <= 0;
    final showCreditCardInput = selectedMethod?.toLowerCase().contains('credit') == true || 
                                selectedMethod?.toLowerCase().contains('card') == true ||
                                selectedMethod?.contains('信用卡') == true;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("選擇付款方式"),
        backgroundColor: Theme.of(context).cardColor,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // 1. Top Summary
            Container(
              padding: const EdgeInsets.all(24),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  Text("應付金額", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("\$${_totalAmount.toStringAsFixed(0)}", 
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 40, fontWeight: FontWeight.bold)
                  ),
                  if (!isComplete) ...[
                    const SizedBox(height: 8),
                    Text("剩餘: \$${remaining.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red, fontSize: 18)),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text("找零: \$${(-remaining).toStringAsFixed(0)}", style: const TextStyle(color: Colors.green, fontSize: 18)),
                  ]
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 2. Added Payments List
            Expanded(
              child: ListView.builder(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final p = payments[index];
                  return Card(
                    color: Theme.of(context).cardColor,
                    child: ListTile(
                      leading: Icon(CupertinoIcons.money_dollar_circle, color: Theme.of(context).colorScheme.primary),
                      title: Text("${p['method']} \$${(p['amount'] as double).toStringAsFixed(0)}"),
                      subtitle: (p['ref'] as String).isNotEmpty ? Text("末四碼: ${p['ref']}") : null,
                      trailing: IconButton(
                        icon: const Icon(CupertinoIcons.minus_circle, color: Colors.red),
                        onPressed: () => _removePayment(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // 3. Add Payment Form
            if (activeInput)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
              ),
              child: SafeArea(
                 top: false,
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                     // Method Selection
                     SingleChildScrollView(
                       scrollDirection: Axis.horizontal,
                       child: Row(
                         children: availableMethods.map((m) {
                           final isSelected = selectedMethod == m;
                           return Padding(
                             padding: const EdgeInsets.only(right: 8),
                             child: ChoiceChip(
                               label: Text(m),
                               selected: isSelected,
                               onSelected: (val) {
                                 setState(() {
                                    if (val) selectedMethod = m;
                                 });
                               },
                             ),
                           );
                         }).toList(),
                       ),
                     ),
                     const SizedBox(height: 16),
                     
                     Row(
                       children: [
                         Expanded(
                           child: TextField(
                             controller: amountController,
                             keyboardType: TextInputType.number,
                             decoration: InputDecoration(
                               labelText: "金額",
                               border: const OutlineInputBorder(),
                               prefixText: '\$',
                               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                             ),
                           ),
                         ),
                         if (showCreditCardInput) ...[
                           const SizedBox(width: 8),
                           Expanded(
                             child: TextField(
                               controller: refController,
                               keyboardType: TextInputType.number,
                               maxLength: 4,
                               decoration: const InputDecoration(
                                 labelText: "末四碼",
                                 border: OutlineInputBorder(),
                                 counterText: "",
                                 contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                               ),
                             ),
                           ),
                         ],
                         const SizedBox(width: 8),
                         ElevatedButton(
                           onPressed: _addPayment,
                           style: ElevatedButton.styleFrom(
                             shape: const CircleBorder(), 
                             padding: const EdgeInsets.all(16)
                           ),
                           child: const Icon(CupertinoIcons.add),
                         )
                       ],
                     ),
                   ],
                 ),
              ),
            ),
            
            // 3.5. Invoice Section
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               decoration: BoxDecoration(
                 color: Theme.of(context).cardColor,
                 border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   Row(
                     children: [
                       Text("統一編號 (選填)", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                       const SizedBox(width: 8),
                       Expanded(
                         child: TextField(
                           controller: ubnController,
                           keyboardType: TextInputType.number,
                           maxLength: 8,
                           decoration: const InputDecoration(
                             counterText: "",
                             isDense: true,
                             border: OutlineInputBorder(),
                             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                           ),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 12),
                   Row(
                     children: [
                       Text("載具設定 ", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                       const SizedBox(width: 8),
                       DropdownButton<String>(
                         value: selectedCarrierType,
                         isDense: true,
                         items: const [
                           DropdownMenuItem(value: 'none', child: Text("無")),
                           DropdownMenuItem(value: '0', child: Text("手機條碼")),
                           DropdownMenuItem(value: '1', child: Text("自然人憑證")),
                         ],
                         onChanged: (val) {
                           if (val != null) setState(() => selectedCarrierType = val);
                         },
                       ),
                       const SizedBox(width: 8),
                       if (selectedCarrierType != 'none')
                         Expanded(
                           child: TextField(
                             controller: carrierNumController,
                             decoration: const InputDecoration(
                               hintText: "例: /ABC1234",
                               isDense: true,
                               border: OutlineInputBorder(),
                               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                             ),
                           ),
                         ),
                     ],
                   )
                 ],
               ),
            ),
            
            // 4. Final Action Button (Always Visible or at least when complete)
            Container(
               padding: const EdgeInsets.all(16),
               color: Theme.of(context).cardColor, // Ensure background matches
               child: SafeArea(
                 top: false,
                 child: SizedBox(
                   height: 50,
                   width: double.infinity,
                   child: ElevatedButton(
                     onPressed: isComplete && !isLoading ? _processPayment : null,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Theme.of(context).colorScheme.primary, 
                       foregroundColor: Theme.of(context).colorScheme.onPrimary,
                     ),
                     child: const Text("完成結帳", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   ),
                 ),
               ),
            )
          ],
        ),
      ),
    );
  }
  
  bool get activeInput => _remaining > 0;
}
