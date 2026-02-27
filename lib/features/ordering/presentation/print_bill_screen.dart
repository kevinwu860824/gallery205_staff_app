import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart';
import 'package:gallery205_staff_app/core/models/tax_profile.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/data/repositories/ordering_repository_impl.dart'; // For fetching
import 'package:gallery205_staff_app/features/ordering/data/datasources/ordering_remote_data_source.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/ordering_repository.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Need prefs for repo
import 'package:gallery205_staff_app/features/ordering/domain/logic/order_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // NEW
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart'; // NEW


class PrintBillScreen extends ConsumerStatefulWidget {
  final String groupKey;
  final String title;
  final String? splitId; // Optional: If handling a specific split sub-order directly via ID vs groupKey

  const PrintBillScreen({
    super.key,
    required this.groupKey,
    required this.title,
    this.splitId,
  });

  @override
  ConsumerState<PrintBillScreen> createState() => _PrintBillScreenState();
}

class _PrintBillScreenState extends ConsumerState<PrintBillScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> items = [];
  String? shopId; // Store shopId
  
  // Billing State
  bool isServiceFeeEnabled = true;
  int serviceFeeRate = 10;
  final List<int> serviceFeeOptions = [0, 5, 10, 15, 20, 25, 30];
  
  double manualDiscount = 0.0;
  final TextEditingController _discountController = TextEditingController();

  double _subtotal = 0;
  double _serviceFee = 0;
  double _taxAmount = 0; // NEW
  double _finalTotal = 0;
  
  TaxProfile? _taxProfile; // NEW

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    
    try {
      // 1. Fetch Order Group Info (for default settings if saved previously)
      final groupRes = await supabase
          .from('order_groups')
          .select('id, table_names, pax, service_fee_rate, discount_amount, shop_id, status, created_at, tax_snapshot')
          .eq('id', widget.groupKey)
          .single();
          
      if (groupRes != null) {
        shopId = groupRes['shop_id'];

        if (groupRes['service_fee_rate'] != null) {
          serviceFeeRate = groupRes['service_fee_rate'];
          isServiceFeeEnabled = serviceFeeRate > 0;
        }
        if (groupRes['discount_amount'] != null) {
          manualDiscount = (groupRes['discount_amount'] as num).toDouble();
          _discountController.text = manualDiscount == 0 ? '' : manualDiscount.toStringAsFixed(0);
        }
      }

      // 2. Fetch Active Items
      // Changed to pass to items list, then we manually consolidate and order
      final itemsRes = await supabase
          .from('order_items')
          .select() // Selects all, including modifiers
          .eq('order_group_id', widget.groupKey)
          .neq('status', 'cancelled')
          .order('created_at', ascending: true); // Ascending: earliest first (from top to bottom)
          
      final List<Map<String, dynamic>> rawItemsList = List<Map<String, dynamic>>.from(itemsRes);
      
      // Helper function to generate visual identity key
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
         
         // In PrintBill we merge similar items within the same seconds
         final String cAtStr = item['created_at']?.toString() ?? '';
         String batchKey = '';
         if (cAtStr.isNotEmpty) {
             final dt = DateTime.parse(cAtStr).toLocal();
             batchKey = "${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute}:${dt.second}";
         }
         
         // Merge logic ignores status since they are all non-cancelled, but consider original_price (招待)
         final String oPrice = item['original_price']?.toString() ?? '';

         return "$name|$price|$note|$modStr|$batchKey|$oPrice";
      }

      List<Map<String, dynamic>> consolidated = [];
      
      for (var item in rawItemsList) {
        bool found = false;
        final String identity = getVisualIdentity(item);
        
        for (var c in consolidated) {
           if (identity == getVisualIdentity(c)) {
              c['quantity'] = (c['quantity'] as num).toInt() + (item['quantity'] as num).toInt();
              
              // Store all source IDs to allow batch deletion / toggle treat
              List<String> sIds = List<String>.from(c['_source_ids'] ?? [c['id']]);
              sIds.add(item['id']);
              c['_source_ids'] = sIds;
              
              found = true;
              break;
           }
        }
        
        if (!found) {
           final newItem = Map<String, dynamic>.from(item);
           newItem['_source_ids'] = [item['id']];
           consolidated.add(newItem);
        }
      }
      
      items = consolidated;
      
      // 3. Fetch Tax Profile (Prefer Snapshot)
      final snapshot = groupRes['tax_snapshot'];
      if (snapshot != null) {
          _taxProfile = TaxProfile(
             id: 'snapshot', 
             shopId: shopId ?? '', 
             rate: (snapshot['rate'] as num?)?.toDouble() ?? 0.0,
             isTaxIncluded: snapshot['is_tax_included'] ?? true,
             updatedAt: DateTime.now()
          );
      } else {
         // Fallback to Live Settings
         final prefs = await SharedPreferences.getInstance();
         final dataSource = OrderingRemoteDataSourceImpl(supabase);
         final repo = OrderingRepositoryImpl(dataSource, prefs);
         _taxProfile = await repo.getTaxProfile();
      }

      _calculateTotals();
    } catch (e) {
      debugPrint("Load bill error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("載入失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateTotals() {
    // 建立臨時的 TaxProfile (如果尚未載入，使用預設值)
    final profile = _taxProfile ?? TaxProfile(
       id: 'temp',
       shopId: shopId ?? '',
       rate: 0,
       isTaxIncluded: true,
       updatedAt: DateTime.now()
    );

    // 🔥 核心修正：呼叫統一計算引擎
    final price = OrderCalculator.calculate(
      items: items, 
      serviceFeeRate: isServiceFeeEnabled ? serviceFeeRate.toDouble() : 0.0,
      discountAmount: manualDiscount,
      taxProfile: profile,
    );

    _subtotal = price.subtotal;
    _serviceFee = price.serviceFee;
    _taxAmount = price.taxAmount;
    _finalTotal = price.finalTotal;
    
    if (mounted) setState(() {});
  }

  // Action: Delete Item (Swipe Left) with Confirmation
  Future<void> _deleteItem(Map<String, dynamic> combinedItem) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("確認刪除?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text("確定要刪除此品項嗎？\n刪除後將標記為「已取消」。", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
           TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("確認刪除", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      )
    );
    
    if (confirm != true) return;

    final supabase = Supabase.instance.client;
    final List<String> itemIds = List<String>.from(combinedItem['_source_ids'] ?? [combinedItem['id']]);

    try {
      await supabase.from('order_items').update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).inFilter('id', itemIds);
      
      setState(() {
        items.removeWhere((item) => item['id'] == combinedItem['id']);
      });
      _calculateTotals();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已刪除品項")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("刪除失敗: $e")));
    }
  }

  // Action: Treat Item (Swipe Right) - Toggle Logic
  Future<void> _toggleTreatItem(Map<String, dynamic> combinedItem, double currentPrice, double? originalPrice) async {
    final supabase = Supabase.instance.client;
    final bool isTreated = currentPrice == 0;
    final List<String> itemIds = List<String>.from(combinedItem['_source_ids'] ?? [combinedItem['id']]);
    
    try {
      if (isTreated) {
        // Cancel Treat (Restore Price)
        final restorePrice = originalPrice ?? 0; // Fallback if 0?
        if (restorePrice == 0) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("無法還原價格 (無原始價格紀錄)")));
           return;
        }
        
        await supabase.from('order_items').update({
          'price': restorePrice,
          'original_price': null
        }).inFilter('id', itemIds);
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已取消招待 (還原價格)")));
      } else {
        // Treat (Set 0, Save Original)
        await supabase.from('order_items').update({
          'price': 0,
          'original_price': currentPrice
        }).inFilter('id', itemIds);
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已設為招待 (價格 \$0)")));
      }
      
      // Local update
      final index = items.indexWhere((item) => item['id'] == combinedItem['id']);
      if (index != -1) {
        setState(() {
          if (isTreated) {
             items[index]['price'] = originalPrice ?? 0;
             items[index]['original_price'] = null;
          } else {
             items[index]['original_price'] = currentPrice;
             items[index]['price'] = 0;
          }
          _calculateTotals();
        });
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("招待操作失敗: $e")));
    }
  }

  Future<void> _printAndClose() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    final printerService = PrinterService();
    
    try {
      // 1. Save Billing Info
      await supabase.from('order_groups').update({
        'service_fee_rate': isServiceFeeEnabled ? serviceFeeRate : 0,
        'discount_amount': manualDiscount,
        'final_amount': _finalTotal,
      }).eq('id', widget.groupKey);

      // Check Mode
      final bool isCheckout = widget.title == '正式收據';
      int printCount = 0;

      if (isCheckout) {
        if (shopId != null) {
           printCount = await _triggerPrint(supabase, printerService);
        }
        
        // Always go to payment if checkout mode
        if (mounted) {
           // If print failed (0), maybe just toast? Or blocking dialog not ideal here as flow moves on.
           // However user can reprint.
           if (printCount == 0 && shopId != null) {
               // Optional: maybe toast here
           }

          context.push('/payment', extra: {
            'groupKey': widget.groupKey,
            'totalAmount': _finalTotal
          });
        }
      } else {
        // Just Print Bill (Pre-checkout)
        if (shopId != null) {
           printCount = await _triggerPrint(supabase, printerService);
        }
        
        if (mounted) {
          if (printCount > 0) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("🖨️ 已發送至 $printCount 台印表機")));
          } else if (printCount == -1) {
             _showNoPrinterDialog();
          } else {
             // printCount == 0
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("列印失敗：無法連線至印表機檢查連線狀態")));
          }
        }
      }

    } catch (e) {
      debugPrint("Print error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("儲存/列印失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<int> _triggerPrint(SupabaseClient supabase, PrinterService service) async {
      // 1. Fetch Printer Settings
      final printerRes = await supabase.from('printer_settings').select().eq('shop_id', shopId!);
      final printerSettings = List<Map<String, dynamic>>.from(printerRes);

      // 2. Refresh Order Info (to get table names etc if needed, or pass from groupRes)
      final groupRes = await supabase.from('order_groups').select('id, table_names, pax, service_fee_rate, discount_amount, shop_id, status, created_at, staff_name').eq('id', widget.groupKey).single();
      
      final orderGroup = OrderGroup(
        id: groupRes['id'],
        status: groupRes['status'] != null ? OrderStatus.values.firstWhere((e) => e.name == groupRes['status'], orElse: () => OrderStatus.dining) : OrderStatus.dining,
        items: [], 
        createdAt: DateTime.parse(groupRes['created_at']),
        shopId: groupRes['shop_id'],
      );
      
      final orderRank = await ref.read(orderingRepositoryProvider).getOrderRank(widget.groupKey); // Fetch Rank
      
      final orderContext = OrderContext(
        order: orderGroup,
        tableNames: List<String>.from(groupRes['table_names'] ?? []),
        peopleCount: groupRes['pax'] ?? 0,
        staffName: (ref.read(authStateProvider).value?.name != null && ref.read(authStateProvider).value!.name.trim().isNotEmpty) 
              ? ref.read(authStateProvider).value!.name 
              : ((groupRes['staff_name'] as String?) ?? (ref.read(authStateProvider).value?.email ?? '')),
      );

      // Tax Logic for Printing: 
      // If tax is included, we pass 0 (hide it). 
      // If excluded, we pass the calculated amount.
      final bool isIncluded = _taxProfile?.isTaxIncluded ?? true;
      final double taxToPrint = isIncluded ? 0 : _taxAmount;
      final String? taxLabel = isIncluded 
            ? null 
            : "稅額 (${(_taxProfile?.rate ?? 0).toStringAsFixed(0)}%)";

      return await service.printBill(
        context: orderContext,
        items: items, // Current items in state
        printerSettings: printerSettings,
        subtotal: _subtotal,
        serviceFee: _serviceFee,
        discount: manualDiscount,
        finalTotal: _finalTotal,
        taxAmount: taxToPrint,
        taxLabel: taxLabel,
        orderSequenceNumber: orderRank, // Correctly pass it
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).cardColor,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: isLoading 
            ? const Center(child: CupertinoActivityIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      // 1. Item List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final String itemId = item['id'];
                            final String name = item['item_name'];
                            
                            // Fix: Calculate Total Price (Base + Modifiers)
                            double unitPrice = (item['price'] as num).toDouble();
                            
                            // Handle modifiers (check both keys)
                            final rawModifiers = item['modifiers'] ?? item['selected_modifiers'];
                            final List<String> modStrings = [];
                            
                            if (rawModifiers != null && rawModifiers is List) {
                               for (var m in rawModifiers) {
                                  if (m is Map) {
                                     final double modPrice = ((m['price'] ?? m['price_adjustment'] ?? 0) as num).toDouble();
                                     unitPrice += modPrice;
                                     
                                     String modName = m['name'] ?? '';
                                     if (modPrice > 0) {
                                        modName += " (+\$${modPrice.toInt()})";
                                     }
                                     modStrings.add(modName);
                                  }
                               }
                            }
    
                            final int qty = (item['quantity'] as num).toInt();
                            // Handle original_price safely
                            final double? originalPrice = item['original_price'] != null 
                                ? (item['original_price'] as num).toDouble() 
                                : null;
                                
                            final bool isFree = unitPrice == 0;
    
                            return Slidable(
                              key: ValueKey(itemId),
                              // Start Pane (Swipe Right -> Left Pane): TREAT
                              startActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) => _toggleTreatItem(item, unitPrice, originalPrice), 
                                    backgroundColor: isFree ? Colors.orange : const Color(0xFF21B7CA),
                                    foregroundColor: Colors.white,
                                    icon: isFree ? CupertinoIcons.arrow_uturn_left : CupertinoIcons.gift_fill,
                                    label: isFree ? '取消招待' : '招待',
                                  ),
                                ],
                              ),
                              // End Pane (Swipe Left -> Right Pane): DELETE
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) => _deleteItem(item), 
                                    backgroundColor: const Color(0xFFFE4A49),
                                    foregroundColor: Colors.white,
                                    icon: CupertinoIcons.delete,
                                    label: '刪除',
                                  ),
                                ],
                              ),
                              child: Container(
                                color: Theme.of(context).cardColor,
                                child: ListTile(
                                  title: Text(name + (isFree ? " (招待)" : ""), 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      color: isFree ? Colors.orange : Theme.of(context).colorScheme.onSurface
                                    )
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (modStrings.isNotEmpty)
                                        Text(modStrings.join(', '), style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                                      Text("數量: $qty"),
                                    ],
                                  ),
                                  trailing: Text("\$${(unitPrice * qty).toStringAsFixed(0)}", 
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // 2. Billing Settings & Footer
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.70 // Limit to 70% of VISIBLE height
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]
                          ),
                          child: SafeArea(
                            top: false,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Service Fee Settings
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
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Manual Discount
                                  TextField(
                                    controller: _discountController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: "手動折扣金額",
                                      prefixText: "- \$",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        manualDiscount = double.tryParse(val) ?? 0;
                                        _calculateTotals();
                                      });
                                    },
                                  ),
                                  
                                  const Divider(height: 32),
                                  
                                  // Summary Rows
                                  _buildSummaryRow("小計", _subtotal),
                                  if (isServiceFeeEnabled) 
                                    _buildSummaryRow("服務費 ($serviceFeeRate%)", _serviceFee, color: Colors.grey),
                                  if (manualDiscount > 0)
                                    _buildSummaryRow("折扣", -manualDiscount, color: Colors.green),
                                  
                                  // Tax Row
                                  if ((_taxProfile?.rate ?? 0) > 0)
                                     _buildSummaryRow(
                                       "稅額 (${_taxProfile!.isTaxIncluded ? '內含' : '外加'} ${_taxProfile!.rate.toStringAsFixed(0)}%)", 
                                       _taxAmount, 
                                       color: Colors.grey,
                                       fontSize: 14
                                     ),
                                  
                                  const SizedBox(height: 16),
                                  _buildSummaryRow("總金額", _finalTotal, isTotal: true),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Print Button
                                  SizedBox(
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                        shape: const StadiumBorder(),
                                      ),
                                      icon: Icon(widget.title == '正式收據' ? CupertinoIcons.creditcard : CupertinoIcons.printer),
                                      label: Text(
                                        widget.title == '正式收據' ? "前往付款" : "列印結帳單", 
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                                      ),
                                      onPressed: _printAndClose,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
            ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false, Color? color, double? fontSize}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: fontSize ?? (isTotal ? 20 : 16), 
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          )),
          Text("\$${amount.toStringAsFixed(0)}", style: TextStyle(
             fontSize: isTotal ? 24 : 16, 
             fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
             color: isTotal ? Theme.of(context).colorScheme.primary : (color ?? Theme.of(context).colorScheme.onSurface)
          )),
        ],
      ),
    );
  }
}