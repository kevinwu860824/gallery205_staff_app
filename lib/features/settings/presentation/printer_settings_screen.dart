// lib/features/settings/presentation/printer_settings_screen.dart

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<Map<String, dynamic>> printers = [];
  List<Map<String, dynamic>> printCategories = []; 
  String? shopId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getString('savedShopId');
    if (shopId == null) return;

    // 1. 讀取印表機 (包含 assigned_print_category_ids)
    final printerRes = await Supabase.instance.client
        .from('printer_settings')
        .select()
        .eq('shop_id', shopId!);

    // 2. 讀取出單工作站
    final pcRes = await Supabase.instance.client
        .from('print_categories')
        .select()
        .eq('shop_id', shopId!)
        .order('created_at', ascending: true);

    if (mounted) {
      setState(() {
        printers = List<Map<String, dynamic>>.from(printerRes);
        printCategories = List<Map<String, dynamic>>.from(pcRes);
      });
    }
  }

  // 輔助方法：統一輸入框樣式
  InputDecoration _buildInputDecoration({required String hintText, required BuildContext context}) {
    final theme = Theme.of(context);
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
      filled: true,
      fillColor: theme.scaffoldBackgroundColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
    );
  }

  // ----------------------------------------------------------------
  // Part 1: 出單工作站管理 (新增/編輯/刪除)
  // ----------------------------------------------------------------

  Future<void> _addOrEditPrintCategory({Map<String, dynamic>? category}) async {
    final isEdit = category != null;
    final controller = TextEditingController(text: category?['name'] ?? '');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(25)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? "編輯出單工作站" : "新增出單工作站", 
                style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                decoration: _buildInputDecoration(hintText: "例如：吧台、熱廚...", context: context),
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: colorScheme.onSurface))),
                  ElevatedButton(
                    onPressed: () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;

                      if (isEdit) {
                        await Supabase.instance.client
                            .from('print_categories')
                            .update({'name': name})
                            .eq('id', category['id']);
                      } else {
                        await Supabase.instance.client
                            .from('print_categories')
                            .insert({'shop_id': shopId, 'name': name});
                      }
                      if (mounted) Navigator.pop(context);
                      _loadData();
                    },
                    child: const Text('儲存'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePrintCategory(String id) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text("刪除工作站", style: TextStyle(color: colorScheme.onSurface)),
        content: const Text("確定要刪除此工作站嗎？相關的菜單設定可能會失效。", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("取消", style: TextStyle(color: colorScheme.onSurface))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("刪除", style: TextStyle(color: colorScheme.error))),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('print_categories').delete().eq('id', id);
      _loadData();
    }
  }

  // ----------------------------------------------------------------
  // Part 2: 印表機綁定邏輯 (Mapping)
  // ----------------------------------------------------------------

  Future<void> _showBindingDialog(Map<String, dynamic> printer) async {
    final String printerId = printer['id'];
    final String printerName = printer['name'];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    List<String> assignedIds = List<String>.from(printer['assigned_print_category_ids'] ?? []);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(25)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$printerName - 負責的工作站', style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('勾選此印表機要負責列印哪些區域', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                
                if (printCategories.isEmpty)
                   const Padding(
                     padding: EdgeInsets.all(20),
                     child: Text("尚未建立任何工作站，請先至上方新增。", style: TextStyle(color: Colors.orange)),
                   ),

                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: printCategories.length,
                    itemBuilder: (context, index) {
                      final pc = printCategories[index];
                      final pcId = pc['id'] as String;
                      final isChecked = assignedIds.contains(pcId);

                      return CheckboxListTile(
                        title: Text(pc['name'], style: TextStyle(color: colorScheme.onSurface)),
                        value: isChecked,
                        activeColor: colorScheme.primary,
                        checkColor: colorScheme.onPrimary,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              assignedIds.add(pcId);
                            } else {
                              assignedIds.remove(pcId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: colorScheme.onSurface))),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await Supabase.instance.client
                              .from('printer_settings')
                              .update({'assigned_print_category_ids': assignedIds})
                              .eq('id', printerId);

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _loadData(); 
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("綁定設定已儲存")));
                          
                        } catch (e) {
                          debugPrint("儲存失敗: $e");
                        }
                      },
                      child: const Text('儲存設定'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Part 3: 印表機基本操作 (新增/編輯/刪除/測試)
  // ----------------------------------------------------------------

  Future<void> _showPrinterDialog({Map<String, dynamic>? data}) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: data?['name'] ?? '');
    final ipController = TextEditingController(text: data?['ip'] ?? '');
    final isEdit = data != null;
    final printerId = data?['id'];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Default to 80mm
    int paperWidth = data?['paper_width_mm'] ?? 80;
    // Default false
    bool isReceipt = data?['is_receipt_printer'] ?? false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(25)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEdit ? l10n.printerDialogEditTitle : l10n.printerDialogAddTitle, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 20),
                TextFormField(controller: nameController, decoration: _buildInputDecoration(hintText: l10n.printerDialogHintName, context: context), style: TextStyle(color: colorScheme.onSurface)),
                const SizedBox(height: 12),
                TextFormField(controller: ipController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _buildInputDecoration(hintText: l10n.printerDialogHintIP, context: context), style: TextStyle(color: colorScheme.onSurface)),
                const SizedBox(height: 12),
                
                // Paper Width Dropdown
                DropdownButtonFormField<int>(
                  value: paperWidth,
                  decoration: _buildInputDecoration(hintText: "紙張寬度", context: context),
                  dropdownColor: theme.cardColor,
                  style: TextStyle(color: colorScheme.onSurface),
                  items: const [
                    DropdownMenuItem(value: 80, child: Text("80mm (標準)")),
                    DropdownMenuItem(value: 58, child: Text("58mm (小型)")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => paperWidth = val);
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                // Receipt Printer Toggle
                SwitchListTile(
                  title: Text("設為收據/結帳印表機", style: TextStyle(color: colorScheme.onSurface)),
                  value: isReceipt,
                  activeColor: colorScheme.primary,
                  onChanged: (val) => setDialogState(() => isReceipt = val),
                ),

                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface))),
                    SizedBox(
                      width: 110, height: 38,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final ip = ipController.text.trim();
                          if (name.isEmpty || ip.isEmpty) return;
                          
                          try {
                            if (isEdit) {
                              await Supabase.instance.client.from('printer_settings').update({
                                'name': name, 
                                'ip': ip,
                                'paper_width_mm': paperWidth,
                                'is_receipt_printer': isReceipt,
                              }).eq('id', printerId);
                            } else {
                              await Supabase.instance.client.from('printer_settings').insert({
                                'shop_id': shopId, 
                                'name': name, 
                                'ip': ip,
                                'paper_width_mm': paperWidth,
                                'is_receipt_printer': isReceipt,
                              });
                            }
                            if(mounted) Navigator.pop(context);
                            _loadData();
                          } catch (e) {
                            debugPrint("Save printer error: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                        child: Text(l10n.commonSave),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deletePrinter(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(l10n.printerDeleteTitle, style: TextStyle(color: colorScheme.onSurface)),
        content: const Text("確定要刪除此印表機嗎？", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel, style: TextStyle(color: colorScheme.onSurface))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.commonDelete, style: TextStyle(color: colorScheme.error))),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.from('printer_settings').delete().eq('id', id);
      _loadData();
    }
  }

  Future<void> _printTestTicket(Map<String, dynamic> printer) async {
    final l10n = AppLocalizations.of(context)!;
    final String ip = printer['ip'];
    final int paperWidth = printer['paper_width_mm'] ?? 80;
    final double targetWidth = (paperWidth == 58) ? 384.0 : 576.0;

    final profile = await CapabilityProfile.load();
    final printerInstance = NetworkPrinter(PaperSize.mm80, profile);
    final result = await printerInstance.connect(ip, port: 9100);
    if (result != PosPrintResult.success) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.printerTestConnectionFailed))); return; }
    
    // 簡單測試圖
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, targetWidth, 200), bgPaint); 
    
    final textStyle = ui.TextStyle(color: Colors.black, fontSize: 30);
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))..pushStyle(textStyle)..addText("Test Print ($paperWidth mm)\n測試列印");
    final paragraph = paragraphBuilder.build()..layout(ui.ParagraphConstraints(width: targetWidth));
    canvas.drawParagraph(paragraph, const Offset(0, 50));
    
    // Draw boundary lines to verify width
    final borderPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(1, 1, targetWidth -2, 198), borderPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(targetWidth.toInt(), 200);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final decoded = img.decodeImage(byteData!.buffer.asUint8List());

    if(decoded != null) printerInstance.image(decoded);
    printerInstance.feed(2); printerInstance.cut(); printerInstance.disconnect();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.printerTestTicketSuccess)));
  }

  Future<void> _openCashDrawer(String ip) async {
    final l10n = AppLocalizations.of(context)!;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(PaperSize.mm80, profile);
    final result = await printer.connect(ip, port: 9100);
    if (result != PosPrintResult.success) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.printerTestConnectionFailed))); return; }
    printer.drawer(pin: PosDrawer.pin2); printer.disconnect();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.printerCashDrawerOpenSuccess)));
  }

  // ----------------------------------------------------------------
  // UI 構建
  // ----------------------------------------------------------------

  Widget _buildPrintCategoryList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("出單工作站 (Print Stations)", style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(CupertinoIcons.add_circled, color: colorScheme.primary),
              onPressed: () => _addOrEditPrintCategory(),
            )
          ],
        ),
        if (printCategories.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("尚無工作站，請新增。", style: TextStyle(color: Colors.grey))),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: printCategories.map((pc) => Chip(
            backgroundColor: theme.cardColor,
            label: Text(pc['name'], style: TextStyle(color: colorScheme.onSurface)),
            deleteIcon: Icon(Icons.close, size: 16, color: colorScheme.error),
            onDeleted: () => _deletePrintCategory(pc['id']),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.grey)),
          )).toList(),
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.grey),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildPrinterCard(Map<String, dynamic> printer) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final String name = printer['name'] ?? l10n.commonUnknown;
    final String ip = printer['ip'] ?? 'N/A';
    final bool isReceipt = printer['is_receipt_printer'] ?? false;
    
    // 顯示負責的區域
    final List<String> assignedIds = List<String>.from(printer['assigned_print_category_ids'] ?? []);
    final assignedNames = printCategories.where((pc) => assignedIds.contains(pc['id'])).map((pc) => pc['name']).join(", ");

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      height: 140, 
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              if (isReceipt)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                   decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                   child: const Text("收據", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                 ),
              const SizedBox(width: 8),
              Text(l10n.printerSettingsLabelIP(ip), style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            assignedNames.isEmpty ? "尚未指定工作站" : "負責: $assignedNames",
            style: TextStyle(color: assignedNames.isEmpty ? Colors.orange : Colors.blue, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: Icon(CupertinoIcons.pencil_ellipsis_rectangle, color: colorScheme.onSurface), onPressed: () => _showPrinterDialog(data: printer)),
              IconButton(icon: Icon(CupertinoIcons.printer_fill, color: colorScheme.onSurface), onPressed: () => _printTestTicket(printer)), 
              IconButton(icon: Icon(CupertinoIcons.money_dollar_circle_fill, color: colorScheme.onSurface), onPressed: () => _openCashDrawer(ip)),
              IconButton(icon: Icon(CupertinoIcons.trash_fill, color: colorScheme.onSurface), onPressed: () => _deletePrinter(printer['id'])),
              IconButton(
                icon: Icon(CupertinoIcons.square_list_fill, color: colorScheme.onSurface), 
                onPressed: () => _showBindingDialog(printer),
                tooltip: "設定負責工作站",
              ),
            ],
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
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(top: safeAreaTop + 140, left: 16, right: 16, bottom: 40),
            children: [
              // 1. 出單工作站管理區塊
              _buildPrintCategoryList(),

              // 2. 印表機列表
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(l10n.printerSettingsListTitle, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500)),
              ),
              ...printers.map((printer) => _buildPrinterCard(printer)).toList(),
              
              if (printers.isEmpty)
                 Center(child: Padding(padding: const EdgeInsets.only(top: 50.0), child: Text(l10n.printerSettingsNoPrinters, style: TextStyle(color: colorScheme.onSurface))))
            ],
          ),
          
          // Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.only(top: safeAreaTop, bottom: 10),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      IconButton(icon: Icon(CupertinoIcons.chevron_left), color: colorScheme.onSurface, iconSize: 30, onPressed: () => context.pop()),
                      Center(child: Text(l10n.printerSettingsTitle, style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold))),
                      Positioned(
                        right: 4,
                        child: IconButton(icon: Icon(CupertinoIcons.add), color: colorScheme.onSurface, iconSize: 30, onPressed: () => _showPrinterDialog()),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}