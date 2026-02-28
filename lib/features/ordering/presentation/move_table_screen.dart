// lib/features/ordering/presentation/move_table_screen.dart

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

class MoveTableScreen extends StatefulWidget {
  final String groupKey; 
  final List<String> currentSeats; 

  const MoveTableScreen({
    super.key,
    required this.groupKey,
    required this.currentSeats,
  });

  @override
  State<MoveTableScreen> createState() => _MoveTableScreenState();
}

class _MoveTableScreenState extends State<MoveTableScreen> {
  OrderingRepositoryImpl? _repository;
  
  List<AreaModel> areas = [];
  String? selectedAreaId;
  List<TableModel> tables = [];
  bool isLoading = true;

  final Set<String> _currentSelection = {};

  @override
  void initState() {
    super.initState();
    // 移除預設勾選現在的桌位，讓使用者直接點擊新桌位即可
    // _currentSelection.addAll(widget.currentSeats);
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
      if (_repository == null) {
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
  // 互動邏輯 (Move Only)
  // ----------------------------------------------------------------

  void _onTableTap(TableModel targetTable) {
    final tableName = targetTable.tableName;
    final isSelected = _currentSelection.contains(tableName);

    // 情境 A: 已經被選取 -> 取消選取 (釋放)
    if (isSelected) {
      setState(() {
        _currentSelection.remove(tableName);
      });
      return;
    }

    // 情境 B: 選回自己 (如果之前被取消的話)
    if (widget.currentSeats.contains(tableName)) {
      setState(() {
        _currentSelection.add(tableName);
      });
      return;
    }

    // 情境 C: 空桌 -> 加桌/換桌
    if (targetTable.status != TableStatus.occupied) {
      setState(() {
        _currentSelection.add(tableName);
      });
      return;
    }

    // 情境 D: 別人的桌子 -> 禁止 (請用併桌)
    if (targetTable.status == TableStatus.occupied && 
        targetTable.currentOrderGroupId != widget.groupKey) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("此桌位已有人，請使用「併桌」功能")));
      return;
    }
  }

  // ----------------------------------------------------------------
  // 提交變更 (Move Logic Only)
  // ----------------------------------------------------------------

  Future<void> _processMove() async {
    // 必須至少選擇一張桌子
    if (_currentSelection.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請至少選擇一個桌位")));
       return;
    }
    
    // 如果選擇跟原本完全一樣，不需要做任何事
    final bool isSame = _currentSelection.length == widget.currentSeats.length && 
                        _currentSelection.containsAll(widget.currentSeats);
    if (isSame) {
       context.pop();
       return;
    }

    setState(() => isLoading = true);
    setState(() => isLoading = true);

    try {
      if (_repository == null) return;
      
      await _repository!.moveTable(
        hostGroupId: widget.groupKey,
        oldTables: widget.currentSeats,
        newTables: _currentSelection.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 桌位已更新")));
        context.pop();
      }
    } catch (e) {
      debugPrint("Save error: $e");
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
    final bool isConfirmEnabled = _currentSelection.isNotEmpty;

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
                    onPressed: isConfirmEnabled ? _processMove : null,
                    child: Text(
                      "確認換桌 (${_currentSelection.length})",
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
                child: const Text("選擇新的桌位以進行搬移", style: TextStyle(color: Colors.white70, fontSize: 13)),
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
    
    // Status Logic for Visuals
    if (table.status == TableStatus.occupied) {
      if (widget.currentSeats.contains(table.tableName)) {
        // Own table (Selected likely)
        if (table.colorIndex != null) {
          tableColor = _groupColors[table.colorIndex! % _groupColors.length];
        } else {
          final int hash = table.currentOrderGroupId.hashCode;
          final int colorIndex = hash.abs() % _groupColors.length;
          tableColor = _groupColors[colorIndex];
        }
      } else {
        // Other occupied -> Grey out
        tableColor = Colors.grey.withOpacity(0.3);
      }
      textColor = Colors.white; 
    } else {
      // Empty
      tableColor = Theme.of(context).colorScheme.onSurface; 
      textColor = Theme.of(context).colorScheme.surface;
    }

    final bool isSelected = _currentSelection.contains(table.tableName);
    final double size = 60.0;
    
    final TextStyle textStyle = TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14);

    Widget container(double w, double h, BoxShape shape, [BorderRadius? radius]) {
      // Determine contrast color for border
      Color borderColor = Colors.white;
      if (isSelected) {
         if (ThemeData.estimateBrightnessForColor(tableColor) == Brightness.light) {
            borderColor = Colors.black;
         } else {
            borderColor = Colors.white;
         }
      }

      return Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: tableColor,
          shape: shape,
          borderRadius: radius,
          border: isSelected ? Border.all(color: borderColor, width: 4) : null,
          boxShadow: isSelected ? [BoxShadow(color: borderColor.withOpacity(0.5), blurRadius: 10)] : null, 
        ),
        alignment: Alignment.center,
        child: Text(table.tableName, style: textStyle),
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