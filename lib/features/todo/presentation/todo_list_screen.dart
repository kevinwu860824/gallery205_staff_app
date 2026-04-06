// lib/features/todo/presentation/todo_list_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'add_task_dialog.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _shopId;
  String? _currentUserId;
  bool _isLoading = true;

  // 頁籤資料
  bool _onlyMyTasks = false;
  List<Map<String, dynamic>> _incompleteTasks = []; // status = 'incomplete'
  List<Map<String, dynamic>> _pendingTasks = [];    // status = 'pending'
  List<Map<String, dynamic>> _completedTasks = [];  // status = 'completed'

  // 已完成頁籤的月份篩選
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // 快取使用者名稱
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    // 改為 3 個頁籤
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (_shopId == null || _currentUserId == null) {
      if (mounted) context.go('/');
      return;
    }

    await _fetchUserNames();
    await _refreshAll();
  }

  Future<void> _fetchUserNames() async {
    final res = await Supabase.instance.client
        .from('users')
        .select('user_id, name')
        .eq('shop_id', _shopId!);

    final Map<String, String> nameMap = {};
    for (var u in res) {
      nameMap[u['user_id'] as String] = u['name'] as String? ?? 'Unknown';
    }
    if (mounted) setState(() => _userNames = nameMap);
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchTasksByStatus('incomplete'),
      _fetchTasksByStatus('pending'),
      _fetchCompletedTasks(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // 通用抓取函式 (未完成 & 待確認)
  Future<void> _fetchTasksByStatus(String status) async {
    var query = Supabase.instance.client
        .from('todos')
        .select()
        .eq('shop_id', _shopId!)
        .eq('status', status);

    final res = await query;
    List<Map<String, dynamic>> tasks = List<Map<String, dynamic>>.from(res);

    // 排序邏輯
    tasks.sort((a, b) {
      final aDue = a['due_date'] != null ? DateTime.parse(a['due_date']) : null;
      final bDue = b['due_date'] != null ? DateTime.parse(b['due_date']) : null;

      // 1. 有截止日期先排
      if (aDue != null && bDue != null) return aDue.compareTo(bDue);
      if (aDue != null && bDue == null) return -1;
      if (aDue == null && bDue != null) return 1;

      // 2. 沒截止日期，依建立時間 (舊的在上面)
      final aCreate = DateTime.parse(a['created_at']);
      final bCreate = DateTime.parse(b['created_at']);
      return aCreate.compareTo(bCreate);
    });

    if (mounted) {
      setState(() {
        if (status == 'incomplete') _incompleteTasks = tasks;
        if (status == 'pending') _pendingTasks = tasks;
      });
    }
  }

  // 抓取已完成 (依月份)
  Future<void> _fetchCompletedTasks() async {
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

    final res = await Supabase.instance.client
        .from('todos')
        .select()
        .eq('shop_id', _shopId!)
        .eq('status', 'completed')
        .gte('completed_at', startOfMonth.toIso8601String())
        .lte('completed_at', endOfMonth.toIso8601String())
        .order('completed_at', ascending: false); // 最新的在上面

    if (mounted) setState(() => _completedTasks = List<Map<String, dynamic>>.from(res));
  }

  // --- 動作邏輯 ---

  // 1. 提交驗收 (由 "未完成" -> "待確認")
  void _submitForReview(Map<String, dynamic> task) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // 檢查是否為被指派人或指派人
    final List<dynamic> assigneeIds = task['assignee_ids'] ?? [];
    final assigner = task['assigner_id'];
    
    if (!assigneeIds.contains(_currentUserId) && _currentUserId != assigner) {
      _showSnackBar(l10n.todoErrorNoPermissionSubmit, isError: true); 
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor,
        title: Text(l10n.todoSubmitReviewTitle, style: theme.dialogTheme.titleTextStyle), 
        content: Text(l10n.todoSubmitReviewContent, style: theme.dialogTheme.contentTextStyle), 
        actions: [
          TextButton(child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface)), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: Text(l10n.todoSubmitButton, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('todos').update({
        'status': 'pending',
      }).eq('id', task['id']);

      // 🔔 通知指派人
      if (_currentUserId != task['assigner_id']) {
        final myName = _userNames[_currentUserId] ?? '員工';
        _sendNotification(
          title: l10n.notificationTodoReviewTitle, 
          body: l10n.notificationTodoReviewBody(myName, task['title']), 
          targetUserIds: [assigner],
        );
      }

      _refreshAll();
    }
  }

  // 2. 通過驗收 (由 "待確認" -> "已完成")
  void _approveTask(Map<String, dynamic> task) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 只有指派人可以驗收
    if (_currentUserId != task['assigner_id']) {
      _showSnackBar(l10n.todoErrorNoPermissionApprove, isError: true); 
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor,
        title: Text(l10n.todoApproveTitle, style: theme.dialogTheme.titleTextStyle), 
        content: Text(l10n.todoApproveContent, style: theme.dialogTheme.contentTextStyle), 
        actions: [
          TextButton(child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface)), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: Text(l10n.todoApproveButton, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('todos').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', task['id']);

      // 🔔 通知被指派人 (任務已完成)
      final List<dynamic> assigneeIds = task['assignee_ids'] ?? [];
      _sendNotification(
        title: l10n.notificationTodoApprovedTitle, 
        body: l10n.notificationTodoApprovedBody(task['title']), 
        targetUserIds: List<String>.from(assigneeIds),
      );

      _refreshAll();
    }
  }

  // 3. 退回重做 (由 "待確認" -> "未完成")
  void _rejectTask(Map<String, dynamic> task) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_currentUserId != task['assigner_id']) {
      _showSnackBar(l10n.todoErrorNoPermissionReject, isError: true); 
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor,
        title: Text(l10n.todoRejectTitle, style: theme.dialogTheme.titleTextStyle), 
        content: Text(l10n.todoRejectContent, style: theme.dialogTheme.contentTextStyle),
        actions: [
          TextButton(child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface)), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: Text(l10n.todoRejectButton, style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('todos').update({
        'status': 'incomplete',
        'completed_at': null,
      }).eq('id', task['id']);

      // 🔔 通知被指派人 (退回)
      final List<dynamic> assigneeIds = task['assignee_ids'] ?? [];
      _sendNotification(
        title: l10n.notificationTodoRejectedTitle, 
        body: l10n.notificationTodoRejectedBody(task['title']), 
        targetUserIds: List<String>.from(assigneeIds),
      );

      _refreshAll();
    }
  }

  // 輔助函式：發送通知
  Future<void> _sendNotification({required String title, required String body, required List<String> targetUserIds}) async {
    try {
      await Supabase.instance.client.functions.invoke('notify-todo-event', body: {
        'title': title,
        'body': body,
        'target_user_ids': targetUserIds,
        'route': '/todoList',
        'shop_id': _shopId,
      });
    } catch (e) {
      debugPrint('Notification Error: $e');
    }
  }

  // 編輯與刪除 (保持原邏輯)
  void _editTask(Map<String, dynamic> task) async {
    final l10n = AppLocalizations.of(context)!;
    if (_currentUserId != task['assigner_id']) {
      _showSnackBar(l10n.todoErrorNoPermissionEdit, isError: true); 
      return;
    }
    final result = await showDialog(
      context: context,
      builder: (_) => AddTaskDialog(shopId: _shopId!, userNames: _userNames, existingTask: task),
    );
    if (result == true) _refreshAll();
  }

  void _deleteTask(Map<String, dynamic> task) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_currentUserId != task['assigner_id']) {
      _showSnackBar(l10n.todoErrorNoPermissionDelete, isError: true); 
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.dialogTheme.backgroundColor,
        title: Text(l10n.todoDeleteTitle, style: theme.dialogTheme.titleTextStyle), 
        content: Text(l10n.todoDeleteContent, style: theme.dialogTheme.contentTextStyle), 
        actions: [
          TextButton(child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface)), onPressed: () => Navigator.pop(context, false)),
          TextButton(child: Text(l10n.commonDelete, style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)), onPressed: () => Navigator.pop(context, true)), 
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('todos').delete().eq('id', task['id']);
      // 發送刪除通知
      final List<dynamic> assigneeIds = task['assignee_ids'] ?? [];
      if (assigneeIds.isNotEmpty) {
        _sendNotification(
          title: l10n.notificationTodoDeletedTitle,
          body: l10n.notificationTodoDeletedBody(task['title']), 
          targetUserIds: List<String>.from(assigneeIds),
        );
      }
      _refreshAll();
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  void _showAddTaskDialog() async {
    final result = await showDialog(
      context: context,
      builder: (_) => AddTaskDialog(shopId: _shopId!, userNames: _userNames),
    );
    if (result == true) {
      _refreshAll();
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.todoScreenTitle, style: TextStyle(color: colorScheme.onSurface)), 
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary, // Selected tab color
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          tabs: [
            Tab(text: l10n.todoTabIncomplete), 
            Tab(text: l10n.todoTabPending),    
            Tab(text: l10n.todoTabCompleted),  
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(CupertinoIcons.add, color: colorScheme.onSurface),
            onPressed: _showAddTaskDialog,
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskList(_incompleteTasks, status: 'incomplete'),
          _buildTaskList(_pendingTasks, status: 'pending'), // 待確認列表
          _buildCompletedTab(),
        ],
      ),
    );
  }

  // 通用列表建構 (未完成 & 待確認)
  Widget _buildTaskList(List<Map<String, dynamic>> tasks, {required String status}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double hPadding = isTablet ? (screenWidth - 600) / 2 : 16.0;
    final displayTasks = _onlyMyTasks
        ? tasks.where((t) {
            final ids = t['assignee_ids'] as List<dynamic>? ?? [];
            return ids.contains(_currentUserId);
          }).toList()
        : tasks;

    return Column(
      children: [
        // 只有 "未完成" 頁籤才需要 "只看我的" 篩選，還是都要？
        // 假設都要
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Theme(
                    data: ThemeData(
                        unselectedWidgetColor: colorScheme.onSurface,
                        checkboxTheme: CheckboxThemeData(
                          fillColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.selected)) {
                              return colorScheme.primary;
                            }
                            return null; // transparent for unselected usually, or Theme default
                          }),
                          checkColor: MaterialStateProperty.all(colorScheme.onPrimary),
                        )
                    ),
                    child: Checkbox(
                      value: _onlyMyTasks,
                      activeColor: colorScheme.primary,
                      checkColor: colorScheme.onPrimary,
                      onChanged: (val) => setState(() => _onlyMyTasks = val ?? false),
                    ),
                  ),
                  Text(l10n.todoFilterMyTasks, style: TextStyle(color: colorScheme.onSurface)), 
                ],
              ),
              Text(l10n.todoCountSuffix(displayTasks.length), style: TextStyle(color: colorScheme.onSurfaceVariant)), 
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
              : displayTasks.isEmpty
              ? Center(child: Text(status == 'pending' ? l10n.todoEmptyPending : l10n.todoEmptyIncomplete, style: TextStyle(color: colorScheme.onSurfaceVariant))) 
              : ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
            itemCount: displayTasks.length,
            itemBuilder: (_, index) => _buildTaskCard(displayTasks[index], status: status),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedTab() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double hPadding = isTablet ? (screenWidth - 600) / 2 : 16.0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
                onPressed: () {
                  setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));
                  _fetchCompletedTasks();
                },
              ),
              Text(
                DateFormat('yyyy / MM').format(_selectedMonth),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface),
                onPressed: () {
                  setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
                  _fetchCompletedTasks();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
              : _completedTasks.isEmpty
              ? Center(child: Text(l10n.todoEmptyCompleted, style: TextStyle(color: colorScheme.onSurfaceVariant))) 
              : ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
            itemCount: _completedTasks.length,
            itemBuilder: (_, index) => _buildTaskCard(_completedTasks[index], status: 'completed'),
          ),
        ),
      ],
    );
  }

  // 卡片元件 (依 status 改變外觀與行為)
  Widget _buildTaskCard(Map<String, dynamic> task, {required String status}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = task['title'] ?? l10n.commonNoTitle; 
    final desc = task['description'] ?? '';
    final assignerName = _userNames[task['assigner_id']] ?? l10n.commonUnknown; 

    final List<dynamic> assigneeIds = task['assignee_ids'] ?? [];
    String assigneeNamesStr;
    if (assigneeIds.isEmpty) {
      assigneeNamesStr = l10n.todoUnassigned; 
    } else if (assigneeIds.length == 1) {
      assigneeNamesStr = _userNames[assigneeIds.first] ?? l10n.commonUnknown;
    } else {
      final first = _userNames[assigneeIds.first] ?? l10n.commonUnknown;
      assigneeNamesStr = '$first (+${assigneeIds.length - 1})';
    }

    final dueDateStr = task['due_date'];
    final DateTime? dueDate = dueDateStr != null ? DateTime.parse(dueDateStr).toLocal() : null;

    // 狀態顏色設定
    bool isOverdue = false;
    bool isUrgent = false;
    if (status == 'incomplete' && dueDate != null) {
      final now = DateTime.now();
      if (now.isAfter(dueDate)) isOverdue = true;
      else if (dueDate.difference(now).inHours < 24) isUrgent = true;
    }

    Color borderColor = theme.cardColor;
    Color dateColor = colorScheme.onSurfaceVariant;

    if (status == 'completed') {
      dateColor = Colors.green;
    } else if (status == 'pending') {
      borderColor = Colors.blue; 
      dateColor = Colors.blue;
    } else {
      if (isOverdue) {
        borderColor = colorScheme.error;
        dateColor = colorScheme.error;
      } else if (isUrgent) {
        borderColor = Colors.amber;
        dateColor = Colors.amber;
      }
    }

    return GestureDetector(
      onTap: () {
        // 點擊卡片後的動作
        if (status == 'incomplete') {
          _showIncompleteActionSheet(task);
        } else if (status == 'pending') {
          _showPendingActionSheet(task);
        }
        // 已完成狀態目前不給點擊操作
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: (status == 'pending' || isOverdue || isUrgent) ? 2 : 0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (dueDate != null)
                  Row(
                    children: [
                      Icon(CupertinoIcons.clock, size: 14, color: dateColor),
                      const SizedBox(width: 4),
                      Text(
                        (dueDate.hour == 23 && dueDate.minute == 59)
                            ? DateFormat('MM/dd').format(dueDate)
                            : DateFormat('MM/dd HH:mm').format(dueDate),
                        style: TextStyle(color: dateColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (desc.isNotEmpty) ...[
              Text(desc, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 8),
            ],
            Divider(color: theme.dividerColor, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${l10n.todoLabelTo}$assigneeNamesStr', style: TextStyle(color: colorScheme.onSurface)), 
                Text('${l10n.todoLabelFrom}$assignerName', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)), 
              ],
            ),
            if (status == 'completed' && task['completed_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.check_mark_circled, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('${l10n.todoLabelCompletedAt}${DateFormat('MM/dd HH:mm').format(DateTime.parse(task['completed_at']).toLocal())}', 
                        style: const TextStyle(color: Colors.green, fontSize: 12))
                  ],
                ),
              ),
            if (status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.hourglass, color: Colors.blue, size: 16),
                    const SizedBox(width: 4),
                    Text(l10n.todoLabelWaitingReview, style: const TextStyle(color: Colors.blue, fontSize: 12)) 
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  // 動作選單：未完成 (提交驗收 / 編輯 / 刪除)
  void _showIncompleteActionSheet(Map<String, dynamic> task) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Use transparent to handle rounded corners in container
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.todoActionSheetTitle(task['title']), // Title
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              
              ListTile(
                leading: Icon(CupertinoIcons.check_mark_circled, color: colorScheme.primary),
                title: Text(l10n.todoActionCompleteAndSubmit, style: TextStyle(color: colorScheme.onSurface)),
                onTap: () { Navigator.pop(context); _submitForReview(task); },
              ),
              
              if (_currentUserId == task['assigner_id']) ...[
                 Divider(height: 1, color: theme.dividerColor, indent: 16, endIndent: 16),
                 ListTile(
                  leading: Icon(CupertinoIcons.pencil, color: colorScheme.onSurface),
                  title: Text(l10n.commonEdit, style: TextStyle(color: colorScheme.onSurface)),
                  onTap: () { Navigator.pop(context); _editTask(task); },
                ),
                 Divider(height: 1, color: theme.dividerColor, indent: 16, endIndent: 16),
                 ListTile(
                  leading: const Icon(CupertinoIcons.delete, color: Colors.red),
                  title: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(context); _deleteTask(task); },
                ),
              ],
              
              Divider(height: 8, thickness: 8, color: theme.scaffoldBackgroundColor), // Separator
              
              ListTile(
                title: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 動作選單：待確認 (通過 / 退回)
  void _showPendingActionSheet(Map<String, dynamic> task) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // 判斷權限：只有指派人可以審核
    final bool isAssigner = _currentUserId == task['assigner_id'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.todoReviewSheetTitle(task['title']), 
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isAssigner) Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.todoReviewSheetMessageAssigner,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ) else Padding(
                 padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.todoReviewSheetMessageAssignee,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              
              Divider(height: 1, color: theme.dividerColor),
              
              if (isAssigner) ...[
                ListTile(
                  leading: const Icon(CupertinoIcons.check_mark, color: Colors.green),
                  title: Text(l10n.todoActionApprove, style: const TextStyle(color: Colors.green)),
                  onTap: () { Navigator.pop(context); _approveTask(task); },
                ),
                Divider(height: 1, color: theme.dividerColor, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(CupertinoIcons.xmark, color: Colors.red),
                  title: Text(l10n.todoActionReject, style: const TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(context); _rejectTask(task); },
                ),
              ] else ...[
                 ListTile(
                  leading: Icon(CupertinoIcons.eye, color: colorScheme.onSurface),
                  title: Text(l10n.todoActionViewDetails, style: TextStyle(color: colorScheme.onSurface)),
                  onTap: () { Navigator.pop(context); },
                ),
              ],
              
              Divider(height: 8, thickness: 8, color: theme.scaffoldBackgroundColor),
              
              ListTile(
                title: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}