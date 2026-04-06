import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gallery205_staff_app/features/staff_management/domain/services/payroll_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class PayrollDetailScreen extends StatefulWidget {
  final String shopId;
  final PayrollReportItem reportItem;
  final DateTime period; 

  const PayrollDetailScreen({
    super.key,
    required this.shopId,
    required this.reportItem,
    required this.period,
  });

  @override
  State<PayrollDetailScreen> createState() => _PayrollDetailScreenState();
}

class _PayrollDetailScreenState extends State<PayrollDetailScreen> {
  late PayrollService _payrollService;
  bool _isLoading = false;
  
  late PayrollReportItem _currentReportItem; // [NEW] Live data

  // Stage 3 Data
  List<Map<String, dynamic>> _adjustments = [];
  double _manualOvertimeHours = 0;
  double _baseTotalHours = 0; 
  double _baseCalculatedWage = 0; // [NEW] Wage excluding manual OT
  String _status = 'draft';
  
  // Smart Reconciliation Data
  List<DailyAttendanceStatus> _attendanceStatus = [];
  
  // Formatters
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _payrollService = PayrollService(Supabase.instance.client);
    _currentReportItem = widget.reportItem; // Init with passed data
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // 0. [NEW] Live Recalculate (Critical for leave updates)
      final newItem = await _payrollService.calculateSingleUserPayroll(
        shopId: widget.shopId,
        userId: widget.reportItem.userId,
        year: widget.period.year,
        month: widget.period.month,
      );
      
      _currentReportItem = newItem;

      // 1. Load Settlement
      final record = await _payrollService.getPayrollRecord(
        shopId: widget.shopId,
        userId: widget.reportItem.userId,
        period: widget.period,
      );

      if (record != null) {
        final List<dynamic> rawAdj = record['adjustments'] ?? [];
        _adjustments = List<Map<String, dynamic>>.from(rawAdj);

        _manualOvertimeHours = (record['manual_overtime_hours'] as num? ?? 0).toDouble();
        _status = record['status'] ?? 'draft';
      }
      
      // Calculate Base Hours (Total - Manual) for UI dynamic update
      // Logic: Service returns Total = Regular + TrackedOT + SavedManualOT.
      // We want Base = Total - SavedManualOT.
      // So displayed Total = Base + CurrentManualOT.
      _baseTotalHours = _currentReportItem.totalHours - _manualOvertimeHours;
      
      // Calculate Base Wage (Total - ManualWage) for UI dynamic update
      double loadedManualWage = 0;
      if (_currentReportItem.salaryType == 'monthly') {
         final rate = _currentReportItem.baseWage / 240.0;
         loadedManualWage = _manualOvertimeHours * rate * 1.33; 
      } else {
         loadedManualWage = _manualOvertimeHours * _currentReportItem.baseWage;
      }
      _baseCalculatedWage = _currentReportItem.calculatedWage - loadedManualWage;
      
      // 2. Load Smart Attendance
      final stati = await _payrollService.getAttendanceReconciliation(
        userId: widget.reportItem.userId,
        shopId: widget.shopId,
        year: widget.period.year,
        month: widget.period.month,
      );
      
      _attendanceStatus = stati;

    } catch (e) {
      debugPrint('Error loading details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalAdjustments {
    return _adjustments.fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());
  }

  double get _finalTotal {
    double manualOtPay = 0;
    if (_currentReportItem.salaryType == 'monthly') {
      final hourlyRate = _currentReportItem.baseWage / 240.0;
      manualOtPay = _manualOvertimeHours * hourlyRate * 1.33; 
    } else {
       manualOtPay = _manualOvertimeHours * _currentReportItem.baseWage;
    }
    
    // exact logic: Base (no manual) + Adjustments + Current Manual
    return _baseCalculatedWage + _totalAdjustments + manualOtPay;
  }

  bool get _isConfirmed => _status == 'confirmed' || _status == 'paid';

  Future<void> _save(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await _payrollService.savePayrollRecord(
        shopId: widget.shopId,
        userId: widget.reportItem.userId,
        period: widget.period,
        totalHours: _currentReportItem.totalHours,
        baseWage: _currentReportItem.baseWage,
        calculatedAmount: _currentReportItem.calculatedWage,
        adjustments: _adjustments,
        manualOvertimeHours: _manualOvertimeHours,
        finalTotal: _finalTotal,
        status: newStatus,
      );
      
      if (mounted) {
        setState(() => _status = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus == 'confirmed' ? '結算已確認' : '草稿已儲存')),
        );
        if (newStatus == 'confirmed') {
          context.pop(true); 
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Smart Actions ---

  Future<void> _fixPunch(DailyAttendanceStatus status) async {
    // Show Action Choice Dialog
    final String? action = await showDialog<String>(
      context: context, 
      builder: (_) => AlertDialog(
        title: const Text('補打卡'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('日期: ${DateFormat('MM/dd').format(status.date)}'),
             if (status.shiftStart != null)
               Text('班表: ${DateFormat('HH:mm').format(status.shiftStart!)} - ${DateFormat('HH:mm').format(status.shiftEnd!)}'),
             const SizedBox(height: 16),
             const Text('請選擇補卡方式：'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'manual'), 
            child: const Text('手動填寫'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'auto'), 
            child: const Text('依班表帶入'),
          ),
        ],
      ),
    );

    if (action == null || action == 'cancel') return;

    DateTime? finalStart;
    DateTime? finalEnd;

    if (action == 'auto') {
      if (status.shiftStart == null || status.shiftEnd == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法依班表補卡：無班表資料')));
        return;
      }
      finalStart = status.shiftStart!;
      finalEnd = status.shiftEnd!;
    } else if (action == 'manual') {
      // Show Manual Input Dialog
      final result = await _showManualPunchDialog(status.date, status.shiftStart, status.shiftEnd);
      if (result == null) return;
      finalStart = result['start'];
      finalEnd = result['end'];
    }

    if (finalStart != null && finalEnd != null) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await _payrollService.fixPunchFromSchedule(
          shopId: widget.shopId,
          userId: widget.reportItem.userId,
          date: status.date,
          shiftStart: finalStart, // Reuse this method as it accepts specific times
          shiftEnd: finalEnd,
        );
        await _loadAllData(); // Reload to refresh status
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, DateTime>?> _showManualPunchDialog(DateTime date, DateTime? defaultStart, DateTime? defaultEnd) async {
    TimeOfDay start = defaultStart != null ? TimeOfDay.fromDateTime(defaultStart) : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = defaultEnd != null ? TimeOfDay.fromDateTime(defaultEnd) : const TimeOfDay(hour: 18, minute: 0);
    
    return showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
             return AlertDialog(
               title: const Text('手動補卡'),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   ListTile(
                     title: const Text('上班時間'),
                     trailing: Text(start.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                     onTap: () async {
                       final t = await showTimePicker(context: context, initialTime: start);
                       if (t != null) setState(() => start = t);
                     },
                   ),
                   ListTile(
                     title: const Text('下班時間'),
                     trailing: Text(end.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                     subtitle: const Text('若下班時間小於上班時間，將視為跨日 (+1天)'),
                     onTap: () async {
                       final t = await showTimePicker(context: context, initialTime: end);
                       if (t != null) setState(() => end = t);
                     },
                   ),
                 ],
               ),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                 ElevatedButton(
                   onPressed: () {
                     // Construct DateTimes
                     final sDate = DateTime(date.year, date.month, date.day, start.hour, start.minute);
                     DateTime eDate = DateTime(date.year, date.month, date.day, end.hour, end.minute);
                     
                     // Auto handle overnight
                     // Note: Simple logic: if End is before Start, assume next day.
                     // Or check if defaultEnd was next day? 
                     // Let's use the explicit compare:
                     if (eDate.isBefore(sDate)) {
                       eDate = eDate.add(const Duration(days: 1));
                     }
                     
                     Navigator.pop(context, {'start': sDate, 'end': eDate});
                   },
                   child: const Text('確認'),
                 ),
               ],
             );
          },
        );
      },
    );
  }

  Future<void> _markAsLeave(DailyAttendanceStatus status) async {
    // Select Leave Type
    final String? leaveType = await showModalBottomSheet<String>(
      context: context, 
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('病假'), onTap: () => Navigator.pop(context, 'sick')),
            ListTile(title: const Text('事假'), onTap: () => Navigator.pop(context, 'personal')),
            ListTile(title: const Text('特休'), onTap: () => Navigator.pop(context, 'annual')),
          ],
        ),
      )
    );
    
    if (leaveType != null && status.shiftStart != null && status.shiftEnd != null) {
      setState(() => _isLoading = true);
      try {
         double hours = status.shiftEnd!.difference(status.shiftStart!).inMinutes / 60.0;
         if (hours < 0) {
           hours += 24.0; // Handle overnight shift (e.g. 22:00 - 02:00)
         }
         await _payrollService.addLeaveRecord(
           shopId: widget.shopId,
           userId: widget.reportItem.userId,
           date: status.date,
           leaveType: leaveType,
           start: status.shiftStart!,
           end: status.shiftEnd!,
           hours: hours,
         );
         await _loadAllData();
      } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
         setState(() => _isLoading = false);
      }
    }
  }
  
  // --- Standard Adjustments ---

  void _addAdjustment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddAdjustmentDialog(),
    );

    if (result != null) {
      setState(() {
        _adjustments.add(result);
      });
    }
  }
  
  void _removeAdjustment(int index) {
    if (_isConfirmed) return;
    setState(() {
      _adjustments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double hPadding = isTablet ? (screenWidth - 600) / 2 : 16.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${_currentReportItem.userName} - 薪資明細'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          if (!_isConfirmed)
            TextButton(
              onPressed: _isLoading ? null : () => _save('draft'),
              child: const Text('儲存草稿'),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CupertinoActivityIndicator())
        : ListView(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
            children: [
              // 1. Stage 2 Card
              _buildSectionTitle(theme, '階段二：薪資試算'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(theme),
                child: Column(
                  children: [
                    _buildRow(theme, '基礎薪資', _currencyFormat.format(_currentReportItem.baseWage)),
                    if (_currentReportItem.salaryType == 'hourly')
                      _buildRow(theme, '總工時', '${(_baseTotalHours + _manualOvertimeHours).toStringAsFixed(1)} 小時'),
                    _buildRow(theme, '試算金額', _currencyFormat.format(_finalTotal), isBold: true), // Use _finalTotal to reflect manual OT change immediately
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Adjustments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle(theme, '階段三：調節項目'),
                  if (!_isConfirmed)
                    IconButton(
                      icon: Icon(CupertinoIcons.add_circled, color: colorScheme.primary),
                      onPressed: _addAdjustment,
                    ),
                ],
              ),
              if (_adjustments.isEmpty)
                Text('無調節項目', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              
              ..._adjustments.asMap().entries.map((entry) {
                 final idx = entry.key;
                 final adj = entry.value;
                 return Container(
                   margin: const EdgeInsets.only(bottom: 8),
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   decoration: _cardDecoration(theme),
                   child: Row(
                     children: [
                       Expanded(child: Text(adj['title'], style: TextStyle(color: colorScheme.onSurface))),
                       Text(
                         _currencyFormat.format(adj['amount']), 
                         style: TextStyle(
                           color: (adj['amount'] as num) >= 0 ? Colors.green : Colors.red,
                           fontWeight: FontWeight.bold
                         )
                       ),
                       if (!_isConfirmed)
                         IconButton(
                           icon: const Icon(CupertinoIcons.minus_circle, color: Colors.red, size: 20),
                           onPressed: () => _removeAdjustment(idx),
                         )
                     ],
                   ),
                 );
              }),
              const SizedBox(height: 20),

              // 3. Final Total
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('最終結算金額', style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                    Text(_currencyFormat.format(_finalTotal), style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              if (!_isConfirmed)
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    child: _isLoading ? const CupertinoActivityIndicator() : const Text('確認結算 (Lock)'),
                    onPressed: _isLoading ? null : () => _save('confirmed'),
                  ),
                )
              else
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✓ 已確認結算', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isLoading ? null : () => _save('draft'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Text('解除鎖定', style: TextStyle(fontSize: 12, color: Colors.blue)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 30),
              
              // 2.5 Manual Overtime
              const SizedBox(height: 20),
              _buildSectionTitle(theme, '手動加班 (月結)'),
              Container(
                 padding: const EdgeInsets.all(16),
                 decoration: _cardDecoration(theme),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     const Text('本月額外加班時數'),
                     Row(
                       children: [
                         IconButton(
                           icon: const Icon(Icons.remove_circle_outline),
                           onPressed: _isConfirmed ? null : () {
                             if (_manualOvertimeHours >= 0.5) {
                               setState(() => _manualOvertimeHours -= 0.5);
                             }
                           },
                         ),
                         Text('${_manualOvertimeHours.toStringAsFixed(1)} h', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                         IconButton(
                           icon: const Icon(Icons.add_circle_outline),
                           onPressed: _isConfirmed ? null : () {
                              setState(() => _manualOvertimeHours += 0.5);
                           },
                         ),
                       ],
                     )
                   ],
                 ),
              ),
              const SizedBox(height: 10),

              // 4. Smart Reconciliation List
              _buildSectionTitle(theme, '每日出勤對帳 (智慧偵測)'),
              ..._attendanceStatus.map((status) => _buildStatusRow(theme, status)),
            ],
          ),
    );
  }

  Widget _buildStatusRow(ThemeData theme, DailyAttendanceStatus status) {
    if (status.shiftStart == null && status.actualIn == null && status.leaveType == null) {
      return const SizedBox.shrink(); 
    }

    final dateStr = DateFormat('MM/dd').format(status.date);
    Color statusColor = theme.colorScheme.onSurface;
    String statusText = '';
    Widget? actionButton;
    
    // Formatting Helper
    String formatTime(DateTime? dt) => dt != null ? DateFormat('HH:mm').format(dt) : '--:--';

    if (status.isMissingPunch) {
      // ⚠️ Missing Punch
      statusColor = Colors.red;
      statusText = '⚠️ 異常：未打卡';
      actionButton = _buildFixActions(status);
      
    } else if (status.isLeave) {
      // 🏥 Leave
      statusColor = Colors.blue;
      final typeMap = {'sick': '病假', 'personal': '事假', 'annual': '特休'};
      statusText = '🏥 請假：${typeMap[status.leaveType] ?? status.leaveType} (${status.leaveHours}h)';
      
    } else if (status.isException) {
      // ⚠️ Exception (Late / Early)
      statusColor = Colors.red;
      List<String> labels = [];
      if (status.isLate) labels.add('遲到');
      if (status.isEarlyLeave) labels.add('早退');
      if (labels.isEmpty) labels.add('異常');
      
      final inStr = formatTime(status.actualIn);
      final outStr = formatTime(status.actualOut);
      statusText = '⚠️ ${labels.join('/')} ($inStr - $outStr)';
      
      // Allow overriding/fixing
      actionButton = IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.orange),
            tooltip: '修正',
            onPressed: () => _fixPunch(status),
      );

    } else if (status.isProperlWork) {
      // ✅ Normal (Smart Snap)
      // Display Actual times, but highlight if OT exists
      final inStr = formatTime(status.actualIn);
      final outStr = status.actualOut != null ? formatTime(status.actualOut) : '工作中';
      
      String extraInfo = '';
      if (status.overtimeHours > 0) {
        extraInfo = ' (+OT ${status.overtimeHours}h)';
        statusColor = Colors.orange.shade800; // Highlight OT
      } else {
        statusText = '✅ $inStr - $outStr';
        // Check if snapped (Implicitly handled by calculation, but UI can hint)
        // If snappedIn != actualIn, maybe show *? 
        // Simplicity first: Just show actual time and "Normal" status.
      }
      statusText = '✅ $inStr - $outStr$extraInfo';
    }

    // Shift Info Text
    String shiftInfo = '';
    if (status.shiftStart != null) {
       shiftInfo = '班表 ${DateFormat('HH:mm').format(status.shiftStart!)} - ${DateFormat('HH:mm').format(status.shiftEnd!)}';
       // Show Break Info?
       // shiftInfo += '\n(休 0.5h)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
           // Date
           SizedBox(
             width: 50,
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Text(dateStr, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                 if (status.regularHours > 0)
                   Text('${status.regularHours}h', style: TextStyle(fontSize: 10, color: Colors.green)),
               ],
             ),
           ),
           // Shift Info (Plan)
           Expanded(
             flex: 2,
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 if (shiftInfo.isNotEmpty)
                    Text(shiftInfo, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
               ],
             ),
           ),
           // Status (Actual)
           Expanded(
             flex: 3,
             child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w500)),
           ),
           if (!_isConfirmed && actionButton != null)
             actionButton,
        ],
      ),
    );
  }
  
  Widget _buildFixActions(DailyAttendanceStatus status) {
     return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.red, size: 20),
            tooltip: '依班表補卡',
            onPressed: () => _fixPunch(status),
          ),
          IconButton(
            icon: const Icon(Icons.sick, color: Colors.blue, size: 20),
            tooltip: '補請假',
            onPressed: () => _markAsLeave(status),
          ),
        ],
      );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(title, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  BoxDecoration _cardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _buildRow(ThemeData theme, String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurface)),
          Text(value, style: TextStyle(
            color: theme.colorScheme.onSurface, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal
          )),
        ],
      ),
    );
  }
}

class _AddAdjustmentDialog extends StatefulWidget {
  @override
  State<_AddAdjustmentDialog> createState() => _AddAdjustmentDialogState();
}

class _AddAdjustmentDialogState extends State<_AddAdjustmentDialog> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  bool _isDeduction = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增調節項目'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: '項目名稱 (例: 全勤獎金)'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: '金額'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              ToggleButtons(
                isSelected: [!_isDeduction, _isDeduction],
                onPressed: (idx) {
                  setState(() => _isDeduction = idx == 1);
                },
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('+')),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-')),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
             final title = _titleCtrl.text.trim();
             final amountText = _amountCtrl.text.trim();
             if (title.isEmpty || amountText.isEmpty) return;
             
             double amount = double.tryParse(amountText) ?? 0;
             if (_isDeduction) amount = -amount;

             Navigator.pop(context, {'title': title, 'amount': amount});
          },
          child: const Text('新增'),
        ),
      ],
    );
  }
}
