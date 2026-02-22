// lib/features/reporting/presentation/cost_dashboard_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// Chart Colors
const List<Color> _pieColors = [
  Color(0xFF43A047), // Green
  Color(0xFF1E88E5), // Blue
  Color(0xFFFDD835), // Yellow
  Color(0xFFE53935), // Red
  Color(0xFF8E24AA), // Purple
  Color(0xFF00ACC1), // Cyan
  Color(0xFFFFB300), // Orange
];

class CostDashboardScreen extends StatefulWidget {
  const CostDashboardScreen({super.key});

  @override
  State<CostDashboardScreen> createState() => _CostDashboardScreenState();
}

class _CostDashboardScreenState extends State<CostDashboardScreen> {
  String? _shopId;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  double _totalRevenue = 0.0;
  double _cogs = 0.0;           
  double _grossProfit = 0.0;
  double _grossMargin = 0.0; 
  double _opex = 0.0;           
  double _opIncome = 0.0;       
  double _netIncome = 0.0;
  double _netMargin = 0.0;   

  List<Map<String, dynamic>> _pieChartData = [];
  Map<String, String> _categoryTypeMap = {};

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
    
    await _fetchCategoryMap();
    await _loadDashboardData();
  }

  Future<void> _fetchCategoryMap() async {
    try {
      final res = await Supabase.instance.client
          .from('expense_categories')
          .select('name, type')
          .eq('shop_id', _shopId!);
      
      final Map<String, String> map = {};
      for (var item in res) {
        map[(item['name'] as String).trim()] = item['type'] as String; 
      }
      _categoryTypeMap = map;
    } catch (e) {
      debugPrint('Error fetching category map: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    
    final startDateStr = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
    final lastDateStr = DateFormat('yyyy-MM-dd').format(lastDayOfMonth);

    try {
      // ====================================================
      // A. 計算 Total Revenue
      // ====================================================
      // ✅ 修改：透過 open_id 關聯查詢 open_date，確保跨日營收歸屬正確
      final revenueRes = await Supabase.instance.client
          .from('sales_transactions')
          .select('revenue_total, open_id!inner(open_date)')
          .eq('shop_id', _shopId!)
          .gte('open_id.open_date', startDateStr)
          .lte('open_id.open_date', lastDateStr);
      
      double revenue = 0.0;
      for (var tx in revenueRes) {
        revenue += (tx['revenue_total'] as num? ?? 0.0).toDouble();
      }

      // ====================================================
      // B. 計算 Costs
      // ====================================================
      
      // 1. 日常成本 (Daily Costs) - 有 open_id 的
      // ✅ 修改：透過 open_id 關聯查詢 open_date
      final dailyCostRes = await Supabase.instance.client
          .from('expense_logs')
          .select('category, amount, open_id!inner(open_date)') 
          .eq('shop_id', _shopId!)
          .not('open_id', 'is', null) 
          .gte('open_id.open_date', startDateStr)
          .lte('open_id.open_date', lastDateStr);

      // 2. 月結成本 (Monthly Costs) - 無 open_id 的
      // 維持原樣：使用 incurred_date (因為這些通常不屬於特定班次)
      final monthlyCostRes = await Supabase.instance.client
          .from('expense_logs')
          .select('category, amount')
          .eq('shop_id', _shopId!)
          .filter('open_id', 'is', null) 
          .gte('incurred_date', startDateStr)
          .lte('incurred_date', lastDateStr);

      final allCosts = [
        ...List<Map<String, dynamic>>.from(dailyCostRes),
        ...List<Map<String, dynamic>>.from(monthlyCostRes)
      ];

      // ====================================================
      // C. 分類計算 (COGS vs OPEX)
      // ====================================================
      double cogs = 0.0;
      double opex = 0.0;
      final Map<String, double> categorySum = {};

      for (var log in allCosts) {
        final String rawCategory = log['category'] ?? 'Unknown';
        final String category = rawCategory.trim(); 
        final double amount = (log['amount'] as num? ?? 0.0).toDouble();
        
        categorySum.update(category, (value) => value + amount, ifAbsent: () => amount);

        String type = _categoryTypeMap[category] ?? 'UNKNOWN';
        if (type == 'UNKNOWN') {
           type = 'OPEX'; 
        }
        
        if (type == 'COGS') {
          cogs += amount;
        } else {
          opex += amount;
        }
      }

      // ====================================================
      // D. 計算指標與比率
      // ====================================================
      final grossProfit = revenue - cogs;
      final opIncome = grossProfit - opex;
      final netIncome = opIncome; 

      // ✅ 計算毛利率與淨利率 (防呆：營收為 0 時比率為 0)
      final grossMargin = revenue == 0 ? 0.0 : (grossProfit / revenue) * 100;
      final netMargin = revenue == 0 ? 0.0 : (netIncome / revenue) * 100;

      // ====================================================
      // E. 準備圓餅圖列表
      // ====================================================
      final List<Map<String, dynamic>> pieData = categorySum.entries.map((e) {
        return {'category': e.key, 'amount': e.value};
      }).toList();
      
      pieData.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
          _cogs = cogs;
          _grossProfit = grossProfit;
          _grossMargin = grossMargin; 
          _opex = opex;
          _opIncome = opIncome;
          _netIncome = netIncome;
          _netMargin = netMargin;     
          _pieChartData = pieData;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.dashboardErrorLoad(e.toString()))), 
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
    _loadDashboardData();
  }

  void _showMonthPicker() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    DateTime tempDate = _selectedMonth;
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
                  data: CupertinoThemeData(brightness: theme.brightness),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.monthYear,
                    initialDateTime: _selectedMonth,
                    maximumDate: DateTime.now().add(const Duration(days: 365)),
                    onDateTimeChanged: (DateTime newDate) {
                      tempDate = DateTime(newDate.year, newDate.month);
                    },
                  ),
                ),
              ),
              CupertinoButton(
                child: Text(l10n.commonConfirm, style: TextStyle(color: colorScheme.onSurface)), 
                onPressed: () {
                  context.pop();
                  setState(() => _selectedMonth = tempDate);
                  _loadDashboardData(); 
                },
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
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
                        l10n.dashboardTitle, 
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    child: Icon(CupertinoIcons.calendar, color: colorScheme.onSurface, size: 28),
                    onPressed: _showMonthPicker,
                  ),
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

            // --- Content ---
            Expanded(
              child: _isLoading
                  ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        children: [
                          // 1. 核心指標 (GridView)
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.4, 
                            children: [
                              _KpiCard(title: l10n.dashboardTotalRevenue, value: _totalRevenue), 
                              _KpiCard(title: l10n.dashboardCogs, value: _cogs), 
                              _KpiCard(title: l10n.dashboardGrossProfit, value: _grossProfit), 
                              // ✅ 毛利率 (顯示 %)
                              _KpiCard(title: l10n.dashboardGrossMargin, value: _grossMargin, isPercentage: true), 
                              
                              _KpiCard(title: l10n.dashboardOpex, value: _opex), 
                              _KpiCard(title: l10n.dashboardOpIncome, value: _opIncome), 
                              _KpiCard(title: l10n.dashboardNetIncome, value: _netIncome), 
                              // ✅ 淨利率 (顯示 %)
                              _KpiCard(title: l10n.dashboardNetProfitMargin, value: _netMargin, isPercentage: true), 
                            ],
                          ),

                          const SizedBox(height: 30),

                          // 2. 圓餅圖
                          SizedBox(
                            height: 300,
                            child: _pieChartData.isEmpty
                                ? Center(child: Text(l10n.dashboardNoCostData, style: const TextStyle(color: Colors.grey))) 
                                : PieChart(
                                    PieChartData(
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 70,
                                      sections: List.generate(_pieChartData.length, (i) {
                                        final data = _pieChartData[i];
                                        final amount = data['amount'] as double;
                                        final total = _cogs + _opex;
                                        final percentage = total == 0 ? 0 : (amount / total) * 100;
                                        
                                        return PieChartSectionData(
                                          color: _pieColors[i % _pieColors.length],
                                          value: amount,
                                          title: '${percentage.toStringAsFixed(0)}%',
                                          radius: 60,
                                          titleStyle: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                          ),
                          
                          // 3. 圓餅圖圖例
                          const SizedBox(height: 20),
                          if (_pieChartData.isNotEmpty)
                             Wrap(
                               spacing: 16,
                               runSpacing: 8,
                               alignment: WrapAlignment.center,
                               children: List.generate(_pieChartData.length, (i) {
                                  final data = _pieChartData[i];
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12, height: 12,
                                        decoration: BoxDecoration(
                                          color: _pieColors[i % _pieColors.length],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        data['category'],
                                        style: TextStyle(color: colorScheme.onSurface, fontSize: 12),
                                      ),
                                    ],
                                  );
                               }),
                             ),
                          
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 自訂元件 (KPI Card)
// -------------------------------------------------------------------

class _KpiCard extends StatelessWidget {
  final String title;
  final double value;
  final bool isPercentage; // 是否顯示百分比

  const _KpiCard({
    required this.title, 
    required this.value,
    this.isPercentage = false, 
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'en_US');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    String displayValue;
    if (isPercentage) {
      displayValue = '${value.toStringAsFixed(1)}%'; // e.g. 25.5%
    } else {
      displayValue = '\$ ${currencyFormat.format(value)}'; // e.g. $ 1,000
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayValue, 
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}