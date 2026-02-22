// lib/features/todo/presentation/add_task_dialog.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

class AddTaskDialog extends StatefulWidget {
  final String shopId;
  final Map<String, String> userNames;
  final Map<String, dynamic>? existingTask;

  const AddTaskDialog({
    super.key,
    required this.shopId,
    required this.userNames,
    this.existingTask,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  // 支援複選
  List<String> _selectedAssigneeIds = [];

  // 日期與時間分開控制
  bool _enableDueDate = false;
  DateTime? _selectedDate;

  bool _enableDueTime = false;
  TimeOfDay? _selectedTime;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      _titleController.text = t['title'];
      _descController.text = t['description'] ?? '';

      // 載入舊的指派人
      if (t['assignee_ids'] != null) {
        _selectedAssigneeIds = List<String>.from(t['assignee_ids']);
      } else if (t['assignee_id'] != null) {
        _selectedAssigneeIds = [t['assignee_id']];
      }

      // 載入日期時間
      if (t['due_date'] != null) {
        _enableDueDate = true;
        final dt = DateTime.parse(t['due_date']).toLocal();
        _selectedDate = DateTime(dt.year, dt.month, dt.day);

        // 簡單判斷是否有設定時間
        if (dt.hour == 23 && dt.minute == 59) {
          _enableDueTime = false;
        } else {
          _enableDueTime = true;
          _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        }
      }
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_titleController.text.trim().isEmpty || _selectedAssigneeIds.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser!;

      // 組合最終的 Due Date
      String? finalDueDateIso;
      if (_enableDueDate && _selectedDate != null) {
        final time = _enableDueTime && _selectedTime != null
            ? _selectedTime!
            : const TimeOfDay(hour: 23, minute: 59);

        final dt = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            time.hour,
            time.minute
        );
        finalDueDateIso = dt.toUtc().toIso8601String();
      }

      final data = {
        'shop_id': widget.shopId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'assigner_id': widget.existingTask?['assigner_id'] ?? user.id,
        'assignee_ids': _selectedAssigneeIds,
        'due_date': finalDueDateIso,
      };

      if (widget.existingTask != null) {
        // --- 更新邏輯 (Update) ---
        await Supabase.instance.client
            .from('todos')
            .update(data)
            .eq('id', widget.existingTask!['id']);
            
        // ✅ 編輯通知 (修正: 加入 .client)
        try {
          String notifTitle = l10n.notificationTodoEditTitle;
          if (finalDueDateIso != null) {
             final dt = DateTime.parse(finalDueDateIso);
             final diff = dt.difference(DateTime.now());
             if (diff.inHours < 18 && diff.inHours > 0) {
               notifTitle = l10n.notificationTodoUrgentUpdate; 
             }
          }

          // 這裡加上了 .client
          await Supabase.instance.client.functions.invoke('notify-todo-event', body: {
            'title': notifTitle,
            'body': l10n.notificationTodoEditBody(_titleController.text.trim()),
            'target_user_ids': _selectedAssigneeIds,
            'route': '/todoList',
            'shop_id': widget.shopId,
          });
        } catch (e) {
          debugPrint('Edit Notification Error: $e');
        }

      } else {
        // --- 新增邏輯 (Insert) ---
        await Supabase.instance.client
            .from('todos')
            .insert(data);
            
        // ✅ 新增通知 (修正: 加入 .client)
        try {
          String notifTitle = l10n.notificationTodoNewTitle;
          if (finalDueDateIso != null) {
             final dt = DateTime.parse(finalDueDateIso);
             final diff = dt.difference(DateTime.now());
             if (diff.inHours < 18 && diff.inHours > 0) {
               notifTitle = l10n.notificationTodoUrgentNew; 
             }
          }
          
          // 這裡加上了 .client
          await Supabase.instance.client.functions.invoke('notify-todo-event', body: {
            'title': notifTitle,
            'body': l10n.notificationTodoNewBody(_titleController.text.trim()), 
            'target_user_ids': _selectedAssigneeIds,
            'route': '/todoList',
            'shop_id': widget.shopId,
          });
        } catch (e) {
          debugPrint('New Task Notification Error: $e');
        }
      }

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      debugPrint('Save Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 顯示月曆
  Future<void> _pickDate() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    
    // 設定 locale
    Locale locale;
    if (l10n.localeName == 'zh') {
      locale = const Locale('zh', 'TW');
    } else {
      locale = const Locale('en', 'US');
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      locale: locale, // 使用當前語言環境
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
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

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // 顯示時間選擇器
  Future<void> _pickTime() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final picked = await showTimePicker(
        context: context,
        initialTime: _selectedTime ?? const TimeOfDay(hour: 12, minute: 0),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: colorScheme.primary,
                onPrimary: colorScheme.onPrimary,
                surface: theme.cardColor,
                onSurface: colorScheme.onSurface,
              ),
            ),
            child: child!,
          );
        }
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final items = widget.userNames.entries
        .map((e) => MultiSelectItem<String>(e.key, e.value))
        .toList();
        
    final inputDecoration = BoxDecoration(
        color: theme.scaffoldBackgroundColor, 
        borderRadius: BorderRadius.circular(10)
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  widget.existingTask != null ? l10n.todoAddTaskTitleEdit : l10n.todoAddTaskTitleNew, 
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // 1. 標題
              CupertinoTextField(
                controller: _titleController,
                placeholder: l10n.todoAddTaskLabelTitle, 
                padding: const EdgeInsets.all(12),
                style: TextStyle(color: colorScheme.onSurface),
                placeholderStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                decoration: inputDecoration,
              ),
              const SizedBox(height: 12),

              // 2. 內容
              CupertinoTextField(
                controller: _descController,
                placeholder: l10n.todoAddTaskLabelDesc, 
                maxLines: 3,
                padding: const EdgeInsets.all(12),
                style: TextStyle(color: colorScheme.onSurface),
                placeholderStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                decoration: inputDecoration,
              ),
              const SizedBox(height: 12),

              // 3. 指派給 (複選)
              Text(l10n.todoAddTaskLabelAssign, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)), 
              const SizedBox(height: 8),
              
              MultiSelectDialogField<String>(
                items: items,
                initialValue: _selectedAssigneeIds,
                title: Text(l10n.todoAddTaskSelectStaff, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)), 
                confirmText: Text(l10n.commonOk, style: TextStyle(color: colorScheme.onSurface)), 
                cancelText: Text(l10n.commonCancel.toUpperCase(), style: TextStyle(color: colorScheme.onSurface)), 
                backgroundColor: theme.cardColor,
                itemsTextStyle: TextStyle(color: colorScheme.onSurface),
                selectedItemsTextStyle: TextStyle(color: colorScheme.onSurface),
                selectedColor: colorScheme.primary, // Using primary color for selected items
                unselectedColor: colorScheme.onSurface.withOpacity(0.6),
                searchTextStyle: TextStyle(color: colorScheme.onSurface),
                searchHintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                buttonText: Text(
                  _selectedAssigneeIds.isEmpty
                      ? l10n.todoAddTaskSelectStaff 
                      : l10n.todoAddTaskSelectedStaff(_selectedAssigneeIds.length), 
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
                buttonIcon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
                onConfirm: (values) {
                  setState(() => _selectedAssigneeIds = values);
                },
                chipDisplay: MultiSelectChipDisplay(
                  chipColor: colorScheme.primary,
                  textStyle: TextStyle(color: colorScheme.onPrimary),
                  items: _selectedAssigneeIds.map((id) => MultiSelectItem(id, widget.userNames[id] ?? 'Unknown')).toList(),
                  onTap: (value) {
                    setState(() => _selectedAssigneeIds.remove(value));
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 4. 截止日期開關
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.todoAddTaskSetDueDate, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
                  CupertinoSwitch(
                    value: _enableDueDate,
                    activeColor: colorScheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _enableDueDate = val;
                        if (val && _selectedDate == null) {
                          _selectedDate = DateTime.now().add(const Duration(days: 1));
                        }
                      });
                    },
                  ),
                ],
              ),

              // 5. 日期選擇 (月曆)
              if (_enableDueDate) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.onSurface.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate != null
                              ? DateFormat.yMMMd(l10n.localeName).add_E().format(_selectedDate!) 
                              : l10n.todoAddTaskSelectDate, 
                          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                        ),
                        Icon(Icons.calendar_month, color: colorScheme.onSurface),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 6. 時間開關
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.todoAddTaskSetDueTime, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)), 
                    CupertinoSwitch(
                      value: _enableDueTime,
                      activeColor: colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          _enableDueTime = val;
                          if (val && _selectedTime == null) {
                            _selectedTime = const TimeOfDay(hour: 12, minute: 0);
                          }
                        });
                      },
                    ),
                  ],
                ),

                // 7. 時間選擇
                if (_enableDueTime)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorScheme.onSurface.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTime != null
                                  ? _selectedTime!.format(context)
                                  : l10n.todoAddTaskSelectTime, 
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                            ),
                            Icon(Icons.access_time, color: colorScheme.onSurface),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 30),

              // 按鈕
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoButton(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const CupertinoActivityIndicator()
                          : Text(l10n.commonSave, style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}