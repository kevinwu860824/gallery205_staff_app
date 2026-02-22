// lib/features/reporting/presentation/clock_in_report_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:gallery205_staff_app/core/constants/app_permissions.dart';
import 'package:gallery205_staff_app/core/services/permission_service.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 1. UI 樣式定義 - Removed _AppColors
// -------------------------------------------------------------------

class ClockInReportScreen extends StatefulWidget {
  const ClockInReportScreen({super.key});

  @override
  State<ClockInReportScreen> createState() => _ClockInReportScreenState();
}

class _ClockInReportScreenState extends State<ClockInReportScreen> {
  String? _shopId;
  String? _currentUserId;
  bool _isLoading = true;
  
  // 權限狀態
  bool _canViewAll = false; 

  // 篩選狀態
  DateTime _targetDate = DateTime.now(); 
  bool _isDayView = false; 
  String? _selectedUserId; 
  
  // 資料
  List<Map<String, dynamic>> _logs = [];
  Map<String, String> _userNames = {};
  List<Map<String, dynamic>> _staffList = [];

  // 統計
  double _totalHours = 0.0;
  int _totalDays = 0; 

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    final user = Supabase.instance.client.auth.currentUser;
    _currentUserId = user?.id;

    if (_shopId == null || _currentUserId == null) {
      if (mounted) context.pop();
      return;
    }
    
    _canViewAll = PermissionService().hasPermission(AppPermissions.backViewAllClockIn);

    if (_canViewAll) {
      await _fetchStaffList();
    } else {
      await _fetchCurrentUserName();
    }

    await _loadReportData();
  }

  DateTime _toShopTime(DateTime utcTime) {
    return utcTime.toUtc().add(const Duration(hours: 8));
  }

  Future<void> _fetchStaffList() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('user_id, name')
          .eq('shop_id', _shopId!);
      
      final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(res);
      final Map<String, String> nameMap = {};
      
      for (var u in users) {
        nameMap[u['user_id']] = u['name'] ?? 'Unknown';
      }

      if (mounted) {
        setState(() {
          _staffList = users;
          _userNames = nameMap;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
    }
  }

  Future<void> _fetchCurrentUserName() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('user_id', _currentUserId!)
          .eq('shop_id', _shopId!)
          .limit(1)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _userNames[_currentUserId!] = res['name'] ?? 'Me';
        });
      }
    } catch (e) {
      debugPrint('Error fetching my name: $e');
    }
  }

  Future<void> _loadReportData() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    String startStr;
    String endStr;

    if (_isDayView) {
      startStr = DateFormat('yyyy-MM-dd').format(_targetDate);
      endStr = startStr;
    } else {
      final firstDay = DateTime(_targetDate.year, _targetDate.month, 1);
      final lastDay = DateTime(_targetDate.year, _targetDate.month + 1, 0);
      startStr = DateFormat('yyyy-MM-dd').format(firstDay);
      endStr = DateFormat('yyyy-MM-dd').format(lastDay);
    }

    try {
      var query = Supabase.instance.client
          .from('work_logs')
          .select()
          .eq('shop_id', _shopId!)
          .gte('date', startStr) 
          .lte('date', endStr);

      if (_canViewAll) {
        if (_selectedUserId != null) {
          query = query.eq('user_id', _selectedUserId!);
        }
      } else {
        query = query.eq('user_id', _currentUserId!);
      }

      final res = await query.order('date', ascending: false).order('clock_in', ascending: false);
      final logs = List<Map<String, dynamic>>.from(res);

      double totalHrs = 0;
      final Set<String> uniqueKeys = {}; 

      for (var log in logs) {
        if (_isDayView) {
          uniqueKeys.add(log['user_id']);
        } else {
          if (log['date'] != null) uniqueKeys.add(log['date']);
        }

        if (log['clock_in'] != null && log['clock_out'] != null) {
          final start = DateTime.parse(log['clock_in']);
          final end = DateTime.parse(log['clock_out']);
          final duration = end.difference(start).inMinutes / 60.0;
          totalHrs += duration;
        }
      }

      if (mounted) {
        setState(() {
          _logs = logs;
          _totalHours = totalHrs;
          _totalDays = uniqueKeys.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading logs: $e');
      if (mounted) {
        _showErrorSnackBar(l10n.punchErrorGeneric(e.toString()));
        setState(() => _isLoading = false);
      }
    }
  }

  void _changePeriod(int offset) {
    setState(() {
      if (_isDayView) {
        _targetDate = _targetDate.add(Duration(days: offset));
      } else {
        _targetDate = DateTime(_targetDate.year, _targetDate.month + offset);
      }
    });
    _loadReportData();
  }

  void _showMonthPicker() {
    final l10n = AppLocalizations.of(context)!;
    DateTime tempDate = _targetDate;
    final theme = Theme.of(context);
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
                    initialDateTime: _targetDate,
                    onDateTimeChanged: (val) => tempDate = val,
                  ),
                ),
              ),
              CupertinoButton(
                child: Text(l10n.commonConfirm, style: TextStyle(color: theme.primaryColor)), // 'Confirm'
                onPressed: () {
                  context.pop();
                  setState(() {
                    _targetDate = tempDate;
                    _isDayView = false; 
                  });
                  _loadReportData();
                },
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDayPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      locale: Locale(l10n.localeName),
      initialDate: _targetDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.cardColor,
              onSurface: theme.colorScheme.onSurface,
            ),

            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _targetDate = picked;
        _isDayView = true;
      });
      _loadReportData();
    }
  }

  void _showStaffFilter() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(l10n.clockInReportSelectStaff, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: Text(l10n.clockInReportAllStaff, style: TextStyle(color: colorScheme.onSurface)),
                    trailing: _selectedUserId == null ? Icon(Icons.check, color: theme.primaryColor) : null,
                    onTap: () {
                      setState(() => _selectedUserId = null);
                      context.pop();
                      _loadReportData();
                    },
                  ),
                  Divider(color: colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
                  ..._staffList.map((u) {
                    final uid = u['user_id'];
                    final name = u['name'];
                    return ListTile(
                      title: Text(name, style: TextStyle(color: colorScheme.onSurface)),
                      trailing: _selectedUserId == uid ? Icon(Icons.check, color: theme.primaryColor) : null,
                      onTap: () {
                        setState(() => _selectedUserId = uid);
                        context.pop();
                        _loadReportData();
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editLogTime(String logId, Map<String, dynamic> logData, bool isClockIn) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    final String currentIso = isClockIn ? logData['clock_in'] : logData['clock_out'];
    final DateTime currentUtc = DateTime.parse(currentIso);
    final DateTime currentShop = _toShopTime(currentUtc);

    // 1. 選擇日期
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentShop, 
      firstDate: currentShop.subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 2)), 
      builder: (context, child) {
         return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.cardColor,
            ),

          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate == null) return;
    if (!mounted) return;

    // 2. 選擇時間
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentShop),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;
    if (!mounted) return;

    // 3. 組合時間 (使用 DateTime.utc 避免本地時區干擾)
    // 我們假設使用者輸入的是 "店鋪時間 (UTC+8)"
    final DateTime newDateTimeUtc = DateTime.utc(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ).subtract(const Duration(hours: 8)); // 轉回 UTC

    if (isClockIn) {
      if (logData['clock_out'] != null) {
        final DateTime endUtc = DateTime.parse(logData['clock_out']);
        if (newDateTimeUtc.isAfter(endUtc)) {
           _showErrorSnackBar(l10n.clockInDetailErrorInLaterThanOut); 
           return;
        }
      }
    } else {
      final DateTime startUtc = DateTime.parse(logData['clock_in']);
      
      if (newDateTimeUtc.isBefore(startUtc)) {
         final diff = startUtc.difference(newDateTimeUtc).inHours;
         if (diff > 12) {
            _showErrorSnackBar(l10n.clockInDetailErrorDateCheck);
         } else {
            _showErrorSnackBar(l10n.clockInDetailErrorOutEarlierThanIn);
         }
         return;
      }
    }

    try {
      final Map<String, dynamic> updateData = isClockIn 
        ? {
            'clock_in': newDateTimeUtc.toIso8601String(),
            'manual_in': true,
            'reason_in': l10n.clockInDetailReasonSupervisorFix, 
          }
        : {
            'clock_out': newDateTimeUtc.toIso8601String(),
            'manual_out': true,
            'reason_out': l10n.clockInDetailReasonSupervisorFix, 
          };

      // 使用 .select() 檢查回傳
      final data = await Supabase.instance.client
          .from('work_logs')
          .update(updateData)
          .eq('id', logId)
          .select();

      if (data.isEmpty) {
        throw 'Permission Denied: Unable to update this record (RLS).';
      }

      if (mounted) {
        context.pop(); 
        _loadReportData(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.clockInDetailSuccessUpdate)), 
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _fixClockOutTime(String logId, String clockInIso) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final DateTime clockInTime = DateTime.parse(clockInIso);
    final DateTime clockInShopTime = _toShopTime(clockInTime); 

    // 1. 先讓主管確認 "下班日期"
    final DateTime estimatedEnd = clockInShopTime.add(const Duration(hours: 9));
    
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: estimatedEnd, 
      firstDate: clockInShopTime.subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 2)),
      helpText: l10n.clockInDetailSelectDate, 
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.cardColor, 
            ),

          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    // 2. 再選時間
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(estimatedEnd),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;
    if (!mounted) return;

    // 3. 組合時間 (使用 DateTime.utc)
    // 假設使用者輸入的是店鋪時間 (UTC+8)
    final DateTime fixUtc = DateTime.utc(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ).subtract(const Duration(hours: 8));

    if (fixUtc.isBefore(clockInTime)) {
      _showErrorSnackBar(l10n.clockInDetailErrorOutEarlierThanIn);
      return;
    }

    try {
      // 使用 .select() 檢查回傳
      final data = await Supabase.instance.client
          .from('work_logs')
          .update({
            'clock_out': fixUtc.toIso8601String(),
            'manual_out': true,
            'reason_out': l10n.clockInDetailReasonSupervisorFix, 
          })
          .eq('id', logId)
          .select();

      if (data.isEmpty) {
         throw 'Permission Denied: Unable to update this record (RLS).';
      }

      if (mounted) {
        context.pop(); 
        _loadReportData(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.clockInDetailSuccessUpdate)), 
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  void _showDetailDialog(Map<String, dynamic> log) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final userId = log['user_id'];
    final logId = log['id'];
    final name = _userNames[userId] ?? l10n.commonUnknown;
    
    String formatTime(String? iso) {
      if (iso == null) return '--:--';
      final utcTime = DateTime.parse(iso);
      final shopTime = _toShopTime(utcTime); 
      return DateFormat('HH:mm (${l10n.localeName == 'zh' ? 'MM/dd' : 'MM/dd'})').format(shopTime);
    }
    
    final inTime = formatTime(log['clock_in']);
    final outTime = formatTime(log['clock_out']);
    
    final bool isManualIn = log['manual_in'] == true;
    final bool isManualOut = log['manual_out'] == true;
    final String reasonIn = log['reason_in'] ?? l10n.commonNone;
    final String reasonOut = log['reason_out'] ?? l10n.commonNone;
    final String wifiIn = log['wifi_name'] ?? l10n.commonUnknown;
    final String wifiOut = log['wifi_name_out'] ?? l10n.commonUnknown;

    final bool isMissingClockOut = log['clock_out'] == null;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              
              _DetailSection(
                title: l10n.clockInDetailTitleIn,
                time: inTime,
                isManual: isManualIn,
                wifi: wifiIn,
                reason: isManualIn ? reasonIn : null,
                icon: CupertinoIcons.arrow_right_circle_fill,
                iconColor: CupertinoColors.systemGreen,
                onEdit: _canViewAll 
                    ? () => _editLogTime(logId, log, true) 
                    : null,
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
              ),
              
              if (isMissingClockOut)
                 Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(CupertinoIcons.exclamationmark_circle_fill, color: theme.colorScheme.error, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.clockInDetailTitleOut, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(l10n.clockInDetailMissing, style: TextStyle(color: theme.colorScheme.error, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (_canViewAll)
                            SizedBox(
                              height: 36,
                              child: ElevatedButton.icon(
                                onPressed: () => _fixClockOutTime(logId, log['clock_in']),
                                icon: const Icon(CupertinoIcons.wrench, size: 16, color: Colors.white),
                                label: Text(l10n.clockInDetailFixButton, style: const TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                _DetailSection(
                  title: l10n.clockInDetailTitleOut,
                  time: outTime,
                  isManual: isManualOut,
                  wifi: wifiOut,
                  reason: isManualOut ? reasonOut : null,
                  icon: CupertinoIcons.arrow_left_circle_fill,
                  iconColor: CupertinoColors.systemOrange,
                  onEdit: _canViewAll 
                    ? () => _editLogTime(logId, log, false) 
                    : null,
                ),

              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 120,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(l10n.clockInDetailCloseButton, style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(CupertinoIcons.chevron_left, color: theme.iconTheme.color, size: 32),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.clockInReportTitle,
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (_canViewAll)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showStaffFilter,
                      child: Icon(
                        _selectedUserId == null ? CupertinoIcons.person_2_fill : CupertinoIcons.person_fill,
                        color: theme.iconTheme.color, 
                        size: 28,
                      ),
                    )
                  else
                    const SizedBox(width: 28),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(CupertinoIcons.chevron_left, color: theme.iconTheme.color, size: 32),
                    onPressed: () => _changePeriod(-1),
                  ),
                  
                  const SizedBox(width: 8), 
                  
                  GestureDetector(
                    onTap: _showMonthPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text(
                        _isDayView 
                            ? DateFormat.yMMMd(l10n.localeName).format(_targetDate)
                            : DateFormat('yyyy/MM').format(_targetDate),
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showDayPicker,
                    child: Icon(
                      CupertinoIcons.calendar,
                      color: colorScheme.onSurfaceVariant, 
                      size: 24,
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(CupertinoIcons.chevron_right, color: theme.iconTheme.color, size: 32),
                    onPressed: () => _changePeriod(1),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    title: l10n.clockInReportTotalHours,
                    value: '${_totalHours.toStringAsFixed(1)} ${l10n.clockInReportUnitHr}',
                  ),
                  Container(width: 1, height: 40, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                  _SummaryItem(
                    title: _isDayView ? l10n.clockInReportStaffCount : l10n.clockInReportWorkDays,
                    value: _isDayView ? '$_totalDays ${l10n.clockInReportUnitPpl}' : '$_totalDays ${l10n.clockInReportUnitDays}', 
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
                  : _logs.isEmpty
                      ? Center(child: Text(l10n.clockInReportNoRecords, style: TextStyle(color: colorScheme.onSurfaceVariant))) 
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final userId = log['user_id'];
                            final name = _userNames[userId] ?? l10n.commonUnknown;
                            
                            final startUtc = DateTime.parse(log['clock_in']);
                            final startShop = _toShopTime(startUtc);

                            DateTime? endShop;
                            if (log['clock_out'] != null) {
                              final endUtc = DateTime.parse(log['clock_out']);
                              endShop = _toShopTime(endUtc);
                            }

                            final bool isManual = (log['manual_in'] == true) || (log['manual_out'] == true);

                            String status = l10n.clockInReportStatusWorking;
                            Color statusColor = CupertinoColors.systemOrange;
                            String durationStr = '--';

                            if (log['clock_out'] != null) {
                              status = l10n.clockInReportStatusCompleted;
                              statusColor = CupertinoColors.systemGreen;
                              final endUtc = DateTime.parse(log['clock_out']);
                              final mins = endUtc.difference(startUtc).inMinutes;
                              final hrs = mins / 60;
                              durationStr = '${hrs.toStringAsFixed(1)} ${l10n.clockInReportUnitHr}';
                            } else {
                              if (DateTime.now().toUtc().difference(startUtc).inHours > 20) {
                                status = l10n.clockInReportStatusIncomplete;
                                statusColor = theme.colorScheme.error;
                              }
                            }

                            return GestureDetector(
                              onTap: () => _showDetailDialog(log),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                            if (isManual) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: CupertinoColors.systemPurple.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: CupertinoColors.systemPurple.withValues(alpha: 0.6)),
                                                ),
                                                child: Text(
                                                  l10n.clockInReportLabelManual,
                                                  style: const TextStyle(color: CupertinoColors.systemPurple, fontSize: 10, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          DateFormat('MM/dd (E)', l10n.localeName).format(startShop),
                                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(color: colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
                                    const SizedBox(height: 12),
                                    
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _TimeRow(label: l10n.clockInReportLabelIn, time: DateFormat('HH:mm').format(startShop)),
                                            const SizedBox(height: 4),
                                            _TimeRow(
                                              label: l10n.clockInReportLabelOut,
                                              time: endShop != null ? DateFormat('HH:mm').format(endShop) : '--:--',
                                            ),
                                          ],
                                        ),
                                        
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              durationStr,
                                              style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        )
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

class _TimeRow extends StatelessWidget {
  final String label;
  final String time;
  const _TimeRow({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
        Text(time, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String time;
  final bool isManual;
  final String wifi;
  final String? reason;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onEdit;

  const _DetailSection({
    required this.title,
    required this.time,
    required this.isManual,
    required this.wifi,
    this.reason,
    required this.icon,
    required this.iconColor,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
                  if (onEdit != null) ...[
                     const SizedBox(width: 8),
                     InkWell(
                       onTap: onEdit,
                       child: Padding(
                         padding: const EdgeInsets.all(4.0),
                         child: Icon(CupertinoIcons.pencil, size: 16, color: theme.primaryColor),
                       ),
                     ),
                  ]
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(time, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                  if (isManual) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemPurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(l10n.clockInReportLabelManual, style: const TextStyle(color: CupertinoColors.systemPurple, fontSize: 10)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(l10n.clockInDetailLabelWifi(wifi), style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
              if (isManual && reason != null) ...[
                const SizedBox(height: 4),
                Text(l10n.clockInDetailLabelReason(reason!), style: const TextStyle(color: CupertinoColors.systemPurple, fontSize: 13, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}