// lib/features/schedule/presentation/schedule_select_shift_type_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'schedule_upload_screen.dart'; // 引入 Employee 模型

// -------------------------------------------------------------------
// 2. Shift Model
// -------------------------------------------------------------------
class Shift {
  final String id;
  final String name;
  final String startTime;
  final String endTime;

  Shift({required this.id, required this.name, required this.startTime, required this.endTime});
}

// -------------------------------------------------------------------
// 3. ScheduleSelectShiftTypeScreen
// -------------------------------------------------------------------

class ScheduleSelectShiftTypeScreen extends StatefulWidget {
  final dynamic employee;

  const ScheduleSelectShiftTypeScreen({super.key, required this.employee});

  @override
  State<ScheduleSelectShiftTypeScreen> createState() => _ScheduleSelectShiftTypeScreenState();
}

class _ScheduleSelectShiftTypeScreenState extends State<ScheduleSelectShiftTypeScreen> {
  String? _shopId;
  bool _isLoading = true;
  List<Shift> _shiftTypes = [];
  late Employee _selectedEmployee;

  @override
  void initState() {
    super.initState();
    _selectedEmployee = widget.employee as Employee;
    _fetchShiftTypes();
  }

  Future<void> _fetchShiftTypes() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');

    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('shop_shift_settings')
          .select('id, shift_name, start_time, end_time')
          .eq('shop_id', _shopId!)
          .eq('is_enabled', true)
          .order('start_time', ascending: true);

      _shiftTypes = res.map((json) => Shift(
        id: json['id'] as String,
        name: json['shift_name'] as String,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
      )).toList();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load shift types: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _selectShiftType(Shift shift) {
    context.push('/scheduleSelectDates', extra: {
      'employee': _selectedEmployee,
      'shift': shift,
    });
  }
  
  // ✅ 新增：自訂列表項（仿設定頁面風格）
  Widget _buildShiftTypeTile(Shift shift, {bool showDivider = true}) {
    // 這裡我們使用 accentGreen 作為班型圖標顏色
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color shiftColor = colorScheme.primary; 
    const double paddingHorizontal = 16.0;

    return Column(
      children: [
        CupertinoListTile(
          padding: const EdgeInsets.symmetric(horizontal: paddingHorizontal, vertical: 14.0),
          // 仿設定頁面樣式：帶背景的圓角 Icon
          leading: Container(
            width: 29, 
            height: 29, 
            decoration: BoxDecoration(
              // 背景色使用淡化綠色
              color: shiftColor.withOpacity(0.2), 
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              CupertinoIcons.clock_fill, // 使用時鐘圖標
              color: shiftColor,
              size: 18,
            ),
          ),
          title: Text(
            shift.name,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '${shift.startTime} - ${shift.endTime}',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          trailing: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurfaceVariant),
          onTap: () => _selectShiftType(shift),
        ),
        
        // **自訂分隔線**
        if (showDivider)
          Divider(
            height: 1.0, 
            thickness: 1.2, 
            color: theme.dividerColor,
            
            // 調整縮排以避開 Icon 和邊界 (與 Step 1 相同)
            indent: 61.0, 
            endIndent: paddingHorizontal,
          ),
      ],
    );
  }


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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        middle: Text(
          'Assign Shifts to ${_selectedEmployee.name} (Step 2/3)',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select Shift Type:',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),

            Expanded(
              child: Padding(
                // 應用卡片外邊距
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    // 應用卡片背景色
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    // 替換為 ListView.builder + 自訂 Tile
                    child: ListView.builder(
                      itemCount: _shiftTypes.length,
                      itemBuilder: (context, index) {
                        final shift = _shiftTypes[index];
                        return _buildShiftTypeTile(
                          shift,
                          // 最後一項不顯示分隔線
                          showDivider: index < _shiftTypes.length - 1,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // 移除原有的 SizedBox(height: 20)
          ],
        ),
      ),
    );
  }
}