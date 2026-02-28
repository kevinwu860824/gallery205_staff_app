// lib/features/home/presentation/home_screen.dart

import 'dart:ui';
import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart'; 
import 'package:gallery205_staff_app/core/services/permission_service.dart'; 
import 'package:gallery205_staff_app/core/constants/app_permissions.dart'; 
import 'package:gallery205_staff_app/core/models/recurrence_rule.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userRole;
  String? shopCode;
  bool isLoading = true;
  
  List<_HomeButton> _currentButtons = [];
  bool _isButtonsInitialized = false;
  
  Locale? _lastLocale;
  
  bool _isEditing = false;
  final GlobalKey<_ScheduleWidgetState> _scheduleKey = GlobalKey<_ScheduleWidgetState>();

  int _unreadCount = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchUnreadCount();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchUnreadCount());
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final savedShopCode = prefs.getString('savedShopCode');
    final shopId = prefs.getString('savedShopId');
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;

    if (savedShopCode == null || shopId == null || userId == null) {
      if (mounted) context.go('/');
      return;
    }

    try {
      final userRes = await Supabase.instance.client
          .from('user_shop_map')
          .select('role, role_id') 
          .eq('user_id', userId)
          .eq('shop_code', shopId)
          .maybeSingle();

      if (userRes != null && userRes['role_id'] != null) {
        await PermissionService().loadPermissions(
          userRes['role_id'], 
          roleName: userRes['role'], 
        );
      } else {
        PermissionService().clear();
      }

      if (mounted) {
        setState(() {
          userRole = userRes?['role'];
          shopCode = savedShopCode;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❗ Supabase 錯誤: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }
  
  Future<void> _fetchUnreadCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final currentShopId = prefs.getString('savedShopId');
    
    if (user == null || currentShopId == null) return; 

    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('shop_id', currentShopId)
          .eq('is_read', false)
          .count(CountOption.exact);
      
      final count = res.count;

      if (mounted && count != _unreadCount) {
        setState(() => _unreadCount = count);
        if (await FlutterAppBadger.isAppBadgeSupported()) {
           if (count > 0) {
             FlutterAppBadger.updateBadgeCount(count);
           } else {
             FlutterAppBadger.removeBadge();
           }
        }
      }
    } catch (e) {
      debugPrint('Notification fetch error: $e'); 
    }
  }

  Future<void> _showNotificationsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const _NotificationPopup(),
    );
    if (mounted) {
      _fetchUnreadCount();
    }
  }

  Future<void> _initButtons(AppLocalizations l10n, {bool forceRefresh = false}) async {
    if (_isButtonsInitialized && !forceRefresh) return;

    final p = PermissionService(); 

    final List<_HomeButton> allButtons = [
      _HomeButton(id: 'order', label: l10n.homeOrder, icon: CupertinoIcons.cart, route: '/selectArea', permissionKey: AppPermissions.homeOrder),
      _HomeButton(id: 'prep', label: l10n.homePrep, icon: CupertinoIcons.doc_text, route: '/prep', permissionKey: AppPermissions.homePrep),
      _HomeButton(id: 'stock', label: l10n.homeStock, icon: CupertinoIcons.cube_box, route: '/inventoryView', permissionKey: AppPermissions.homeStock),
      _HomeButton(id: 'dashboard', label: l10n.homeBackhouse, icon: CupertinoIcons.chart_bar_alt_fill, route: '/dashboard', permissionKey: AppPermissions.homeBackDashboard),
      _HomeButton(id: 'daily', label: l10n.homeDailyCost, icon: CupertinoIcons.money_dollar, route: '/costInput', permissionKey: AppPermissions.homeDailyCost),
      _HomeButton(id: 'cashflow', label: l10n.homeCashFlow, icon: CupertinoIcons.doc_chart, route: '/cashSettlement', permissionKey: AppPermissions.homeCashFlow),
      _HomeButton(id: 'scan', label: 'AI Scan', icon: CupertinoIcons.viewfinder, route: '/smartScanner', permissionKey: AppPermissions.homeScan),
      
      _HomeButton(id: 'calendar', label: l10n.homeCalendar, icon: CupertinoIcons.calendar, route: '/personalSchedule', permissionKey: null),
      _HomeButton(id: 'shift', label: l10n.homeShift, icon: CupertinoIcons.briefcase, route: '/scheduleView', permissionKey: null),
      _HomeButton(id: 'punch', label: l10n.homeClockIn, icon: CupertinoIcons.person, route: '/punchIn', permissionKey: null),
      _HomeButton(id: 'report', label: l10n.homeWorkReport, icon: CupertinoIcons.pencil_ellipsis_rectangle, route: '/workReport', permissionKey: null),
      _HomeButton(id: 'todo', label: '待辦事項', icon: CupertinoIcons.checkmark_square, route: '/todoList', permissionKey: null),
      _HomeButton(id: 'settings', label: l10n.homeSetting, icon: CupertinoIcons.settings, route: '/settings', permissionKey: null),
    ];

    List<_HomeButton> visibleButtons = allButtons.where((btn) {
      if (btn.permissionKey == null) return true;
      return p.hasPermission(btn.permissionKey!);
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedOrder = prefs.getStringList('home_icon_order');

    if (savedOrder != null && savedOrder.isNotEmpty) {
      visibleButtons.sort((a, b) {
        int indexA = savedOrder.indexOf(a.id);
        int indexB = savedOrder.indexOf(b.id);
        if (indexA == -1) indexA = 999;
        if (indexB == -1) indexB = 999;
        return indexA.compareTo(indexB);
      });
    }

    if (mounted) {
      setState(() {
        _currentButtons = visibleButtons;
        _isButtonsInitialized = true;
      });
    }
  }

  Future<void> _saveButtonOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> idList = _currentButtons.map((btn) => btn.id).toList();
    await prefs.setStringList('home_icon_order', idList);
  }

  void _enterEditMode() {
    if (!_isEditing) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isEditing = true;
      });
    }
  }

  void _exitEditMode() {
    setState(() {
      _isEditing = false;
    });
  }

  // [新增] 關帳前檢查未結單桌位
  Future<bool> _checkActiveOrdersBeforeSettlement() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return true;

    setState(() => isLoading = true);

    try {
      final res = await Supabase.instance.client
          .from('order_groups')
          .select('table_names')
          .eq('shop_id', shopId)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .neq('status', 'merged');
      
      if (res.isNotEmpty) {
        final List<String> tableNames = (res as List)
            .expand((row) => (row['table_names'] as String).split(','))
            .toSet()
            .toList();
        
        tableNames.sort();

        if (mounted) {
          setState(() => isLoading = false);
          await showDialog(
            context: context,
            builder: (context) => _DarkStyleDialog(
              title: "尚有未結桌位",
              contentWidget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("請先結清或取消以下桌位的訂單，\n才能進行關帳與結算：", 
                    style: TextStyle(color: Colors.white70, fontSize: 16), 
                    textAlign: TextAlign.center
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tableNames.map((name) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )).toList(),
                  ),
                ],
              ),
              confirmText: "前往結帳",
              onConfirm: () => context.push('/selectArea'),
              cancelText: "取消",
              onCancel: () => Navigator.pop(context),
            ),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint("Check active orders failed: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = Localizations.localeOf(context);

    if (!isLoading) {
      if (!_isButtonsInitialized || currentLocale != _lastLocale) {
        _lastLocale = currentLocale;
        _initButtons(l10n, forceRefresh: true);
      }
    }

    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CupertinoActivityIndicator(color: Theme.of(context).colorScheme.onSurface)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                    child: IgnorePointer(
                      ignoring: _isEditing,
                      child: Opacity(
                        opacity: _isEditing ? 0.6 : 1.0,
                        child: _ScheduleWidget(
                          key: _scheduleKey,
                          l10n: l10n,
                          unreadCount: _unreadCount,           
                          onBellTap: _showNotificationsDialog, 
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 27),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ReorderableGridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 6 : 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 0,
                      childAspectRatio: 0.75,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          final element = _currentButtons.removeAt(oldIndex);
                          _currentButtons.insert(newIndex, element);
                        });
                        _saveButtonOrder();
                      },
                      children: _currentButtons.map((button) {
                        return _LiquidGlassIcon(
                          key: ValueKey(button.id),
                          label: button.label,
                          icon: button.icon,
                          isEditing: _isEditing,
                          onPressed: button.route != null
                              ? () async {
                                  if (_isEditing) return;
                                  
                                  // [新增] 關帳提前檢查
                                  if (button.id == 'cashflow') {
                                    final proceed = await _checkActiveOrdersBeforeSettlement();
                                    if (!proceed) return;
                                  }

                                  await context.push(button.route!);
                                  if (mounted) {
                                    _scheduleKey.currentState?.refresh();
                                  }
                                }
                              : null,
                          onLongPress: _enterEditMode, 
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          
          if (_isEditing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 24,
              child: GestureDetector(
                onTap: _exitEditMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Text(
                    "Done",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 🔔 通知彈窗組件
// -------------------------------------------------------------------
class _NotificationPopup extends StatefulWidget {
  const _NotificationPopup();

  @override
  State<_NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends State<_NotificationPopup> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndReadNotifications();
  }

  Future<void> _fetchAndReadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final currentShopId = prefs.getString('savedShopId');

    if (user == null || currentShopId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .eq('shop_id', currentShopId)
          .order('created_at', ascending: false)
          .limit(50);
      
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }

      final unreadIds = _notifications
          .where((n) => n['is_read'] == false)
          .map((n) => n['id'])
          .toList();
      
      if (unreadIds.isNotEmpty) {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .inFilter('id', unreadIds);
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final currentShopId = prefs.getString('savedShopId');

    if (user == null || currentShopId == null) return;

    setState(() => _loading = true);

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('shop_id', currentShopId)
          .eq('is_read', false);
      
      await _fetchAndReadNotifications();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _loading ? null : _markAllAsRead,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.checkmark_alt, color: Theme.of(context).colorScheme.onSurface, size: 16),
                              const SizedBox(width: 4),
                              Text("Read All", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(CupertinoIcons.xmark, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: _loading 
                ? Center(child: CupertinoActivityIndicator(color: Theme.of(context).colorScheme.onSurface))
                : _notifications.isEmpty 
                    ? Center(child: Text('No notifications', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))))
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          final created = DateTime.parse(notif['created_at']).toLocal();
                          final bool isUnread = notif['is_read'] == false;
                          
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Row(
                                  children: [
                                    if (isUnread)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        notif['title'] ?? '通知',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(notif['body'] ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
                                    const SizedBox(height: 6),
                                    Text(
                                      DateFormat('MM/dd HH:mm').format(created),
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  if (notif['route'] != null) {
                                    Navigator.pop(context);
                                    context.push(notif['route']);
                                  }
                                },
                              ),
                              if (index < _notifications.length - 1)
                                Divider(height: 1, color: Theme.of(context).dividerColor, indent: 16, endIndent: 16),
                            ],
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

// -------------------------------------------------------------------
// Widget 組件
// -------------------------------------------------------------------
class _ScheduleWidget extends StatefulWidget {
  final AppLocalizations l10n;
  final int unreadCount;
  final VoidCallback onBellTap;

  const _ScheduleWidget({
    super.key, 
    required this.l10n,
    required this.unreadCount,
    required this.onBellTap,
  });

  @override
  State<_ScheduleWidget> createState() => _ScheduleWidgetState();
}

class _ScheduleWidgetState extends State<_ScheduleWidget> {
  Map<int, List<Map<String, dynamic>?>> _weeklyEvents = {};
  Map<int, Color> _weeklyShiftColors = {};
  List<Map<String, dynamic>> _activeShiftDefinitions = []; 
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    await _fetchAllWeeklyData();
  }

  Future<void> _fetchAllWeeklyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId'); 
      final userId = supabase.auth.currentUser?.id;
      
      if (shopId == null || userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final now = DateTime.now();
      final int currentDartWeekday = now.weekday; 
      final int daysToSubtract = (currentDartWeekday == 7) ? 0 : currentDartWeekday;
      final DateTime startOfWeek = now.subtract(Duration(days: daysToSubtract)); 
      final DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));        
      
      final String startStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
      final String endStr = DateFormat('yyyy-MM-dd').format(endOfWeek);

      final results = await Future.wait([
        _fetchShiftColorsAndDefinitions(supabase, shopId, userId, startStr, endStr),
        _fetchCalendarEvents(supabase, shopId, userId, startOfWeek, endOfWeek),
      ]);

      if (mounted) {
        setState(() { 
          _weeklyShiftColors = results[0] as Map<int, Color>;
          _weeklyEvents = results[1] as Map<int, List<Map<String, dynamic>?>>;
          _isLoading = false; 
        });
      }
    } catch (e) {
      debugPrint('Error fetching weekly data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<int, Color>> _fetchShiftColorsAndDefinitions(
      SupabaseClient supabase, String shopId, String userId, String startStr, String endStr) async {
    final Map<int, Color> resultMap = {};
    for (int i = 0; i <= 6; i++) resultMap[i] = Colors.transparent;

    final settingsRes = await supabase
        .from('shop_shift_settings')
        .select('id, shift_name, start_time, end_time, color') 
        .eq('shop_id', shopId);
        
    final Map<String, Map<String, dynamic>> shiftConfigMap = {};
    for (var item in settingsRes) {
      final String? id = item['id']?.toString();
      if (id == null) continue;

      shiftConfigMap[id] = {
        'color': _hexToColor(item['color'] ?? '#808080'),
        'name': item['shift_name'] ?? 'Unknown',
        'start': item['start_time']?.toString().substring(0, 5) ?? '',
        'end': item['end_time']?.toString().substring(0, 5) ?? '',
      };
    }

    final response = await supabase.from('schedule_assignments')
        .select('shift_date, shift_type_id')
        .eq('shop_id', shopId)
        .eq('employee_id', userId)
        .gte('shift_date', startStr)
        .lte('shift_date', endStr);

    final Set<String> todayShiftIds = {};
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var item in response) {
      final String? shiftDateStr = item['shift_date']?.toString();
      final String? shiftTypeId = item['shift_type_id']?.toString();

      if (shiftDateStr == null || shiftTypeId == null) continue;

      final shiftDate = DateTime.parse(shiftDateStr);
      int weekdayIndex = shiftDate.weekday == 7 ? 0 : shiftDate.weekday;
      
      if (shiftConfigMap.containsKey(shiftTypeId)) {
        resultMap[weekdayIndex] = shiftConfigMap[shiftTypeId]!['color'];
        if (shiftDateStr == todayStr) {
          todayShiftIds.add(shiftTypeId);
        }
      }
    }

    final List<Map<String, dynamic>> definitions = [];
    for (var id in todayShiftIds) {
      if (shiftConfigMap.containsKey(id)) {
        definitions.add(shiftConfigMap[id]!);
      }
    }
    definitions.sort((a, b) => a['start'].compareTo(b['start']));

    if (mounted) {
      setState(() {
        _activeShiftDefinitions = definitions;
      });
    }

    return resultMap;
  }

  // 🔥 核心演算法：將本週所有事件「展開」並「排序」
  Future<Map<int, List<Map<String, dynamic>?>>> _fetchCalendarEvents(
      SupabaseClient supabase, String shopId, String userId, DateTime startOfWeek, DateTime endOfWeek) async {
    
    final Map<int, List<Map<String, dynamic>?>> resultMap = {};
    for (int i = 0; i <= 6; i++) resultMap[i] = [];

    final endIso = endOfWeek.toUtc().toIso8601String();

    final response = await supabase.from('calendar_events')
        .select('title, start_time, end_time, color, all_day, repeat, recurrence_end_date, recurrence_rule, related_user_ids, user_id, id, calendar_groups(name, user_id, visible_user_ids)')
        .eq('shop_id', shopId)
        .lte('start_time', endIso); 

    List<_HomeVisualEvent> visualEvents = [];

    for (var event in response) {
      final group = event['calendar_groups'];
      if (group == null) continue;

      final String groupName = group['name'] ?? '';
      final String groupOwnerId = group['user_id']?.toString() ?? '';
      final List<dynamic> groupMembers = (group['visible_user_ids'] is List) 
          ? group['visible_user_ids'] 
          : [];
      
      bool amIMember = (groupOwnerId == userId) || groupMembers.contains(userId);
      bool isPersonalGroup = (groupName == '個人' || groupName == 'Personal');

      if (isPersonalGroup) {
        if (groupOwnerId != userId) continue; 
      } else {
        if (!amIMember) continue; 
      }

      final String? eventId = event['id']?.toString() ?? event.hashCode.toString();
      final DateTime rawStart = DateTime.parse(event['start_time']).toLocal();
      DateTime rawEnd = DateTime.parse(event['end_time']).toLocal();
      final String repeat = event['repeat'] ?? 'none';
      final bool isAllDay = event['all_day'] == true;

      if (isAllDay) {
         rawEnd = DateTime(rawEnd.year, rawEnd.month, rawEnd.day, 23, 59, 59);
      }

      RecurrenceRule? rule;
      bool isRepeating = false;
      if (event['recurrence_rule'] != null) {
        try {
          rule = RecurrenceRule.fromJson(event['recurrence_rule']);
          isRepeating = true;
        } catch (_) {}
      } else if (repeat != 'none') {
        isRepeating = true;
      }

      Duration duration;
      if (!isRepeating) {
        duration = rawEnd.difference(rawStart);
      } else {
        DateTime effectiveEnd = DateTime(
          rawStart.year, rawStart.month, rawStart.day,
          rawEnd.hour, rawEnd.minute, rawEnd.second
        );
        if (effectiveEnd.isBefore(rawStart)) {
          effectiveEnd = effectiveEnd.add(const Duration(days: 1));
        }
        duration = effectiveEnd.difference(rawStart);
        if (duration.inHours > 24) duration = const Duration(hours: 24);
      }

      final String? recurrenceEndIso = event['recurrence_end_date'];
      final DateTime? recurrenceEnd = recurrenceEndIso != null 
          ? DateTime.parse(recurrenceEndIso).toLocal() 
          : null;

      for (int i = 0; i <= 6; i++) {
        final DateTime checkDay = startOfWeek.add(Duration(days: i));
        final DateTime dayStart = DateTime(checkDay.year, checkDay.month, checkDay.day);
        final DateTime dayEnd = dayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

        bool shouldShow = false;
        DateTime displayStart = rawStart;
        DateTime displayEnd = rawEnd;

        if (!isRepeating) {
          if (!rawStart.isAfter(dayEnd) && !rawEnd.isBefore(dayStart)) {
            shouldShow = true;
            displayStart = rawStart;
            displayEnd = rawEnd;
          }
        } else {
          if (recurrenceEnd != null) {
             final DateTime checkSimple = DateTime(checkDay.year, checkDay.month, checkDay.day);
             final DateTime endSimple = DateTime(recurrenceEnd.year, recurrenceEnd.month, recurrenceEnd.day);
             if (checkSimple.isAfter(endSimple)) continue;
          }
          if (checkDay.isBefore(DateTime(rawStart.year, rawStart.month, rawStart.day))) continue;

          bool matches = false;
          if (rule != null) {
            matches = rule.matches(checkDay, rawStart);
          } else {
            switch (repeat) {
              case 'daily': matches = true; break;
              case 'weekly': matches = rawStart.weekday == checkDay.weekday; break;
              case 'monthly': matches = rawStart.day == checkDay.day; break;
              case 'yearly': matches = rawStart.day == checkDay.day && rawStart.month == checkDay.month; break;
            }
          }

          if (matches) {
            shouldShow = true;
            displayStart = DateTime(
              checkDay.year, checkDay.month, checkDay.day,
              rawStart.hour, rawStart.minute, rawStart.second
            );
            displayEnd = displayStart.add(duration);
          }
        }

        if (shouldShow) {
           visualEvents.add(_HomeVisualEvent(
             originalEvent: event,
             dayIndex: i, 
             start: displayStart,
             end: displayEnd,
             eventId: eventId!,
           ));
        }
      }
    }

    visualEvents.sort((a, b) {
      int cmpStart = a.start.compareTo(b.start);
      if (cmpStart != 0) return cmpStart;
      final durationA = a.end.difference(a.start);
      final durationB = b.end.difference(b.start);
      return durationB.compareTo(durationA);
    });

    // 🔥 修正點：加入「重力」與「連續性」判斷
    Map<int, List<bool>> weeklyOccupancy = {};
    for(int i=0; i<=6; i++) weeklyOccupancy[i] = [];
    
    // 記錄每個事件被分配到的行數
    Map<String, int> eventRowMap = {};
    // 記錄每個事件「最後一次」出現在哪一天 (用來判斷是否連續)
    Map<String, int> lastSeenDayMap = {};

    for (var vEvent in visualEvents) {
      int assignedRow = -1;

      // 只有當昨天也有這個事件時 (連續)，才嘗試鎖定行數
      if (eventRowMap.containsKey(vEvent.eventId)) {
        // 檢查是否連續 (昨天的 index 應該是今天 index - 1)
        int lastDay = lastSeenDayMap[vEvent.eventId] ?? -999;
        
        if (lastDay == vEvent.dayIndex - 1) {
          // 是連續的 -> 嘗試沿用行數 (為了好看的長條圖)
          int preferredRow = eventRowMap[vEvent.eventId]!;
          if (_isRowAvailable(weeklyOccupancy, vEvent.dayIndex, preferredRow)) {
            assignedRow = preferredRow;
          }
        }
      }

      // 如果沒有連續，或者原行數被佔用了 -> 重新找空位 (Gravity / 往上貼齊)
      if (assignedRow == -1) {
        int tryRow = 0;
        while (true) {
          if (_isRowAvailable(weeklyOccupancy, vEvent.dayIndex, tryRow)) {
            assignedRow = tryRow;
            break;
          }
          tryRow++;
        }
      }

      _markRowOccupied(weeklyOccupancy, vEvent.dayIndex, assignedRow);
      
      // 更新記錄
      eventRowMap[vEvent.eventId] = assignedRow;
      lastSeenDayMap[vEvent.eventId] = vEvent.dayIndex;
      
      while (resultMap[vEvent.dayIndex]!.length <= assignedRow) {
        resultMap[vEvent.dayIndex]!.add(null);
      }
      
      resultMap[vEvent.dayIndex]![assignedRow] = {
        'id': vEvent.eventId,
        'title': vEvent.originalEvent['title'] ?? 'Event',
        'color': _hexToColor(vEvent.originalEvent['color'] ?? '#0A84FF'),
        'raw_start': vEvent.start,
        'raw_end': vEvent.end,
      };
    }

    return resultMap;
  }

  bool _isRowAvailable(Map<int, List<bool>> occupancy, int dayIndex, int row) {
    List<bool> rows = occupancy[dayIndex]!;
    if (row >= rows.length) return true; 
    return !rows[row]; 
  }

  void _markRowOccupied(Map<int, List<bool>> occupancy, int dayIndex, int row) {
    List<bool> rows = occupancy[dayIndex]!;
    while (rows.length <= row) {
      rows.add(false); 
    }
    rows[row] = true; 
  }

  Color _hexToColor(String hex) {
    String cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLight = Theme.of(context).brightness == Brightness.light;
    const double widgetHeight = 160.0; 

    return GestureDetector(
      onTap: () async {
        await context.push('/personalSchedule'); 
        if (mounted) refresh();
      },
      child: Container(
        height: widgetHeight,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          // ✅ [Modified] Use Theme Card Color (Matches Sage #537B6A)
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isLight ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ] : null,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 32, // Slightly taller for large header
              child: Row(
                children: [
                  Text(
                    DateFormat('MMMM').format(now),
                    style: TextStyle(
                      // [Modified] Use FAFCFA for Sage/Standard text as requested
                      color: isLight ? Colors.black : const Color(0xFFFAFCFA), 
                      fontSize: 22, 
                      fontWeight: FontWeight.w700, 
                      fontFamily: 'SF Pro'
                    ),
                  ),
                  const Spacer(), // Ensure Month is left, others right
                  if (!isLight) ...[
                  Expanded(
                    child: _isLoading 
                      ? const SizedBox.shrink() 
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _activeShiftDefinitions.length,
                          physics: const BouncingScrollPhysics(),
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final def = _activeShiftDefinitions[index];
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: def['color'],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${def['name']} ${def['start']}-${def['end']}",
                                  style: const TextStyle(
                                    // [Modified] Use FAFCFA for shift text too
                                    color: Color(0xFFFAFCFA),
                                    fontSize: 9, 
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  ),
                  const SizedBox(width: 8),
                  ], // Close spread

                  // Reverted to Bell Icon for both modes as requested
                  GestureDetector(
                    onTap: widget.onBellTap,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(CupertinoIcons.bell_fill, color: isLight ? Colors.black : const Color(0xFFFAFCFA), size: 20), 
                        if (widget.unreadCount > 0)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),

            Expanded(
              child: _isLoading
                  ? Center(child: CupertinoActivityIndicator(color: isLight ? Colors.black : const Color(0xFFFAFCFA)))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (colIndex) {
                        final DateTime dayDate = DateTime.now().subtract(Duration(days: (DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday))).add(Duration(days: colIndex));
                        final bool isToday = dayDate.day == now.day && dayDate.month == now.month;
                        final String dayLabel = DateFormat('E').format(dayDate).substring(0, 3).toUpperCase();
                        
                        final Color shiftColor = _weeklyShiftColors[colIndex] ?? Colors.transparent;
                        final bool hasShift = shiftColor != Colors.transparent;
                        
                        final bool isBgLight = hasShift && ThemeData.estimateBrightnessForColor(shiftColor) == Brightness.light;
                        
                        // [Modified] Weekend Colors (Blue/Red)
                        Color baseTextColor = (isLight ? Colors.black : const Color(0xFFFAFCFA));
                        if (!hasShift && !isToday) {
                          if (dayDate.weekday == DateTime.saturday) baseTextColor = const Color(0xFF0044CC);
                          if (dayDate.weekday == DateTime.sunday) baseTextColor = const Color(0xFFCC0000);
                        }

                        final Color dateTextColor = hasShift 
                            ? (isBgLight ? Colors.black : const Color(0xFFFAFCFA)) 
                            : (isToday 
                                ? Colors.white // [Modified] Force White on Today (Red Bg) regardless of theme
                                : baseTextColor);
                        
                        final List<Map<String, dynamic>?> daySlots = _weeklyEvents[colIndex] ?? [];
                        const int maxVisibleRows = 5;

                        return Expanded(
                          child: Column(
                            children: [
                              Text(dayLabel, style: TextStyle(color: isLight ? Colors.grey.shade500 : const Color(0xFFFAFCFA).withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w600)),
                              
                              const SizedBox(height: 2),
                              
                              Container(
                                width: 24, height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: hasShift ? shiftColor : (isToday ? Colors.red : Colors.transparent), 
                                  shape: BoxShape.circle,
                                  border: null,
                                ),
                                child: Text(
                                  dayDate.day.toString(),
                                  style: TextStyle(
                                    color: dateTextColor,
                                    fontSize: 13, 
                                    fontWeight: FontWeight.w700
                                  )
                                ),
                              ),
                              
                              const SizedBox(height: 2),
                              
                              Expanded(
                                child: ListView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  clipBehavior: Clip.none,
                                  itemCount: daySlots.length > maxVisibleRows ? maxVisibleRows : daySlots.length,
                                  padding: EdgeInsets.zero,
                                  itemBuilder: (context, rowIndex) {
                                    if (rowIndex == maxVisibleRows - 1 && daySlots.length > maxVisibleRows) {
                                      int hiddenRealEvents = 0;
                                      for (int k = rowIndex; k < daySlots.length; k++) {
                                        if (daySlots[k] != null) hiddenRealEvents++;
                                      }

                                      if (hiddenRealEvents > 0) {
                                        return Container(
                                          height: 13, 
                                          margin: const EdgeInsets.only(bottom: 2),
                                          padding: EdgeInsets.zero,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '+$hiddenRealEvents',
                                            style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, height: 1.1),
                                          ),
                                        );
                                      }
                                    }

                                    final event = daySlots[rowIndex];
                                    if (event == null) return const SizedBox(height: 15); 

                                    final Color bgCol = event['color'];
                                    final bool isLight = ThemeData.estimateBrightnessForColor(bgCol) == Brightness.light;
                                    final String? eventId = event['id']?.toString();

                                    bool connectsLeft = false;
                                    if (colIndex > 0) {
                                      final List<Map<String, dynamic>?> prevDaySlots = _weeklyEvents[colIndex - 1] ?? [];
                                      if (rowIndex < prevDaySlots.length) {
                                        final prevEvent = prevDaySlots[rowIndex];
                                        if (prevEvent != null && prevEvent['id']?.toString() == eventId) {
                                          connectsLeft = true;
                                        }
                                      }
                                    }

                                    bool connectsRight = false;
                                    if (colIndex < 6) {
                                      final List<Map<String, dynamic>?> nextDaySlots = _weeklyEvents[colIndex + 1] ?? [];
                                      if (rowIndex < nextDaySlots.length) {
                                        final nextEvent = nextDaySlots[rowIndex];
                                        if (nextEvent != null && nextEvent['id']?.toString() == eventId) {
                                          connectsRight = true;
                                        }
                                      }
                                    }

                                    bool showTitle = false;
                                    bool isEvenSpan = false;
                                    
                                    if (eventId != null) {
                                      int leftSpan = 0;
                                      for (int k = colIndex - 1; k >= 0; k--) {
                                        final slots = _weeklyEvents[k] ?? [];
                                        if (rowIndex < slots.length && slots[rowIndex]?['id']?.toString() == eventId) {
                                          leftSpan++;
                                        } else { break; }
                                      }

                                      int rightSpan = 0;
                                      for (int k = colIndex + 1; k <= 6; k++) {
                                        final slots = _weeklyEvents[k] ?? [];
                                        if (rowIndex < slots.length && slots[rowIndex]?['id']?.toString() == eventId) {
                                          rightSpan++;
                                        } else { break; }
                                      }

                                      int totalSpan = leftSpan + 1 + rightSpan;
                                      isEvenSpan = totalSpan % 2 == 0;
                                      
                                      int middleIndex = isEvenSpan ? (totalSpan ~/ 2) : ((totalSpan - 1) ~/ 2);
                                      if (leftSpan == middleIndex) {
                                        showTitle = true;
                                      }
                                    }

                                    final BorderRadius borderRadius = BorderRadius.horizontal(
                                      left: connectsLeft ? Radius.zero : const Radius.circular(4),
                                      right: connectsRight ? Radius.zero : const Radius.circular(4),
                                    );

                                    final EdgeInsets margin = EdgeInsets.only(
                                      bottom: 2,
                                      left: connectsLeft ? 0 : 2,
                                      right: connectsRight ? 0 : 2,
                                    );

                                    BoxBorder? border;
                                    if (connectsLeft || connectsRight) {
                                      border = Border(
                                        left: connectsLeft ? BorderSide(color: bgCol, width: 1.0) : BorderSide.none,
                                        right: connectsRight ? BorderSide(color: bgCol, width: 1.0) : BorderSide.none,
                                      );
                                    }

                                    return Container(
                                      height: 13, 
                                      margin: margin,
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(
                                        color: bgCol, 
                                        borderRadius: borderRadius,
                                        border: border,
                                      ),
                                      alignment: Alignment.center,
                                      child: showTitle 
                                        ? LayoutBuilder(
                                            builder: (context, constraints) {
                                              final double offsetX = isEvenSpan ? -(constraints.maxWidth / 2) : 0;
                                              return Transform.translate(
                                                offset: Offset(offsetX, 0),
                                                child: Text(
                                                  event['title'] ?? '', 
                                                  maxLines: 1, 
                                                  overflow: TextOverflow.ellipsis, 
                                                  style: TextStyle(
                                                    color: Colors.white, 
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.1,
                                                  )
                                                ),
                                              );
                                            },
                                          )
                                        : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton {
  final String id;
  final String label;
  final IconData icon;
  final String? route;
  final String? permissionKey;

  const _HomeButton({
    required this.id, 
    required this.label, 
    required this.icon, 
    required this.route,
    this.permissionKey,
  });
}

class _LiquidGlassIcon extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool isEditing;

  const _LiquidGlassIcon({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.onLongPress,
    required this.isEditing,
  });

  @override
  State<_LiquidGlassIcon> createState() => _LiquidGlassIconState();
}

class _LiquidGlassIconState extends State<_LiquidGlassIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 140),
      vsync: this,
    );
    _animation = Tween<double>(begin: -0.05, end: 0.05).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isEditing) _startShaking();
  }

  @override
  void didUpdateWidget(_LiquidGlassIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing != oldWidget.isEditing) {
      if (widget.isEditing) {
        _startShaking();
      } else {
        _stopShaking();
      }
    }
  }

  void _startShaking() {
    _controller.repeat(reverse: true);
  }

  void _stopShaking() {
    _controller.stop();
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double iconSize = 62.0; 
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: widget.isEditing ? null : widget.onPressed,
      onLongPress: widget.isEditing ? null : widget.onLongPress, 
      
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: widget.isEditing ? _animation.value : 0,
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0), // iOS rounded square
                  // ✅ [Modified] Use Theme Card Color for base
                  color: Theme.of(context).cardColor,
                  // ✅ [Modified] Flat Color Block (No Gradient)
                  gradient: null,
                  boxShadow: isLight ? [
                     BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ] : [], // ✅ [Modified] No Shadow for Flat Look

                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    // ✅ [Modified] Always use primary color (Sage=Green, Dark=White, Light=Black)
                    color: Theme.of(context).colorScheme.primary,
                    size: 30.0,
                  ),
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  // ✅ [Modified] Always use onSurface color (Sage=Light, Dark=White, Light=Black)
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: isLight ? null : [
                    Shadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeVisualEvent {
  final Map<String, dynamic> originalEvent;
  final int dayIndex;
  final DateTime start;
  final DateTime end;
  final String eventId;

  _HomeVisualEvent({
    required this.originalEvent,
    required this.dayIndex,
    required this.start,
    required this.end,
    required this.eventId,
  });
}
class _DarkStyleDialog extends StatelessWidget {
  final String title;
  final Widget contentWidget;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String? confirmText;
  final String? cancelText;

  const _DarkStyleDialog({
    required this.title,
    required this.contentWidget,
    required this.onCancel,
    required this.onConfirm,
    this.confirmText,
    this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, 
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            contentWidget,
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: Text(cancelText ?? "取消", style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 16)),
                ),
                SizedBox(
                  width: 120, height: 40,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface,
                      foregroundColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(confirmText ?? "確認", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
