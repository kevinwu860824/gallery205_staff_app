// lib/features/schedule/presentation/calendar_group_settings_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math; 
import 'package:flutter/services.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart'; 

class CalendarGroupSettingsScreen extends StatefulWidget {
  const CalendarGroupSettingsScreen({super.key});

  @override
  State<CalendarGroupSettingsScreen> createState() => _CalendarGroupSettingsScreenState();
}

class _CalendarGroupSettingsScreenState extends State<CalendarGroupSettingsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _shopUsers = [];
  bool _isLoading = true;
  String? _currentShopId;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser?.id;
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentShopId = prefs.getString('savedShopId');

    if (_currentShopId == null || _currentUserId == null) {
      if (mounted) context.pop();
      return;
    }

    await Future.wait([
      _loadGroups(),
      _loadShopUsers(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroups() async {
    try {
      final res = await supabase
          .from('calendar_groups')
          .select()
          .eq('shop_id', _currentShopId!)
          .order('created_at');
      
      final allShopGroups = List<Map<String, dynamic>>.from(res);

      final filteredGroups = allShopGroups.where((group) {
        if (group['name'] == '個人' || group['name'] == 'Personal') {
          return group['user_id'] == _currentUserId;
        }
        return true; 
      }).toList();

      setState(() {
        _groups = filteredGroups;
      });
    } catch (e) {
      debugPrint('❌ 載入群組失敗: $e');
    }
  }

  Future<void> _loadShopUsers() async {
    try {
      final res = await supabase
          .from('users')
          .select('user_id, name')
          .eq('shop_id', _currentShopId!);
      
      setState(() {
        _shopUsers = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('❌ 載入員工失敗: $e');
    }
  }

  void _openGroupEditor({Map<String, dynamic>? group}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GroupEditorSheet(
        shopId: _currentShopId!,
        currentUser: _currentUserId!,
        existingGroup: group,
        allUsers: _shopUsers,
        onSave: _loadGroups,
      ),
    );
  }

  Color _hexToColor(String? hex) {
    if (hex == null) return Theme.of(context).colorScheme.primary;
    String cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

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
        title: Text(l10n.calendarGroupsTitle, style: TextStyle(color: colorScheme.onSurface)),
        actions: [
          IconButton(
            icon: Icon(CupertinoIcons.add, color: colorScheme.onSurface),
            onPressed: () => _openGroupEditor(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                final isPersonal = group['name'] == '個人' || group['name'] == 'Personal';
                final color = _hexToColor(group['color']);
                final memberCount = (group['visible_user_ids'] as List?)?.length ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 24, 
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                    ),
                    title: Text(
                      isPersonal ? l10n.calendarGroupPersonal : (group['name'] ?? l10n.calendarGroupUntitled),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isPersonal 
                          ? l10n.calendarGroupPrivateDesc
                          : l10n.calendarGroupVisibleToMembers(memberCount),
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    trailing: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurfaceVariant, size: 16),
                    onTap: () => _openGroupEditor(group: group),
                  ),
                );
              },
            ),
    );
  }
}

// -------------------------------------------------------------------
// 2. 編輯/新增群組用的 Bottom Sheet
// -------------------------------------------------------------------

class _GroupEditorSheet extends StatefulWidget {
  final String shopId;
  final String currentUser;
  final Map<String, dynamic>? existingGroup;
  final List<Map<String, dynamic>> allUsers;
  final VoidCallback onSave;

  const _GroupEditorSheet({
    required this.shopId,
    required this.currentUser,
    this.existingGroup,
    required this.allUsers,
    required this.onSave,
  });

  @override
  State<_GroupEditorSheet> createState() => _GroupEditorSheetState();
}

class _GroupEditorSheetState extends State<_GroupEditorSheet> {
  final SupabaseClient supabase = Supabase.instance.client;
  
  late TextEditingController _nameController;
  late Color _selectedColor;
  late List<String> _visibleUserIds;
  bool _isPersonal = false;
  bool _isSaving = false;

  List<Map<String, dynamic>> _groupEventColors = [];
  bool _loadingColors = false;

  final List<Color> _availableColors = [
    const Color(0xFF0A84FF), const Color(0xFF30D158), const Color(0xFFFF9F0A),
    const Color(0xFFFF453A), const Color(0xFFBF5AF2), const Color(0xFFFF375F),
    const Color(0xFF64D2FF), const Color(0xFFFFD60A), const Color(0xFF8E8E93),
  ];

  @override
  void initState() {
    super.initState();
    final group = widget.existingGroup;
    _isPersonal = group?['name'] == '個人' || group?['name'] == 'Personal';
    _nameController = TextEditingController(text: group?['name'] ?? '');
    
    if (group != null && group['color'] != null) {
      String hex = group['color'].toString().replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      _selectedColor = Color(int.parse(hex, radix: 16));
    } else {
      _selectedColor = _availableColors[0];
    }

    if (group != null && group['visible_user_ids'] != null) {
      _visibleUserIds = List<String>.from(group['visible_user_ids']);
    } else {
      _visibleUserIds = [widget.currentUser];
    }

    if (widget.existingGroup != null) {
      _loadGroupEventColors();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupEventColors() async {
    setState(() => _loadingColors = true);
    try {
      final res = await supabase
          .from('group_event_colors')
          .select()
          .eq('calendar_group_id', widget.existingGroup!['id'])
          .order('created_at'); 
      
      final colors = List<Map<String, dynamic>>.from(res);

      if (colors.isEmpty) {
        await _initDefaultColors();
        return _loadGroupEventColors();
      }

      if (mounted) {
        setState(() {
          _groupEventColors = colors;
          _loadingColors = false;
        });
      }
    } catch (e) {
      debugPrint('Load colors error: $e');
      if (mounted) setState(() => _loadingColors = false);
    }
  }

  Future<void> _initDefaultColors() async {
    final defaultPresets = [
      {'name': 'Color 10', 'color': '#B28ADC'},   
      {'name': 'Color 9', 'color': '#FEC02F'},   
      {'name': 'Color 8', 'color': '#FA7E78'},   
      {'name': 'Color 7', 'color': '#F25F8B'},   
      {'name': 'Color 6', 'color': '#E73B3C'},   
      {'name': 'Color 5', 'color': '#212121'},   
      {'name': 'Color 4', 'color': '#947F78'},   
      {'name': 'Color 3', 'color': '#48B2F7'},   
      {'name': 'Color 2', 'color': '#3CC2C7'},   
      {'name': 'Color 1', 'color': '#2DCB86'},  
    ];

    for (var preset in defaultPresets) {
      await supabase.from('group_event_colors').insert({
        'calendar_group_id': widget.existingGroup!['id'],
        'name': preset['name'],
        'color': preset['color'],
      });
    }
  }

  Future<void> _saveGroup() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final colorHex = '#${_selectedColor.value.toRadixString(16).substring(2)}';
      
      // 1. 找出被「新加入」的成員
      List<String> oldMembers = [];
      if (widget.existingGroup != null) {
        oldMembers = List<String>.from(widget.existingGroup!['visible_user_ids'] ?? []);
      }
      final newMembers = List<String>.from(_visibleUserIds);
      final addedMembers = newMembers.where((id) => !oldMembers.contains(id)).toList();

      final data = {
        'name': _nameController.text.trim(),
        'color': colorHex,
        'visible_user_ids': _visibleUserIds,
        'shop_id': widget.shopId,
        'user_id': widget.existingGroup?['user_id'] ?? widget.currentUser,
      };

      if (widget.existingGroup == null) {
        await supabase.from('calendar_groups').insert(data);
      } else {
        await supabase.from('calendar_groups').update(data).eq('id', widget.existingGroup!['id']);
      }
      
      // 🔔 發送通知
      addedMembers.remove(widget.currentUser);
      
      if (addedMembers.isNotEmpty) {
        await supabase.functions.invoke('notify-calendar-event', body: {
          'title': l10n.notificationGroupInviteTitle,
          'body': l10n.notificationGroupInviteBody(_nameController.text.trim()),
          'target_user_ids': addedMembers,
          'route': '/personalSchedule',
          'shop_id': widget.shopId,
        });
      }

      if (mounted) {
        widget.onSave();
        context.pop();
      }
    } catch (e) {
      debugPrint('Save Error: $e');
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteGroup() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isPersonal) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.calendarGroupDelete),
        content: Text(l10n.calendarGroupDeleteConfirm),
        actions: [
          CupertinoDialogAction(child: Text(l10n.commonCancel), onPressed: () => Navigator.pop(ctx, false)),
          CupertinoDialogAction(isDestructiveAction: true, child: Text(l10n.commonDelete), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase
            .from('calendar_groups')
            .delete()
            .eq('id', widget.existingGroup!['id']);
        
        if (mounted) {
          widget.onSave();
          context.pop();
        }
      } catch (e) {
        debugPrint('Delete Error: $e');
      }
    }
  }

  void _openColorEditor({Map<String, dynamic>? colorData}) async {
    if (widget.existingGroup == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ColorEditorSheet(
        groupId: widget.existingGroup!['id'],
        existingData: colorData,
        onSave: _loadGroupEventColors,
      ),
    );
  }

  Color _hexToColor(String? hex) {
    if (hex == null) return Theme.of(context).colorScheme.primary;
    String cleanHex = hex.replaceFirst('#', '');
    if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(onTap: () => context.pop(), child: Text(l10n.commonCancel, style: const TextStyle(color: Colors.grey, fontSize: 16))),
                Text(widget.existingGroup == null ? l10n.calendarGroupNew : l10n.calendarGroupEdit, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                GestureDetector(onTap: _isSaving ? null : _saveGroup, child: Text(l10n.commonSave, style: TextStyle(color: _isSaving ? Colors.grey : colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(l10n.calendarGroupName, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _nameController,
                  placeholder: l10n.calendarGroupNameHint,
                  style: TextStyle(color: colorScheme.onSurface),
                  placeholderStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  readOnly: _isPersonal,
                  cursorColor: colorScheme.primary,
                ),
                
                const SizedBox(height: 24),
                Text(l10n.calendarGroupColor, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16, runSpacing: 16,
                  children: _availableColors.map((color) {
                    final isSelected = color.value == _selectedColor.value;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                if (widget.existingGroup != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.calendarGroupEventColors, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                      GestureDetector(
                        onTap: () => _openColorEditor(),
                        child: Icon(CupertinoIcons.add_circled, color: colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                    child: _loadingColors 
                        ? const Padding(padding: EdgeInsets.all(20), child: CupertinoActivityIndicator())
                        : Column(
                            children: _groupEventColors.map((colorItem) {
                              final color = _hexToColor(colorItem['color']);
                              return Column(
                                children: [
                                  ListTile(
                                    leading: Container(
                                      width: 20, height: 20,
                                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                    ),
                                    title: Text(colorItem['name'], style: TextStyle(color: colorScheme.onSurface)),
                                    trailing: Icon(CupertinoIcons.chevron_right, size: 16, color: colorScheme.onSurfaceVariant),
                                    onTap: () => _openColorEditor(colorData: colorItem),
                                  ),
                                  if (colorItem != _groupEventColors.last) 
                                    Divider(height: 1, color: theme.dividerColor, indent: 16, endIndent: 16),
                                ],
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l10n.calendarGroupSaveFirstHint, style: const TextStyle(color: Colors.white, fontSize: 13))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                if (!_isPersonal) ...[
                  Text(l10n.calendarGroupVisibleTo, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: widget.allUsers.map((user) {
                        final uid = user['user_id'] as String;
                        final name = user['name'] as String;
                        final isSelected = _visibleUserIds.contains(uid);
                        return SwitchListTile.adaptive(
                          title: Text(name, style: TextStyle(color: colorScheme.onSurface)),
                          value: isSelected,
                          activeColor: colorScheme.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val) _visibleUserIds.add(uid); else _visibleUserIds.remove(uid);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],

                if (widget.existingGroup != null && !_isPersonal)
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: CupertinoButton(
                      color: colorScheme.error, borderRadius: BorderRadius.circular(12), padding: EdgeInsets.zero,
                      onPressed: _deleteGroup,
                      child: Text(l10n.calendarGroupDelete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 編輯顏色用的 Bottom Sheet
// -------------------------------------------------------------------
class _ColorEditorSheet extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic>? existingData;
  final VoidCallback onSave;

  const _ColorEditorSheet({
    required this.groupId,
    this.existingData,
    required this.onSave,
  });

  @override
  State<_ColorEditorSheet> createState() => _ColorEditorSheetState();
}

class _ColorEditorSheetState extends State<_ColorEditorSheet> {
  late TextEditingController _nameController;
  late TextEditingController _hexController;
  final FocusNode _hexFocusNode = FocusNode();

  Color _selectedColor = const Color(0xFF0A84FF);
  bool _isSaving = false;
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingData?['name'] ?? '');
    
    if (widget.existingData != null && widget.existingData!['color'] != null) {
      String hex = widget.existingData!['color'].toString().replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      _selectedColor = Color(int.parse(hex, radix: 16));
    }

    _updateHexController();
    
    _hexFocusNode.addListener(() {
      if (!_hexFocusNode.hasFocus) {
        _updateHexController();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hexController.dispose();
    _hexFocusNode.dispose();
    super.dispose();
  }

  void _updateHexController() {
    if (!_hexFocusNode.hasFocus) {
      String colorString = _selectedColor.value.toRadixString(16).toUpperCase();
      if (colorString.length == 8) colorString = colorString.substring(2);
      _hexController = TextEditingController(text: colorString);
    }
  }

  void _onColorChanged(Color color) {
    setState(() {
      _selectedColor = color;
    });
    _updateHexController();
  }

  void _onHexChanged(String value) {
    String hex = value.trim().toUpperCase();
    if (hex.length == 6) {
      hex = 'FF$hex';
    } else if (hex.length == 8) {
    } else {
      return;
    }

    try {
      final newColor = Color(int.parse(hex, radix: 16));
      setState(() {
        _selectedColor = newColor;
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _save() async {
    _hexFocusNode.unfocus();

    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final colorHex = '#${_selectedColor.value.toRadixString(16).substring(2)}';
      
      final data = {
        'calendar_group_id': widget.groupId,
        'name': _nameController.text.trim(),
        'color': colorHex,
      };

      if (widget.existingData == null) {
        await supabase.from('group_event_colors').insert(data);
      } else {
        await supabase
            .from('group_event_colors')
            .update(data)
            .eq('id', widget.existingData!['id']);
      }

      if (mounted) {
        widget.onSave();
        context.pop();
      }
    } catch (e) {
      debugPrint('Save Color Error: $e');
      setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.calendarColorDelete),
        content: Text(l10n.calendarColorDeleteConfirm),
        actions: [
          CupertinoDialogAction(child: Text(l10n.commonCancel), onPressed: () => Navigator.pop(ctx, false)),
          CupertinoDialogAction(isDestructiveAction: true, child: Text(l10n.commonDelete), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase
            .from('group_event_colors')
            .delete()
            .eq('id', widget.existingData!['id']);
        
        if (mounted) {
          widget.onSave();
          context.pop();
        }
      } catch (e) {
        debugPrint('Delete Color Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85, 
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(onTap: () => context.pop(), child: Text(l10n.commonCancel, style: const TextStyle(color: Colors.grey, fontSize: 16))),
                  Text(widget.existingData == null ? l10n.calendarColorNew : l10n.calendarColorEdit, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  GestureDetector(onTap: _isSaving ? null : _save, child: Text(l10n.commonSave, style: TextStyle(color: _isSaving ? Colors.grey : colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const ClampingScrollPhysics(), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.calendarColorName, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _nameController,
                      placeholder: l10n.calendarColorNameHint,
                      style: TextStyle(color: colorScheme.onSurface),
                      placeholderStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                      cursorColor: colorScheme.primary,
                    ),
                    
                    const SizedBox(height: 24),
                    Text(l10n.calendarColorPick, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 12),
                    
                    _InteractiveColorPicker(
                      initialColor: _selectedColor,
                      onChanged: _onColorChanged,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Text('HEX:', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoTextField(
                            controller: _hexController,
                            focusNode: _hexFocusNode,
                            style: TextStyle(color: colorScheme.onSurface),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(color: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                            readOnly: false,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(6),
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                            ],
                            onChanged: _onHexChanged,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => FocusScope.of(context).unfocus(),
                            scrollPadding: const EdgeInsets.only(bottom: 100),
                            cursorColor: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                    if (widget.existingData != null)
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: CupertinoButton(
                          color: colorScheme.error, borderRadius: BorderRadius.circular(12), padding: EdgeInsets.zero,
                          onPressed: _delete,
                          child: Text(l10n.calendarColorDelete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 4. 自定義可拖拉 Color Picker 元件 (包含 HSV 面板 + Hue Bar)
// -------------------------------------------------------------------
class _InteractiveColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;

  const _InteractiveColorPicker({
    required this.initialColor,
    required this.onChanged,
  });

  @override
  State<_InteractiveColorPicker> createState() => _InteractiveColorPickerState();
}

class _InteractiveColorPickerState extends State<_InteractiveColorPicker> {
  late HSVColor _currentHsv;

  @override
  void initState() {
    super.initState();
    _currentHsv = HSVColor.fromColor(widget.initialColor);
  }

  void _updateColor() {
    widget.onChanged(_currentHsv.toColor());
  }

  @override
  void didUpdateWidget(_InteractiveColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialColor != widget.initialColor) {
      _currentHsv = HSVColor.fromColor(widget.initialColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onPanUpdate: (details) => _handleSaturationValueChange(context, details.localPosition, details.globalPosition),
          onTapDown: (details) => _handleSaturationValueChange(context, details.localPosition, details.globalPosition),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = 200.0;
              
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: HSVColor.fromAHSV(1, _currentHsv.hue, 1, 1).toColor(),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Colors.white, Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      left: _currentHsv.saturation * width - 10,
                      top: (1 - _currentHsv.value) * height - 10,
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          color: _currentHsv.toColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        GestureDetector(
          onPanUpdate: (details) => _handleHueChange(context, details.localPosition),
          onTapDown: (details) => _handleHueChange(context, details.localPosition),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Container(
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                      Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000)
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: (_currentHsv.hue / 360) * width - 15,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.black12),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleSaturationValueChange(BuildContext context, Offset local, Offset global) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    double width = box.size.width; 
    double height = 200.0;

    double dx = local.dx.clamp(0, width);
    double dy = local.dy.clamp(0, height);

    setState(() {
      _currentHsv = _currentHsv.withSaturation(dx / width).withValue(1 - (dy / height));
    });
    _updateColor();
  }

  void _handleHueChange(BuildContext context, Offset local) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    double width = box.size.width;
    double dx = local.dx.clamp(0, width);

    setState(() {
      _currentHsv = _currentHsv.withHue((dx / width) * 360);
    });
    _updateColor();
  }
}