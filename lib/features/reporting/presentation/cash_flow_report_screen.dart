// lib/features/reporting/presentation/cash_flow_report_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 2. CashFlowReportScreen
// -------------------------------------------------------------------

class CashFlowReportScreen extends StatefulWidget {
  const CashFlowReportScreen({super.key});

  @override
  State<CashFlowReportScreen> createState() => _CashFlowReportScreenState();
}

class _CashFlowReportScreenState extends State<CashFlowReportScreen> {
  String? _shopId;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  
  List<Map<String, dynamic>> _settlements = [];
  double _monthTotalRevenue = 0.0;
  double _monthTotalDifference = 0.0; 

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

    try {
      final res = await Supabase.instance.client
          .from('sales_transactions')
          .select(
            'id, transaction_date, revenue_total, cost_total, expected_cash_difference, '
            'open_id!inner(open_count, open_date)' 
          ) 
          .eq('shop_id', _shopId!)
          .gte('open_id.open_date', DateFormat('yyyy-MM-dd').format(firstDayOfMonth))
          .lte('open_id.open_date', DateFormat('yyyy-MM-dd').format(lastDayOfMonth))
          .order('transaction_date', ascending: false);

      final settlements = List<Map<String, dynamic>>.from(res);
      
      double totalRevenue = 0.0;
      double totalDifference = 0.0;

      for (final tx in settlements) {
        totalRevenue += (tx['revenue_total'] as num? ?? 0.0).toDouble();
        totalDifference += (tx['expected_cash_difference'] as num? ?? 0.0).toDouble();
      }

      if (mounted) {
        setState(() {
          _settlements = settlements;
          _monthTotalRevenue = totalRevenue;
          _monthTotalDifference = totalDifference;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading report: $e');
      setState(() => _isLoading = false);
    }
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
  
  void _goToDetail(Map<String, dynamic> settlement) {
    final txId = settlement['id'] as String;
    context.push('/settlementDetail', extra: txId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyFormat = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- Header (Title) ---
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
                        l10n.cashFlowTitle, 
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

            // --- Summary Cards ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  // Monthly Revenue Card
                  Expanded(
                    child: Container(
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
                            l10n.cashFlowMonthlyRevenue, 
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '\$ ${currencyFormat.format(_monthTotalRevenue)}',
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Monthly Difference Card
                  Expanded(
                    child: Container(
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
                            l10n.cashFlowMonthlyDifference, 
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '\$ ${currencyFormat.format(_monthTotalDifference)}',
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // --- Daily List ---
            Expanded(
              child: _isLoading
                  ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
                  : _settlements.isEmpty
                      ? Center(child: Text(l10n.cashFlowNoRecords, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)))) 
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _settlements.length,
                          itemBuilder: (context, index) {
                            final tx = _settlements[index];
                            
                            final openData = tx['open_id'] as Map<String, dynamic>? ?? {};
                            final openDateStr = openData['open_date'] as String?;
                            
                            final date = openDateStr != null 
                                ? DateTime.parse(openDateStr) 
                                : DateTime.parse(tx['transaction_date']);
                                
                            final revenue = (tx['revenue_total'] as num? ?? 0.0);
                            final cost = (tx['cost_total'] as num? ?? 0.0);
                            final difference = (tx['expected_cash_difference'] as num? ?? 0.0);
                            final openCount = openData['open_count'] ?? 1;

                            return GestureDetector(
                              onTap: () => _goToDetail(tx),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Date & Shift
                                    Text(
                                      '${DateFormat.yMMMd(l10n.localeName).add_E().format(date)} (${l10n.cashFlowLabelShift(openCount)})', 
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 10),
                                    Divider(height: 1, color: colorScheme.outlineVariant, thickness: 1),
                                    const SizedBox(height: 10),
                                    
                                    // Rows
                                    _buildRow(l10n.cashFlowLabelRevenue, currencyFormat.format(revenue)), 
                                    const SizedBox(height: 6),
                                    _buildRow(l10n.cashFlowLabelCost, currencyFormat.format(cost)), 
                                    const SizedBox(height: 6),
                                    _buildRow(l10n.cashFlowLabelDifference, currencyFormat.format(difference)), 
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

  Widget _buildRow(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '\$ $value',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}