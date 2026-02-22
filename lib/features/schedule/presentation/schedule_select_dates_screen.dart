// lib/features/schedule/presentation/schedule_select_dates_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 引入所需的模型 (Employee 來自 Step 1)
import 'schedule_upload_screen.dart'; 

class Shift {
  final String id;
  final String name;
  final String startTime;
  final String endTime;

  Shift({required this.id, required this.name, required this.startTime, required this.endTime});
  
  // 用於顯示在 Picker 中
  @override
  String toString() => '$name (${startTime} - ${endTime})';
}

class ScheduleSelectDatesScreen extends StatefulWidget {
  // 僅接收 Employee
  final dynamic employee; 

  const ScheduleSelectDatesScreen({
    super.key, 
    required this.employee, 
  });

  @override
  State<ScheduleSelectDatesScreen> createState() => _ScheduleSelectDatesScreenState();
}

class _ScheduleSelectDatesScreenState extends State<ScheduleSelectDatesScreen> {
  late final Employee emp;
  String? _shopId;
  bool _isLoading = true;

  // 班型選擇狀態
  List<Shift> _shiftTypes = [];
  Shift? _selectedShift;

  // 日曆排班狀態
  DateTime _focusedDay = DateTime.now();
  Set<DateTime> _selectedDays = {};
  bool _isSaving = false;
  
  // 數據預覽：該員工已排班的日期集合
  Set<DateTime> _employeeAssignedDates = {}; 

  @override
  void initState() {
    super.initState();
    emp = widget.employee as Employee;
    _fetchInitialData();
  }

  // 獲取班型列表和該員工已排班日期 (數據預覽)
  Future<void> _fetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    
    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    try {
      final client = Supabase.instance.client;
      final shopId = _shopId!;

      // 1. 獲取所有可用的班型 (Step 2 邏輯)
      final shiftRes = await client
          .from('shop_shift_settings')
          .select('id, shift_name, start_time, end_time')
          .eq('shop_id', shopId)
          .eq('is_enabled', true)
          .order('start_time', ascending: true);
      
      _shiftTypes = shiftRes.map((json) => Shift(
        id: json['id'] as String,
        name: json['shift_name'] as String,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
      )).toList();
      
      // 預設選中第一個班型
      _selectedShift = _shiftTypes.isNotEmpty ? _shiftTypes.first : null;
      
      // 2. 獲取該員工已排班的日期 (數據預覽邏輯)
      final assignedRes = await client
          .from('schedule_assignments')
          .select('shift_date')
          .eq('employee_id', emp.userId)
          .eq('shop_id', shopId); 

      _employeeAssignedDates = assignedRes.map((json) {
        // 將 Supabase DATE 字串轉換為 DateTime 對象 (且只取日期部分)
        final date = DateTime.parse(json['shift_date'] as String);
        return DateTime(date.year, date.month, date.day);
      }).toSet();
      
    } catch (e) {
      _showSnackBar('數據載入失敗: ${e.toString()}', isError: true);
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  // 檢查某個日期是否已被排班 (用於日曆標記)
  bool _isAssigned(DateTime day) {
    // 確保只比較日期部分
    final dateOnly = DateTime(day.year, day.month, day.day);
    return _employeeAssignedDates.contains(dateOnly);
  }

  // 處理日期選擇邏輯
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // 檢查是否是過去的日期 (只允許選今天及未來)
    if (selectedDay.isBefore(DateTime.now().subtract(const Duration(days: 1))) && !isSameDay(selectedDay, DateTime.now())) {
      _showSnackBar('不能選擇過去的日期。', isError: true);
      return;
    }

    setState(() {
      _focusedDay = focusedDay;
      final dateOnly = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

      if (_selectedDays.contains(dateOnly)) {
        _selectedDays.remove(dateOnly);
      } else {
        _selectedDays.add(dateOnly);
      }
    });
  }
  
  // 格式化日期為 Supabase Date 類型 (YYYY-MM-DD)
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 執行批量儲存
  Future<void> _bulkSaveAssignments() async {
    if (_selectedShift == null) {
      _showSnackBar('請先選擇一個班型。', isError: true);
      return;
    }
    if (_selectedDays.isEmpty || _shopId == null) {
      _showSnackBar('請至少選擇一個日期。', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final List<Map<String, dynamic>> assignments = _selectedDays.map((date) {
        return {
          'shop_id': _shopId!,
          'employee_id': emp.userId,
          'shift_date': _formatDate(date), 
          'shift_type_id': _selectedShift!.id, // 使用選中的班型 ID
        };
      }).toList();

      await Supabase.instance.client
          .from('schedule_assignments')
          .upsert(
            assignments, 
            onConflict: 'employee_id, shift_date'
          );

      _showSnackBar('✅ 成功為 ${emp.name} 批量安排 ${assignments.length} 個班次！');
      
      // 成功後清除已選，並更新日曆預覽 (將新增的日期加入 _employeeAssignedDates)
      setState(() {
        _employeeAssignedDates.addAll(_selectedDays);
        _selectedDays.clear();
      });

    } on PostgrestException catch (e) {
      _showSnackBar('❌ 排班失敗: ${e.message}', isError: true);
    } catch (e) {
      _showSnackBar('❌ 發生未知錯誤: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  // -------------------------------------------------------------------
  // UI 構建
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
      );
    }

    final bool isButtonDisabled = _selectedDays.isEmpty || _isSaving || _selectedShift == null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        middle: Text('Assign Shift & Dates', style: TextStyle(color: colorScheme.onSurface)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 頂部資訊卡片 (包含班型選擇)
            _buildInfoCard(),
            
            // 日曆區塊
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TableCalendar(
                  focusedDay: _focusedDay,
                  firstDay: DateTime.now(), 
                  lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
                  
                  // ... (其他日曆配置保持不變) ...
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  
                  selectedDayPredicate: (day) => _selectedDays.any((selectedDay) => isSameDay(selectedDay, day)),
                  onDaySelected: _onDaySelected,
                  
                  // ⭐️ 數據預覽：標記已排班日期
                  // 使用 eventLoader 來標記已排班日期
                  eventLoader: (day) {
                    return _isAssigned(day) ? [true] : []; // 返回一個非空列表即可
                  },
                  
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18),
                    leftChevronIcon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
                    rightChevronIcon: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface),
                  ),
                  calendarStyle: CalendarStyle(
                    // 文字顏色
                    defaultTextStyle: TextStyle(color: colorScheme.onSurface),
                    weekendTextStyle: TextStyle(color: colorScheme.onSurface),
                    outsideTextStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                    todayTextStyle: TextStyle(color: colorScheme.onSurface),
                    selectedTextStyle: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold),
                    
                    // ⭐️ 數據預覽樣式：已排班日期的標記點
                    markerDecoration: BoxDecoration(
                      color: colorScheme.error, // 已排班的點標記為紅色
                      shape: BoxShape.circle,
                    ),
                    
                    // 今天/選中標記
                    todayDecoration: BoxDecoration(
                      color: colorScheme.outline.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    weekendStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            
            // 儲存按鈕
            _buildSaveButton(isButtonDisabled),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '安排給：${emp.name} (${emp.role.toUpperCase()})',
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            // ⭐️ 班型選擇下拉式選單
            _buildShiftPicker(),
            
            const SizedBox(height: 10),
            Text(
              '已選日期：${_selectedDays.length} 天',
              style: TextStyle(
                color: _selectedDays.isEmpty ? colorScheme.outline : colorScheme.primary, 
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftPicker() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '選擇班型:',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 5),
        // 使用 Cupertino Button/ActionSheet 來模擬下拉式選單
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: theme.cardColor.withOpacity(0.5), // Not exactly matching but close, or use input decoration color
          minSize: 0,
          onPressed: () => _showShiftPickerSheet(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedShift?.toString() ?? '請選擇班型',
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(CupertinoIcons.chevron_down, color: colorScheme.onSurfaceVariant, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  void _showShiftPickerSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_shiftTypes.isEmpty) {
      _showSnackBar('無可選班型，請先在設定中新增。', isError: true);
      return;
    }
    
    // 預設選中當前班型的索引
    int initialIndex = _selectedShift != null ? _shiftTypes.indexOf(_selectedShift!) : 0;
    if (initialIndex < 0) initialIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              // 完成按鈕
              Container(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('完成', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                ),
              ),
              // Picker
              Expanded(
                child: CupertinoPicker(
                  magnification: 1.22,
                  squeeze: 1.2,
                  useMagnifier: true,
                  itemExtent: 32.0,
                  scrollController: FixedExtentScrollController(initialItem: initialIndex),
                  onSelectedItemChanged: (int selectedItem) {
                    setState(() {
                      _selectedShift = _shiftTypes[selectedItem];
                    });
                  },
                  children: List<Widget>.generate(_shiftTypes.length, (int index) {
                    return Center(
                      child: Text(
                        _shiftTypes[index].toString(),
                        style: TextStyle(
                          color: colorScheme.onSurface, 
                          fontSize: 18,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSaveButton(bool isDisabled) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: CupertinoButton.filled(
        onPressed: isDisabled ? null : _bulkSaveAssignments,
        minSize: 50,
        disabledColor: colorScheme.primary.withOpacity(0.5),
        child: _isSaving
            ? CupertinoActivityIndicator(color: theme.scaffoldBackgroundColor)
            : Text(
                '確認批量排班 (${_selectedDays.length} 天)',
                style: TextStyle(color: theme.scaffoldBackgroundColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}