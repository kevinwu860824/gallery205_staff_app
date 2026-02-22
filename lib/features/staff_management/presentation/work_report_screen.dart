// lib/features/staff_management/presentation/work_report_screen.dart
// ✅ Figma 完整修正版 (Overtime 改為 Slider)

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// 白色圓角輸入框樣式
InputDecoration _buildInputDecoration({required String hintText, required BuildContext context, int maxLines = 1}) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 16, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: theme.cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    alignLabelWithHint: maxLines > 1 ? true : false,
  );
}

// -------------------------------------------------------------------
// 2. WorkReportScreen (主頁面)
// -------------------------------------------------------------------

class WorkReportScreen extends StatefulWidget {
  const WorkReportScreen({super.key});

  @override
  State<WorkReportScreen> createState() => _WorkReportScreenState();
}

class _WorkReportScreenState extends State<WorkReportScreen> {
  DateTime selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  
  // ✅ 修改 1: 移除 hoursController，改用 double 變數
  double _overtimeHours = 0.0;
  
  bool isSubmitting = false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    // hoursController.dispose(); // 已移除
    super.dispose();
  }

  // 日期選擇 (UI 不變，只改觸發按鈕)
  void _showDatePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final earliestWithTime = now.subtract(const Duration(days: 4));
    final earliest = DateTime(earliestWithTime.year, earliestWithTime.month, earliestWithTime.day);
    final today = DateTime(now.year, now.month, now.day);
    final theme = Theme.of(context);

    showCupertinoModalPopup(
      context: context,
      builder: (_) => SizedBox(
        height: 320,
        child: CupertinoPopupSurface(
child: Container(
            color: theme.scaffoldBackgroundColor,
            child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    maximumDate: today,
                    minimumDate: earliest,
                    initialDateTime: selectedDate,
                    onDateTimeChanged: (DateTime newDate) {
                      setState(() {
                        selectedDate = DateTime(
                          newDate.year,
                          newDate.month,
                          newDate.day,
                        );
                      });
                    },
                  ),
                ),
                CupertinoButton(
                  child: Text(l10n.commonOk, style: TextStyle(color: theme.colorScheme.primary)), 
                  onPressed: () => context.pop(),
                )
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  // 顯示自訂 Dialog
  Future<void> _showNoticeDialog(String title, String content, {bool popPage = false}) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _NoticeDialog(title: title, content: content),
    );
    
    if (popPage && mounted) {
      context.pop(); // 關閉報告頁面
    }
  }

  // 顯示自訂的「覆蓋」Dialog
  Future<bool> _showConfirmOverwriteDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: l10n.workReportConfirmOverwriteTitle, 
        content: l10n.workReportConfirmOverwriteMsg, 
        confirmText: l10n.workReportOverwriteYes, 
      ),
    );
    return result ?? false; // 如果用戶點擊背景，視為 false
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty) {
      _showNoticeDialog(
        l10n.workReportErrorRequiredTitle, 
        l10n.workReportErrorRequiredMsg, 
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      final user = Supabase.instance.client.auth.currentUser;

      if (shopId == null || user == null) {
        throw 'Cannot get user information';
      }

      final existing = await Supabase.instance.client
          .from('work_reports')
          .select('id')
          .eq('user_id', user.id)
          .eq('work_date', DateFormat('yyyy-MM-dd').format(selectedDate))
          .maybeSingle();
      
      // ✅ 修改 2: 處理時數 (0 代表 null)
      final double? hoursToSave = _overtimeHours > 0 ? _overtimeHours : null;

      if (existing != null) {
        final shouldReplace = await _showConfirmOverwriteDialog();

        if (shouldReplace == true) {
          await Supabase.instance.client
              .from('work_reports')
              .update({
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'hours': hoursToSave, // 使用 Slider 的值
              })
              .eq('id', existing['id']);
        } else {
          setState(() => isSubmitting = false);
          return;
        }
      } else {
        await Supabase.instance.client.from('work_reports').insert({
          'user_id': user.id,
          'shop_id': shopId,
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'hours': hoursToSave, // 使用 Slider 的值
          'work_date': DateFormat('yyyy-MM-dd').format(selectedDate),
        });
      }

      if (mounted) {
        _showNoticeDialog(
          l10n.workReportSuccessTitle, 
          l10n.workReportSuccessMsg, 
          popPage: true, // 成功後自動 pop
        );
      }
    } catch (e) {
      if (mounted) {
        _showNoticeDialog(l10n.workReportSubmitFailed, e.toString()); 
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildHeader(context, l10n.workReportTitle), 
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 日期選擇 ---
              Text(
                l10n.workReportSelectDate, 
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _WhiteInputButton(
                text: DateFormat('yyyy/MM/dd').format(selectedDate),
                icon: CupertinoIcons.calendar,
                onPressed: () => _showDatePicker(context),
              ),
              const SizedBox(height: 20),
              
              // --- 標題 ---
              TextFormField(
                controller: titleController,
                decoration: _buildInputDecoration(hintText: l10n.workReportJobSubject, context: context), 
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                textAlignVertical: TextAlignVertical.center,
              ),
              const SizedBox(height: 12),
              
              // --- 內容 ---
              TextFormField(
                controller: descriptionController,
                decoration: _buildInputDecoration(
                  hintText: l10n.workReportJobDescription, 
                  maxLines: 5,
                  context: context,
                ),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              
              // --- ✅ 修改 3: Over Time Hour (Slider) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: theme.cardColor, 
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.workReportOverTime, 
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5), 
                            fontSize: 16, 
                            fontWeight: FontWeight.w500
                          ),
                        ),
                        Text(
                          '${_overtimeHours.toStringAsFixed(1)} ${l10n.workReportHourUnit}', 
                          style: TextStyle(
                            color: colorScheme.onSurface, 
                            fontSize: 18, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 40,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: colorScheme.primary, 
                          inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.1),
                          thumbColor: colorScheme.primary, 
                          overlayColor: colorScheme.primary.withValues(alpha: 0.1),
                          trackHeight: 4.0,
                        ),
                        child: Slider(
                          value: _overtimeHours,
                          min: 0.0,
                          max: 4.0,
                          divisions: 8, // (4-0) / 0.5 = 8 格
                          onChanged: (value) {
                            setState(() {
                              _overtimeHours = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // --- 送出按鈕 ---
              Center(
                child: _DialogWhiteButton(
                  text: l10n.commonSave, 
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
                      ? CupertinoActivityIndicator(color: colorScheme.onPrimary)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 4. 自訂 Dialog Widget (Figma 樣式)
// -------------------------------------------------------------------

// --- 統一的頁面頂部 (Header) ---
PreferredSizeWidget _buildHeader(BuildContext context, String title) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return PreferredSize(
    preferredSize: const Size.fromHeight(100.0), 
    child: Container(
      color: theme.scaffoldBackgroundColor,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
              onPressed: () => context.pop(), 
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 58), 
          ],
        ),
      ),
    ),
  );
}

// --- Dialog 專用的小白按鈕 (Save / OK) ---
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
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: child ?? Text(
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

// --- 白色文字按鈕 (Cancel) ---
class _TextCancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  const _TextCancelButton({required this.onPressed, this.text = 'Cancel'});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final displayText = text == 'Cancel' ? l10n.commonCancel : text;
    
    return TextButton(
      onPressed: onPressed,
      child: Text(
        displayText,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// --- Dialog 1: Notice (OK) ---
class _NoticeDialog extends StatelessWidget {
  final String title;
  final String content;
  const _NoticeDialog({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _DialogWhiteButton(
              text: l10n.commonOk, 
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Dialog 2: Confirm (Cancel / Confirm) ---
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;

  const _ConfirmDialog({
    required this.title,
    required this.content,
    this.confirmText = 'Save',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TextCancelButton(
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                _DialogWhiteButton(
                  text: confirmText,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- 報表頁面中的白色按鈕 (Date) ---
class _WhiteInputButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  
  const _WhiteInputButton({required this.text, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 38,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurface, size: 22),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}