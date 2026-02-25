// lib/core/services/printer_service.dart

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode/barcode.dart' as bc_pkg;
import 'package:barcode_widget/barcode_widget.dart' as bc_widget;
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/ordering/domain/entities/order_context.dart';
import '../../features/ordering/domain/entities/order_item.dart';
import './local_db_service.dart';

class PrinterService {
  final LocalDbService _localDb = LocalDbService();

  /// 執行智慧分單列印 (一般點餐)
  /// Returns list of item IDs that FAILED to print.
  Future<List<String>> processOrderPrinting(
    OrderContext context, 
    List<Map<String, dynamic>> printerSettings,
    List<Map<String, dynamic>> allPrintCategories,
    int orderSequenceNumber, 
  ) async {
    return await _coreProcessPrinting(
      context: context,
      itemsToPrint: context.order.items,
      printerSettings: printerSettings,
      allPrintCategories: allPrintCategories,
      orderSequenceNumber: orderSequenceNumber,
      isDeletion: false,
    );
  }

  /// 執行刪除單列印 (退菜)
  Future<List<String>> processDeletionPrinting(
    OrderContext context, 
    OrderItem deletedItem,
    List<Map<String, dynamic>> printerSettings,
    List<Map<String, dynamic>> allPrintCategories,
    int orderSequenceNumber,
  ) async {
    // 構造一個只包含該刪除品項的 List
    final itemCopy = OrderItem(
      id: deletedItem.id,
      menuItemId: deletedItem.menuItemId, // Copy menuItemId
      itemName: deletedItem.itemName,
      quantity: deletedItem.quantity,
      price: deletedItem.price,
      status: 'cancelled',
      targetPrintCategoryIds: deletedItem.targetPrintCategoryIds,
      selectedModifiers: deletedItem.selectedModifiers, 
      note: deletedItem.note,
    );

    return await _coreProcessPrinting(
      context: context,
      itemsToPrint: [itemCopy],
      printerSettings: printerSettings,
      allPrintCategories: allPrintCategories,
      orderSequenceNumber: orderSequenceNumber,
      isDeletion: true,
    );
  }

  // 共用核心邏輯
  Future<List<String>> _coreProcessPrinting({
    required OrderContext context,
    required List<OrderItem> itemsToPrint,
    required List<Map<String, dynamic>> printerSettings,
    required List<Map<String, dynamic>> allPrintCategories,
    required int orderSequenceNumber,
    required bool isDeletion,
  }) async {
    final Set<String> failedItemIds = {};

    // 1. Group items by Station ID
    Map<String, List<OrderItem>> itemsByStation = {};
    for (var item in itemsToPrint) {
      if (item.targetPrintCategoryIds.isEmpty) {
        debugPrint("品項 ${item.itemName} 未指定工作站，略過");
        continue;
      }
      for (String stationId in item.targetPrintCategoryIds) {
        itemsByStation.putIfAbsent(stationId, () => []).add(item);
      }
    }

    // 2. Assign Stations to Printers
    Map<String, Set<String>> tasksByPrinterIp = {}; // IP -> Set<StationId>
    for (var stationId in itemsByStation.keys) {
      var targetPrinters = printerSettings.where((p) {
        List<String> assigned = List<String>.from(p['assigned_print_category_ids'] ?? []);
        return assigned.contains(stationId);
      }).toList();

      if (targetPrinters.isEmpty) {
        debugPrint("警告: 工作站 ID $stationId 沒有分配給任何印表機");
        // No printer = Failed
        final items = itemsByStation[stationId] ?? [];
        failedItemIds.addAll(items.map((e) => e.id));
        continue;
      }

      for (var printer in targetPrinters) {
        final ip = printer['ip'];
        if (ip != null && ip.isNotEmpty) {
          tasksByPrinterIp.putIfAbsent(ip, () => {}).add(stationId);
        }
      }
    }

    // 3. Execute Printing
    for (var entry in tasksByPrinterIp.entries) {
      final ip = entry.key;
      final stationIds = entry.value.toList();
      
      final printerConfig = printerSettings.firstWhere(
        (p) => p['ip'] == ip, 
        orElse: () => <String, dynamic>{}
      );
      final int paperWidth = printerConfig['paper_width_mm'] ?? 80;

      debugPrint("正在發送至 $ip ($paperWidth mm)，包含工作站: $stationIds (刪除單: $isDeletion)");
      
      try {
        await _createAndExecuteSmartTask(
          context, 
          ip, 
          stationIds, 
          itemsByStation, 
          allPrintCategories,
          orderSequenceNumber,
          isDeletion,
          paperWidth,
        );
      } catch (e) {
         // Mark items as failed
         for (var sid in stationIds) {
            final items = itemsByStation[sid] ?? [];
            failedItemIds.addAll(items.map((i) => i.id));
         }
      }
    }
    
    return failedItemIds.toList();
  }

  Future<void> _createAndExecuteSmartTask(
    OrderContext context,
    String ip,
    List<String> stationIds,
    Map<String, List<OrderItem>> itemsByStation,
    List<Map<String, dynamic>> allPrintCategories,
    int orderSequenceNumber,
    bool isDeletion,
    int paperWidth, // New Arg
  ) async {
    final taskId = const Uuid().v4();
    final now = DateTime.now();

    await _localDb.insertPrintTask({
      'id': taskId,
      'order_group_id': context.order.id,
      'content_json': isDeletion ? '{"type":"deletion"}' : '{}',
      'printer_ip': ip,
      'status': 'pending',
      'created_at': now.toIso8601String(),
    });

    try {
      const PaperSize paper = PaperSize.mm80;
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(paper, profile);

      final result = await printer.connect(ip, port: 9100);
      if (result != PosPrintResult.success) {
        throw Exception("無法連線至印表機 $ip");
      }

      for (String stationId in stationIds) {
        final items = itemsByStation[stationId] ?? [];
        if (items.isEmpty) continue;

        final stationName = allPrintCategories.firstWhere(
          (c) => c['id'] == stationId, 
          orElse: () => {'name': '工作站'}
        )['name'];

        final Uint8List imageBytes = await _generatePrintImage(
          context, items, stationName, orderSequenceNumber, isDeletion, ip, paperWidth
        );
        
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          // Apply High Contrast to make text thicker/darker
          _applyHighContrast(decodedImage);
          
          printer.image(decodedImage);
          printer.feed(1);
          printer.cut(); 
        }
      }

      printer.disconnect();
      await _localDb.updatePrintTaskStatus(taskId, 'success');
    } catch (e) {
      debugPrint("列印失敗 ($ip): $e");
      await _localDb.updatePrintTaskStatus(taskId, 'failed', error: e.toString());
      throw e; // Rethrow to let caller know items failed
    }
  }

  /// Manually apply a threshold to make the image pure Black/White.
  /// Increasing threshold makes text thicker (captures lighter grays as black).
  void _applyHighContrast(img.Image src) {
    const int threshold = 220; // 0-255. High threshold = Darker output (Thicker text)
    final int black = img.getColor(0, 0, 0);
    final int white = img.getColor(255, 255, 255);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        if (img.getLuminance(pixel) < threshold) {
          src.setPixel(x, y, black);
        } else {
          src.setPixel(x, y, white);
        }
      }
    }
  }

  // ----------------------------------------------------------------
  // Custom Receipt Layout Engine
  // ----------------------------------------------------------------
  Future<Uint8List> _generatePrintImage(
    OrderContext context, 
    List<OrderItem> items, 
    String stationName, 
    int orderSequenceNumber,
    bool isDeletion,
    String printerIp,
    int paperWidth,
  ) async {
    final recorder = ui.PictureRecorder();
    
    // Logic: Reflow content based on actual paper width.
    // 80mm => 576px, 58mm => 384px.
    final double width = (paperWidth == 58) ? 384.0 : 576.0;
    final double padding = (paperWidth == 58) ? 0.0 : 10.0; // Minimize margin for 58mm
    
    // Estimate height. Since width is narrower for 58mm, lines might wrap more, so add buffer.
    final double estimatedHeight = 600.0 + (items.length * 150.0); 
    
    final canvas = ui.Canvas(recorder, Rect.fromPoints(Offset.zero, Offset(width, estimatedHeight)));
    
    // Fill Background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, estimatedHeight), bgPaint);

    const String fontFamily = 'NotoSansTC'; 
    
    // Font Configuration
    // Keep fonts reasonably large. For 58mm, 32px is extremely readable (large).
    final styleLabel = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.bold); // Bolder
    final styleValue = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.w900); // Bolder
    

    // Increased ITEM font size by 1.2x (32 -> 38.4 -> 38)
    final styleItemName = TextStyle(color: Colors.black, fontSize: 38, fontFamily: fontFamily, fontWeight: FontWeight.w600);
    final styleItemNameDeleted = TextStyle(color: Colors.black, fontSize: 38, fontFamily: fontFamily, fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough);
    final styleQty = TextStyle(color: Colors.black, fontSize: 38, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    
    // Modifier Style
    final styleModifier = TextStyle(color: Colors.black, fontSize: 26, fontFamily: fontFamily, fontWeight: FontWeight.w500);

    double y = 40;
    final double contentWidth = width - (padding * 2);
    final double x = padding;

    // 1. Transaction ID & Time
    final now = DateTime.now();
    final txnIdPrefix = DateFormat('yyyyMMddHHmm').format(now);
    final txnId = "$txnIdPrefix$orderSequenceNumber";
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    _drawText(canvas, "交易序號：$txnId", x, y, contentWidth, styleLabel.copyWith(fontSize: 18));
    y += 26;
    _drawText(canvas, "列印時間：$timeStr", x, y, contentWidth, styleLabel.copyWith(fontSize: 18));
    y += 40;

    // 2. Black Bar Header
    // Reduced by 40% (0.6x)
    final double headerSize = (paperWidth == 58) ? 36 : 48;
    final double seqSize = (paperWidth == 58) ? 42 : 54;
    
    // Reduced bar height
    final double barHeight = (paperWidth == 58) ? 60 : 80;
    
    final blackPaint = Paint()..color = Colors.black;
    // Full width bar
    final double barWidth = contentWidth; 
    canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), blackPaint);
    
    final styleHeaderInverse = TextStyle(color: Colors.white, fontSize: headerSize, fontFamily: fontFamily, fontWeight: FontWeight.w900);
    final styleSeqInverse = TextStyle(color: Colors.white, fontSize: seqSize, fontFamily: fontFamily, fontWeight: FontWeight.w900);

    final tableName = "${context.tableNames.join(",")}桌"; 
    
    // Vertically center text in bar
    double textY = y + (barHeight - headerSize) / 2 - 5; // Adjustment
    
    // Fit text in bar (Left)
    _drawText(canvas, tableName, x + 10, textY, barWidth * 0.6, styleHeaderInverse); 

    // Calculate Total Quantity
    int totalQty = 0;
    for (var i in items) {
      totalQty += i.quantity;
    }
    final String badgeText = "$totalQty";

    // Right align Item Count (White)
    // Adjust Y for text specifically if needed
    double seqY = y + (barHeight - seqSize) / 2 - 5;
    _drawTextRight(canvas, badgeText, width - padding - 10, seqY, barWidth * 0.4, styleSeqInverse);

    y += barHeight + 20; // Add extra spacing after big bar
    
    // 3. Pax Info
    _drawText(canvas, "人數：${context.peopleCount} 大 0 小", x, y, contentWidth, styleLabel);
    y += 30;

    _drawDivider(canvas, width, y); // Divider spans full width
    y += 20;

    // 4. Station Alert
    String subtitle = "[$stationName]";
    if (isDeletion) subtitle += " 【退菜單】";
    
    _drawText(canvas, subtitle, x, y, contentWidth, styleValue);
    y += 40;

    // 5. Items List - Consolidated
    List<OrderItem> consolidatedItems = [];
    for (var item in items) {
      bool found = false;
      // Key generation
      final String iName = item.itemName;
      final double iPrice = item.price;
      final String iNote = item.note;
      
      String iModStr = "";
      if (item.selectedModifiers.isNotEmpty) {
          final modNames = item.selectedModifiers.map((m) => (m['name'] as String? ?? '')).toList();
          modNames.sort();
          iModStr = modNames.join('|');
      }

      for (int k = 0; k < consolidatedItems.length; k++) {
         final existing = consolidatedItems[k];
         final String eName = existing.itemName;
         final double ePrice = existing.price;
         final String eNote = existing.note;
         
         String eModStr = "";
         if (existing.selectedModifiers.isNotEmpty) {
             final modNames = existing.selectedModifiers.map((m) => (m['name'] as String? ?? '')).toList();
             modNames.sort();
             eModStr = modNames.join('|');
         }

         if (iName == eName && iPrice == ePrice && iNote == eNote && iModStr == eModStr) {
             // Merge
             final newQty = existing.quantity + item.quantity;
             consolidatedItems[k] = existing.copyWith(quantity: newQty);
             found = true;
             break;
         }
      }
      
      if (!found) {
         consolidatedItems.add(item); 
      }
    }

    for (var item in consolidatedItems) {
      String name = item.itemName;
      if (isDeletion) {
        name = "刪 $name";
      }

      // Quantity takes rightmost space
      final double qtyWidth = 70;
      final double nameWidth = contentWidth - qtyWidth;

      final double nameHeight = _drawText(canvas, name, x, y, nameWidth, isDeletion ? styleItemNameDeleted : styleItemName);
      
      _drawTextRight(canvas, "${item.quantity}", width - padding, y, qtyWidth, styleQty);

      // Use dynamic height from name (which might wrap)
      // Ensure at least 50 height or nameHeight + padding
      y += (nameHeight > 40 ? nameHeight : 40) + 10; 

      // Modifiers
      if (item.selectedModifiers.isNotEmpty) {
        String modStr = item.selectedModifiers.map((m) => m['name'] ?? '').where((s) => s.isNotEmpty).join(', ');
        if (modStr.isNotEmpty) {
           _drawText(canvas, modStr, x + 20, y, contentWidth - 20, styleModifier);
           y += 35;
        }
      }

      // Notes
      if (item.note.isNotEmpty) {
        _drawText(canvas, "備註: ${item.note}", x + 20, y, contentWidth - 20, styleLabel.copyWith(fontSize: 24));
        y += 35;
      }
      
      y += 15; 
    }

    y += 20;
    _drawDivider(canvas, width, y);
    y += 10;
    
    // 6. Footer
    final String machineId = printerIp.split('.').last;
    
    // Display Staff Name or Fallback
    // Sanitize: Trim and remove Zero Width Space / invisible chars
    String safeName = context.staffName.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    debugPrint("PRINTER_DEBUG: Raw='${context.staffName}' (Len: ${context.staffName.length}), Safe='$safeName' (Len: ${safeName.length}), CodeUnits: ${context.staffName.codeUnits}");

    final String staffDisplay = safeName.isNotEmpty ? safeName : "-";
    
    // Center Align Staff Name (Since Machine ID is removed)
    _drawTextCenter(canvas, "人員：$staffDisplay", width, y, styleLabel);
    
    y += 45; // Ensure enough space for footer text height

    final picture = recorder.endRecording();
    final imgObj = await picture.toImage(width.toInt(), y.toInt());
    final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  // Helpers
  double _drawText(ui.Canvas canvas, String text, double x, double y, double maxWidth, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
    textPainter.layout(minWidth: 0, maxWidth: maxWidth);
    textPainter.paint(canvas, Offset(x, y));
    return textPainter.height;
  }

  void _drawTextRight(ui.Canvas canvas, String text, double rightX, double y, double maxWidth, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
    textPainter.layout(minWidth: 0, maxWidth: maxWidth);
    textPainter.paint(canvas, Offset(rightX - textPainter.width, y));
  }

  void _drawDivider(ui.Canvas canvas, double width, double y) {
    final paint = Paint()..color = Colors.black..strokeWidth = 2;
    canvas.drawLine(Offset(0, y), Offset(width, y), paint);
  }
  // ----------------------------------------------------------------
  // Checkout Bill Printing
  // ----------------------------------------------------------------
  Future<int> printBill({
    required OrderContext context,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> printerSettings,
    required double subtotal,
    required double serviceFee,
    required double discount,
    required double finalTotal,
    double taxAmount = 0, // NEW
    String? taxLabel, // NEW
    int? orderSequenceNumber, // NEW
    List<Map<String, dynamic>>? payments, // NEW: Payment Details
  }) async {
    // 1. Find Receipt Printers
    final targets = printerSettings.where((p) => p['is_receipt_printer'] == true).toList();
    
    if (targets.isEmpty) {
      debugPrint("No receipt printer configured (is_receipt_printer=true).");
      return -1; 
    }

    int successCount = 0;

    // 2. Execute for each printer
    for (var printerConfig in targets) {
      final String ip = printerConfig['ip'];
      final int paperWidth = printerConfig['paper_width_mm'] ?? 80;
      
      if (ip.isEmpty) continue;

      try {
        final profile = await CapabilityProfile.load();
        final printer = NetworkPrinter(PaperSize.mm80, profile);

        final result = await printer.connect(ip, port: 9100);
        if (result != PosPrintResult.success) {
          debugPrint("Receipt Printer Connect Failed: $ip");
          continue;
        }

        final Uint8List imageBytes = await _generateBillImage(
          context: context,
          items: items,
          subtotal: subtotal,
          serviceFee: serviceFee,
          discount: discount,
          finalTotal: finalTotal,
          taxAmount: taxAmount,
          taxLabel: taxLabel,
          orderSequenceNumber: orderSequenceNumber,
          payments: payments, // NEW
          printerIp: ip,
          paperWidth: paperWidth,
        );
        
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          _applyHighContrast(decodedImage);
          printer.image(decodedImage);
          printer.feed(1);
          printer.cut();
          successCount++;
        }
        
        printer.disconnect();

      } catch (e) {
        debugPrint("Print Bill Error ($ip): $e");
      }
    }
    return successCount;
  }

  // ----------------------------------------------------------------
  // Payment Detail Printing (結帳明細)
  // ----------------------------------------------------------------
  Future<int> printPaymentDetails({
    required OrderContext context,
    required double finalTotal,
    required String paymentMethod,
    required double receivedAmount,
    required double changeAmount,
    required String? invoiceNumber,
    required String? unifiedTaxNumber, // 統編
    required List<Map<String, dynamic>> printerSettings,
  }) async {
    // 1. Find Receipt Printers
    final targets = printerSettings.where((p) => p['is_receipt_printer'] == true).toList();
    
    if (targets.isEmpty) {
      debugPrint("No receipt printer configured.");
      return 0; 
    }

    int successCount = 0;

    for (var printerConfig in targets) {
      final String ip = printerConfig['ip'];
      final int paperWidth = printerConfig['paper_width_mm'] ?? 80;
      
      if (ip.isEmpty) continue;

      try {
        final profile = await CapabilityProfile.load();
        final printer = NetworkPrinter(PaperSize.mm80, profile);

        final result = await printer.connect(ip, port: 9100);
        if (result != PosPrintResult.success) {
          debugPrint("Printer Connect Failed: $ip");
          continue;
        }

        final Uint8List imageBytes = await _generatePaymentDetailImage(
          context: context,
          finalTotal: finalTotal,
          paymentMethod: paymentMethod,
          receivedAmount: receivedAmount,
          changeAmount: changeAmount,
          invoiceNumber: invoiceNumber,
          unifiedTaxNumber: unifiedTaxNumber,
          printerIp: ip,
          paperWidth: paperWidth,
        );
        
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          _applyHighContrast(decodedImage);
          printer.image(decodedImage);
          printer.feed(1);
          printer.cut();
          successCount++;
        }
        
        printer.disconnect();

      } catch (e) {
        debugPrint("Print Payment Detail Error ($ip): $e");
      }
    }
    return successCount;
  }

  Future<Uint8List> _generatePaymentDetailImage({
    required OrderContext context,
    required double finalTotal,
    required String paymentMethod,
    required double receivedAmount,
    required double changeAmount,
    required String? invoiceNumber,
    required String? unifiedTaxNumber,
    required String printerIp,
    required int paperWidth,
  }) async {
    final recorder = ui.PictureRecorder();
    final double width = (paperWidth == 58) ? 384.0 : 576.0;
    final double padding = (paperWidth == 58) ? 0.0 : 10.0;
    
    // Fixed height estimate since content is static
    final double estimatedHeight = 600.0; 
    
    final canvas = ui.Canvas(recorder, Rect.fromPoints(Offset.zero, Offset(width, estimatedHeight)));
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, estimatedHeight), bgPaint);

    const String fontFamily = 'NotoSansTC'; 
    
    // Styles
    final styleLabel = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleTitle = TextStyle(color: Colors.black, fontSize: 40, fontFamily: fontFamily, fontWeight: FontWeight.w900);
    final styleValueBig = TextStyle(color: Colors.black, fontSize: 32, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleNormal = TextStyle(color: Colors.black, fontSize: 26, fontFamily: fontFamily, fontWeight: FontWeight.w500);

    double y = 40;
    final double contentWidth = width - (padding * 2);
    final double x = padding;

    // 1. Header
    _drawTextCenter(canvas, "結帳明細 (PAYMENT)", width, y, styleTitle);
    y += 50;

    final now = DateTime.now();
    final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
    
    _drawText(canvas, "時間: $timeStr", x, y, contentWidth, styleLabel);
    y += 30;
    _drawText(canvas, "單號: #${context.order.id.substring(0,6)}", x, y, contentWidth, styleLabel);
    y += 30;

    _drawDivider(canvas, width, y);
    y += 20;

    // 2. Payment Info
    _drawSummaryRow(canvas, "應收金額", "\$${finalTotal.toStringAsFixed(0)}", x, y, width, padding, styleLabel, styleValueBig);
    y += 40;
    
    _drawSummaryRow(canvas, "支付方式", paymentMethod, x, y, width, padding, styleLabel, styleNormal);
    y += 35;
    
    _drawSummaryRow(canvas, "實收金額", "\$${receivedAmount.toStringAsFixed(0)}", x, y, width, padding, styleLabel, styleNormal);
    y += 35;

    if (changeAmount > 0) {
       _drawSummaryRow(canvas, "找零", "\$${changeAmount.toStringAsFixed(0)}", x, y, width, padding, styleLabel, styleValueBig);
       y += 35;
    }

    y += 10;
    _drawDivider(canvas, width, y);
    y += 20;

    // 3. Invoice Info
    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      _drawText(canvas, "發票號碼：$invoiceNumber", x, y, contentWidth, styleLabel);
      y += 35;
    }
    
    if (unifiedTaxNumber != null && unifiedTaxNumber.isNotEmpty) {
      _drawText(canvas, "統一編號：$unifiedTaxNumber", x, y, contentWidth, styleLabel);
      y += 35;
    }

    y += 40;
    // Footer
    String safeName = context.staffName.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    final String staffDisplay = safeName.isNotEmpty ? safeName : "人員";
    _drawTextCenter(canvas, "結帳人員：$staffDisplay", width, y, styleLabel);

    y += 50;

    final picture = recorder.endRecording();
    final imgObj = await picture.toImage(width.toInt(), y.toInt());
    final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _generateBillImage({
    required OrderContext context,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double serviceFee,
    required double discount,
    required double finalTotal,
    required String printerIp,
    required int paperWidth,
    double taxAmount = 0,
    String? taxLabel,
    int? orderSequenceNumber,
    List<Map<String, dynamic>>? payments,
  }) async {
    final recorder = ui.PictureRecorder();
    
    // Width Logic (Same as Order)
    final double width = (paperWidth == 58) ? 384.0 : 576.0;
    final double padding = (paperWidth == 58) ? 0.0 : 10.0; 
    
    // Estimate Height
    final double estimatedHeight = 800.0 + (items.length * 150.0); 
    
    final canvas = ui.Canvas(recorder, Rect.fromPoints(Offset.zero, Offset(width, estimatedHeight)));
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, estimatedHeight), bgPaint);

    const String fontFamily = 'NotoSansTC'; 
    
    // Styles
    final styleLabel = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    
    // Header Title
    final styleTitle = TextStyle(color: Colors.black, fontSize: 40, fontFamily: fontFamily, fontWeight: FontWeight.w900);
    
    // Item List
    final styleItemName = TextStyle(color: Colors.black, fontSize: 28, fontFamily: fontFamily, fontWeight: FontWeight.w600);
    final styleItemSmall = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.w500); 
    final stylePrice = TextStyle(color: Colors.black, fontSize: 28, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    
    // Totals
    final styleTotalLabel = TextStyle(color: Colors.black, fontSize: 26, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleTotalValue = TextStyle(color: Colors.black, fontSize: 32, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleFinalTotal = TextStyle(color: Colors.black, fontSize: 48, fontFamily: fontFamily, fontWeight: FontWeight.w900);

    double y = 40;
    final double contentWidth = width - (padding * 2);
    final double x = padding;

    // 1. Transaction ID & Time
    // 1. Transaction ID & Time
    final now = DateTime.now();
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    
    // ID Generation: Try to use Created At + Seq if available to match Ticket style
    String txnId;
    if (orderSequenceNumber != null && orderSequenceNumber > 0) {
       final createdTime = DateFormat('yyyyMMddHHmm').format(context.order.createdAt ?? now);
       txnId = "$createdTime$orderSequenceNumber";
    } else {
       txnId = context.order.id.substring(0,8);
    }

    _drawText(canvas, "交易序號：$txnId", x, y, contentWidth, styleLabel.copyWith(fontSize: 18));
    y += 26;
    _drawText(canvas, "列印時間：$timeStr", x, y, contentWidth, styleLabel.copyWith(fontSize: 18));
    y += 40;

    // 2. Black Bar Header (Unified Style)
    // Reduced by 40% (0.6x)
    final double headerSize = (paperWidth == 58) ? 36 : 48;
    
    // Reduced bar height
    final double barHeight = (paperWidth == 58) ? 60 : 80;
    
    final blackPaint = Paint()..color = Colors.black;
    // Full width bar
    final double barWidth = contentWidth; 
    canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), blackPaint);
    
    final styleHeaderInverse = TextStyle(color: Colors.white, fontSize: headerSize, fontFamily: fontFamily, fontWeight: FontWeight.w900);

    final title = "結帳單 (RECEIPT)"; 
    
    // Vertically center text in bar
    double textY = y + (barHeight - headerSize) / 2 - 5; 
    
    // Center Title
    final textSpan = TextSpan(text: title, style: styleHeaderInverse);
    final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
    textPainter.layout(minWidth: barWidth, maxWidth: barWidth);
    textPainter.paint(canvas, Offset(x, textY));
    
    y += barHeight + 20;

    // 3. Info Row (Table)
    _drawText(canvas, "桌號：${context.tableNames.join(",")}", x, y, contentWidth, styleLabel);
    y += 30;
    _drawDivider(canvas, width, y);
    y += 20;

    // 4. Items Header
    _drawText(canvas, "品名", x, y, contentWidth/2, styleItemSmall);
    _drawTextRight(canvas, "金額", width-padding, y, 100, styleItemSmall);
    _drawTextRight(canvas, "數量", width-padding-110, y, 60, styleItemSmall);
    y += 30;

    // Consolidate Items (Merge duplicates unless they have notes)
    List<Map<String, dynamic>> consolidatedItems = [];
    for (var item in items) {
      bool found = false;
      // Key generation for comparison
      final String iName = item['item_name'];
      final double iPrice = (item['price'] as num).toDouble();
      final String iNote = item['note'] ?? '';
      
      // Modifiers String for Key
      String iModStr = "";
      if (item['modifiers'] != null && item['modifiers'] is List) {
         final mods = item['modifiers'] as List;
         final modNames = mods.map((m) => (m is Map) ? (m['name'] ?? '') : '').toList();
         modNames.sort(); // Ensure order doesn't matter for merging
         iModStr = modNames.join('|');
      }

      for (var existing in consolidatedItems) {
         final String eName = existing['item_name'];
         final double ePrice = (existing['price'] as num).toDouble();
         final String eNote = existing['note'] ?? '';
         
         String eModStr = "";
         if (existing['modifiers'] != null && existing['modifiers'] is List) {
             final mods = existing['modifiers'] as List;
             final modNames = mods.map((m) => (m is Map) ? (m['name'] ?? '') : '').toList();
             modNames.sort();
             eModStr = modNames.join('|');
         }

         if (iName == eName && iPrice == ePrice && iNote == eNote && iModStr == eModStr) {
             // Merge
             existing['quantity'] = ((existing['quantity'] as num).toInt() + (item['quantity'] as num).toInt());
             found = true;
             break;
         }
      }
      
      if (!found) {
         // Create a copy to avoid mutating original source if needed, though Maps are ref.
         // Deep copy modifiers? Not strictly needed if we don't mutate them.
         // We do mutate quantity. So we should copy valid map items.
         consolidatedItems.add(Map<String, dynamic>.from(item));
      }
    }

    // 5. Items Loop (Dynamic Height)
    for (var item in consolidatedItems) {
       final String name = item['item_name'];
       final int qty = (item['quantity'] as num).toInt();
       
       // Fix: Add modifier prices to base price
       double price = (item['price'] as num).toDouble();
       
       // Handle mismatched keys (modifiers vs selected_modifiers)
       final rawModifiers = item['modifiers'] ?? item['selected_modifiers'];
       final List<Map<String, dynamic>> modifierList = [];

       if (rawModifiers != null && rawModifiers is List) {
          for (var m in rawModifiers) {
             if (m is Map) {
                modifierList.add(Map<String, dynamic>.from(m));
             }
          }
       }

       // Calculate price adjustments
       for(var m in modifierList) {
           // Check 'price' first (standard), then 'price_adjustment' (DB col)
           price += ((m['price'] ?? m['price_adjustment'] ?? 0) as num).toDouble();
       }

       final double amount = price * qty;
       final bool isFree = price == 0;
       
       String displayName = name;
       if(isFree) displayName += " (招待)";

       // Name (Left) - Use Unified Style & Dynamic Height
       final double qtyWidth = 70;
       // [FIX] Reduce name width to avoid overlay with Qty. Qty is at width-padding-110 (ends there).
       // Actually Qty starts approx at width-padding-170.
       // So Name should end before that.
       // Safe width = contentWidth - 170.
       final double nameWidth = contentWidth - 170; 
       
       // Calculate dynamic height
       final double nameHeight = _drawText(canvas, displayName, x, y, nameWidth, styleItemName);
       
       // Amount (Right)
       _drawTextRight(canvas, "\$${amount.toStringAsFixed(0)}", width-padding, y, 100, stylePrice);
       
       // Qty (Middle-Right)
       _drawTextRight(canvas, "x$qty", width-padding-110, y, 60, styleItemName);
       
       // Dynamic Spacing
       y += (nameHeight > 35 ? nameHeight : 35) + 10;
       
       // Modifiers Display
       if (modifierList.isNotEmpty) {
           List<String> modStrings = [];
           for(var m in modifierList) {
              String mName = m['name'] ?? '';
              double mPrice = ((m['price'] ?? m['price_adjustment'] ?? 0) as num).toDouble();
              if (mPrice > 0) {
                 mName += " (+\$${mPrice.toInt()})";
              }
              modStrings.add(mName);
           }
           
           if (modStrings.isNotEmpty) {
              final modStr = modStrings.join(", ");
              final modHeight = _drawText(canvas, modStr, x+20, y, contentWidth-20, styleItemSmall);
              y += modHeight + 10;
           }
       }
       y += 10;
    }
    
    y += 15;
    _drawDivider(canvas, width, y); // Top Divider
    y += 20;

    // 6. Totals
    int totalQty = items.fold(0, (sum, item) => sum + (item['quantity'] as num).toInt());
    
    _drawSummaryRow(canvas, "總數量", "$totalQty", x, y, width, padding, styleTotalLabel, styleTotalValue);
    y += 45; // Increased from 20 to 45 to clear text
    _drawDivider(canvas, width, y); // Bottom Divider
    y += 25; // Spacing to Subtotal

    _drawSummaryRow(canvas, "小計", "\$${subtotal.toStringAsFixed(0)}", x, y, width, padding, styleTotalLabel, styleTotalValue);
    y += 35;
    
    if (serviceFee > 0) {
      _drawSummaryRow(canvas, "服務費", "\$${serviceFee.toStringAsFixed(0)}", x, y, width, padding, styleTotalLabel, styleTotalValue);
      y += 35;
    }
    
    if (discount > 0) {
      _drawSummaryRow(canvas, "折扣", "-\$${discount.toStringAsFixed(0)}", x, y, width, padding, styleTotalLabel, styleTotalValue);
      y += 35;
    }

    if (taxAmount > 0) {
      _drawSummaryRow(canvas, taxLabel ?? "稅額", "\$${taxAmount.toStringAsFixed(0)}", x, y, width, padding, styleTotalLabel, styleTotalValue.copyWith(fontSize: 24));
      y += 35;
    }

    y += 10;
    _drawDivider(canvas, width, y);
    y += 20;

    // Final Total
    _drawText(canvas, "總金額", x, y+10, contentWidth/2, styleTotalLabel.copyWith(fontSize: 36));
    _drawTextRight(canvas, "\$${finalTotal.toStringAsFixed(0)}", width-padding, y, contentWidth/2, styleFinalTotal);
    
    y += 80;

    // 7. Payment Details (If provided)
    if (payments != null && payments.isNotEmpty) {
      _drawDivider(canvas, width, y);
      y += 20;
      
      double totalPaid = 0;
      
      for (var p in payments) {
        String method = p['method'] ?? 'Cash';
        double amount = (p['amount'] as num).toDouble();
        String ref = p['ref'] ?? ''; // Last 4
        
        totalPaid += amount;
        
        String label = method;
        // Credit Card Last 4
        if (ref.isNotEmpty) {
           label += " ($ref)"; // User asked for "Last 4", simpler display "Visa (1234)"
        }
        
        // Paid Amount Line
        _drawSummaryRow(canvas, label, "\$${amount.toStringAsFixed(0)}", x, y, width, padding, styleLabel, styleTotalValue);
        y += 35;
      }
      
      // Change (Only if totalPaid > finalTotal)
      if (totalPaid > finalTotal) { 
         double change = totalPaid - finalTotal;
         _drawSummaryRow(canvas, "找零", "\$${change.toStringAsFixed(0)}", x, y, width, padding, styleLabel, styleTotalValue.copyWith(fontSize: 24));
         y += 35;
      }
      
      y += 10;
      _drawDivider(canvas, width, y);
      y += 20;
    }

    // Footer - Unified Style (Centered Staff, No Machine ID)
    String safeName = context.staffName.trim().replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    final String staffDisplay = safeName.isNotEmpty ? safeName : "-";
    _drawTextCenter(canvas, "結帳人員：$staffDisplay", width, y, styleLabel);
    
    y += 40;
    _drawTextCenter(canvas, "謝謝光臨", width, y, styleLabel);
    y += 50;

    final picture = recorder.endRecording();
    final imgObj = await picture.toImage(width.toInt(), y.toInt());
    final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }


  // ----------------------------------------------------------------
  // E-Invoice Proof Printing (電子發票證明聯)
  // ----------------------------------------------------------------
  Future<int> printInvoiceProof({
    required OrderGroup order,
    required List<Map<String, dynamic>> printerSettings,
    required String shopName,
    required String sellerUbn,
    String? shopCode,
    String? address,
    String? phone,
    required List<Map<String, dynamic>> itemDetails,
    bool isReprint = false,
    bool shouldCut = true,
  }) async {
    final targets = printerSettings.where((p) => p['is_receipt_printer'] == true).toList();
    if (targets.isEmpty) return 0;

    int successCount = 0;
    for (var printerConfig in targets) {
      final String ip = printerConfig['ip'] ?? '';
      final int paperWidth = printerConfig['paper_width_mm'] ?? 80;
      if (ip.isEmpty) continue;

      try {
        final profile = await CapabilityProfile.load();
        final printer = NetworkPrinter(paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);

        final result = await printer.connect(ip, port: 9100);
        if (result != PosPrintResult.success) continue;

        final Uint8List imageBytes = await _generateInvoiceProofImage(
          order: order,
          shopName: shopName,
          sellerUbn: sellerUbn,
          shopCode: shopCode,
          address: address,
          phone: phone,
          itemDetails: itemDetails,
          paperWidth: paperWidth,
          isReprint: isReprint,
        );
        
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          _applyHighContrast(decodedImage);
          printer.image(decodedImage);
          if (shouldCut) {
            printer.feed(2); 
            printer.cut();
          }
          successCount++;
        }
        printer.disconnect();
      } catch (e) {
        debugPrint("Print Invoice Proof Error ($ip): $e");
      }
    }
    return successCount;
  }

  Future<Uint8List> _generateInvoiceProofImage({
    required OrderGroup order,
    required String shopName,
    required String sellerUbn,
    String? shopCode,
    String? address,
    String? phone,
    required List<Map<String, dynamic>> itemDetails,
    required int paperWidth,
    bool isReprint = false,
  }) async {
  final recorder = ui.PictureRecorder();
  final double canvWidth = (paperWidth == 58) ? 384.0 : 576.0;
  // Reduce proofWidth to ensure it fits with margins. 
  // Standard 80mm is 576, 58mm is 384.
  double proofWidth = 380.0;
  if (proofWidth > canvWidth - 40) {
    proofWidth = canvWidth - 40; // Maintain at least 20px margin on each side
  }
  final double startX = (canvWidth - proofWidth) / 2;

  // Increased from 1500 to 2000 to prevent long B2B itemized lists from being digitally clipped
  const double maxHeight = 2000.0; 
  final canvas = ui.Canvas(recorder, Rect.fromPoints(Offset.zero, Offset(canvWidth, maxHeight)));
  
  final bgPaint = Paint()..color = Colors.white;
  canvas.drawRect(Rect.fromLTWH(0, 0, canvWidth, maxHeight), bgPaint);

  const String fontFamily = 'NotoSansTC';
  final styleLogo = TextStyle(color: Colors.black, fontSize: 62, fontFamily: fontFamily, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic);
  final styleTitle = TextStyle(color: Colors.black, fontSize: 44, fontFamily: fontFamily, fontWeight: FontWeight.bold);
  final stylePeriod = TextStyle(color: Colors.black, fontSize: 42, fontFamily: fontFamily, fontWeight: FontWeight.bold);
  final styleInvoiceNum = TextStyle(color: Colors.black, fontSize: 52, fontFamily: fontFamily, fontWeight: FontWeight.w900);
  final styleNormal = TextStyle(color: Colors.black, fontSize: 26, fontFamily: fontFamily, fontWeight: FontWeight.w500);
  final styleMeta = TextStyle(color: Colors.black, fontSize: 28, fontFamily: fontFamily, fontWeight: FontWeight.bold);
  final styleFooter = TextStyle(color: Colors.black, fontSize: 22, fontFamily: fontFamily, fontWeight: FontWeight.w500);

  double y = 40;

  // 1. Header: Shop Name (Logo)
  _drawTextCenter(canvas, shopName, canvWidth, y, styleLogo);
  y += 75;

  // 2. Title
  if (isReprint) {
    _drawTextCenter(canvas, "電子發票證明聯 (補印)", canvWidth, y, styleTitle.copyWith(fontSize: 38));
  } else {
    _drawTextCenter(canvas, "電子發票證明聯", canvWidth, y, styleTitle);
  }
  y += 65;

  // 3. Period
  final time = (order.checkoutTime ?? DateTime.now()).toLocal();
  final year = time.year - 1911;
  final month = time.month;
  final periodStart = (month % 2 == 0) ? month - 1 : month;
  final periodEnd = periodStart + 1;
  final periodStartStr = periodStart.toString().padLeft(2, '0');
  final periodEndStr = periodEnd.toString().padLeft(2, '0');
  final periodStr = "${year}年$periodStartStr-$periodEndStr月";

  _drawTextCenter(canvas, periodStr, canvWidth, y, stylePeriod);
  y += 60;

  // 4. Invoice Number (Boldly formatted with hyphen)
  String rawNum = order.ezpayInvoiceNumber ?? "XX-XXXXXXXX";
  String formattedNum = rawNum;
  if (rawNum.length == 10 && !rawNum.contains('-')) {
    formattedNum = "${rawNum.substring(0, 2)}-${rawNum.substring(2)}";
  }
  _drawTextCenter(canvas, formattedNum, canvWidth, y, styleInvoiceNum);
  y += 70;

  // 5. Timestamp (YYYY-MM-DD HH:mm:ss)
  final String timestamp = "${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}";
  _drawText(canvas, timestamp, startX, y, proofWidth, styleNormal);
  y += 40;

  // 6. Metadata Layout
  final randomNum = order.ezpayRandomNum ?? "0000";
  final totalAmt = order.finalAmount?.toInt() ?? 0;
  final buyerUbn = order.buyerUbn ?? "";
  
  // Row 1: Random Code and Total
  _drawText(canvas, "隨機碼 : $randomNum", startX, y, proofWidth/2, styleMeta);
  _drawTextRight(canvas, "總計 : $totalAmt", startX + proofWidth, y, proofWidth/2, styleMeta);
  y += 40;

  // Row 2: Seller UBN
  _drawText(canvas, "賣方 : $sellerUbn", startX, y, proofWidth, styleMeta);

  if (buyerUbn.isNotEmpty && buyerUbn != "00000000") {
    y += 40;
    _drawText(canvas, "買方 : $buyerUbn", startX, y, proofWidth, styleMeta);
  }

  // 7. Barcode Code 128 (Standard for E-Invoice)
  if (order.ezpayInvoiceNumber != null && order.ezpayInvoiceNumber!.isNotEmpty) {
    y += 50;
    // --- PIXEL PERFECT MANUAL PAINTER ---
    // The `barcode_widget` package relies on Flutter UI nodes. Instead, we use the core 
    // `barcode` package to get the exact boolean map of the Code128 pattern, and paint
    // it manually onto the Canvas.
    final String barcodeData = "${year}$periodEndStr${order.ezpayInvoiceNumber}$randomNum";
    final bc = bc_pkg.Barcode.code128();
    final bcPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    // 1. Get the logical structure of the barcode. 
    // We pass a dummy width (e.g., 200) just to satisfy the API. 
    // The barcode package will return logical units that we will rescale perfectly anyway.
    final bcPoints = bc.make(barcodeData, width: 200.0, height: 80);
    
    // 2. Find total logical width
    double totalLogicalWidth = 0;
    for (var p in bcPoints) {
      if (p.left + p.width > totalLogicalWidth) {
        totalLogicalWidth = p.left + p.width;
      }
    }
    
    // 3. FORCE multiplier to prevent thermal bleed. 
    // Usually Code128 is ~150-180 units wide. * 2.0 = ~300-360px (fits easily in 380px proofWidth)
    final double moduleMultiplier = 2.0;
    final double finalPixelWidth = totalLogicalWidth * moduleMultiplier;
    
    // 4. Center it on the paper
    final double bcStartX = startX + (proofWidth - finalPixelWidth) / 2;
    
    // 5. Paint it to canvas with absolute, rounded integer constraints
    for (var p in bcPoints) {
      if (p is bc_pkg.BarcodeBar) {
         // Round to the nearest physical pixel
         final double left = (bcStartX + (p.left * moduleMultiplier)).roundToDouble();
         final double logicalWidth = (p.width * moduleMultiplier).roundToDouble();
         
         // --- THERMAL BLEED COMPENSATION ---
         // The printer head bleeds heat, causing black lines to expand by ~1 dot on each side,
         // squeezing the white gaps shut (as seen in user photos).
         // We counteract this by intentionally drawing each black bar narrower.
         // We shave off 1.0 pixel of width to leave extra room for the physical ink to spread.
         final double bleedCompensation = 1.0; 
         double finalWidth = logicalWidth - bleedCompensation;
         
         // Safety check: ensure we don't accidentally make a bar disappear entirely
         if (finalWidth < 0.5) finalWidth = 0.5;

         canvas.drawRect(
           Rect.fromLTWH(left, y, finalWidth, 80),
           bcPaint
         );
      }
    }
    y += 110;
  }

  // 8. QR Codes
  final qrSize = 150.0; // Shrunk from 175
  final qrGap = (proofWidth - (qrSize * 2)) / 3;
  final String qrLeftData = order.ezpayQrLeft ?? "";
  final String qrRightData = order.ezpayQrRight ?? "";

  if (qrLeftData.isNotEmpty || qrRightData.isNotEmpty) {
    y += 20; // Small space before QRs
    if (qrLeftData.isNotEmpty) {
      final qrPainterL = QrPainter(
        data: qrLeftData,
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      canvas.save();
      canvas.translate(startX + qrGap/2, y);
      qrPainterL.paint(canvas, Size(qrSize, qrSize));
      canvas.restore();
    }

    if (qrRightData.isNotEmpty) {
      final qrPainterR = QrPainter(
        data: qrRightData,
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      canvas.save();
      canvas.translate(startX + qrSize + qrGap*2, y); // Adjust positioning for side-by-side
      qrPainterR.paint(canvas, Size(qrSize, qrSize));
      canvas.restore();
    }
    y += qrSize + 40;
  }

  // 9. Footer Note
  _drawTextCenter(canvas, "備  註：此為電子發票開立測試樣張", canvWidth, y, styleFooter);
  y += 40;

  // 10. Store Info Footer
  if (address != null && address.isNotEmpty) {
    _drawText(canvas, "地址：$address", startX, y, proofWidth, styleFooter);
    y += 30;
  }
  if (phone != null && phone.isNotEmpty) {
    _drawText(canvas, "ＴＥＬ：$phone", startX, y, proofWidth, styleFooter);
    y += 35;
  }

  // 11. B2B Transaction Details & Tax Breakdown
  if (buyerUbn.isNotEmpty && buyerUbn != "00000000" && itemDetails.isNotEmpty) {
    y += 20;
    _drawText(canvas, "＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝", startX, y, proofWidth, styleFooter);
    y += 30;

    int itemsSum = 0;
    for (var item in itemDetails) {
      String name = item['item_name'] ?? 'Item';
      int qty = item['quantity'] ?? 1;
      int price = (item['price'] as num?)?.toInt() ?? 0;
      int amt = qty * price;
      itemsSum += amt;
      _drawText(canvas, name, startX, y, proofWidth, styleFooter);
      y += 30;
      _drawText(canvas, "$qty x \$$price", startX, y, proofWidth/2, styleFooter);
      _drawTextRight(canvas, "\$$amt", startX + proofWidth/2, y, proofWidth/2, styleFooter);
      y += 30;
    }

    int finalTotalAmt = order.finalAmount?.toInt() ?? 0;
    int diff = finalTotalAmt - itemsSum;
    
    if (diff > 0) {
      _drawText(canvas, "服務費", startX, y, proofWidth, styleFooter);
      y += 30;
      _drawText(canvas, "1 x \$$diff", startX, y, proofWidth/2, styleFooter);
      _drawTextRight(canvas, "\$$diff", startX + proofWidth/2, y, proofWidth/2, styleFooter);
      y += 30;
    } else if (diff < 0) {
      _drawText(canvas, "折扣", startX, y, proofWidth, styleFooter);
      y += 30;
      _drawText(canvas, "1 x \$$diff", startX, y, proofWidth/2, styleFooter);
      _drawTextRight(canvas, "\$$diff", startX + proofWidth/2, y, proofWidth/2, styleFooter);
      y += 30;
    }

    _drawText(canvas, "＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝", startX, y, proofWidth, styleFooter);
    y += 30;

    // Tax Breakdown for B2B (Assumes 5% tax included in price)
    int salesAmount = (finalTotalAmt / 1.05).round();
    int taxAmount = finalTotalAmt - salesAmount;

    _drawSummaryRow(canvas, "銷售額", "\$$salesAmount", startX, y, proofWidth, 0, styleFooter, styleFooter);
    y += 30;
    _drawSummaryRow(canvas, "營業稅", "\$$taxAmount", startX, y, proofWidth, 0, styleFooter, styleFooter);
    y += 30;
    _drawSummaryRow(canvas, "總　計", "\$$finalTotalAmt", startX, y, proofWidth, 0, styleFooter, styleFooter);
    y += 40;
  }

  final picture = recorder.endRecording();
  final imgObj = await picture.toImage(canvWidth.toInt(), y.toInt());
  final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void _drawSummaryRow(ui.Canvas canvas, String label, String value, double x, double y, double width, double padding, TextStyle styleLabel, TextStyle styleValue) {
      _drawText(canvas, label, x, y, width/2, styleLabel);
      _drawTextRight(canvas, value, x + width - padding, y, width/2, styleValue);
  }

  void _drawTextCenter(ui.Canvas canvas, String text, double totalWidth, double y, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
    textPainter.layout(minWidth: totalWidth, maxWidth: totalWidth);
    textPainter.paint(canvas, Offset(0, y));
  }

  // ----------------------------------------------------------------
  // Settlement Printing (關帳單 & 單日銷售紀錄)
  // ----------------------------------------------------------------
  Future<void> printSettlementRecords({
    required String shopId,
    required String staffName,
    required Map<String, dynamic> rpcData,
    required Map<String, dynamic> uiData,
  }) async {
    try {
      final res = await Supabase.instance.client
          .from('printer_settings')
          .select('*')
          .eq('shop_id', shopId)
          .eq('is_receipt_printer', true);
      
      final receiptPrinters = List<Map<String, dynamic>>.from(res);

      if (receiptPrinters.isEmpty) {
        debugPrint("No receipt printers configured for settlement printing.");
        return;
      }

      final profile = await CapabilityProfile.load();
      
      for (var p in receiptPrinters) {
        final ip = p['ip'];
        final widthMm = p['paper_width_mm'] ?? 80;
        final paperSize = (widthMm == 58) ? PaperSize.mm58 : PaperSize.mm80;

        try {
          final printer = NetworkPrinter(paperSize, profile);
          final res = await printer.connect(ip, port: 9100, timeout: const Duration(seconds: 5));
          if (res != PosPrintResult.success) {
            debugPrint("Failed to connect to printer $ip for settlement");
            continue;
          }

          // 1. 單日銷售紀錄 (Daily Sales)
          final salesBytes = await _generateDailySalesImage(staffName, rpcData, widthMm);
          final img.Image? decodedSales = img.decodeImage(salesBytes);
          if (decodedSales != null) {
            _applyHighContrast(decodedSales);
            printer.image(decodedSales);
            printer.feed(1);
            printer.cut();
          }

          // Buffer between cuts (thermal printers can jam on successive cuts)
          await Future.delayed(const Duration(milliseconds: 1000));

          // 2. 關帳紀錄 (Settlement Record)
          final settlementBytes = await _generateSettlementRecordImage(staffName, rpcData, uiData, widthMm);
          final img.Image? decodedSettlement = img.decodeImage(settlementBytes);
          if (decodedSettlement != null) {
            _applyHighContrast(decodedSettlement);
            printer.image(decodedSettlement);
            printer.feed(2);
            printer.cut();
          }

          printer.disconnect();
        } catch (e) {
          debugPrint("Error printing settlement to $ip: $e");
        }
      }
    } catch (e) {
      debugPrint("printSettlementRecords exception: $e");
    }
  }

  Future<Uint8List> _generateDailySalesImage(String staffName, Map<String, dynamic> rpcData, int paperWidthMm) async {
    final double width = (paperWidthMm == 58) ? 384.0 : 576.0;
    final double startX = (paperWidthMm == 58) ? 0.0 : 10.0;
    final double contentWidth = width - (startX * 2);
    
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, 5000));
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, 5000), bgPaint);

    const String fontFamily = 'NotoSansTC'; 
    final styleTitle = TextStyle(color: Colors.black, fontSize: 32, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleHeader = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.bold); // Increased weight
    final styleCategory = TextStyle(color: Colors.black, fontSize: 28, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleItem = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.bold); // Increased weight

    double y = 40.0;
    
    _drawTextCenter(canvas, "GALLERY 205", width, y, styleTitle.copyWith(fontSize: 40));
    y += 50;
    _drawTextCenter(canvas, "Gallery 205", width, y, styleHeader);
    y += 40;

    // Title Block
    final paintObj = Paint()..color = Colors.black..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(startX, y, contentWidth, 40), paintObj);
    _drawTextCenter(canvas, "單日銷售紀錄", width, y + 4, styleTitle.copyWith(color: Colors.white));
    y += 50;

    // Date & Staff
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy/MM/dd EEEE', 'zh_TW').format(now);
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    
    _drawText(canvas, todayStr, startX, y, contentWidth, styleHeader);
    y += 35;
    _drawText(canvas, "列印時間:$timeStr", startX, y, contentWidth, styleHeader.copyWith(fontSize: 20));
    y += 30;
    _drawText(canvas, "人員:$staffName", startX, y, contentWidth, styleHeader);
    y += 40;

    _drawDivider(canvas, width, y);
    y += 20;

    // Items by Category
    final List<dynamic> itemizedSales = rpcData['itemized_sales'] ?? [];
    int totalItems = 0;
    double totalSales = 0.0;

    for (var cat in itemizedSales) {
      String catName = cat['category'] ?? '未分類';
      List<dynamic> items = cat['items'] ?? [];
      if (items.isEmpty) continue;

      _drawText(canvas, catName, startX, y, contentWidth, styleCategory);
      y += 40;

      for (var item in items) {
        String name = item['name'] ?? 'Item';
        int qty = item['qty'] ?? 0;
        double subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
        totalItems += qty;
        totalSales += subtotal;

        double nameHeight = _drawText(canvas, name, startX, y, contentWidth * 0.5, styleItem);
        _drawText(canvas, "x$qty", startX + contentWidth * 0.6, y, contentWidth * 0.15, styleItem);
        _drawTextRight(canvas, "${subtotal.toStringAsFixed(0)}", startX + contentWidth, y, contentWidth * 0.25, styleItem);
        
        y += (nameHeight > 35 ? nameHeight : 35) + 5;
      }
      
      y += 10;
      _drawDivider(canvas, width, y);
      y += 20;
    }

    // Footer summary
    _drawSummaryRow(canvas, "合計項目數", "$totalItems", startX, y, contentWidth, 0, styleHeader, styleHeader);
    y += 40;
    _drawSummaryRow(canvas, "總銷售額(不含折扣及服務費)", "${totalSales.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleHeader, styleHeader);
    y += 50;
    _drawDivider(canvas, width, y);
    y += 40;

    final picture = recorder.endRecording();
    final imgObj = await picture.toImage(width.toInt(), y.toInt());
    final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _generateSettlementRecordImage(String staffName, Map<String, dynamic> rpcData, Map<String, dynamic> uiData, int paperWidthMm) async {
    final double width = (paperWidthMm == 58) ? 384.0 : 576.0;
    final double startX = (paperWidthMm == 58) ? 0.0 : 10.0;
    final double contentWidth = width - (startX * 2);
    
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, 5000));
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, 5000), bgPaint);

    const String fontFamily = 'NotoSansTC'; 
    final styleTitle = TextStyle(color: Colors.black, fontSize: 32, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleHeader = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.bold); // Increased weight
    final styleCategory = TextStyle(color: Colors.black, fontSize: 26, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleLabel = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.bold); // Increased weight
    final styleValueBig = TextStyle(color: Colors.black, fontSize: 28, fontFamily: fontFamily, fontWeight: FontWeight.bold);

    double y = 40.0;
    
    _drawTextCenter(canvas, "GALLERY 205", width, y, styleTitle.copyWith(fontSize: 40));
    y += 50;
    _drawTextCenter(canvas, "Gallery 205", width, y, styleHeader);
    y += 40;

    // Title Block
    final paintObj = Paint()..color = Colors.black..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(startX, y, contentWidth, 40), paintObj);
    _drawTextCenter(canvas, "關帳紀錄", width, y + 4, styleTitle.copyWith(color: Colors.white));
    y += 50;

    final now = DateTime.now();
    final timeStr = DateFormat('yyyy/MM/dd HH:mm:ss').format(now);
    
    _drawText(canvas, "本次關帳: $timeStr", startX, y, contentWidth, styleHeader.copyWith(fontSize: 20));
    y += 30;
    _drawText(canvas, "人員: $staffName", startX, y, contentWidth, styleHeader.copyWith(fontSize: 20));
    y += 40;

    // --- Data Extraction ---
    final metrics = rpcData['metrics'] ?? {};
    final payments = rpcData['payments'] ?? {};
    
    double totalRevenue = (metrics['total_revenue'] as num?)?.toDouble() ?? 0.0;
    double totalDiscount = (metrics['total_discount'] as num?)?.toDouble() ?? 0.0;
    double totalVoidAmount = (metrics['total_void_amount'] as num?)?.toDouble() ?? 0.0;
    
    int totalTransactions = metrics['total_transactions'] ?? 0;
    int voidTransactions = metrics['void_transactions'] ?? 0;
    int totalGuests = metrics['total_guests'] ?? 0;
    
    // UI Data
    double paidInCash = (uiData['paidInCash'] as num?)?.toDouble() ?? 0.0;
    double cashDifference = (uiData['cashDifference'] as num?)?.toDouble() ?? 0.0;
    double depositsRedeemed = (uiData['depositsRedeemed'] as num?)?.toDouble() ?? 0.0;

    // 1. 營業額 Block
    _drawSummaryRow(canvas, "營業額", "${totalRevenue.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleCategory, styleValueBig);
    y += 35;
    _drawDivider(canvas, width, y);
    y += 15;
    
    _drawSummaryRow(canvas, "現金總收入", "${paidInCash.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 35;
    
    payments.forEach((method, amount) {
       double amt = (amount as num?)?.toDouble() ?? 0.0;
       if (amt > 0) {
         _drawSummaryRow(canvas, "+ $method", "${amt.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleLabel, styleLabel);
         y += 35;
       }
    });

    if (cashDifference > 0) { // Overage
      _drawSummaryRow(canvas, "+ 溢收找零", "${cashDifference.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleLabel, styleLabel);
      y += 35;
    }

    y += 10;
    // 溢收金額
    _drawSummaryRow(canvas, "溢收金額", "${(cashDifference > 0 ? cashDifference : 0).toStringAsFixed(0)}", startX, y, contentWidth, 0, styleCategory, styleValueBig);
    y += 35;
    _drawDivider(canvas, width, y);
    y += 15;

    // 作廢總額
    _drawSummaryRow(canvas, "作廢總額", "${totalVoidAmount.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleCategory, styleValueBig);
    y += 35;
    _drawDivider(canvas, width, y);
    y += 15;
    _drawSummaryRow(canvas, "作廢現金", "0", startX, y, contentWidth, 0, styleLabel, styleLabel); // Basic stub
    y += 35;

    // 預付訂金
    y += 10;
    _drawSummaryRow(canvas, "預付訂金", "${depositsRedeemed.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleCategory, styleValueBig);
    y += 35;
    _drawDivider(canvas, width, y);
    y += 15;

    // 現金短溢 (Shortage)
    y += 10;
    double shortage = cashDifference < 0 ? cashDifference.abs() : 0.0;
    _drawSummaryRow(canvas, "現金短溢", "${shortage.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleCategory, styleValueBig);
    y += 35;
    _drawDivider(canvas, width, y);
    y += 15;
    
    // 總折扣讓
    y += 10;
    _drawSummaryRow(canvas, "總折扣讓", "${totalDiscount.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleCategory, styleValueBig);
    y += 35;
    _drawDivider(canvas, width, y);
    y += 15;

    // 銷售總額
    double totalSales = totalRevenue + totalDiscount;
    y += 10;
    _drawSummaryRow(canvas, "銷售總額", "${totalSales.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleCategory, styleValueBig);
    y += 35;
    _drawDivider(canvas, width, y);
    y += 15;
    _drawSummaryRow(canvas, "+ 營業額", "${totalRevenue.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 35;
    _drawSummaryRow(canvas, "+ 總折扣讓", "${totalDiscount.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 45;

    // 交易 Block
    _drawText(canvas, "交易", startX, y, contentWidth, styleCategory);
    y += 35;
    _drawDivider(canvas, width, y);
    y += 15;
    _drawSummaryRow(canvas, "總交易單數", "$totalTransactions", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 35;
    _drawSummaryRow(canvas, "總交易金額", "${totalRevenue.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 35;
    _drawSummaryRow(canvas, "總作廢交易單數", "$voidTransactions", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 35;
    _drawSummaryRow(canvas, "總作廢交易金額", "${totalVoidAmount.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 45;

    // 其他 Block
    _drawText(canvas, "其他", startX, y, contentWidth, styleCategory);
    y += 35;
    _drawDivider(canvas, width, y);
    y += 15;
    _drawSummaryRow(canvas, "來客數", "$totalGuests", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 35;
    
    int qtySold = 0;
    final List<dynamic> salesArray = rpcData['itemized_sales'] ?? [];
    for(var cat in salesArray) {
      for(var item in (cat['items'] ?? [])) {
        qtySold += (item['qty'] as num?)?.toInt() ?? 0;
      }
    }
    
    _drawSummaryRow(canvas, "銷售數量", "$qtySold", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 35;
    
    double avgSpendGuest = totalGuests > 0 ? totalRevenue / totalGuests : 0;
    _drawSummaryRow(canvas, "平均客單價", "${avgSpendGuest.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 35;
    
    double avgSpendTrans = totalTransactions > 0 ? totalRevenue / totalTransactions : 0;
    _drawSummaryRow(canvas, "平均單價", "${avgSpendTrans.toStringAsFixed(0)}", startX, y, contentWidth, 0, styleLabel, styleLabel);
    y += 50;

    _drawDivider(canvas, width, y);
    y += 40;

    final picture = recorder.endRecording();
    final imgObj = await picture.toImage(width.toInt(), y.toInt());
    final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}