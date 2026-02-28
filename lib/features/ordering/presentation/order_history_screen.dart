import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/ordering/data/repositories/ordering_repository_impl.dart';
import 'package:gallery205_staff_app/features/ordering/data/datasources/ordering_remote_data_source.dart';
import 'package:gallery205_staff_app/core/models/tax_profile.dart';

class OrderHistoryScreen extends StatefulWidget {
  final bool currentShiftOnly;
  const OrderHistoryScreen({super.key, this.currentShiftOnly = true});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> orders = [];
  DateTime? _selectedDate;
  TaxProfile? _taxProfile; // NEW
  
  // Totals for Current Shift Mode
  double _paidTotal = 0.0;
  double _unpaidTotal = 0.0;
  double _grandTotal = 0.0;
  
  // Map<OrderId, DisplayId> e.g. "uuid" -> "#4-1"
  Map<String, String> _displayIds = {}; 

  // Shift Filtering
  List<Map<String, dynamic>> _shifts = [];
  String? _selectedShiftId;

  @override
  void initState() {
    super.initState();
    if (!widget.currentShiftOnly) {
      _selectedDate = DateTime.now();
    }
    _fetchHistory();
    if (!widget.currentShiftOnly) {
      _fetchShifts();
    }
  }

  Future<void> _fetchShifts() async {
    if (_selectedDate == null) return;
    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final dataSource = OrderingRemoteDataSourceImpl(supabase);
      final repo = OrderingRepositoryImpl(dataSource, prefs);
      
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final shifts = await repo.getShifts(dateStr);
      
      if (mounted) {
        setState(() {
          _shifts = shifts;
          _selectedShiftId = null; // Reset selection on date change
        });
      }
    } catch (e) {
      debugPrint("Error fetching shifts: $e");
    }
  }

  Future<void> _fetchHistory() async {
    setState(() {
      isLoading = true;
      _paidTotal = 0.0;
      _unpaidTotal = 0.0;
      _grandTotal = 0.0;
    });

    try {
      final supabase = Supabase.instance.client;
      dynamic queryBuilder = supabase
          .from('order_groups')
          .select('id, tax_snapshot, table_names, final_amount, total_amount, checkout_time, created_at, status, payment_method, service_fee_rate, discount_amount, note, order_items(price, quantity, status)');

      // 1. Get Open ID (if needed)
      String? currentOpenId;
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      
      // Fetch Tax Profile
      try {
         final dataSource = OrderingRemoteDataSourceImpl(supabase);
         final repo = OrderingRepositoryImpl(dataSource, prefs);
         _taxProfile = await repo.getTaxProfile();
      } catch(e) {
         debugPrint("Error fetching tax profile: $e");
      }
      
      if (shopId != null) {
        try {
           final statusRes = await supabase.rpc('rpc_get_current_cash_status', params: {'p_shop_id': shopId}).maybeSingle();
           if (statusRes != null && statusRes['status'] == 'OPEN') {
              currentOpenId = statusRes['open_id'] as String?;
           }
        } catch(e) {
           debugPrint("Error fetching open_id: $e");
        }
      }


      
      if (shopId != null) {
          queryBuilder = queryBuilder.eq('shop_id', shopId);
      }

      // 2. Build Query
       if (widget.currentShiftOnly) {
        if (currentOpenId != null) {
           queryBuilder = queryBuilder.eq('open_id', currentOpenId);
           queryBuilder = queryBuilder.neq('status', 'merged'); // 隱藏已併單的幽靈單
           queryBuilder = queryBuilder.order('created_at', ascending: false);
        } else {
           if (mounted) setState(() { orders = []; isLoading = false; });
           return;
        }
      } else {
        // History Mode
        queryBuilder = queryBuilder.eq('status', 'completed');
        
        // Filter by Shift if selected
        if (_selectedShiftId != null) {
           queryBuilder = queryBuilder.eq('open_id', _selectedShiftId);
        } else if (_selectedDate != null) {
           // Filter by Date (All Shifts)
           final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
           final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
           queryBuilder = queryBuilder
               .gte('checkout_time', startOfDay.toIso8601String())
               .lte('checkout_time', endOfDay.toIso8601String());
        }
        
        queryBuilder = queryBuilder.order('checkout_time', ascending: false).limit(50);
      }

      final res = await queryBuilder;
      final fetchedOrders = List<Map<String, dynamic>>.from(res);

      // 3. Calculate Totals (Only for Current Shift View)
      if (widget.currentShiftOnly) {
         // ... (existing logic)
         for (var order in fetchedOrders) {
           final isCompleted = order['status'] == 'completed';
           final finalAmount = (order['final_amount'] as num?)?.toDouble() ?? 0.0;
           
           double currentAmount = 0.0;
           if (isCompleted) {
              currentAmount = finalAmount;
           } else {
              currentAmount = _calculateOrderTotal(order);
           }
           
           if (isCompleted) {
             _paidTotal += finalAmount;
           } else if (order['status'] != 'cancelled') {
             _unpaidTotal += currentAmount;
           }
         }
         _grandTotal = _paidTotal + _unpaidTotal;
      }
      
      // 4. Calculate Display IDs (Split Bill Support)
      _calculateDisplayIds(fetchedOrders);

      if (mounted) {
        setState(() {
          orders = fetchedOrders;
        });
      }
    } catch (e) {
      debugPrint("Fetch history error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _calculateDisplayIds(List<Map<String, dynamic>> allOrders) {
     _displayIds.clear();
     
     // 1. Sort by CreatedAt ASC for valid numbering
     final sorted = List<Map<String, dynamic>>.from(allOrders);
     sorted.sort((a, b) {
        final tA = DateTime.parse(a['created_at']);
        final tB = DateTime.parse(b['created_at']);
        return tA.compareTo(tB);
     });
     
     int mainCounter = 1;
     final Map<String, int> subCounters = {}; // ParentId -> count
     
     for (var order in sorted) {
        final String id = order['id'];
        final String note = order['note'] ?? '';
        
        // Check for [Parent:ID]
        // Regex: \[Parent:([a-f0-9\-]+)\]
        final RegExp parentReg = RegExp(r'\[Parent:([a-f0-9\-]+)\]');
        final match = parentReg.firstMatch(note);
        
        if (match != null) {
           final String parentId = match.group(1)!;
           
           // Check if we have seen parent (and thus assigned an ID)
           // If parent is not in this list (e.g. filtered out?), fall back to main counter.
           // However, if we are in Current Shift, we should see it.
           // But wait, if parent is CANCELLED (e.g. fully split out?), it might be gone?
           // Or user filters? Current Shift shows all? 
           // If parent is active or completed, it's there.
           // If parent was "merged back" -> cancelled.
           // If parent was "fully split" -> usually parent stays?
           
           if (_displayIds.containsKey(parentId)) {
              // Found Parent
              subCounters[parentId] = (subCounters[parentId] ?? 0) + 1;
              final parentDisplay = _displayIds[parentId]!.replaceAll('#', '');
              _displayIds[id] = "#$parentDisplay-${subCounters[parentId]}";
              continue;
           }
        }
        
        // Main Order
        _displayIds[id] = "#$mainCounter";
        mainCounter++;
     }
  }

  double _calculateOrderTotal(Map<String, dynamic> order) {
      double itemSubtotal = 0.0;
      if (order['order_items'] != null) {
          final items = order['order_items'] as List;
          for (var i in items) {
              if (i['status'] != 'cancelled') {
                  final p = (i['price'] as num?)?.toDouble() ?? 0.0;
                  final q = (i['quantity'] as num?)?.toInt() ?? 1;
                  itemSubtotal += p * q;
              }
          }
      }
      
      // Calculate Service Fee
      final rate = (order['service_fee_rate'] as num?)?.toInt() ?? 10;
      final totalWithService = itemSubtotal * (1 + rate / 100.0);
      
      // Subtract Discount
      final discount = (order['discount_amount'] as num?)?.toDouble() ?? 0.0;
      final finalTotal = totalWithService - discount;

      // If we have items (or a discount applied), return result
      if (itemSubtotal > 0 || discount > 0) {
         return finalTotal < 0 ? 0 : finalTotal.roundToDouble();
      }
      
      // Fallback
      return (order['total_amount'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.currentShiftOnly ? "本班次交易紀錄" : "過往交易紀錄"),
        backgroundColor: theme.cardColor,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.pop(),
        ),
        actions: !widget.currentShiftOnly ? [
          // Shift Dropdown
          if (_shifts.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedShiftId,
                hint: const Text("全部班次", style: TextStyle(color: Colors.white)), // Assuming dark theme default or contrast? AppBar theme usually handles it? 
                // Wait, text color depends on AppBar. 
                // Let's use standard Text.
                dropdownColor: theme.cardColor,
                icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                items: [
                   const DropdownMenuItem<String?>(
                     value: null,
                     child: Text("全部班次"),
                   ),
                   ..._shifts.map((s) {
                      final count = s['open_count'];
                      // created_at unavailable
                      return DropdownMenuItem<String?>(
                        value: s['id'],
                        child: Text("第 $count 班"),
                      );
                   }),
                ],
                onChanged: (val) {
                   setState(() => _selectedShiftId = val);
                   _fetchHistory();
                },
              ),
            ),
          const SizedBox(width: 8),

          TextButton.icon(
            icon: const Icon(CupertinoIcons.calendar),
            label: Text(_selectedDate == null ? "選擇日期" : DateFormat('yyyy/MM/dd').format(_selectedDate!)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                await _fetchShifts();
                _fetchHistory();
              }
            },
          ),
          const SizedBox(width: 8),
        ] : null,
      ),
      body: isLoading 
        ? const Center(child: CupertinoActivityIndicator())
        : Column(
            children: [
              if (widget.currentShiftOnly) _buildSummaryHeader(theme),
              if (widget.currentShiftOnly) _buildListHeader(theme),
              Expanded(
                child: orders.isEmpty 
                  ? Center(child: Text("尚無交易紀錄", style: TextStyle(color: colorScheme.onSurface)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, index) {
                         if (widget.currentShiftOnly) {
                           return _buildLogItem(orders[index], index, orders.length, theme);
                         } else {
                           return _buildHistoryItem(orders[index], theme);
                         }
                      },
                    ),
              ),
            ],
          ),
    );
  }

  Widget _buildSummaryHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryCard(theme, "已結帳總額", _paidTotal, Colors.green),
          _buildSummaryCard(theme, "未結帳總額", _unpaidTotal, Colors.orange),
          _buildSummaryCard(theme, "今日目前營業額", _grandTotal, theme.colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String label, double amount, Color valueColor) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
        const SizedBox(height: 5),
        Text("\$${amount.toStringAsFixed(0)}", style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildListHeader(ThemeData theme) {
    final style = TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text("時間", style: style)),
          Expanded(flex: 2, child: Text("類型", style: style)), 
          Expanded(flex: 2, child: Text("編號", style: style)), // New Column
          Expanded(flex: 3, child: Text("桌號", style: style)), // Split Column
          Expanded(flex: 3, child: Text("狀態", style: style)),
          Expanded(flex: 2, child: Text("稅額", style: style, textAlign: TextAlign.right)), // NEW
          Expanded(flex: 4, child: Text("訂單總額", style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> order, int index, int totalCount, ThemeData theme) {
    final ca = order['created_at'] != null ? DateTime.parse(order['created_at']).toLocal() : DateTime.now();
    final timeStr = DateFormat('HH:mm').format(ca);
    
    final tables = (order['table_names'] as List?)?.join(',') ?? '-';
    final isTakeout = tables == '-' || tables.isEmpty;
    final displayType = isTakeout ? '外帶' : '內用'; 
    
    // Calculate Sequential Order Number
    final displayId = _displayIds[order['id']] ?? "#?";
    
    final displayTable = tables.isNotEmpty ? tables : "-";

    final status = order['status'] ?? 'unknown';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';
    
    String displayStatus;
    Color statusColor;
    if (isCompleted) {
      displayStatus = '已結帳';
      statusColor = Colors.green;
    } else if (isCancelled) {
      displayStatus = '已作廢';
      statusColor = Colors.red;
    } else {
      displayStatus = '進行中';
      statusColor = Colors.orange;
    }

    final amount = isCompleted 
        ? (order['final_amount'] as num?)?.toDouble() ?? 0
        : _calculateOrderTotal(order);

    return InkWell(
      onTap: () async {
        // Allow tapping Cancelled/Completed orders to view details
        if (isCompleted || isCancelled) {
           final bool? result = await context.push<bool>('/transactionDetail', extra: {
             'orderGroupId': order['id'], 
             'transactionId': displayId
           });
           
           if (result == true && mounted) {
             _fetchHistory(); // Refresh list on return
           }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(timeStr, style: TextStyle(color: theme.colorScheme.onSurface))),
            Expanded(flex: 2, child: Text(displayType, style: TextStyle(color: theme.colorScheme.onSurface))),
            Expanded(flex: 2, child: Text(displayId, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text(displayTable, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold))),
            Expanded(flex: 3, child: Text(displayStatus, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
            
            // Tax Column
            Expanded(flex: 2, child: _buildTaxCell(theme, amount, order['discount_amount'], order)),

            Expanded(
              flex: 4, 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text("\$${amount.toStringAsFixed(0)}", style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  if (isCompleted) 
                    Icon(CupertinoIcons.chevron_right, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.5))
                  else
                    const SizedBox(width: 14), 
                ],
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> order, ThemeData theme) {
    final time = order['checkout_time'] != null 
        ? DateFormat('MM/dd HH:mm').format(DateTime.parse(order['checkout_time']).toLocal())
        : 'Unknown Time';
    final tables = (order['table_names'] as List?)?.join(',') ?? 'Unknown Table';
    final amount = (order['final_amount'] as num?)?.toDouble() ?? 0;
    final method = order['payment_method'] ?? '-';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text("桌號: $tables", style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("$time  |  $method"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("\$${amount.toStringAsFixed(0)}", 
            style: TextStyle(fontSize: 18, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)
          ),
          const SizedBox(width: 10),
          const Icon(CupertinoIcons.chevron_right, size: 16),
        ],
      ),
      onTap: () async {
         final bool? result = await context.push<bool>('/transactionDetail', extra: {
             'orderGroupId': order['id'], 
             'transactionId': '?',
             'isReadOnly': true, // Historical items are read-only
           });
           
         if (result == true && mounted) {
             _fetchHistory(); 
         }
      },
    );
  }
  Widget _buildTaxCell(ThemeData theme, double finalAmount, dynamic discountVal, Map<String, dynamic> order) {
      double rate = 0;
      
      // 1. Try Tax Snapshot (Historical)
      if (order['tax_snapshot'] != null) {
         final snap = order['tax_snapshot'];
         if (snap is Map) {
             rate = (snap['rate'] as num?)?.toDouble() ?? 0;
         }
      } 
      // 2. Fallback to Current Profile (Legacy Orders)
      else if (_taxProfile != null) {
         rate = _taxProfile!.rate;
      }

      if (rate == 0) {
         return Text("-", textAlign: TextAlign.right, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)));
      }
      
      double discount = 0.0;
      if (discountVal is num) discount = discountVal.toDouble();
      
      final preDiscount = finalAmount + discount;
      final tax = preDiscount - (preDiscount / (1 + (rate / 100)));
      
      return Text(
        "\$${tax.toStringAsFixed(0)}", 
        textAlign: TextAlign.right,
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)
      );
  }
}