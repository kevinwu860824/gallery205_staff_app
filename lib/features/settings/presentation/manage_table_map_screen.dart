// lib/features/settings/presentation/manage_table_map_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 2. ManageTableMapScreen (主頁面)
// -------------------------------------------------------------------
class ManageTableMapScreen extends StatefulWidget {
  const ManageTableMapScreen({super.key});

  @override
  State<ManageTableMapScreen> createState() => _ManageTableMapScreenState();
}

class _ManageTableMapScreenState extends State<ManageTableMapScreen> {
  String selectedArea = '';
  List<String> allAreas = [];
  List<Map<String, dynamic>> tables = [];
  List<String> availableTableNames = [];

  bool isEditing = false;

  // 拖曳相關變數
  Offset? _dragStartOffset;
  Offset? _widgetStartOffset; // 儲存拖曳開始時的螢幕渲染位置
  Offset? verticalGuideLine;
  Offset? horizontalGuideLine;

  final double widgetWidth = 90;
  final double widgetHeight = 60;
  final double headerHeight = 140.0; // 預留頂部 Header 高度

  // 參考裝置尺寸（iPhone 14 Pro）
  static const double phoneCanvasWidth = 393.0;
  static const double phoneCanvasHeight = 852.0;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  // --- 資料讀取邏輯 ---
  Future<void> _loadAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final result = await Supabase.instance.client
        .from('table_area')
        .select('area_id')
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);

    final areas = List<String>.from(result.map((e) => e['area_id']));
    setState(() {
      allAreas = areas;
      if (areas.isNotEmpty && selectedArea.isEmpty) {
        selectedArea = areas.first;
      }
    });
    await _loadTables();
    await _loadAvailableTables();
  }

  Future<void> _loadAvailableTables() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null || selectedArea.isEmpty) return;

    final result = await Supabase.instance.client
        .from('tables')
        .select('table_name')
        .eq('shop_id', shopId)
        .eq('area_id', selectedArea)
        .filter('shape', 'is', null)
        .order('table_name');

    setState(() {
      availableTableNames = List<String>.from(result.map((e) => e['table_name']));
    });
  }

  Future<void> _loadTables() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null || selectedArea.isEmpty) return;

    final tableResult = await Supabase.instance.client
        .from('tables')
        .select('table_name, x, y, shape, rotation')
        .eq('shop_id', shopId)
        .eq('area_id', selectedArea);

    setState(() {
      tables = tableResult
          .map((e) => {
                'table_name': e['table_name'],
                'shape': e['shape'],
                'x': (e['x'] as num?)?.toDouble() ?? 0.0,
                'y': (e['y'] as num?)?.toDouble() ?? 0.0,
                'rotation': e['rotation'],
              })
          .where((e) =>
              e['x']! >= 0 &&
              e['y']! >= 0 &&
              e['shape'] != null)
          .toList();
    });
  }

  // --- 新增 / 刪除 / 更新邏輯 ---

  Future<void> _showAddTableDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AddTableDialog(availableTableNames: availableTableNames),
    );

    if (result != null) {
      _addTable(result['shape']!, result['name']!);
    }
  }

  Future<void> _addTable(String shape, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    // 以參考座標系置中（iPhone 14 Pro 的中間偏上）
    await Supabase.instance.client
        .from('tables')
        .update({
          'area_id': selectedArea,
          'shape': shape,
          'x': phoneCanvasWidth / 2 - 30,
          'y': headerHeight + 50,
          'rotation': 0,
        })
        .eq('shop_id', shopId)
        .eq('table_name', name);

    await _loadTables();
    await _loadAvailableTables();
  }

  Future<void> _updateTablePosition(int index, double x, double y) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final table = tables[index];
    await Supabase.instance.client
        .from('tables')
        .update({'x': x, 'y': y})
        .eq('shop_id', shopId)
        .eq('area_id', selectedArea)
        .eq('table_name', table['table_name']);
  }

  Future<void> _confirmDelete(String tableName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: l10n.tableMapRemoveTitle,
        content: l10n.tableMapRemoveContent(tableName),
        confirmText: l10n.tableMapRemoveConfirm,
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      await _removeTableFromMap(tableName);
    }
  }

  Future<void> _removeTableFromMap(String tableName) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    await Supabase.instance.client
        .from('tables')
        .update({
          'x': null,
          'y': null,
          'shape': null,
          'rotation': null,
        })
        .eq('shop_id', shopId)
        .eq('area_id', selectedArea)
        .eq('table_name', tableName);

    await _loadTables();
    await _loadAvailableTables();
  }

  void _rotateRectangle(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final current = (tables[index]['rotation'] ?? 0) as int;
    final newRotation = (current + 90) % 360;

    setState(() {
      tables[index]['rotation'] = newRotation;
    });

    await Supabase.instance.client
        .from('tables')
        .update({'rotation': newRotation})
        .eq('shop_id', shopId)
        .eq('area_id', selectedArea)
        .eq('table_name', tables[index]['table_name']);
  }

  // --- UI 建構 ---

  /// 建構單個桌子 Widget
  /// [canvasLeft]：iPad 時 canvas 左側偏移（手機為 0）
  /// [scaleX]/[scaleY]：參考座標 → 螢幕座標的縮放比例（iPad 為 1.0）
  Widget _buildTableWidget(
    Map<String, dynamic> table,
    int index, {
    double canvasLeft = 0.0,
    double canvasTop = 0.0,
    double scaleX = 1.0,
    double scaleY = 1.0,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shape = table['shape'];
    final name = table['table_name'];
    if (shape == null) return const SizedBox.shrink();

    final double size = 60;
    Widget shapeWidget;

    final TextStyle textStyle = TextStyle(
      color: colorScheme.onPrimary,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    final Color tableColor = colorScheme.primary;

    switch (shape) {
      case 'circle':
        shapeWidget = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: tableColor),
          alignment: Alignment.center,
          child: Text(name, style: textStyle),
        );
        break;
      case 'square':
        shapeWidget = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: tableColor,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(name, style: textStyle),
        );
        break;
      case 'rectangle':
        final rotation = (table['rotation'] ?? 0) as int;
        shapeWidget = Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: rotation * 3.14159265 / 180,
              child: Container(
                width: size + 30,
                height: size,
                decoration: BoxDecoration(
                  color: tableColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Text(name, style: textStyle),
          ],
        );
        break;
      default:
        shapeWidget = Container();
    }

    // 將參考座標轉換為螢幕渲染座標
    final double refX = (table['x'] as num?)?.toDouble() ?? 0.0;
    final double refY = (table['y'] as num?)?.toDouble() ?? 0.0;
    final double renderX = canvasLeft + refX * scaleX;
    final double renderY = canvasTop + (refY - headerHeight) * scaleY;

    return Positioned(
      left: renderX.clamp(0.0, double.infinity),
      top: renderY.clamp(0.0, double.infinity),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onLongPressStart: (details) {
              _dragStartOffset = details.globalPosition;
              // 儲存拖曳開始時的螢幕渲染位置
              _widgetStartOffset = Offset(renderX, renderY);
            },
            onLongPressMoveUpdate: (details) {
              if (_dragStartOffset != null && _widgetStartOffset != null) {
                final dx = details.globalPosition.dx - _dragStartOffset!.dx;
                final dy = details.globalPosition.dy - _dragStartOffset!.dy;
                // 計算新的螢幕位置，再轉換回參考座標儲存
                final newScreenX = _widgetStartOffset!.dx + dx;
                final newScreenY = _widgetStartOffset!.dy + dy;
                final newRefX = (newScreenX - canvasLeft) / scaleX;
                final newRefY = headerHeight + (newScreenY - canvasTop) / scaleY;
                setState(() {
                  tables[index]['x'] = newRefX;
                  tables[index]['y'] = newRefY;
                });
                _checkAlignment(index, newRefX, newRefY);
              }
            },
            onLongPressEnd: (_) async {
              _handleDragEnd(index, shape, size);
            },
            child: shapeWidget,
          ),

          // 編輯模式下的移除按鈕
          if (isEditing)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => _confirmDelete(table['table_name']),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),

          // 編輯模式下矩形的旋轉按鈕
          if (isEditing && table['shape'] == 'rectangle')
            Positioned(
              top: -8,
              left: -8,
              child: GestureDetector(
                onTap: () => _rotateRectangle(index),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.rotate_right, size: 16, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 輔助線檢查（使用參考座標）
  void _checkAlignment(int index, double refX, double refY) {
    for (int i = 0; i < tables.length; i++) {
      if (i == index) continue;
      final tx = (tables[i]['x'] as num).toDouble();
      final ty = (tables[i]['y'] as num).toDouble();

      if ((refX - tx).abs() < 5.0) {
        setState(() => verticalGuideLine = Offset(refX + widgetWidth / 2, 0));
      } else {
        setState(() => verticalGuideLine = null);
      }

      if ((refY - ty).abs() < 5.0) {
        setState(() => horizontalGuideLine = Offset(0, refY + widgetHeight / 2));
      } else {
        setState(() => horizontalGuideLine = null);
      }
    }
  }

  /// 拖曳結束處理：在參考座標系內做邊界限制，再存回資料庫
  Future<void> _handleDragEnd(int index, String? shape, double size) async {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final safeBottom = mediaQuery.padding.bottom;
    final bool isTablet = mediaQuery.size.shortestSide >= 600;

    // 計算縮放比例
    final double scaleX = isTablet ? 1.0 : screenWidth / phoneCanvasWidth;
    final double availableHeight = screenHeight - safeBottom - headerHeight;
    final double canvasDisplayHeight = (phoneCanvasHeight - headerHeight).clamp(0.0, screenHeight - headerHeight - safeBottom);
    final double scaleY = isTablet
        ? canvasDisplayHeight / (phoneCanvasHeight - headerHeight)
        : availableHeight / (phoneCanvasHeight - headerHeight);

    final double wWidth = shape == 'rectangle' ? size + 30 : size;
    final double wHeight = size;

    // 轉換為參考座標系的 widget 尺寸，計算邊界
    final double refWWidth = wWidth / scaleX;
    final double refWHeight = wHeight / scaleY;

    double x = (tables[index]['x'] as num).toDouble();
    double y = (tables[index]['y'] as num).toDouble();

    // 在參考座標系內限制範圍
    x = x.clamp(0.0, phoneCanvasWidth - refWWidth);
    y = y.clamp(headerHeight, phoneCanvasHeight - refWHeight);

    setState(() {
      tables[index]['x'] = x;
      tables[index]['y'] = y;
      verticalGuideLine = null;
      horizontalGuideLine = null;
    });

    await _updateTablePosition(index, x, y);
    _dragStartOffset = null;
    _widgetStartOffset = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    // iPad：canvas 置中，尺寸固定為參考裝置大小（1:1）
    // 手機：canvas 佔全寬，依比例縮放座標
    final double canvasLeft = isTablet ? (screenWidth - phoneCanvasWidth) / 2 : 0.0;
    final double canvasTop = headerHeight - 50.0; // 整體往上移 50px
    final double availableHeight = screenHeight - safeBottom - headerHeight;
    // canvas 區域從 header 底部開始，高度 = 852-140 = 712，若螢幕不夠高則自動縮減
    final double canvasDisplayHeight = (phoneCanvasHeight - headerHeight).clamp(0.0, screenHeight - headerHeight - safeBottom);
    final double scaleX = isTablet ? 1.0 : screenWidth / phoneCanvasWidth;
    final double scaleY = isTablet
        ? canvasDisplayHeight / (phoneCanvasHeight - headerHeight)
        : availableHeight / (phoneCanvasHeight - headerHeight);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. 桌位區域
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                // iPad：顯示固定尺寸的手機顯示範圍框（393 × 712）
                if (isTablet)
                  Positioned(
                    left: canvasLeft,
                    top: canvasTop,
                    width: phoneCanvasWidth,
                    height: canvasDisplayHeight,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.onSurface.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '手機顯示範圍',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.3),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                ...tables.asMap().entries.map((e) => _buildTableWidget(
                  e.value,
                  e.key,
                  canvasLeft: canvasLeft,
                  canvasTop: canvasTop,
                  scaleX: scaleX,
                  scaleY: scaleY,
                )),

                // 輔助線（參考座標轉換為螢幕座標後渲染）
                if (verticalGuideLine != null)
                  Positioned(
                    left: canvasLeft + verticalGuideLine!.dx * scaleX,
                    top: canvasTop,
                    bottom: 0,
                    child: Container(width: 1, color: Colors.grey),
                  ),
                if (horizontalGuideLine != null)
                  Positioned(
                    top: canvasTop + (horizontalGuideLine!.dy - headerHeight) * scaleY,
                    left: canvasLeft,
                    width: isTablet ? phoneCanvasWidth : null,
                    right: isTablet ? null : 0,
                    child: Container(height: 1, color: Colors.grey),
                  ),
              ],
            ),
          ),

          // 2. 自訂 Header (固定在頂部)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Row(
                      children: [
                        // 返回按鈕
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
                          onPressed: () => context.pop(),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 區域下拉選單
                            Theme(
                              data: theme.copyWith(canvasColor: theme.cardColor),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedArea.isNotEmpty ? selectedArea : null,
                                  icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => selectedArea = value);
                                      _loadTables();
                                      _loadAvailableTables();
                                    }
                                  },
                                  items: allAreas.map((area) => DropdownMenuItem(
                                    value: area,
                                    child: Text('$area${l10n.tableMapAreaSuffix}'),
                                  )).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 編輯按鈕
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: Icon(
                                isEditing ? CupertinoIcons.check_mark_circled : CupertinoIcons.pencil,
                                color: colorScheme.onSurface,
                                size: 28,
                              ),
                              onPressed: () => setState(() => isEditing = !isEditing),
                            ),
                            const SizedBox(width: 8),
                            // 新增按鈕
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _showAddTableDialog,
                              child: Icon(CupertinoIcons.add, color: colorScheme.onSurface, size: 28),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 自訂 Dialogs
// -------------------------------------------------------------------

class _AddTableDialog extends StatefulWidget {
  final List<String> availableTableNames;
  const _AddTableDialog({required this.availableTableNames});

  @override
  State<_AddTableDialog> createState() => _AddTableDialogState();
}

class _AddTableDialogState extends State<_AddTableDialog> {
  String selectedShape = 'square';
  String? selectedName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double dialogHPadding = isTablet ? (MediaQuery.of(context).size.width - 480) / 2 : 40.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: dialogHPadding),
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
              l10n.tableMapAddDialogTitle,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // 形狀選擇
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShapeButton(
                  icon: Icons.circle,
                  label: l10n.tableMapShapeCircle,
                  isSelected: selectedShape == 'circle',
                  onTap: () => setState(() => selectedShape = 'circle'),
                ),
                _ShapeButton(
                  icon: Icons.square,
                  label: l10n.tableMapShapeSquare,
                  isSelected: selectedShape == 'square',
                  onTap: () => setState(() => selectedShape = 'square'),
                ),
                _ShapeButton(
                  icon: Icons.rectangle,
                  label: l10n.tableMapShapeRect,
                  isSelected: selectedShape == 'rectangle',
                  onTap: () => setState(() => selectedShape = 'rectangle'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 桌號選擇 (Dropdown)
            if (widget.availableTableNames.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: Text(l10n.tableMapAddDialogHint, style: const TextStyle(color: Colors.grey)),
                    value: selectedName,
                    icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                    items: widget.availableTableNames.map((name) {
                      return DropdownMenuItem(value: name, child: Text(name));
                    }).toList(),
                    onChanged: (value) => setState(() => selectedName = value),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.tableMapNoAvailableTables, style: const TextStyle(color: Colors.grey)),
              ),

            const SizedBox(height: 24),

            // 按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DialogWhiteButton(
                  text: l10n.commonCancel,
                  onPressed: () => Navigator.of(context).pop(null),
                  buttonColor: theme.cardColor,
                  textColor: colorScheme.onSurface,
                ),
                const SizedBox(width: 20),
                _DialogWhiteButton(
                  text: l10n.commonAdd,
                  onPressed: selectedName != null
                    ? () => Navigator.of(context).pop({'shape': selectedShape, 'name': selectedName!})
                    : null,
                  buttonColor: colorScheme.primary,
                  textColor: colorScheme.onPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShapeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShapeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedColor = colorScheme.primary;
    final unselectedColor = Colors.grey;
    final textColor = colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? selectedColor : unselectedColor,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? colorScheme.onPrimary : unselectedColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? textColor : unselectedColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final bool isDestructive;

  const _ConfirmDialog({
    required this.title,
    required this.content,
    required this.confirmText,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final double dialogHPadding = isTablet ? (MediaQuery.of(context).size.width - 480) / 2 : 40.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: dialogHPadding),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(content, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DialogWhiteButton(
                   text: l10n.commonCancel,
                   onPressed: () => Navigator.of(context).pop(false),
                   buttonColor: theme.cardColor,
                   textColor: colorScheme.onSurface,
                ),
                const SizedBox(width: 20),
                _DialogWhiteButton(
                  text: confirmText,
                  onPressed: () => Navigator.of(context).pop(true),
                  buttonColor: isDestructive ? colorScheme.error : colorScheme.primary,
                  textColor: isDestructive ? colorScheme.onError : colorScheme.onPrimary,
                ),
              ],
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
  final Color? buttonColor;
  final Color? textColor;

  const _DialogWhiteButton({
    required this.text,
    this.onPressed,
    this.buttonColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor ?? Theme.of(context).colorScheme.primary,
          disabledBackgroundColor: Colors.grey[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: EdgeInsets.zero,
        ),
        child: Text(text, style: TextStyle(color: textColor ?? Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
