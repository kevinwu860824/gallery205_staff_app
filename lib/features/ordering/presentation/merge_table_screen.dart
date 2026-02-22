// lib/features/ordering/presentation/merge_table_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../data/repositories/ordering_repository_impl.dart'; 
import '../data/datasources/ordering_remote_data_source.dart'; 
import '../domain/models/table_model.dart';

// -------------------------------------------------------------------
// 1. 樣式與色盤 (保持 20 色)
// -------------------------------------------------------------------
const List<Color> _groupColors = [
      Color(0xFF0A84FF), // Blue
      Color(0xFF32D74B), // Green
      Color(0xFFFF9F0A), // Orange
      Color(0xFFFF453A), // Red
      Color(0xFF5E5CE6), // Indigo
      Color(0xFFBF5AF2), // Purple
      Color(0xFF64D2FF), // Light Blue
      Color(0xFF30D158), // Emerald Green
      Color(0xFFD1D1D6), // Light Grey
  ];

class MergeTableScreen extends StatefulWidget {
  final String groupKey; 
  final List<String> currentSeats; 

  const MergeTableScreen({
    super.key,
    required this.groupKey,
    required this.currentSeats,
  });

  @override
  State<MergeTableScreen> createState() => _MergeTableScreenState();
}

class _MergeTableScreenState extends State<MergeTableScreen> {
  OrderingRepositoryImpl? _repository;
  
  List<AreaModel> areas = [];
  String? selectedAreaId;
  List<TableModel> tables = [];
  bool isLoading = true;

  // 記錄 User 想要合併進來的目標 Group IDs
  final Set<String> _pendingMergeGroups = {};

  // 記錄 User 想要「拆桌 (取消合併)」的 Group IDs
  final Set<String> _pendingUnmergeGroups = {}; 

  // 已合併的子群組 (從 DB 讀取)
  final Set<String> _mergedChildGroups = {};

  // 用於 UI 顯示已選的桌子 (包含自己 + 準備合併的桌子)
  final Set<String> _visualSelection = {};

  @override
  void initState() {
    super.initState();
    _visualSelection.addAll(widget.currentSeats);
    _initData();
  }

  Future<void> _initData() async {
    setState(() => isLoading = true);
    try {
      if (_repository == null) {
        final prefs = await SharedPreferences.getInstance();
        final client = Supabase.instance.client;
        final dataSource = OrderingRemoteDataSourceImpl(client);
        _repository = OrderingRepositoryImpl(dataSource, prefs);
      }

      final fetchedAreas = await _repository!.fetchAreas();
      
      // 2. Fetch Merged Child Groups
      final childHeaders = await _repository!.fetchMergedChildGroups(widget.groupKey);
      _mergedChildGroups.addAll(childHeaders);

      if (fetchedAreas.isNotEmpty) {
        final initialArea = fetchedAreas.first.id;
        areas = fetchedAreas;
        await _loadTablesForArea(initialArea);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadTablesForArea(String areaId) async {
    setState(() => isLoading = true);
    try {
      if (_repository == null) { // Safety check
         // ... (init if needed, but likely already done)
         return; 
      }
      final fetchedTables = await _repository!.fetchTablesInArea(areaId);
      setState(() {
        tables = fetchedTables;
        selectedAreaId = areaId;
      });
    } catch (e) {
      debugPrint("Load tables error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ----------------------------------------------------------------
  // 互動邏輯 (Merge Mode)
  // ----------------------------------------------------------------

  void _onTableTap(TableModel targetTable) {
    if (targetTable.status != TableStatus.occupied) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("此桌為空桌，請使用「換桌」功能")));
      return;
    }

    final String targetGroupId = targetTable.currentOrderGroupId!;

    // 情境 A: 點擊的是「已經合併進來的子桌」 -> 觸發拆桌 (Un-merge)
    if (_mergedChildGroups.contains(targetGroupId)) {
      setState(() {
         if (_pendingUnmergeGroups.contains(targetGroupId)) {
           _pendingUnmergeGroups.remove(targetGroupId);
         } else {
           _pendingUnmergeGroups.add(targetGroupId);
         }
      });
      return;
    }

    // 情境 B: 本桌 (Host) -> 不可取消
    if (widget.currentSeats.contains(targetTable.tableName)) {
      return; 
    }

    // 情境 C: 自己的 Group (包含了 Host + 已合併的) -> 已經透過 情境A 處理了已合併的部分
    // 如果是 Host 本身 (非 child)，則不動作
    if (targetGroupId == widget.groupKey) {
      return;
    }

    // 情境 D: 別人的桌子 (Occupied by others) -> Toggle Merge (併桌)
    
    // [New Rule] 如果目前 Group 已經是併桌後的狀態 (有 Child Groups)，則不允許再併入新桌子
    // 必須先拆桌回到原始狀態，才能重新組合
    if (_mergedChildGroups.isNotEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("此訂單包含已合併的桌子，請先「拆桌」還原後再重新合併")));
      return;
    }

    // 找出該 Group 所有的桌子
    final sameGroupTables = tables
        .where((t) => t.currentOrderGroupId == targetGroupId)
        .map((t) => t.tableName)
        .toList();

    setState(() {
      if (_pendingMergeGroups.contains(targetGroupId)) {
        // 取消選取
        _pendingMergeGroups.remove(targetGroupId);
        _visualSelection.removeAll(sameGroupTables);
      } else {
        // 選取合併
        _pendingMergeGroups.add(targetGroupId);
        _visualSelection.addAll(sameGroupTables);
      }
    });
  }

  // ----------------------------------------------------------------
  // 提交變更 (Process Merge)
  // ----------------------------------------------------------------

  Future<void> _processMerge() async {
    if (_pendingMergeGroups.isEmpty && _pendingUnmergeGroups.isEmpty) return;
    
    setState(() => isLoading = true);
    
    try {
      if (_repository == null) return; // Should be init

      // Part A: Merge
      if (_pendingMergeGroups.isNotEmpty) {
        await _repository!.mergeOrderGroups(
          hostGroupId: widget.groupKey,
          targetGroupIds: _pendingMergeGroups.toList(),
        );
      }

      // Part B: Unmerge
      if (_pendingUnmergeGroups.isNotEmpty) {
        await _repository!.unmergeOrderGroups(
          hostGroupId: widget.groupKey,
          targetGroupIds: _pendingUnmergeGroups.toList(),
        );
      }

      if (mounted) {
        String msg = "✅ 更新完成";
        if (_pendingMergeGroups.isNotEmpty) msg += " (併入了 ${_pendingMergeGroups.length} 桌)";
        if (_pendingUnmergeGroups.isNotEmpty) msg += " (拆除了 ${_pendingUnmergeGroups.length} 桌)";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        context.pop();
      }
    } catch (e) {
      debugPrint("Update error: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("更新失敗: $e")));
      }
    }
  }

  // ----------------------------------------------------------------
  // UI 構建
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final safePaddingTop = MediaQuery.of(context).padding.top;
    final bool isConfirmEnabled = _pendingMergeGroups.isNotEmpty || _pendingUnmergeGroups.isNotEmpty;

    String btnText = "確認";
    if (_pendingMergeGroups.isNotEmpty) btnText += " 併 ${_pendingMergeGroups.length} 桌";
    if (_pendingUnmergeGroups.isNotEmpty) btnText += " 拆 ${_pendingUnmergeGroups.length} 桌";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. 地圖層
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: isLoading 
              ? Center(child: CupertinoActivityIndicator(color: Theme.of(context).colorScheme.onSurface))
              : Stack(
                  children: tables.map((table) => _buildTableItem(table)).toList(),
                ),
          ),

          // 2. Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
              padding: EdgeInsets.only(top: safePaddingTop + 10, bottom: 10, left: 16, right: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(CupertinoIcons.back, color: Theme.of(context).colorScheme.onSurface, size: 28),
                    onPressed: () => context.pop(),
                  ),
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  area.id,
                                  style: TextStyle(
                                    color: isSelected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
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
                ],
              ),
            ),
          ),

          // 3. 底部確認按鈕
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                    color: isConfirmEnabled ? Theme.of(context).colorScheme.onSurface : Theme.of(context).disabledColor,
                    borderRadius: BorderRadius.circular(30),
                    onPressed: isConfirmEnabled ? _processMerge : null,
                    child: Text(
                      btnText,
                      style: TextStyle(
                        color: isConfirmEnabled ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface.withOpacity(0.5), 
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 4. 頂部提示
          Positioned(
            top: safePaddingTop + 70, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: const Text("點選其他桌位進行「併桌」，或點選已併桌位進行「拆桌」", style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableItem(TableModel table) {
    Color tableColor;
    Color textColor;
    
    final bool isSelf = widget.currentSeats.contains(table.tableName);
    bool isSelectedMerge = _pendingMergeGroups.contains(table.currentOrderGroupId);
    
    // Check if this table belongs to a currently "merged child" group
    final bool isMergedChild = table.currentOrderGroupId != null && 
                               _mergedChildGroups.contains(table.currentOrderGroupId);
    
    // Check if user wants to un-merge this child
    final bool isSelectedUnmerge = isMergedChild && 
                                   _pendingUnmergeGroups.contains(table.currentOrderGroupId);

    if (table.status == TableStatus.occupied) {
      // Calculate group color for ANY occupied table
      Color groupColor = Colors.grey;
      if (table.currentOrderGroupId != null) {
        if (table.colorIndex != null) {
          groupColor = _groupColors[table.colorIndex! % _groupColors.length];
        } else {
          final int hash = table.currentOrderGroupId.hashCode;
          final int colorIndex = hash.abs() % _groupColors.length;
          groupColor = _groupColors[colorIndex];
        }
      }

      if (isSelf) {
        tableColor = groupColor; 
      } else if (isSelectedMerge) {
        tableColor = groupColor; 
      } else if (isMergedChild) {
        // 已合併的桌子：如果選了要拆，就保持原色(or dim?)；如果沒選要拆，就保持原色
        // 重點是 Border 或 Icon 要不一樣
        tableColor = groupColor;
      } else {
        // Other occupied tables -> Dim out
        tableColor = groupColor.withOpacity(0.5); 
      }
      textColor = Colors.white; 
    } else {
      // Empty tables
      tableColor = Theme.of(context).cardColor;
      textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.3); 
    }

    final double size = 60.0;
    
    final TextStyle textStyle = TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14);

    Widget container(double w, double h, BoxShape shape, [BorderRadius? radius]) {
      // Determine contrast color for border
      Color borderColor = Colors.white;
      if (isSelf || isSelectedMerge || isSelectedUnmerge) {
         if (ThemeData.estimateBrightnessForColor(tableColor) == Brightness.light) {
            borderColor = Colors.black;
         } else {
            borderColor = Colors.white;
         }
      }

      // Icon Logic
      Widget? overlayIcon;
      if (isSelectedMerge) {
        overlayIcon = Icon(CupertinoIcons.add_circled_solid, color: borderColor, size: 24);
      } else if (isSelectedUnmerge) {
        overlayIcon = Icon(CupertinoIcons.minus_circle_fill, color: borderColor, size: 24);
      }

      return Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: tableColor,
          shape: shape,
          borderRadius: radius,
          border: (isSelf || isSelectedMerge || isSelectedUnmerge) ? Border.all(color: borderColor, width: 2) : null,
          boxShadow: (isSelf || isSelectedMerge || isSelectedUnmerge) ? [BoxShadow(color: Colors.black26, blurRadius: 8)] : null, 
        ),
        alignment: Alignment.center,
        child: overlayIcon ?? Text(table.tableName, style: textStyle.copyWith(color: borderColor == Colors.black ? Colors.black : Colors.white)),
      );
    }

    Widget shapeWidget;
    switch (table.shape) {
      case 'circle':
        shapeWidget = container(size, size, BoxShape.circle);
        break;
      case 'rectangle':
        shapeWidget = Transform.rotate(
          angle: table.rotation * 3.14159265 / 180,
          child: container(size + 30, size, BoxShape.rectangle, BorderRadius.circular(8)),
        );
        break;
      case 'square':
      default:
        shapeWidget = container(size, size, BoxShape.rectangle, BorderRadius.circular(8));
        break;
    }
    
    return Positioned(
      left: table.x,
      top: table.y,
      child: GestureDetector(
        onTap: () => _onTableTap(table),
        child: shapeWidget,
      ),
    );
  }
}
