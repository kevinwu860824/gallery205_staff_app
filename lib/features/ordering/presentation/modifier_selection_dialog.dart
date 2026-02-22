import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_item.dart';

class ModifierSelectionDialog extends StatefulWidget {
  final String itemId;
  final String itemName;
  final double basePrice;
  final bool isMarketPrice;
  final List<String> targetPrintCategoryIds;
  final Function(OrderItem) onAddToCart;

  const ModifierSelectionDialog({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.basePrice,
    required this.isMarketPrice,
    required this.targetPrintCategoryIds,
    required this.onAddToCart,
  });

  @override
  State<ModifierSelectionDialog> createState() => _ModifierSelectionDialogState();
}

class _ModifierSelectionDialogState extends State<ModifierSelectionDialog> {
  bool isLoading = true;
  List<Map<String, dynamic>> modifierGroups = [];
  
  // Selections state: { group_id: [modifier_id_1, modifier_id_2] }
  final Map<String, Set<String>> _selections = {};
  
  // Note and Quantity
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.isMarketPrice) {
      _priceController.text = ""; 
    } else {
      _priceController.text = widget.basePrice.toStringAsFixed(0);
    }
    _loadModifiers();
  }

  Future<void> _loadModifiers() async {
    setState(() => isLoading = true);
    try {
      final client = Supabase.instance.client;
      
      // 1. Get linked groups
      final links = await client
          .from('menu_item_modifier_groups')
          .select('modifier_group_id')
          .eq('menu_item_id', widget.itemId);
      
      if (links.isEmpty) {
        setState(() => isLoading = false);
        return;
      }
      
      final groupIds = links.map((e) => e['modifier_group_id']).toList();

      // 2. Fetch groups and modifiers
      final groupsRes = await client
          .from('modifier_groups')
          .select('*, modifiers(*)')
          .inFilter('id', groupIds)
          .order('sort_order', ascending: true);
      
      if (mounted) {
        setState(() {
          modifierGroups = List<Map<String, dynamic>>.from(groupsRes);
          // Sort modifiers
          for (var g in modifierGroups) {
             final mods = List<Map<String, dynamic>>.from(g['modifiers']);
             mods.sort((a,b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0));
             g['modifiers'] = mods;
             
             // Initialize selection for 'single' type if needed (optional)
             // For now, we leave it empty.
             _selections[g['id']] = {};
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load modifiers error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _onModifierTap(Map<String, dynamic> group, Map<String, dynamic> modifier) {
    final String groupId = group['id'];
    final String modId = modifier['id'];
    final bool isSingle = group['selection_type'] == 'single';
    
    setState(() {
      if (isSingle) {
        // Toggle off if already selected, or switch to new
        if (_selections[groupId]!.contains(modId)) {
          _selections[groupId]!.remove(modId);
        } else {
          _selections[groupId]!.clear(); // Clear others
          _selections[groupId]!.add(modId);
        }
      } else {
        // Multiple: Toggle
        if (_selections[groupId]!.contains(modId)) {
           _selections[groupId]!.remove(modId);
        } else {
           // Check max selection
           final int? max = group['max_selection'];
           if (max != null && _selections[groupId]!.length >= max) {
              // Should show error or replace? Let's just block for now
              return;
           }
           _selections[groupId]!.add(modId);
        }
      }
    });
  }

  double get _currentTotalUnit {
    double base = double.tryParse(_priceController.text) ?? widget.basePrice;
    if (widget.isMarketPrice && _priceController.text.isEmpty) base = 0;

    double mods = 0;
    for (var group in modifierGroups) {
      final selectedIds = _selections[group['id']] ?? {};
      final allMods = group['modifiers'] as List;
      for (var mod in allMods) {
        if (selectedIds.contains(mod['id'])) {
          mods += (mod['price_adjustment'] as num).toDouble();
        }
      }
    }
    return base + mods;
  }

  void _confirm() {
    // 1. Validate requirements
    for (var group in modifierGroups) {
      final int min = group['min_selection'] ?? 0;
      final selectedCount = _selections[group['id']]?.length ?? 0;
      if (selectedCount < min) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${group['name']} 至少需選擇 $min 項")));
        return;
      }
    }
    
    final price = double.tryParse(_priceController.text);
    if (widget.isMarketPrice && price == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請輸入時價金額")));
       return;
    }

    // 2. Build selected Modifiers List for OrderItem
    List<Map<String, dynamic>> finalModifiers = [];
    for (var group in modifierGroups) {
      final selectedIds = _selections[group['id']] ?? {};
      final allMods = group['modifiers'] as List;
      for (var mod in allMods) {
        if (selectedIds.contains(mod['id'])) {
          finalModifiers.add({
            'id': mod['id'],
            'name': mod['name'],
            'price': mod['price_adjustment'],
            'group_name': group['name']
          });
        }
      }
    }

    final item = OrderItem(
      id: widget.itemId, // Temporary ID (Menu ID) for Cart aggregation
      menuItemId: widget.itemId, // Actual Menu Item ID
      itemName: widget.itemName,
      quantity: _quantity,
      price: price ?? widget.basePrice,
      note: _noteController.text.trim(),
      targetPrintCategoryIds: widget.targetPrintCategoryIds,
      selectedModifiers: finalModifiers,
    );
    
    widget.onAddToCart(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate display total
    final total = _currentTotalUnit * _quantity;
    
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.itemName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold))),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(CupertinoIcons.xmark, color: Colors.grey)),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          
          // Scrollable Content
          Expanded(
            child: isLoading 
              ? const Center(child: CupertinoActivityIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Price Input (if Market Price)
                    if (widget.isMarketPrice) ...[
                      Text("輸入單價 (時價)", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: _priceController, 
                        keyboardType: TextInputType.number, 
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        onChanged: (_) => setState((){}),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Modifier Groups
                    ...modifierGroups.map((group) {
                       final bool isSingle = group['selection_type'] == 'single';
                       final mods = group['modifiers'] as List;
                       final selectedIds = _selections[group['id']] ?? {};

                       return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             children: [
                               Text(group['name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                               const SizedBox(width: 8),
                               if (group['min_selection'] > 0)
                                 Text("(必選 ${group['min_selection']})", style: const TextStyle(color: Colors.red, fontSize: 12)),
                               if (!isSingle && group['max_selection'] != null)
                                 Text("(最多 ${group['max_selection']})", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                             ],
                           ),
                           const SizedBox(height: 10),
                           Wrap(
                             spacing: 10,
                             runSpacing: 10,
                             children: mods.map((mod) {
                               final bool isSelected = selectedIds.contains(mod['id']);
                               final double price = (mod['price_adjustment'] as num).toDouble();
                               
                               return GestureDetector(
                                 onTap: () => _onModifierTap(group, Map<String, dynamic>.from(mod)),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                   decoration: BoxDecoration(
                                     color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Theme.of(context).scaffoldBackgroundColor,
                                     border: Border.all(
                                       color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.3),
                                       width: isSelected ? 1.5 : 1
                                     ),
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: Column(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Text(
                                         mod['name'], 
                                         style: TextStyle(
                                           color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface, 
                                           fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                         )
                                       ),
                                       if (price > 0)
                                          Text("+\$${price.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                     ],
                                   ),
                                 ),
                               );
                             }).toList(),
                           ),
                           const SizedBox(height: 24),
                         ],
                       );
                    }),
                    
                    // Note & Quantity (Always at bottom of scroll)
                    Text("備註", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _noteController, 
                      placeholder: "口味調整...", 
                      padding: const EdgeInsets.all(12),
                      placeholderStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1), // Light Green Background
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text("數量", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                      Row(children: [
                        CupertinoButton(padding: EdgeInsets.zero, child: const Icon(CupertinoIcons.minus_circle, size: 30), onPressed: () { if (_quantity > 1) setState(() => _quantity--); }),
                        SizedBox(width: 40, child: Text('$_quantity', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold))),
                        CupertinoButton(padding: EdgeInsets.zero, child: const Icon(CupertinoIcons.add_circled, size: 30), onPressed: () => setState(() => _quantity++)),
                      ]),
                    ]),
                  ],
                ),
          ),
          
          Divider(height: 1, color: Theme.of(context).dividerColor),
          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: Theme.of(context).colorScheme.primary,
                onPressed: _confirm,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Text("加入購物車", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                     const SizedBox(width: 10),
                     Text("\$${total.toStringAsFixed(0)}", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8))),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
