// lib/features/schedule/presentation/recurrence_picker.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/core/models/recurrence_rule.dart';

class RecurrencePicker extends StatefulWidget {
  final DateTime initialStartDate;
  final RecurrenceRule? initialRule;
  final DateTime? initialEndDate;

  const RecurrencePicker({
    super.key,
    required this.initialStartDate,
    this.initialRule,
    this.initialEndDate,
  });

  @override
  State<RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<RecurrencePicker> {
  // 核心狀態
  late String _freq; // 'none', 'daily', 'weekly', 'monthly', 'yearly'
  late int _interval;
  late DateTime? _endDate;
  
  // Weekly 狀態
  late Set<int> _selectedWeekDays; // 1=Mon, 7=Sun

  // Monthly 狀態
  late String _monthlyType; // 'date', 'day'
  late int _byMonthDay; // 幾號
  late int _bySetPos; // 第幾個
  late int _byDay; // 星期幾

  // Yearly 狀態
  late int _byYearMonth;
  late int _byYearDay;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final r = widget.initialRule;
    final start = widget.initialStartDate;

    _freq = r?.freq ?? 'none'; // 預設為無 
    _interval = r?.interval ?? 1;
    _endDate = widget.initialEndDate;

    // Weekly 初始化
    if (r?.freq == 'weekly' && r?.byWeekDays != null) {
      _selectedWeekDays = r!.byWeekDays!.toSet();
    } else {
      _selectedWeekDays = {start.weekday}; 
    }

    // Monthly 初始化
    if (r?.freq == 'monthly') {
      _monthlyType = r!.monthlyType ?? 'date';
      _byMonthDay = r.byMonthDay ?? start.day;
      _bySetPos = r.bySetPos ?? _calculateNth(start);
      _byDay = r.byDay ?? start.weekday;
    } else {
      _monthlyType = 'date';
      _byMonthDay = start.day;
      _bySetPos = _calculateNth(start);
      _byDay = start.weekday;
    }

    _byYearMonth = start.month;
    _byYearDay = start.day;
  }

  int _calculateNth(DateTime date) {
    return ((date.day - 1) / 7).floor() + 1;
  }

  String _getWeekdayName(int weekday) {
    const days = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    return days[weekday - 1];
  }

  String _getNthName(int n) {
    if (n == 1) return '第一個';
    if (n == 2) return '第二個';
    if (n == 3) return '第三個';
    if (n == 4) return '第四個';
    if (n == 5) return '第五個'; 
    return '第 $n 個';
  }

  void _onConfirm() {
    RecurrenceRule? rule; // 允許為 null 代表不重複

    switch (_freq) {
      case 'none':
        rule = null;
        break;
      case 'daily':
        rule = RecurrenceRule(freq: 'daily', interval: _interval);
        break;
      case 'weekly':
        if (_selectedWeekDays.isEmpty) {
          _selectedWeekDays.add(widget.initialStartDate.weekday);
        }
        final sortedDays = _selectedWeekDays.toList()..sort();
        rule = RecurrenceRule(
          freq: 'weekly',
          interval: _interval,
          byWeekDays: sortedDays,
        );
        break;
      case 'monthly':
        if (_monthlyType == 'date') {
          rule = RecurrenceRule(
            freq: 'monthly',
            interval: _interval,
            monthlyType: 'date',
            byMonthDay: _byMonthDay,
          );
        } else {
          rule = RecurrenceRule(
            freq: 'monthly',
            interval: _interval,
            monthlyType: 'day',
            bySetPos: _bySetPos,
            byDay: _byDay,
          );
        }
        break;
      case 'yearly':
        rule = RecurrenceRule(
          freq: 'yearly',
          interval: _interval,
        );
        break;
      default:
        rule = null;
    }

    Navigator.pop(context, {
      'rule': rule,
      'endDate': _endDate,
    });
  }

  // 🔥 數字輸入框 (已改為系統 Theme)
  void _showIntervalInputDialog(ThemeData theme) {
    final controller = TextEditingController(text: _interval.toString());
    final isDark = theme.brightness == Brightness.dark;
    
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        // 使用 Theme 色彩
        title: Text('設定重複間隔', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            textAlign: TextAlign.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            child: const Text('確定'),
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                setState(() => _interval = val);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // 使用系統背景色 (Light/Dark)
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(CupertinoIcons.xmark, color: colorScheme.onSurfaceVariant),
                ),
                // 🔥 移除「永不停止」文字，僅顯示有截止日時的日期
                Text(
                  _endDate == null || _freq == 'none' ? '' : '截止於 ${DateFormat('yyyy/MM/dd').format(_endDate!)}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                GestureDetector(
                  onTap: _onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary, // 使用主題色
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('儲存', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // 2. Summary
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              _generateSummaryText(),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ),

          // 3. Tabs (加入 '無')
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.inputDecorationTheme.fillColor ?? theme.cardColor.withOpacity(0.5), // 使用輸入框背景或卡片色
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: ['不重複', '每天', '每週', '每月', '每年'].asMap().entries.map((entry) {
                final index = entry.key;
                final label = entry.value;
                final keys = ['none', 'daily', 'weekly', 'monthly', 'yearly'];
                final key = keys[index];
                
                final isSelected = _freq == key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _freq = key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primaryContainer : Colors.transparent, // 選中時使用 Primary Container
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12, // 稍微縮小字體以容納更多選項
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // 4. Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_freq == 'none') _buildNoneContent(theme),
                  if (_freq == 'weekly') _buildWeeklyContent(theme),
                  if (_freq == 'monthly') _buildMonthlyContent(theme),
                  if (_freq == 'yearly') _buildYearlyContent(theme),
                  if (_freq == 'daily') _buildDailyContent(theme),

                  const SizedBox(height: 32),

                  if (_freq != 'none') _buildEndDateSection(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoneContent(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text(
          '此事件將不會重複發生',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildDailyContent(ThemeData theme) {
    return _buildIntervalSelector('天', theme);
  }

  Widget _buildWeeklyContent(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final dayValue = index == 0 ? 7 : index; 
            final label = ['日', '一', '二', '三', '四', '五', '六'][index];
            final isSelected = _selectedWeekDays.contains(dayValue);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    if (_selectedWeekDays.length > 1) _selectedWeekDays.remove(dayValue);
                  } else {
                    _selectedWeekDays.add(dayValue);
                  }
                });
              },
              child: Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : theme.cardColor,
                  shape: BoxShape.circle,
                  border: isSelected ? null : Border.all(color: theme.dividerColor),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        _buildIntervalSelector('週', theme)
      ],
    );
  }

  Widget _buildMonthlyContent(ThemeData theme) {
    final dateText = '每個月的 $_byMonthDay 號重複';
    final dayText = '每個月的 ${_getNthName(_bySetPos)} ${_getWeekdayName(_byDay)} 重複';

    return Column(
      children: [
        _buildRadioOption(
          theme: theme,
          label: dateText,
          isSelected: _monthlyType == 'date',
          onTap: () => setState(() => _monthlyType = 'date'),
        ),
        const SizedBox(height: 12),
        _buildRadioOption(
          theme: theme,
          label: dayText,
          isSelected: _monthlyType == 'day',
          onTap: () => setState(() => _monthlyType = 'day'),
        ),
        const SizedBox(height: 24),
        _buildIntervalSelector('月', theme), 
      ],
    );
  }

  Widget _buildYearlyContent(ThemeData theme) {
    final dateStr = DateFormat('M月d日').format(widget.initialStartDate);
    return Column(
      children: [
        _buildRadioOption(
          theme: theme,
          label: '每年 $dateStr 重複',
          isSelected: true,
          onTap: () {},
        ),
        const SizedBox(height: 24),
        _buildIntervalSelector('年', theme),
      ],
    );
  }

  Widget _buildIntervalSelector(String unit, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    // 🔥 使用更顯眼的顏色 (Tertiary Container)
    final boxColor = colorScheme.tertiaryContainer; 
    final boxTextColor = colorScheme.onTertiaryContainer;

    return Row(
      children: [
        GestureDetector(
          onTap: () => _showIntervalInputDialog(theme),
          child: Container(
            width: 50, height: 50, // 稍微加大
            decoration: BoxDecoration(
              color: boxColor, 
              borderRadius: BorderRadius.circular(12),
              // 加個明顯外框
              border: Border.all(color: colorScheme.tertiary, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              '$_interval',
              style: TextStyle(color: boxTextColor, fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text('每隔 $_interval $unit 重複一次', style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
      ],
    );
  }

  Widget _buildRadioOption({required ThemeData theme, required String label, required bool isSelected, required VoidCallback onTap}) {
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: colorScheme.primary, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isSelected ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: colorScheme.onSurface, fontSize: 15))),
          ],
        ),
      ),
    );
  }

  Widget _buildEndDateSection(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('設定重複截止日期', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _endDate ?? widget.initialStartDate.add(const Duration(days: 365)),
              firstDate: widget.initialStartDate,
              lastDate: DateTime(2050),
              builder: (context, child) {
                // 使用系統 Theme
                return Theme(
                  data: theme.copyWith(
                    colorScheme: colorScheme, 
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _endDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _endDate == null ? '永不停止' : DateFormat('yyyy/MM/dd').format(_endDate!),
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
                if (_endDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _endDate = null),
                    child: Icon(Icons.close, color: colorScheme.onSurfaceVariant, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _generateSummaryText() {
    if (_freq == 'none') return '不重複';
    
    String intervalStr = _interval > 1 ? '每 $_interval ' : '每';
    
    if (_freq == 'daily') return '${intervalStr}天重複';
    if (_freq == 'weekly') {
      final dayNames = _selectedWeekDays.toList()..sort();
      final daysStr = dayNames.map((d) => _getWeekdayName(d)).join('、');
      return '${intervalStr}週於 $daysStr 重複';
    }
    if (_freq == 'monthly') {
      if (_monthlyType == 'date') return '${intervalStr}月的 $_byMonthDay 號重複';
      return '${intervalStr}月的 ${_getNthName(_bySetPos)} ${_getWeekdayName(_byDay)} 重複';
    }
    return '${intervalStr}年重複';
  }
}