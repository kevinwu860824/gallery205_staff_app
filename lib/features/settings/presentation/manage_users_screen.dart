// lib/features/settings/presentation/manage_users_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

// -------------------------------------------------------------------
// UI 樣式與輔助方法
// -------------------------------------------------------------------

InputDecoration _buildInputDecoration(BuildContext context, {required String hintText, Widget? suffixIcon}) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 16),
    filled: true,
    fillColor: theme.cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    suffixIcon: suffixIcon,
  );
}

// -------------------------------------------------------------------
// 主螢幕類別
// -------------------------------------------------------------------

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> _filteredUsers = []; // ✅ Added for filtering
  
  String? currentShopId; 
  String? currentUserEmail;
  String? currentUserRoleName; 
  bool isLoading = true;
  
  final TextEditingController _searchController = TextEditingController(); // ✅ Search Controller

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged); // ✅ Listen for search changes
    _loadInitial();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(users);
      } else {
        _filteredUsers = users.where((user) {
          final name = (user['name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    currentShopId = prefs.getString('savedShopId'); 
    currentUserEmail = supabase.auth.currentUser?.email;

    if (currentShopId == null || currentUserEmail == null) {
      if (mounted) context.go('/');
      return;
    }

    await _loadUsers();
  }

  Future<void> _loadUsers() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final response = await supabase
          .from('user_shop_map')
          .select('''
            user_id, role_id, 
            salary_type, base_wage, 
            dob, id_number, enroll_date, 
            phone, address, 
            bank_code, bank_account, 
            emergency_contact, emergency_phone,
            shop_roles(name), users(email, name)
          ''')
          .eq('shop_code', currentShopId!);

      final List<dynamic> data = response as List<dynamic>;

      final List<Map<String, dynamic>> formattedUsers = [];
      
      for (var item in data) {
        final roleData = item['shop_roles'];
        final userData = item['users'];
        
        final String roleName = roleData != null ? roleData['name'] : l10n.commonUnknown;
        final String email = userData != null ? userData['email'] : l10n.userMgmtStatusInvited;
        final String name = userData != null ? userData['name'] : l10n.userMgmtStatusWaiting;
        
        if (email == currentUserEmail) {
          currentUserRoleName = roleName;
        }

        formattedUsers.add({
          'user_id': item['user_id'],
          'role_id': item['role_id'],
          'role_name': roleName,
          'email': email,
          'name': name,
          'salary_type': item['salary_type'] ?? 'hourly',
          'base_wage': item['base_wage'] ?? 0,
          'dob': item['dob'],
          'id_number': item['id_number'],
          'enroll_date': item['enroll_date'],
          'phone': item['phone'],
          'address': item['address'],
          'bank_code': item['bank_code'],
          'bank_account': item['bank_account'],
          'emergency_contact': item['emergency_contact'],
          'emergency_phone': item['emergency_phone'],
        });
      }

      if (mounted) {
        setState(() {
          users = formattedUsers;
          _filteredUsers = formattedUsers; // ✅ Initialize filtered list
          isLoading = false;
        });
        _onSearchChanged(); // Re-apply search if exists
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      _showAlert(l10n.userMgmtErrorLoad(e.toString()));
    }
  }

  bool _canModify(Map<String, dynamic> targetUser) {
    if (targetUser['email'] == currentUserEmail) return false;
    
    final myRole = currentUserRoleName?.toLowerCase() ?? '';
    return myRole.contains('owner') || myRole.contains('manager') || myRole.contains('admin');
  }

  Future<void> _addUser() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => _AddUserDialog(shopId: currentShopId!),
    );
    
    if (result == null) return;

    setState(() => isLoading = true);

    try {
      final response = await supabase.functions.invoke(
        'invite-user', 
        body: {
          'email': result['email'],
          'name': result['name'],
          'role_id': result['role_id'], 
          'shop_id': currentShopId,     
        },
      );

      if (response.status >= 200 && response.status < 300) {
        
        final responseData = response.data is Map ? response.data : {};
        String? newUserId = responseData['user_id'] ?? responseData['id'];

        if (result['hr_details'] != null && result['hr_details'] is Map) {
            await _loadUsers();
            
            final newUser = users.firstWhere(
               (u) => u['email'] == result['email'], 
               orElse: () => {},
            );
            
            if (newUser.isNotEmpty && newUser['user_id'] != null) {
               await supabase
                .from('user_shop_map')
                .update(result['hr_details'])
                .eq('user_id', newUser['user_id'])
                .eq('shop_code', currentShopId!);
            }
        }

        if (mounted) _showAlert(l10n.userMgmtInviteSuccess);
      } else {
        final errorMsg = response.data is Map ? response.data['error'] : response.data;
        _showAlert(l10n.userMgmtInviteFailed(errorMsg.toString()));
      }
    } catch (e) {
      _showAlert(l10n.userMgmtErrorConnection(e.toString()));
    } finally {
      await _loadUsers();
    }
  }

  Future<void> _editUser(Map user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditUserDialog(
        user: user, 
        shopId: currentShopId!
      ),
    );
    
    if (result == true) {
      await _loadUsers();
    }
  }

  Future<void> _deleteUser(Map user) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteUserDialog(userName: user['name'] ?? l10n.commonUnknown),
    );

    if (confirmed == true) {
      setState(() => isLoading = true);
      try {
        await supabase
            .from('user_shop_map')
            .delete()
            .eq('user_id', user['user_id'])
            .eq('shop_code', currentShopId!);

        await _loadUsers();
      } catch (e) {
        _showAlert(l10n.userMgmtDeleteFailed(e.toString()));
        setState(() => isLoading = false);
      }
    }
  }

  void _showAlert(String message) {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(l10n.commonNotificationTitle),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n.commonConfirm),
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // ✅ Scaffold Structure
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface, size: 28), // 30 -> 28
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.userMgmtTitle,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20, // 30 -> 20 standard AppBar size
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(CupertinoIcons.add, color: colorScheme.onSurface, size: 28),
            onPressed: _addUser,
          ),
        ],
      ),
      body: isLoading
        ? Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface))
        : Column(
            children: [
              // ✅ Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: '搜尋姓名 (Search Name)...', // Localize if possible or hardcode for now
                  style: TextStyle(color: colorScheme.onSurface),
                  placeholderStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  backgroundColor: theme.cardColor,
                  borderRadius: BorderRadius.circular(10), // Flatter standard style
                ),
              ),
              
              // ✅ User List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
                  itemCount: _filteredUsers.length,
                  itemBuilder: (_, i) {
                    final user = _filteredUsers[i];
                    final canModify = _canModify(user);
                    
                    return _UserCard(
                      user: user,
                      onEdit: canModify ? () => _editUser(user) : null,
                      onDelete: canModify ? () => _deleteUser(user) : null,
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}

// -------------------------------------------------------------------
// User Card
// -------------------------------------------------------------------

class _UserCard extends StatelessWidget {
  final Map user;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _UserCard({required this.user, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0), // Reduced margin
      padding: const EdgeInsets.all(16.0),
      height: 120, // Slightly reduced height
      decoration: BoxDecoration(
        color: theme.cardColor, 
        borderRadius: BorderRadius.circular(16),  // Standard radius
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user['name'] ?? 'N/A',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                   color: colorScheme.primary.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(8)
                ),
                child: Text(
                  user['role_name'] ?? 'N/A', // Role Badge
                  style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(
            user['email'] ?? 'N/A',
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 14),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
                if (onEdit != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: onEdit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.pencil, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 4),
                        Text(l10n.commonEdit, style: TextStyle(color: colorScheme.primary, fontSize: 14))
                      ],
                    ),
                  ),
                if (onDelete != null) ...[
                  const SizedBox(width: 16),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: onDelete,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.trash, color: colorScheme.error, size: 20),
                        const SizedBox(width: 4),
                        Text(l10n.commonDelete, style: TextStyle(color: colorScheme.error, fontSize: 14))
                      ],
                    ),
                  ),
                ]
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// Add User Dialog
// -------------------------------------------------------------------

class _AddUserDialog extends StatefulWidget {
  final String shopId;

  const _AddUserDialog({required this.shopId});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  // Basic
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  
  List<Map<String, dynamic>> roles = [];
  Map<String, dynamic>? selectedRole;
  bool isLoadingRoles = true;

  // HR
  final idController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  DateTime? dob;
  DateTime? enrollDate;

  // Payroll
  final wageController = TextEditingController(text: '0');
  String salaryType = 'hourly';
  final bankCodeController = TextEditingController();
  final bankAccountController = TextEditingController();

  // Emergency
  final emergencyContactController = TextEditingController();
  final emergencyPhoneController = TextEditingController();

  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    try {
      final res = await Supabase.instance.client
          .from('shop_roles')
          .select('id, name')
          .eq('shop_id', widget.shopId)
          .order('is_system_default', ascending: false)
          .order('created_at');
      
      final data = List<Map<String, dynamic>>.from(res);
      
      if (mounted) {
        setState(() {
          roles = data;
          if (data.isNotEmpty) selectedRole = data.first;
          isLoadingRoles = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching roles: $e');
    }
  }

  Future<void> _showRolePicker() async {
    final l10n = AppLocalizations.of(context)!;
    if (roles.isEmpty) return;
    int tempIndex = roles.indexOf(selectedRole ?? roles.first);
    if (tempIndex == -1) tempIndex = 0;

    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: Theme.of(context).cardColor,
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(l10n.userMgmtButtonDone),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    selectedRole = roles[tempIndex];
                  });
                },
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: tempIndex),
                itemExtent: 40,
                onSelectedItemChanged: (index) => tempIndex = index,
                children: roles.map((r) => Center(child: Text(r['name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(String type) async {
    final now = DateTime.now();
    final initial = (type == 'dob' ? dob : enrollDate) ?? now;
    
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Theme.of(context).cardColor,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: initial,
          onDateTimeChanged: (val) {
             setState(() {
               if (type == 'dob') dob = val;
               else enrollDate = val;
             });
          },
        ),
      ),
    );
  }

  void _submit() {
    final email = emailController.text.trim();
    final name = nameController.text.trim();
    
    if (email.isEmpty || name.isEmpty || selectedRole == null) {
      return; 
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return;
    }

    Navigator.of(context).pop({
      'email': email,
      'name': name,
      'role_id': selectedRole!['id'],
      'shop_id': widget.shopId,
       // HR Payload (Requires backend support in invite-user function, or subsequent update)
       // Notes: 'invite-user' might only take basic info. 
       // If so, we might need to handle this differently (e.g., invite first, then update user_shop_map).
       // However, 'invite-user' is likely an Edge Function. If I can't modify it easily,
       // I should probably do a subsequent update call here if the invite succeeds?
       // Wait, the main screen calls `invite-user`. I should pass these details back to main screen.
       'hr_details': {
         'id_number': idController.text.trim(),
         'phone': phoneController.text.trim(),
         'address': addressController.text.trim(),
         'dob': dob?.toIso8601String().split('T').first,
         'enroll_date': enrollDate?.toIso8601String().split('T').first,
         'salary_type': salaryType,
         'base_wage': double.tryParse(wageController.text) ?? 0,
         'bank_code': bankCodeController.text.trim(),
         'bank_account': bankAccountController.text.trim(),
         'emergency_contact': emergencyContactController.text.trim(),
         'emergency_phone': emergencyPhoneController.text.trim(),
       }
    });
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
           const SizedBox(height: 4),
           TextFormField(
             controller: ctrl,
             keyboardType: type,
             style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
             decoration: _buildInputDecoration(context, hintText: ''),
           ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
     return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
           const SizedBox(height: 4),
           GestureDetector(
             onTap: onTap,
             child: Container(
               height: 48,
               padding: const EdgeInsets.symmetric(horizontal: 20),
               decoration: BoxDecoration(
                 color: Theme.of(context).cardColor,
                 borderRadius: BorderRadius.circular(25),
               ),
               alignment: Alignment.centerLeft,
               child: Text(
                 date == null ? '尚未選擇' : date.toIso8601String().split('T').first,
                 style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
               ),
             ),
           ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tabs = ['基本', '人事', '薪資', '緊急'];
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor, 
          borderRadius: BorderRadius.circular(25), 
        ),
        child: Column(
          children: [
             Padding(
              padding: const EdgeInsets.all(20),
              child: Text(l10n.userMgmtInviteNewUser, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            CupertinoSegmentedControl<int>(
              children: {
                0: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(tabs[0])),
                1: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(tabs[1])),
                2: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(tabs[2])),
                3: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(tabs[3])),
              },
              onValueChanged: (v) => setState(() => _currentTab = v),
              groupValue: _currentTab,
              borderColor: colorScheme.primary,
              selectedColor: colorScheme.primary,
              unselectedColor: theme.scaffoldBackgroundColor,
              pressedColor: colorScheme.primary.withOpacity(0.2), 
            ),
            const SizedBox(height: 10),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                     if (_currentTab == 0) ...[
                        _buildTextField(l10n.userMgmtLabelEmail, emailController, type: TextInputType.emailAddress),
                        _buildTextField(l10n.userMgmtNameHint, nameController),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: isLoadingRoles ? null : _showRolePicker,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 20), 
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.userMgmtLabelRolePicker, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 16)),
                                isLoadingRoles 
                                  ? const CupertinoActivityIndicator()
                                  : Text(selectedRole?['name'] ?? l10n.userMgmtLabelRoleSelect, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
                                Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurface),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.userMgmtInviteNote,
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                     ] else if (_currentTab == 1) ...[
                        _buildTextField('身分證字號', idController),
                        _buildDatePicker('出生年月日', dob, () => _pickDate('dob')),
                        _buildTextField('聯絡電話', phoneController, type: TextInputType.phone),
                        _buildTextField('通訊地址', addressController),
                        _buildDatePicker('到職日期', enrollDate, () => _pickDate('enroll')),
                     ] else if (_currentTab == 2) ...[
                        CupertinoSlidingSegmentedControl<String>(
                          groupValue: salaryType,
                          children: const {'hourly': Text('時薪'), 'monthly': Text('月薪')},
                          onValueChanged: (v) => setState(() => salaryType = v ?? 'hourly'),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(salaryType == 'hourly' ? '每小時薪資' : '每月薪資', wageController, type: TextInputType.number),
                        const Divider(),
                        _buildTextField('銀行代碼', bankCodeController, type: TextInputType.number),
                        _buildTextField('銀行帳號', bankAccountController, type: TextInputType.number),
                     ] else if (_currentTab == 3) ...[
                        _buildTextField('緊急聯絡人姓名', emergencyContactController),
                        _buildTextField('緊急聯絡人電話', emergencyPhoneController, type: TextInputType.phone),
                     ]
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null), 
                    child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface))
                  ),
                  SizedBox(
                    width: 110, height: 38,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                      ),
                      child: Text(l10n.userMgmtInviteButton, style: TextStyle(color: colorScheme.onPrimary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// Edit User Dialog
// -------------------------------------------------------------------

class _EditUserDialog extends StatefulWidget {
  final Map user;
  final String shopId;

  const _EditUserDialog({required this.user, required this.shopId});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  // Basic
  late final TextEditingController nameController;
  List<Map<String, dynamic>> roles = [];
  Map<String, dynamic>? selectedRole;
  bool isLoadingRoles = true;

  // HR
  late final TextEditingController idController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  DateTime? dob;
  DateTime? enrollDate;

  // Payroll
  late final TextEditingController wageController;
  String salaryType = 'hourly'; // hourly / monthly
  late final TextEditingController bankCodeController;
  late final TextEditingController bankAccountController;

  // Emergency
  late final TextEditingController emergencyContactController;
  late final TextEditingController emergencyPhoneController;

  int _currentTab = 0; // 0:Basic, 1:HR, 2:Payroll, 3:Emergency

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    nameController = TextEditingController(text: u['name']);
    
    idController = TextEditingController(text: u['id_number']);
    phoneController = TextEditingController(text: u['phone']);
    addressController = TextEditingController(text: u['address']);
    dob = u['dob'] != null ? DateTime.tryParse(u['dob']) : null;
    enrollDate = u['enroll_date'] != null ? DateTime.tryParse(u['enroll_date']) : null;

    wageController = TextEditingController(text: (u['base_wage'] ?? 0).toString());
    salaryType = u['salary_type'] ?? 'hourly';
    bankCodeController = TextEditingController(text: u['bank_code']);
    bankAccountController = TextEditingController(text: u['bank_account']);

    emergencyContactController = TextEditingController(text: u['emergency_contact']);
    emergencyPhoneController = TextEditingController(text: u['emergency_phone']);

    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    try {
      final res = await Supabase.instance.client
          .from('shop_roles')
          .select('id, name')
          .eq('shop_id', widget.shopId)
          .order('is_system_default', ascending: false);
      
      final data = List<Map<String, dynamic>>.from(res);
      
      final currentRoleId = widget.user['role_id'];
      final current = data.firstWhere((r) => r['id'] == currentRoleId, orElse: () => data.first);

      if (mounted) {
        setState(() {
          roles = data;
          selectedRole = current;
          isLoadingRoles = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching roles: $e');
    }
  }

  Future<void> _showRolePicker() async {
    final l10n = AppLocalizations.of(context)!;
    if (roles.isEmpty) return;
    int tempIndex = roles.indexOf(selectedRole ?? roles.first);
    if (tempIndex == -1) tempIndex = 0;

    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: Theme.of(context).cardColor,
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(l10n.userMgmtButtonDone),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    selectedRole = roles[tempIndex];
                  });
                },
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: tempIndex),
                itemExtent: 40,
                onSelectedItemChanged: (index) => tempIndex = index,
                children: roles.map((r) => Center(child: Text(r['name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(String type) async {
    final now = DateTime.now();
    final initial = (type == 'dob' ? dob : enrollDate) ?? now;
    
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Theme.of(context).cardColor,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: initial,
          onDateTimeChanged: (val) {
             setState(() {
               if (type == 'dob') dob = val;
               else enrollDate = val;
             });
          },
        ),
      ),
    );
  }

  Future<void> _saveEdit() async {
    final newName = nameController.text.trim();
    if (newName.isEmpty || selectedRole == null) return;

    // Update Name (Public Profile)
    if (newName != widget.user['name']) {
      await Supabase.instance.client
          .from('users')
          .update({'name': newName})
          .eq('user_id', widget.user['user_id']);
    }

    // Update Shop Map Details (Role + HR Info)
    final Map<String, dynamic> updates = {
      'role_id': selectedRole!['id'],
      'id_number': idController.text.trim(),
      'phone': phoneController.text.trim(),
      'address': addressController.text.trim(),
      'dob': dob?.toIso8601String().split('T').first,
      'enroll_date': enrollDate?.toIso8601String().split('T').first,
      'salary_type': salaryType,
      'base_wage': double.tryParse(wageController.text) ?? 0,
      'bank_code': bankCodeController.text.trim(),
      'bank_account': bankAccountController.text.trim(),
      'emergency_contact': emergencyContactController.text.trim(),
      'emergency_phone': emergencyPhoneController.text.trim(),
    };

    await Supabase.instance.client
        .from('user_shop_map')
        .update(updates)
        .eq('user_id', widget.user['user_id'])
        .eq('shop_code', widget.shopId);
    
    if (mounted) {
       Navigator.of(context).pop(true);
    }
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
           const SizedBox(height: 4),
           TextFormField(
             controller: ctrl,
             keyboardType: type,
             style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
             decoration: _buildInputDecoration(context, hintText: ''),
           ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
     return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
           const SizedBox(height: 4),
           GestureDetector(
             onTap: onTap,
             child: Container(
               height: 48,
               padding: const EdgeInsets.symmetric(horizontal: 20),
               decoration: BoxDecoration(
                 color: Theme.of(context).cardColor,
                 borderRadius: BorderRadius.circular(25),
               ),
               alignment: Alignment.centerLeft,
               child: Text(
                 date == null ? '尚未選擇' : date.toIso8601String().split('T').first,
                 style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
               ),
             ),
           ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tabs = ['基本', '人事', '薪資', '緊急'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor, 
          borderRadius: BorderRadius.circular(25), 
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(l10n.userMgmtEditTitle, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            
            // Tab Bar
            CupertinoSegmentedControl<int>(
              children: {
                0: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(tabs[0])),
                1: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(tabs[1])),
                2: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(tabs[2])),
                3: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(tabs[3])),
              },
              onValueChanged: (v) => setState(() => _currentTab = v),
              groupValue: _currentTab,
              borderColor: colorScheme.primary,
              selectedColor: colorScheme.primary,
              unselectedColor: theme.scaffoldBackgroundColor,
              pressedColor: colorScheme.primary.withOpacity(0.2), 
            ),
            const SizedBox(height: 10),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_currentTab == 0) ...[
                      _buildTextField(l10n.userMgmtNameHint, nameController),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: isLoadingRoles ? null : _showRolePicker,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 20), 
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.userMgmtLabelRolePicker, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 16)),
                              isLoadingRoles 
                                ? const CupertinoActivityIndicator()
                                : Text(selectedRole?['name'] ?? l10n.userMgmtLabelRoleSelect, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
                              Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurface),
                            ],
                          ),
                        ),
                      ),
                    ] else if (_currentTab == 1) ...[
                      _buildTextField('身分證字號', idController),
                      _buildDatePicker('出生年月日', dob, () => _pickDate('dob')),
                      _buildTextField('聯絡電話', phoneController, type: TextInputType.phone),
                      _buildTextField('通訊地址', addressController),
                      _buildDatePicker('到職日期', enrollDate, () => _pickDate('enroll')),
                    ] else if (_currentTab == 2) ...[
                      CupertinoSlidingSegmentedControl<String>(
                        groupValue: salaryType,
                        children: const {'hourly': Text('時薪'), 'monthly': Text('月薪')},
                        onValueChanged: (v) => setState(() => salaryType = v ?? 'hourly'),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(salaryType == 'hourly' ? '每小時薪資' : '每月薪資', wageController, type: TextInputType.number),
                      const Divider(),
                      _buildTextField('銀行代碼', bankCodeController, type: TextInputType.number),
                      _buildTextField('銀行帳號', bankAccountController, type: TextInputType.number),
                    ] else if (_currentTab == 3) ...[
                      _buildTextField('緊急聯絡人姓名', emergencyContactController),
                      _buildTextField('緊急聯絡人電話', emergencyPhoneController, type: TextInputType.phone),
                    ]
                  ],
                ),
              ),
            ),
            
            // Footer Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface))),
                  SizedBox(
                    width: 110, height: 38,
                    child: ElevatedButton(
                      onPressed: _saveEdit,
                      style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                      child: Text(l10n.commonSave, style: TextStyle(color: colorScheme.onPrimary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteUserDialog extends StatelessWidget {
  final String userName;
  const _DeleteUserDialog({required this.userName});

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
            Text(
              l10n.userMgmtDeleteTitle,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500)
            ),
            Text(
              l10n.userMgmtDeleteContent(userName),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16)
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface))),
                SizedBox(
                  width: 110, height: 38,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error, 
                      foregroundColor: colorScheme.onError, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                    ),
                    child: Text(l10n.commonDelete),
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