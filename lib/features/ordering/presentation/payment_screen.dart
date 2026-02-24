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
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart'; // NEW

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
  final TextEditingController carrierNumController = TextEditingController();
  final TextEditingController ubnController = TextEditingController();

  // Exclusivity Check
  void _onUbnChanged() {
    if (ubnController.text.length == 8 && carrierNumController.text.isNotEmpty) {
      _handleMutualExclusivity(fromUbn: true);
    }
  }

  Future<void> _handleMutualExclusivity({required bool fromUbn}) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(fromUbn ? "已設定載具" : "已輸入統編"),
        content: Text(fromUbn ? "您已輸入統編，要切換為統編開立（並移除載具）嗎？" : "您已掃描載具，要切換為客製載具（並移除統編）嗎？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("保留原本")),
          TextButton(
            onPressed: () => Navigator.pop(c, true), 
            child: Text("確定切換", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        if (fromUbn) {
          carrierNumController.clear();
        } else {
          ubnController.clear();
        }
      });
    } else {
      if (fromUbn) {
        // Re-clear UBN to keep carrier
        ubnController.removeListener(_onUbnChanged);
        ubnController.clear();
        ubnController.addListener(_onUbnChanged);
      } else {
        // Discard scanned carrier to keep UBN
        setState(() {
          carrierNumController.clear();
        });
      }
    }
  }

  Future<void> _scanCarrier() async {
    // If UBN already exists, warn before scanning or after scanning? 
    // Usually after scanning is better UX so they don't get interrupted before even seeing the camera.
    
    final String? result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (c) => _CarrierScannerOverlay(),
    );

    if (result != null && result.isNotEmpty) {
      // Validation
      final String upperResult = result.toUpperCase();
      final bool isValid = RegExp(r'^\/[A-Z0-9\.\-\+]{7}$').hasMatch(upperResult);
      
      if (!isValid) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("載具格式錯誤！應為 / 開頭且共 8 碼"))
           );
         }
         return;
      }

      setState(() {
        carrierNumController.text = upperResult;
      });

      if (ubnController.text.isNotEmpty) {
        _handleMutualExclusivity(fromUbn: false);
      }
    }
  }

  
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
    ubnController.addListener(_onUbnChanged);
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

    final ubn = ubnController.text.trim();
    if (ubn.isNotEmpty && ubn.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("統一編號格式不正確 (需為 8 碼)")));
      return;
    }

    final carrierNum = carrierNumController.text.trim();
    if (carrierNum.isNotEmpty && !RegExp(r'^\/[A-Z0-9\.\-\+]{7}$').hasMatch(carrierNum.toUpperCase())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("手機載具格式不正確 (應為 / 開頭且共 8 碼)")));
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
      
      // REFINED TAX CALCULATION (Sync with Edge Function)
      final int finalAmtInt = _totalAmount.toInt();
      final int calculatedAmt = (finalAmtInt / 1.05).round();
      final int calculatedTax = finalAmtInt - calculatedAmt;

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
          'carrier_type': carrierNum.isNotEmpty ? '0' : null, // Force '0' for mobile barcode
          'carrier_num': carrierNum.isNotEmpty ? carrierNum : null,
        }).eq('id', widget.groupKey);
      } catch (e) {
        throw "更新訂單狀態失敗: $e";
      }
      
      // 3. Fire Payment Completed Event (for other listeners if any)
      final bus = ref.read(orderEventBusProvider);
      final event = PaymentCompletedEvent(
         orderGroupId: widget.groupKey,
         finalAmount: _totalAmount,
         taxAmount: calculatedTax.toDouble(),
      );
      bus.fire(event);

      // 3.5. Issue Invoice (Synchronous/Blocking) if Tax is 5%
      bool invoiceSuccess = false;
      if (_taxProfile != null && _taxProfile!.rate == 5.0) {
        while (!invoiceSuccess) {
          invoiceSuccess = await ref.read(invoiceServiceProvider).onPaymentCompleted(event);
          
          if (!invoiceSuccess) {
             final bool? retry = await showDialog<bool>(
               context: context,
               barrierDismissible: false,
               builder: (ctx) => AlertDialog(
                 title: const Text("發票開立失敗"),
                 content: const Text("電子發票開立發生錯誤（可能是字軌用完或網路問題）。是否要重試？"),
                 actions: [
                   TextButton(
                     onPressed: () => Navigator.pop(ctx, false), 
                     child: const Text("不開票直接完成"),
                   ),
                   ElevatedButton(
                     onPressed: () => Navigator.pop(ctx, true), 
                     child: const Text("重試"),
                   ),
                 ],
               ),
             );
             
             if (retry != true) {
               // User chose to skip
               break;
             }
          }
        }
      }

      // 4. Print Receipt (Sync or Semi-sync)
      try {
        final printerService = PrinterService();
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
        final double taxToPrint = isIncluded ? 0 : calculatedTax.toDouble();
        final String? taxLabel = isIncluded ? null : "稅額 (${(_taxProfile?.rate ?? 0).toStringAsFixed(0)}%)";

        // We add a timeout to prevent hanging if a printer is unreachable
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
          payments: payments,
        ).timeout(const Duration(seconds: 10), onTimeout: () => 0);
      } catch (e) {
        debugPrint("Payment Print Error (Safe caught): $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("收據列印失敗 (可稍後補印): $e")));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("結帳完成 🎉")));
        // Safety: ensure we pop even if snackbar is still showing
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.of(context).pop(true);
        });
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
        title: const Text("選擇付款方式", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 24),
                          // 1. Top Summary
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Column(
                              children: [
                                Text("應付金額", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), fontSize: 16)),
                                const SizedBox(height: 8),
                                Text("\$${_totalAmount.toStringAsFixed(0)}", 
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 56, fontWeight: FontWeight.w600, letterSpacing: -1)
                                ),
                                if (!isComplete) ...[
                                  const SizedBox(height: 8),
                                  Text("剩餘: \$${remaining.toStringAsFixed(0)}", style: const TextStyle(color: Colors.redAccent, fontSize: 18)),
                                ] else ...[
                                  const SizedBox(height: 8),
                                  Text("找零: \$${(-remaining).toStringAsFixed(0)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 18)),
                                ]
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // 2. Added Payments List
                          if (payments.isNotEmpty)
                            Container(
                              width: double.infinity,
                              color: Colors.white.withValues(alpha: 0.05),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Column(
                                children: payments.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final p = entry.value;
                                  return Card(
                                    color: Theme.of(context).cardColor.withValues(alpha: 0.8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: EdgeInsets.only(bottom: index == payments.length - 1 ? 0 : 8),
                                    child: ListTile(
                                      leading: Icon(CupertinoIcons.money_dollar_circle, color: Theme.of(context).colorScheme.primary),
                                      title: Text("${p['method']} \$${(p['amount'] as double).toStringAsFixed(0)}"),
                                      subtitle: (p['ref'] as String).isNotEmpty ? Text("末四碼: ${p['ref']}") : null,
                                      trailing: IconButton(
                                        icon: const Icon(CupertinoIcons.minus_circle, color: Colors.redAccent),
                                        onPressed: () => _removePayment(index),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          
                          if (payments.isEmpty)
                            const SizedBox(height: 32),
                        ],
                      ),
                      
                      // 3. Bottom Controls Area
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 3.1 Invoice Section
                            if (_taxProfile != null && _taxProfile!.rate == 5.0) ...[
                              Row(
                                children: [
                                  const Icon(CupertinoIcons.doc_plaintext, size: 20, color: Colors.white),
                                  const SizedBox(width: 8),
                                  const Text("電子發票設定", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(height: 1, color: Colors.white.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 70,
                                    child: const Text("統一編號", style: TextStyle(color: Colors.white, fontSize: 15))
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: ubnController,
                                      keyboardType: TextInputType.number,
                                      maxLength: 8,
                                      style: const TextStyle(color: Colors.white, fontSize: 16),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(8),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: "8 碼統編 (選填)",
                                        hintStyle: const TextStyle(color: Colors.white70),
                                        counterText: "",
                                        isDense: true,
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.15),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 70,
                                    child: const Text("手機載具", style: TextStyle(color: Colors.white, fontSize: 15))
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: _scanCarrier,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: carrierNumController.text.isEmpty ? Colors.transparent : Colors.greenAccent.withValues(alpha: 0.8), width: 1.5),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(CupertinoIcons.camera, size: 18, color: Colors.white.withValues(alpha: 0.6)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                carrierNumController.text.isEmpty ? "點擊掃描手機條碼" : carrierNumController.text,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: carrierNumController.text.isEmpty 
                                                    ? Colors.white70
                                                    : Colors.white,
                                                  fontWeight: carrierNumController.text.isEmpty ? FontWeight.normal : FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (carrierNumController.text.isNotEmpty) ...[
                                              const Icon(CupertinoIcons.check_mark_circled_solid, size: 18, color: Colors.greenAccent),
                                              const SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    carrierNumController.clear();
                                                  });
                                                },
                                                child: Icon(CupertinoIcons.clear_thick_circled, size: 20, color: Colors.white.withValues(alpha: 0.5)),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                            
                            // 3.2 Add Payment Form
                            if (activeInput) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: availableMethods.map((m) {
                                      final isSelected = selectedMethod == m;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          label: Text(m, style: const TextStyle(fontSize: 15, color: Colors.white)),
                                          selected: isSelected,
                                          showCheckmark: isSelected,
                                          checkmarkColor: Theme.of(context).colorScheme.primary,
                                          selectedColor: Colors.transparent,
                                          backgroundColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.5)),
                                          ),
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
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: amountController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white, fontSize: 18),
                                      decoration: InputDecoration(
                                        labelText: "金額",
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Colors.white)
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Colors.white)
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Colors.white, width: 2)
                                        ),
                                        prefixText: '\$ ',
                                        prefixStyle: const TextStyle(color: Colors.white, fontSize: 18),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                        style: const TextStyle(color: Colors.white, fontSize: 18),
                                        decoration: InputDecoration(
                                          labelText: "末四碼",
                                          labelStyle: const TextStyle(color: Colors.white70),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.white)
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.white)
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Colors.white, width: 2)
                                          ),
                                          counterText: "",
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 12),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2), // Align visually with textfield height ignoring label
                                    child: InkWell(
                                      onTap: _addPayment,
                                      borderRadius: BorderRadius.circular(26),
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.15),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        child: const Icon(CupertinoIcons.add, color: Colors.white, size: 24),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                            
                            // 3.3 Final Action Button
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: isComplete && !isLoading ? _processPayment : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.2), 
                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                                  disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                  elevation: 0,
                                ),
                                child: const Text("完成結帳", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
    }
    
    bool get activeInput => _remaining > 0;
  }

class _CarrierScannerOverlay extends StatefulWidget {
  @override
  State<_CarrierScannerOverlay> createState() => _CarrierScannerOverlayState();
}

class _CarrierScannerOverlayState extends State<_CarrierScannerOverlay> {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code39, BarcodeFormat.code128],
  );

  bool _hasScanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double size = MediaQuery.of(context).size.width * 0.7;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("掃描載具條碼", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(CupertinoIcons.xmark_circle_fill, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      if (_hasScanned) return;
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                        _hasScanned = true;
                        Navigator.pop(context, barcodes.first.rawValue);
                      }
                    },
                  ),
                  // Finder Overlay
                  Container(
                    width: size,
                    height: size * 0.4,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: const Text("將載具條碼置於框內", style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
