// lib/features/settings/presentation/manage_tables_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 1. 桌位管理主頁面 (ManageTablesScreen)
// -------------------------------------------------------------------

class ManageTablesScreen extends StatefulWidget {
  const ManageTablesScreen({super.key});

  @override
  State<ManageTablesScreen> createState() => _ManageTablesScreenState();
}

class _ManageTablesScreenState extends State<ManageTablesScreen> {
  bool isEditing = false;
  Map<String, List<String>> tableData = {};

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final areaRes = await Supabase.instance.client
        .from('table_area')
        .select('area_id')
        .eq('shop_id', shopId)
        .order('sort_order', ascending: true);

    final data = <String, List<String>>{};
    for (final row in areaRes) {
      final area = row['area_id'] as String;

      final tableRes = await Supabase.instance.client
          .from('tables')
          .select('table_name')
          .eq('shop_id', shopId)
          .eq('area_id', area)
          .order('sort_order', ascending: true);

      data[area] = List<String>.from(tableRes.map((e) => e['table_name']));
    }

    setState(() => tableData = data);
  }

  Future<void> _addArea() async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddEditDialog(
        title: l10n.tableMgmtAreaListAddTitle,
        hintText: l10n.tableMgmtAreaListHintName,
        existingNames: tableData.keys.toList(),
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        await Supabase.instance.client.from('table_area').insert({
          'shop_id': shopId,
          'area_id': name,
          'sort_order': tableData.keys.length, // 初始排序
        });

        await _loadTables();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tableMgmtAreaAddSuccess(name))),
        );
      } catch (e) {
        debugPrint('❌ 新增區域失敗: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tableMgmtAreaAddFailure)),
        );
      }
    }
  }

  Future<void> _editArea(String oldName) async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _AddEditDialog(
        title: l10n.tableMgmtAreaListEditTitle,
        hintText: l10n.tableMgmtAreaListHintName,
        initialName: oldName,
        existingNames: tableData.keys.toList(),
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      try {
        await Supabase.instance.client
            .from('table_area')
            .update({'area_id': newName})
            .eq('shop_id', shopId)
            .eq('area_id', oldName);
        
        // 級聯更新 'tables' 中的 area_id
        await Supabase.instance.client
            .from('tables')
            .update({'area_id': newName})
            .eq('shop_id', shopId)
            .eq('area_id', oldName);
            
        await _loadTables();
      } catch (e) {
        debugPrint('❗ 編輯區域發生錯誤: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonSaveFailure)), 
        );
      }
    }
  }


  Future<void> _deleteArea(String area) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        title: l10n.tableMgmtAreaListDeleteTitle,
        content: l10n.tableMgmtAreaListDeleteContent(area),
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final shopId = prefs.getString('savedShopId');
        if (shopId == null) return;

        // 刪除區域
        await Supabase.instance.client
            .from('table_area')
            .delete()
            .eq('shop_id', shopId)
            .eq('area_id', area);

        // 級聯刪除該區域所有桌子
        await Supabase.instance.client
            .from('tables')
            .delete()
            .eq('shop_id', shopId)
            .eq('area_id', area);

        debugPrint('✅ 區域 $area 已刪除');
        await _loadTables();
      } catch (e) {
        debugPrint('❗ 刪除區域發生錯誤: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonDeleteFailure)),
        );
      }
    }
  }

  void _navigateToAreaDetail(String area) {
    context.push('/manageTablesDetail', extra: area)
      .then((_) => _loadTables());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final keys = tableData.keys.toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.tableMgmtTitle, // 'Table Management'
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: () => setState(() => isEditing = !isEditing),
            child: Icon(
              isEditing ? CupertinoIcons.check_mark_circled : CupertinoIcons.pencil, 
              color: colorScheme.onSurface, 
              size: 24,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), 
        children: [
          // 區域列表卡片
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                // 列表
                isEditing
                    ? ReorderableListView( 
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        
                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex--;

                          // 1. 更新本地狀態
                          final keysList = tableData.keys.toList();
                          final movedKey = keysList.removeAt(oldIndex);
                          keysList.insert(newIndex, movedKey);

                          setState(() {
                            tableData = {for (final k in keysList) k: tableData[k]!};
                          });

                          // 2. 更新 Supabase
                          final prefs = await SharedPreferences.getInstance();
                          final shopId = prefs.getString('savedShopId');
                          
                          for (int i = 0; i < keysList.length; i++) {
                            await Supabase.instance.client
                                .from('table_area')
                                .update({'sort_order': i}) // 將 index 存入 sort_order
                                .eq('shop_id', shopId!)
                                .eq('area_id', keysList[i]);
                          }
                        },
                        children: keys.asMap().entries.map<Widget>((entry) {
                          final i = entry.key;
                          final area = entry.value;

                          return Column(
                            key: ValueKey(area),
                            children: [
                              _CustomTile(
                                title: area,
                                isEditing: true,
                                reorderIndex: i,
                                onDelete: () => _deleteArea(area),
                                onEdit: () => _editArea(area), // 編輯區域名稱
                                onTap: () => _navigateToAreaDetail(area), // 點擊進入
                              ),
                              if (i < keys.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        }).toList(),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: keys.length,
                        itemBuilder: (_, index) {
                          final area = keys[index];
                          return Column(
                            children: [
                              _CustomTile(
                                title: area,
                                isEditing: false,
                                onTap: () => _navigateToAreaDetail(area),
                              ),
                              if (index < keys.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        },
                      ),
                      
                
                // ＋ Add New Area (移入卡片內部)
                if (keys.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                  ),
                
                CupertinoButton(
                  onPressed: _addArea,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    l10n.tableMgmtAreaListAddButton, // '＋ Add New Area'
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 2. 區域/桌位卡片元件 (_CustomTile)
// -------------------------------------------------------------------

class _CustomTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool isEditing;
  final int? reorderIndex;

  const _CustomTile({
    required this.title,
    required this.isEditing,
    this.onTap,
    this.onDelete,
    this.onEdit,
    this.reorderIndex,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (isEditing) {
      // 編輯模式
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 刪除按鈕
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
              onPressed: onDelete,
            ),
            const SizedBox(width: 10),
            // 名稱 (點擊編輯)
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: onEdit, 
                child: Text(
                  title,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
              ),
            ),
            // 排序手柄
            if (reorderIndex != null) // 僅在需要排序時顯示
              ReorderableDragStartListener(
                index: reorderIndex!, 
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(CupertinoIcons.bars, color: colorScheme.onSurface),
                ),
              ),
          ],
        ),
      );
    } else {
      // 正常模式
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
        onPressed: onTap, // 正常模式點擊是進入下一頁
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurface, size: 20),
          ],
        ),
      );
    }
  }
}


// -------------------------------------------------------------------
// 3. 桌位詳情頁面 (AreaDetailScreen)
// -------------------------------------------------------------------

class AreaDetailScreen extends StatefulWidget {
  final String area;
  const AreaDetailScreen({super.key, required this.area});

  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  bool isEditing = false;
  List<String> tables = [];

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final response = await Supabase.instance.client
        .from('tables')
        .select('table_name')
        .eq('shop_id', shopId)
        .eq('area_id', widget.area)
        .order('sort_order', ascending: true);

    setState(() {
      tables = List<String>.from(response.map((e) => e['table_name']));
    });
  }

  Future<void> _addTable() async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddEditDialog(
        title: l10n.tableMgmtTableListAddTitle, // 'Add New Table'
        hintText: l10n.tableMgmtTableListHintName, // 'Table Name'
        existingNames: tables,
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        await Supabase.instance.client.from('tables').insert({
          'shop_id': shopId,
          'area_id': widget.area,
          'table_name': name,
          'sort_order': tables.length, // 初始排序
        });
        await _loadTables();
      } catch (e) {
        debugPrint('❗ 新增桌位失敗: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tableMgmtTableAddFailure)),
        );
      }
    }
  }
  
  Future<void> _editTable(String oldName) async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _AddEditDialog(
        title: l10n.tableMgmtTableListEditTitle, // 'Edit Table'
        hintText: l10n.tableMgmtTableListHintName, // 'Table Name'
        initialName: oldName,
        existingNames: tables,
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      try {
        await Supabase.instance.client
            .from('tables')
            .update({'table_name': newName})
            .eq('shop_id', shopId)
            .eq('area_id', widget.area)
            .eq('table_name', oldName);
            
        await _loadTables();
      } catch (e) {
        debugPrint('❗ 編輯桌位發生錯誤: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commonSaveFailure)), 
        );
      }
    }
  }


  Future<void> _deleteTable(String table) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        title: l10n.tableMgmtTableListDeleteTitle, // 'Delete Table'
        content: l10n.tableMgmtTableListDeleteContent(table), // 'Are you sure to delete Table $table?'
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId');
      if (shopId == null) return;

      try {
        await Supabase.instance.client
            .from('tables')
            .delete()
            .eq('shop_id', shopId)
            .eq('area_id', widget.area)
            .eq('table_name', table);

        await _loadTables();
      } catch (e) {
        debugPrint('❗ 刪除桌位失敗: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tableMgmtTableDeleteFailure)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 30),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.area, // 顯示區域名稱
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: () => setState(() => isEditing = !isEditing),
            child: Icon(
              isEditing ? CupertinoIcons.check_mark_circled : CupertinoIcons.pencil, 
              color: colorScheme.onSurface, 
              size: 24,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                // 列表
                isEditing
                    ? ReorderableListView( 
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,

                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex--;
                          
                          // 1. 更新本地狀態
                          final item = tables.removeAt(oldIndex);
                          tables.insert(newIndex, item);
                          
                          setState(() {}); // 立即更新 UI

                          // 2. 更新 Supabase
                          final prefs = await SharedPreferences.getInstance();
                          final shopId = prefs.getString('savedShopId');

                          for (int i = 0; i < tables.length; i++) {
                            await Supabase.instance.client
                                .from('tables')
                                .update({'sort_order': i}) // 將 index 存入 sort_order
                                .eq('shop_id', shopId!)
                                .eq('area_id', widget.area)
                                .eq('table_name', tables[i]);
                          }
                        },
                        children: tables.asMap().entries.map<Widget>((entry) {
                          final i = entry.key;
                          final table = entry.value;

                          return Column(
                            key: ValueKey(table),
                            children: [
                              _CustomTile(
                                title: table,
                                isEditing: true,
                                reorderIndex: i,
                                onDelete: () => _deleteTable(table),
                                onEdit: () => _editTable(table), // 編輯桌位名稱
                                onTap: () => _editTable(table), // 點擊進入
                              ),
                              if (i < tables.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        }).toList(),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: tables.length,
                        itemBuilder: (_, index) {
                          final table = tables[index];
                          return Column(
                            children: [
                              _CustomTile(
                                title: table,
                                isEditing: false,
                                onTap: () => _editTable(table), // 正常模式點擊也是編輯
                              ),
                              if (index < tables.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                                )
                            ],
                          );
                        },
                      ),
                
                // ＋ Add New Table (移入卡片內部)
                if (tables.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(color: colorScheme.onSurface, height: 1, thickness: 0.5),
                  ),
                
                CupertinoButton(
                  onPressed: _addTable,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    l10n.tableMgmtTableListAddButton, // '＋ Add New Table'
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// -------------------------------------------------------------------
// 4. 輔助 Dialog 類別 (新增/編輯)
// -------------------------------------------------------------------

class _AddEditDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String? initialName;
  final List<String> existingNames;

  const _AddEditDialog({
    required this.title,
    required this.hintText,
    required this.existingNames,
    this.initialName,
  });

  @override
  State<_AddEditDialog> createState() => _AddEditDialogState();
}

class _AddEditDialogState extends State<_AddEditDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final name = controller.text.trim();
    if (name.isEmpty) return;

    if (widget.initialName == null && widget.existingNames.contains(name)) {
      // 新增模式下，檢查到名稱重複
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonNameExists)), // 使用通用名稱重複鍵
      );
      return; 
    }
    
    Navigator.of(context).pop(name);
  }

  InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
        filled: true,
        fillColor: theme.scaffoldBackgroundColor, // 對比色
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditMode = widget.initialName != null;
    
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
              widget.title,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: controller,
              decoration: _buildInputDecoration(hintText: widget.hintText, context: context),
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null), 
                  child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface, fontSize: 16)) 
                ),
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                    child: Text(
                      isEditMode ? l10n.commonSave : l10n.commonAdd, 
                      style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w500)
                    ),
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

// -------------------------------------------------------------------
// 5. 輔助 Dialog 類別 (刪除確認)
// -------------------------------------------------------------------

class _DeleteDialog extends StatelessWidget {
  final String title;
  final String content;

  const _DeleteDialog({required this.title, required this.content});

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
        height: 183, 
        decoration: BoxDecoration(
          color: theme.cardColor, 
          borderRadius: BorderRadius.circular(25), 
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 標題
            Text(
              title, 
              style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500)
            ),
            
            // 內容
            Text(
              content, 
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16)
            ),
            
            // 按鈕區塊
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel, style: const TextStyle(color: Colors.grey, fontSize: 16))), 
                SizedBox(
                  width: 109.6, height: 38,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error, 
                      foregroundColor: colorScheme.onError, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(l10n.commonDelete, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)), 
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