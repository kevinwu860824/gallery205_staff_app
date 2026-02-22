// lib/features/schedule/presentation/personal_schedule_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
// 🔥 1. 引入 RecurrenceRule 模型
import 'package:gallery205_staff_app/core/models/recurrence_rule.dart';

class PersonalScheduleScreen extends StatefulWidget {
  const PersonalScheduleScreen({super.key});

  @override
  State<PersonalScheduleScreen> createState() => _PersonalScheduleScreenState();
}

class _PersonalScheduleScreenState extends State<PersonalScheduleScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Map<String, dynamic>> _allEventsCache = [];
  List<Map<String, dynamic>> _availableGroups = [];
  Set<String> _customSelectedGroupIds = {};

  bool _isLoading = true;
  String? _currentShopId;
  String? _currentUserId;

  int _filterGroupValue = 1;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _initShopAndData();
  }

  Future<void> _handleEventNavigation({
    Map<String, dynamic>? event,
    VoidCallback? onRefresh,
  }) async {
    final bool? shouldRefresh = await context.push<bool>(
      '/eventDetail',
      extra: {
        'event': event,
        'group': event != null ? event['calendar_groups'] : null,
      },
    );

    if (shouldRefresh == true) {
      await _loadEvents();
      if (onRefresh != null) {
        onRefresh();
      }
    }
  }

  Future<void> _initShopAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    setState(() {
      _currentShopId = shopId;
    });

    await _ensurePersonalGroupExists(shopId, user.id);
    await _loadEvents();
  }

  Future<void> _ensurePersonalGroupExists(String shopId, String userId) async {
    final existingGroup = await Supabase.instance.client
        .from('calendar_groups')
        .select()
        .eq('shop_id', shopId)
        .eq('user_id', userId)
        .eq('name', '個人')
        .limit(1)
        .maybeSingle();

    if (existingGroup == null) {
      await Supabase.instance.client.from('calendar_groups').insert({
        'name': '個人',
        'shop_id': shopId,
        'user_id': userId,
        'visible_user_ids': [userId],
        'color': '#2196F3',
      });
    }
  }

  Future<void> _loadEvents() async {
    if (_currentShopId == null) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final groupResponse = await Supabase.instance.client
          .from('calendar_groups')
          .select()
          .eq('shop_id', _currentShopId!)
          .order('created_at');

      final List<Map<String, dynamic>> rawGroups =
          List<Map<String, dynamic>>.from(groupResponse);
      final List<Map<String, dynamic>> uniqueGroups = [];
      bool hasMyPersonalGroup = false;

      for (var group in rawGroups) {
        final groupName = group['name'] as String;
        final groupUserId = group['user_id'] as String;
        final isPersonalName = (groupName == '個人' || groupName == 'Personal');

        if (isPersonalName) {
          if (groupUserId == _currentUserId) {
            if (!hasMyPersonalGroup) {
              uniqueGroups.add(group);
              hasMyPersonalGroup = true;
            }
          }
        } else {
          uniqueGroups.add(group);
        }
      }

      final allGroupIds = rawGroups.map((e) => e['id']).toList();

      if (allGroupIds.isEmpty) {
        _updateCacheAndList([], []);
        return;
      }

      // 🔥 注意：這裡要多 select recurrence_rule
      final response = await Supabase.instance.client
          .from('calendar_events')
          .select('*, calendar_groups(id, name, color, visible_user_ids, user_id)')
          .inFilter('calendar_group_id', allGroupIds);

      final fetchedEvents = List<Map<String, dynamic>>.from(response);
      _updateCacheAndList(fetchedEvents, uniqueGroups);
    } catch (e) {
      debugPrint('❌ 載入事件失敗: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateCacheAndList(
      List<Map<String, dynamic>> events, List<Map<String, dynamic>> groups) {
    if (mounted) {
      setState(() {
        _allEventsCache = events;
        _availableGroups = groups;

        if (_customSelectedGroupIds.isEmpty && groups.isNotEmpty) {
          _customSelectedGroupIds =
              groups.map((g) => g['id'] as String).toSet();
        }

        _isLoading = false;
      });
    }
  }

  // -------------------------------------------------------------------
  // 插槽分配演算法 (升級版：支援複雜規則)
  // -------------------------------------------------------------------

  // 🔥 升級：使用 RecurrenceRule 判斷
  bool _isEventOnDay(Map<String, dynamic> event, DateTime day) {
    final start = DateTime.parse(event['start_time']).toLocal();
    final String repeat = event['repeat'] ?? 'none';
    
    // 1. 檢查截止日
    final recurrenceEndIso = event['recurrence_end_date'] as String?;
    final DateTime? recurrenceEnd = recurrenceEndIso != null
        ? DateTime.parse(recurrenceEndIso).toLocal()
        : null;

    final daySimple = DateTime(day.year, day.month, day.day);
    final startSimple = DateTime(start.year, start.month, start.day);
    
    if (daySimple.isBefore(startSimple)) return false;

    if (recurrenceEnd != null) {
      final endSimple = DateTime(recurrenceEnd.year, recurrenceEnd.month, recurrenceEnd.day);
      if (daySimple.isAfter(endSimple)) return false;
    }

    // 2. 判斷邏輯
    // A. 優先嘗試讀取複雜規則 JSON
    if (event['recurrence_rule'] != null) {
      try {
        final rule = RecurrenceRule.fromJson(event['recurrence_rule']);
        // 直接使用 Model 裡的 matches 方法！
        return rule.matches(day, start);
      } catch (e) {
        debugPrint('Rule parse error: $e');
        // 解析失敗則降級回舊邏輯
      }
    }

    // B. 舊邏輯 fallback
    if (repeat == 'none') {
      final end = DateTime.parse(event['end_time']).toLocal();
      // 全天事件修正
      DateTime effectiveEnd = end;
      if (event['all_day'] == true) {
         effectiveEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
      }
      final endSimple = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day);
      return !daySimple.isBefore(startSimple) && !daySimple.isAfter(endSimple);
    }

    switch (repeat) {
      case 'daily': return true;
      case 'weekly': return startSimple.weekday == daySimple.weekday;
      case 'monthly': return startSimple.day == daySimple.day;
      case 'yearly': return startSimple.day == daySimple.day && startSimple.month == daySimple.month;
      default: return false;
    }
  }

  // 🔥 升級：Tetris 演算法也要支援 RecurrenceRule
  List<Map<String, dynamic>?> _getEventsForWeekWithSlots(DateTime day) {
    final int daysFromSunday = day.weekday == 7 ? 0 : day.weekday;
    final DateTime weekStart = DateTime(day.year, day.month, day.day)
        .subtract(Duration(days: daysFromSunday));
    final DateTime weekEnd = weekStart
        .add(const Duration(days: 7))
        .subtract(const Duration(milliseconds: 1));

    List<_VisualEvent> visualEvents = [];

    for (var event in _allEventsCache) {
      // --- A. 篩選邏輯 ---
      final group = event['calendar_groups'];
      if (group == null) continue;

      bool isVisible = false;
      if (_filterGroupValue == 0) { 
        isVisible = (group['name'] == '個人' || group['name'] == 'Personal') &&
            group['user_id'] == _currentUserId;
      } else if (_filterGroupValue == 2) { 
        isVisible = _customSelectedGroupIds.contains(group['id']);
      } else { 
        isVisible = true;
      }
      if (!isVisible) continue;

      // --- B. 展開邏輯 ---
      final repeat = event['repeat'] ?? 'none';
      final bool isAllDay = event['all_day'] == true;
      final rawStart = DateTime.parse(event['start_time']).toLocal();
      DateTime rawEnd = DateTime.parse(event['end_time']).toLocal();

      if (isAllDay) {
        rawEnd = DateTime(rawEnd.year, rawEnd.month, rawEnd.day, 23, 59, 59);
      }
      
      Duration duration;
      bool isRepeating = repeat != 'none';
      RecurrenceRule? rule;

      // 嘗試解析複雜規則
      if (event['recurrence_rule'] != null) {
        try {
          rule = RecurrenceRule.fromJson(event['recurrence_rule']);
          isRepeating = true;
        } catch (_) {}
      }

      if (!isRepeating) {
        duration = rawEnd.difference(rawStart);
      } else {
        // 循環事件：計算單次 Duration
        DateTime effectiveEnd = DateTime(
          rawStart.year, rawStart.month, rawStart.day,
          rawEnd.hour, rawEnd.minute, rawEnd.second
        );
        if (effectiveEnd.isBefore(rawStart)) {
          effectiveEnd = effectiveEnd.add(const Duration(days: 1));
        }
        duration = effectiveEnd.difference(rawStart);
        if (duration.inHours > 24) duration = const Duration(hours: 24);
      }

      final recurrenceEndIso = event['recurrence_end_date'] as String?;
      final DateTime? recurrenceEnd = recurrenceEndIso != null
          ? DateTime.parse(recurrenceEndIso).toLocal()
          : null;

      if (!isRepeating) {
        // [非循環]
        if (rawEnd.isAfter(weekStart) && rawStart.isBefore(weekEnd)) {
          visualEvents.add(_VisualEvent(
            originalEvent: event,
            start: rawStart,
            end: rawEnd,
            isAllDay: isAllDay,
          ));
        }
      } else {
        // [循環]：逐日展開
        DateTime checkDay = weekStart;
        while (checkDay.isBefore(weekEnd)) {
          // 檢查截止日
          if (recurrenceEnd != null) {
             final checkSimple = DateTime(checkDay.year, checkDay.month, checkDay.day);
             final endSimple = DateTime(recurrenceEnd.year, recurrenceEnd.month, recurrenceEnd.day);
             if (checkSimple.isAfter(endSimple)) {
               checkDay = checkDay.add(const Duration(days: 1));
               continue;
             }
          }

          // 核心判斷：是否符合規則
          bool matches = false;
          if (rule != null) {
            // 使用新規則
            matches = rule.matches(checkDay, rawStart);
          } else {
            // 使用舊規則 fallback
            if (!checkDay.isBefore(DateTime(rawStart.year, rawStart.month, rawStart.day))) {
               switch (repeat) {
                  case 'daily': matches = true; break;
                  case 'weekly': matches = rawStart.weekday == checkDay.weekday; break;
                  case 'monthly': matches = rawStart.day == checkDay.day; break;
                  case 'yearly': matches = rawStart.day == checkDay.day && rawStart.month == checkDay.month; break;
               }
            }
          }

          if (matches) {
            final instanceStart = DateTime(
                checkDay.year, checkDay.month, checkDay.day,
                rawStart.hour, rawStart.minute, rawStart.second
            );
            final instanceEnd = instanceStart.add(duration);

            visualEvents.add(_VisualEvent(
              originalEvent: event,
              start: instanceStart,
              end: instanceEnd,
              isAllDay: isAllDay,
            ));
          }
          checkDay = checkDay.add(const Duration(days: 1));
        }
      }
    }

    // 3. 排序
    visualEvents.sort((a, b) {
      int cmpStart = a.start.compareTo(b.start);
      if (cmpStart != 0) return cmpStart;
      final durationA = a.end.difference(a.start);
      final durationB = b.end.difference(b.start);
      return durationB.compareTo(durationA);
    });

    // 4. 分配行數 (Tetris)
    List<DateTime> rowOccupiedUntil = [];
    for (var vEvent in visualEvents) {
      int assignedRow = -1;
      for (int i = 0; i < rowOccupiedUntil.length; i++) {
        if (!rowOccupiedUntil[i].isAfter(vEvent.start)) {
          assignedRow = i;
          DateTime endOfDay = DateTime(vEvent.end.year, vEvent.end.month, vEvent.end.day, 23, 59, 59);
          DateTime effectiveOccupied = vEvent.end.isAfter(endOfDay) ? vEvent.end : endOfDay;
          rowOccupiedUntil[i] = effectiveOccupied;
          break;
        }
      }
      if (assignedRow == -1) {
        DateTime endOfDay = DateTime(vEvent.end.year, vEvent.end.month, vEvent.end.day, 23, 59, 59);
        DateTime effectiveOccupied = vEvent.end.isAfter(endOfDay) ? vEvent.end : endOfDay;
        rowOccupiedUntil.add(effectiveOccupied);
        assignedRow = rowOccupiedUntil.length - 1;
      }
      vEvent.assignedRow = assignedRow;
    }

    // 5. 取出「當天」
    final int maxRows = 6;
    final DateTime dayStart = DateTime(day.year, day.month, day.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    List<_VisualEvent> eventsOnDay = visualEvents.where((v) {
      return !v.start.isAfter(dayEnd) && !v.end.isBefore(dayStart);
    }).toList();

    eventsOnDay.sort((a, b) => a.assignedRow.compareTo(b.assignedRow));

    return eventsOnDay.take(maxRows).map((v) => v.originalEvent).toList();
  }

  // --- 後續 UI 構建邏輯保持不變 ---

  int _calculateRowCount(DateTime focusedDay) {
    final firstDayOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
    final lastDayOfMonth = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final int firstWeekday = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;
    final DateTime calendarStartDate = firstDayOfMonth.subtract(Duration(days: firstWeekday));
    final int lastWeekday = lastDayOfMonth.weekday == 7 ? 0 : lastDayOfMonth.weekday;
    final int daysConfigured = (lastDayOfMonth.difference(calendarStartDate).inDays) + 1;
    final int daysToEndOfWeek = 6 - lastWeekday;
    final int totalDaysVisible = daysConfigured + daysToEndOfWeek;
    return (totalDaysVisible / 7).ceil();
  }

  List<Map<String, dynamic>> _getEventsForDaySimple(DateTime day) {
    final eventsOnDay = _allEventsCache.where((e) => _isEventOnDay(e, day));
    return eventsOnDay.where((event) {
      final group = event['calendar_groups'];
      if (group == null) return false;
      if (_filterGroupValue == 0) {
        final isPersonal = group['name'] == '個人' || group['name'] == 'Personal';
        return isPersonal && group['user_id'] == _currentUserId;
      }
      if (_filterGroupValue == 2) {
        return _customSelectedGroupIds.contains(group['id']);
      }
      return true;
    }).toList();
  }

  Color _hexToColor(String? hex) {
    if (hex == null) return Theme.of(context).colorScheme.primary;
    String cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatTimeRange(String? startIso, String? endIso) {
    if (startIso == null || endIso == null) return '';
    final start = DateTime.tryParse(startIso)?.toLocal();
    final end = DateTime.tryParse(endIso)?.toLocal();
    if (start == null || end == null) return '';
    return '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _showDayDetails(selectedDay);
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDay = now;
      _selectedDay = now;
    });
  }

  void _showCustomFilterDialog() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.scheduleSelectGroups,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text(l10n.commonDone, style: TextStyle(color: colorScheme.primary)),
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      }),
                ],
              ),
              Divider(color: theme.dividerColor),
              Expanded(
                child: ListView.builder(
                  itemCount: _availableGroups.length,
                  itemBuilder: (context, index) {
                    final group = _availableGroups[index];
                    final groupId = group['id'] as String;
                    final isSelected = _customSelectedGroupIds.contains(groupId);
                    final color = _hexToColor(group['color']);
                    final isPersonal = group['name'] == '個人' || group['name'] == 'Personal';
                    final displayName = isPersonal
                        ? l10n.schedulePersonalMe
                        : (group['name'] ?? l10n.scheduleUntitled);
                    return ListTile(
                      leading: Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      title: Text(displayName, style: TextStyle(color: colorScheme.onSurface)),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: colorScheme.primary)
                          : const Icon(Icons.circle_outlined, color: Colors.grey),
                      onTap: () => setSheetState(() {
                        if (isSelected)
                          _customSelectedGroupIds.remove(groupId);
                        else
                          _customSelectedGroupIds.add(groupId);
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthYearPicker() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    DateTime tempDate = _focusedDay;
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: theme.cardColor,
        child: Column(children: [
          Container(
            color: theme.cardColor.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              CupertinoButton(padding: EdgeInsets.zero, child: Text(l10n.commonCancel, style: const TextStyle(color: Colors.grey)), onPressed: () => Navigator.of(ctx).pop()),
              CupertinoButton(padding: EdgeInsets.zero, child: Text(l10n.commonDone, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)), onPressed: () {
                setState(() {
                  _focusedDay = tempDate;
                  if (_selectedDay?.month != tempDate.month || _selectedDay?.year != tempDate.year)
                    _selectedDay = DateTime(tempDate.year, tempDate.month, 1);
                });
                _loadEvents();
                Navigator.of(ctx).pop();
              }),
            ]),
          ),
          Expanded(
              child: CupertinoTheme(
                  data: CupertinoThemeData(brightness: theme.brightness),
                  child: CupertinoDatePicker(mode: CupertinoDatePickerMode.monthYear, initialDateTime: _focusedDay, minimumDate: DateTime(2020), maximumDate: DateTime(2030), onDateTimeChanged: (newDate) => tempDate = newDate))),
        ]),
      ),
    );
  }

  void _showDayDetails(DateTime day) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (context, setSheetState) {
        final events = _getEventsForDaySimple(day);
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
            Text(DateFormat.yMMMd(l10n.localeName).format(day) + ' ' + DateFormat.E(l10n.localeName).format(day), style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(child: events.isEmpty ? Center(child: Text(l10n.scheduleNoEvents, style: const TextStyle(color: Colors.grey))) : ListView.builder(itemCount: events.length, itemBuilder: (context, index) => _buildEventListCard(events[index], onRefresh: () => setSheetState(() {})))),
          ]),
        );
      }),
    );
  }

  Widget _buildEventListCard(Map<String, dynamic> event, {VoidCallback? onRefresh}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String? eventHexColor = event['color'] ?? event['calendar_groups']?['color'];
    Color eventColor = _hexToColor(eventHexColor);
    String? groupHexColor = event['calendar_groups']?['color'];
    Color groupColor = _hexToColor(groupHexColor);
    bool allDay = event['all_day'] == true;
    String timeLabel = allDay ? l10n.scheduleAllDay : _formatTimeRange(event['start_time'], event['end_time']);

    return GestureDetector(
      onTap: () => _handleEventNavigation(event: event, onRefresh: onRefresh),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: eventColor, width: 4))),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(children: [
          SizedBox(width: 75, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(allDay ? 'All' : timeLabel.split(' - ')[0], style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)), if (!allDay) ...[const SizedBox(height: 4), Text(timeLabel.split(' - ').length > 1 ? timeLabel.split(' - ')[1] : '', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13))], if (allDay) Text(l10n.scheduleDayLabel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))])),
          Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(event['title'] ?? l10n.scheduleUntitled, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis), if (event['note'] != null && event['note'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(event['note'], style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)), const SizedBox(height: 4), Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: groupColor, shape: BoxShape.circle)), const SizedBox(width: 6), Text(event['calendar_groups']?['name'] ?? 'Personal', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))])])),
          Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurfaceVariant, size: 16),
        ]),
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
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface), onPressed: () => context.pop()),
        title: Text(l10n.scheduleTitle, style: TextStyle(color: colorScheme.onSurface)),
        actions: [
          IconButton(icon: Icon(CupertinoIcons.settings, color: colorScheme.onSurface), onPressed: () async { await context.push('/calendarGroupSettings'); _loadEvents(); }),
          IconButton(icon: Icon(CupertinoIcons.add, color: colorScheme.onSurface), onPressed: () => _handleEventNavigation(event: null)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.scaffoldBackgroundColor,
            child: Row(children: [
              Expanded(child: CupertinoSlidingSegmentedControl<int>(
                backgroundColor: theme.cardColor, 
                thumbColor: colorScheme.inverseSurface, // Contrast color for thumb
                groupValue: _filterGroupValue, 
                children: {
                  0: Text(l10n.scheduleTabMy, style: TextStyle(color: _filterGroupValue == 0 ? colorScheme.onInverseSurface : colorScheme.onSurface)), 
                  1: Text(l10n.scheduleTabAll, style: TextStyle(color: _filterGroupValue == 1 ? colorScheme.onInverseSurface : colorScheme.onSurface)), 
                  2: Text(l10n.scheduleTabCustom, style: TextStyle(color: _filterGroupValue == 2 ? colorScheme.onInverseSurface : colorScheme.onSurface))
                }, 
                onValueChanged: (val) { if (val != null) setState(() => _filterGroupValue = val); }
              )),
              if (_filterGroupValue == 2) ...[const SizedBox(width: 8), IconButton(icon: Icon(Icons.filter_list, color: colorScheme.primary), onPressed: _showCustomFilterDialog, tooltip: l10n.scheduleFilterTooltip)],
            ]),
          ),
          _buildCustomHeader(),
          Expanded(
            child: _isLoading ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)) : LayoutBuilder(builder: (context, constraints) {
              final double availableHeight = constraints.maxHeight;
              final double daysOfWeekHeight = 30.0;
              final int rowCount = _calculateRowCount(_focusedDay);
              final double rowHeight = (availableHeight - daysOfWeekHeight) / rowCount;
              final int maxVisibleEvents = ((rowHeight - 22 - 1) / 14.0).floor();

              return TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                headerVisible: false,
                shouldFillViewport: true,
                daysOfWeekHeight: 40.0,
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold), 
                  weekendStyle: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                locale: l10n.localeName,
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(day, maxCount: maxVisibleEvents),
                  todayBuilder: (context, day, focusedDay) => _buildCalendarCell(day, isToday: true, maxCount: maxVisibleEvents),
                  selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(day, isSelected: true, maxCount: maxVisibleEvents),
                  outsideBuilder: (context, day, focusedDay) => _buildCalendarCell(day, isOutside: true, maxCount: maxVisibleEvents),
                ),
                onDaySelected: _onDaySelected,
                onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCell(DateTime day, {bool isToday = false, bool isSelected = false, bool isOutside = false, required int maxCount}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final eventsWithSlots = _getEventsForWeekWithSlots(day);

    // [Modified] User requested Blue(Sat) and Red(Sun) but with better contrast against #8DA399
    // Using darker/stronger shades:
    Color dateColor = colorScheme.onSurface; // Default White
    
    if (!isOutside) {
      if (day.weekday == DateTime.saturday) dateColor = const Color(0xFF0044CC); // Darker Blue
      if (day.weekday == DateTime.sunday) dateColor = const Color(0xFFCC0000); // Darker Red
    }
    
    if (isOutside) dateColor = colorScheme.onSurfaceVariant.withOpacity(0.5);
    
    // Today always keeps the color but adds the border.
    // However, if today is Sat/Sun, it will keep the Sat/Sun color.
    
    return GestureDetector(
      onTap: () => _onDaySelected(day, _focusedDay),
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isSelected ? theme.cardColor : Colors.transparent, 
          // [Modified] Today gets a White Border
          border: isToday 
              ? Border.all(color: Colors.white, width: 2.5) 
              : Border(top: BorderSide(color: theme.dividerColor, width: 0.3))
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(left: 4, top: 4, bottom: 2), child: Text('${day.day}', style: TextStyle(color: dateColor, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, fontSize: 14))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: eventsWithSlots.length > maxCount ? maxCount : eventsWithSlots.length,
                  itemBuilder: (context, index) {
                    if (index == maxCount - 1 && eventsWithSlots.length > maxCount) {
                      int hiddenRealEvents = 0;
                      for (int i = index; i < eventsWithSlots.length; i++) { if (eventsWithSlots[i] != null) hiddenRealEvents++; }
                      if (hiddenRealEvents > 0) return Container(height: 14, padding: const EdgeInsets.only(left: 2), alignment: Alignment.centerLeft, child: Text(l10n.scheduleMoreEvents(hiddenRealEvents), style: const TextStyle(color: Colors.grey, fontSize: 10)));
                    }
                    final event = eventsWithSlots[index];
                    if (event == null) return const SizedBox(height: 14);
                    return _buildEventChip(event, currentDay: day);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventChip(Map<String, dynamic> event, {required DateTime currentDay}) {
    final l10n = AppLocalizations.of(context)!;
    String? hexColor = event['color'] ?? event['calendar_groups']?['color'];
    Color bgColor = _hexToColor(hexColor);
    String title = event['title'] ?? l10n.commonNoTitle;

    BorderRadiusGeometry borderRadius = BorderRadius.circular(6);
    EdgeInsets margin = const EdgeInsets.only(bottom: 2);
    bool showTitle = true;
    bool shouldShiftLeft = false;

    // 🔥 循環事件邏輯修正 (Recurrence Rule)
    bool isRepeating = event['repeat'] != null && event['repeat'] != 'none';
    if (event['recurrence_rule'] != null) isRepeating = true;

    final start = DateTime.parse(event['start_time']).toLocal();
    final end = DateTime.parse(event['end_time']).toLocal();
    final currentSimple = DateTime(currentDay.year, currentDay.month, currentDay.day);

    if (isRepeating) {
      borderRadius = BorderRadius.circular(3);
      margin = const EdgeInsets.only(top: 0, bottom: 2, left: 2.0, right: 2.0);
      showTitle = true;
      shouldShiftLeft = false;
    } else {
      final startSimple = DateTime(start.year, start.month, start.day);
      final endSimple = DateTime(end.year, end.month, end.day);
      bool isEventStart = isSameDay(currentSimple, startSimple);
      bool isEventEnd = isSameDay(currentSimple, endSimple);
      bool isRowStart = currentSimple.weekday == 7;
      bool isRowEnd = currentSimple.weekday == 6;
      bool roundLeft = isEventStart || isRowStart;
      bool roundRight = isEventEnd || isRowEnd;

      int dayOffset = currentSimple.weekday == 7 ? 0 : currentSimple.weekday;
      DateTime weekStart = currentSimple.subtract(Duration(days: dayOffset));
      DateTime weekEnd = weekStart.add(const Duration(days: 6));
      DateTime rangeStart = startSimple.isAfter(weekStart) ? startSimple : weekStart;
      DateTime rangeEnd = endSimple.isBefore(weekEnd) ? endSimple : weekEnd;

      int daysSpan = rangeEnd.difference(rangeStart).inDays + 1;
      int midIndex = (daysSpan / 2).floor();
      DateTime midDate = rangeStart.add(Duration(days: midIndex));
      showTitle = isSameDay(currentSimple, midDate);

      if (daysSpan % 2 == 0 && showTitle && currentSimple.weekday != 7) {
        shouldShiftLeft = true;
      }

      margin = EdgeInsets.only(top: 0, bottom: 2, left: roundLeft ? 2.0 : 0.0, right: roundRight ? 2.0 : 0.0);
      borderRadius = BorderRadius.horizontal(left: roundLeft ? const Radius.circular(3) : Radius.zero, right: roundRight ? const Radius.circular(3) : Radius.zero);
    }

    return GestureDetector(
      onTap: () => _onDaySelected(currentDay, _focusedDay),
      child: Container(
        height: 12, margin: margin, padding: EdgeInsets.zero,
        decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
        alignment: Alignment.center,
        child: LayoutBuilder(builder: (context, constraints) {
          Widget textWidget = Center(child: Text(showTitle ? title : '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false));
          if (shouldShiftLeft) return Transform.translate(offset: Offset(-constraints.maxWidth / 2, 0), child: SizedBox(width: constraints.maxWidth * 2, child: textWidget));
          return SizedBox(width: constraints.maxWidth, child: textWidget);
        }),
      ),
    );
  }

  Widget _buildCustomHeader() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final headerText = DateFormat.yMMMM(l10n.localeName).format(_focusedDay);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 20), onPressed: () { setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)); _loadEvents(); }),
        const SizedBox(width: 8),
        GestureDetector(onTap: _showMonthYearPicker, child: Row(children: [Text(headerText, style: TextStyle(color: colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(width: 4), Icon(CupertinoIcons.chevron_down, color: colorScheme.onSurfaceVariant, size: 14)])),
        const SizedBox(width: 20),
        GestureDetector(onTap: _jumpToToday, child: Text(l10n.commonToday, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))), // Keep white for contrast if needed, or use colorScheme
        const SizedBox(width: 8),
        IconButton(icon: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface, size: 20), onPressed: () { setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)); _loadEvents(); }),
      ]),
    );
  }
}

class _VisualEvent {
  final Map<String, dynamic> originalEvent;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
  int assignedRow = 0;

  _VisualEvent({
    required this.originalEvent,
    required this.start,
    required this.end,
    this.isAllDay = false,
  });
}