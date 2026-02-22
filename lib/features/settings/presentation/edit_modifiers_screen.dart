import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class EditModifiersScreen extends StatefulWidget {
  const EditModifiersScreen({super.key});

  @override
  State<EditModifiersScreen> createState() => _EditModifiersScreenState();
}

class _EditModifiersScreenState extends State<EditModifiersScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> modifierGroups = [];
  String? shopId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopCode = prefs.getString('savedShopCode');
      if (shopCode == null) return;

      final shopRes = await Supabase.instance.client
          .from('shops')
          .select('id')
          .eq('code', shopCode)
          .maybeSingle();

      if (shopRes == null) return;
      shopId = shopRes['id'];

      // Fetch groups and their options
      final groupsRes = await Supabase.instance.client
          .from('modifier_groups')
          .select('*, modifiers(*)') // Join modifiers
          .eq('shop_id', shopId!)
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          modifierGroups = List<Map<String, dynamic>>.from(groupsRes);
          // Sort modifiers inside each group
          for (var group in modifierGroups) {
             final mods = List<Map<String, dynamic>>.from(group['modifiers']);
             mods.sort((a,b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
             group['modifiers'] = mods;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _addOrEditGroup({Map<String, dynamic>? group}) async {
    await showDialog(
      context: context,
      builder: (context) => _GroupDialog(
        shopId: shopId!,
        group: group,
        onSave: _loadData,
      ),
    );
  }

  Future<void> _deleteGroup(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("刪除配料群組"),
        content: const Text("確定要刪除？這會將群組內的所有選項一併刪除。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("刪除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('modifier_groups').delete().eq('id', groupId);
      _loadData();
    }
  }

  // --- Modifiers Logic ---
  
  Future<void> _addOrEditModifier(String groupId, {Map<String, dynamic>? modifier}) async {
    await showDialog(
      context: context,
      builder: (context) => _ModifierDialog(
        groupId: groupId,
        modifier: modifier,
        onSave: _loadData,
      ),
    );
  }

  Future<void> _deleteModifier(String modifierId) async {
     await Supabase.instance.client.from('modifiers').delete().eq('id', modifierId);
     _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         title: const Text("配料設定"),
         actions: [
            IconButton(icon: const Icon(CupertinoIcons.add), onPressed: () => _addOrEditGroup()),
         ],
      ),
      body: isLoading
        ? const Center(child: CupertinoActivityIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: modifierGroups.length,
            itemBuilder: (context, index) {
              final group = modifierGroups[index];
              final modifiers = group['modifiers'] as List;
              
              return Card(
                color: Theme.of(context).cardColor,
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  title: Text(
                    "${group['name']} (${group['selection_type'] == 'single' ? '單選' : '多選'})",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "限制: ${group['min_selection']} ~ ${group['max_selection'] ?? '無上限'}",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       IconButton(icon: const Icon(CupertinoIcons.pencil, size: 20), onPressed: () => _addOrEditGroup(group: group)),
                       IconButton(icon: const Icon(CupertinoIcons.trash, size: 20, color: Colors.red), onPressed: () => _deleteGroup(group['id'])),
                    ],
                  ),
                  children: [
                     // List of modifiers
                     ...modifiers.map((mod) => ListTile(
                        dense: true,
                        title: Text(mod['name']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             Text(
                               mod['price_adjustment'] == 0 ? "免費" : "+\$${mod['price_adjustment']}",
                               style: TextStyle(
                                 color: mod['price_adjustment'] > 0 ? Colors.green : Colors.grey,
                                 fontWeight: FontWeight.bold
                               ),
                             ),
                             const SizedBox(width: 10),
                             IconButton(icon: const Icon(CupertinoIcons.pencil, size: 16), onPressed: () => _addOrEditModifier(group['id'], modifier: mod)),
                             IconButton(icon: const Icon(CupertinoIcons.trash, size: 16, color: Colors.red), onPressed: () => _deleteModifier(mod['id'])),
                          ],
                        ),
                     )),
                     
                     // Add Modifier Button
                     Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: TextButton.icon(
                         icon: const Icon(CupertinoIcons.add),
                         label: const Text("新增選項"),
                         onPressed: () => _addOrEditModifier(group['id']),
                       ),
                     )
                  ],
                ),
              );
            },
          ),
    );
  }
}

// --- Dialogs ---

class _GroupDialog extends StatefulWidget {
  final String shopId;
  final Map<String, dynamic>? group;
  final VoidCallback onSave;

  const _GroupDialog({required this.shopId, this.group, required this.onSave});

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  final _nameCtrl = TextEditingController();
  final _minCtrl = TextEditingController(text: "0");
  final _maxCtrl = TextEditingController(); // Empty means unlimited
  String _selectionType = 'single';

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _nameCtrl.text = widget.group!['name'];
      _minCtrl.text = widget.group!['min_selection'].toString();
      if (widget.group!['max_selection'] != null) {
        _maxCtrl.text = widget.group!['max_selection'].toString();
      }
      _selectionType = widget.group!['selection_type'];
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    
    final min = int.tryParse(_minCtrl.text) ?? 0;
    final max = int.tryParse(_maxCtrl.text);

    final data = {
      'shop_id': widget.shopId,
      'name': name,
      'selection_type': _selectionType,
      'min_selection': min,
      'max_selection': max,
    };

    if (widget.group == null) {
      await Supabase.instance.client.from('modifier_groups').insert(data);
    } else {
      await Supabase.instance.client.from('modifier_groups').update(data).eq('id', widget.group!['id']);
    }
    
    widget.onSave();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.group == null ? "新增群組" : "編輯群組"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "群組名稱 (如: 甜度)")),
             const SizedBox(height: 10),
             DropdownButtonFormField<String>(
               value: _selectionType,
               items: const [
                 DropdownMenuItem(value: 'single', child: Text("單選 (Radio)")),
                 DropdownMenuItem(value: 'multiple', child: Text("多選 (Checkbox)")),
               ],
               onChanged: (v) => setState(() => _selectionType = v!),
               decoration: const InputDecoration(labelText: "選擇類型"),
             ),
             const SizedBox(height: 10),
             Row(
               children: [
                 Expanded(child: TextField(controller: _minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "最少選幾項"))),
                 const SizedBox(width: 10),
                 Expanded(child: TextField(controller: _maxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "最多選幾項 (留空無限制)"))),
               ],
             )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
        ElevatedButton(onPressed: _submit, child: const Text("儲存")),
      ],
    );
  }
}

class _ModifierDialog extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic>? modifier;
  final VoidCallback onSave;

  const _ModifierDialog({required this.groupId, this.modifier, required this.onSave});

  @override
  State<_ModifierDialog> createState() => _ModifierDialogState();
}

class _ModifierDialogState extends State<_ModifierDialog> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: "0");

  @override
  void initState() {
    super.initState();
    if (widget.modifier != null) {
      _nameCtrl.text = widget.modifier!['name'];
      _priceCtrl.text = widget.modifier!['price_adjustment'].toString();
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    final data = {
      'group_id': widget.groupId,
      'name': name,
      'price_adjustment': price,
    };

    if (widget.modifier == null) {
      await Supabase.instance.client.from('modifiers').insert(data);
    } else {
      await Supabase.instance.client.from('modifiers').update(data).eq('id', widget.modifier!['id']);
    }

    widget.onSave();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.modifier == null ? "新增選項" : "編輯選項"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
           TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "選項名稱 (如: 半糖)")),
           const SizedBox(height: 10),
           TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "加價 (0表示免費)")),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
        ElevatedButton(onPressed: _submit, child: const Text("儲存")),
      ],
    );
  }
}
