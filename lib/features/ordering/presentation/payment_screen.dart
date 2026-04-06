import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/core/services/hub_client.dart';
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
import 'package:dropdown_button2/dropdown_button2.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/domain/ordering_constants.dart';


class PaymentScreen extends ConsumerStatefulWidget {
  final String groupKey;
  final double totalAmount;
  final bool embedded;
  final VoidCallback? onClose;
  final VoidCallback? onPaymentComplete;

  const PaymentScreen({
    super.key,
    required this.groupKey,
    required this.totalAmount,
    this.embedded = false,
    this.onClose,
    this.onPaymentComplete,
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

  String? _shopName;
  String? _shopAddress;
  String? _shopPhone;
  String? _sellerUbn;
  String? _shopCode;


  // Manual Adjustments
  bool isServiceFeeEnabled = true;
  int serviceFeeRate = 10;
  double manualDiscount = 0.0;
  final TextEditingController discountController = TextEditingController();
  final List<int> serviceFeeOptions = [0, 5, 10, 15];


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
    discountController.dispose();
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

      // Fetch Shop Info
      final shopRes = await Supabase.instance.client
          .from('shops')
          .select('name, address, phone, code, uniform_id')
          .eq('id', shopId)
          .maybeSingle();
      if (shopRes != null) {
        if (mounted) setState(() {
          _shopName = shopRes['name'];
          _shopAddress = shopRes['address'];
          _shopPhone = shopRes['phone'];
          _shopCode = shopRes['code'];
          _sellerUbn = shopRes['uniform_id'];
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
        
        final int initialRate = groupRes['service_fee_rate'] ?? 10;
        final double initialDiscount = (groupRes['discount_amount'] as num?)?.toDouble() ?? 0;
        
        if (!_isLoaded) {
           isServiceFeeEnabled = initialRate > 0;
           serviceFeeRate = initialRate > 0 ? initialRate : 10;
           manualDiscount = initialDiscount;
           discountController.text = manualDiscount != 0 ? manualDiscount.toStringAsFixed(0) : '';
        }

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
            .neq('status', OrderingConstants.orderStatusCancelled);
        
        _itemDetails = List<Map<String, dynamic>>.from(itemsRes);
        _taxProfile = taxProfile;
        _tableNames = List<String>.from(groupRes['table_names'] ?? []);
        _pax = groupRes['pax'] ?? 0;
        _createdAt = DateTime.parse(groupRes['created_at']);
        
        _calculateTotals();

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

  void _calculateTotals() {
    if (_taxProfile == null) return;
    
    final price = OrderCalculator.calculate(
      items: _itemDetails,
      serviceFeeRate: isServiceFeeEnabled ? serviceFeeRate.toDouble() : 0.0,
      discountAmount: manualDiscount,
      taxProfile: _taxProfile!,
    );

    if (mounted) {
      setState(() {
        _totalAmount = price.finalTotal;
        _taxAmount = price.taxAmount;
        _serviceFeeAmount = price.serviceFee;
        _discountAmount = manualDiscount;
        _subtotal = price.subtotal;
        
        // Update remaining amount in form
        final rem = _totalAmount - _paidTotal;
        amountController.text = rem > 0 ? rem.toStringAsFixed(0) : '';
      });
    }
  }

  // Printing Helper for "結帳確認單"
  Future<void> _reprintBill() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    final printerService = PrinterService();

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) return;

      final printerRes = await supabase.from('printer_settings').select().eq('shop_id', shopId);
      final printerSettings = List<Map<String, dynamic>>.from(printerRes);

      final orderGroup = OrderGroup(
        id: widget.groupKey,
        status: OrderStatus.dining,
        items: [],
        createdAt: _createdAt ?? DateTime.now(),
        shopId: shopId,
      );

      final orderRank = await ref.read(orderingRepositoryProvider).getOrderRank(widget.groupKey);

      final orderContext = OrderContext(
        order: orderGroup,
        tableNames: _tableNames,
        peopleCount: _pax,
        staffName: (ref.read(authStateProvider).value?.name != null && ref.read(authStateProvider).value!.name.trim().isNotEmpty)
            ? ref.read(authStateProvider).value!.name
            : (ref.read(authStateProvider).value?.email ?? ''),
      );

      final bool isIncluded = _taxProfile?.isTaxIncluded ?? true;
      final double taxToPrint = isIncluded ? 0 : _taxAmount;
      final String? taxLabel = isIncluded ? null : "稅額 (${(_taxProfile?.rate ?? 0).toStringAsFixed(0)}%)";

      final int printCount = await printerService.printBill(
        context: orderContext,
        items: _itemDetails,
        printerSettings: printerSettings,
        subtotal: _subtotal,
        serviceFee: _serviceFeeAmount,
        discount: manualDiscount,
        finalTotal: _totalAmount,
        taxAmount: taxToPrint,
        taxLabel: taxLabel,
        orderSequenceNumber: orderRank,
      );

      if (mounted) {
        if (printCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🖨️ 已補印 $printCount 台印表機")));
        } else if (printCount == -1) {
           _showNoPrinterDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("列印失敗或未設定收據印表機")));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("列印錯誤: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  
  void _showNoPrinterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("未設定結帳印表機"),
        content: const Text("系統找不到已設為「收據/結帳」的印表機。\n請至 設定 > 印表機設定，編輯任一印表機並開啟「設為收據印表機」開關。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("好")
          ),
          TextButton(
             onPressed: () {
               Navigator.pop(context);
               context.push('/printerSettings'); 
             },
             child: const Text("前往設定"),
          )
        ],
      )
    );
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

      // REFINED TAX CALCULATION
      final int finalAmtInt = _totalAmount.toInt();
      final int calculatedAmt = (finalAmtInt / 1.05).floor();
      final int calculatedTax = finalAmtInt - calculatedAmt;

      // 0.5 ~ 2. Supabase 結帳寫入（Hub 離線時 fallback 存本地）
      bool savedToHubOffline = false;
      try {
        // 0.5. Hub 模式：結帳前先同步訂單到 Supabase
        if (HubClient().isHubAvailable) {
          await _syncPendingOrderToSupabase(supabase);
        }

        // 1. Insert Payments
        for (var p in payments) {
          await supabase.from('order_payments').insert({
            'order_group_id': widget.groupKey,
            'payment_method': p['method'],
            'amount': p['amount'],
            'reference': (p['ref'] as String).isEmpty ? null : p['ref'],
            'open_id': openId,
          });
        }

        // 2. Update Order Group Status
        final ubn = ubnController.text.trim();
        final carrierNum = carrierNumController.text.trim();
        await supabase.from('order_groups').update({
          'status': OrderingConstants.orderStatusCompleted,
          'checkout_time': DateTime.now().toUtc().toIso8601String(),
          'payment_method': payments.map((p) => p['method']).toSet().join(','),
          'final_amount': _totalAmount,
          'service_fee_rate': isServiceFeeEnabled ? serviceFeeRate : 0,
          'discount_amount': manualDiscount,
          'open_id': openId,
          'buyer_ubn': ubn.isNotEmpty ? ubn : null,
          'carrier_type': carrierNum.isNotEmpty ? '0' : null,
          'carrier_num': carrierNum.isNotEmpty ? carrierNum : null,
        }).eq('id', widget.groupKey);
      } catch (e) {
        // Supabase 不可用時，若 Hub 在線則存本地，稍後同步
        if (HubClient().isHubAvailable) {
          debugPrint('⚠️ Supabase unavailable, saving checkout to Hub: $e');
          await _saveCheckoutToHub(openId);
          savedToHubOffline = true;
        } else {
          throw "結帳失敗（無法連線至伺服器）: $e";
        }
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
      String? invoiceError;
      if (!savedToHubOffline && _taxProfile != null && _taxProfile!.rate == 5.0) {
        bool isResolved = false;
        while (!isResolved) {
          invoiceError = await ref.read(invoiceServiceProvider).onPaymentCompleted(event);
          
          if (invoiceError != null) {
             final bool? retry = await showDialog<bool>(
               context: context,
               barrierDismissible: false,
               builder: (ctx) => AlertDialog(
                 title: const Text("發票開立失敗"),
                 content: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text("電子發票開立發生錯誤。"),
                     const SizedBox(height: 12),
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: Colors.red.withValues(alpha: 0.1),
                         borderRadius: BorderRadius.circular(4),
                         border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                       ),
                       child: Text(
                         invoiceError!,
                         style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontFamily: 'monospace'),
                       ),
                     ),
                     const SizedBox(height: 12),
                     const Text("是否要重試？"),
                   ],
                 ),
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
               isResolved = true; // User skip
             }
          } else {
            isResolved = true; // Success
          }
        }
      }

      // 3.6. Print Invoice Proof (if issued)
      if (!savedToHubOffline && _taxProfile != null && _taxProfile!.rate == 5.0 && invoiceError == null) {
        try {
          final updatedGroup = await supabase.from('order_groups').select().eq('id', widget.groupKey).single();
          final printerService = PrinterService();
          final allSettings = await supabase.from('printer_settings').select().eq('shop_id', shopId!);
          final printerSettings = List<Map<String, dynamic>>.from(allSettings);

          final orderForProof = OrderGroup(
             id: updatedGroup['id'],
             status: OrderStatus.completed,
             items: [],
             shopId: shopId,
             createdAt: _createdAt,
             checkoutTime: updatedGroup['checkout_time'] != null ? DateTime.parse(updatedGroup['checkout_time']) : null,
             ezpayInvoiceNumber: updatedGroup['ezpay_invoice_number'],
             ezpayRandomNum: updatedGroup['ezpay_random_num'],
             ezpayQrLeft: updatedGroup['ezpay_qr_left'],
             ezpayQrRight: updatedGroup['ezpay_qr_right'],
             finalAmount: (updatedGroup['final_amount'] as num?)?.toDouble(),
             buyerUbn: updatedGroup['buyer_ubn']?.toString(),
          );

          final isB2B = updatedGroup['buyer_ubn'] != null && updatedGroup['buyer_ubn'].toString().length == 8;
          final hasCarrier = updatedGroup['carrier_num'] != null && updatedGroup['carrier_num'].toString().trim().isNotEmpty;
          
          // Taiwan E-Invoice Rule: If B2B -> ALWAYS Print. If Carrier present (and no UBN) -> DO NOT Print Proof.
          final shouldPrintInvoiceProof = isB2B || !hasCarrier;

          if (shouldPrintInvoiceProof) {
            await printerService.printInvoiceProof(
               order: orderForProof,
               printerSettings: printerSettings,
               shopName: _shopName ?? 'Store',
               sellerUbn: _sellerUbn ?? '',
               shopCode: _shopCode,
               address: _shopAddress,
               phone: _shopPhone,
               itemDetails: _itemDetails,
               shouldCut: true, 
            ).timeout(const Duration(seconds: 30), onTimeout: () => 0);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("電子發票已開立並印出 🎉")));
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("電子發票已開立，存入載具 🎉")));
            }
          }
          
          // REMOVED EARLY RETURN: 
          // We must let the function continue to Section 4 (printBill) 
          // so B2C and Carrier users still get their itemized transaction receipt!

          // --- CRITICAL FIX: PRINTER BUFFER OVERLAP ---
          // B2B invoices are long. If we immediately blast the printer with the receipt (printBill)
          // while it's still physically printing the invoice, the thermal printer's image buffer 
          // or TCP stack can get corrupted, causing severe printing misalignment (錯位).
          // We MUST enforce a mandatory "cooling-off" period to let the printer finish the first job.
          if (shouldPrintInvoiceProof) {
             debugPrint("Cooling off for 3 seconds before printing receipt...");
             await Future.delayed(const Duration(seconds: 3));
          }

        } catch (e) {
          debugPrint("Invoice Proof Print Error: $e");
        }
      }

      // 4. Print Receipt (Sync or Semi-sync)
      bool receiptPrintFailed = false;
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
          context: OrderContext(
            order: orderContext.order,
            tableNames: orderContext.tableNames,
            peopleCount: orderContext.peopleCount,
            paxAdult: orderContext.order.paxAdult,
            paxChild: orderContext.order.paxChild,
            staffName: orderContext.staffName,
          ),
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
        receiptPrintFailed = true;
      }

      // 追蹤未完成列印（Scenario A / B1 / B2）
      final bool needsInvoice = !savedToHubOffline
          && (_taxProfile?.rate == 5.0)
          && (invoiceError != null);
      if (savedToHubOffline || receiptPrintFailed || needsInvoice) {
        try {
          await ref.read(orderingRepositoryProvider).addPendingReceiptPrint({
            'id': widget.groupKey,
            'table_names': jsonEncode(_tableNames),
            'final_amount': _totalAmount,
            'checkout_time': DateTime.now().toIso8601String(),
            'needs_invoice': (savedToHubOffline && (_taxProfile?.rate == 5.0)) || needsInvoice ? 1 : 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (trackErr) {
          debugPrint('⚠️ addPendingReceiptPrint failed: $trackErr');
        }
      }

      if (mounted) {
        String msg;
        if (savedToHubOffline) {
          msg = '結帳已暫存，連線後自動同步 📥';
        } else if (receiptPrintFailed) {
          msg = '結帳完成，但收據列印失敗，可至補印區補印 🖨️';
        } else {
          msg = '結帳完成 🎉';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          if (widget.onPaymentComplete != null) {
            widget.onPaymentComplete!();
          } else {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("結帳失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }




  /// Hub 模式：將 Hub 本地 SQLite 的訂單資料同步到 Supabase
  /// 在結帳寫入 order_payments / 更新 order_groups 之前呼叫，確保 FK 存在
  Future<void> _syncPendingOrderToSupabase(SupabaseClient supabase) async {
    final data = await HubClient().get('/orders/${widget.groupKey}');
    if (data == null) throw '無法從主機取得訂單資料，請確認主機連線正常';

    final group = data['order_group'] as Map<String, dynamic>?;
    final rawItems = data['order_items'] as List?;
    if (group == null) throw '主機回傳訂單資料格式錯誤';

    // 解析 table_names（Hub 以 JSON string 儲存，Supabase 需要 List<String>）
    List<String> tableNames = [];
    final rawTableNames = group['table_names'];
    if (rawTableNames is String) {
      tableNames = List<String>.from(jsonDecode(rawTableNames) as List);
    } else if (rawTableNames is List) {
      tableNames = List<String>.from(rawTableNames);
    }

    // 解析 tax_snapshot（Hub 以 JSON string 儲存，Supabase 需要 Map）
    Map<String, dynamic>? taxSnapshot;
    final rawTax = group['tax_snapshot'];
    if (rawTax is String && rawTax.isNotEmpty) {
      taxSnapshot = jsonDecode(rawTax) as Map<String, dynamic>;
    } else if (rawTax is Map) {
      taxSnapshot = Map<String, dynamic>.from(rawTax);
    }

    // Upsert order_group（含 id，確保冪等）
    await supabase.from('order_groups').upsert({
      'id': group['id'],
      'shop_id': group['shop_id'],
      'table_names': tableNames,
      'pax_adult': group['pax_adult'] ?? 0,
      'staff_name': group['staff_name'],
      'tax_snapshot': taxSnapshot,
      'color_index': group['color_index'] ?? 0,
      'created_at': group['created_at'],
      'status': OrderingConstants.orderStatusDining,
    });

    // Upsert order_items（欄位名稱已對齊 Supabase，只需 jsonDecode）
    if (rawItems != null && rawItems.isNotEmpty) {
      for (final raw in rawItems.cast<Map<String, dynamic>>()) {
        // modifiers：JSON string → List
        List<dynamic> modifiers = [];
        final rawMod = raw['modifiers'];
        if (rawMod is String && rawMod.isNotEmpty) {
          modifiers = jsonDecode(rawMod) as List;
        }

        // target_print_category_ids：JSON string → List<String>
        List<String> printCatIds = [];
        final rawCat = raw['target_print_category_ids'];
        if (rawCat is String && rawCat.isNotEmpty) {
          printCatIds = List<String>.from(jsonDecode(rawCat) as List);
        } else if (rawCat is List) {
          printCatIds = List<String>.from(rawCat);
        }

        await supabase.from('order_items').upsert({
          'id': raw['id'],
          'order_group_id': raw['order_group_id'],
          'item_id': raw['item_id'],
          'item_name': raw['item_name'],
          'quantity': raw['quantity'],
          'price': raw['price'],
          'modifiers': modifiers,
          'note': raw['note'] ?? '',
          'target_print_category_ids': printCatIds,
          'created_at': raw['created_at'],
          'status': raw['status'] ?? 'new',
        });
      }
    }

    debugPrint('✅ Hub order synced to Supabase: ${widget.groupKey}');
  }

  /// Hub 離線結帳：將結帳資料存入 Hub 本地 pending_checkouts，稍後由 syncOfflineOrders 同步
  Future<void> _saveCheckoutToHub(String? openId) async {
    final ubn = ubnController.text.trim();
    final carrierNum = carrierNumController.text.trim();
    await HubClient().post('/checkout', {
      'checkout': {
        'id': const Uuid().v4(),
        'order_group_id': widget.groupKey,
        'payment_method': payments.map((p) => p['method']).toSet().join(','),
        'final_amount': _totalAmount,
        'discount_amount': manualDiscount,
        'service_fee_rate': isServiceFeeEnabled ? serviceFeeRate.toDouble() : 0.0,
        'buyer_ubn': ubn.isNotEmpty ? ubn : null,
        'carrier_num': carrierNum.isNotEmpty ? carrierNum : null,
        'carrier_type': carrierNum.isNotEmpty ? '0' : null,
        'checkout_time': DateTime.now().toIso8601String(),
        'payments_json': jsonEncode(payments),
        'open_id': openId,
        'is_synced': 0,
      },
      'table_name': _tableNames.isNotEmpty ? _tableNames.first : null,
    });
    debugPrint('📥 Checkout saved to Hub offline: ${widget.groupKey}');
  }

  Widget _buildBody(BuildContext context) {
    final remaining = _remaining;
    final isComplete = remaining <= 0;
    final showCreditCardInput = selectedMethod?.toLowerCase().contains('credit') == true ||
                                selectedMethod?.toLowerCase().contains('card') == true ||
                                selectedMethod?.contains('信用卡') == true;
    return GestureDetector(
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
                          SizedBox(height: widget.embedded ? 8 : MediaQuery.of(context).padding.top + kToolbarHeight + 24),
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

                          // 1.5 Adjustments (Service Fee & Discount)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: isServiceFeeEnabled, 
                                      activeColor: Theme.of(context).colorScheme.primary,
                                      onChanged: (v) => setState(() {
                                        isServiceFeeEnabled = v ?? true;
                                        _calculateTotals();
                                      }),
                                    ),
                                    const Text("服務費", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    if (isServiceFeeEnabled)
                                      DropdownButtonHideUnderline(
                                        child: DropdownButton2<int>(
                                          value: serviceFeeRate,
                                          items: serviceFeeOptions.map((rate) => DropdownMenuItem(
                                            value: rate,
                                            child: Text("$rate%", style: const TextStyle(fontSize: 14)),
                                          )).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                serviceFeeRate = val;
                                                _calculateTotals();
                                              });
                                            }
                                          },
                                          buttonStyleData: ButtonStyleData(
                                            height: 36,
                                            width: 80,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Theme.of(context).dividerColor),
                                              color: Theme.of(context).cardColor,
                                            ),
                                          ),
                                          menuItemStyleData: const MenuItemStyleData(height: 36),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 12),
                                    const Icon(CupertinoIcons.scissors, size: 20),
                                    const SizedBox(width: 12),
                                    const Text("折讓金額", style: TextStyle(fontSize: 16)),
                                    const Spacer(),
                                    SizedBox(
                                      width: 80,
                                      height: 36,
                                      child: TextField(
                                        controller: discountController,
                                        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 20),
                                        decoration: InputDecoration(
                                          hintText: "0",
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          isDense: true,
                                        ),
                                        onChanged: (v) {
                                          setState(() {
                                            manualDiscount = double.tryParse(v) ?? 0.0;
                                            _calculateTotals();
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),

                          
                          // 2. Added Payments List
                          if (payments.isNotEmpty)
                            Container(
                              width: double.infinity,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
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
                                  Icon(CupertinoIcons.doc_plaintext, size: 20, color: Theme.of(context).colorScheme.onSurface),
                                  const SizedBox(width: 8),
                                  Text("電子發票設定", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(height: 1, color: Theme.of(context).dividerColor),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 70,
                                    child: Text("統一編號", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15))
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: ubnController,
                                      keyboardType: TextInputType.number,
                                      maxLength: 8,
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(8),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: "8 碼統編 (選填)",
                                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                        counterText: "",
                                        isDense: true,
                                        filled: true,
                                        fillColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                                    child: Text("手機載具", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15))
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: _scanCarrier,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: carrierNumController.text.isEmpty ? Colors.transparent : Colors.greenAccent.withValues(alpha: 0.8), width: 1.5),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(CupertinoIcons.camera, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                carrierNumController.text.isEmpty ? "點擊掃描手機條碼" : carrierNumController.text,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: carrierNumController.text.isEmpty 
                                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                                                    : Theme.of(context).colorScheme.onSurface,
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
                                                child: Icon(CupertinoIcons.clear_thick_circled, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
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
                                          label: Text(m, style: TextStyle(fontSize: 15, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface)),
                                          selected: isSelected,
                                          showCheckmark: isSelected,
                                          checkmarkColor: Theme.of(context).colorScheme.primary,
                                          selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                          backgroundColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
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
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
                                      decoration: InputDecoration(
                                        labelText: "金額",
                                        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Theme.of(context).dividerColor)
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Theme.of(context).dividerColor)
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                                        ),
                                        prefixText: '\$ ',
                                        prefixStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
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
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
                                        decoration: InputDecoration(
                                          labelText: "末四碼",
                                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Theme.of(context).dividerColor)
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Theme.of(context).dividerColor)
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
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
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                                        ),
                                        child: Icon(CupertinoIcons.add, color: Theme.of(context).colorScheme.primary, size: 24),
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
                                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: isComplete ? 1.0 : 0.1), 
                                  foregroundColor: isComplete ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                  disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        children: [
          // Embedded header: printer + title + close
          SafeArea(
            bottom: false,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(CupertinoIcons.printer_fill, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: isLoading ? null : _reprintBill,
                    tooltip: "補印結帳確認單",
                  ),
                  Expanded(
                    child: Text(
                      "結帳",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.xmark, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => widget.onClose?.call(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("選擇付款方式", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.printer_fill),
            onPressed: isLoading ? null : _reprintBill,
            tooltip: "補印結帳確認單",
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: _buildBody(context),
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
