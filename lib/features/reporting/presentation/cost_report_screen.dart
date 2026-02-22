// lib/features/reporting/presentation/cost_report_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 2. CostReportScreen
// -------------------------------------------------------------------

class CostReportScreen extends StatefulWidget {
  const CostReportScreen({super.key});

  @override
  State<CostReportScreen> createState() => _CostReportScreenState();
}

class _CostReportScreenState extends State<CostReportScreen> {
  String? _shopId;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  
  List<Map<String, dynamic>> _shiftSummaries = [];
  double _monthTotalCost = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }
    await _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final res = await Supabase.instance.client
        .from('sales_transactions')
        .select('id, transaction_date, cost_total, open_id!inner(open_count, open_date)') 
        .eq('shop_id', _shopId!)
        .gte('open_id.open_date', DateFormat('yyyy-MM-dd').format(firstDayOfMonth))
        .lte('open_id.open_date', DateFormat('yyyy-MM-dd').format(lastDayOfMonth))
        .order('transaction_date', ascending: false);

    final closedSummaries = List<Map<String, dynamic>>.from(res);
    double monthTotal = 0.0;
    
    final List<Map<String, dynamic>> summaries = closedSummaries.map((tx) {
      final openData = tx['open_id'] as Map<String, dynamic>? ?? {};
      final totalCost = (tx['cost_total'] as num? ?? 0.0).toDouble();
      monthTotal += totalCost;

      final String displayDate = openData['open_date'] ?? tx['transaction_date'];

      return {
        'transaction_id': tx['id'],
        'summary_date': displayDate, 
        'open_count': openData['open_count'] ?? 1,
        'total_cost': totalCost,
        'status': 'Closed',
        'open_id': null, 
      };
    }).toList();

    // -----------------------------------------------------------
    // 檢查「今日未關帳」並計算即時成本
    // -----------------------------------------------------------
    
    if (_selectedMonth.year == DateTime.now().year && _selectedMonth.month == DateTime.now().month) {
        final dynamic response = await Supabase.instance.client.rpc(
          'rpc_get_current_cash_status',
          params: {'p_shop_id': _shopId}
        );

        Map<String, dynamic>? statusData;
        if (response is List && response.isNotEmpty) {
          statusData = response.first as Map<String, dynamic>;
        } else if (response is Map) {
          statusData = response as Map<String, dynamic>;
        }

        final String? activeOpenId = (statusData != null && statusData['status'] == 'OPEN') 
            ? statusData['open_id'] as String? 
            : null;

        if (activeOpenId != null) { 
            final costRes = await Supabase.instance.client
                .from('expense_logs')
                .select('amount')
                .eq('shop_id', _shopId!)
                .eq('open_id', activeOpenId); 
                
            final todayTotal = costRes.fold(0.0, (sum, row) => sum + (row['amount'] as num? ?? 0.0));
            
            final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

            summaries.add({
                'transaction_id': null, 
                'summary_date': todayStr,
                'open_count': 0, 
                'total_cost': todayTotal.toDouble(),
                'status': "Open",
                'open_id': activeOpenId, 
            });
            
            monthTotal += todayTotal.toDouble();
        }
    }
    
    summaries.sort((a, b) {
      int dateCompare = (b['summary_date'] as String).compareTo(a['summary_date'] as String);
      if (dateCompare != 0) return dateCompare;
      
      bool aIsUnclosed = (a['open_count'] as int) == 0;
      bool bIsUnclosed = (b['open_count'] as int) == 0;
      if (aIsUnclosed && !bIsUnclosed) return -1;
      if (!aIsUnclosed && bIsUnclosed) return 1;
      
      return (b['open_count'] as int).compareTo(a['open_count'] as int);
    });

    setState(() {
      _shiftSummaries = summaries; 
      _monthTotalCost = monthTotal;
      _isLoading = false;
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
    _loadReportData();
  }

  void _showMonthPicker() {
    final l10n = AppLocalizations.of(context)!;
    DateTime tempDate = _selectedMonth;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: theme.brightness,
                    textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(color: colorScheme.onSurface)
                    )
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.monthYear,
                    initialDateTime: _selectedMonth,
                    onDateTimeChanged: (DateTime newDate) {
                      tempDate = DateTime(newDate.year, newDate.month);
                    },
                  ),
                ),
              ),
              CupertinoButton(
                child: Text(l10n.commonConfirm, style: TextStyle(color: colorScheme.primary)), 
                onPressed: () {
                  context.pop();
                  setState(() => _selectedMonth = tempDate);
                  _loadReportData(); 
                },
              )
            ],
          ),
        );
      },
    );
  }
  
  void _goToDetail(Map<String, dynamic> summary) {
    final l10n = AppLocalizations.of(context)!;
    final totalCost = (summary['total_cost'] as num? ?? 0.0);

    if (totalCost == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.costReportNoRecordsShift), 
          backgroundColor: Colors.grey,
        ),
      );
      return; 
    }
    
    final txId = summary['transaction_id'] as String?;
    final date = summary['summary_date'] as String;
    final openId = summary['open_id'] as String?;

    context.push(
      '/costDetails',
      extra: {
        'transaction_id': txId, 
        'targetDate': date,
        'open_id': openId, 
      }, 
    ).then((_) => _loadReportData()); 
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyFormat = NumberFormat('#,###', 'zh_TW');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 32),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.costReportTitle, 
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32), 
                ],
              ),
            ),

            // --- Month Navigator ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 32),
                    onPressed: () => _changeMonth(-1),
                  ),
                  GestureDetector(
                    onTap: _showMonthPicker,
                    child: Text(
                      DateFormat('yyyy/MM').format(_selectedMonth),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface, size: 32),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),

            // --- Total Summary Card ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                width: double.infinity,
                height: 118,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.costReportMonthlyTotal, 
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '\$ ${currencyFormat.format(_monthTotalCost)}',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 30, 
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // --- Cost List ---
            Expanded(
              child: _isLoading
                  ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
                  : _shiftSummaries.isEmpty
                      ? Center(child: Text(l10n.costReportNoRecords, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)))) 
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _shiftSummaries.length,
                          itemBuilder: (context, index) {
                            final summary = _shiftSummaries[index];
                            final date = DateTime.parse(summary['summary_date']);
                            final totalCost = (summary['total_cost'] as num? ?? 0.0);
                            final openCount = summary['open_count'] as int;
                            final status = summary['status'] as String;

                            final String title = (openCount == 0)
                                ? '${DateFormat.yMMMd(l10n.localeName).add_E().format(date)} ($status)' 
                                : '${DateFormat.yMMMd(l10n.localeName).add_E().format(date)} (${l10n.cashFlowLabelShift(openCount)})'; 
                            
                            final Color titleColor = (openCount == 0) ? Colors.orangeAccent : colorScheme.onSurface;

                            return GestureDetector(
                              onTap: () => _goToDetail(summary),
                              child: Container(
                                height: 67,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 上方日期
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: titleColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // 下方金額
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          l10n.costReportLabelTotalCost, 
                                          style: TextStyle(
                                            color: colorScheme.onSurface,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '\$ ${currencyFormat.format(totalCost)}',
                                          style: TextStyle(
                                            color: colorScheme.onSurface,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}