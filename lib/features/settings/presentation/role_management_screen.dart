// lib/features/settings/presentation/role_management_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/core/constants/app_permissions.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// 1. UI 樣式定義 - Cleaned up to use Theme.of(context)
// -------------------------------------------------------------------

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> roles = [];
  bool isLoading = true;
  String? currentShopId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoles();
    });
  }

  Future<void> _loadRoles() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getString('savedShopId'); 

      if (shopId == null) {
        if (mounted) context.pop();
        return; 
      }
      currentShopId = shopId;

      final res = await supabase
          .from('shop_roles')
          .select('id, name, is_system_default')
          .eq('shop_id', shopId)
          .order('is_system_default', ascending: false)
          .order('created_at');

      if (mounted) {
        setState(() {
          roles = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('❌ 載入角色失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.roleMgmtErrorLoad(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addNewRole() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _AddRoleDialog(),
    );

    if (result != null && result.isNotEmpty && currentShopId != null && mounted) {
      final l10n = AppLocalizations.of(context)!;
      try {
        await supabase.from('shop_roles').insert({
          'shop_id': currentShopId,
          'name': result,
          'is_system_default': false,
        });
        if (mounted) _loadRoles();
      } catch (e) {
        debugPrint('Error adding role: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.roleMgmtErrorAdd(e.toString()))));
        }
      }
    }
  }

  void _editRole(Map<String, dynamic> role) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => RolePermissionEditorScreen(
          key: ValueKey(role['id']),
          roleId: role['id'],
          roleName: role['name'],
          isSystemDefault: role['is_system_default'] ?? false,
          onSave: _loadRoles, 
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
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.roleMgmtTitle, style: TextStyle(color: colorScheme.onSurface)),
        actions: [
          IconButton(
            icon: Icon(CupertinoIcons.add, color: colorScheme.onSurface),
            onPressed: _addNewRole,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: roles.length,
              itemBuilder: (context, index) {
                final role = roles[index];
                final isDefault = role['is_system_default'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    title: Text(
                      role['name'],
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    subtitle: isDefault 
                      ? Text(l10n.roleMgmtSystemDefault, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))
                      : null,
                    trailing: Icon(CupertinoIcons.chevron_right, color: colorScheme.onSurfaceVariant),
                    onTap: () => _editRole(role),
                  ),
                );
              },
            ),
    );
  }
}

// -------------------------------------------------------------------
// 3. 編輯權限頁面 (RolePermissionEditorScreen)
// -------------------------------------------------------------------

class RolePermissionEditorScreen extends StatefulWidget {
  final String roleId;
  final String roleName;
  final bool isSystemDefault;
  final VoidCallback onSave;

  const RolePermissionEditorScreen({
    super.key,
    required this.roleId,
    required this.roleName,
    required this.isSystemDefault,
    required this.onSave,
  });

  @override
  State<RolePermissionEditorScreen> createState() => _RolePermissionEditorScreenState();
}

class _RolePermissionEditorScreenState extends State<RolePermissionEditorScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<String> activePermissions = []; 
  bool isLoading = true;
  late TextEditingController nameController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.roleName);
    _loadPermissions();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final res = await supabase
        .from('shop_role_permissions')
        .select('permission_key')
        .eq('role_id', widget.roleId);
    
    setState(() {
      activePermissions = (res as List).map((e) => e['permission_key'] as String).toList();
      isLoading = false;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => isLoading = true);
    
    try {
      if (!widget.isSystemDefault && nameController.text.trim() != widget.roleName) {
        await supabase.from('shop_roles').update({
          'name': nameController.text.trim(),
        }).eq('id', widget.roleId);
      }

      await supabase.from('shop_role_permissions').delete().eq('role_id', widget.roleId);

      if (activePermissions.isNotEmpty) {
        final insertData = activePermissions.map((key) => {
          'role_id': widget.roleId,
          'permission_key': key,
        }).toList();
        
        await supabase.from('shop_role_permissions').insert(insertData);
      }

      if (mounted) {
        widget.onSave();
        context.pop();
      }
    } catch (e) {
      debugPrint('Error saving permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.roleMgmtErrorSave(e.toString()))));
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deleteRole() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => isLoading = true);

    try {
      final res = await supabase
          .from('user_shop_map')
          .select('user_id') 
          .eq('role_id', widget.roleId) 
          .count(CountOption.exact); 

      final int userCount = res.count;

      if (userCount > 0) {
        if (mounted) {
          setState(() => isLoading = false); 
          
          await showDialog(
            context: context,
            builder: (ctx) => _UnableToDeleteDialog(
              roleName: widget.roleName,
              count: userCount,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() => isLoading = false); 
        
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => const _DeleteConfirmationDialog(),
        );

        if (confirm == true) {
          setState(() => isLoading = true);
          
          await supabase.from('shop_role_permissions').delete().eq('role_id', widget.roleId);
          await supabase.from('shop_roles').delete().eq('id', widget.roleId);
          
          if (mounted) {
            widget.onSave();
            context.pop();
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking role usage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.roleMgmtErrorSave(e.toString()))));
        setState(() => isLoading = false);
      }
    }
  }

  void _togglePermission(String key, bool value) {
    setState(() {
      if (value) {
        if (!activePermissions.contains(key)) activePermissions.add(key);
      } else {
        activePermissions.remove(key);
      }
    });
  }

  String _translatePermissionLabel(String key, AppLocalizations l10n) {
      switch (key) {
        case AppPermissions.homeOrder: return l10n.permHomeOrder;
        case AppPermissions.homePrep: return l10n.permHomePrep;
        case AppPermissions.homeStock: return l10n.permHomeStock;
        case AppPermissions.homeBackDashboard: return l10n.permHomeBackDashboard;
        case AppPermissions.homeDailyCost: return l10n.permHomeDailyCost;
        case AppPermissions.homeCashFlow: return l10n.permHomeCashFlow;
        case AppPermissions.homeMonthlyCost: return l10n.permHomeMonthlyCost;
        case AppPermissions.homeScan: return l10n.permHomeScan;
        case AppPermissions.scheduleEdit: return l10n.permScheduleEdit;
        case AppPermissions.backCashFlow: return l10n.permBackCashFlow;
        case AppPermissions.backCostSum: return l10n.permBackCostSum;
        case AppPermissions.backDashboard: return l10n.permBackDashboard;
        case AppPermissions.backCashVault: return l10n.permBackCashVault;
        case AppPermissions.backClockIn: return l10n.permBackClockIn;
        case AppPermissions.backViewAllClockIn: return l10n.permBackViewAllClockIn;
        case AppPermissions.backWorkReport: return l10n.permBackWorkReport;
        case AppPermissions.backPayroll: return l10n.permBackPayroll;
        case AppPermissions.backLoginWeb: return l10n.permBackLoginWeb;
        case AppPermissions.setStaff: return l10n.permSetStaff;
        case AppPermissions.setRole: return l10n.permSetRole;
        case AppPermissions.setPrinter: return l10n.permSetPrinter;
        case AppPermissions.setTableMap: return l10n.permSetTableMap;
        case AppPermissions.setTableList: return l10n.permSetTableList;
        case AppPermissions.setMenu: return l10n.permSetMenu;
        case AppPermissions.setShift: return l10n.permSetShift;
        case AppPermissions.setPunch: return l10n.permSetPunch;
        case AppPermissions.setPay: return l10n.permSetPay;
        case AppPermissions.setCostCat: return l10n.permSetCostCat;
        case AppPermissions.setInv: return l10n.permSetInv;
        case AppPermissions.setCashReg: return l10n.permSetCashReg;
        default: return key; 
      }
  }

  String _translateGroupName(String key, AppLocalizations l10n) {
      switch (key) {
        case 'permGroupMainScreen': return l10n.permGroupMainScreen;
        case 'permGroupSchedule': return l10n.permGroupSchedule;
        case 'permGroupBackstageDashboard': return l10n.permGroupBackstageDashboard;
        case 'permGroupSettings': return l10n.permGroupSettings;
        default: return key;
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
        title: Text(l10n.roleMgmtTitle, style: TextStyle(color: colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _save,
            child: Text(l10n.roleMgmtSaveButton, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: isLoading
          ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
          : SafeArea(
              child: Column(
                children: [
                  if (!widget.isSystemDefault)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CupertinoTextField(
                        controller: nameController,
                        placeholder: l10n.roleMgmtRoleNameHint,
                        padding: const EdgeInsets.all(12),
                        style: TextStyle(color: colorScheme.onSurface),
                        placeholderStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: AppPermissions.groups.length,
                      itemBuilder: (context, index) {
                        final group = AppPermissions.groups[index];
                        final String groupNameKey = group['name'];
                        final String translatedGroupName = _translateGroupName(groupNameKey, l10n);
                        final List permissions = group['permissions'];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                              child: Text(
                                translatedGroupName,
                                style: TextStyle(color: colorScheme.outline, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: permissions.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final perm = entry.value;
                                  final pKey = perm['key'];
                                  final pLabel = _translatePermissionLabel(pKey, l10n);
                                  final isLast = idx == permissions.length - 1;

                                  return Column(
                                    children: [
                                      SwitchListTile.adaptive(
                                        title: Text(pLabel, style: TextStyle(color: colorScheme.onSurface)),
                                        value: activePermissions.contains(pKey),
                                        activeTrackColor: colorScheme.primary, 
                                        onChanged: (val) => _togglePermission(pKey, val),
                                      ),
                                      if (!isLast)
                                        Divider(height: 1, color: theme.dividerColor, indent: 16, endIndent: 16),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  if (!widget.isSystemDefault)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: CupertinoButton(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(12),
                          padding: EdgeInsets.zero,
                          onPressed: _deleteRole,
                          child: Text(
                            l10n.roleMgmtDeleteRole, 
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
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
// 4. 自訂黑色風格 Dialog (新增角色)
// -------------------------------------------------------------------

class _AddRoleDialog extends StatefulWidget {
  const _AddRoleDialog();

  @override
  State<_AddRoleDialog> createState() => _AddRoleDialogState();
}

class _AddRoleDialogState extends State<_AddRoleDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.roleMgmtAddNewRole,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: _controller,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: l10n.roleMgmtEnterRoleName, 
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)) 
                ),
                SizedBox(
                  width: 100, 
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _controller.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(l10n.roleMgmtCreateButton, style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
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
// 5. 自訂黑色風格 Dialog (刪除確認)
// -------------------------------------------------------------------

class _DeleteConfirmationDialog extends StatelessWidget {
  const _DeleteConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.roleMgmtDeleteConfirmTitle,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.roleMgmtDeleteConfirmContent, 
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)),
                ),
                SizedBox(
                  width: 100,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(l10n.commonDelete, style: TextStyle(color: colorScheme.onError, fontWeight: FontWeight.bold)),
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
// 6. 無法刪除警告視窗 (當角色還有人使用時顯示)
// -------------------------------------------------------------------

class _UnableToDeleteDialog extends StatelessWidget {
  final String roleName;
  final int count;

  const _UnableToDeleteDialog({required this.roleName, required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String messageWithParams = l10n.roleMgmtCannotDeleteContent(count, roleName);
    final countPlaceholder = count.toString();
    final rolePlaceholder = roleName;
    
    List<String> partsByCount = messageWithParams.split(countPlaceholder);
    
    final part1 = partsByCount.first; 
    
    String middleSection = '';
    String lastSection = '';

    if (partsByCount.length > 1) {
        final remainingAfterCount = partsByCount[1];
        List<String> middleParts = remainingAfterCount.split(rolePlaceholder);
        middleSection = middleParts.first;
        if (middleParts.length > 1) {
            lastSection = middleParts[1];
        }
    }


    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: CupertinoColors.systemOrange,
              size: 48,
            ),
            const SizedBox(height: 16),
            
            Text(
              l10n.roleMgmtCannotDeleteTitle,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16, height: 1.5),
                children: [
                  TextSpan(text: part1), 
                  TextSpan(
                    text: count.toString(), 
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold) 
                  ),
                  TextSpan(text: middleSection), 
                  TextSpan(
                    text: roleName,
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)
                  ),
                  TextSpan(text: lastSection), 
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.onSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(l10n.roleMgmtUnderstandButton, style: TextStyle(color: theme.scaffoldBackgroundColor, fontWeight: FontWeight.bold)), 
              ),
            ),
          ],
        ),
      ),
    );
  }
}