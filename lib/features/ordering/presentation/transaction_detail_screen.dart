import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';
import 'package:gallery205_staff_app/features/ordering/data/models/ordering_models.dart'; // Added for OrderContextMapper
import 'package:gallery205_staff_app/core/services/invoice_service.dart'; // Added
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/features/ordering/data/repositories/ordering_repository_impl.dart';
import 'package:gallery205_staff_app/features/ordering/data/datasources/ordering_remote_data_source.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/ordering_repository.dart';
import 'package:gallery205_staff_app/features/ordering/domain/repositories/session_repository.dart';
import 'package:gallery205_staff_app/features/ordering/domain/models/table_model.dart'; // Needed for TableStatus
import 'package:shared_preferences/shared_preferences.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final String orderGroupId;
  final String transactionId; // e.g. "20260127..."
  final bool isReadOnly;

  const TransactionDetailScreen({
    super.key,
    required this.orderGroupId,
    this.transactionId = '-',
    this.isReadOnly = false,
  });

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {
  bool isLoading = true;
  Map<String, dynamic>? orderData;
  List<Map<String, dynamic>> items = [];
  
  // Grouped items: Map<DateTime, List<Map<String, dynamic>>>
  // Key is the approximate batch time
  Map<String, List<Map<String, dynamic>>> groupedBatches = {};
  Map<String, String> printCategoryNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // 1. Fetch Order Group
      final groupResFuture = supabase
          .from('order_groups')
          .select('*, order_items(*, updated_at)')
          .eq('id', widget.orderGroupId)
          .single();
          
      // 2. Fetch Print Categories for mapping
      // Fetch after getting group data to know shop_id, or chain.
      // We will await groupRes first.
      
      final groupRes = await groupResFuture;
      orderData = groupRes;
      items = List<Map<String, dynamic>>.from(groupRes['order_items'] ?? []);
      
      final shopId = groupRes['shop_id'];
      if (shopId != null) {
        // Fetch Print Categories
        final catsRes = await supabase
            .from('print_categories')
            .select('id, name')
            .eq('shop_id', shopId);
        
        for (var row in catsRes) {
          printCategoryNames[row['id']] = row['name'];
        }

        // Fetch Shop Metadata for Printing
        final shopRes = await supabase
            .from('shops')
            .select('name')
            .eq('id', shopId)
            .maybeSingle();
        shopName = shopRes?['name'] ?? 'The Gallery 205';

        final ezpayRes = await supabase
            .from('shop_ezpay_settings')
            .select('seller_ubn')
            .eq('shop_id', shopId)
            .maybeSingle();
        sellerUbn = ezpayRes?['seller_ubn'] ?? '';
      }

      // 3. Event Sourcing & Batching
      // We want to create a list of "Events": Order Created, Item Deleted, etc.
      List<Map<String, dynamic>> allEvents = [];
      
      for (var item in items) {
         // A. Order Event (Always exists)
         allEvents.add({
           'type': 'order',
           'time': DateTime.parse(item['created_at']).toLocal(),
           'item': {...item, 'time_used': DateTime.parse(item['created_at']).toLocal()}, // Inject time checking
         });
         
         // B. Delete Event (If cancelled)
         bool isDeleted = false;
         DateTime? deleteTime;
         
         if (item['status'] == 'cancelled') {
             // Individual cancellation
             isDeleted = true;
             if (item['updated_at'] != null) {
                deleteTime = DateTime.parse(item['updated_at']).toLocal();
             }
         }
         // Removed synthetic void logic for 'cancelled' group status as per user request.
         // Only individual item cancellations (marked in item status) will generate delete events.
         
         // 3. Fallback: Parse from Note (Workaround for Schema Cache)
         if (item['note'] != null && (item['note'] as String).contains('| 刪除:')) {
            final note = item['note'] as String;
            final parts = note.split('| 刪除:');
            if (parts.length > 1) {
               final timeStr = parts.last.trim();
               try {
                  deleteTime = DateTime.parse(timeStr).toLocal();
                  isDeleted = true; // Mark as deleted based on note
               } catch (_) {}
            }
         }
         
         if (isDeleted) {
             // If we can't determine time, fallback to created_at (same batch) or group updated_at
             // This ensures it SHOWS up.
             DateTime time = deleteTime ?? (orderData?['updated_at'] != null ? DateTime.parse(orderData!['updated_at']).toLocal() : DateTime.parse(item['created_at']).toLocal());
             
             // DEBUG: Print updated_at status
             debugPrint("Item ${item['item_name']} - Status: ${item['status']}, UpdatedAt: ${item['updated_at']}, DeleteTime: $deleteTime, FinalTime: $time");

             // CRITICAL FIX: If delete time is effectively same as create time (due to fallback or lack of precision),
             // Force a small offset to ensure they are in different batches.
             // We check if it's identical to Created At.
             final createdAt = DateTime.parse(item['created_at']).toLocal();
             if (time.isAtSameMomentAs(createdAt)) {
                 debugPrint("Time collision detected for deletion. Adding offset.");
                 time = time.add(const Duration(milliseconds: 100));
             }

             // Create a "Deletion Item" (Copy)
             final Map<String, dynamic> deleteItem = Map.from(item);
             deleteItem['_is_deletion_record'] = true;
             deleteItem['time_used'] = time; // Inject time checking
             
             allEvents.add({
               'type': 'delete',
               'time': time,
               'item': deleteItem,
             });
         }
      }
      
      // Sort Events by Time
      allEvents.sort((a, b) {
         final tA = a['time'] as DateTime;
         final tB = b['time'] as DateTime;
         int cmp = tA.compareTo(tB);
         if (cmp != 0) return cmp;
         // Stable sort: Order before Delete if same second?
         return (a['type'] == 'order' ? -1 : 1);
      });
      
      // Group into Batches (HH:mm:ss)
      groupedBatches.clear();
      
      for (var event in allEvents) {
        final dt = event['time'] as DateTime;
        // Use Milliseconds to distinguish batches within the same second
        final String key = DateFormat('yyyy/MM/dd HH:mm:ss.SSS').format(dt);
        groupedBatches.putIfAbsent(key, () => []).add(event['item']);
      }
      
      // Ensure key order (Chronological) for map iteration
      final sortedKeys = groupedBatches.keys.toList()..sort();
      final Map<String, List<Map<String, dynamic>>> sortedMap = {};
      for (var k in sortedKeys) {
        sortedMap[k] = groupedBatches[k]!;
      }
      groupedBatches = sortedMap;

    } catch (e) {
      debugPrint("Load transaction error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("載入失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  OrderingRepository? _repository;
  Future<void> _ensureRepository() async {
    if (_repository != null) return;
    final prefs = await SharedPreferences.getInstance();
    final client = Supabase.instance.client;
    // We need to import these. Assuming I will add imports.
    // For now, using fully qualified or assume imports added.
    final dataSource = OrderingRemoteDataSourceImpl(client);
    _repository = OrderingRepositoryImpl(dataSource, prefs);
  }

  Future<void> _processVoid() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("確認作廢"),
        content: const Text("確定要結束並作廢此筆交易嗎？\n此操作無法復原。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("取消")),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text("確認作廢"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    await _ensureRepository();
    
    try {
      // 1. Check if we need to invalidate an ezPay invoice
      final String? invoiceNum = orderData?['ezpay_invoice_number'];
      final String? invoiceStatus = orderData?['ezpay_invoice_status']?.toString();
      
      if (invoiceNum != null && invoiceStatus == '1') {
         // Show a specific warning for invoice invalidation
         final bool? invalidateConfirm = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text("作廢電子發票"),
              content: Text("此訂單已開立發票 ($invoiceNum)，作廢訂單將同步作廢電子發票。是否繼續？"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("點錯了")),
                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("確認作廢")),
              ],
            ),
         );
         
         if (invalidateConfirm != true) {
            setState(() => isLoading = false);
            return;
         }

         // Call Invalidation
         final bool invalidResult = await ref.read(invoiceServiceProvider).invalidateInvoice(widget.orderGroupId);
         if (!invalidResult) {
            throw "電子發票作廢失敗，請檢查網路或手動至藍新後台處理。";
         }
      }

      await _repository!.voidOrderGroup(
        widget.orderGroupId,
        staffName: (ref.read(authStateProvider).value?.name != null && ref.read(authStateProvider).value!.name.trim().isNotEmpty) 
               ? ref.read(authStateProvider).value!.name 
               : (ref.read(authStateProvider).value?.email ?? ''),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("交易已作廢")));
        context.pop(true); // Return true to signal refresh
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("作廢失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ... _processClone (Keep as is or refactor if ambitious, but keeping user scope in mind) ...

  Future<void> _processPrintBatch(List<Map<String, dynamic>> batchItems, int batchIndex) async {
      if (orderData == null) return;
      
      setState(() => isLoading = true);
      await _ensureRepository();

      try {
        final List<OrderItem> items = [];
        for (var itemMap in batchItems) {
            // Check if deletion record
            final isDeletion = itemMap['_is_deletion_record'] == true;
            final status = isDeletion ? 'cancelled' : (itemMap['status'] ?? 'submitted');
            
            items.add(OrderItem(
              id: itemMap['id'] ?? '',
              menuItemId: itemMap['menu_item_id'] ?? itemMap['item_id'] ?? '',
              itemName: itemMap['item_name'],
              quantity: itemMap['quantity'] ?? 1,
              price: (itemMap['price'] as num).toDouble(),
              status: status ?? 'submitted',
              note: itemMap['note'] ?? '',
              targetPrintCategoryIds: List<String>.from(itemMap['target_print_category_ids'] ?? []),
              selectedModifiers: List<Map<String, dynamic>>.from(itemMap['modifiers'] ?? itemMap['selected_modifiers'] ?? []),
            ));
        }

        await _repository!.reprintBatch(
           orderGroupId: widget.orderGroupId, 
           items: items, 
           tableNames: List<String>.from(orderData!['table_names'] ?? []), 
           pax: orderData!['pax'] ?? 0, 
           batchIndex: batchIndex,
           staffName: orderData!['staff_name'] ?? (ref.read(authStateProvider).value?.name != null && ref.read(authStateProvider).value!.name.trim().isNotEmpty 
               ? ref.read(authStateProvider).value!.name 
               : (ref.read(authStateProvider).value?.email ?? '')),
        );


        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已送出補印")));

      } catch (e) {
        debugPrint("Batch Print error: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("補印失敗: $e")));
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
  }

  Future<void> _processClone() async {
    // 1. Prepare Repository
    setState(() => isLoading = true);
    await _ensureRepository();
    // Use SessionRepository cast if needed, but OrderingRepositoryImpl implements it.
    final sessionRepo = _repository as SessionRepository;

    try {
      // 2. Fetch Areas
      final areas = await sessionRepo.fetchAreas();
      
      if (mounted) setState(() => isLoading = false); // Stop loading to show dialog
      if (!mounted) return;

      if (areas.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("無可用區域")));
        return;
      }

      // 3. Step 1: Select Area
      final String? selectedAreaId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("選擇區域"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: areas.length,
              itemBuilder: (context, index) {
                final area = areas[index];
                return ListTile(
                  title: Text(area.name, style: const TextStyle(fontSize: 18)),
                  onTap: () => Navigator.pop(context, area.id),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          ],
        ),
      );

      if (selectedAreaId == null) return;

      // 4. Fetch Tables for Area
      if (mounted) setState(() => isLoading = true);
      final tables = await sessionRepo.fetchTablesInArea(selectedAreaId);
      
      if (mounted) setState(() => isLoading = false);
      if (!mounted) return;

      // 5. Step 2: Select Table
      final String? selectedTable = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("選擇目標桌位"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: tables.isEmpty 
                ? const Center(child: Text("此區域無桌位"))
                : ListView.builder(
                    itemCount: tables.length,
                    itemBuilder: (context, index) {
                      final t = tables[index];
                      final isOccupied = t.status == TableStatus.occupied;
                      
                      return ListTile(
                        title: Text(
                          "${t.tableName}${isOccupied ? ' (使用中)' : ''}", 
                          style: TextStyle(
                            fontSize: 18, 
                            color: isOccupied ? Theme.of(context).disabledColor : Theme.of(context).colorScheme.onSurface
                          )
                        ),
                        onTap: () {
                          if (isOccupied) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("桌號 ${t.tableName} 已有人入座，請選擇其他桌位"),
                              duration: const Duration(seconds: 2),
                            ));
                          } else {
                            Navigator.pop(context, t.tableName);
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          ],
        ),
      );
      
      if (selectedTable == null) return;

      // Perform Clone
      if (mounted) setState(() => isLoading = true);
      
      // A. Create new OrderGroup
      final originalPax = orderData!['pax'] ?? 2;
      final shopId = orderData!['shop_id'];
      
      // Get Open ID (Reuse existing logic or move to repo)
      String? openId;
      final supabase = Supabase.instance.client;
       try {
         if(shopId != null) {
            final statusRes = await supabase.rpc('rpc_get_current_cash_status', params: {'p_shop_id': shopId}).maybeSingle();
            if (statusRes != null && statusRes['status'] == 'OPEN') {
               openId = statusRes['open_id'] as String?;
            }
         }
       } catch(e) {
          debugPrint("OpenID error: $e");
       }

      final newGroupRes = await supabase.from('order_groups').insert({
        'table_names': [selectedTable],
        'pax': originalPax,
        'status': 'dining', // Active
        'shop_id': shopId,
        'open_id': openId,
        'note': orderData!['note'] // Copy note too
      }).select().single();
      
      final newGroupId = newGroupRes['id'];

      // B. Copy Items
      final List<Map<String, dynamic>> itemsToInsert = [];
      for(var item in items) {
         if (item['status'] == 'cancelled') continue; // Don't copy cancelled items
         
         itemsToInsert.add({
           'order_group_id': newGroupId,
           'item_name': item['item_name'],
           'price': item['price'],
           'quantity': item['quantity'],
           'status': 'submitted', // Reset status
           'modifiers': item['modifiers'] ?? item['selected_modifiers'],
           'note': item['note'],
           'target_print_category_ids': item['target_print_category_ids'],
         });
      }
      
      if (itemsToInsert.isNotEmpty) {
        await supabase.from('order_items').insert(itemsToInsert);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已複製到桌號 $selectedTable")));
        // Go to Area Selection but maybe pre-select the area? 
        // Or just go to table selection.
        // Let's go to selectArea implies resetting.
        context.go('/selectArea'); 
      }
      
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("複製失敗: $e")));
    } finally {
      if(mounted) setState(() => isLoading = false);
    }
  }

  String shopName = '';
  String sellerUbn = '';

  Future<void> _printInvoiceProof({bool isReprint = false}) async {
    if (orderData == null) return;
    
    setState(() => isLoading = true);
    try {
      final contextData = OrderContextMapper.fromJson(orderData!, items.map((e) => OrderItemMapper.fromJson(e)).toList());
      
      final String shopIdStr = orderData!['shop_id'];
      final allSettings = await Supabase.instance.client.from('printer_settings').select().eq('shop_id', shopIdStr);
      final printerSettings = List<Map<String, dynamic>>.from(allSettings);

      final printerService = PrinterService();
      final int success = await printerService.printInvoiceProof(
        order: contextData.order,
        printerSettings: printerSettings,
        shopName: shopName,
        sellerUbn: sellerUbn,
        isReprint: isReprint,
      );

      if (success > 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("電子發票證明聯列印成功")));
      } else {
        throw "無可用印表機或列印失敗";
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("列印失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _processRetryInvoice() async {
    if (orderData == null) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Warn about cross-period issuance
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("補開電子發票"),
        content: const Text(
            "確定要補開這筆訂單的電子發票嗎？\n\n"
            "【注意】請確認目前日期與訂單營業日是否為同一個申報期（雙數月底）。若跨期補開可能會有稅務申報上的問題，建議先與會計確認。"
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("取消")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.primary),
            onPressed: () => Navigator.pop(c, true), 
            child: const Text("確認補開")
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    
    try {
      final InvoiceService invoiceService = ref.read(invoiceServiceProvider);
      final String? newInvoiceNum = await invoiceService.issueInvoice(widget.orderGroupId);
      
      if (newInvoiceNum != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("成功開立發票：$newInvoiceNum")));
        
        // Ask if they want to print it
        final bool? printConfirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("發票開立成功"),
            content: Text("發票號碼 $newInvoiceNum 已開立，是否立即列印證明聯？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("不列印")),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: colorScheme.primary),
                onPressed: () => Navigator.pop(c, true), 
                child: const Text("列印證明聯")
              ),
            ],
          ),
        );

        if (printConfirm == true) {
           // Reload first to get the QR codes from DB
           await _loadData(); 
           await _printInvoiceProof();
        } else {
           await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("補開失敗"),
            content: Text("藍新 API 回傳錯誤：\n$e\n\n請檢查字軌是否用罄、參數設定，或稍後再試。"),
            actions: [
               TextButton(onPressed: () => Navigator.pop(c), child: const Text("確定"))
            ],
          )
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Basic Info from Data
    final bool hasData = orderData != null;
    final String dateStr = hasData ? DateFormat('yyyy/MM/dd').format(DateTime.parse(orderData!['created_at']).toLocal()) : '-';
    // Use last updated or checkout time as "Transaction Date"?
    final String timeStr = hasData && orderData!['checkout_time'] != null 
        ? DateFormat('yyyy/MM/dd HH:mm:ss').format(DateTime.parse(orderData!['checkout_time']).toLocal()) 
        : '-';
    
    // Attempt to find a 'seq' or order number. Usually passed in or calculated.
    // Using ID snippet for now if not provided.
    final String displayId = widget.transactionId != '-' ? widget.transactionId : (hasData ? orderData!['id'].toString().substring(0,8) : '-');
    final String invoice = orderData?['invoice_number'] ?? '-';
    final String pickupNum = orderData?['pickup_number']?.toString() ?? '1';
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("交易紀錄詳情"),
        backgroundColor: theme.cardColor,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.pop(),
        ),
      ),
      body: isLoading 
          ? const Center(child: CupertinoActivityIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                   // 1. Info Card
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       color: theme.cardColor,
                       borderRadius: BorderRadius.circular(12),
                       boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                     ),
                     child: Column(
                       children: [
                         _buildInfoRow(context, "營業日期：", dateStr),
                         _buildInfoRow(context, "交易日期：", timeStr),
                         _buildInfoRow(context, "領餐號：", pickupNum),
                         _buildInfoRow(context, "交易編號：", displayId),
                         _buildInfoRow(context, "統一發票：", invoice),
                         if (orderData?['staff_name'] != null)
                             _buildInfoRow(context, "經手人員：", orderData!['staff_name']),
                         
                         if (!widget.isReadOnly) ...[
                             const SizedBox(height: 24),
                             Row(
                               children: [
                                 Expanded(
                                   child: OutlinedButton(
                                     onPressed: _processClone,
                                     style: OutlinedButton.styleFrom(
                                       padding: const EdgeInsets.symmetric(vertical: 16),
                                       side: BorderSide(color: theme.dividerColor),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                       foregroundColor: colorScheme.onSurface,
                                     ),
                                     child: const Text("複製菜單並點餐", style: TextStyle(fontSize: 16)),
                                   ),
                                 ),
                               const SizedBox(width: 16),
                                 Expanded(
                                   child: Opacity(
                                     opacity: (orderData?['status'] == 'cancelled') ? 0.5 : 1.0,
                                     child: OutlinedButton.icon(
                                       onPressed: (orderData?['status'] == 'cancelled') ? null : _processVoid,
                                       style: OutlinedButton.styleFrom(
                                         padding: const EdgeInsets.symmetric(vertical: 16),
                                         side: BorderSide(color: theme.dividerColor),
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                         foregroundColor: colorScheme.error, 
                                       ),
                                       icon: Icon(CupertinoIcons.doc_text, color: colorScheme.error, size: 18),
                                       label: Text("結束交易", style: TextStyle(color: colorScheme.error, fontSize: 16)),
                                     ),
                                   ),
                                 )
                               ],
                             )
                          ],
                       ],
                     ),
                   ),
                   
                   const SizedBox(height: 20),
                   
                   // 2. Batches
                   // Map iteration gives us ability to index
                   // 2. Batches
                   // Map iteration gives us ability to index
                   ...groupedBatches.entries.toList().asMap().entries.map((indexedEntry) {
                      final int index = indexedEntry.key;
                      final String timeKey = indexedEntry.value.key;
                      final List<Map<String, dynamic>> batchItems = indexedEntry.value.value;
                      final bool isExpanded = true; // Default expanded? or (index == 0)? Let's default open for latest? 
                      // Actually user said "point into to see details". So maybe default closed?
                      // "不用把每一次點單的明細都列出來... 如果想要看該單的明細可以點入看" -> Default Closed.
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: false, // Default closed as requested
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              "第 ${index + 1} 次出單", 
                              style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                            subtitle: Text(
                              timeKey.substring(11, 19), 
                              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 14)
                            ),
                            children: [
                               Divider(height: 1, color: theme.dividerColor),
                               ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: batchItems.length,
                                separatorBuilder: (c, i) => Divider(height: 1, color: theme.dividerColor),
                                itemBuilder: (context, index) {
                                  final item = batchItems[index];
                                  final bool isDeletion = item['_is_deletion_record'] == true;
                                  final bool isCancelled = item['status'] == 'cancelled';
                                  
                                  // Resolve Station Names
                                  List<String> targetIds = List<String>.from(item['target_print_category_ids'] ?? []);
                                  List<String> stationNames = targetIds.map((id) => printCategoryNames[id] ?? '').where((n) => n.isNotEmpty).toList();
                                  String stationText = stationNames.isEmpty ? "" : " (${stationNames.join(", ")})";

                                  // Style
                                  Color nameColor = colorScheme.onSurface;
                                  Color qtyColor = colorScheme.primary;
                                  TextDecoration? decoration;
                                  String prefix = "";
                                  
                                  if (isDeletion) {
                                     nameColor = colorScheme.error;
                                     qtyColor = colorScheme.error;
                                     prefix = "刪 "; // User request: "刪 A"
                                  } else if (isCancelled) {
                                     nameColor = colorScheme.onSurface; 
                                  }
                                  
                                  // Modifiers Text
                                  final List<dynamic> mods = item['modifiers'] ?? item['selected_modifiers'] ?? [];
                                  final String modText = mods.map((m) => m['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: RichText(
                                            text: TextSpan(
                                              style: TextStyle(
                                                  fontSize: 16, 
                                                  fontWeight: isDeletion ? FontWeight.bold : FontWeight.w500, 
                                                  color: nameColor,
                                                  decoration: decoration,
                                                  fontFamily: 'NotoSansTC'
                                              ),
                                              children: [
                                                TextSpan(text: "$prefix${item['item_name']}"),
                                                if (modText.isNotEmpty)
                                                   TextSpan(
                                                     text: "\n$modText",
                                                     style: TextStyle(color: isDeletion ? Theme.of(context).disabledColor : Colors.grey, fontSize: 13, fontWeight: FontWeight.normal)
                                                   ),
                                                   
                                                // Display Clean Note (remove our hack tag)
                                                if (item['note'] != null && (item['note'] as String).isNotEmpty)
                                                   TextSpan(
                                                     text: "\n備註: ${(item['note'] as String).split('| 刪除:').first.trim()}",
                                                     style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.normal)
                                                   ),

                                                if (stationText.isNotEmpty)
                                                  TextSpan(
                                                    text: stationText,
                                                    style: TextStyle(
                                                      fontSize: 14, 
                                                      color: isDeletion ? colorScheme.error : colorScheme.onSurface.withOpacity(0.6),
                                                      fontWeight: isDeletion ? FontWeight.bold : FontWeight.normal,
                                                      decoration: decoration
                                                    )
                                                  )
                                              ]
                                            )
                                          )
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "x${item['quantity']}",
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: qtyColor),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          "\$${item['price']}",
                                          style: TextStyle(
                                            fontSize: 16, 
                                            color: isDeletion ? colorScheme.error : colorScheme.onSurface,
                                            fontWeight: isDeletion ? FontWeight.bold : FontWeight.normal,
                                            decoration: decoration
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                               ),
                               // Batch Print Button
                               Padding(
                                 padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                 child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _processPrintBatch(batchItems, index + 1),
                                    icon: const Icon(CupertinoIcons.printer, size: 16),
                                    label: const Text("補印此單 (工作站/工單)"),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: theme.dividerColor),
                                      foregroundColor: colorScheme.onSurface,
                                    ),
                                  ),
                                 ),
                               )
                            ],
                          ),
                        ),
                      );
                   }).toList(),

                   // 3. Print Actions (Completed OR Cancelled)
                   // 3. New Collapsible Sections for Completed Orders
                   if (['completed', 'cancelled'].contains(orderData?['status'])) ...[
                      // 3.1 Customer Detail (顧客明細)
                      Container(
                        margin: const EdgeInsets.only(top: 16, bottom: 16),
                        decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text("顧客明細", style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                            children: [
                               Divider(height: 1, color: theme.dividerColor),
                               // Show All Valid Items Summary
                               ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                     final item = items[index];
                                     if (item['status'] == 'cancelled') return const SizedBox.shrink();
                                     // Only show valid items? User said "Customer Detail" -> Receipt.
                                     // Receipt usually shows everything or just valid? Usually valid.
                                     
                                     return Padding(
                                       padding: const EdgeInsets.only(bottom: 8.0),
                                       child: Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                            Expanded(child: Text(item['item_name'], style: const TextStyle(fontSize: 16))),
                                            Text("x${item['quantity']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 16),
                                            Text("\$${item['price']}", style: const TextStyle(fontSize: 16)),
                                         ],
                                       ),
                                     );
                                  },
                               ),
                               Padding(
                                 padding: const EdgeInsets.all(16.0),
                                 child: Column(
                                   children: [
                                     SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _processPrintReceipt,
                                        icon: const Icon(CupertinoIcons.printer),
                                        label: const Text("列印結帳單"),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.all(16),
                                          side: BorderSide(color: colorScheme.primary), 
                                          foregroundColor: colorScheme.primary, // Make it distinct
                                        ),
                                      ),
                                     ),
                                     if (orderData?['ezpay_invoice_number'] != null && orderData?['ezpay_invoice_status']?.toString() == '1') ...[
                                       const SizedBox(height: 12),
                                       SizedBox(
                                         width: double.infinity,
                                         child: FilledButton.icon(
                                           onPressed: _printInvoiceProof,
                                           icon: const Icon(CupertinoIcons.barcode_viewfinder),
                                           label: const Text("印發票證明聯"),
                                           style: FilledButton.styleFrom(
                                             padding: const EdgeInsets.all(16),
                                             backgroundColor: Colors.indigo,
                                           ),
                                         ),
                                       ),
                                       const SizedBox(height: 12),
                                       SizedBox(
                                         width: double.infinity,
                                         child: OutlinedButton.icon(
                                           onPressed: () async {
                                              final bool? confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (c) => AlertDialog(
                                                  title: const Text("發票補印"),
                                                  content: const Text("確定要進行發票補印嗎？補印之證明聯將標記『(補印)』字樣。（註：每張發票僅能擁有一份正本證明聯，補印件不可重複對獎）"),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("取消")),
                                                    FilledButton(
                                                      onPressed: () => Navigator.pop(c, true), 
                                                      child: const Text("確認補印")
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                _printInvoiceProof(isReprint: true);
                                              }
                                           },
                                           icon: const Icon(CupertinoIcons.printer),
                                           label: const Text("補印發票證明聯"),
                                           style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.all(16),
                                              side: const BorderSide(color: Colors.indigo),
                                              foregroundColor: Colors.indigo,
                                           ),
                                         ),
                                       ),
                                     ],
                                      // Retry invoice Logic (Only if tax rate is 5.0)
                                      if (orderData?['status'] == 'completed' && orderData?['ezpay_invoice_number'] == null && (orderData?['tax_snapshot']?['rate'] as num?)?.toDouble() == 5.0) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: _processRetryInvoice,
                                            icon: const Icon(CupertinoIcons.cloud_upload),
                                            label: const Text("補開電子發票"),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.all(16),
                                              backgroundColor: Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "此訂單尚未成功開立發票",
                                          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                   ],
                                 ),
                               )
                            ],
                          ),
                        ),
                      ),

                      // 3.2 Payment Detail (結帳明細)
                      Container(
                        margin: const EdgeInsets.only(bottom: 32),
                        decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text("結帳明細", style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                            children: [
                               Divider(height: 1, color: theme.dividerColor),
                               Padding(
                                 padding: const EdgeInsets.all(16.0),
                                 child: Column(
                                   children: [
                                      _buildInfoRow(context, "支付方式：", orderData?['payment_method'] ?? '-'),
                                      _buildInfoRow(context, "應收金額：", "\$${orderData?['final_amount'] ?? 0}"),
                                      _buildInfoRow(context, "實收金額：", "\$${orderData?['received_amount'] ?? 0}"),
                                      _buildInfoRow(context, "找零金額：", "\$${orderData?['change_amount'] ?? 0}"),
                                      if (orderData?['invoice_number'] != null)
                                         _buildInfoRow(context, "發票號碼：", orderData!['invoice_number']),
                                      if (orderData?['unified_tax_number'] != null)
                                         _buildInfoRow(context, "統一編號：", orderData!['unified_tax_number']),
                                   ],
                                 ),
                               ),
                               Padding(
                                 padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                 child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _processPrintPaymentDetail,
                                    icon: const Icon(CupertinoIcons.list_bullet),
                                    label: const Text("列印結帳明細"),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.all(16),
                                      side: BorderSide(color: colorScheme.primary),
                                      foregroundColor: colorScheme.primary,
                                    ),
                                  ),
                                 ),
                               )
                            ],
                          ),
                        ),
                      ),
                   ] 
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 16))
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500))
          )
        ],
      ),
    );
  }



  Future<void> _processPrintReceipt() async {
      await _processPrintGeneric(isDetail: false);
  }


  Future<void> _processPrintPaymentDetail() async {
      await _processPrintGeneric(isDetail: true);
  }

  Future<void> _processPrintGeneric({required bool isDetail}) async {
      if (orderData == null) return;
      
      setState(() => isLoading = true);
      try {
        final supabase = Supabase.instance.client;
        final shopId = orderData!['shop_id'];
        
        // Fetch Settings
        final settingsRes = await supabase.from('printer_settings').select().eq('shop_id', shopId);
        final settings = List<Map<String, dynamic>>.from(settingsRes);
        
        // Fetch Order Rank
        int orderRank = 0;
        try {
           // We can use repo if available, or just call DataSource directly?
           // We have repo providers in other screens. Here we are using direct supabase + state.
           // To be clean, let's use the Repo instance if attainable, or just call proper logic.
           // Since we don't have Repo injected easily here without refactor, and I added logic to RemoteDataSource/Repo.
           // I'll assume we can use the provider.
           // `import .../ordering_providers.dart` is available?
           // The file imports `auth_providers`. Does it import ordering?
           // File imports `package:gallery205_staff_app/features/ordering/presentation/providers/ordering_providers.dart`?
           // Let's check imports.
           if (mounted) {
               // ref is available
               // orderRank = await ref.read(orderingRepositoryProvider).getOrderRank(widget.orderGroupId);
               // Wait, orderingRepositoryProvider is in `ordering_providers.dart`.
               // I need to check if it is imported.
               // File 1 imports:
               // import 'package:gallery205_staff_app/features/auth/presentation/providers/auth_providers.dart';
               // It does NOT import ordering_providers.
               // I will add import in next tool call or assume I can duplicate logic?
               // Duplicating rank logic here is complex (needs open_id logic).
               // I SHOULD use the Repo.
               // So I will add import if missing.
               // For now, I'll use `ref.read` dynamically? No, type safety.
               // I'll add the import in a separate tool call to be safe? 
               // Or I can add it to this chunk if near top? No, line 867 is far.
               // I will use direct Supabase query here to save round trips/imports?
               // Query:
               final orderRes = await supabase.from('order_groups').select('open_id, created_at').eq('id', widget.orderGroupId).single();
               final String? openId = orderRes['open_id'];
               final String createdAt = orderRes['created_at'];
               if (openId != null) {
                  orderRank = await supabase.from('order_groups').count(CountOption.exact).eq('open_id', openId).lte('created_at', createdAt);
               }
           }
        } catch (_) {}

        // Fetch Tax Settings
        double taxAmount = 0;
        String? taxLabel;
        try {
           final taxRes = await supabase.from('tax_settings').select().eq('shop_id', shopId).maybeSingle();
           if (taxRes != null) {
              final double rate = (taxRes['rate'] as num).toDouble() / 100.0;
              final bool isIncluded = taxRes['is_tax_included'] == true;
              final double total = (orderData!['final_amount'] as num).toDouble();
              
              if (!isIncluded) {
                 // If NOT included (Add-on), we assume final_amount *includes* it? 
                 // Or final_amount = subtotal + tax?
                 // Usually final_amount is what customer pays.
                 // If tax is add-on, tax = subtotal * rate. final = subtotal + tax.
                 // If tax is included, tax = final - (final / (1+rate)).
                 // BUT User says: "If tax is included, DON'T print it."
                 // So we only care if it is EXCLUDED.
                 // If excluded, we usually need to know the tax amount to print.
                 // Assuming 'total_amount' is subtotal? 
                 // orderData has 'final_amount', 'total_amount', 'service_fee'.
                 // We should probably rely on what was stored if possible, or recalculate.
                 // Simplest: Calculate based on final.
                 // If Excluded (Add-on): tax = total_amount * rate?
                 // Let's defer to simple logic: Only show if !isIncluded.
                 // Use total_amount (subtotal) * rate.
                 taxAmount = (orderData!['total_amount'] as num).toDouble() * rate;
                 taxLabel = "稅額 (${(rate*100).toStringAsFixed(0)}%)";
              }
           }
        } catch (_) {}
        
        // Construct OrderGroup object (Minimal for printing)
        final orderGroup = OrderGroup(
          id: widget.orderGroupId,
          status: OrderStatus.completed,
          items: [], 
          shopId: shopId,
        );
        
        final orderContext = OrderContext(
          order: orderGroup,
          tableNames: List<String>.from(orderData!['table_names'] ?? []),
          peopleCount: orderData!['pax'] ?? 0,
          staffName: (ref.read(authStateProvider).value?.name != null && ref.read(authStateProvider).value!.name.trim().isNotEmpty) 
              ? ref.read(authStateProvider).value!.name 
              : (orderData!['staff_name'] ?? (ref.read(authStateProvider).value?.email ?? '')),
        );

        final printerService = PrinterService();
        int count = 0;

        if (isDetail) {
           // Print Payment Detail
           count = await printerService.printPaymentDetails(
             context: orderContext, 
             finalTotal: (orderData!['final_amount'] as num).toDouble(), 
             paymentMethod: orderData!['payment_method'] ?? 'Unknown', 
             receivedAmount: (orderData!['received_amount'] as num?)?.toDouble() ?? 0, 
             changeAmount: (orderData!['change_amount'] as num?)?.toDouble() ?? 0, 
             invoiceNumber: orderData!['invoice_number'], 
             unifiedTaxNumber: orderData!['unified_tax_number'], 
             printerSettings: settings
           );
        } else {
           // Print Customer Receipt (Bill)
           count = await printerService.printBill(
             context: orderContext, 
             items: items, // The raw list of maps
             printerSettings: settings, 
             subtotal: (orderData!['total_amount'] as num).toDouble(), 
             serviceFee: (orderData!['service_fee'] as num?)?.toDouble() ?? 0, 
             discount: (orderData!['discount_amount'] as num?)?.toDouble() ?? 0, 
             finalTotal: (orderData!['final_amount'] as num).toDouble(),
             taxAmount: taxAmount, 
             taxLabel: taxLabel,
             orderSequenceNumber: orderRank, // NEW
           );
        }

        if (mounted) {
           if (count > 0) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("已發送至 $count 台印表機")));
           } else if (count == -1) {
              // No printer configured
              // We can just show SnackBar here as it's less intrusive than dialog for viewing history
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("未設定收據印表機")));
           } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("列印失敗：無法連線至印表機")));
           }
        }

      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("列印失敗: $e")));
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
  }
}
