// lib/features/schedule/presentation/schedule_view_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; 
import 'package:table_calendar/table_calendar.dart';

// ✅ 1. 引入權限服務與常數
import 'package:gallery205_staff_app/core/services/permission_service.dart';
import 'package:gallery205_staff_app/core/constants/app_permissions.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// 檢視模式
enum ViewMode {
  self, // 只看自己的班
  all,  // 看全店的班
}

// -------------------------------------------------------------------
// 2. 數據模型
// -------------------------------------------------------------------

class Shift {
  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final Color color;

  Shift({
    required this.id, 
    required this.name, 
    required this.startTime, 
    required this.endTime, 
    required this.color,
  });
}

class ScheduleEntry {
  final String employeeName;
  final String employeeRole;
  final Shift shift;

  ScheduleEntry({
    required this.employeeName,
    required this.employeeRole,
    required this.shift,
  });
}

// -------------------------------------------------------------------
// 3. ScheduleViewScreen (主頁面)
// -------------------------------------------------------------------

class ScheduleViewScreen extends StatefulWidget {
  const ScheduleViewScreen({super.key});

  @override
  State<ScheduleViewScreen> createState() => _ScheduleViewScreenState();
}

class _ScheduleViewScreenState extends State<ScheduleViewScreen> {
  ViewMode _currentMode = ViewMode.self;
  bool _isLoadingRole = true; 
  bool _isLoadingData = true; 
  
  String? _shopId;
  String? _userId;

  List<Shift> _allShifts = [];
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<ScheduleEntry>> _groupedSchedules = {}; 
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // ✅ 顏色轉換輔助函式
  Color _hexToColor(String hex) {
    String cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.green; // 預設顏色
    }
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    _userId = Supabase.instance.client.auth.currentUser?.id;

    if (_shopId == null || _userId == null) {
      if (mounted) context.go('/');
      return;
    }

    try {
      final client = Supabase.instance.client;
      
      final bool canViewAll = PermissionService().hasPermission(AppPermissions.shiftEdit);
      _currentMode = canViewAll ? ViewMode.all : ViewMode.self;

      final shiftsRes = await client
          .from('shop_shift_settings')
          .select('id, shift_name, start_time, end_time, color')
          .eq('shop_id', _shopId!)
          .eq('is_enabled', true)
          .order('start_time', ascending: true);
      
      _allShifts = List.generate(shiftsRes.length, (index) {
        final json = shiftsRes[index];
        final colorHex = json['color'] as String? ?? '#34C759';
        
        return Shift(
          id: json['id'] as String,
          name: json['shift_name'] as String,
          startTime: json['start_time'] as String,
          endTime: json['end_time'] as String,
          color: _hexToColor(colorHex),
        );
      });

      if (mounted) {
        setState(() {
          _isLoadingRole = false;
        });
        _fetchScheduleDataForMonth(_focusedDay);
      }
      
    } catch (e) {
      if (mounted) setState(() => _isLoadingRole = false);
      if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showSnackBar(l10n.scheduleViewErrorInit(e.toString()), isError: true);
      }
    }
  }

  Future<void> _fetchScheduleDataForMonth(DateTime month) async {
    if (_shopId == null) return;
    
    setState(() {
      _isLoadingData = true;
    });
    
    final DateTime startDate = DateTime(month.year, month.month, 1);
    final DateTime endDate = DateTime(month.year, month.month + 1, 0);

    try {
      var queryBuilder = Supabase.instance.client
        .from('schedule_assignments')
        .select('''
          shift_date,
          shift_type_id,
          users ( user_id, name, role ) 
        ''')
        .eq('shop_id', _shopId!)
        .gte('shift_date', startDate.toIso8601String())
        .lte('shift_date', endDate.toIso8601String());

      if (_currentMode == ViewMode.self && _userId != null) {
        queryBuilder = queryBuilder.eq('employee_id', _userId!);
      }
      
      final res = await queryBuilder.order('shift_date', ascending: true);

      final Map<DateTime, List<ScheduleEntry>> groupedData = {};
      
      for (final json in res) {
        final userJson = json['users'];
        final shiftTypeId = json['shift_type_id'];
        
        final shift = _allShifts.firstWhere(
          (s) => s.id == shiftTypeId, 
          orElse: () => Shift(id: 'unknown', name: 'Unknown', startTime: '??', endTime: '??', color: Colors.grey),
        );
        
        final employeeName = userJson?['name'] as String? ?? 'N/A';
        final employeeRole = userJson?['role'] as String? ?? 'staff';
        
        final entry = ScheduleEntry(
          employeeName: employeeName,
          employeeRole: employeeRole,
          shift: shift,
        );
        
        final date = DateTime.parse(json['shift_date'] as String);
        final dateOnly = DateTime(date.year, date.month, date.day);
        
        if (!groupedData.containsKey(dateOnly)) {
          groupedData[dateOnly] = [];
        }
        groupedData[dateOnly]!.add(entry);
      }

      setState(() {
        _groupedSchedules = groupedData;
      });

    } catch (e) {
      if(mounted) {
         final l10n = AppLocalizations.of(context)!;
         _showSnackBar(l10n.scheduleViewErrorFetch(e.toString()), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }
  
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
  
  void _goToUploadScreen() {
    context.push('/scheduleUpload').then((_) {
      _fetchScheduleDataForMonth(_focusedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_isLoadingRole) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
      );
    }
    
    final bool canEditShift = PermissionService().hasPermission(AppPermissions.scheduleEdit);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        middle: Text(l10n.scheduleViewTitle, style: TextStyle(color: colorScheme.onSurface)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        trailing: canEditShift
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.add, color: colorScheme.primary), 
                onPressed: _goToUploadScreen,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView( 
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: CupertinoSegmentedControl<ViewMode>(
                  groupValue: _currentMode,
                  onValueChanged: (ViewMode newValue) {
                    setState(() {
                      _currentMode = newValue;
                    });
                    _fetchScheduleDataForMonth(_focusedDay);
                  },
                  children: <ViewMode, Widget>{
                    ViewMode.self: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(l10n.scheduleViewModeMy, style: const TextStyle(fontSize: 14)), 
                    ),
                    ViewMode.all: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(l10n.scheduleViewModeAll, style: const TextStyle(fontSize: 14)), 
                    ),
                  },
                  selectedColor: colorScheme.primary,
                  unselectedColor: theme.scaffoldBackgroundColor,
                  borderColor: colorScheme.primary,
                ),
              ),

              _isLoadingData
                  ? Padding(
                      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.3),
                      child: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
                    )
                  : _buildCalendar(theme, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 4. UI Builder 輔助函式
  // -------------------------------------------------------------------

  Widget _buildCalendar(ThemeData theme, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    return TableCalendar(
      rowHeight: 110.0,
      focusedDay: _focusedDay,
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      
      locale: l10n.localeName,
      
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
        _fetchScheduleDataForMonth(focusedDay);
      },
      
      onDaySelected: (selectedDay, focusedDay) {
        if (_currentMode == ViewMode.all) {
          final dateOnly = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
          final entries = _groupedSchedules[dateOnly] ?? [];
          if (entries.isNotEmpty) {
            _showScheduleModal(dateOnly, entries);
          }
        }
      },
      
      daysOfWeekHeight: 40.0, // [Modified] Explicit height
      
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: false,
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        leftChevronIcon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
        rightChevronIcon: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        // [Modified] Bold White Headers for Sage Theme
        weekdayStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
        weekendStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold), 
      ),

      calendarBuilders: CalendarBuilders(
        outsideBuilder: (context, day, focusedDay) => 
          _buildCalendarCell(day, [], isOutside: true, theme: theme, colorScheme: colorScheme),
        defaultBuilder: (context, day, focusedDay) {
          final dateOnly = DateTime(day.year, day.month, day.day);
          final entries = _groupedSchedules[dateOnly] ?? [];
          return _buildCalendarCell(day, entries, theme: theme, colorScheme: colorScheme);
        },
        todayBuilder: (context, day, focusedDay) {
          final dateOnly = DateTime(day.year, day.month, day.day);
          final entries = _groupedSchedules[dateOnly] ?? [];
          return _buildCalendarCell(day, entries, isToday: true, theme: theme, colorScheme: colorScheme);
        },
      ),
    );
  }

  Widget _buildCalendarCell(DateTime day, List<ScheduleEntry> entries, {bool isToday = false, bool isOutside = false, required ThemeData theme, required ColorScheme colorScheme}) {
    // [Modified] Weekend Colors (Blue/Red) and White Text Logic
    Color textColor = colorScheme.onSurface; // Default White
    if (!isOutside) {
       if (day.weekday == DateTime.saturday) textColor = const Color(0xFF0044CC); // Dark Blue
       if (day.weekday == DateTime.sunday) textColor = const Color(0xFFCC0000); // Dark Red
    }
    if (isOutside) textColor = colorScheme.onSurfaceVariant.withOpacity(0.5);

    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        border: isToday 
            ? Border.all(color: Colors.white, width: 2.5) // [Modified] Explicit White Border 
            : null,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, top: 2.0),
            child: Text(
              day.day.toString(),
              style: TextStyle(
                color: textColor, // [Modified] Applied calculated color
                fontSize: 12,
                fontWeight: (isToday || day.weekday >= 6) ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          
          if (entries.isNotEmpty)
            Expanded(
              child: _currentMode == ViewMode.self
                  ? _buildSelfCellContent(entries)
                  : _buildAllCellContent(entries),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSelfCellContent(List<ScheduleEntry> entries) {
    final entry = entries.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 2, 2, 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: entry.shift.color,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Center(
        child: Text(
          entry.shift.name, 
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  Widget _buildAllCellContent(List<ScheduleEntry> entries) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
      child: Column(
        children: entries.take(4).map((entry) { 
          return Container(
            margin: const EdgeInsets.only(bottom: 2.0),
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
            decoration: BoxDecoration(
              color: entry.shift.color,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Center(
              child: Text(
                entry.employeeName, 
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showScheduleModal(DateTime day, List<ScheduleEntry> entries) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4, 
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.yMMMMd(l10n.localeName).add_EEEE().format(day), 
                style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1.0, 
                    thickness: 1.2, 
                    color: theme.dividerColor,
                    indent: 61.0, 
                    endIndent: 16.0,
                  ),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _buildScheduleTile(entry, colorScheme);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleTile(ScheduleEntry entry, ColorScheme colorScheme) {
    final Color iconColor = entry.shift.color;

    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10.0), 
      leading: Container(
        width: 29, 
        height: 29, 
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.2), 
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(CupertinoIcons.clock_fill, color: iconColor, size: 18),
      ),
      title: Text(
        entry.employeeName, 
        style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        entry.shift.name, 
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }
}