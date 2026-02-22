// lib/features/reporting/presentation/work_report_overview_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 1. UI 樣式定義 - Removed _AppColors
// -------------------------------------------------------------------

class WorkReportOverviewScreen extends StatefulWidget {
  const WorkReportOverviewScreen({super.key});

  @override
  State<WorkReportOverviewScreen> createState() => _WorkReportOverviewScreenState();
}

class _WorkReportOverviewScreenState extends State<WorkReportOverviewScreen> {
  String? _shopId;
  bool _isLoading = true;

  // 篩選狀態
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedUserId; // null 代表 "All Staff"

  // 資料
  List<Map<String, dynamic>> _reports = [];
  Map<String, String> _userNames = {}; // user_id -> name
  List<Map<String, dynamic>> _staffList = []; // 下拉選單用

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    if (_shopId == null) {
      if (mounted) context.pop();
      return;
    }

    await Future.wait([
      _fetchStaffList(),
      _loadReportData(),
    ]);
  }

  // 1. 抓取員工清單 (用於篩選與顯示名字)
  Future<void> _fetchStaffList() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('user_id, name')
          .eq('shop_id', _shopId!);

      final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(res);
      final Map<String, String> nameMap = {};

      for (var u in users) {
        nameMap[u['user_id']] = u['name'] ?? 'Unknown';
      }

      if (mounted) {
        setState(() {
          _staffList = users;
          _userNames = nameMap;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff: $e');
    }
  }

  // 2. 抓取工作日報
  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startStr = DateFormat('yyyy-MM-dd').format(firstDay);
    final endStr = DateFormat('yyyy-MM-dd').format(lastDay);

    try {
      // 查詢 work_reports 表
      var query = Supabase.instance.client
          .from('work_reports')
          .select()
          .eq('shop_id', _shopId!)
          .gte('work_date', startStr)
          .lte('work_date', endStr);

      // 如果有選特定員工
      if (_selectedUserId != null) {
        query = query.eq('user_id', _selectedUserId!);
      }

      // 排序：最新的日期在上面
      final res = await query.order('work_date', ascending: false);
      
      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
    _loadReportData();
  }

  void _showMonthPicker() {
    final l10n = AppLocalizations.of(context)!;
    DateTime tempDate = _selectedMonth;
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(brightness: theme.brightness),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.monthYear,
                    initialDateTime: _selectedMonth,
                    onDateTimeChanged: (val) => tempDate = val,
                  ),
                ),
              ),
              CupertinoButton(
                child: Text(l10n.commonConfirm, style: TextStyle(color: theme.primaryColor)),
                onPressed: () {
                  context.pop();
                  setState(() => _selectedMonth = tempDate);
                  _loadReportData();
                },
              )
            ],
          ),
        );
      },
    );
  }

  void _showStaffFilter() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(l10n.workReportOverviewSelectStaff, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: Text(l10n.workReportOverviewAllStaff, style: TextStyle(color: colorScheme.onSurface)),
                    trailing: _selectedUserId == null ? Icon(Icons.check, color: theme.primaryColor) : null,
                    onTap: () {
                      setState(() => _selectedUserId = null);
                      context.pop();
                      _loadReportData();
                    },
                  ),
                  Divider(color: colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
                  ..._staffList.map((u) {
                    final uid = u['user_id'];
                    final name = u['name'];
                    return ListTile(
                      title: Text(name, style: TextStyle(color: colorScheme.onSurface)),
                      trailing: _selectedUserId == uid ? Icon(Icons.check, color: theme.primaryColor) : null,
                      onTap: () {
                        setState(() => _selectedUserId = uid);
                        context.pop();
                        _loadReportData();
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

  // 顯示詳細內容 Dialog
  void _showDetailDialog(Map<String, dynamic> report) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final userId = report['user_id'];
    final name = _userNames[userId] ?? l10n.commonUnknown;
    final dateStr = report['work_date'];
    final title = report['title'] ?? l10n.workReportOverviewNoSubject;
    final content = report['description'] ?? l10n.workReportOverviewNoContent;
    final hours = report['hours'] as num?;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(dateStr, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
              const SizedBox(height: 16),
              
              // Title
              Text(title, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              
              // Overtime Badge (if any)
              if (hours != null && hours > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.primaryColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    l10n.workReportDetailOvertimeLabel(hours.toStringAsFixed(1)),
                    style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              
              // Description (Scrollable)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 16, height: 1.5),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 120,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(l10n.commonClose, style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. Header ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(CupertinoIcons.chevron_left, color: theme.iconTheme.color, size: 32),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.workReportOverviewTitle,
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  // Staff Filter
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showStaffFilter,
                    child: Icon(
                      _selectedUserId == null ? CupertinoIcons.person_2_fill : CupertinoIcons.person_fill,
                      color: theme.primaryColor,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. Month Navigator ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(CupertinoIcons.chevron_left, color: theme.iconTheme.color, size: 32),
                    onPressed: () => _changeMonth(-1),
                  ),
                  GestureDetector(
                    onTap: _showMonthPicker,
                    child: Text(
                      DateFormat('yyyy/MM').format(_selectedMonth),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(CupertinoIcons.chevron_right, color: theme.iconTheme.color, size: 32),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // --- 3. Report List ---
            Expanded(
              child: _isLoading
                  ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
                  : _reports.isEmpty
                      ? Center(child: Text(l10n.workReportOverviewNoRecords, style: TextStyle(color: colorScheme.onSurfaceVariant))) // Modified to use theme color
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reports.length,
                          itemBuilder: (context, index) {
                            final report = _reports[index];
                            final userId = report['user_id'];
                            final name = _userNames[userId] ?? l10n.commonUnknown;
                            final dateStr = report['work_date'];
                            final title = report['title'] ?? l10n.workReportOverviewNoSubject;
                            final desc = report['description'] ?? l10n.workReportOverviewNoContent;
                            final hours = report['hours'] as num?;

                            return GestureDetector(
                              onTap: () => _showDetailDialog(report),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Name & Date
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(name, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
                                        Text(DateFormat.yMMMd(l10n.localeName).format(DateTime.parse(dateStr)), style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Title & Overtime Tag
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (hours != null && hours > 0)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.cardColor.withValues(alpha: 0.8), 
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              l10n.workReportOverviewOvertimeTag(hours.toStringAsFixed(1)),
                                              style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Preview Description
                                    Text(
                                      desc,
                                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}