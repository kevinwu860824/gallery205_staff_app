// lib/features/schedule/presentation/event_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/core/services/notification_helper.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
// 🔥 記得 import 這兩個新檔案
import 'package:gallery205_staff_app/features/schedule/presentation/recurrence_picker.dart';
import 'package:gallery205_staff_app/core/models/recurrence_rule.dart';
import 'package:gallery205_staff_app/core/services/widget_session_service.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? event;
  final Map<String, dynamic>? group;
  final DateTime? initialDate;

  const EventDetailScreen({
    super.key,
    this.event,
    this.group,
    this.initialDate,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  // 表單控制器
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  
  // 表單資料狀態
  late DateTime _startTime;
  late DateTime _endTime;
  
  // 🔥 新增：複雜重複規則物件 & 截止日
  RecurrenceRule? _recurrenceRule;
  DateTime? _recurrenceEndDate;
  
  // 舊版相容 (僅用於 UI 顯示邏輯判斷，實際存檔以 _recurrenceRule 為主)
  String _repeat = 'none'; 
  
  bool _allDay = false;
  
  // 選項資料
  String? _selectedGroupId;
  List<String> _selectedUserIds = [];
  String? _selectedEventColor; 

  // 下拉選單資料來源
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _shopUsers = [];
  List<Map<String, dynamic>> _availableEventColors = [];

  // 頁面狀態
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isViewMode = false;
  
  String? _currentShopId;
  String? _currentUserId;

  // 舊版選項 (僅備用)
  final List<String> _repeatOptions = ['none', 'daily', 'weekly', 'monthly'];

  String get _myDisplayName {
    final user = _shopUsers.firstWhere(
      (u) => u['user_id'] == _currentUserId,
      orElse: () => {'name': 'Someone'},
    );
    return user['name'];
  }

  String get _currentGroupName {
    final group = _groups.firstWhere(
      (g) => g['id'] == _selectedGroupId,
      orElse: () => {'name': 'Unknown'},
    );
    return group['name'] == '個人' ? 'Personal' : group['name'];
  }

  List<String> _calculateNotifyTargets() {
    final Set<String> targets = {};
    final group = _groups.firstWhere((g) => g['id'] == _selectedGroupId, orElse: () => {});
    if (group.isNotEmpty && group['name'] != '個人' && group['name'] != 'Personal') {
      final members = List<String>.from(group['visible_user_ids'] ?? []);
      targets.addAll(members);
    }
    targets.addAll(_selectedUserIds);
    return targets.toList();
  }

  Future<void> _sendCloudNotification({
    required String title,
    required String body,
  }) async {
    final targets = _calculateNotifyTargets();
    if (targets.isEmpty) return;

    try {
      await supabase.functions.invoke('notify-calendar-event', body: {
        'title': title,
        'body': body,
        'target_user_ids': targets,
        'route': '/personalSchedule',
        'shop_id': _currentShopId,
      });
    } catch (e) {
      debugPrint('Notification Error: $e');
    }
  }
  
  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _isViewMode = widget.event != null;
    
    final e = widget.event;
    
    _titleController = TextEditingController(text: e?['title'] ?? '');
    _noteController = TextEditingController(text: e?['note'] ?? '');
    
    if (e != null) {
      _startTime = DateTime.parse(e['start_time']).toLocal();
      _endTime = DateTime.parse(e['end_time']).toLocal();
      _allDay = e['all_day'] ?? false;
      
      _selectedGroupId = e['calendar_group_id'];
      _selectedUserIds = List<String>.from(e['related_user_ids'] ?? []);
      _selectedEventColor = e['color'];
      
      // 初始化循環截止日
      if (e['recurrence_end_date'] != null) {
        _recurrenceEndDate = DateTime.parse(e['recurrence_end_date']).toLocal();
      }

      // 🔥 初始化複雜規則 (讀取 DB JSON)
      if (e['recurrence_rule'] != null) {
        try {
          _recurrenceRule = RecurrenceRule.fromJson(e['recurrence_rule']);
          _repeat = _recurrenceRule!.freq; // 同步舊變數
        } catch (_) {
          _restoreSimpleRule(e['repeat']);
        }
      } else {
        // 如果沒有 JSON，嘗試從舊欄位還原
        _restoreSimpleRule(e['repeat']);
      }

    } else {
      final now = DateTime.now();
      if (widget.initialDate != null) {
        final d = widget.initialDate!;
        _startTime = DateTime(d.year, d.month, d.day, 9, 0);
        _endTime = DateTime(d.year, d.month, d.day, 10, 0);
      } else {
        final nextHour = (now.hour + 1).clamp(0, 23);
        _startTime = DateTime(now.year, now.month, now.day, nextHour, 0);
        _endTime = _startTime.add(const Duration(hours: 1));
      }
      _selectedGroupId = widget.group?['id'];
      if (_currentUserId != null) {
        _selectedUserIds = [_currentUserId!];
      }
    }

    _initData();
  }

  // 從舊版字串還原成 Rule 物件
  void _restoreSimpleRule(String? simpleRepeat) {
    if (simpleRepeat == null || simpleRepeat == 'none') {
      _recurrenceRule = null;
      _repeat = 'none';
    } else {
      _recurrenceRule = RecurrenceRule(freq: simpleRepeat);
      _repeat = simpleRepeat;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentShopId = prefs.getString('savedShopId');

    if (_currentShopId == null) {
      if (mounted) context.pop();
      return;
    }

    await Future.wait([
      _loadGroups(),
      _loadShopUsers(),
    ]);

    if (widget.event == null && _selectedGroupId == null && _groups.isNotEmpty) {
      final personal = _groups.firstWhere(
        (g) => g['name'] == '個人' && g['user_id'] == _currentUserId, 
        orElse: () => _groups.first
      );
      _selectedGroupId = personal['id'];
    }

    if (_selectedGroupId != null) {
      await _loadGroupColors(_selectedGroupId!);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadGroups() async {
    final res = await supabase
        .from('calendar_groups')
        .select()
        .eq('shop_id', _currentShopId!)
        .order('created_at');
    
    final all = List<Map<String, dynamic>>.from(res);
    final filtered = all.where((g) {
      if (g['name'] == '個人') return g['user_id'] == _currentUserId;
      return true;
    }).toList();

    setState(() => _groups = filtered);
  }

  Future<void> _loadGroupColors(String groupId) async {
    try {
      final res = await supabase
          .from('group_event_colors')
          .select()
          .eq('calendar_group_id', groupId)
          .order('created_at');
      
      if (mounted) {
        setState(() {
          _availableEventColors = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Load Group Colors Error: $e');
    }
  }

  Future<void> _loadShopUsers() async {
    final res = await supabase
        .from('users')
        .select('user_id, name')
        .eq('shop_id', _currentShopId!);
    setState(() => _shopUsers = List<Map<String, dynamic>>.from(res));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_titleController.text.trim().isEmpty) {
      _showError(l10n.eventDetailErrorTitleRequired);
      return;
    }
    if (_selectedGroupId == null) {
      _showError(l10n.eventDetailErrorGroupRequired);
      return;
    }
    if (!_allDay && _endTime.isBefore(_startTime)) {
      _showError(l10n.eventDetailErrorEndTime);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final finalColor = _selectedEventColor ?? _findGroupDefaultColor(_selectedGroupId);
      final isNew = widget.event == null;

      // 🔥 修正邏輯：處理循環事件的「結束時間殘留」問題
      DateTime saveEndTime = _endTime;
      final bool isRepeating = _recurrenceRule != null;
      
      if (isRepeating) {
        final durationInHours = _endTime.difference(_startTime).inHours;
        
        // 如果單次事件長度超過 24 小時，強制修正回當天
        if (durationInHours > 24) {
          final newEnd = DateTime(
            _startTime.year,
            _startTime.month,
            _startTime.day,
            _endTime.hour,
            _endTime.minute,
          );
          if (newEnd.isBefore(_startTime)) {
            saveEndTime = newEnd.add(const Duration(days: 1));
          } else {
            saveEndTime = newEnd;
          }
        }
      }

      final data = {
        'title': _titleController.text.trim(),
        'note': _noteController.text.trim(),
        'start_time': _startTime.toUtc().toIso8601String(),
        'end_time': saveEndTime.toUtc().toIso8601String(), // 使用修正後的 saveEndTime
        'all_day': _allDay,
        
        // 🔥 存入新結構
        'recurrence_rule': isRepeating ? _recurrenceRule!.toJson() : null,
        'repeat': isRepeating ? _recurrenceRule!.freq : 'none', // 保持相容性
        'recurrence_end_date': (isRepeating && _recurrenceEndDate != null)
            ? _recurrenceEndDate!.toUtc().toIso8601String()
            : null,
            
        'calendar_group_id': _selectedGroupId,
        'user_id': widget.event?['user_id'] ?? _currentUserId,
        'shop_id': _currentShopId,
        'related_user_ids': _selectedUserIds,
        'color': finalColor,
      };

      if (isNew) {
        await supabase.from('calendar_events').insert(data);
        
        String timeStr;
        if (_allDay) {
          final startStr = DateFormat('MM/dd').format(_startTime);
          final isSameDay = _startTime.year == saveEndTime.year &&
              _startTime.month == saveEndTime.month &&
              _startTime.day == saveEndTime.day;
          timeStr = isSameDay ? '$startStr (${l10n.eventDetailLabelAllDay})' : '$startStr - ${DateFormat('MM/dd').format(saveEndTime)}';
        } else {
          timeStr = DateFormat('MM/dd HH:mm').format(_startTime);
        }

        await _sendCloudNotification(
          title: l10n.notificationNewEventTitle(_currentGroupName),
          body: l10n.notificationNewEventBody(_myDisplayName, _titleController.text, timeStr),
        );

      } else {
        final oldStart = DateTime.parse(widget.event!['start_time']).toLocal();
        final bool timeChanged = oldStart != _startTime;

        await supabase.from('calendar_events').update(data).eq('id', widget.event!['id']);

        if (timeChanged) {
           await _sendCloudNotification(
            title: l10n.notificationTimeChangeTitle,
            body: l10n.notificationTimeChangeBody(_myDisplayName, _titleController.text),
          );
        } else {
           await _sendCloudNotification(
            title: l10n.notificationContentChangeTitle,
            body: l10n.notificationContentChangeBody(_myDisplayName, _titleController.text),
          );
        }
      }

      final String eventTitle = data['title'] as String;
      final int eventIdHash = eventTitle.hashCode; 
      
      await NotificationHelper.cancel(eventIdHash);

      final reminderTime = _startTime.subtract(const Duration(minutes: 10));
      
      if (reminderTime.isAfter(DateTime.now())) {
        await NotificationHelper.scheduleNotification(
          id: eventIdHash,
          title: l10n.localNotificationTitle,
          body: l10n.localNotificationBody(eventTitle),
          scheduledDate: reminderTime,
        );
      }

      await WidgetSessionService.reloadWidget();

      if (mounted) {
        context.pop(true); 
      }
    } catch (e) {
      debugPrint('Save Error: $e');
      _showError(l10n.eventDetailErrorSave);
      setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.eventDetailDelete),
        content: Text(l10n.eventDetailDeleteConfirm),
        actions: [
          CupertinoDialogAction(child: Text(l10n.commonCancel), onPressed: () => Navigator.pop(ctx, false)),
          CupertinoDialogAction(isDestructiveAction: true, child: Text(l10n.commonDelete), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await _sendCloudNotification(
          title: l10n.notificationDeleteTitle,
          body: l10n.notificationDeleteBody(_myDisplayName, _titleController.text),
        );

        await supabase.from('calendar_events').delete().eq('id', widget.event!['id']);
        
        await WidgetSessionService.reloadWidget();

        if (mounted) context.pop(true);
      } catch (e) {
        debugPrint('Delete Error: $e');
        _showError(l10n.eventDetailErrorDelete);
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNewEvent = widget.event == null;
    
    return _isViewMode && !isNewEvent 
        ? _buildViewUI(l10n) 
        : _buildEditUI(l10n, isNewEvent);
  }

  Widget _buildViewUI(AppLocalizations l10n) {
    final displayColorHex = _selectedEventColor ?? _findGroupDefaultColor(_selectedGroupId);
    final relatedCount = _selectedUserIds.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double hPadding = isTablet ? (screenWidth - 600) / 2 : 16.0;
    
    // 顯示複雜規則的文字
    String repeatLabel = _recurrenceRule != null ? _recurrenceRule.toString() : 'None';
    // 這裡可以用 l10n 做更漂亮的轉換，暫時用 toString
    if (l10n.localeName == 'zh' && _recurrenceRule != null) {
       // 簡單的中文化範例，如果要完整支援建議在 RecurrenceRule 加個 toLocalizedString
       if (_recurrenceRule!.freq == 'daily') repeatLabel = '每天';
       else if (_recurrenceRule!.freq == 'weekly') repeatLabel = '每週';
       else if (_recurrenceRule!.freq == 'monthly') repeatLabel = '每月';
       else if (_recurrenceRule!.freq == 'yearly') repeatLabel = '每年';
    }

    if (_recurrenceRule != null && _recurrenceEndDate != null) {
      final dateStr = DateFormat('yyyy/MM/dd').format(_recurrenceEndDate!);
      repeatLabel += ' (直到 $dateStr)'; 
    } else if (_recurrenceRule != null) {
      repeatLabel += ' (永不停止)'; 
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Event Details', style: TextStyle(color: colorScheme.onSurface)), 
        actions: [
          IconButton(
            // 🔥 修改點：右上角的筆改成白色 (textPrimary)
            icon: Icon(Icons.edit, color: colorScheme.onSurface),
            onPressed: () => setState(() => _isViewMode = false),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border(left: BorderSide(color: _hexToColor(displayColorHex), width: 6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text,
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(CupertinoIcons.time, color: colorScheme.onSurfaceVariant, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _formatDisplayDate(_startTime, isStart: true),
                            // 這裡之前已經改過，保持白色
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (!_allDay) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const SizedBox(width: 26), 
                            Text(
                              _formatDisplayDate(_endTime, isStart: false),
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildViewRow(l10n.eventDetailLabelGroup, _getGroupName(_selectedGroupId), icon: CupertinoIcons.folder, colorScheme: colorScheme),
                      Divider(color: theme.dividerColor, height: 1),
                      _buildViewRow(l10n.eventDetailLabelRepeat, repeatLabel, icon: CupertinoIcons.repeat, colorScheme: colorScheme),
                      Divider(color: theme.dividerColor, height: 1),
                      _buildViewRow(l10n.eventDetailLabelRelatedPeople, relatedCount == 0 ? l10n.eventDetailNone : l10n.eventDetailPeopleCount(relatedCount), icon: CupertinoIcons.person_2, colorScheme: colorScheme),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (_noteController.text.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(CupertinoIcons.doc_text, color: colorScheme.onSurfaceVariant, size: 16),
                            const SizedBox(width: 8),
                            Text(l10n.eventDetailLabelNotes, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _noteController.text,
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 16, height: 1.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEditUI(AppLocalizations l10n, bool isNewEvent) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double hPadding = isTablet ? (screenWidth - 600) / 2 : 16.0;
    
    // 顯示文字
    String repeatLabel = _recurrenceRule != null ? _recurrenceRule.toString() : 'None';
    if (_recurrenceRule != null && _recurrenceEndDate != null) {
      final dateStr = DateFormat('yyyy/MM/dd').format(_recurrenceEndDate!);
      repeatLabel += ' (Until $dateStr)';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.xmark, color: colorScheme.onSurface),
          onPressed: () {
            if (isNewEvent) {
              context.pop();
            } else {
              setState(() => _isViewMode = true);
            }
          },
        ),
        title: Text(
          isNewEvent ? l10n.eventDetailTitleNew : l10n.eventDetailTitleEdit,
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? CupertinoActivityIndicator(color: colorScheme.primary)
                : Icon(Icons.check, color: colorScheme.primary),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
              children: [
                _buildSection([
                  CupertinoTextField(
                    controller: _titleController,
                    placeholder: l10n.eventDetailLabelTitle,
                    placeholderStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 18),
                    decoration: null,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    cursorColor: colorScheme.primary,
                  ),
                  Divider(color: theme.dividerColor, height: 1),
                  _buildRowItem(
                    label: l10n.eventDetailLabelGroup,
                    value: _getGroupName(_selectedGroupId),
                    onTap: _showGroupPicker,
                    showArrow: true,
                    colorScheme: colorScheme,
                  ),
                  Divider(color: theme.dividerColor, height: 1),
                  _buildRowItem(
                    label: l10n.eventDetailLabelColor,
                    value: _getColorNameOrHex(_selectedEventColor),
                    onTap: _showEventColorPicker,
                    showArrow: true,
                    iconColor: _hexToColor(_selectedEventColor ?? _findGroupDefaultColor(_selectedGroupId)),
                    colorScheme: colorScheme,
                  ),
                ], theme),

                const SizedBox(height: 24),

                _buildSection([
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.eventDetailLabelAllDay, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
                        CupertinoSwitch(
                          value: _allDay,
                          activeColor: colorScheme.primary,
                          onChanged: (val) => setState(() => _allDay = val),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: theme.dividerColor, height: 1),
                  
                  // 開始時間 (永遠顯示)
                  _buildRowItem(
                    label: l10n.eventDetailLabelStarts,
                    value: _formatDisplayDate(_startTime, isStart: true),
                    onTap: () => _pickDateTime(isStart: true),
                    valueColor: colorScheme.onSurface,
                    colorScheme: colorScheme,
                  ),
                  Divider(color: theme.dividerColor, height: 1),
                  
                  // 只有在「不重複」的時候，才顯示「結束時間」
                  if (_recurrenceRule == null) ...[
                    _buildRowItem(
                      label: l10n.eventDetailLabelEnds,
                      value: _formatDisplayDate(_endTime, isStart: false),
                      onTap: () => _pickDateTime(isStart: false),
                      valueColor: colorScheme.onSurface,
                      colorScheme: colorScheme,
                    ),
                    Divider(color: theme.dividerColor, height: 1),
                  ],
                  
                  // 🔥 重複選項 (串接新 Picker)
                  _buildRowItem(
                    label: l10n.eventDetailLabelRepeat,
                    value: repeatLabel,
                    onTap: _showRepeatPicker,
                    showArrow: true,
                    colorScheme: colorScheme,
                  ),
                ], theme),

                const SizedBox(height: 24),

                _buildSection([
                  _buildRowItem(
                    label: l10n.eventDetailLabelRelatedPeople,
                    value: _selectedUserIds.isEmpty
                        ? l10n.eventDetailNone
                        : l10n.eventDetailPeopleCount(_selectedUserIds.length),
                    onTap: _showUserPicker,
                    showArrow: true,
                    colorScheme: colorScheme,
                  ),
                  Divider(color: theme.dividerColor, height: 1),
                  CupertinoTextField(
                    controller: _noteController,
                    placeholder: l10n.eventDetailLabelNotes,
                    placeholderStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: null,
                    maxLines: 4,
                    minLines: 2,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    cursorColor: colorScheme.primary,
                  ),
                ], theme),

                const SizedBox(height: 32),

                if (!isNewEvent)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CupertinoButton(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      padding: EdgeInsets.zero,
                      onPressed: _delete,
                      child: Text(
                        l10n.eventDetailDelete,
                        style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  // --- 輔助元件與函式 ---

  Widget _buildSection(List<Widget> children, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildViewRow(String label, String value, {required IconData icon, required ColorScheme colorScheme}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)),
          const Spacer(),
          Text(value, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildRowItem({
    required String label, 
    required String value, 
    required VoidCallback onTap, 
    required ColorScheme colorScheme,
    bool showArrow = false,
    Color? valueColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            if (iconColor != null) ...[
              Container(width: 12, height: 12, decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle)),
              const SizedBox(width: 12),
            ],
            Text(label, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
            const Spacer(),
            Text(value, style: TextStyle(color: valueColor ?? colorScheme.onSurfaceVariant, fontSize: 16)),
            if (showArrow) ...[
              const SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurfaceVariant, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  // 🔥 串接新的 Picker
  void _showRepeatPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecurrencePicker(
        initialStartDate: _startTime,
        initialRule: _recurrenceRule,
        initialEndDate: _recurrenceEndDate,
      ),
    );

    if (result != null) {
      final RecurrenceRule rule = result['rule'];
      final DateTime? endDate = result['endDate'];

      setState(() {
        _recurrenceRule = rule;
        _recurrenceEndDate = endDate;
        
        // 相容舊邏輯變數 (UI顯示用)
        _repeat = rule.freq; 
      });
    }
  }

  // --- 後續的 Picker 保持不變 ---
  
  // (省略 _showRecurrenceEndPicker, _pickRecurrenceDate, 因為新 UI 已經整合在 RecurrencePicker 內了，這邊其實可以移除，但為了避免錯誤先保留也無妨)
  // 不過，既然 RecurrencePicker 已經處理了 end date，上面的 _buildEditUI 已經改用 _showRepeatPicker
  // 所以舊的 _showRecurrenceEndPicker 其實不會被呼叫到了。

  Future<void> _pickDateTime({required bool isStart}) async {
    final l10n = AppLocalizations.of(context)!;
    final initialDate = isStart ? _startTime : _endTime;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Locale locale;
    if (l10n.localeName == 'zh') {
      locale = const Locale('zh', 'TW');
    } else {
      locale = const Locale('en', 'US');
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      locale: locale, 
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.primary, 
              onPrimary: colorScheme.onPrimary,   
              surface: theme.cardColor, 
              onSurface: colorScheme.onSurface,  
            ),
            dialogBackgroundColor: theme.cardColor, 
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    TimeOfDay pickedTime = TimeOfDay.fromDateTime(initialDate);
    if (!_allDay) {
      final TimeOfDay? t = await showTimePicker(
        context: context,
        initialTime: pickedTime,
        builder: (context, child) {
          return Theme(
            data: theme.copyWith(
              colorScheme: colorScheme.copyWith(
                primary: colorScheme.primary,
                onPrimary: colorScheme.onPrimary,
                surface: theme.cardColor,
                onSurface: colorScheme.onSurface,
              ),
              timePickerTheme: TimePickerThemeData(
                backgroundColor: theme.cardColor,
              ),
            ),
            child: child!,
          );
        },
      );
      if (t == null) return; 
      pickedTime = t;
    }

    setState(() {
      final newDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _allDay ? 0 : pickedTime.hour, 
        _allDay ? 0 : pickedTime.minute,
      );

      if (isStart) {
        _startTime = newDateTime;
        if (_endTime.isBefore(_startTime)) {
           _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = newDateTime;
        if (_endTime.isBefore(_startTime)) {
          _startTime = _endTime.subtract(const Duration(hours: 1));
        }
      }
    });
  }
  
  String _getRepeatLabel(String value) {
    final l10n = AppLocalizations.of(context)!;
    switch (value) {
      case 'daily': return l10n.eventDetailRepeatDaily;
      case 'weekly': return l10n.eventDetailRepeatWeekly;
      case 'monthly': return l10n.eventDetailRepeatMonthly;
      case 'none':
      default: return l10n.eventDetailRepeatNone;
    }
  }

  void _showRepeatPickerLegacy() {
    // 舊的 Picker 函式，保留名稱但不使用
    final l10n = AppLocalizations.of(context)!;
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: _repeatOptions.map((opt) => CupertinoActionSheetAction(
          onPressed: () {
            setState(() {
              _repeat = opt;
              if (opt == 'none') _recurrenceEndDate = null;
            });
            Navigator.pop(context);
          },
          child: Text(_getRepeatLabel(opt)),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
      ),
    );
  }

  void _showGroupPicker() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.eventDetailSelectGroup, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(l10n.commonCancel, style: const TextStyle(color: Colors.grey)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerColor, height: 1),
            ..._groups.map((g) => ListTile(
              leading: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(color: _hexToColor(g['color']), shape: BoxShape.circle),
              ),
              title: Text(
                g['name'] == '個人' ? l10n.commonPersonalMe : g['name'],
                style: TextStyle(color: colorScheme.onSurface),
              ),
              trailing: _selectedGroupId == g['id'] ? Icon(Icons.check, color: colorScheme.primary) : null,
              onTap: () {
                setState(() {
                  _selectedGroupId = g['id'];
                  _selectedEventColor = null;
                  _availableEventColors = [];
                });
                _loadGroupColors(g['id']);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEventColorPicker() {
    final l10n = AppLocalizations.of(context)!;
    final groupDefaultColor = _findGroupDefaultColor(_selectedGroupId);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 500,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.eventDetailSelectColor, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(l10n.commonCancel, style: const TextStyle(color: Colors.grey)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerColor, height: 1),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(color: _hexToColor(groupDefaultColor), shape: BoxShape.circle),
                    ),
                    title: Text(l10n.eventDetailGroupDefault, style: TextStyle(color: colorScheme.onSurface)),
                    trailing: _selectedEventColor == null ? Icon(Icons.check, color: colorScheme.primary) : null,
                    onTap: () {
                      setState(() => _selectedEventColor = null);
                      Navigator.pop(context);
                    },
                  ),
                  Divider(color: theme.dividerColor, height: 1, indent: 16, endIndent: 16),

                  ..._availableEventColors.map((c) {
                    final colorHex = c['color'];
                    final colorName = c['name'];
                    final isSelected = _selectedEventColor == colorHex;

                    return ListTile(
                      leading: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(color: _hexToColor(colorHex), shape: BoxShape.circle),
                      ),
                      title: Text(colorName, style: TextStyle(color: colorScheme.onSurface)),
                      trailing: isSelected ? Icon(Icons.check, color: colorScheme.primary) : null,
                      onTap: () {
                        setState(() => _selectedEventColor = colorHex);
                        Navigator.pop(context);
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

  void _showUserPicker() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: 500,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.eventDetailSelectPeople, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Text(l10n.commonDone, style: TextStyle(color: colorScheme.primary)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(color: theme.dividerColor, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _shopUsers.length,
                  itemBuilder: (context, index) {
                    final u = _shopUsers[index];
                    final uid = u['user_id'] as String;
                    final isSelected = _selectedUserIds.contains(uid);
                    return ListTile(
                      title: Text(u['name'], style: TextStyle(color: colorScheme.onSurface)),
                      trailing: isSelected ? Icon(Icons.check, color: colorScheme.primary) : null,
                      onTap: () {
                        setSheetState(() {
                          if (isSelected) {
                            _selectedUserIds.remove(uid);
                          } else {
                            _selectedUserIds.add(uid);
                          }
                        });
                        setState(() {}); 
                      },
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

  String _formatDisplayDate(DateTime dt, {required bool isStart}) {
    final l10n = AppLocalizations.of(context)!;
    final localeName = l10n.localeName;
    
    if (!_allDay) {
      return DateFormat('MMM d, HH:mm', localeName).format(dt);
    }

    final dateStr = DateFormat.yMMMd(localeName).format(dt);
    
    final bool isSameDay = _startTime.year == _endTime.year &&
        _startTime.month == _endTime.month &&
        _startTime.day == _endTime.day;

    if (isSameDay && isStart) {
      return '$dateStr (${l10n.eventDetailLabelAllDay})';
    }

    return dateStr;
  }

  String _getGroupName(String? id) {
    final l10n = AppLocalizations.of(context)!;
    if (id == null) return l10n.commonSelect;
    final g = _groups.firstWhere((g) => g['id'] == id, orElse: () => {});
    if (g.isEmpty) return l10n.commonUnknown;
    return g['name'] == '個人' ? l10n.commonPersonalMe : g['name'];
  }

  String _findGroupDefaultColor(String? groupId) {
    final group = _groups.firstWhere((g) => g['id'] == groupId, orElse: () => {});
    return group['color'] ?? '#0A84FF';
  }

  String _getColorNameOrHex(String? hex) {
    final l10n = AppLocalizations.of(context)!;
    if (hex == null) return l10n.eventDetailGroupDefault;
    final found = _availableEventColors.firstWhere((c) => c['color'] == hex, orElse: () => {});
    if (found.isNotEmpty) return found['name'];
    return l10n.eventDetailCustomColor;
  }

  Color _hexToColor(String? hex) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (hex == null) return colorScheme.primary;
    String cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return colorScheme.primary;
    }
  }

  void _showError(String msg) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: colorScheme.error));
  }
}