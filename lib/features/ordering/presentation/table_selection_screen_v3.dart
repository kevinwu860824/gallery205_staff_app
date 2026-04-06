// lib/features/ordering/presentation/table_selection_screen_v2.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:gallery205_staff_app/core/services/hub_client.dart';
import 'package:gallery205_staff_app/core/services/hub_exceptions.dart';
import 'package:gallery205_staff_app/core/services/local_db_service.dart';

import '../domain/repositories/ordering_repository.dart';
import '../domain/repositories/session_repository.dart'; // NEW
import '../data/repositories/ordering_repository_impl.dart';
import '../data/datasources/ordering_remote_data_source.dart';
import '../domain/models/table_model.dart';
import '../domain/entities/order_item.dart';
import '../../../core/services/site_verification_service.dart'; // [修正]
import 'print_bill_screen.dart';
import 'payment_screen_v2.dart';
import 'split_bill_screen.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'providers/ordering_providers.dart';
import 'package:gallery205_staff_app/features/ordering/domain/ordering_constants.dart';
import 'package:gallery205_staff_app/core/services/invoice_service.dart';
import 'package:gallery205_staff_app/core/services/printer_service.dart';
import 'package:gallery205_staff_app/core/models/tax_profile.dart';
import 'package:gallery205_staff_app/features/ordering/domain/logic/order_calculator.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_context.dart';

// -------------------------------------------------------------------
// 1. 樣式與色盤定義
// -------------------------------------------------------------------

enum _OccupiedSubMode {
  main,
  updatePax,
  editNote,
  moveTable,
  mergeTable,
  tableInfo,
  printBill,
  payment,
  splitBill
}

class TableSelectionScreenV3 extends ConsumerStatefulWidget {
  const TableSelectionScreenV3({super.key});

  @override
  ConsumerState<TableSelectionScreenV3> createState() =>
      _TableSelectionScreenV3State();
}

class _TableSelectionScreenV3State extends ConsumerState<TableSelectionScreenV3>
    with SingleTickerProviderStateMixin {
  OrderingRepository? _orderingRepo;
  SessionRepository? _sessionRepo;

  final TransformationController _mapTransformController =
      TransformationController();
  bool _mapTransformInitialized = false;

  List<AreaModel> areas = [];
  String? selectedAreaId;
  List<TableModel> tables = [];
  bool isLoading = true;

  final Set<String> _selectedEmptyTables = {};

  bool _isDialogOpen = false;
  bool _isShiftClosed = false;

  // iPad left-panel selection state
  TableModel? _selectedOccupiedTable;
  String? _selectedOccupiedOrderGroupId;
  int _panelAdults = 1;
  int _panelChildren = 0;

  // iPad left-panel sub-modes
  _OccupiedSubMode _occupiedSubMode = _OccupiedSubMode.main;
  int _updatePaxAdults = 0;
  int _updatePaxChildren = 0;
  bool _updatePaxLoading = false;
  final TextEditingController _noteController = TextEditingController();
  bool _noteSaving = false;
  String _selectedOrderNote = '';
  Set<String> _moveTargetTables = {};

  // tableInfo sub-mode state
  bool _tableInfoLoading = false;
  Map<String, dynamic>? _tableInfoData;
  List<Map<String, dynamic>> _tableInfoItems = [];
  final Map<String, double> _tableInfoSwipeOffsets = {};
  double _tableInfoTotal = 0.0;

  // merge/unmerge sub-mode state
  Set<String> _pendingMergeGroups = {};
  Set<String> _pendingUnmergeGroups = {};
  Set<String> _mergedChildGroups = {};
  Set<String> _busyGroupIds =
      {}; // all group IDs involved in ANY merge (host or child)
  bool _mergeLoading = false;

  List<String> get _sameGroupTables {
    if (_selectedOccupiedTable == null || _selectedOccupiedOrderGroupId == null)
      return [];
    final result = tables
        .where((t) =>
            t.activeOrderGroupIds.contains(_selectedOccupiedOrderGroupId))
        .map((t) => t.tableName)
        .toList()
      ..sort();
    if (result.isEmpty) result.add(_selectedOccupiedTable!.tableName);
    return result;
  }

  int unsyncedCount = 0;
  int failedPrintCount = 0;
  bool _autoShowReprintChecked = false; // 進入頁面時只自動跳一次
  bool _isHubOfflineDialogShowing = false;

  // [新增] 場域驗證狀態
  SiteVerificationResult? _siteResult;
  bool _isVerifyingSite = false;

  RealtimeChannel? _subscription;
  StreamSubscription? _printTaskSubscription;
  StreamSubscription? _wsTableSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _verifySite().then((_) {
      _checkShiftStatus().then((_) => _initData());
    });
    _subscribeToRealtime();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _orderingRepo?.cleanupStalePendingItems();
      _checkFailedPrints();
      _checkSyncStatus();
      if (selectedAreaId != null) _silentRefreshTables();
      // 定時檢查 hub 是否離線，若離線且 dialog 未顯示則跳出
      _checkHubOfflineDialog();
    });
  }

  bool _hubListenerRegistered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hubListenerRegistered) {
      _hubListenerRegistered = true;
      ref.listenManual(hubAvailableProvider, (previous, next) {
        if (previous == true && next == false) {
          _checkHubOfflineDialog();
        }
      });
    }
    if (!_mapTransformInitialized) {
      _mapTransformInitialized = true;
      final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
      if (isTablet) {
        _mapTransformController.value = Matrix4.translationValues(0, -25, 0);
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _printTaskSubscription?.cancel();
    _wsTableSubscription?.cancel();
    _noteController.dispose();
    _mapTransformController.dispose();
    if (_subscription != null) {
      Supabase.instance.client.removeChannel(_subscription!);
      _subscription = null;
    }
    super.dispose();
  }

  Future<void> _subscribeToRealtime() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final hubClient = HubClient();

    if (hubClient.isHubAvailable) {
      // ── Hub 模式：訂閱 Hub WebSocket 推播 ──────────────────
      _wsTableSubscription = hubClient.tableUpdates.listen((data) {
        if (mounted && selectedAreaId != null) {
          _loadTablesForArea(selectedAreaId!);
        }
      });
    } else {
      // ── Fallback：Supabase Realtime（原有邏輯）──────────────
      final client = Supabase.instance.client;
      _subscription = client
          .channel('public:order_groups:$shopId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'order_groups',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'shop_id',
              value: shopId,
            ),
            callback: (payload) {
              debugPrint('Realtime update received: ${payload.eventType}');
              if (selectedAreaId != null && mounted) {
                _loadTablesForArea(selectedAreaId!);
              }
            },
          )
          .subscribe();
    }
  }

  Future<void> _ensureRepository() async {
    if (_orderingRepo == null || _sessionRepo == null) {
      final prefs = await SharedPreferences.getInstance();
      final client = Supabase.instance.client;
      final dataSource = OrderingRemoteDataSourceImpl(client);
      final impl = OrderingRepositoryImpl(dataSource, prefs, null, null, HubClient());
      _orderingRepo = impl;
      _sessionRepo = impl;
    }

    // Always ensure listener is active
    if (_printTaskSubscription == null) {
      _printTaskSubscription = _orderingRepo!.onPrintTaskUpdate.listen((_) {
        _checkFailedPrints();
      });
      // Initial check logic moved here or called by caller?
      // Caller _initData calls it via _checkSyncStatus usually? No.
      // Let's explicitly check once we have a listener.
      _checkFailedPrints();
    }
  }

  Future<void> _checkShiftStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    try {
      final res = await Supabase.instance.client.rpc(
          'rpc_get_current_cash_status',
          params: {'p_shop_id': shopId}).single();
      if (res['status'] != 'OPEN') {
        if (mounted) {
          setState(() => _isShiftClosed = true);
          _showShiftClosedDialog();
        }
      }
    } catch (e) {
      debugPrint("Check shift status failed: $e");
    }
  }

  Future<void> _checkSyncStatus() async {
    _ensureRepository();
    if (_orderingRepo != null) {
      final count = await _orderingRepo!.getUnsyncedOrdersCount();
      if (mounted && count != unsyncedCount) {
        setState(() => unsyncedCount = count);
      }
      _checkFailedPrints();
    }
  }

  Future<void> _checkFailedPrints({bool autoShow = false}) async {
    if (_orderingRepo != null) {
      try {
        final items = await _orderingRepo!.fetchFailedPrintItems();
        final pendingReceipts = await _orderingRepo!.getPendingReceiptPrints();
        if (!mounted) return;
        final total = items.length + pendingReceipts.length;
        if (total != failedPrintCount) {
          setState(() => failedPrintCount = total);
        }
        if (autoShow && !_autoShowReprintChecked && total > 0) {
          _autoShowReprintChecked = true;
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) _showFailedPrintsDialog();
        } else if (autoShow) {
          _autoShowReprintChecked = true;
        }
      } catch (_) {}
    }
  }

  Future<void> _showUnsyncedDialog() async {
    _ensureRepository();
    if (_orderingRepo == null) return;
    await showDialog(
      context: context,
      builder: (_) => _UnsyncedOrdersDialog(
        repository: _orderingRepo!,
        onSyncComplete: () => _checkSyncStatus(),
      ),
    );
    await _checkSyncStatus();
  }

  void _showShiftClosedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: _DarkStyleDialog(
          title: "尚未開班",
          contentWidget: const Text("請先至【關帳】進行開班，\n才能開始進行點餐作業。",
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center),
          onConfirm: () => context.go('/cashSettlement'),
          confirmText: "前往開班",
          onCancel: () => context.go('/home'),
          cancelText: "返回首頁",
        ),
      ),
    );
  }

  Future<void> _initData() async {
    setState(() => isLoading = true);
    await _ensureRepository();

    try {
      final fetchedAreas = await _sessionRepo!.fetchAreas();
      if (fetchedAreas.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final lastArea = prefs.getString('last_selected_area');

        final initialArea = fetchedAreas.any((a) => a.id == lastArea)
            ? lastArea
            : fetchedAreas.first.id;

        areas = fetchedAreas;
        selectedAreaId = initialArea;
        await _loadTablesForArea(initialArea!);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
    await _checkFailedPrints(autoShow: true);
    await _checkHubOfflineDialog();
  }

  Future<void> _checkHubOfflineDialog() async {
    if (!mounted) return;
    if (_isHubOfflineDialogShowing) return;
    final prefs = await SharedPreferences.getInstance();
    final isHubDevice = prefs.getBool('isHubDevice') ?? false;
    if (isHubDevice) return;
    if (!HubClient().hasHubIpConfigured) return;
    if (HubClient().isHubAvailable) return;

    if (!mounted) return;
    _isHubOfflineDialogShowing = true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _HubOfflineDialog(
        onReconnected: () {
          if (mounted) {
            ref.read(hubAvailableProvider.notifier).state = true;
            _silentRefreshTables();
          }
        },
        onDismissed: () {
          if (mounted) context.pop();
        },
      ),
    );
    _isHubOfflineDialogShowing = false;
  }

  Future<void> _loadTablesForArea(String areaId) async {
    setState(() => isLoading = true);
    await _silentRefreshTables(areaIdOverride: areaId);
    if (mounted)
      setState(() {
        selectedAreaId = areaId;
        isLoading = false;
      });
  }

  Future<void> _silentRefreshTables({String? areaIdOverride}) async {
    final targetArea = areaIdOverride ?? selectedAreaId;
    if (targetArea == null) return;

    // Hub 已設定但目前離線：保留現有桌位顯示，不清空
    final prefs2 = await SharedPreferences.getInstance();
    final isHubDevice2 = prefs2.getBool('isHubDevice') ?? false;
    if (!isHubDevice2 && HubClient().hasHubIpConfigured && !HubClient().isHubAvailable) return;

    await _ensureRepository();
    // Do NOT clear _selectedEmptyTables on silent refresh to avoid losing selection state while user is active
    // Also do NOT clear if a dialog (e.g. pax input) is currently open — prevents race condition
    // where a Realtime event (from another device's action) wipes the selected tables mid-flow.
    if (areaIdOverride != null && !_isDialogOpen) _selectedEmptyTables.clear();

    try {
      final fetchedTables = await _sessionRepo!.fetchTablesInArea(targetArea);
      if (areaIdOverride != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_selected_area', areaIdOverride);
      }

      if (mounted) {
        setState(() {
          tables = fetchedTables;
        });
      }
    } catch (_) {}
  }

  // ----------------------------------------------------------------
  // 互動邏輯
  // ----------------------------------------------------------------

  void _onTableTap(TableModel table) async {
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    if (table.status == TableStatus.occupied) {
      final List<String> sortedOrderIds = List.from(table.activeOrderGroupIds);
      if (sortedOrderIds.isEmpty && table.currentOrderGroupId != null) {
        sortedOrderIds.add(table.currentOrderGroupId!);
      }

      if (isTablet) {
        // iPad: intercept if in mergeTable mode
        if (_occupiedSubMode == _OccupiedSubMode.mergeTable) {
          // Case 1: already has merged children → panel shows unmerge only, ignore map taps
          if (_mergedChildGroups.isNotEmpty) return;

          // Case 2: merge selection mode
          final targetGroupId = table.currentOrderGroupId;
          if (targetGroupId == null) return;
          // Source table → ignore
          if (_sameGroupTables.contains(table.tableName)) return;
          // Target is involved in another merge → block
          if (_busyGroupIds.contains(targetGroupId)) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("此桌已有合併桌位，無法再次合併")),
            );
            return;
          }
          // Other independent occupied table → toggle merge
          setState(() {
            if (_pendingMergeGroups.contains(targetGroupId)) {
              _pendingMergeGroups.remove(targetGroupId);
            } else {
              _pendingMergeGroups.add(targetGroupId);
            }
          });
          return;
        }

        // iPad: intercept if in moveTable mode
        if (_occupiedSubMode == _OccupiedSubMode.moveTable) {
          // Tapping the source table → toggle in/out of target
          if (_sameGroupTables.contains(table.tableName)) {
            setState(() {
              if (_moveTargetTables.contains(table.tableName)) {
                _moveTargetTables.remove(table.tableName);
              } else {
                _moveTargetTables.add(table.tableName);
              }
            });
            return;
          }
          // Tapping a different occupied table → not allowed
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("此桌位已有人，請使用「併桌」功能")),
          );
          return;
        }

        // iPad: show in left panel
        // Toggle off if same table tapped again
        if (_selectedOccupiedTable?.tableName == table.tableName &&
            sortedOrderIds.length <= 1) {
          setState(() {
            _selectedOccupiedTable = null;
            _selectedOccupiedOrderGroupId = null;
            _moveTargetTables.clear();
            _pendingMergeGroups.clear();
            _pendingUnmergeGroups.clear();
            _mergedChildGroups.clear();
            _busyGroupIds.clear();
            _occupiedSubMode = _OccupiedSubMode.main;
          });
          return;
        }
        if (sortedOrderIds.length > 1) {
          final String? selectedId = await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text("請選擇要操作的訂單"),
              children: List.generate(sortedOrderIds.length, (index) {
                final id = sortedOrderIds[index];
                return SimpleDialogOption(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  onPressed: () => Navigator.pop(context, id),
                  child: Text("訂單 ${index + 1}",
                      style: const TextStyle(fontSize: 18)),
                );
              }),
            ),
          );
          if (selectedId != null) {
            setState(() {
              _selectedEmptyTables.clear();
              _selectedOccupiedTable = table;
              _selectedOccupiedOrderGroupId = selectedId;
              _occupiedSubMode = _OccupiedSubMode.main;
            });
            _loadSelectedOrderNote();
          }
        } else {
          setState(() {
            _selectedEmptyTables.clear();
            _selectedOccupiedTable = table;
            _selectedOccupiedOrderGroupId = sortedOrderIds.isNotEmpty
                ? sortedOrderIds.first
                : table.currentOrderGroupId;
            _occupiedSubMode = _OccupiedSubMode.main;
          });
          _loadSelectedOrderNote();
        }
      } else {
        // Phone: existing bottom sheet behavior
        if (sortedOrderIds.length > 1) {
          final String? selectedId = await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text("請選擇要操作的訂單"),
              children: List.generate(sortedOrderIds.length, (index) {
                final id = sortedOrderIds[index];
                return SimpleDialogOption(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  onPressed: () => Navigator.pop(context, id),
                  child: Text("訂單 ${index + 1}",
                      style: const TextStyle(fontSize: 18)),
                );
              }),
            ),
          );
          if (selectedId != null) {
            _showOccupiedActionMenu(table, overrideOrderGroupId: selectedId);
          }
        } else {
          _showOccupiedActionMenu(table);
        }
      }
    } else {
      // Empty table
      if (isTablet && _occupiedSubMode == _OccupiedSubMode.mergeTable) {
        // Case 1 (unmerge only): silent ignore
        if (_mergedChildGroups.isNotEmpty) return;
        // Case 2 (merge selection): empty tables not selectable
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("此桌為空桌，請使用「換桌」功能")),
        );
        return;
      }
      if (isTablet && _occupiedSubMode == _OccupiedSubMode.moveTable) {
        // In moveTable mode: toggle target selection
        setState(() {
          if (_moveTargetTables.contains(table.tableName)) {
            _moveTargetTables.remove(table.tableName);
          } else {
            _moveTargetTables.add(table.tableName);
          }
        });
        return;
      }
      // iPad: if an occupied table is already selected, deselect it and switch to empty table
      if (isTablet && _selectedOccupiedTable != null) {
        setState(() {
          _selectedOccupiedTable = null;
          _selectedOccupiedOrderGroupId = null;
          _occupiedSubMode = _OccupiedSubMode.main;
          _moveTargetTables.clear();
          _pendingMergeGroups.clear();
          _pendingUnmergeGroups.clear();
          _mergedChildGroups.clear();
          _busyGroupIds.clear();
          _selectedEmptyTables.clear();
          _selectedEmptyTables.add(table.tableName);
        });
        return;
      }

      setState(() {
        if (_selectedEmptyTables.contains(table.tableName)) {
          _selectedEmptyTables.remove(table.tableName);
        } else {
          _selectedEmptyTables.add(table.tableName);
        }
      });
    }
  }

  // 顯示「開桌」的人數輸入視窗
  Future<void> _showPaxDialog() async {
    setState(() => _isDialogOpen = true);

    // 預設 0 大 0 小
    final adultController = TextEditingController(text: '0');
    final childController = TextEditingController(text: '0');

    final result = await showDialog<Map<String, int>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return _DarkStyleDialog(
              title: '入座確認: ${_selectedEmptyTables.join(", ")}',
              contentWidget: Column(
                children: [
                  Text('請輸入用餐人數',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 24),

                  // 大人行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('大人',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.minus_circle_fill),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            iconSize: 32,
                            onPressed: () {
                              int val = int.tryParse(adultController.text) ?? 0;
                              if (val > 0)
                                adultController.text = (val - 1).toString();
                            },
                          ),
                          SizedBox(
                            width: 60,
                            child: CupertinoTextField(
                              controller: adultController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                              decoration: null,
                              padding: EdgeInsets.zero,
                              onChanged: (value) {
                                // 如果原本是 "0" 且輸入了一個字元變成兩位數，則直接取那個新的數字
                                if (value.length > 1 && value.contains('0')) {
                                  final newDigit = value.replaceFirst('0', '');
                                  if (newDigit.length == 1) {
                                    adultController.text = newDigit;
                                    adultController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: adultController.text.length),
                                    );
                                    return;
                                  }
                                }

                                // 原本的領頭 0 處理
                                if (value.length > 1 && value.startsWith('0')) {
                                  final n = int.tryParse(value);
                                  if (n != null) {
                                    adultController.text = n.toString();
                                    adultController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: adultController.text.length),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.plus_circle_fill),
                            color: Colors
                                .black, // Changed to black per user request
                            iconSize: 32,
                            onPressed: () {
                              int val = int.tryParse(adultController.text) ?? 0;
                              adultController.text = (val + 1).toString();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 小孩行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('小孩',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.minus_circle_fill),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            iconSize: 32,
                            onPressed: () {
                              int val = int.tryParse(childController.text) ?? 0;
                              if (val > 0)
                                childController.text = (val - 1).toString();
                            },
                          ),
                          SizedBox(
                            width: 60,
                            child: CupertinoTextField(
                              controller: childController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                              decoration: null,
                              padding: EdgeInsets.zero,
                              onChanged: (value) {
                                if (value.length > 1 && value.contains('0')) {
                                  final newDigit = value.replaceFirst('0', '');
                                  if (newDigit.length == 1) {
                                    childController.text = newDigit;
                                    childController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: childController.text.length),
                                    );
                                    return;
                                  }
                                }
                                if (value.length > 1 && value.startsWith('0')) {
                                  final n = int.tryParse(value);
                                  if (n != null) {
                                    childController.text = n.toString();
                                    childController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: childController.text.length),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.plus_circle_fill),
                            color: Colors
                                .black, // Changed to black per user request
                            iconSize: 32,
                            onPressed: () {
                              int val = int.tryParse(childController.text) ?? 0;
                              childController.text = (val + 1).toString();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                final adultPax = int.tryParse(adultController.text) ?? 0;
                final childPax = int.tryParse(childController.text) ?? 0;
                final totalPax = adultPax + childPax;
                if (totalPax > 0) {
                  Navigator.pop(context,
                      {'pax': totalPax, 'adult': adultPax, 'child': childPax});
                } else {
                  // Must have at least 1 person
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text("人數必須大於 0")));
                }
              },
            );
          },
        );
      },
    );

    if (result == null) {
      setState(() => _isDialogOpen = false);
    } else {
      await _createNewOrderGroup(
          result['pax']!, result['adult']!, result['child']!);
      setState(() => _isDialogOpen = false);
    }
  }

  Future<void> _onTableDoubleTap(TableModel table) async {
    // Only applies to Occupied Tables
    if (table.currentOrderGroupId == null || table.activeOrderGroupIds.isEmpty)
      return;

    final String orderId = table.currentOrderGroupId!;

    // Find all tables in this group
    final sameGroupTables = tables
        .where((t) => t.activeOrderGroupIds.contains(orderId))
        .map((t) => t.tableName)
        .toList();
    if (sameGroupTables.isEmpty) sameGroupTables.add(table.tableName);
    sameGroupTables.sort();

    // Navigate directly to Add Order screen
    await context.push('/orderV2', extra: {
      'tableNumbers': sameGroupTables,
      'orderGroupId': orderId,
      'isNewOrder': false,
    });

    // Refresh on return
    if (selectedAreaId != null && mounted) {
      await _loadTablesForArea(selectedAreaId!);
    }
  }

  Future<void> _createNewOrderGroup(int pax, int adult, int child) async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');

      if (shopId != null) {
        String? currentOpenId;
        try {
          final res = await Supabase.instance.client.rpc(
              'rpc_get_current_cash_status',
              params: {'p_shop_id': shopId}).maybeSingle();

          if (res != null && res['status'] == 'OPEN') {
            currentOpenId = res['open_id'] as String?;
          }
        } catch (e) {
          debugPrint("Error fetching open_id in TableSelection: $e");
        }

        // Capture Tax Snapshot
        Map<String, dynamic>? taxSnapshot;
        try {
          if (_orderingRepo == null) await _ensureRepository();
          final profile = await _orderingRepo!.getTaxProfile();
          taxSnapshot = {
            'rate': profile.rate,
            'is_tax_included': profile.isTaxIncluded,
            'shop_id': profile.shopId,
            'captured_at': DateTime.now().toIso8601String(),
          };
        } catch (e) {
          debugPrint(
              "Warning: Failed to capture tax snapshot in TableSelection screen: $e");
        }

        // 非 Hub 裝置且未設定 Hub IP → 不允許直接寫 Supabase，避免桌況不同步
        final isHubDevice = prefs.getBool('isHubDevice') ?? false;
        if (!isHubDevice && !HubClient().hasHubIpConfigured) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('找不到主機'),
              content: const Text(
                '店內目前沒有任何裝置開啟 Hub 主機模式。\n\n'
                '請先在主機 iPad 上開啟 App 並啟用 Hub 模式，再回來點餐。\n\n'
                '若已開啟主機，也可手動前往設定頁面取得主機 IP。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('知道了'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    context.push('/hubSettings');
                  },
                  child: const Text('前往設定'),
                ),
              ],
            ),
          );
          return;
        }

        // Hub 已設定但目前離線：擋住開桌，避免多台設備各自開同一桌
        if (!isHubDevice &&
            HubClient().hasHubIpConfigured &&
            !HubClient().isHubAvailable) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('主機目前離線'),
              content: const Text(
                '開桌需要透過主機協調，以避免多台設備重複開同一桌。\n\n'
                '請確認主機 iPad 已開啟 App 並保持在前台，連線後即可開桌。\n\n'
                '若已在點餐中的桌子需要加點，可直接進入該桌繼續點餐，訂單會暫存在本機，待主機恢復後自動同步。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
          return;
        }

        // 先選好顏色（Hub 和 Supabase 路徑共用）
        final colorIndex = await _pickColorIndex(shopId, _selectedEmptyTables.toList(), isHubDevice: isHubDevice);

        if (isHubDevice) {
          // Hub Device 本身：直接寫本地 SQLite
          final groupId = const Uuid().v4();
          String staffNameVal = '';
          try {
            final container = ProviderScope.containerOf(context);
            final user = container.read(authStateProvider).value;
            staffNameVal = (user?.name != null && user!.name.trim().isNotEmpty)
                ? user.name
                : (user?.email ?? '');
          } catch (_) {}

          await LocalDbService().insertPendingOrderGroup({
            'id': groupId,
            'shop_id': shopId,
            'table_names': jsonEncode(_selectedEmptyTables.toList()),
            'pax': pax,
            'pax_adult': adult,
            'pax_child': child,
            'staff_name': staffNameVal,
            'tax_snapshot':
                taxSnapshot != null ? jsonEncode(taxSnapshot) : null,
            'color_index': colorIndex,
            'status': OrderingConstants.orderStatusDining,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'open_id': currentOpenId,
            'is_synced': 0,
          });

          for (final tableName in _selectedEmptyTables) {
            await LocalDbService().upsertCachedTable({
              'table_name': tableName,
              'area_id': selectedAreaId,
              'status': 'occupied',
              'current_order_group_id': groupId,
              'color_index': colorIndex,
              'pax_adult': adult,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        } else if (HubClient().isHubAvailable) {
          // Hub Client：建立訂單在 Hub 本地，更新 cached_tables
          final groupId = const Uuid().v4();
          String staffNameVal = '';
          try {
            final container = ProviderScope.containerOf(context);
            final user = container.read(authStateProvider).value;
            staffNameVal = (user?.name != null && user!.name.trim().isNotEmpty)
                ? user.name
                : (user?.email ?? '');
          } catch (_) {}

          final orderResult = await HubClient().post('/orders', {
            'order_group': {
              'id': groupId,
              'shop_id': shopId,
              'table_names': jsonEncode(_selectedEmptyTables.toList()),
              'pax': pax,
              'pax_adult': adult,
              'pax_child': child,
              'staff_name': staffNameVal,
              'tax_snapshot':
                  taxSnapshot != null ? jsonEncode(taxSnapshot) : null,
              'color_index': colorIndex,
              'status': OrderingConstants.orderStatusDining,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'is_synced': 0,
            },
            'order_items': [],
          });
          debugPrint('🔍 Hub POST /orders result: $orderResult');
          if (orderResult == null) throw Exception('Hub POST /orders failed');

          for (final tableName in _selectedEmptyTables) {
            await HubClient().post('/tables/seat', {
              'table_name': tableName,
              'area_id': selectedAreaId,
              'order_group_id': groupId,
              'color_index': colorIndex,
              'pax_adult': adult,
            });
          }
        } else {
          // 非 Hub 模式：直接寫 Supabase
          await Supabase.instance.client.from('order_groups').insert({
            'shop_id': shopId,
            'table_names': _selectedEmptyTables.toList(),
            'pax': pax,
            'pax_adult': adult,
            'pax_child': child,
            'status': OrderingConstants.orderStatusDining,
            'open_id': currentOpenId,
            'tax_snapshot': taxSnapshot,
          });
        }

        _selectedEmptyTables.clear();
        if (selectedAreaId != null) {
          await _loadTablesForArea(selectedAreaId!);
        }
      }
    } on HubConflictException catch (e) {
      debugPrint("開桌衝突: ${e.error}");
      // 桌位被搶佔：重整桌位列表並提示
      if (selectedAreaId != null) await _loadTablesForArea(selectedAreaId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("桌位已被入座，請重新整理")),
        );
      }
    } catch (e) {
      debugPrint("開桌失敗: $e");
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("開桌失敗，請重試")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// 三層優先級選色，防止鄰桌相同顏色（同 Supabase 版邏輯）
  Future<int> _pickColorIndex(
    String shopId,
    List<String> tableNames, {
    bool isHubDevice = false,
  }) async {
    try {
      final primaryTableName = tableNames.isNotEmpty ? tableNames.first : '';

      // 取得全店桌位座標（Supabase）
      final tablesRes = await Supabase.instance.client
          .from('tables')
          .select('table_name, x, y')
          .eq('shop_id', shopId);

      final Map<String, Map<String, double>> tableCoords = {};
      for (final row in tablesRes) {
        tableCoords[row['table_name'] as String] = {
          'x': (row['x'] as num?)?.toDouble() ?? 0.0,
          'y': (row['y'] as num?)?.toDouble() ?? 0.0,
        };
      }
      final myCoords = tableCoords[primaryTableName];

      const double threshold = 150.0;
      final Set<int> allUsedColors = {};
      final Set<int> nearbyUsedColors = {};

      if (isHubDevice || HubClient().isHubAvailable) {
        // Hub 模式：從 cached_tables 讀取現有顏色
        List<Map<String, dynamic>> occupiedTables;
        if (isHubDevice) {
          occupiedTables = await LocalDbService().getCachedTables();
        } else {
          final res = await HubClient().get('/tables');
          occupiedTables =
              List<Map<String, dynamic>>.from(res?['tables'] ?? []);
        }

        for (final ct in occupiedTables) {
          if (ct['status'] != 'occupied') continue;
          final colorIndex = ct['color_index'] as int?;
          if (colorIndex == null) continue;
          allUsedColors.add(colorIndex);

          if (myCoords != null) {
            final otherCoords = tableCoords[ct['table_name'] as String?];
            if (otherCoords != null) {
              final dx = myCoords['x']! - otherCoords['x']!;
              final dy = myCoords['y']! - otherCoords['y']!;
              if (dx * dx + dy * dy <= threshold * threshold) {
                nearbyUsedColors.add(colorIndex);
              }
            }
          }
        }
      } else {
        // Supabase 模式
        final activeOrdersRes = await Supabase.instance.client
            .from('order_groups')
            .select('table_names, color_index')
            .eq('shop_id', shopId)
            .eq('status', OrderingConstants.orderStatusDining);

        for (final row in activeOrdersRes) {
          if (row['color_index'] == null) continue;
          final int colorUsed = row['color_index'] as int;
          allUsedColors.add(colorUsed);

          if (myCoords != null) {
            final List<String> groupTables =
                List<String>.from(row['table_names'] ?? []);
            bool isNeighbor = false;
            for (final otherName in groupTables) {
              final otherCoords = tableCoords[otherName];
              if (otherCoords != null) {
                final dx = myCoords['x']! - otherCoords['x']!;
                final dy = myCoords['y']! - otherCoords['y']!;
                if (dx * dx + dy * dy <= threshold * threshold) {
                  isNeighbor = true;
                  break;
                }
              }
            }
            if (isNeighbor) nearbyUsedColors.add(colorUsed);
          }
        }
      }

      // 三層優先級
      // index 1（綠色 #32D74B）與選中空桌的螢光綠太相似，排除不用
      const Set<int> reservedColors = {1};
      final List<int> p1 = []; // 全店無人用
      final List<int> p2 = []; // 有人用但非鄰桌
      for (int i = 0; i < 9; i++) {
        if (reservedColors.contains(i)) continue;
        if (!allUsedColors.contains(i)) {
          p1.add(i);
        } else if (!nearbyUsedColors.contains(i)) {
          p2.add(i);
        }
      }
      p1.shuffle();
      p2.shuffle();

      if (p1.isNotEmpty) return p1.first;
      if (p2.isNotEmpty) return p2.first;
      // fallback：排除保留色後取餘數
      final fallbackPool = List.generate(9, (i) => i)
          .where((i) => !reservedColors.contains(i))
          .toList();
      return fallbackPool[DateTime.now().millisecondsSinceEpoch % fallbackPool.length];
    } catch (e) {
      debugPrint('⚠️ _pickColorIndex fallback: $e');
      return DateTime.now().millisecondsSinceEpoch % 9;
    }
  }

  // 🔥 [Refactored] Use Repository
  Future<void> _processClearTable(TableModel table,
      {String? targetGroupId}) async {
    final String groupId = targetGroupId ?? table.currentOrderGroupId!;

    // Display Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) =>
          const Center(child: CupertinoActivityIndicator(color: Colors.white)),
    );

    try {
      if (_orderingRepo == null) await _ensureRepository();
      await _orderingRepo!.clearTable({
        'table_name': table.tableName,
        'current_order_group_id': groupId,
      });

      if (mounted) {
        Navigator.pop(context); // Close Loading
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("桌號 ${table.tableName} 已清桌")));
        if (selectedAreaId != null) _loadTablesForArea(selectedAreaId!);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close Loading
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("清桌失敗: $e")));
      }
    }
  }

  Future<void> _executeGuestLeave(String targetGroupId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) =>
          const Center(child: CupertinoActivityIndicator(color: Colors.white)),
    );
    try {
      if (_orderingRepo == null) await _ensureRepository();
      final contextObj = await _orderingRepo!.getOrderContext(targetGroupId);
      if (contextObj == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final totalItemsCount = contextObj.order.items.length;

      if (mounted) Navigator.pop(context);

      if (totalItemsCount > 0) {
        if (mounted) {
          final bool? confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(ctx).cardColor,
              title: Text("確認顧客離開？",
                  style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
              content: Text(
                "此桌尚有品項 (或是已作廢品項)。\n確認離開將會把此訂單視為「已作廢」並結束。",
                style: TextStyle(
                    color:
                        Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text("返回",
                        style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onSurface))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text("確認離開",
                        style:
                            TextStyle(color: Theme.of(ctx).colorScheme.error))),
              ],
            ),
          );
          if (confirm == true) {
            if (_orderingRepo == null) await _ensureRepository();
            await _orderingRepo!.voidOrderGroup(targetGroupId);
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("訂單已作廢並結束")));
              if (selectedAreaId != null) _loadTablesForArea(selectedAreaId!);
            }
          }
        }
      } else {
        if (_sessionRepo == null) await _ensureRepository();
        await _sessionRepo!.deleteOrderGroup(targetGroupId);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("已清空 (無交易紀錄)")));
          if (selectedAreaId != null) _loadTablesForArea(selectedAreaId!);
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("操作失敗: $e")));
    }
  }

  void _showOccupiedActionMenu(TableModel table,
      {String? overrideOrderGroupId}) {
    final parentContext = context; // Capture parent context for navigation
    final List<String> sortedOrderIds = List.from(table.activeOrderGroupIds);
    if (sortedOrderIds.isEmpty && table.currentOrderGroupId != null)
      sortedOrderIds.add(table.currentOrderGroupId!);

    // Default to the *First* (Main) or *Last*?
    // User said "Main 1, Split 2...".
    // Usually "Main" is the one you want? Or "Latest"?
    // Let's default to the ONE that is currently assigned to the table (usually latest),
    // OR default to the FIRST one (Main)?
    // Let's default to the `table.currentOrderGroupId` (which is latest/active).
    // And allow switching.

    // Default to the *First* (Main) order as per user request
    String currentSelectedId = overrideOrderGroupId ??
        (sortedOrderIds.isNotEmpty
            ? sortedOrderIds.first
            : table.currentOrderGroupId!);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            // Re-calculate sameGroupTables for the selected ID
            final sameGroupTables = tables
                .where((t) => t.activeOrderGroupIds.contains(currentSelectedId))
                .map((t) => t.tableName)
                .toList();
            if (sameGroupTables.isEmpty) sameGroupTables.add(table.tableName);
            sameGroupTables.sort();

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: () async {
                                try {
                                  await _ensureRepository();
                                  final ctx = await _orderingRepo!.getOrderContext(currentSelectedId);
                                  return ctx?.order.note ?? '';
                                } catch (_) {
                                  return '';
                                }
                              }(),
                              builder: (context, snapshot) {
                                final noteText = snapshot.data ?? '';
                                return RichText(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: '.SF Pro Text'),
                                    children: [
                                      TextSpan(
                                          text:
                                              "桌號：${sameGroupTables.join(", ")}"),
                                      if (noteText.isNotEmpty)
                                        TextSpan(
                                          text: " ($noteText)",
                                          style: const TextStyle(
                                              color: Color(0xFFFF9F0A),
                                              fontSize: 18),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "單號：...${currentSelectedId.substring(currentSelectedId.length - 6)}", // Use currentSelectedId
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(CupertinoIcons.xmark_circle_fill,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
                            size: 28),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Grid Action Buttons ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                    children: [
                      _buildGlassActionBtn(
                          context, "點菜", CupertinoIcons.cart_fill,
                          color: const Color(0xFF0A84FF), onTap: () {
                        Navigator.pop(sheetContext);
                        context.push('/orderV2', extra: {
                          'tableNumbers': sameGroupTables,
                          'orderGroupId':
                              currentSelectedId, // Use currentSelectedId
                          'isNewOrder': false,
                        }).then((_) => _loadTablesForArea(selectedAreaId!));
                      }),
                      _buildGlassActionBtn(
                          context, "調整人數", CupertinoIcons.person_2_fill,
                          onTap: () {
                        Navigator.pop(sheetContext);
                        _showUpdatePaxDialog(
                            currentSelectedId); // Use currentSelectedId
                      }),
                      _buildGlassActionBtn(
                          context, "換桌", CupertinoIcons.arrow_right_arrow_left,
                          onTap: () async {
                        Navigator.pop(sheetContext);
                        await context.push('/moveTable', extra: {
                          'groupKey':
                              currentSelectedId, // Use currentSelectedId
                          'currentSeats': sameGroupTables
                        });
                        if (selectedAreaId != null && mounted) {
                          await _loadTablesForArea(selectedAreaId!);
                        }
                      }),
                      _buildGlassActionBtn(context, "併桌/拆桌",
                          CupertinoIcons.arrow_down_right_arrow_up_left,
                          onTap: () async {
                        Navigator.pop(sheetContext);
                        await _handleMergeOrUnmergeTap(currentSelectedId,
                            sameGroupTables); // Use currentSelectedId
                      }),
                      _buildGlassActionBtn(
                          context, "桌位資訊", CupertinoIcons.info_circle_fill,
                          onTap: () {
                        Navigator.pop(sheetContext);
                        context.push('/tableInfo', extra: {
                          'tableName': sameGroupTables.join(", "),
                          'orderGroupId':
                              currentSelectedId, // Use currentSelectedId
                        });
                      }),
                      _buildGlassActionBtn(
                          context, "拆單", CupertinoIcons.scissors,
                          onTap: () async {
                        Navigator.pop(sheetContext);
                        await parentContext.push('/splitBill', extra: {
                          'groupKey': currentSelectedId,
                          'currentSeats': sameGroupTables
                        });

                        if (selectedAreaId != null && mounted) {
                          await _loadTablesForArea(selectedAreaId!);
                        }
                      }),
                      _buildGlassActionBtn(
                          context, "整單備註", CupertinoIcons.doc_text_fill,
                          onTap: () async {
                        Navigator.pop(sheetContext);
                        await _showNoteDialog(
                            currentSelectedId); // Note dialog might update note, but doesn't change structure. But refreshing is safe.
                        // Actually _showNoteDialog doesn't navigate away, it shows dialog on top.
                        // But we popped sheetContext.
                        // If _showNoteDialog is async and waits for dialog, we can refresh.

                        if (selectedAreaId != null && mounted) {
                          await _loadTablesForArea(selectedAreaId!);
                        }
                      }),
                      _buildGlassActionBtn(
                          context, "列印結帳單", CupertinoIcons.printer,
                          onTap: () async {
                        Navigator.pop(sheetContext);
                        if (mounted) {
                          parentContext.push('/printBillV2', extra: {
                            'groupKey': currentSelectedId,
                            'title': '結帳單 (預結)',
                          });
                        }
                      }),
                      _buildGlassActionBtn(context, "結帳",
                          CupertinoIcons.money_dollar_circle_fill,
                          color: const Color(0xFF32D74B), onTap: () async {
                        Navigator.pop(sheetContext);

                        await parentContext.push('/paymentV2', extra: {
                          'groupKey': currentSelectedId,
                          'totalAmount': 0.0, // Calculated internally
                        });

                        if (selectedAreaId != null && mounted) {
                          await _loadTablesForArea(selectedAreaId!);
                        }
                      }),
                      // Destructive
                      _buildGlassActionBtn(context, "顧客離開",
                          CupertinoIcons.person_crop_circle_badge_xmark,
                          isDestructive: true, onTap: () async {
                        Navigator.pop(sheetContext);

                        final targetGroupId = currentSelectedId.isNotEmpty
                            ? currentSelectedId
                            : table.currentOrderGroupId;
                        if (targetGroupId == null) return;

                        showDialog(
                          context: parentContext,
                          barrierDismissible: false,
                          builder: (c) => const Center(
                              child: CupertinoActivityIndicator(
                                  color: Colors.white)),
                        );

                        try {
                          final supabase = Supabase.instance.client;

                          // Check for ANY items (even cancelled ones? No, user said "no items" -> delete. "Has items" -> void.)
                          // But usually "Has items" implies "Has ACTIVE items" to worth voiding.
                          // If has only cancelled items? It's effectively empty/voided properly.
                          // The logic: "If order has no items" -> delete. "If order has items" -> void.

                          // Check total count to decide if Void (keeps history) or Delete (no history)
                          final totalItemsCount = await supabase
                              .from('order_items')
                              .count(CountOption.exact)
                              .eq('order_group_id', targetGroupId);

                          if (mounted)
                            Navigator.pop(parentContext); // Close loading

                          if (totalItemsCount > 0) {
                            // Has items (active or cancelled).
                            // Logic: Confim Leave -> Void.
                            if (mounted) {
                              final bool? confirm = await showDialog<bool>(
                                context: parentContext,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Theme.of(context).cardColor,
                                  title: Text("確認顧客離開？",
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                  content: Text(
                                    "此桌尚有品項 (或是已作廢品項)。\n確認離開將會把此訂單視為「已作廢」並結束。",
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7)),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text("返回",
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface)),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text("確認離開",
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                // Execute Void
                                if (_orderingRepo == null)
                                  await _ensureRepository();
                                await _orderingRepo!
                                    .voidOrderGroup(targetGroupId);

                                // 通知 Hub 清桌
                                await _clearTableOnHub(
                                    table.tableName, targetGroupId);

                                if (mounted) {
                                  ScaffoldMessenger.of(parentContext)
                                      .showSnackBar(const SnackBar(
                                          content: Text("訂單已作廢並結束")));
                                  if (selectedAreaId != null)
                                    _loadTablesForArea(selectedAreaId!);
                                }
                              }
                            }
                          } else {
                            // No items at all -> Delete (Don't record)
                            if (_sessionRepo == null) await _ensureRepository();
                            await _sessionRepo!.deleteOrderGroup(targetGroupId);

                            // 通知 Hub 清桌
                            await _clearTableOnHub(
                                table.tableName, targetGroupId);

                            if (mounted) {
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                  const SnackBar(content: Text("已清空 (無交易紀錄)")));
                              if (selectedAreaId != null)
                                _loadTablesForArea(selectedAreaId!);
                            }
                          }
                        } catch (e) {
                          if (mounted && Navigator.canPop(parentContext))
                            Navigator.pop(
                                parentContext); // Ensure loading closed
                          debugPrint("Check error: $e");
                          if (mounted)
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(content: Text("操作失敗: $e")));
                        }
                      }),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ----------------------------------------------------------------
  // iPad Left Panel
  // ----------------------------------------------------------------

  /// Hub 模式清桌：通知 Hub 更新 cached_tables
  Future<void> _clearTableOnHub(String tableName, String orderGroupId) async {
    final isHubDevice =
        (await SharedPreferences.getInstance()).getBool('isHubDevice') ?? false;
    if (isHubDevice) {
      // Hub 裝置直接清本地 SQLite
      await LocalDbService().clearCachedTable(tableName);
    } else if (HubClient().isHubAvailable) {
      // Client 通知 Hub
      await HubClient().post('/tables/clear', {
        'table_name': tableName,
        'order_group_id': orderGroupId,
      });
    }
  }

  Future<void> _executePanelSeat() async {
    final pax = _panelAdults + _panelChildren;
    if (pax <= 0) return;
    await _createNewOrderGroup(pax, _panelAdults, _panelChildren);
    if (mounted)
      setState(() {
        _panelAdults = 1;
        _panelChildren = 0;
      });
  }

  Widget _buildLeftPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 300,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border:
            Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_occupiedSubMode == _OccupiedSubMode.splitBill ||
                _occupiedSubMode == _OccupiedSubMode.payment)
              GestureDetector(
                onTap: () =>
                    setState(() => _occupiedSubMode = _OccupiedSubMode.main),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.chevron_left,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        _occupiedSubMode == _OccupiedSubMode.payment
                            ? '結帳中...'
                            : '拆單中...',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(CupertinoIcons.back,
                    color: theme.colorScheme.onSurface, size: 28),
                onPressed: () => context.go('/home'),
              ),
            Expanded(
              child: _selectedEmptyTables.isNotEmpty
                  ? _buildPaxPanel(context)
                  : _occupiedSubMode == _OccupiedSubMode.moveTable
                      ? _buildMoveTablePanel(context)
                      : _occupiedSubMode == _OccupiedSubMode.mergeTable
                          ? _buildMergeTablePanel(context)
                          : _occupiedSubMode == _OccupiedSubMode.updatePax
                              ? _buildUpdatePaxPanel(context)
                              : _occupiedSubMode == _OccupiedSubMode.editNote
                                  ? _buildEditNotePanel(context)
                                  : _occupiedSubMode ==
                                          _OccupiedSubMode.tableInfo
                                      ? _buildTableInfoPanel(context)
                                      : _occupiedSubMode ==
                                              _OccupiedSubMode.printBill
                                          ? _buildPrintBillPanel(context)
                                          : _buildOccupiedActionsPanel(context,
                                              enabled: _selectedOccupiedTable !=
                                                  null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelPaxRow(BuildContext context, String label, int count,
      {required VoidCallback onMinus, required VoidCallback onPlus}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
        Row(children: [
          GestureDetector(
            onTap: onMinus,
            child: Icon(CupertinoIcons.minus_circle_fill,
                color: colorScheme.onSurface.withOpacity(0.4), size: 28),
          ),
          SizedBox(
            width: 36,
            child: Text('$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          GestureDetector(
            onTap: onPlus,
            child: Icon(CupertinoIcons.plus_circle_fill,
                color: colorScheme.onSurface, size: 28),
          ),
        ]),
      ],
    );
  }

  Future<void> _executeMoveTable() async {
    if (_moveTargetTables.isEmpty || _selectedOccupiedOrderGroupId == null)
      return;
    setState(() => isLoading = true);
    try {
      await _ensureRepository();
      final newTablesList = _moveTargetTables.toList();
      final colorIndex = await _sessionRepo!.pickColorForTables(newTablesList)
          .catchError((_) => 0);
      await (_orderingRepo as OrderingRepositoryImpl).moveTable(
        hostGroupId: _selectedOccupiedOrderGroupId!,
        oldTables: _sameGroupTables,
        newTables: newTablesList,
        colorIndex: colorIndex,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("✅ 桌位已更新")));
        setState(() {
          _selectedOccupiedTable = null;
          _selectedOccupiedOrderGroupId = null;
          _occupiedSubMode = _OccupiedSubMode.main;
          _moveTargetTables.clear();
        });
        if (selectedAreaId != null) await _loadTablesForArea(selectedAreaId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("換桌失敗: $e")));
      }
    }
  }

  Future<void> _executeMerge() async {
    if (_pendingMergeGroups.isEmpty && _pendingUnmergeGroups.isEmpty) return;
    setState(() => isLoading = true);
    try {
      await _ensureRepository();
      if (_pendingMergeGroups.isNotEmpty) {
        // Collect all tables (host + targets) to pick a non-conflicting color
        final List<String> allMergeTables = [..._sameGroupTables];
        for (final targetGroupId in _pendingMergeGroups) {
          for (final t in tables) {
            if (t.activeOrderGroupIds.contains(targetGroupId)) {
              allMergeTables.add(t.tableName);
            }
          }
        }
        final prefs = await SharedPreferences.getInstance();
        final shopId = prefs.getString('savedShopId') ?? '';
        final isHubDevice = prefs.getBool('isHubDevice') ?? false;
        final mergeColorIndex = await _pickColorIndex(shopId, allMergeTables, isHubDevice: isHubDevice);

        await _sessionRepo!.mergeOrderGroups(
          hostGroupId: _selectedOccupiedOrderGroupId!,
          targetGroupIds: _pendingMergeGroups.toList(),
          colorIndex: mergeColorIndex,
        );
      }
      if (_pendingUnmergeGroups.isNotEmpty) {
        final hostGroupId = _selectedOccupiedOrderGroupId!;
        final hostTableSet = _sameGroupTables.toSet();

        // 取得子群組的原始桌名，檢查是否有桌位已移動
        final childGroupsWithTables =
            await _sessionRepo!.fetchMergedChildGroupsWithTables(hostGroupId);
        final conflictedChildren = <String, List<String>>{};
        for (final childId in _pendingUnmergeGroups) {
          final childTables = childGroupsWithTables[childId] ?? [];
          if (!childTables.every((t) => hostTableSet.contains(t))) {
            conflictedChildren[childId] = childTables;
          }
        }

        Map<String, String>? tableOverrides;
        if (conflictedChildren.isNotEmpty) {
          setState(() => isLoading = false);
          if (!mounted) return;
          final emptyTableModels = await _fetchAllEmptyTables();
          if (!mounted) return;
          tableOverrides = await showDialog<Map<String, String>>(
            context: context,
            builder: (ctx) => _UnmergeConflictDialog(
              conflictedChildren: conflictedChildren,
              emptyTableModels: emptyTableModels,
              areas: areas,
              onCancel: () => Navigator.pop(ctx),
              onConfirm: (overrides) => Navigator.pop(ctx, overrides),
            ),
          );
          if (tableOverrides == null) return; // 使用者取消
          setState(() => isLoading = true);
        }

        await _sessionRepo!.unmergeOrderGroups(
          hostGroupId: hostGroupId,
          targetGroupIds: _pendingUnmergeGroups.toList(),
          tableOverrides: tableOverrides,
        );
      }
      if (mounted) {
        String msg = "✅ 更新完成";
        if (_pendingMergeGroups.isNotEmpty)
          msg += " (併入 ${_pendingMergeGroups.length} 桌)";
        if (_pendingUnmergeGroups.isNotEmpty)
          msg += " (拆除 ${_pendingUnmergeGroups.length} 桌)";
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        setState(() {
          _occupiedSubMode = _OccupiedSubMode.main;
          _pendingMergeGroups.clear();
          _pendingUnmergeGroups.clear();
          _mergedChildGroups.clear();
          _busyGroupIds.clear();
          _selectedOccupiedTable = null;
          _selectedOccupiedOrderGroupId = null;
        });
        if (selectedAreaId != null) await _loadTablesForArea(selectedAreaId!);
      }
    } catch (e) {
      debugPrint("Merge error: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("更新失敗: $e")));
      }
    }
  }

  Widget _buildMergeTablePanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final source = _sameGroupTables;
    final hasMergedChildren = _mergedChildGroups.isNotEmpty;

    void cancel() => setState(() {
          _occupiedSubMode = _OccupiedSubMode.main;
          _pendingMergeGroups.clear();
          _pendingUnmergeGroups.clear();
          _mergedChildGroups.clear();
          _busyGroupIds.clear();
        });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            GestureDetector(
              onTap: cancel,
              child: Icon(CupertinoIcons.chevron_left,
                  color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Text(hasMergedChildren ? '拆桌' : '併桌',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          Divider(height: 24, color: theme.dividerColor),

          if (_mergeLoading)
            const Expanded(child: Center(child: CupertinoActivityIndicator()))

          // ── Case 1: 已有合併子桌，只顯示拆桌 ──
          else if (hasMergedChildren) ...[
            Text('本桌',
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11)),
            const SizedBox(height: 4),
            Text(source.join(', '),
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF453A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFFF453A).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('此桌已有合併桌位',
                      style: TextStyle(
                          color: const Color(0xFFFF453A),
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('若需重新併桌，請先確認拆桌還原',
                      style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // List merged child table names (best effort from local tables data)
            Builder(builder: (_) {
              final names = tables
                  .where((t) =>
                      t.currentOrderGroupId != null &&
                      _mergedChildGroups.contains(t.currentOrderGroupId))
                  .map((t) => t.tableName)
                  .toList()
                ..sort();
              // Fallback: at minimum show count
              final display = names.isEmpty
                  ? '${_mergedChildGroups.length} 桌'
                  : names.join(', ');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已合併桌位',
                      style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(display,
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              );
            }),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: const Color(0xFFFF453A),
                borderRadius: BorderRadius.circular(12),
                onPressed: () {
                  setState(() => _pendingUnmergeGroups =
                      Set<String>.from(_mergedChildGroups));
                  _executeMerge();
                },
                child: Text('確認拆桌 (${_mergedChildGroups.length} 桌)',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),

            // ── Case 2: 尚未合併，選擇要併入的桌位 ──
          ] else ...[
            Text('本桌',
                style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11)),
            const SizedBox(height: 4),
            Text(source.join(', '),
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_pendingMergeGroups.isEmpty)
              Text('點選地圖上其他已入座桌位進行併桌',
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.35),
                      fontSize: 12))
            else ...[
              Text('準備合併',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11)),
              const SizedBox(height: 4),
              Builder(builder: (_) {
                final names = tables
                    .where((t) =>
                        t.currentOrderGroupId != null &&
                        _pendingMergeGroups.contains(t.currentOrderGroupId))
                    .map((t) => t.tableName)
                    .toList()
                  ..sort();
                return Text(names.join(', '),
                    style: const TextStyle(
                        color: Color(0xFF32D74B),
                        fontSize: 15,
                        fontWeight: FontWeight.bold));
              }),
            ],
            const Spacer(),
            if (_pendingMergeGroups.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _executeMerge,
                  child: Text('確認併桌 (${_pendingMergeGroups.length} 桌)',
                      style: TextStyle(
                          color: colorScheme.surface,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadTableInfo() async {
    if (_selectedOccupiedOrderGroupId == null) return;
    setState(() => _tableInfoLoading = true);
    try {
      if (_orderingRepo == null) await _ensureRepository();
      final contextObj = await _orderingRepo!.getOrderContext(_selectedOccupiedOrderGroupId!);
      
      if (contextObj == null) {
        setState(() => _tableInfoLoading = false);
        return;
      }

      final group = {
        'created_at': contextObj.order.createdAt?.toIso8601String(),
        'pax': contextObj.peopleCount,
        'pax_adult': contextObj.order.paxAdult,
        'pax_child': contextObj.order.paxChild,
        'note': contextObj.order.note,
        'staff_name': contextObj.staffName,
      };

      final List<Map<String, dynamic>> itemsJson = contextObj.order.items.map((it) => <String, dynamic>{
        'id': it.id,
        'item_id': it.menuItemId,
        'item_name': it.itemName,
        'quantity': it.quantity,
        'price': it.price,
        'status': it.status,
        'modifiers': it.selectedModifiers,
        'note': it.note,
        'target_print_category_ids': it.targetPrintCategoryIds,
      }).toList();

      double total = 0.0;
      for (final item in itemsJson) {
        if (item['status'] != OrderingConstants.orderStatusCancelled) {
          double p = (item['price'] as num).toDouble();
          final mods = item['modifiers'];
          List<dynamic> modsList = [];
          if (mods is String) {
            try { modsList = jsonDecode(mods); } catch (_) {}
          } else if (mods is List) {
            modsList = mods;
          }
          for (var m in modsList) {
            if (m is Map) {
              p += ((m['price'] ?? m['price_adjustment'] ?? 0) as num).toDouble();
            }
          }
          total += p * (item['quantity'] as num);
        }
      }
      
      if (mounted) {
        setState(() {
          _tableInfoData = group;
          _tableInfoItems = itemsJson;
          _tableInfoTotal = total;
          _tableInfoLoading = false;
        });
      }
    } catch (e) {
      debugPrint("TableInfo load error: $e");
      if (mounted) setState(() => _tableInfoLoading = false);
    }
  }

  Future<void> _loadSelectedOrderNote() async {
    final groupId = _selectedOccupiedOrderGroupId;
    if (groupId == null) {
      if (mounted) setState(() => _selectedOrderNote = '');
      return;
    }
    try {
      if (_orderingRepo == null) await _ensureRepository();
      final ctx = await _orderingRepo!.getOrderContext(groupId);
      if (mounted) setState(() => _selectedOrderNote = ctx?.order.note ?? '');
    } catch (_) {
      if (mounted) setState(() => _selectedOrderNote = '');
    }
  }

  Future<void> _reprintTableInfoItem(int index) async {
    final item = _tableInfoItems[index];
    final orderGroupId = _selectedOccupiedOrderGroupId;
    if (orderGroupId == null) return;
    final tableName = _selectedOccupiedTable?.tableName ?? '';

    final mods = item['modifiers'];
    final List<Map<String, dynamic>> modifiers = [];
    if (mods is List) {
      for (var m in mods) {
        if (m is Map) modifiers.add(Map<String, dynamic>.from(m));
      }
    }

    final cats = item['target_print_category_ids'];
    final List<String> printCategoryIds = [];
    if (cats is List) {
      for (var c in cats) {
        if (c is String) printCategoryIds.add(c);
      }
    }

    final orderItem = OrderItem(
      id: item['id'] as String,
      menuItemId: item['item_id'] as String? ?? '',
      itemName: item['item_name'] as String? ?? '',
      quantity: (item['quantity'] as num).toInt(),
      price: (item['price'] as num).toDouble(),
      note: item['note'] as String? ?? '',
      targetPrintCategoryIds: printCategoryIds,
      selectedModifiers: modifiers,
      status: item['status'] as String? ?? 'submitted',
    );

    try {
      await _orderingRepo!.reprintSingleItem(
        orderGroupId: orderGroupId,
        item: orderItem,
        tableName: tableName,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("補印指令已發送")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("補印失敗: $e")));
    }
  }

  Future<void> _deleteTableInfoItem(int index) async {
    if (index >= _tableInfoItems.length) return;
    final item = _tableInfoItems[index];
    if (item['status'] == OrderingConstants.orderStatusCancelled) return;

    double unit = (item['price'] as num).toDouble();
    final mods = item['modifiers'];
    if (mods is List) {
      for (var m in mods) {
        if (m is Map)
          unit += ((m['price'] ?? m['price_adjustment'] ?? 0) as num).toDouble();
      }
    }
    final qty = (item['quantity'] as num);

    // Optimistic: mark as cancelled immediately
    setState(() {
      _tableInfoItems[index] = <String, dynamic>{...item, 'status': OrderingConstants.orderStatusCancelled};
      _tableInfoTotal -= unit * qty;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final user = container.read(authStateProvider).value;
      final staffName = (user?.name != null && user!.name.trim().isNotEmpty)
          ? user.name
          : (user?.email ?? '');

      final orderItemEntity = OrderItem(
        id: item['id'],
        menuItemId: item['item_id'] ?? '',
        itemName: item['item_name'] ?? '',
        quantity: (item['quantity'] as num).toInt(),
        price: (item['price'] as num).toDouble(),
        status: 'submitted',
        targetPrintCategoryIds: List<String>.from(item['target_print_category_ids'] ?? []),
        selectedModifiers: List<Map<String, dynamic>>.from(item['modifiers'] ?? []),
        note: item['note'] ?? '',
      );

      await container.read(orderingRepositoryProvider).voidOrderItem(
        orderGroupId: _selectedOccupiedOrderGroupId!,
        item: orderItemEntity,
        tableName: _selectedOccupiedTable?.tableName ?? '',
        orderGroupPax: (_tableInfoData?['pax'] ?? 0) as int,
        staffName: staffName,
      );
    } catch (e) {
      // Revert: restore original item on failure
      if (mounted) {
        setState(() {
          _tableInfoItems[index] = item;
          _tableInfoTotal += unit * qty;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
      }
    }
  }

  Widget _buildTableInfoPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    String formatTime(dynamic raw) {
      try {
        final dt = DateTime.parse(raw.toString()).toLocal();
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return '';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () =>
                  setState(() => _occupiedSubMode = _OccupiedSubMode.main),
              child: Icon(CupertinoIcons.chevron_left,
                  color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Text('桌位資訊',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: _loadTableInfo,
              child: Icon(CupertinoIcons.refresh,
                  color: colorScheme.onSurface.withOpacity(0.4), size: 18),
            ),
          ]),
        ),
        Divider(height: 16, color: theme.dividerColor),

        if (_tableInfoLoading)
          const Expanded(child: Center(child: CupertinoActivityIndicator()))
        else if (_tableInfoData == null)
          Expanded(
              child: Center(
                  child: Text('讀取失敗',
                      style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5)))))
        else ...[
          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sameGroupTables.join(', '),
                    style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(CupertinoIcons.person_2_fill,
                      color: colorScheme.onSurface.withOpacity(0.4), size: 13),
                  const SizedBox(width: 4),
                  Text('${_tableInfoData!['pax'] ?? 0} 位',
                      style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 12)),
                  const SizedBox(width: 12),
                  if (_tableInfoData!['created_at'] != null) ...[
                    Icon(CupertinoIcons.clock,
                        color: colorScheme.onSurface.withOpacity(0.4),
                        size: 13),
                    const SizedBox(width: 4),
                    Text(formatTime(_tableInfoData!['created_at']),
                        style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 12)),
                  ],
                ]),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('目前總額',
                        style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12)),
                    Text('\$${_tableInfoTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Color(0xFF32D74B),
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 12, color: theme.dividerColor),

          // Items list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              itemCount: _tableInfoItems.length,
              separatorBuilder: (_, __) => const SizedBox.shrink(),
              itemBuilder: (context, i) {
                final item = _tableInfoItems[i];
                final cancelled = item['status'] == OrderingConstants.orderStatusCancelled;
                double unit = (item['price'] as num).toDouble();
                final mods = item['modifiers'];
                if (mods is List) {
                  for (var m in mods) {
                    if (m is Map)
                      unit +=
                          ((m['price'] ?? m['price_adjustment'] ?? 0) as num)
                              .toDouble();
                  }
                }
                final qty = (item['quantity'] as num).toInt();
                final textColor = cancelled
                    ? colorScheme.onSurface.withValues(alpha: 0.3)
                    : colorScheme.onSurface;

                final row = Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        item['item_name'] ?? '',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 17,
                          decoration:
                              cancelled ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('×$qty',
                        style: TextStyle(
                            color: textColor.withOpacity(0.7), fontSize: 16)),
                    const SizedBox(width: 6),
                    Text('\$${(unit * qty).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          decoration:
                              cancelled ? TextDecoration.lineThrough : null,
                        )),
                    if (!cancelled) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _reprintTableInfoItem(i),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(CupertinoIcons.printer,
                              color: colorScheme.primary, size: 18),
                        ),
                      ),
                    ],
                  ]),
                );

                final itemId = item['id'] as String? ?? '$i';
                final swipeOffset = _tableInfoSwipeOffsets[itemId] ?? 0.0;

                return KeyedSubtree(
                  key: ValueKey('tableinfo_item_$itemId'),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: cancelled ? null : (details) {
                      final next = (swipeOffset + details.delta.dx).clamp(-300.0, 0.0);
                      setState(() => _tableInfoSwipeOffsets[itemId] = next);
                      if (next <= -300.0) {
                        _tableInfoSwipeOffsets.remove(itemId);
                        _deleteTableInfoItem(i);
                      }
                    },
                    onHorizontalDragEnd: cancelled ? null : (details) {
                      if (swipeOffset <= -150 || details.velocity.pixelsPerSecond.dx < -800) {
                        _tableInfoSwipeOffsets.remove(itemId);
                        _deleteTableInfoItem(i);
                      } else {
                        setState(() => _tableInfoSwipeOffsets.remove(itemId));
                      }
                    },
                    child: Transform.translate(
                      offset: Offset(swipeOffset, 0),
                      child: row,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrintBillPanel(BuildContext context) {
    final orderGroupId = _selectedOccupiedOrderGroupId;
    if (orderGroupId == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () =>
                  setState(() => _occupiedSubMode = _OccupiedSubMode.main),
              child: Icon(CupertinoIcons.chevron_left,
                  color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Text('列印結帳單',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        Divider(height: 16, color: Theme.of(context).dividerColor),
        Expanded(
          child: PrintBillScreen(
            key: ValueKey(orderGroupId),
            groupKey: orderGroupId,
            title: '結帳單 (預結)',
            embedded: true,
            onClose: () =>
                setState(() => _occupiedSubMode = _OccupiedSubMode.main),
            onCheckout: () =>
                setState(() => _occupiedSubMode = _OccupiedSubMode.payment),
          ),
        ),
      ],
    );
  }

  Widget _buildMoveTablePanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final source = _sameGroupTables;
    final targetList = _moveTargetTables.toList()..sort();
    final hasTarget = _moveTargetTables.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => setState(() {
                _occupiedSubMode = _OccupiedSubMode.main;
                _moveTargetTables.clear();
              }),
              child: Icon(CupertinoIcons.chevron_left,
                  color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Text('換桌',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          Divider(height: 24, color: theme.dividerColor),
          Text('原桌位',
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Text(source.join(', '),
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Icon(CupertinoIcons.arrow_down,
              color: colorScheme.onSurface.withOpacity(0.4), size: 20),
          const SizedBox(height: 8),
          Text('換桌後',
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            hasTarget ? targetList.join(', ') : '請至少選擇一個桌位',
            style: TextStyle(
              color: hasTarget
                  ? const Color(0xFF32D74B)
                  : colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: hasTarget ? 20 : 13,
              fontWeight: hasTarget ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 6),
          Text('可保留原桌位或選擇新桌位（點選地圖切換）',
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 10)),
          const Spacer(),
          if (hasTarget)
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: colorScheme.onSurface,
                borderRadius: BorderRadius.circular(12),
                minSize: 44,
                onPressed: _executeMoveTable,
                child: Text('確認換桌',
                    style: TextStyle(
                        color: colorScheme.surface,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpdatePaxPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final sameGroupTables = _sameGroupTables;
    final orderGroupId = _selectedOccupiedOrderGroupId ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () =>
                  setState(() => _occupiedSubMode = _OccupiedSubMode.main),
              child: Icon(CupertinoIcons.chevron_left,
                  color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Text('調整人數',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text(sameGroupTables.join(', '),
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
          Divider(height: 24, color: theme.dividerColor),
          if (_updatePaxLoading)
            const Center(child: CupertinoActivityIndicator())
          else ...[
            _buildPanelPaxRow(context, '大人', _updatePaxAdults,
                onMinus: () {
                  if (_updatePaxAdults > 0) setState(() => _updatePaxAdults--);
                },
                onPlus: () => setState(() => _updatePaxAdults++)),
            const SizedBox(height: 16),
            _buildPanelPaxRow(context, '小孩', _updatePaxChildren,
                onMinus: () {
                  if (_updatePaxChildren > 0)
                    setState(() => _updatePaxChildren--);
                },
                onPlus: () => setState(() => _updatePaxChildren++)),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: colorScheme.onSurface,
              borderRadius: BorderRadius.circular(12),
              minSize: 44,
              onPressed: _updatePaxAdults + _updatePaxChildren > 0
                  ? () async {
                      try {
                        await Supabase.instance.client
                            .from('order_groups')
                            .update({
                          'pax': _updatePaxAdults + _updatePaxChildren,
                          'pax_adult': _updatePaxAdults,
                          'pax_child': _updatePaxChildren,
                        }).eq('id', orderGroupId);
                        if (mounted) {
                          setState(
                              () => _occupiedSubMode = _OccupiedSubMode.main);
                          if (selectedAreaId != null)
                            await _loadTablesForArea(selectedAreaId!);
                        }
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('更新失敗: $e')));
                      }
                    }
                  : null,
              child: Text('確認',
                  style: TextStyle(
                      color: colorScheme.surface, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditNotePanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final sameGroupTables = _sameGroupTables;
    final orderGroupId = _selectedOccupiedOrderGroupId ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () =>
                  setState(() => _occupiedSubMode = _OccupiedSubMode.main),
              child: Icon(CupertinoIcons.chevron_left,
                  color: colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 8),
            Text('整單備註',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text(sameGroupTables.join(', '),
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
          Divider(height: 24, color: theme.dividerColor),
          Expanded(
            child: CupertinoTextField(
              controller: _noteController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              placeholder: '輸入備註...',
              style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
              placeholderStyle:
                  TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3)),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: colorScheme.onSurface,
              borderRadius: BorderRadius.circular(12),
              minSize: 44,
              onPressed: _noteSaving
                  ? null
                  : () async {
                      setState(() => _noteSaving = true);
                      try {
                        if (_orderingRepo == null) await _ensureRepository();
                        await _orderingRepo!.updateOrderGroupNote(orderGroupId, _noteController.text.trim());
                        if (mounted)
                          setState(() {
                            _noteSaving = false;
                            _occupiedSubMode = _OccupiedSubMode.main;
                            _selectedOrderNote = _noteController.text.trim();
                          });
                      } catch (e) {
                        if (mounted) {
                          setState(() => _noteSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('儲存失敗: $e')));
                        }
                      }
                    },
              child: _noteSaving
                  ? const CupertinoActivityIndicator()
                  : Text('儲存',
                      style: TextStyle(
                          color: colorScheme.surface,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaxPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('待入座桌位',
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Text(_selectedEmptyTables.join(', '),
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Divider(height: 24, color: theme.dividerColor),
          Text('用餐人數',
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildPanelPaxRow(context, '大人', _panelAdults,
              onMinus: () {
                if (_panelAdults > 0) setState(() => _panelAdults--);
              },
              onPlus: () => setState(() => _panelAdults++)),
          const SizedBox(height: 12),
          _buildPanelPaxRow(context, '小孩', _panelChildren,
              onMinus: () {
                if (_panelChildren > 0) setState(() => _panelChildren--);
              },
              onPlus: () => setState(() => _panelChildren++)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: colorScheme.onSurface,
              borderRadius: BorderRadius.circular(12),
              minSize: 44,
              onPressed:
                  _panelAdults + _panelChildren > 0 ? _executePanelSeat : null,
              child: Text('確認入座',
                  style: TextStyle(
                      color: colorScheme.surface, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupiedActionsPanel(BuildContext context,
      {required bool enabled}) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final orderGroupId = _selectedOccupiedOrderGroupId ?? '';
    final sameGroupTables = _sameGroupTables;

    Widget btn(String label, IconData icon, VoidCallback onTap,
        {Color? color, bool isDestructive = false}) {
      return Expanded(
        child: Opacity(
          opacity: enabled ? 1.0 : 0.3,
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isDestructive
                          ? const Color(0xFFFF453A)
                          : (color ?? colorScheme.primary),
                      size: 20),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                          color: isDestructive
                              ? const Color(0xFFFF453A)
                              : colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: enabled
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sameGroupTables.join(', '),
                        style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (_selectedOrderNote.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(_selectedOrderNote,
                            style: const TextStyle(
                                color: Color(0xFFFF9F0A), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                )
              : Text('請選擇已入座桌位',
                  style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.35),
                      fontSize: 13)),
        ),
        Divider(height: 8, color: theme.dividerColor),
        btn('點菜', CupertinoIcons.cart_fill, () async {
          setState(() => _selectedOccupiedTable = null);
          await context.push('/orderV2', extra: {
            'tableNumbers': sameGroupTables,
            'orderGroupId': orderGroupId,
            'isNewOrder': false,
          });
          if (selectedAreaId != null && mounted)
            await _loadTablesForArea(selectedAreaId!);
        }, color: const Color(0xFF0A84FF)),
        btn('調整人數', CupertinoIcons.person_2_fill, () async {
          setState(() {
            _updatePaxLoading = true;
            _occupiedSubMode = _OccupiedSubMode.updatePax;
          });
          try {
            if (_orderingRepo == null) await _ensureRepository();
            final contextObj = await _orderingRepo!.getOrderContext(orderGroupId);
            if (mounted && contextObj != null) {
              setState(() {
                _updatePaxAdults = contextObj.order.paxAdult;
                _updatePaxChildren = contextObj.order.paxChild;
                
                // Fallback if pax_adult is 0 but peopleCount > 0
                if (_updatePaxAdults == 0 && contextObj.peopleCount > 0) {
                  _updatePaxAdults = contextObj.peopleCount;
                }
                
                _updatePaxLoading = false;
              });
            } else if (mounted) {
               setState(() => _updatePaxLoading = false);
            }
          } catch (_) {
            if (mounted) setState(() => _updatePaxLoading = false);
          }
        }),
        btn('換桌', CupertinoIcons.arrow_right_arrow_left, () {
          setState(() {
            _moveTargetTables.clear();
            _occupiedSubMode = _OccupiedSubMode.moveTable;
          });
        }),
        btn('併桌/拆桌', CupertinoIcons.arrow_down_right_arrow_up_left, () async {
          setState(() {
            _mergeLoading = true;
            _pendingMergeGroups.clear();
            _pendingUnmergeGroups.clear();
            _mergedChildGroups.clear();
            _busyGroupIds.clear();
            _occupiedSubMode = _OccupiedSubMode.mergeTable;
          });
          try {
            await _ensureRepository();
            final childIds =
                await _sessionRepo!.fetchMergedChildGroups(orderGroupId);
            final mergedChildSet = Set<String>.from(childIds);

            Set<String> busyIds = {};
            if (mergedChildSet.isEmpty) {
              // Case 2: merge selection — fetch all groups involved in any merge
              final prefs = await SharedPreferences.getInstance();
              final shopId = prefs.getString('savedShopId') ?? '';
              final res = await Supabase.instance.client
                  .from('order_groups')
                  .select('id, merged_target_id')
                  .eq('status', OrderingConstants.orderStatusMerged)
                  .eq('shop_id', shopId);
              for (final row in res as List) {
                busyIds.add(row['id'] as String);
                if (row['merged_target_id'] != null) {
                  busyIds.add(row['merged_target_id'] as String);
                }
              }
            }

            if (mounted)
              setState(() {
                _mergedChildGroups = mergedChildSet;
                _busyGroupIds = busyIds;
                _mergeLoading = false;
              });
          } catch (_) {
            if (mounted) setState(() => _mergeLoading = false);
          }
        }),
        btn('桌位資訊', CupertinoIcons.info_circle_fill, () {
          setState(() {
            _tableInfoData = null;
            _tableInfoItems = [];
            _tableInfoTotal = 0.0;
            _occupiedSubMode = _OccupiedSubMode.tableInfo;
          });
          _loadTableInfo();
        }),
        btn('整單備註', CupertinoIcons.doc_text_fill, () async {
          // 先載入現有備註
          try {
            if (_orderingRepo == null) await _ensureRepository();
            final contextObj = await _orderingRepo!.getOrderContext(orderGroupId);
            if (mounted) {
               _noteController.text = contextObj?.order.note ?? '';
            }
          } catch (_) {
            _noteController.text = '';
          }
          if (mounted)
            setState(() => _occupiedSubMode = _OccupiedSubMode.editNote);
        }),
        btn('列印結帳單', CupertinoIcons.printer, () {
          setState(() => _occupiedSubMode = _OccupiedSubMode.printBill);
        }),
        btn('拆單', CupertinoIcons.rectangle_split_3x1, () {
          setState(() => _occupiedSubMode = _OccupiedSubMode.splitBill);
        }),
        btn('結帳', CupertinoIcons.money_dollar_circle_fill, () {
          setState(() => _occupiedSubMode = _OccupiedSubMode.payment);
        }, color: const Color(0xFF32D74B)),
        btn('顧客離開', CupertinoIcons.person_crop_circle_badge_xmark, () async {
          final id = orderGroupId;
          setState(() => _selectedOccupiedTable = null);
          await _executeGuestLeave(id);
        }, isDestructive: true),
        const SizedBox(height: 8),
      ],
    );
  }

  // Refactored to match Home Screen Design
  Widget _buildGlassActionBtn(
    BuildContext context,
    String label,
    IconData icon, {
    Color? color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    const double iconSize = 62.0;
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Icon Color: Use passed color, or Primary, or Red if destructive
    final Color iconColor = isDestructive
        ? const Color(0xFFFF453A)
        : (color ?? Theme.of(context).colorScheme.primary);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              color: Theme.of(context).cardColor, // Consistent background
              boxShadow: isLight
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
              border: isDestructive
                  ? Border.all(color: const Color(0xFFFF453A).withOpacity(0.5))
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                color: iconColor,
                size: 30.0,
              ),
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDestructive
                  ? const Color(0xFFFF453A)
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // [功能 2] 調整人數
  Future<void> _showUpdatePaxDialog(String orderGroupId) async {
    int initialAdult = 0;
    int initialChild = 0;

    try {
      if (_orderingRepo == null) await _ensureRepository();
      final contextObj = await _orderingRepo!.getOrderContext(orderGroupId);
      if (contextObj != null) {
        initialAdult = contextObj.order.paxAdult;
        initialChild = contextObj.order.paxChild;
        
        // If adult is 0 but peopleCount > 0, fallout to peopleCount
        if (initialAdult == 0 && contextObj.peopleCount > 0) {
          initialAdult = contextObj.peopleCount;
        }
      }
    } catch (e) {
      debugPrint("無法讀取目前人數: $e");
    }

    if (!mounted) return;

    final adultController =
        TextEditingController(text: initialAdult.toString());
    final childController =
        TextEditingController(text: initialChild.toString());

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return _DarkStyleDialog(
              title: "調整人數",
              contentWidget: Column(
                children: [
                  // 大人行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('大人',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.minus_circle_fill),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            iconSize: 32,
                            onPressed: () {
                              int val = int.tryParse(adultController.text) ?? 0;
                              if (val > 0)
                                adultController.text = (val - 1).toString();
                            },
                          ),
                          SizedBox(
                            width: 60,
                            child: CupertinoTextField(
                              controller: adultController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                              decoration: null,
                              padding: EdgeInsets.zero,
                              onChanged: (value) {
                                if (value.length > 1 && value.contains('0')) {
                                  final newDigit = value.replaceFirst('0', '');
                                  if (newDigit.length == 1) {
                                    adultController.text = newDigit;
                                    adultController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: adultController.text.length),
                                    );
                                    return;
                                  }
                                }
                                if (value.length > 1 && value.startsWith('0')) {
                                  final n = int.tryParse(value);
                                  if (n != null) {
                                    adultController.text = n.toString();
                                    adultController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: adultController.text.length),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.plus_circle_fill),
                            color: Colors
                                .black, // Changed to black per user request
                            iconSize: 32,
                            onPressed: () {
                              int val = int.tryParse(adultController.text) ?? 0;
                              adultController.text = (val + 1).toString();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 小孩行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('小孩',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.minus_circle_fill),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            iconSize: 32,
                            onPressed: () {
                              int val = int.tryParse(childController.text) ?? 0;
                              if (val > 0)
                                childController.text = (val - 1).toString();
                            },
                          ),
                          SizedBox(
                            width: 60,
                            child: CupertinoTextField(
                              controller: childController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                              decoration: null,
                              padding: EdgeInsets.zero,
                              onChanged: (value) {
                                if (value.length > 1 && value.contains('0')) {
                                  final newDigit = value.replaceFirst('0', '');
                                  if (newDigit.length == 1) {
                                    childController.text = newDigit;
                                    childController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: childController.text.length),
                                    );
                                    return;
                                  }
                                }
                                if (value.length > 1 && value.startsWith('0')) {
                                  final n = int.tryParse(value);
                                  if (n != null) {
                                    childController.text = n.toString();
                                    childController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: childController.text.length),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.plus_circle_fill),
                            color: Colors
                                .black, // Changed to black per user request
                            iconSize: 32,
                            onPressed: () {
                              int val = int.tryParse(childController.text) ?? 0;
                              childController.text = (val + 1).toString();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              onCancel: () => Navigator.pop(context),
              onConfirm: () async {
                final adultVal = int.tryParse(adultController.text) ?? 0;
                final childVal = int.tryParse(childController.text) ?? 0;
                final newPax = adultVal + childVal;

                if (newPax > 0) {
                  try {
                    if (_sessionRepo == null) await _ensureRepository();
                    await _sessionRepo!.updatePax(orderGroupId, newPax,
                        adult: adultVal, child: childVal);

                    if (mounted)
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text("人數已更新")));
                  } catch (e) {
                    debugPrint("更新人數失敗: $e");
                  }
                  if (mounted) Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text("人數必須大於 0")));
                }
              },
            );
          },
        );
      },
    );
  }

  // [功能] 整單備註
  Future<void> _showNoteDialog(String orderGroupId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CupertinoActivityIndicator(color: Colors.white)),
    );

    String currentNote = '';

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isHubDevice = prefs.getBool('isHubDevice') ?? false;
      final String hubIp = prefs.getString('hubIpAddress') ?? '';
      final bool isHubClient = hubIp.isNotEmpty && !isHubDevice;

      if (isHubDevice) {
        final group = await LocalDbService().getPendingOrderGroup(orderGroupId);
        currentNote = (group?['note'] as String?) ?? '';
      } else if (isHubClient) {
        final res = await HubClient().get('/orders/$orderGroupId');
        currentNote = (res?['order_group']?['note'] as String?) ?? '';
      } else {
        final res = await Supabase.instance.client
            .from('order_groups')
            .select('note')
            .eq('id', orderGroupId)
            .single();
        currentNote = (res['note'] as String?) ?? '';
      }
    } catch (e) {
      debugPrint("讀取備註失敗: $e");
    }

    if (!mounted) return;
    Navigator.pop(context);

    final noteController = TextEditingController(text: currentNote);

    await showDialog(
      context: context,
      builder: (context) => _DarkStyleDialog(
        title: "整單備註",
        contentWidget: CupertinoTextField(
          controller: noteController,
          placeholder: "例如：VIP、壽星、不吃牛...",
          placeholderStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              fontSize: 16),
          maxLines: 3,
          padding: const EdgeInsets.all(12),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
          autofocus: true,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onCancel: () => Navigator.pop(context),
        onConfirm: () async {
          final note = noteController.text.trim();
          try {
            if (_orderingRepo == null) await _ensureRepository();
            await _orderingRepo!.updateOrderGroupNote(orderGroupId, note);

            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("備註已更新")));
              Navigator.pop(context);
              if (selectedAreaId != null) {
                _loadTablesForArea(selectedAreaId!);
              }
            }
          } catch (e) {
            debugPrint("更新備註失敗: $e");
            if (mounted)
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("更新失敗")));
          }
        },
      ),
    );
  }

  // 處理「併桌/拆桌」按鈕點擊
  Future<void> _handleMergeOrUnmergeTap(
      String groupId, List<String> currentSeats) async {
    await _ensureRepository();

    // 1. 取得所有子群組及其原始桌名
    final childGroupsWithTables =
        await _sessionRepo!.fetchMergedChildGroupsWithTables(groupId);

    // 2. 沒有子群組 → 進入一般的併桌選擇畫面
    if (childGroupsWithTables.isEmpty) {
      if (!mounted) return;
      await context.push('/mergeTable',
          extra: {'groupKey': groupId, 'currentSeats': currentSeats});
      if (selectedAreaId != null && mounted) {
        await _loadTablesForArea(selectedAreaId!);
      }
      return;
    }

    // 3. 偵測衝突：子群組的原始桌名是否還在 host 目前的桌位列表中
    //    仍在 → 沒有移動過，可以直接拆回
    //    不在 → host 已移動，需要員工另選空桌
    final hostTableSet = currentSeats.toSet();
    final conflictedChildren = <String, List<String>>{}; // childId → 原始桌名
    for (final entry in childGroupsWithTables.entries) {
      final stillInHost = entry.value.every((t) => hostTableSet.contains(t));
      if (!stillInHost) conflictedChildren[entry.key] = entry.value;
    }

    if (!mounted) return;

    if (conflictedChildren.isEmpty) {
      // 4a. 無衝突 → 顯示簡單確認 Dialog
      showDialog(
        context: context,
        builder: (ctx) => _DarkStyleDialog(
          title: "是否回復原桌位？",
          contentWidget: Text(
            "此訂單包含了 ${childGroupsWithTables.length} 桌合併的桌位。\n確認後將自動拆分並歸還至原本的桌號。",
            style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface, fontSize: 16),
          ),
          onCancel: () => Navigator.pop(ctx),
          onConfirm: () async {
            Navigator.pop(ctx);
            await _executeQuickUnmerge(groupId, currentSeats, childGroupsWithTables);
          },
        ),
      );
    } else {
      // 4b. 有衝突 → 讓員工選擇空桌
      final emptyTableModels = await _fetchAllEmptyTables();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => _UnmergeConflictDialog(
          conflictedChildren: conflictedChildren,
          emptyTableModels: emptyTableModels,
          areas: areas,
          onCancel: () => Navigator.pop(ctx),
          onConfirm: (tableOverrides) async {
            Navigator.pop(ctx);
            await _executeQuickUnmerge(groupId, currentSeats, childGroupsWithTables,
                tableOverrides: tableOverrides);
          },
        ),
      );
    }
  }

  /// 撈取所有區域的空桌（供衝突 Dialog 使用）
  Future<List<TableModel>> _fetchAllEmptyTables() async {
    if (_sessionRepo == null) await _ensureRepository();
    final List<TableModel> result = [];
    for (final area in areas) {
      final ts = await _sessionRepo!.fetchTablesInArea(area.id);
      result.addAll(ts.where((t) => t.status == TableStatus.empty));
    }
    return result;
  }

  // 執行快速拆桌 (還原)
  Future<void> _executeQuickUnmerge(
    String hostGroupId,
    List<String> hostSeats,
    Map<String, List<String>> childGroupsWithTables, {
    Map<String, String>? tableOverrides,
  }) async {
    setState(() => isLoading = true);

    try {
      if (_sessionRepo == null) await _ensureRepository();

      await _sessionRepo!.unmergeOrderGroups(
        hostGroupId: hostGroupId,
        targetGroupIds: childGroupsWithTables.keys.toList(),
        tableOverrides: tableOverrides,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("✅ 已回復原桌位")));
        if (selectedAreaId != null) {
          await _loadTablesForArea(selectedAreaId!);
        }
      }
    } catch (e) {
      debugPrint("Unmerge error: $e");
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("拆桌失敗: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showFailedPrintsDialog() async {
    _ensureRepository();
    if (_orderingRepo == null) return;
    await showDialog(
      context: context,
      builder: (context) => _FailedPrintsDialog(repository: _orderingRepo!),
    );
    _checkFailedPrints(); // Refresh after dialog close
  }

  @override
  Widget build(BuildContext context) {
    final safePaddingTop = MediaQuery.of(context).padding.top;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    final tableMapStack = Stack(
      children: [
        // 1. 桌位地圖
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: isLoading
              ? Center(
                  child: CupertinoActivityIndicator(
                      color: Theme.of(context).colorScheme.onSurface))
              : InteractiveViewer(
                  transformationController: _mapTransformController,
                  boundaryMargin: const EdgeInsets.all(500),
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background tap to clear all selections
                      GestureDetector(
                        onTap: () {
                          if (_selectedOccupiedTable != null ||
                              _selectedEmptyTables.isNotEmpty) {
                            setState(() {
                              _selectedOccupiedTable = null;
                              _selectedOccupiedOrderGroupId = null;
                              _selectedEmptyTables.clear();
                              _moveTargetTables.clear();
                              _pendingMergeGroups.clear();
                              _pendingUnmergeGroups.clear();
                              _mergedChildGroups.clear();
                              _busyGroupIds.clear();
                              _occupiedSubMode = _OccupiedSubMode.main;
                            });
                          }
                        },
                        child: Container(
                            width: 3000,
                            height: 3200,
                            color: Colors.transparent),
                      ),
                      ...tables.map((table) => _buildSingleTable(table)),
                    ],
                  ),
                ),
        ),

        // [新增] 場域驗證攔截遮罩
        if (_siteResult != null && !_siteResult!.isVerified)
          _buildSiteVerificationOverlay(),

        if (_isVerifyingSite)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
                child: CupertinoActivityIndicator(color: Colors.white)),
          ),

        // 2. Header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            padding: EdgeInsets.only(
                top: safePaddingTop + 10, bottom: 10, left: 16, right: 16),
            child: Row(
              children: [
                if (MediaQuery.of(context).size.shortestSide < 600)
                  IconButton(
                    icon: Icon(CupertinoIcons.back,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 28),
                    onPressed: () => context.go('/home'),
                  ),
                if (MediaQuery.of(context).size.shortestSide < 600)
                  const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: areas.map((area) {
                        final isSelected = area.id == selectedAreaId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => _loadTablesForArea(area.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                area.id,
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.list_bullet,
                      color: Theme.of(context).colorScheme.onSurface, size: 28),
                  onPressed: () => context
                      .push('/orderHistory', extra: {'currentShiftOnly': true}),
                ),
                const SizedBox(width: 5),
                if (unsyncedCount > 0)
                  IconButton(
                    icon: const Icon(CupertinoIcons.cloud_upload_fill,
                        color: Colors.amber, size: 28),
                    onPressed: _showUnsyncedDialog,
                    tooltip: "有 $unsyncedCount 筆未同步訂單",
                  ),
                const SizedBox(width: 5),
                Badge(
                  isLabelVisible: failedPrintCount > 0,
                  label: Text("$failedPrintCount"),
                  child: IconButton(
                    icon: Icon(CupertinoIcons.printer,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 28),
                    onPressed: _showFailedPrintsDialog,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. 底部入座按鈕 (手機版)
        if (!isTablet && _selectedEmptyTables.isNotEmpty && !_isDialogOpen)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "已選 ${_selectedEmptyTables.length} 桌: ${_selectedEmptyTables.join(", ")}",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    color: Theme.of(context).colorScheme.onPrimary,
                    borderRadius: BorderRadius.circular(20),
                    minSize: 0,
                    onPressed: _showPaxDialog,
                    child: Text("確認入座",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(child: isTablet
          ? Row(
              children: [
                _buildLeftPanel(context),
                Expanded(
                  child: _occupiedSubMode == _OccupiedSubMode.payment &&
                          _selectedOccupiedOrderGroupId != null
                      ? PaymentScreenV2(
                          key: ValueKey(_selectedOccupiedOrderGroupId),
                          groupKey: _selectedOccupiedOrderGroupId!,
                          totalAmount: 0.0,
                          embedded: true,
                          onClose: () => setState(
                              () => _occupiedSubMode = _OccupiedSubMode.main),
                          onPaymentComplete: () async {
                            setState(() {
                              _occupiedSubMode = _OccupiedSubMode.main;
                              _selectedOccupiedTable = null;
                              _selectedOccupiedOrderGroupId = null;
                            });
                            if (selectedAreaId != null && mounted)
                              await _loadTablesForArea(selectedAreaId!);
                          },
                        )
                      : _occupiedSubMode == _OccupiedSubMode.splitBill &&
                              _selectedOccupiedOrderGroupId != null
                          ? SplitBillScreen(
                              key: ValueKey(
                                  'split_$_selectedOccupiedOrderGroupId'),
                              groupKey: _selectedOccupiedOrderGroupId!,
                              currentSeats: _sameGroupTables.toList(),
                              embedded: true,
                              onClose: () => setState(() =>
                                  _occupiedSubMode = _OccupiedSubMode.main),
                              onSplitComplete: () async {
                                setState(() =>
                                    _occupiedSubMode = _OccupiedSubMode.main);
                                if (selectedAreaId != null && mounted)
                                  await _loadTablesForArea(selectedAreaId!);
                              },
                            )
                          : tableMapStack,
                ),
              ],
            )
          : tableMapStack),
        ],
      ),
    );
  }

  Widget _buildSingleTable(TableModel table) {
    // Define groupColors locally
    const List<Color> _groupColors = [
      Color(0xFF0A84FF), // Blue
      Color(0xFF32D74B), // Green
      Color(0xFFFF9F0A), // Orange
      Color(0xFFFF453A), // Red
      Color(0xFF5E5CE6), // Indigo
      Color(0xFFBF5AF2), // Purple
      Color(0xFF64D2FF), // Light Blue
      Color(0xFFFF375F), // Rose
      Color(0xFFD1D1D6), // Light Grey
    ];

    Color tableColor;

    // 4. 空桌樣式 (使用 Theme onSurface 或 disabled color，或 maintaining white for contrast if needed)
    // 但因為 Theme 可以切換，我們最好使用 Theme colors。
    tableColor = Theme.of(context).disabledColor; // Or similar
    if (_selectedEmptyTables.contains(table.tableName)) {
      tableColor =
          const Color(0xFF4CD964); // Selected Green (keep for visibility)
    } else {
      tableColor = Theme.of(context)
          .colorScheme
          .onSurface; // Default text color (e.g. White or Black)
    }

    // 5. 使用群組顏色
    if (table.status == TableStatus.occupied &&
        table.currentOrderGroupId != null) {
      if (table.colorIndex != null) {
        // Use assigned smart color
        tableColor = _groupColors[table.colorIndex! % _groupColors.length];
      } else {
        // Fallback for old data without color_index
        final int hash = table.currentOrderGroupId.hashCode;
        tableColor = _groupColors[hash.abs() % _groupColors.length];
      }
    }

    final double size = 60.0;
    Widget shapeWidget;

    final TextStyle textStyle = TextStyle(
      color: (table.status == TableStatus.occupied ||
              _selectedEmptyTables.contains(table.tableName))
          ? Colors.white // Occupied or Selected -> White text
          : Theme.of(context)
              .colorScheme
              .surface, // Empty -> Background color text (invert against onSurface)
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    switch (table.shape) {
      case 'circle':
        shapeWidget = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tableColor,
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(table.tableName, style: textStyle),
        );
        break;
      case 'rectangle':
        shapeWidget = Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: table.rotation * 3.14159265 / 180,
              child: Container(
                width: size + 30,
                height: size,
                decoration: BoxDecoration(
                  color: tableColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
            ),
            Text(table.tableName, style: textStyle),
          ],
        );
        break;
      case 'square':
      default:
        shapeWidget = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: tableColor, // 這是背景色 (Filled)
            borderRadius: BorderRadius.circular(12),
            // 增加一個邊框讓淺色模式下的空桌可見（如果背景是白，空桌也是白）
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(table.tableName, style: textStyle),
        );
        break;
    }

    // In merge-selection mode (Case 2): dim tables involved in other merges
    if (_occupiedSubMode == _OccupiedSubMode.mergeTable &&
        _mergedChildGroups.isEmpty &&
        table.currentOrderGroupId != null &&
        _busyGroupIds.contains(table.currentOrderGroupId) &&
        !_sameGroupTables.contains(table.tableName)) {
      shapeWidget = Stack(
        children: [
          shapeWidget,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: table.shape == 'circle'
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius:
                    table.shape == 'circle' ? null : BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }

    // Visual indicators for merge/unmerge mode (iPad)
    if (table.currentOrderGroupId != null) {
      if (_pendingMergeGroups.contains(table.currentOrderGroupId)) {
        shapeWidget = Stack(
          clipBehavior: Clip.none,
          children: [
            shapeWidget,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: table.shape == 'circle'
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: table.shape == 'circle'
                      ? null
                      : BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF32D74B), width: 3),
                ),
              ),
            ),
            const Positioned(
                top: -4,
                right: -4,
                child: Icon(CupertinoIcons.add_circled_solid,
                    color: Color(0xFF32D74B), size: 16)),
          ],
        );
      } else if (_pendingUnmergeGroups.contains(table.currentOrderGroupId)) {
        shapeWidget = Stack(
          clipBehavior: Clip.none,
          children: [
            shapeWidget,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: table.shape == 'circle'
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: table.shape == 'circle'
                      ? null
                      : BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF453A), width: 3),
                ),
              ),
            ),
            const Positioned(
                top: -4,
                right: -4,
                child: Icon(CupertinoIcons.minus_circle_fill,
                    color: Color(0xFFFF453A), size: 16)),
          ],
        );
      }
    }

    // Green ring for move target tables (iPad moveTable mode)
    if (_moveTargetTables.contains(table.tableName)) {
      shapeWidget = Stack(
        children: [
          shapeWidget,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: table.shape == 'circle'
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius:
                    table.shape == 'circle' ? null : BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF32D74B), width: 3),
              ),
            ),
          ),
        ],
      );
    }

    // Highlight ring for selected occupied table (iPad)
    if (table.tableName == _selectedOccupiedTable?.tableName) {
      shapeWidget = Stack(
        children: [
          shapeWidget,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: table.shape == 'circle'
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius:
                    table.shape == 'circle' ? null : BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        ],
      );
    }

    return Positioned(
      left: table.x,
      top: table.y,
      child: GestureDetector(
        onTap: () => _onTableTap(table),
        onDoubleTap: () => _onTableDoubleTap(table),
        child: shapeWidget,
      ),
    );
  }

  // [新增] 執行場域驗證
  Future<void> _verifySite() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    setState(() => _isVerifyingSite = true);

    final result = await SiteVerificationService().verifySite(shopId);

    if (mounted) {
      setState(() {
        _siteResult = result;
        _isVerifyingSite = false;
      });
    }
  }

  Widget _buildSiteVerificationOverlay() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: Colors.black.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.location_slash_fill,
                color: Colors.white, size: 80),
            const SizedBox(height: 24),
            const Text(
              "點餐功能受限",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              _siteResult?.errorMessage ?? "請確認您是否於店內工作範圍，並已連結正確 Wi-Fi。",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _verifySite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("重新驗證場域",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text("回到主畫面",
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 2. 自定義組件
// -------------------------------------------------------------------

class _HubOfflineDialog extends ConsumerStatefulWidget {
  final VoidCallback onReconnected;
  final VoidCallback onDismissed;
  const _HubOfflineDialog({required this.onReconnected, required this.onDismissed});

  @override
  ConsumerState<_HubOfflineDialog> createState() => _HubOfflineDialogState();
}

class _HubOfflineDialogState extends ConsumerState<_HubOfflineDialog> {
  bool _isConnecting = false;
  String? _statusMessage;

  Future<void> _reconnect() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) {
        setState(() => _statusMessage = '找不到店家資料，請重新登入');
        return;
      }

      final res = await Supabase.instance.client
          .from('shops')
          .select('hub_ip')
          .eq('id', shopId)
          .maybeSingle();

      final ip = res?['hub_ip'] as String?;
      if (ip == null || ip.isEmpty) {
        setState(() => _statusMessage = '目前沒有主機 IP 紀錄，請確認主機 iPad 已開啟 App');
        return;
      }

      await prefs.setString('hubIpAddress', ip);

      bool connected = false;
      await ref.read(hubClientProvider).updateHubIp(ip, (available) {
        connected = available;
      });

      if (connected) {
        widget.onReconnected();
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() => _statusMessage = '無法連線到主機（$ip），請確認主機 App 已開啟並留在前台');
      }
    } catch (e) {
      setState(() => _statusMessage = '連線失敗，請確認網路狀態');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('主機目前離線'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '開桌需要透過主機協調，以避免多台設備重複開同一桌。\n\n'
              '請確認主機 iPad 已開啟 App 並保持在前台，然後點擊「重新連線」。\n\n'
              '若已在點餐中的桌子需要加點，可直接進入該桌繼續點餐，訂單會暫存在本機，待主機恢復後自動同步。',
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDismissed();
            },
            child: const Text('知道了'),
          ),
          FilledButton(
            onPressed: _isConnecting ? null : _reconnect,
            child: _isConnecting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('重新連線'),
          ),
        ],
      ),
    );
  }
}

// 深色風格 Dialog (Now Dynamic Theme Dialog)
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
            Text(title,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            contentWidget,
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: Text(cancelText ?? "取消",
                      style: TextStyle(
                          color: Theme.of(context).disabledColor,
                          fontSize: 16)),
                ),
                SizedBox(
                  width: 120,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface, // Button fills with primary text color (Black/White)
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .surface, // Text is surface color
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(confirmText ?? "確認",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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

// 統一樣式的 Dropdown（帶外框 + 標籤）
class _StyledDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;

  const _StyledDropdown({
    required this.label,
    required this.items,
    this.value,
    this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: hint != null
              ? Text(hint!,
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 14))
              : null,
          isDense: true,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// 拆桌衝突解決 Dialog：桌位已移動時，讓員工為每個子群組選擇新空桌
class _UnmergeConflictDialog extends StatefulWidget {
  final Map<String, List<String>> conflictedChildren; // childId → 原始桌名列表
  final List<TableModel> emptyTableModels;
  final List<AreaModel> areas;
  final VoidCallback onCancel;
  final void Function(Map<String, String> tableOverrides) onConfirm;

  const _UnmergeConflictDialog({
    required this.conflictedChildren,
    required this.emptyTableModels,
    required this.areas,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<_UnmergeConflictDialog> createState() => _UnmergeConflictDialogState();
}

class _UnmergeConflictDialogState extends State<_UnmergeConflictDialog> {
  // childId → selected areaId
  final Map<String, String?> _selectedAreas = {};
  // childId → selected tableName
  final Map<String, String?> _selections = {};

  @override
  void initState() {
    super.initState();
    final firstArea = widget.areas.isNotEmpty ? widget.areas.first.id : null;
    for (final id in widget.conflictedChildren.keys) {
      _selectedAreas[id] = firstArea;
      _selections[id] = null;
    }
  }

  bool get _allSelected => _selections.values.every((v) => v != null);

  // 已被其他子群組選走的桌名
  Set<String> _usedByOthers(String childId) => _selections.entries
      .where((e) => e.key != childId && e.value != null)
      .map((e) => e.value!)
      .toSet();

  // 指定子群組可選的空桌（同區域、未被他人選走）
  List<String> _availableFor(String childId) {
    final areaId = _selectedAreas[childId];
    final used = _usedByOthers(childId);
    return widget.emptyTableModels
        .where((t) => t.areaId == areaId && !used.contains(t.tableName))
        .map((t) => t.tableName)
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.85).clamp(300.0, 560.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: (screenWidth - dialogWidth) / 2,
        vertical: 24,
      ),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "桌位已移動，請指定新桌位",
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "桌位移動後，以下訂單無法回到原桌，請為每組指定一張空桌：",
              style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...widget.conflictedChildren.entries.map((entry) {
              final childId = entry.key;
              final originalTables = entry.value;
              final available = _availableFor(childId);
              final selectedTable = _selections[childId];
              // If currently selected table is no longer available (area changed), clear it
              final effectiveTable =
                  (selectedTable != null && available.contains(selectedTable))
                      ? selectedTable
                      : null;
              if (effectiveTable != selectedTable) {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => setState(() => _selections[childId] = null));
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "原桌：${originalTables.join('、')}",
                      style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // 區域 dropdown
                        Expanded(
                          child: _StyledDropdown<String>(
                            label: '區域',
                            value: _selectedAreas[childId],
                            items: widget.areas
                                .map((a) => DropdownMenuItem(
                                    value: a.id, child: Text(a.id)))
                                .toList(),
                            onChanged: (val) => setState(() {
                              _selectedAreas[childId] = val;
                              _selections[childId] = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 桌號 dropdown
                        Expanded(
                          child: _StyledDropdown<String>(
                            label: available.isEmpty ? '無空桌' : '空桌',
                            value: effectiveTable,
                            hint: available.isEmpty ? '—' : '選擇桌號',
                            items: available
                                .map((t) =>
                                    DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: available.isEmpty
                                ? null
                                : (val) =>
                                    setState(() => _selections[childId] = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text("取消",
                      style: TextStyle(
                          color: Theme.of(context).disabledColor, fontSize: 16)),
                ),
                SizedBox(
                  width: 120,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _allSelected
                        ? () => widget.onConfirm(Map.fromEntries(_selections.entries
                            .map((e) => MapEntry(e.key, e.value!))))
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.onSurface,
                      foregroundColor: colorScheme.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Text("確認",
                        style: TextStyle(fontWeight: FontWeight.bold)),
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

class _FailedPrintsDialog extends StatefulWidget {
  final OrderingRepository repository;
  const _FailedPrintsDialog({super.key, required this.repository});
  @override
  State<_FailedPrintsDialog> createState() => _FailedPrintsDialogState();
}

class _FailedPrintsDialogState extends State<_FailedPrintsDialog> {
  bool isLoading = true;
  List<Map<String, dynamic>> failedItems = [];
  List<Map<String, dynamic>> pendingReceipts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final items = await widget.repository.fetchFailedPrintItems();
      final receipts = await widget.repository.getPendingReceiptPrints();
      debugPrint('🖨️ failedItems=${items.length}, pendingReceipts=${receipts.length}');
      if (mounted)
        setState(() {
          failedItems = items;
          pendingReceipts = receipts;
          isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _reprint(List<String> itemIds) async {
    setState(() => isLoading = true);
    int successCount = 0;

    for (var row in failedItems) {
      final item = row['item'] as OrderItem;
      if (!itemIds.contains(item.id)) continue;

      await widget.repository.reprintSingleItem(
          orderGroupId: row['orderGroupId'],
          item: item,
          tableName: row['tableName'],
          printJobs: row['printJobs'] as Map<String, dynamic>?);
      successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("已發送 $successCount 筆補印指令")));
      _loadData();
    }
  }

  Future<void> _clearAll(List<String> itemIds) async {
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text("確認全部清除？",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface)),
              content: Text("確定要清除所有卡住的列印項目嗎？\n(這並不會刪除訂單，但項目將不再提示補印)",
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("取消")),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("確認清除",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold))),
              ],
            ));

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      if (itemIds.isNotEmpty) {
        await widget.repository.updatePrintStatus(itemIds, 'success');
      }
      for (final record in pendingReceipts) {
        await widget.repository.removePendingReceiptPrint(record['id'] as String);
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("已清除所有待補印項目")));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("清除失敗: $e")));
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _reprintPendingReceipt(Map<String, dynamic> record) async {
    setState(() => isLoading = true);
    try {
      final orderId = record['id'] as String;
      final needsInvoice = (record['needs_invoice'] as int? ?? 0) == 1;
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId') ?? '';

      // 1. Fetch order data
      var orderData = await supabase.from('order_groups').select().eq('id', orderId).single();

      // 2. Issue invoice if needed
      if (needsInvoice && orderData['ezpay_invoice_number'] == null) {
        final err = await InvoiceServiceImpl().issueInvoice(orderId);
        if (err != null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('補開發票失敗: $err')));
          setState(() => isLoading = false);
          return;
        }
        orderData = await supabase.from('order_groups').select().eq('id', orderId).single();
      }

      // 3. Fetch dependencies
      final itemsRes = await supabase.from('order_items').select().eq('order_group_id', orderId).neq('status', 'cancelled');
      final paymentsRes = await supabase.from('order_payments').select().eq('order_group_id', orderId);
      final printerRes = await supabase.from('printer_settings').select().eq('shop_id', shopId);
      final shopRes = await supabase.from('shops').select('name, address, phone, code, uniform_id').eq('id', shopId).maybeSingle();
      final printerSettings = List<Map<String, dynamic>>.from(printerRes);
      final itemDetails = List<Map<String, dynamic>>.from(itemsRes);
      final payments = List<Map<String, dynamic>>.from(paymentsRes);

      // 4. Reconstruct amounts
      final rawTax = orderData['tax_snapshot'];
      double taxRate = 0;
      bool isTaxIncluded = true;
      if (rawTax is String && rawTax.isNotEmpty) {
        final m = jsonDecode(rawTax) as Map;
        taxRate = (m['rate'] as num?)?.toDouble() ?? 0;
        isTaxIncluded = m['is_tax_included'] as bool? ?? true;
      } else if (rawTax is Map) {
        taxRate = (rawTax['rate'] as num?)?.toDouble() ?? 0;
        isTaxIncluded = rawTax['is_tax_included'] as bool? ?? true;
      }
      final taxProfile = TaxProfile(id: '', shopId: shopId, rate: taxRate, isTaxIncluded: isTaxIncluded, updatedAt: DateTime.now());
      final serviceFeeRate = (orderData['service_fee_rate'] as num?)?.toDouble() ?? 0;
      final discountAmount = (orderData['discount_amount'] as num?)?.toDouble() ?? 0;
      final finalAmount = (orderData['final_amount'] as num?)?.toDouble() ?? 0;
      final orderPrice = OrderCalculator.calculate(items: itemDetails, serviceFeeRate: serviceFeeRate, discountAmount: discountAmount, taxProfile: taxProfile);

      final tableNames = jsonDecode(record['table_names'] as String? ?? '[]') as List;
      final orderGroup = OrderGroup(
        id: orderId, status: OrderStatus.completed, items: [], shopId: shopId, createdAt: DateTime.now(),
        checkoutTime: orderData['checkout_time'] != null ? DateTime.tryParse(orderData['checkout_time']) : null,
        ezpayInvoiceNumber: orderData['ezpay_invoice_number'],
        ezpayRandomNum: orderData['ezpay_random_num'],
        ezpayQrLeft: orderData['ezpay_qr_left'],
        ezpayQrRight: orderData['ezpay_qr_right'],
        finalAmount: finalAmount,
        buyerUbn: orderData['buyer_ubn']?.toString(),
      );
      final orderContext = OrderContext(order: orderGroup, tableNames: List<String>.from(tableNames), peopleCount: orderData['people_count'] ?? 1);
      final printerService = PrinterService();

      // 5. Print receipt
      await printerService.printBill(
        context: orderContext,
        items: itemDetails,
        printerSettings: printerSettings,
        subtotal: orderPrice.subtotal,
        serviceFee: orderPrice.serviceFee,
        discount: orderPrice.discount,
        finalTotal: finalAmount,
        taxAmount: isTaxIncluded ? 0 : orderPrice.taxAmount,
        taxLabel: isTaxIncluded ? null : '稅額 (${taxRate.toStringAsFixed(0)}%)',
        payments: payments.map((p) => {'method': p['payment_method'], 'amount': p['amount']}).toList(),
      ).timeout(const Duration(seconds: 10), onTimeout: () => 0);

      // 6. Print invoice proof if available
      if (orderData['ezpay_invoice_number'] != null) {
        final isB2B = orderData['buyer_ubn'] != null && orderData['buyer_ubn'].toString().length == 8;
        final hasCarrier = orderData['carrier_num'] != null && orderData['carrier_num'].toString().trim().isNotEmpty;
        if (isB2B || !hasCarrier) {
          await Future.delayed(const Duration(seconds: 2));
          await printerService.printInvoiceProof(
            order: orderGroup,
            printerSettings: printerSettings,
            shopName: shopRes?['name'] ?? '',
            sellerUbn: shopRes?['uniform_id'] ?? '',
            shopCode: shopRes?['code'],
            address: shopRes?['address'],
            phone: shopRes?['phone'],
            itemDetails: itemDetails,
            isReprint: true,
          ).timeout(const Duration(seconds: 15), onTimeout: () => 0);
        }
      }

      // 7. Remove from pending
      await widget.repository.removePendingReceiptPrint(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('補印完成 ✅')));
        _loadData();
      }
    } catch (e) {
      debugPrint('_reprintPendingReceipt error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('補印失敗: $e')));
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Theme.of(context).cardColor,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
            child: Column(children: [
              Text("列印檢測 / 補印",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface)),
              Divider(color: Theme.of(context).dividerColor),
              if (isLoading)
                const Expanded(
                    child: Center(child: CupertinoActivityIndicator())),
              if (!isLoading && failedItems.isEmpty && pendingReceipts.isEmpty)
                Expanded(
                    child: Center(
                        child: Text("目前沒有列印失敗或待處理的項目",
                            style: TextStyle(
                                color: Theme.of(context).disabledColor)))),
              if (!isLoading && (failedItems.isNotEmpty || pendingReceipts.isNotEmpty))
                Expanded(
                    child: ListView(children: [
                      // ── 廚房出單失敗 ──
                      if (failedItems.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text('廚房出單失敗',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                  color: Theme.of(context).disabledColor)),
                        ),
                        ...failedItems.map((row) {
                          final item = row['item'] as OrderItem;
                          final printJobs = (row['printJobs'] as Map?)?.cast<String, dynamic>() ?? {};
                          final failedPrinterNames = printJobs.entries
                              .where((e) => (e.value as Map?)?['status'] == 'failed')
                              .map((e) {
                                final name = (e.value as Map?)?['name'] as String?;
                                return (name != null && name.isNotEmpty) ? name : e.key;
                              })
                              .toList();
                          return Column(children: [
                            ListTile(
                              title: Text(item.itemName,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('桌號: ${row['tableName']}',
                                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                if (failedPrinterNames.isNotEmpty)
                                  Text('未出單：${failedPrinterNames.join('、')}',
                                      style: TextStyle(fontSize: 11,
                                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8))),
                              ]),
                              trailing: IconButton(
                                icon: Icon(CupertinoIcons.printer, color: Theme.of(context).colorScheme.primary),
                                onPressed: () => _reprint([item.id]),
                              ),
                            ),
                            Divider(height: 1, color: Theme.of(context).dividerColor),
                          ]);
                        }),
                      ],
                      // ── 結帳待補印 ──
                      if (pendingReceipts.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Text('結帳待補印',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                  color: Theme.of(context).disabledColor)),
                        ),
                        ...pendingReceipts.map((record) {
                          final needsInvoice = (record['needs_invoice'] as int? ?? 0) == 1;
                          final tableNames = (() {
                            try { return (jsonDecode(record['table_names'] as String? ?? '[]') as List).join('、'); }
                            catch (_) { return record['table_names'] ?? ''; }
                          })();
                          final amount = (record['final_amount'] as num?)?.toStringAsFixed(0) ?? '-';
                          final timeStr = (() {
                            final raw = record['checkout_time'] as String?;
                            if (raw == null) return '';
                            final dt = DateTime.tryParse(raw)?.toLocal();
                            if (dt == null) return '';
                            return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
                          })();
                          return Column(children: [
                            ListTile(
                              title: Text(tableNames.isEmpty ? '外帶' : tableNames,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                              subtitle: Row(children: [
                                Text('NT\$ $amount  $timeStr',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                                if (needsInvoice) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('待補開發票', style: TextStyle(fontSize: 11, color: Colors.orange)),
                                  ),
                                ],
                              ]),
                              trailing: IconButton(
                                icon: Icon(CupertinoIcons.printer, color: Theme.of(context).colorScheme.primary),
                                tooltip: needsInvoice ? '補開發票並補印' : '補印收據',
                                onPressed: () => _reprintPendingReceipt(record),
                              ),
                            ),
                            Divider(height: 1, color: Theme.of(context).dividerColor),
                          ]);
                        }),
                      ],
                    ])),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (failedItems.isNotEmpty || pendingReceipts.isNotEmpty)
                      IconButton(
                        onPressed: _loadData,
                        icon: const Icon(CupertinoIcons.refresh),
                        tooltip: "重新整理",
                      ),
                    if (failedItems.isNotEmpty || pendingReceipts.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: () => _clearAll(List<String>.from(
                              failedItems
                                  .map((e) => (e['item'] as OrderItem).id))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: const Text("全部清除")),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: () async {
                            if (failedItems.isNotEmpty) {
                              await _reprint(List<String>.from(
                                  failedItems.map((e) => (e['item'] as OrderItem).id)));
                            }
                            for (final record in pendingReceipts) {
                              await _reprintPendingReceipt(record);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor:
                                Theme.of(context).scaffoldBackgroundColor,
                            elevation: 0,
                            side: BorderSide(
                                color: Theme.of(context).dividerColor),
                          ),
                          child: const Text("全部補印")),
                    ]
                  ],
                ),
              )
            ])));
  }
}

// ─────────────────────────────────────────────────────────────
// 待同步訂單 Dialog
// ─────────────────────────────────────────────────────────────

class _UnsyncedOrdersDialog extends StatefulWidget {
  final OrderingRepository repository;
  final VoidCallback onSyncComplete;
  const _UnsyncedOrdersDialog({required this.repository, required this.onSyncComplete});

  @override
  State<_UnsyncedOrdersDialog> createState() => _UnsyncedOrdersDialogState();
}

class _UnsyncedOrdersDialogState extends State<_UnsyncedOrdersDialog> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  bool isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => isLoading = true);
    final data = await widget.repository.getUnsyncedOrdersDetail();
    if (mounted) setState(() { orders = data; isLoading = false; });
  }

  Future<void> _sync() async {
    setState(() => isSyncing = true);
    await widget.repository.syncOfflineOrders();
    await _loadData();
    if (mounted) {
      setState(() => isSyncing = false);
      widget.onSyncComplete();
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.cloud_upload_fill, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                const Text('待同步訂單', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(CupertinoIcons.refresh, color: Colors.white54, size: 20),
                  onPressed: isLoading ? null : _loadData,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: Colors.amber),
              )
            else if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('目前沒有待同步的訂單', style: TextStyle(color: Colors.white54)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    final tables = (o['table_names'] as List?)?.join(', ') ?? '—';
                    final amount = o['final_amount'] != null ? '\$${(o['final_amount'] as double).toStringAsFixed(0)}' : '—';
                    final isHub = o['source'] == 'hub';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isHub ? Colors.blue.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isHub ? '主機' : '本機',
                              style: TextStyle(fontSize: 11, color: isHub ? Colors.blue[300] : Colors.orange[300]),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(tables, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          ),
                          Text(amount, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(width: 10),
                          Text(_formatTime(o['created_at'] as String?), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('關閉', style: TextStyle(color: Colors.white54)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    onPressed: isSyncing ? null : _sync,
                    child: isSyncing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('立即同步', style: TextStyle(fontWeight: FontWeight.w600)),
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
