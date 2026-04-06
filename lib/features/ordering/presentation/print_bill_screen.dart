import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/core/models/tax_profile.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/data/repositories/ordering_repository_impl.dart'; // For fetching
import 'package:gallery205_staff_app/features/ordering/data/datasources/ordering_remote_data_source.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/ordering_repository.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Need prefs for repo
import 'package:gallery205_staff_app/features/ordering/domain/logic/order_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // NEW
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart'; // NEW
import 'package:gallery205_staff_app/features/ordering/domain/ordering_constants.dart';

class PrintBillScreen extends ConsumerStatefulWidget {
  final String groupKey;
  final String title;
  final String?
      splitId; // Optional: If handling a specific split sub-order directly via ID vs groupKey
  final VoidCallback? onClose;
  final VoidCallback? onCheckout;
  final bool embedded;

  const PrintBillScreen({
    super.key,
    required this.groupKey,
    required this.title,
    this.splitId,
    this.onClose,
    this.onCheckout,
    this.embedded = false,
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
  final FocusNode _discountFocusNode = FocusNode();

  double _subtotal = 0;
  double _serviceFee = 0;
  double _taxAmount = 0; // NEW
  double _finalTotal = 0;

  TaxProfile? _taxProfile; // NEW

  @override
  void initState() {
    super.initState();
    _discountFocusNode.addListener(() {
      if (!_discountFocusNode.hasFocus) _saveBilling();
    });
    _loadData();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _discountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final repo = ref.read(orderingRepositoryProvider);
      final contextObj = await repo.getOrderContext(widget.groupKey);
      if (contextObj == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final group = contextObj.order;
      
      shopId = group.shopId;
      serviceFeeRate = (group.serviceFeeRate ?? 10).toInt();
      isServiceFeeEnabled = serviceFeeRate > 0;
      manualDiscount = group.discountAmount ?? 0.0;
      _discountController.text = manualDiscount == 0 ? '' : manualDiscount.toStringAsFixed(0);

      final List<Map<String, dynamic>> rawItemsList = contextObj.order.items.where((it) => it.status != OrderingConstants.orderStatusCancelled).map((it) => {
        'id': it.id,
        'item_id': it.menuItemId,
        'item_name': it.itemName,
        'quantity': it.quantity,
        'price': it.price,
        'original_price': it.originalPrice,
        'modifiers': it.selectedModifiers,
        'note': it.note,
        'status': it.status,
        'created_at': it.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      }).toList();

      // Helper function to generate visual identity key
      String getVisualIdentity(Map<String, dynamic> item) {
        final String name = (item['item_name'] ?? '').toString().trim();
        final double price = (item['price'] as num?)?.toDouble() ?? 0.0;

        final String note = (item['note'] ?? '')
            .toString()
            .replaceAll(RegExp(r'\| 刪除:.*'), '')
            .trim();

        final List<dynamic> mods =
            item['modifiers'] ?? item['selected_modifiers'] ?? [];
        final List<String> modNames = mods
            .map((m) =>
                (m is Map ? m['name']?.toString() ?? '' : m.toString()).trim())
            .where((n) => n.isNotEmpty)
            .toList()
          ..sort();
        final String modStr = modNames.join('|');

        // In PrintBill we merge similar items within the same seconds
        final String cAtStr = item['created_at']?.toString() ?? '';
        String batchKey = '';
        if (cAtStr.isNotEmpty) {
          final dt = DateTime.parse(cAtStr).toLocal();
          batchKey =
              "${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute}:${dt.second}";
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
            c['quantity'] = (c['quantity'] as num).toInt() +
                (item['quantity'] as num).toInt();

            // Store all source IDs to allow batch deletion / toggle treat
            List<String> sIds =
                List<String>.from(c['_source_ids'] ?? [c['id']]);
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
      // Note: OrderGroup currently doesn't expose taxSnapshot directly in Domain
      _taxProfile = await repo.getTaxProfile();

      _calculateTotals();
    } catch (e) {
      debugPrint("Load bill error: $e");
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("載入失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateTotals() {
    // 建立臨時的 TaxProfile (如果尚未載入，使用預設值)
    final profile = _taxProfile ??
        TaxProfile(
            id: 'temp',
            shopId: shopId ?? '',
            rate: 0,
            isTaxIncluded: true,
            updatedAt: DateTime.now());

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
    final List<String> itemIds =
        List<String>.from(combinedItem['_source_ids'] ?? [combinedItem['id']]);

    try {
      final repo = ref.read(orderingRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final staffName = (user?.name != null && user!.name.trim().isNotEmpty) ? user.name : (user?.email ?? '');
      
      final orderContext = await repo.getOrderContext(widget.groupKey);
      if (orderContext == null) return;

      final sourceItems = List<Map<String, dynamic>>.from(combinedItem['_source_items'] ?? [combinedItem]);

      for (var srcItem in sourceItems) {
        List<Map<String, dynamic>> selectedModifiers = [];
        if (srcItem['modifiers'] != null && srcItem['modifiers'] is List) {
          selectedModifiers = List<Map<String, dynamic>>.from(srcItem['modifiers']);
        }
        
        final orderItemEntity = OrderItem(
            id: srcItem['id'],
            menuItemId: srcItem['item_id'] ?? srcItem['menu_item_id'] ?? '',
            itemName: srcItem['item_name'],
            quantity: (srcItem['quantity'] as num).toInt(),
            price: (srcItem['price'] as num).toDouble(),
            status: 'submitted',
            targetPrintCategoryIds: List<String>.from(srcItem['target_print_category_ids'] ?? []),
            selectedModifiers: selectedModifiers,
            note: srcItem['note'] ?? '');

        await repo.voidOrderItem(
          orderGroupId: widget.groupKey,
          item: orderItemEntity,
          tableName: orderContext.tableNames.join(','),
          orderGroupPax: orderContext.peopleCount,
          staffName: staffName,
        );
      }

      setState(() {
        items.removeWhere((item) => item['id'] == combinedItem['id']);
      });
      _calculateTotals();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("已刪除品項")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("刪除失敗: $e")));
    }
  }

  // Action: Treat Item (Swipe Right) - Toggle Logic
  Future<void> _toggleTreatItem(Map<String, dynamic> combinedItem,
      double currentPrice, double? originalPrice) async {
    final bool isTreated = currentPrice == 0;
    final List<String> itemIds =
        List<String>.from(combinedItem['_source_ids'] ?? [combinedItem['id']]);

    try {
      final repo = ref.read(orderingRepositoryProvider);
      if (isTreated) {
        // Cancel Treat (Restore Price)
        final restorePrice = originalPrice ?? 0;
        if (restorePrice == 0) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("無法還原價格 (無原始價格紀錄)")));
          return;
        }
        await repo.treatOrderItem(
          orderGroupId: widget.groupKey,
          itemIds: itemIds,
          price: restorePrice,
          originalPrice: null,
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("已取消招待 (還原價格)")));
      } else {
        // Treat (Set 0, Save Original)
        await repo.treatOrderItem(
          orderGroupId: widget.groupKey,
          itemIds: itemIds,
          price: 0,
          originalPrice: currentPrice,
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("已設為招待 (價格 \$0)")));
      }

      // Local update
      final index =
          items.indexWhere((item) => item['id'] == combinedItem['id']);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("招待操作失敗: $e")));
    }
  }

  void _saveBilling() {
    final repo = ref.read(orderingRepositoryProvider);
    repo.updateBillingInfo(
      orderGroupId: widget.groupKey,
      serviceFeeRate: isServiceFeeEnabled ? serviceFeeRate.toDouble() : 0,
      discountAmount: manualDiscount,
      finalAmount: _finalTotal,
    );
  }

  Future<void> _printAndClose() async {
    final supabase = Supabase.instance.client;
    setState(() => isLoading = true);
    final repo = ref.read(orderingRepositoryProvider);
    final printerService = PrinterService();

    try {
      // 1. Save Billing Info
      await repo.updateBillingInfo(
        orderGroupId: widget.groupKey,
        serviceFeeRate: isServiceFeeEnabled ? serviceFeeRate.toDouble() : 0,
        discountAmount: manualDiscount,
        finalAmount: _finalTotal,
      );

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

          context.push('/payment',
              extra: {'groupKey': widget.groupKey, 'totalAmount': _finalTotal});
        }
      } else {
        // Just Print Bill (Pre-checkout)
        if (shopId != null) {
          printCount = await _triggerPrint(supabase, printerService);
        }

        if (mounted) {
          if (printCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("🖨️ 已發送至 $printCount 台印表機")));
          } else if (printCount == -1) {
            _showNoPrinterDialog();
          } else {
            // printCount == 0
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("列印失敗：無法連線至印表機檢查連線狀態")));
          }
        }
      }
    } catch (e) {
      debugPrint("Print error: $e");
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("儲存/列印失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveAndCheckout() async {
    if (widget.onCheckout == null) return;
    try {
      final repo = ref.read(orderingRepositoryProvider);
      await repo.updateBillingInfo(
        orderGroupId: widget.groupKey,
        serviceFeeRate: isServiceFeeEnabled ? serviceFeeRate.toDouble() : 0,
        discountAmount: manualDiscount,
        finalAmount: _finalTotal,
      );
    } catch (_) {}
    widget.onCheckout!();
  }

  Future<int> _triggerPrint(
      SupabaseClient supabase, PrinterService service) async {
    final repo = ref.read(orderingRepositoryProvider);

    final printerRes = await supabase.from('printer_settings').select().eq('shop_id', shopId!);
    final printerSettings = List<Map<String, dynamic>>.from(printerRes);

    final orderContext = await repo.getOrderContext(widget.groupKey);
    if (orderContext == null) return 0;
    
    final orderRank = await repo.getOrderRank(widget.groupKey); 

    final currentStaff = ref.read(authStateProvider).value?.name ?? ref.read(authStateProvider).value?.email ?? '';
    final printContext = OrderContext(
      order: orderContext.order,
      tableNames: orderContext.tableNames,
      peopleCount: orderContext.peopleCount,
      staffName: (orderContext.staffName != null && orderContext.staffName!.isNotEmpty) ? orderContext.staffName : currentStaff,
    );

    final bool isIncluded = _taxProfile?.isTaxIncluded ?? true;
    final double taxToPrint = isIncluded ? 0 : _taxAmount;
    final String? taxLabel = isIncluded ? null : "稅額 (${(_taxProfile?.rate ?? 0).toStringAsFixed(0)}%)";

    return await service.printBill(
      context: printContext,
      items: items, 
      printerSettings: printerSettings,
      subtotal: _subtotal,
      serviceFee: _serviceFee,
      discount: manualDiscount,
      finalTotal: _finalTotal,
      taxAmount: taxToPrint,
      taxLabel: taxLabel,
      orderSequenceNumber: orderRank,
    );
  }

  void _showNoPrinterDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("未設定結帳印表機"),
              content: const Text(
                  "系統找不到已設為「收據/結帳」的印表機。\n請至 設定 > 印表機設定，編輯任一印表機並開啟「設為收據印表機」開關。"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("好")),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/printerSettings');
                  },
                  child: const Text("前往設定"),
                )
              ],
            ));
  }

  Widget _buildBody(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : LayoutBuilder(builder: (context, constraints) {
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
                        final rawModifiers =
                            item['modifiers'] ?? item['selected_modifiers'];
                        final List<String> modStrings = [];

                        if (rawModifiers != null && rawModifiers is List) {
                          for (var m in rawModifiers) {
                            if (m is Map) {
                              final double modPrice = ((m['price'] ??
                                      m['price_adjustment'] ??
                                      0) as num)
                                  .toDouble();
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
                        final double? originalPrice =
                            item['original_price'] != null
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
                                onPressed: (_) => _toggleTreatItem(
                                    item, unitPrice, originalPrice),
                                backgroundColor: isFree
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                                foregroundColor: isFree
                                    ? Theme.of(context).colorScheme.onError
                                    : Theme.of(context).colorScheme.onPrimary,
                                icon: isFree
                                    ? CupertinoIcons.arrow_uturn_left
                                    : CupertinoIcons.gift_fill,
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
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onError,
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
                                      color: isFree
                                          ? Colors.orange
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (modStrings.isNotEmpty)
                                    Text(modStrings.join(', '),
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7))),
                                  Text("數量: $qty"),
                                ],
                              ),
                              trailing: Text(
                                  "\$${(unitPrice * qty).toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 2. Billing Settings & Footer
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight *
                            0.70 // Limit to 70% of VISIBLE height
                        ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, -2))
                          ]),
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
                                    activeColor:
                                        Theme.of(context).colorScheme.primary,
                                    onChanged: (v) => setState(() {
                                      isServiceFeeEnabled = v ?? true;
                                      _calculateTotals();
                                      _saveBilling();
                                    }),
                                  ),
                                  const Text("服務費",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  if (isServiceFeeEnabled)
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton2<int>(
                                        value: serviceFeeRate,
                                        items: serviceFeeOptions
                                            .map((rate) => DropdownMenuItem(
                                                  value: rate,
                                                  child: Text("$rate%",
                                                      style: const TextStyle(
                                                          fontSize: 14)),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              serviceFeeRate = val;
                                              _calculateTotals();
                                            });
                                            _saveBilling();
                                          }
                                        },
                                        buttonStyleData: ButtonStyleData(
                                          height: 36,
                                          width: 80,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Manual Discount
                              TextField(
                                controller: _discountController,
                                focusNode: _discountFocusNode,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "手動折扣金額",
                                  prefixText: "- \$",
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
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
                                _buildSummaryRow(
                                    "服務費 ($serviceFeeRate%)", _serviceFee,
                                    color: Colors.grey),
                              if (manualDiscount > 0)
                                _buildSummaryRow("折扣", -manualDiscount,
                                    color: Colors.green),

                              // Tax Row
                              if ((_taxProfile?.rate ?? 0) > 0)
                                _buildSummaryRow(
                                    "稅額 (${_taxProfile!.isTaxIncluded ? '內含' : '外加'} ${_taxProfile!.rate.toStringAsFixed(0)}%)",
                                    _taxAmount,
                                    color: Colors.grey,
                                    fontSize: 14),

                              const SizedBox(height: 16),
                              _buildSummaryRow("總金額", _finalTotal,
                                  isTotal: true),

                              const SizedBox(height: 24),

                              // Print + Checkout Buttons
                              SizedBox(
                                height: 50,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          shape: const StadiumBorder(),
                                        ),
                                        icon: Icon(widget.title == '正式收據'
                                            ? CupertinoIcons.creditcard
                                            : CupertinoIcons.printer),
                                        label: Text(
                                          widget.title == '正式收據'
                                              ? "前往付款"
                                              : "列印結帳單",
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: _printAndClose,
                                      ),
                                    ),
                                    if (widget.onCheckout != null &&
                                        widget.title != '正式收據') ...[
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 95,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            shape: const StadiumBorder(),
                                          ),
                                          icon: const Icon(
                                              CupertinoIcons
                                                  .money_dollar_circle_fill,
                                              size: 16),
                                          label: const Text(
                                            '結帳',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: _saveAndCheckout,
                                        ),
                                      ),
                                    ],
                                  ],
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
            }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody(context);
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).cardColor,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: widget.onClose ?? () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildSummaryRow(String label, double amount,
      {bool isTotal = false, Color? color, double? fontSize}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: fontSize ?? (isTotal ? 20 : 16),
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: color ?? Theme.of(context).colorScheme.onSurface,
              )),
          Text("\$${amount.toStringAsFixed(0)}",
              style: TextStyle(
                  fontSize: isTotal ? 24 : 16,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                  color: isTotal
                      ? Theme.of(context).colorScheme.primary
                      : (color ?? Theme.of(context).colorScheme.onSurface))),
        ],
      ),
    );
  }
}
