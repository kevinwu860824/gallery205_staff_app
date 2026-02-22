import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:gallery205_staff_app/features/staff_management/domain/services/payroll_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  List<PayrollReportItem> _report = [];
  String? _shopId;
  late PayrollService _payrollService;
  
  // Formatters
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _payrollService = PayrollService(Supabase.instance.client);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    if (_shopId != null) {
      _fetchPayroll();
    }
  }

  Future<void> _fetchPayroll() async {
    if (_shopId == null) return;
    setState(() => _isLoading = true);

    try {
      final items = await _payrollService.calculateMonthlyPayroll(
        shopId: _shopId!,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      );
      
      setState(() {
        _report = items;
      });
    } catch (e) {
      debugPrint('Error fetching payroll: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMonth() async {
    // Simple year-month picker using CuperintnoDatePicker
    // Since CupertinoDatePicker doesn't strictly support Month only, we use Date mode and ignore day.
    
    DateTime temp = _selectedMonth;
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Theme.of(context).cardColor,
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text("Done"), // Needs L10n ideally
                onPressed: () {
                   Navigator.of(context).pop();
                   if (temp != _selectedMonth) {
                     setState(() => _selectedMonth = temp);
                     _fetchPayroll();
                   }
                },
              ),
            ),
             Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedMonth,
                maximumDate: DateTime.now().add(const Duration(days: 30)),
                onDateTimeChanged: (val) => temp = val,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final l10n = AppLocalizations.of(context)!; // Need to add keys later
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final totalExpense = _report.fold(0.0, (sum, item) => sum + (item.finalWage ?? item.calculatedWage));
    final monthStr = DateFormat('yyyy MMM').format(_selectedMonth);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('薪資報表'), // L10n
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Column(
        children: [
          // 1. Dashboard Header
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     GestureDetector(
                       onTap: _pickMonth,
                       child: Row(
                         children: [
                           Text(monthStr, style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 16, fontWeight: FontWeight.w500)),
                           Icon(Icons.arrow_drop_down, color: colorScheme.onPrimaryContainer),
                         ],
                       ),
                     ),
                     const SizedBox(height: 8),
                     Text('預估總額', style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.7), fontSize: 12)),
                     Text(_currencyFormat.format(totalExpense), style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                     Text('員工人數', style: TextStyle(color: colorScheme.onPrimaryContainer.withOpacity(0.7), fontSize: 12)),
                     Text('${_report.length}', style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 20, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 8),
                     // Placeholder for status
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                       child: const Text('草稿', style: TextStyle(fontSize: 10)),
                     ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Staff List
          Expanded(
            child: _isLoading 
                ? const Center(child: CupertinoActivityIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _report.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                       final item = _report[index];
                       return _buildStaffCard(item, theme, colorScheme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(PayrollReportItem item, ThemeData theme, ColorScheme color) {
    return GestureDetector(
      onTap: () async {
         final result = await context.push<bool>('/payrollDetail', extra: {
           'shopId': _shopId,
           'reportItem': item,
           'period': DateTime(_selectedMonth.year, _selectedMonth.month, 1),
         });
         
         // If detail screen returns true (indicating data change), reload list
         if (result == true) {
           _fetchPayroll();
         }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
           // Avatar / Initials
           CircleAvatar(
             backgroundColor: color.primary.withOpacity(0.1),
             child: Text(item.userName.substring(0, 1).toUpperCase(), style: TextStyle(color: color.primary)),
           ),
           const SizedBox(width: 16),
           
           // Details
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(item.userName, style: TextStyle(color: color.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                 const SizedBox(height: 4),
                 Row(
                   children: [
                      _buildTag(theme, '${item.attendanceDays} 天'),
                      const SizedBox(width: 8),
                      if (item.salaryType == 'hourly')
                        _buildTag(theme, '${item.totalHours.toStringAsFixed(1)} 小時'),
                      if (item.salaryType == 'monthly')
                         _buildTag(theme, '月薪'),
                   ],
                 ),
               ],
             ),
           ),
           
           // Wage
           Column(
             crossAxisAlignment: CrossAxisAlignment.end,
             children: [
                Text(
                  _currencyFormat.format(item.finalWage ?? item.calculatedWage), 
                  style: TextStyle(color: (item.finalWage != null) ? Colors.green : color.primary, fontWeight: FontWeight.bold, fontSize: 16)
                ),
                if (item.settlementStatus != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 2),
                     child: Text(
                       item.settlementStatus == 'confirmed' ? '已結算' : (item.settlementStatus == 'paid' ? '已發放' : '草稿'),
                       style: TextStyle(color: item.settlementStatus == 'confirmed' ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                     ),
                   )
                else
                  Text(
                    item.salaryType == 'hourly' ? '@ ${_currencyFormat.format(item.baseWage)}/時' : '固定薪資',
                    style: TextStyle(color: color.onSurfaceVariant, fontSize: 10),
                  ),
             ],
           ),
        ],
      ),
    ),
  );
}

  Widget _buildTag(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
    );
  }
}
