// lib/features/settings/presentation/settings_shift_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 1. 資料模型 (ShiftType Model) - 新增 Color
// -------------------------------------------------------------------

class ShiftType {
  final String? id;
  String name;
  String startTime; // HH:mm 格式
  String endTime; // HH:mm 格式
  bool isEnabled;
  String color; // Hex Color String (e.g., "#FF0000")

  ShiftType({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.isEnabled = true,
    this.color = '#34C759', // 預設綠色
  });

  factory ShiftType.fromJson(Map<String, dynamic> json) {
    // 保持原始邏輯，不添加運行時容錯
    return ShiftType(
      id: json['id'] as String?,
      name: json['shift_name'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      isEnabled: json['is_enabled'] as bool? ?? true,
      color: json['color'] as String? ?? '#34C759', // 讀取顏色
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'shift_name': name,
      'start_time': startTime,
      'end_time': endTime,
      'is_enabled': isEnabled,
      'color': color, // 儲存顏色
    };

    if (id != null) {
      data['id'] = id;
    }
    return data;
  }
}

// 預設可選的顏色列表
const List<Color> _presetColors = [
  Color(0xFF2DCB86), // Green
  Color(0xFF3CC2C7), // Blue
  Color(0xFF48B2F7), // Red
  Color(0xFF947F78), // Orange
  Color(0xFFB8D6E2), // Purple
  Color(0xFFE73B3C), // Pink
  Color(0xFFF25F8B), // Light Blue
  Color(0xFFFA7E78), // Yellow
  Color(0xFFFEC02F), // Gray
  Color(0xFFB28ADC), // White
];

// Helper: Hex String 轉 Color
Color _hexToColor(String hex) {
  try {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  } catch (e) {
    return const Color(0xFF34C759);
  }
}

// Helper: Color 轉 Hex String
String _colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}

InputDecoration _buildInputDecoration({String hintText = '', required BuildContext context}) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
        color: Colors.grey,
        fontSize: 16,
        fontWeight: FontWeight.w500),
    filled: true,
    fillColor: theme.scaffoldBackgroundColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
  );
}

// -------------------------------------------------------------------
// 3. SettingsShiftScreen (主頁面)
// -------------------------------------------------------------------

class SettingsShiftScreen extends StatefulWidget {
  const SettingsShiftScreen({super.key});

  @override
  State<SettingsShiftScreen> createState() => _SettingsShiftScreenState();
}

class _SettingsShiftScreenState extends State<SettingsShiftScreen> {
  String? _shopId;
  bool _isLoading = true;
  bool _isSaving = false;
  List<ShiftType> _shiftTypes = [];
  Set<String> _deletedShiftIds = {};

  @override
  void initState() {
    super.initState();
    _fetchShiftSettings();
  }

  Future<void> _fetchShiftSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    _shopId = prefs.getString('savedShopId');
    if (_shopId == null) {
      context.go('/');
      return;
    }
    
    // Fallback theme colors if context not ready (unlikely here but safe)
    // Actually we are in async, so context.mounted check is needed.

    try {
      final res = await Supabase.instance.client
          .from('shop_shift_settings')
          .select('*')
          .eq('shop_id', _shopId!)
          .order('start_time', ascending: true); // 依開始時間排序

      setState(() {
        _shiftTypes =
            (res as List).map((json) => ShiftType.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shiftLoadError(e.toString())), 
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showNoticeDialog(String titleKey, String content) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!; 
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // 根據 Key 翻譯標題
    final translatedTitle = titleKey == 'Success' ? l10n.commonSuccess : l10n.commonError;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$translatedTitle: $content'),
        backgroundColor: titleKey == 'Success'
            ? colorScheme.primary
            : colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. 處理刪除
      if (_deletedShiftIds.isNotEmpty) {
        await Supabase.instance.client
            .from('shop_shift_settings')
            .delete()
            .inFilter('id', _deletedShiftIds.toList());
        _deletedShiftIds.clear();
      }

      // 2. 分類數據
      final List<Map<String, dynamic>> updates = [];
      final List<Map<String, dynamic>> inserts = [];

      for (final shift in _shiftTypes) {
        final Map<String, dynamic> data = {
          'shop_id': _shopId,
          'shift_name': shift.name,
          'start_time': shift.startTime,
          'end_time': shift.endTime,
          'is_enabled': shift.isEnabled,
          'color': shift.color, // 儲存顏色
        };

        if (shift.id != null && shift.id!.isNotEmpty) {
          data['id'] = shift.id;
          updates.add(data);
        } else {
          inserts.add(data);
        }
      }

      // 3. 執行 UPDATE
      if (updates.isNotEmpty) {
        await Supabase.instance.client
            .from('shop_shift_settings')
            .upsert(updates);
      }

      // 4. 執行 INSERT
      if (inserts.isNotEmpty) {
        await Supabase.instance.client
            .from('shop_shift_settings')
            .insert(inserts);
      }

      await _fetchShiftSettings();
      if(mounted) _showNoticeDialog('Success', AppLocalizations.of(context)!.shiftSaveSuccess);
    } catch (e) {
      if(mounted) _showNoticeDialog('Error', AppLocalizations.of(context)!.shiftSaveError(e.toString()));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showAddOrEditShiftDialog({ShiftType? shift}) async {
    final isEditing = shift != null;
    final nameController = TextEditingController(text: shift?.name ?? '');

    TimeOfDay startTime = shift != null
        ? TimeOfDay.fromDateTime(DateFormat('HH:mm').parse(shift.startTime))
        : const TimeOfDay(hour: 9, minute: 0);

    TimeOfDay endTime = shift != null
        ? TimeOfDay.fromDateTime(DateFormat('HH:mm').parse(shift.endTime))
        : const TimeOfDay(hour: 17, minute: 0);

    String color = shift?.color ?? '#34C759';

    final result = await showDialog<ShiftType?>(
      context: context,
      builder: (_) => _AddEditShiftDialog(
        isEditing: isEditing,
        nameController: nameController,
        initialStartTime: startTime,
        initialEndTime: endTime,
        initialColor: color,
      ),
    );

    if (result != null) {
      if (isEditing) {
        setState(() {
          shift!.name = result.name;
          shift.startTime = result.startTime;
          shift.endTime = result.endTime;
          shift.color = result.color; // 更新顏色
        });
      } else {
        final newShift = ShiftType(
          id: null,
          name: result.name,
          startTime: result.startTime,
          endTime: result.endTime,
          color: result.color, // 新增顏色
        );
        setState(() {
          _shiftTypes.add(newShift);
        });
      }
    }
  }

  void _deleteShift(ShiftType shift) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmationDialog(shiftName: shift.name),
    );

    if (shouldDelete == true) {
      if (shift.id != null && shift.id!.isNotEmpty) {
        _deletedShiftIds.add(shift.id!);
      }
      setState(() {
        _shiftTypes.remove(shift);
      });
      _showNoticeDialog(
          'Deleted', l10n.shiftDeleteLocalSuccess(shift.name)); // 翻譯刪除成功訊息
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
            child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        middle: Text(l10n.shiftSetupTitle, 
            style: TextStyle(color: colorScheme.onSurface)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.chevron_left,
              color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(l10n.shiftSetupSectionTitle, 
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  ..._shiftTypes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final shift = entry.value;
                    return Column(
                      children: [
                        _ShiftListTile(
                          shift: shift,
                          onToggle: (value) {
                            setState(() {
                              shift.isEnabled = value;
                            });
                          },
                          onEdit: () => _showAddOrEditShiftDialog(shift: shift),
                          onDelete: () => _deleteShift(shift),
                        ),
                        if (index < _shiftTypes.length - 1)
                          Divider(
                              color: theme.dividerColor,
                              height: 1,
                              indent: 56,
                              endIndent: 16),
                      ],
                    );
                  }).toList(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onPressed: () => _showAddOrEditShiftDialog(),
                    child: Text(
                      l10n.shiftSetupListAddButton, 
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: _WhiteButton(
                text: l10n.commonSave, 
                onPressed: _isSaving ? null : _saveSettings,
                backgroundColor: colorScheme.primary,
                textColor: colorScheme.onPrimary,
                child: _isSaving
                    ? CupertinoActivityIndicator(
                        color: colorScheme.onPrimary)
                    : null,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 4. 輔助 Widget
// -------------------------------------------------------------------

// --- 列表中的單個班型元件 ---
class _ShiftListTile extends StatelessWidget {
  final ShiftType shift;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShiftListTile({
    required this.shift,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color shiftColor = _hexToColor(shift.color);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
      child: Row(
        children: [
          // 左側圖示：從時鐘改為顏色圓點
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: shiftColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(shift.name,
                    style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                Text(
                    l10n.shiftListStartTime(shift.startTime, shift.endTime), 
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(CupertinoIcons.pencil,
                color: colorScheme.onSurface, size: 22),
            onPressed: onEdit,
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(CupertinoIcons.delete_simple,
                color: colorScheme.error, size: 22),
            onPressed: onDelete,
          ),
          CupertinoSwitch(
            value: shift.isEnabled,
            onChanged: onToggle,
            activeTrackColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// --- 新增/編輯班型 Dialog (包含顏色選擇) ---
class _AddEditShiftDialog extends StatefulWidget {
  final bool isEditing;
  final TextEditingController nameController;
  final TimeOfDay initialStartTime;
  final TimeOfDay initialEndTime;
  final String initialColor;

  const _AddEditShiftDialog({
    required this.isEditing,
    required this.nameController,
    required this.initialStartTime,
    required this.initialEndTime,
    required this.initialColor,
  });

  @override
  State<_AddEditShiftDialog> createState() => _AddEditShiftDialogState();
}

class _AddEditShiftDialogState extends State<_AddEditShiftDialog> {
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  late String selectedColorHex;

  @override
  void initState() {
    super.initState();
    startTime = widget.initialStartTime;
    endTime = widget.initialEndTime;
    selectedColorHex = widget.initialColor;
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  void _onSave() {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shiftDialogErrorNameEmpty)), 
      );
      return;
    }

    final String start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final String end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    final resultShift = ShiftType(
      id: null,
      name: name,
      startTime: start,
      endTime: end,
      color: selectedColorHex,
    );

    Navigator.of(context).pop(resultShift);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _CustomDialogBase(
      title: widget.isEditing ? l10n.shiftDialogEditTitle : l10n.shiftDialogAddTitle, 
      isScrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 54,
            child: TextFormField(
              controller: widget.nameController,
              decoration: _buildInputDecoration(hintText: l10n.shiftDialogHintName, context: context), 
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              textAlignVertical: TextAlignVertical.center,
            ),
          ),
          const SizedBox(height: 12),
          _TimeSelectButton(
            label: l10n.shiftDialogLabelStartTime, 
            time: startTime,
            onTap: () => _selectTime(context, true),
          ),
          const SizedBox(height: 12),
          _TimeSelectButton(
            label: l10n.shiftDialogLabelEndTime, 
            time: endTime,
            onTap: () => _selectTime(context, false),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.shiftDialogLabelColor, 
            style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          // 顏色選擇器
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((color) {
              final hex = _colorToHex(color);
              final isSelected = hex == selectedColorHex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedColorHex = hex;
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        _TextCancelButton(onPressed: () => Navigator.of(context).pop(), text: l10n.commonCancel), 
        _DialogWhiteButton(text: l10n.commonSave, onPressed: _onSave), 
      ],
    );
  }
}

// --- 時間選擇按鈕 (用於 Dialog) ---
class _TimeSelectButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeSelectButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // 對話框是 CardColor，按鈕背景用 Scanffold
        borderRadius: BorderRadius.circular(25),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              time.format(context),
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 5. 基礎 UI 輔助元件
// -------------------------------------------------------------------

class _CustomDialogBase extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool isScrollable;

  const _CustomDialogBase({
    required this.title,
    required this.content,
    required this.actions,
    this.isScrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const double dialogWidth = 361.0;
    final contentWidget =
        isScrollable ? Flexible(child: SingleChildScrollView(child: content)) : content;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: isScrollable ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            contentWidget,
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogWhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? child;
  const _DialogWhiteButton({required this.text, this.onPressed, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: 109.6,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary, // Save Button Primary
          foregroundColor: colorScheme.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: EdgeInsets.zero,
        ),
        child: child ??
            Text(
              text,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? child;
  final Color? backgroundColor;
  final Color? textColor;
  
  const _WhiteButton({required this.text, this.onPressed, this.child, this.backgroundColor, this.textColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: 161,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? theme.cardColor,
          foregroundColor: textColor ?? colorScheme.onSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: EdgeInsets.zero,
        ),
        child: child ??
            Text(
              text,
              style: TextStyle(
                color: textColor ?? colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
      ),
    );
  }
}

class _TextCancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const _TextCancelButton({required this.onPressed, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _DeleteConfirmationDialog extends StatelessWidget {
    final String shiftName;
    const _DeleteConfirmationDialog({required this.shiftName});
    
    @override
    Widget build(BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return _CustomDialogBase(
            title: l10n.shiftDeleteConfirmTitle,
            content: Text(
                l10n.shiftDeleteConfirmContent(shiftName),
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            ),
            actions: [
                _TextCancelButton(onPressed: () => Navigator.of(context).pop(false), text: l10n.commonCancel),
                 SizedBox(
                  width: 109.6,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      l10n.commonDelete,
                      style: TextStyle(
                        color: colorScheme.onError,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
            ]
        );
    }
}