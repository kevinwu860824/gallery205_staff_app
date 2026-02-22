// lib/features/schedule/presentation/schedule_upload_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // [新增] 用於日期格式化
import 'package:gallery205_staff_app/l10n/app_localizations.dart'; // [新增] 引入多語言

// -------------------------------------------------------------------
// 1. 樣式與模型定義
// -------------------------------------------------------------------

// 員工數據模型
class Employee {
  final String userId;
  final String name;
  final String role;
  Employee({required this.userId, required this.name, required this.role});
}

// 班型數據模型
class Shift {
  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final Color color; // 用於日曆和標籤的顏色

  Shift({
    required this.id, 
    required this.name, 
    required this.startTime, 
    required this.endTime, 
    required this.color,
  });
}

// -------------------------------------------------------------------
// 2. ScheduleUploadScreen (排班主控台)
// -------------------------------------------------------------------

class ScheduleUploadScreen extends StatefulWidget {
  const ScheduleUploadScreen({super.key});

  @override
  State<ScheduleUploadScreen> createState() => _ScheduleUploadScreenState();
}

class _ScheduleUploadScreenState extends State<ScheduleUploadScreen> {
  // --- 狀態變量 ---
  bool _isLoading = true;
  bool _isSaving = false;
  String? _shopId;
  String? _loggedInUserId;

  // 員工管理
  List<Employee> _allEmployees = [];
  Employee? _currentEmployee; // 當前正在排班的員工

  // 班型管理
  List<Shift> _allShifts = [];
  Shift? _selectedShift; // 當前選中的 "畫筆"
  bool _isShiftListExpanded = false;

  // 日曆與數據管理
  DateTime _focusedDay = DateTime.now();
  
  // 1. 數據庫原始數據 (該員工已儲存的班表)
  Map<DateTime, Shift> _databaseEvents = {};

  // 2. 本地暫存變更 (使用者在UI上點擊的內容)
  Map<DateTime, Shift?> _pendingChanges = {};
  
  // 3. 是否有未儲存變更
  bool get _isDirty => _pendingChanges.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // ✅ 顏色轉換輔助函式
  Color _hexToColor(String hex) {
    String cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.green;
    }
  }

  // -------------------------------------------------------------------
  // 3. 核心數據載入邏輯
  // -------------------------------------------------------------------

  Future<void> _fetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    _loggedInUserId = Supabase.instance.client.auth.currentUser?.id;

    if (_shopId == null || _loggedInUserId == null) {
      if (mounted) context.go('/');
      return;
    }

    try {
      final client = Supabase.instance.client;
      final shopId = _shopId!;

      // 1. 獲取所有員工
      final usersRes = await client
          .from('users')
          .select('user_id, name, role')
          .eq('shop_id', shopId)
          .order('name', ascending: true);
      
      _allEmployees = usersRes.map((json) => Employee(
        userId: json['user_id'] as String,
        name: json['name'] as String? ?? 'No Name',
        role: json['role'] as String? ?? 'staff',
      )).toList();

      // 2. 獲取所有班型 (✅ 修改：加入 color 欄位)
      final shiftsRes = await client
          .from('shop_shift_settings')
          .select('id, shift_name, start_time, end_time, color')
          .eq('shop_id', shopId)
          .eq('is_enabled', true)
          .order('start_time', ascending: true);

      // ✅ 修改：使用 DB 中的顏色
      _allShifts = List.generate(shiftsRes.length, (index) {
        final json = shiftsRes[index];
        final colorHex = json['color'] as String? ?? '#34C759'; // 預設綠色
        
        return Shift(
          id: json['id'] as String,
          name: json['shift_name'] as String,
          startTime: json['start_time'] as String,
          endTime: json['end_time'] as String,
          color: _hexToColor(colorHex), // 轉換顏色
        );
      });
      
      // 3. 設定預設員工
      _currentEmployee = _allEmployees.firstWhere(
        (e) => e.userId == _loggedInUserId,
        orElse: () => _allEmployees.first,
      );

      // 4. 載入預設員工的班表
      await _loadScheduleForCurrentEmployee();

    } catch (e) {
      if (mounted) {
         final l10n = AppLocalizations.of(context)!;
        _showSnackBar(l10n.scheduleUploadLoadError(e.toString()), isError: true); // 'Failed to load initial data: ...'
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // 載入當前選中員工的班表
  Future<void> _loadScheduleForCurrentEmployee() async {
    if (_currentEmployee == null || _shopId == null) return;
    
    setState(() {
      _pendingChanges.clear();
      _databaseEvents.clear();
    });

    try {
      final res = await Supabase.instance.client
        .from('schedule_assignments')
        .select('shift_date, shift_type_id')
        .eq('employee_id', _currentEmployee!.userId)
        .eq('shop_id', _shopId!);
        
      final Map<DateTime, Shift> loadedEvents = {};
      for (final item in res) {
        final date = DateTime.parse(item['shift_date'] as String);
        final dateOnly = DateTime(date.year, date.month, date.day);
        
        final shift = _allShifts.firstWhere(
          (s) => s.id == item['shift_type_id'],
          orElse: () => Shift(id: 'unknown', name: 'Unknown', startTime: '', endTime: '', color: Colors.grey),
        );
        loadedEvents[dateOnly] = shift;
      }
      
      setState(() {
        _databaseEvents = loadedEvents;
        _focusedDay = DateTime.now(); 
      });
      
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showSnackBar(l10n.scheduleUploadLoadScheduleError(_currentEmployee!.name), isError: true); // 'Failed to load schedule for ...'
      }
    }
  }

  // -------------------------------------------------------------------
  // 4. 核心互動邏輯
  // -------------------------------------------------------------------

  // 日曆點擊
  void _onDaySelected(DateTime day, DateTime focusedDay) {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedShift == null) {
      _showSnackBar(l10n.scheduleUploadSelectShiftFirst, isError: true); // 'Please select a shift type from above first.'
      return;
    }
    
    final dateOnly = DateTime(day.year, day.month, day.day);
    final currentShiftOnDay = _getShiftForDay(dateOnly);
    
    setState(() {
      if (currentShiftOnDay == _selectedShift) {
        _pendingChanges[dateOnly] = null;
      } else {
        _pendingChanges[dateOnly] = _selectedShift;
      }
    });
  }

  // 處理員工切換
  Future<void> _onEmployeeChange(Employee newEmployee) async {
    Navigator.pop(context); // 關閉 Modal

    if (newEmployee.userId == _currentEmployee?.userId) return;

    if (_isDirty) {
      final bool? wantsToLeave = await _showDirtyWarningDialog();
      if (wantsToLeave == null || !wantsToLeave) {
        return; 
      }
    }
    
    setState(() {
      _currentEmployee = newEmployee;
      _isLoading = true; 
    });
    
    await _loadScheduleForCurrentEmployee();
    
    setState(() {
      _isLoading = false;
    });
  }

  // 儲存變更
  Future<void> _handleSave() async {
    final l10n = AppLocalizations.of(context)!;
    if (_pendingChanges.isEmpty) {
      _showSnackBar(l10n.scheduleUploadNoChanges, isError: false); // 'No changes to save.'
      return;
    }

    setState(() => _isSaving = true);
    
    final List<Map<String, dynamic>> upsertList = [];
    final List<String> deleteDatesList = [];

    _pendingChanges.forEach((date, shift) {
      if (shift != null) {
        upsertList.add({
          'shop_id': _shopId!,
          'employee_id': _currentEmployee!.userId,
          'shift_date': _formatDate(date),
          'shift_type_id': shift.id,
        });
      } else {
        if (_databaseEvents.containsKey(date)) {
          deleteDatesList.add(_formatDate(date));
        }
      }
    });

    try {
      final client = Supabase.instance.client;
      
      if (upsertList.isNotEmpty) {
        await client
          .from('schedule_assignments')
          .upsert(upsertList, onConflict: 'employee_id, shift_date');
      }
      
      if (deleteDatesList.isNotEmpty) {
        await client
          .from('schedule_assignments')
          .delete()
          .eq('employee_id', _currentEmployee!.userId)
          .filter('shift_date', 'in', deleteDatesList); 
      }

      _showSnackBar(l10n.scheduleUploadSaveSuccess, isError: false); // 'Schedule saved!'
      
      await _loadScheduleForCurrentEmployee();

    } catch (e) {
      _showSnackBar(l10n.scheduleUploadSaveError(e.toString()), isError: true); // 'Save failed: ...'
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // -------------------------------------------------------------------
  // 5. 防遺失彈窗 & 導航
  // -------------------------------------------------------------------

  Future<bool> _onWillPop() async {
    if (!_isDirty) {
      return true; 
    }
    
    final bool? wantsToLeave = await _showDirtyWarningDialog();
    
    return wantsToLeave ?? false; 
  }
  
  Future<bool?> _showDirtyWarningDialog() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor, // Explicitly use theme
        title: Text(l10n.scheduleUploadUnsavedChanges, style: theme.dialogTheme.titleTextStyle),
        content: Text(l10n.scheduleUploadDiscardChangesMessage, style: theme.dialogTheme.contentTextStyle),
        actions: [
          TextButton(
            child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text(l10n.commonConfirm, style: TextStyle(color: colorScheme.error)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // 6. UI Builder 輔助函式
  // -------------------------------------------------------------------

  void _showEmployeeModal() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isDirty) {
      final bool? wantsToLeave = await _showDirtyWarningDialog();
      if (wantsToLeave == null || !wantsToLeave) {
        return;
      }
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.scheduleUploadSelectEmployee, // 'Select Employee'
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _allEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = _allEmployees[index];
                    return _buildEmployeeTile(
                      employee,
                      showDivider: index < _allEmployees.length - 1, 
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmployeeTile(Employee employee, {bool showDivider = true}) {
    final l10n = AppLocalizations.of(context)!;
    final Color roleColor = _getRoleColor(employee.role);
    const double paddingHorizontal = 16.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        CupertinoListTile(
          padding: const EdgeInsets.symmetric(horizontal: paddingHorizontal, vertical: 14.0),
          leading: Container(
            width: 29, 
            height: 29, 
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.2), 
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(CupertinoIcons.person_fill, color: roleColor, size: 18),
          ),
          title: Text(employee.name, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
          // [修改] 使用翻譯字串
          subtitle: Text(l10n.scheduleUploadRole(employee.role.toUpperCase()), style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)), 
          onTap: () => _onEmployeeChange(employee), 
        ),
        if (showDivider)
          Divider(
            height: 1.0, 
            thickness: 1.2, 
            color: theme.dividerColor,
            indent: 61.0, 
            endIndent: paddingHorizontal,
          ),
      ],
    );
  }

  Shift? _getShiftForDay(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    
    if (_pendingChanges.containsKey(dateOnly)) {
      return _pendingChanges[dateOnly]; 
    }
    
    if (_databaseEvents.containsKey(dateOnly)) {
      return _databaseEvents[dateOnly];
    }
    
    return null;
  }

  // -------------------------------------------------------------------
  // 7. UI 主體 Build
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // [新增]
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) async {
        if (didPop) return; 
        final bool canPop = await _onWillPop();
        if (canPop && mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: CupertinoNavigationBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          middle: Text(l10n.scheduleUploadTitle, style: TextStyle(color: colorScheme.onSurface)), // 'Shift Assigning'
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
            onPressed: () async {
              final bool canPop = await _onWillPop();
              if (canPop && mounted) {
                context.pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopSelectors(),
              _buildShiftSelector(),
              Expanded(
                child: _isLoading
                    ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
                    : _buildCalendar(),
              ),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // UI 組件 1: 頂部選擇器
  Widget _buildTopSelectors() {
    final l10n = AppLocalizations.of(context)!;
    // 使用 locale 來格式化年月顯示
    final dateString = DateFormat.yMMMM(l10n.localeName).format(_focusedDay); 
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showEmployeeModal,
            child: Row(
              children: [
                Text(
                  _currentEmployee?.name ?? l10n.scheduleUploadSelectEmployee, // 'Select Employee'
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Icon(CupertinoIcons.chevron_down, color: colorScheme.onSurfaceVariant, size: 16),
              ],
            ),
          ),
          
          Text(
            dateString, // Localized date
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // UI 組件 2: 班型選擇器 (可展開)
  Widget _buildShiftSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _isShiftListExpanded ? double.infinity : 50.0,
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(), // 收起時不應滾動
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), 
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _allShifts.map((shift) {
                    final isSelected = _selectedShift?.id == shift.id;

                    return Container(
                      decoration: BoxDecoration(
                        // 根據 isSelected 顯示白色邊框
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minSize: 0,
                        // ✅ 使用 DB 中的顏色
                        color: shift.color, 
                        borderRadius: BorderRadius.circular(8.0),
                        onPressed: () {
                          setState(() {
                            _selectedShift = shift;
                          });
                        },
                        child: Text(
                          shift.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        
        if (_allShifts.length > 5) 
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                _isShiftListExpanded = !_isShiftListExpanded;
              });
            },
            child: Icon(
              _isShiftListExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        
        Divider(color: theme.dividerColor, height: 1),
      ],
    );
  }

  // UI 組件 3: 日曆
  Widget _buildCalendar() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TableCalendar(
      
      focusedDay: _focusedDay,
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
      
      // [新增] 設定 locale
      locale: l10n.localeName,
      
      // [Modified] Add explicit height to prevent clipping of "Mon/Tue"
      daysOfWeekHeight: 40.0,
      
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: const TextStyle(color: Colors.transparent), 
        leftChevronVisible: true, 
        rightChevronVisible: true,
        leftChevronIcon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
        rightChevronIcon: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        // [Modified] Use White/High Contrast for Sage Theme (Light Green Bg)
        weekdayStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
        weekendStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold), 
      ),
      
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final shift = _getShiftForDay(day);
          return _buildCalendarCell(day, shift?.color);
        },
        todayBuilder: (context, day, focusedDay) {
          final shift = _getShiftForDay(day);
          return _buildCalendarCell(
            day, 
            shift?.color, 
            isToday: true,
          );
        },
        outsideBuilder: (context, day, focusedDay) {
          return _buildCalendarCell(
            day, 
            null, 
            isOutside: true,
          );
        },
      ),
      
      onDaySelected: _onDaySelected,
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },
    );
  }

  // 自訂日曆格子
  Widget _buildCalendarCell(DateTime date, Color? shiftColor, {bool isToday = false, bool isOutside = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine text color based on background
    Color textColor = colorScheme.onSurface;

    if (shiftColor != null) {
      // If has shift (Green/Blue/etc), use White text
      textColor = Colors.white; 
    } else {
      // No shift. Check for weekend colors
      if (!isOutside) {
        if (date.weekday == DateTime.saturday) textColor = const Color(0xFF0044CC); // Darker Blue
        if (date.weekday == DateTime.sunday) textColor = const Color(0xFFCC0000); // Darker Red
      }
      
      if (isOutside) textColor = colorScheme.onSurface.withOpacity(0.5);
    }
    
    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: shiftColor ?? Colors.transparent, 
        borderRadius: BorderRadius.circular(8.0),
        border: isToday 
            ? Border.all(color: Colors.white, width: 2.5) // [Modified] Explicit White Border 
            : null,
      ),
      child: Center(
        child: Text(
          date.day.toString(),
          style: TextStyle(
            color: textColor,
            fontWeight: (shiftColor != null || isToday) ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // UI 組件 4: 儲存按鈕
  Widget _buildSaveButton() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine button color
    // ✅ [Modified] Match Monthly Cost Button Design (Theme Primary)
    final buttonBackground = colorScheme.primary; 
    final buttonText = colorScheme.onPrimary;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Center(
        child: SizedBox(
          width: 109.6, // Exact width from Monthly Cost _DialogWhiteButton
          height: 38,   // Exact height from Monthly Cost _DialogWhiteButton
          child: ElevatedButton(
            onPressed: (_isDirty && !_isSaving) ? _handleSave : null,
            style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary, // #FAFCFA
            foregroundColor: colorScheme.onPrimary, // #2D3A34
            elevation: 0, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
            padding: EdgeInsets.zero,
          ),
          child: _isSaving
              ? CupertinoActivityIndicator(color: colorScheme.onPrimary) 
              : Text(
                  l10n.commonSaveChanges, // 'Save Changes'
                  style: TextStyle(
                    color: colorScheme.onPrimary, 
                    fontSize: 16,
                    fontWeight: FontWeight.w500, // w500
                  ),
                ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 8. 輔助函式
  // -------------------------------------------------------------------

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return const Color(0xFFFF453A); // Red
      case 'manager': return const Color(0xFFFF9500); // Orange
      case 'editor': return const Color(0xFFAF52DE); // Purple
      case '早班': return const Color(0xFF34C759);
      case '晚班': return const Color(0xFF0A84FF);
      case '大夜': return const Color(0xFF5E5CE6);
      default: return Colors.green;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? theme.colorScheme.error : theme.colorScheme.primary,
      ),
    );
  }
}