// lib/features/reporting/presentation/settlement_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 2. SettlementDetailScreen
// -------------------------------------------------------------------

class SettlementDetailScreen extends StatefulWidget {
  final String transactionId; 

  const SettlementDetailScreen({super.key, required this.transactionId});

  @override
  State<SettlementDetailScreen> createState() => _SettlementDetailScreenState();
}

class _SettlementDetailScreenState extends State<SettlementDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _txData; 
  Map<String, dynamic>? _openData; 
  final currencyFormat = NumberFormat('#,##0', 'en_US'); 

  final List<int> _denominations = [2000, 1000, 500, 200, 100, 50, 10, 5, 1];

  @override
  void initState() {
    super.initState();
    _loadTransactionDetails();
  }

  Future<void> _loadTransactionDetails() async {
    try {
      final res = await Supabase.instance.client
          .from('sales_transactions')
          .select('*, open_id(*)') 
          .eq('id', widget.transactionId)
          .single();

      setState(() {
        _txData = res;
        _openData = res['open_id'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load details: ${e.toString()}')),
        );
        context.pop(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    
    if (_isLoading || _txData == null || _openData == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
      );
    }
    
    // --- 資料解析 & 計算 ---
    final openDate = DateTime.parse(_openData!['open_date']);
    final openCount = _openData!['open_count'] as int;
    
    // 1. 基礎數據
    final revenueTotal = (_txData!['revenue_total'] as num? ?? 0);
    final costTotal = (_txData!['cost_total'] as num? ?? 0); 
    final openingCash = (_openData!['petty_cash_amount'] as num? ?? 0);
    final cashDifference = (_txData!['expected_cash_difference'] as num? ?? 0);
    final deposit = (_txData!['deposit_amount'] as num? ?? 0);
    
    // ✅ 新增：實際點收現金 (closed_cash_amount)
    final closedCashAmount = (_txData!['closed_cash_amount'] as num? ?? 0);

    // 2. 取得非現金支付列表 (JSON)
    final details = _txData!['details_json'] as Map<String, dynamic>? ?? {};

    // 3. 計算非現金支付總和
    double nonCashTotal = 0.0;
    details.forEach((key, value) {
      nonCashTotal += (value as num? ?? 0.0).toDouble();
    });

    // 4. 計算應收付現 (Receivable Cash)
    // 公式：總營收 - 總成本(現金支出) - 非現金支付總和
    final receivableCash = revenueTotal - costTotal - nonCashTotal;

    // 5. 計算預期總現金 (Total Expected Cash)
    // 公式：期初零用金 + 應收付現
    final totalExpectedCash = openingCash + receivableCash;

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
                        '${DateFormat('yyyy/MM/dd').format(openDate)} (${l10n.cashFlowLabelShift(openCount)})',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 26, 
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

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // --- 1. Daily Revenue Summary ---
                    Text(
                      l10n.settlementDetailDailyRevenueSummary,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow(l10n.settlementDetailTotalRevenue, revenueTotal),
                    _buildSummaryRow(l10n.settlementDetailTotalCost, costTotal),
                    _buildSummaryRow(l10n.cashSettlementOpeningCash, openingCash),
                    _buildSummaryRow(l10n.cashSettlementReceivableCash, receivableCash),
                    _buildSummaryRow(l10n.cashSettlementTotalExpectedCash, totalExpectedCash),
                    _buildSummaryRow(l10n.cashFlowLabelDifference, cashDifference),
                    
                    // ✅ 新增：Today's Cash Total
                    _buildSummaryRow(l10n.cashSettlementTodaysCashCount, closedCashAmount),
                    
                    const SizedBox(height: 20),
                    Divider(color: colorScheme.outlineVariant, thickness: 1),
                    const SizedBox(height: 20),

                    // --- 2. Payment Details ---
                    Text(
                      l10n.settlementDetailPaymentDetails,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildSummaryRow(l10n.settlementDetailCash, receivableCash),
                    
                    ...details.entries.map((entry) {
                      final key = entry.key;
                      final value = entry.value as num? ?? 0;
                      return _buildSummaryRow('$key:', value); 
                    }),

                    _buildSummaryRow(l10n.settlementDetailTodayDeposit, deposit),
                    
                    const SizedBox(height: 20),
                    Divider(color: colorScheme.outlineVariant, thickness: 1),
                    const SizedBox(height: 20),

                    // --- 3. Cash Count (Table) ---
                    Text(
                      l10n.settlementDetailCashCount,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    
                    // Table Header
                    Row(
                      children: [
                        Expanded(flex: 2, child: Text(l10n.settlementDetailValue, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600))),
                        Expanded(flex: 1, child: Text(l10n.commonAmount, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text(l10n.settlementDetailSummary, textAlign: TextAlign.right, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Table Rows
                    ..._denominations.map((value) {
                      final count = (_txData!['cash_$value'] as int? ?? 0);
                      final total = count * value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text('\$ ${currencyFormat.format(value)}', style: TextStyle(color: colorScheme.onSurface, fontSize: 16))),
                            Expanded(flex: 1, child: Text(count.toString(), textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface, fontSize: 16))),
                            Expanded(flex: 2, child: Text(total == 0 ? '0' : '\$ ${currencyFormat.format(total)}', textAlign: TextAlign.right, style: TextStyle(color: colorScheme.onSurface, fontSize: 16))),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 10),
                    
                    // Total Row
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${l10n.cashSettlementTotal} ${_txData!['closed_cash_amount']}', 
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 輔助 Widget
  Widget _buildSummaryRow(String label, num value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            value % 1 == 0 
                ? currencyFormat.format(value) 
                : NumberFormat('#,##0.00', 'en_US').format(value),
            style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}