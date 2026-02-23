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
import 'package:gallery205_staff_app/features/ordering/domain/entities/order_group.dart';


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
    const int threshold = 200; // 0-255. High threshold = Darker output
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
    bool isReprint = false,
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
          paperWidth: paperWidth,
          isReprint: isReprint,
        );
        
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage != null) {
          _applyHighContrast(decodedImage);
          printer.image(decodedImage);
          printer.feed(2); 
          printer.cut();
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
    required int paperWidth,
    bool isReprint = false,
  }) async {
    final recorder = ui.PictureRecorder();
    const double proofWidth = 410.0;
    final double canvWidth = (paperWidth == 58) ? 384.0 : 576.0;
    final double startX = (canvWidth - proofWidth) / 2;

    const double height = 1200.0; 
    final canvas = ui.Canvas(recorder, Rect.fromPoints(Offset.zero, Offset(canvWidth, height)));
    
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, canvWidth, height), bgPaint);

    const String fontFamily = 'NotoSansTC';
    final styleShop = TextStyle(color: Colors.black, fontSize: 32, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleTitle = TextStyle(color: Colors.black, fontSize: 42, fontFamily: fontFamily, fontWeight: FontWeight.w900);
    final stylePeriod = TextStyle(color: Colors.black, fontSize: 34, fontFamily: fontFamily, fontWeight: FontWeight.bold);
    final styleInvoiceNum = TextStyle(color: Colors.black, fontSize: 44, fontFamily: fontFamily, fontWeight: FontWeight.w900);
    final styleNormal = TextStyle(color: Colors.black, fontSize: 24, fontFamily: fontFamily, fontWeight: FontWeight.w500);
    final styleLabel = TextStyle(color: Colors.black, fontSize: 22, fontFamily: fontFamily, fontWeight: FontWeight.bold);

    double y = 40;

    // 1. Header
    _drawTextCenter(canvas, shopName, canvWidth, y, styleShop);
    y += 45;
    if (isReprint) {
      _drawTextCenter(canvas, "電子發票證明聯 (補印)", canvWidth, y, styleTitle.copyWith(fontSize: 38));
    } else {
      _drawTextCenter(canvas, "電子發票證明聯", canvWidth, y, styleTitle);
    }
    y += 60;

    final time = order.checkoutTime ?? DateTime.now();
    final year = time.year - 1911;
    final month = time.month;
    final periodStart = (month % 2 == 0) ? month - 1 : month;
    final periodEnd = periodStart + 1;
    final periodStartStr = periodStart.toString().padLeft(2, '0');
    final periodEndStr = periodEnd.toString().padLeft(2, '0');
    final periodStr = "${year}年$periodStartStr-$periodEndStr月";

    _drawTextCenter(canvas, periodStr, canvWidth, y, stylePeriod);
    y += 50;
    _drawTextCenter(canvas, order.ezpayInvoiceNumber ?? "XX-XXXXXXXX", canvWidth, y, styleInvoiceNum);
    y += 60;

    // 2. Barcode Code 39
    final String barcodeData = "${year}$periodStartStr${order.ezpayInvoiceNumber}";
    final bc = bc_pkg.Barcode.code39();
    final bcPaint = Paint()..color = Colors.black;
    final bcPoints = bc.make(barcodeData, width: proofWidth, height: 60);
    for (var point in bcPoints) {
       if (point is bc_pkg.BarcodeBar) {
          canvas.drawRect(Rect.fromLTWH(startX + point.left, y, point.width, point.height), bcPaint);
       }
    }
    y += 80;

    // 3. Metadata
    final randomNum = order.ezpayRandomNum ?? "0000";
    final totalAmt = order.finalAmount?.toInt() ?? 0;
    final buyerUbn = order.buyerUbn ?? "00000000";
    
    _drawText(canvas, "隨機碼 $randomNum", startX, y, proofWidth/2, styleNormal);
    _drawTextRight(canvas, "總計 \$$totalAmt", startX + proofWidth, y, proofWidth/2, styleNormal.copyWith(fontSize: 30, fontWeight: FontWeight.bold));
    y += 40;

    _drawText(canvas, "賣方 $sellerUbn", startX, y, proofWidth/2, styleNormal);
    _drawTextRight(canvas, "買方 $buyerUbn", startX + proofWidth, y, proofWidth/2, styleNormal);
    y += 50;

    // 4. QR Codes
    final qrSize = 180.0;
    final qrGap = (proofWidth - (qrSize * 2)) / 3;
    final String qrLeftData = order.ezpayQrLeft ?? "";
    final String qrRightData = order.ezpayQrRight ?? "";

    if (qrLeftData.isNotEmpty) {
      final qrPainterL = QrPainter(
        data: qrLeftData,
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      qrPainterL.paint(canvas, Size(qrSize, qrSize));
      // Need to translate canvas to draw at specific offset since paint doesn't take offset
      // Wait, QrPainter.paint only takes (Canvas, Size). We should translate canvas.
      
      canvas.save();
      canvas.translate(startX + qrGap, y);
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
      canvas.translate(startX + qrSize + (qrGap * 2), y);
      qrPainterR.paint(canvas, Size(qrSize, qrSize));
      canvas.restore();
    }
    y += qrSize + 40;

    _drawTextCenter(canvas, "退貨請持證明聯辦理", canvWidth, y, styleLabel.copyWith(fontSize: 16));
    y += 30;

    final picture = recorder.endRecording();
    final imgObj = await picture.toImage(canvWidth.toInt(), y.toInt());
    final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }


  void _drawSummaryRow(ui.Canvas canvas, String label, String value, double x, double y, double width, double padding, TextStyle styleLabel, TextStyle styleValue) {
      _drawText(canvas, label, x, y, width/2, styleLabel);
      _drawTextRight(canvas, value, width-padding, y, width/2, styleValue);
  }

  void _drawTextCenter(ui.Canvas canvas, String text, double totalWidth, double y, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center);
    textPainter.layout(minWidth: totalWidth, maxWidth: totalWidth);
    textPainter.paint(canvas, Offset(0, y));
  }
}