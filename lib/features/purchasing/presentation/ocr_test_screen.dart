// lib/features/purchasing/presentation/ocr_test_screen.dart

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery205_staff_app/features/purchasing/data/supplier_template_repository.dart';

// ---------------------------------------------------------------------------
// Item entry (UI state)
// ---------------------------------------------------------------------------

class _ItemEntry {
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController subtotal;

  _ItemEntry({String n = '', String q = '', String u = '', String s = ''})
      : name = TextEditingController(text: n),
        quantity = TextEditingController(text: q),
        unitPrice = TextEditingController(text: u),
        subtotal = TextEditingController(text: s);

  void dispose() {
    name.dispose();
    quantity.dispose();
    unitPrice.dispose();
    subtotal.dispose();
  }

  bool get isEmpty =>
      name.text.trim().isEmpty &&
      quantity.text.trim().isEmpty &&
      subtotal.text.trim().isEmpty;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class OcrTestScreen extends StatefulWidget {
  const OcrTestScreen({super.key});

  @override
  State<OcrTestScreen> createState() => _OcrTestScreenState();
}

class _OcrTestScreenState extends State<OcrTestScreen> {
  File? _image;
  String _rawOcrText = '';
  bool _isProcessing = false;
  bool _showForm = false;

  final _supplierCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  List<_ItemEntry> _items = [_ItemEntry()];

  SupplierTemplate? _matchedTemplate;
  List<SupplierTemplate> _allTemplates = [];
  bool _isNewSupplier = false;

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.chinese);
  final SupplierTemplateRepository _repo = SupplierTemplateRepository();

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _supplierCtrl.dispose();
    _dateCtrl.dispose();
    for (final item in _items) item.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    _allTemplates = await _repo.fetchAll();
  }

  // -------------------------------------------------------------------------
  // 拍照 / 選圖
  // -------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (picked == null) return;

      setState(() {
        _image = File(picked.path);
        _rawOcrText = '';
        _showForm = false;
        _isProcessing = true;
        _isNewSupplier = false;
        _matchedTemplate = null;
        _resetFields();
      });

      await _processImage(File(picked.path));
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('取得圖片失敗：$e');
    }
  }

  // -------------------------------------------------------------------------
  // OCR
  // -------------------------------------------------------------------------

  Future<void> _processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText result =
          await _textRecognizer.processImage(inputImage);

      final buffer = StringBuffer();
      for (final block in result.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
      }

      final ocrText = buffer.toString().trim();
      _rawOcrText = ocrText;

      _matchedTemplate = await _findMatchingTemplate(ocrText);
      _isNewSupplier = _matchedTemplate == null;

      if (_matchedTemplate != null) {
        _prefillFromTemplate(_matchedTemplate!, ocrText);
      } else {
        _autoExtractBasic(ocrText);
      }

      setState(() {
        _isProcessing = false;
        _showForm = true;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _showForm = false;
      });
      _showError('辨識失敗：$e');
    }
  }

  // -------------------------------------------------------------------------
  // 廠商比對
  // -------------------------------------------------------------------------

  Future<SupplierTemplate?> _findMatchingTemplate(String ocrText) async {
    final normalized = ocrText.replaceAll(' ', '').replaceAll('\n', '');

    SupplierTemplate? exactMatch;
    SupplierTemplate? fuzzyMatch;
    double bestFuzzyScore = 0;

    for (final t in _allTemplates) {
      if (t.supplierName.length < 2) continue;
      final name = t.supplierName.replaceAll(' ', '');

      if (normalized.contains(name)) {
        exactMatch = t;
        break;
      }

      final score = _charOverlapScore(name, normalized);
      if (score > bestFuzzyScore) {
        bestFuzzyScore = score;
        fuzzyMatch = t;
      }
    }

    if (exactMatch != null) return exactMatch;

    if (fuzzyMatch != null && bestFuzzyScore >= 0.55) {
      final confirmed =
          await _confirmFuzzyMatch(fuzzyMatch.supplierName, bestFuzzyScore);
      if (confirmed) return fuzzyMatch;
    }

    return null;
  }

  double _charOverlapScore(String name, String ocrText) {
    if (name.isEmpty) return 0;
    int matched = 0;
    final remaining = StringBuffer(ocrText);
    for (final char in name.split('')) {
      final idx = remaining.toString().indexOf(char);
      if (idx >= 0) {
        matched++;
        final s = remaining.toString();
        remaining.clear();
        remaining.write(s.substring(0, idx) + s.substring(idx + 1));
      }
    }
    return matched / name.length;
  }

  Future<bool> _confirmFuzzyMatch(String supplierName, double score) async {
    final percent = (score * 100).toStringAsFixed(0);
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('找到相似廠商'),
        content: Text('這張單據是否來自「$supplierName」？\n（相似度 $percent%）'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('不是，當新廠商'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('是'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // -------------------------------------------------------------------------
  // 從模板提取欄位
  // -------------------------------------------------------------------------

  void _prefillFromTemplate(SupplierTemplate template, String ocrText) {
    _supplierCtrl.text = template.supplierName;
    final lines = ocrText.split('\n');

    if (template.dateKeyword != null) {
      _dateCtrl.text = _extractDateAfterKeyword(lines, template.dateKeyword!);
    }

    // 單品項：用 keyword 直接提取各欄位值
    final name = template.itemKeyword != null
        ? _extractAfterKeyword(lines, template.itemKeyword!)
        : '';
    final qty = template.quantityKeyword != null
        ? _extractAfterKeyword(lines, template.quantityKeyword!)
        : '';
    final unitPrice = template.unitPriceKeyword != null
        ? _extractAfterKeyword(lines, template.unitPriceKeyword!)
        : '';
    final subtotal = template.subtotalKeyword != null
        ? _extractAfterKeyword(lines, template.subtotalKeyword!)
        : '';

    for (final item in _items) item.dispose();
    _items = [_ItemEntry(n: name, q: qty, u: unitPrice, s: subtotal)];
  }

  // -------------------------------------------------------------------------
  // 新廠商：基本自動提取
  // -------------------------------------------------------------------------

  void _autoExtractBasic(String ocrText) {
    final lines = ocrText.split('\n');

    // 日期
    final dateRegex = RegExp(r'\d{4}-\d{2}-\d{2}');
    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        _dateCtrl.text = match.group(0)!;
        break;
      }
    }

    // 金額：找最大的數字當小計
    final numberRegex = RegExp(r'[\d,]+');
    int maxAmount = 0;
    for (final line in lines) {
      for (final match in numberRegex.allMatches(line)) {
        final num = int.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0;
        if (num > maxAmount) maxAmount = num;
      }
    }
    if (maxAmount > 0) {
      _items.first.subtotal.text = maxAmount.toString();
    }
  }

  /// 專門找日期：找到 keyword 行後，往下掃日期格式 YYYY-MM-DD 或 YYYY/MM/DD
  String _extractDateAfterKeyword(List<String> lines, String keyword) {
    final dateRegex = RegExp(r'\d{4}[-/]\d{2}[-/]\d{2}');
    for (int i = 0; i < lines.length; i++) {
      if (!lines[i].contains(keyword)) continue;
      // 先掃同行
      final sameLineMatch = dateRegex.firstMatch(lines[i]);
      if (sameLineMatch != null) return sameLineMatch.group(0)!;
      // 往下找最多 20 行
      for (int j = i + 1; j < lines.length && j <= i + 20; j++) {
        final match = dateRegex.firstMatch(lines[j]);
        if (match != null) return match.group(0)!;
      }
    }
    return '';
  }

  /// 找到含 keyword 的行，取後面的內容；若空白或無意義則往下找
  String _extractAfterKeyword(List<String> lines, String keyword) {
    // 無意義內容的判斷：含括號標記、純標點、純空白
    bool isMeaningless(String s) {
      if (s.isEmpty) return true;
      // 含 [xxx] 或 xxx] 這類欄位標記
      if (s.contains('[') || s.contains(']')) return true;
      // 純標點或單一字符
      if (RegExp(r'^[：:\-\s\.]+$').hasMatch(s)) return true;
      return false;
    }

    for (int i = 0; i < lines.length; i++) {
      if (!lines[i].contains(keyword)) continue;

      // 先取同行 keyword 之後的內容
      final idx = lines[i].indexOf(keyword);
      final after = lines[i]
          .substring(idx + keyword.length)
          .replaceFirst(RegExp(r'^[:：\s]+'), '')
          .trim();

      if (!isMeaningless(after)) return after;

      // 同行無意義 → 往下找最多 20 行，跳過無意義的行
      for (int j = i + 1; j < lines.length && j <= i + 20; j++) {
        final next = lines[j].trim();
        if (!isMeaningless(next)) return next;
      }
    }
    return '';
  }

  void _resetFields() {
    _supplierCtrl.clear();
    _dateCtrl.clear();
    for (final item in _items) item.dispose();
    _items = [_ItemEntry()];
  }

  // -------------------------------------------------------------------------
  // 儲存
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    if (_supplierCtrl.text.trim().isEmpty) {
      _showError('請填入廠商名稱');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final sId = prefs.getString('savedShopId') ?? '';

    if (_isNewSupplier) {
      await _showKeywordDialog(sId);
    } else {
      await _savePurchaseRecord(sId, _matchedTemplate!.id!);
    }
  }

  Future<void> _savePurchaseRecord(String shopId, String templateId) async {
    try {
      final purchaseItems = _items
          .where((e) => !e.isEmpty)
          .map((e) => PurchaseItem(
                name: e.name.text.trim(),
                quantity: num.tryParse(e.quantity.text.trim()) ?? 0,
                unitPrice: e.unitPrice.text.trim().isNotEmpty
                    ? num.tryParse(e.unitPrice.text.trim().replaceAll(',', ''))
                    : null,
                subtotal:
                    num.tryParse(e.subtotal.text.trim().replaceAll(',', '')) ?? 0,
              ))
          .toList();

      final total = purchaseItems.fold<num>(0, (sum, i) => sum + i.subtotal);

      await _repo.savePurchaseRecord(
        supplierTemplateId: templateId,
        shopId: shopId,
        deliveryDate: _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim(),
        items: purchaseItems,
        totalAmount: total,
      );
      _showSnackbar('已儲存進貨記錄');
      _reset();
    } catch (e) {
      _showError('儲存失敗：$e');
    }
  }

  Future<void> _showKeywordDialog(String shopId) async {
    final dateKwCtrl = TextEditingController(
        text: _guessKeyword(_rawOcrText, _dateCtrl.text));
    final itemKwCtrl = TextEditingController(
        text: _guessKeyword(_rawOcrText, _items.first.name.text));
    final qtyKwCtrl = TextEditingController(
        text: _guessKeyword(_rawOcrText, _items.first.quantity.text));
    final unitPriceKwCtrl = TextEditingController(
        text: _guessKeyword(_rawOcrText, _items.first.unitPrice.text));
    final subtotalKwCtrl = TextEditingController(
        text: _guessKeyword(_rawOcrText, _items.first.subtotal.text));

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('記錄廠商版型'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              '填入這張單上各欄位旁的標題文字，例如日期旁邊寫「交貨日期」就填交貨日期。下次拍同廠商的單會自動辨識。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            _KeywordField(label: '日期關鍵字', controller: dateKwCtrl),
            _KeywordField(label: '品名關鍵字', controller: itemKwCtrl),
            _KeywordField(label: '數量關鍵字', controller: qtyKwCtrl),
            _KeywordField(label: '單價關鍵字', controller: unitPriceKwCtrl),
            _KeywordField(label: '小計關鍵字', controller: subtotalKwCtrl),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('略過'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('儲存版型'),
          ),
        ],
      ),
    );

    try {
      final template = SupplierTemplate(
        shopId: shopId,
        supplierName: _supplierCtrl.text.trim(),
        dateKeyword: dateKwCtrl.text.trim().isEmpty ? null : dateKwCtrl.text.trim(),
        itemKeyword: itemKwCtrl.text.trim().isEmpty ? null : itemKwCtrl.text.trim(),
        quantityKeyword: qtyKwCtrl.text.trim().isEmpty ? null : qtyKwCtrl.text.trim(),
        unitPriceKeyword: unitPriceKwCtrl.text.trim().isEmpty ? null : unitPriceKwCtrl.text.trim(),
        subtotalKeyword: subtotalKwCtrl.text.trim().isEmpty ? null : subtotalKwCtrl.text.trim(),
        sampleOcrText: _rawOcrText,
      );
      await _repo.upsert(template);
      await _loadTemplates();

      // 找到剛存的模板 id 再存進貨記錄
      final saved = _allTemplates.firstWhere(
        (t) => t.supplierName == template.supplierName,
        orElse: () => template,
      );
      if (saved.id != null) {
        await _savePurchaseRecord(shopId, saved.id!);
      } else {
        _showSnackbar(confirmed == true ? '已儲存廠商版型' : '已儲存廠商（無關鍵字）');
        _reset();
      }
    } catch (e) {
      _showError('儲存失敗：$e');
    }
  }

  String _guessKeyword(String ocrText, String value) {
    if (value.isEmpty) return '';
    for (final line in ocrText.split('\n')) {
      if (line.contains(value)) {
        final idx = line.indexOf(value);
        final before = line.substring(0, idx).replaceAll(RegExp(r'[:：\s]+$'), '').trim();
        if (before.isNotEmpty) return before;
      }
    }
    return '';
  }

  void _reset() {
    setState(() {
      _image = null;
      _rawOcrText = '';
      _showForm = false;
      _matchedTemplate = null;
      _isNewSupplier = false;
      _resetFields();
    });
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('錯誤'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2E),
        foregroundColor: Colors.white,
        title: const Text('進貨辨識', style: TextStyle(color: Colors.white, fontSize: 17)),
        actions: [
          if (_showForm)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onPressed: _reset,
              child: const Text('重拍',
                  style: TextStyle(color: CupertinoColors.systemOrange)),
            ),
        ],
      ),
      body: _showForm ? _buildForm() : _buildCapture(),
    );
  }

  // -------------------------------------------------------------------------
  // 拍照頁
  // -------------------------------------------------------------------------

  Widget _buildCapture() {
    return Column(
      children: [
        Expanded(
          child: _image == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.doc_text_viewfinder,
                          size: 64, color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text('拍照或從相簿選取進貨單',
                          style: TextStyle(color: Colors.white38, fontSize: 15)),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_image!, fit: BoxFit.contain),
                    if (_isProcessing)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text('辨識中...',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Container(
          color: const Color(0xFF2C2C2E),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.camera,
                  label: '拍照',
                  onTap: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ActionButton(
                  icon: CupertinoIcons.photo,
                  label: '從相簿選取',
                  onTap: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 表單頁
  // -------------------------------------------------------------------------

  Widget _buildForm() {
    return Row(
      children: [
        // 左：填寫欄位
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // 廠商狀態 Banner
              Container(
                width: double.infinity,
                color: _isNewSupplier
                    ? const Color(0xFF3A2800)
                    : const Color(0xFF002A1A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _isNewSupplier
                          ? CupertinoIcons.sparkles
                          : CupertinoIcons.checkmark_seal_fill,
                      color: _isNewSupplier ? Colors.orange : Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isNewSupplier
                            ? '新廠商 — 確認欄位後將記錄版型'
                            : '已找到廠商版型：${_matchedTemplate?.supplierName ?? ''}',
                        style: TextStyle(
                          color: _isNewSupplier ? Colors.orange : Colors.green,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 基本資訊
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _FormField(
                                label: '廠商名稱 *', controller: _supplierCtrl),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FormField(
                                label: '日期', controller: _dateCtrl),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 品項標題
                      Row(
                        children: [
                          const Text('品項',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() => _items.add(_ItemEntry())),
                            child: const Row(
                              children: [
                                Icon(CupertinoIcons.add_circled,
                                    size: 16, color: CupertinoColors.activeBlue),
                                SizedBox(width: 4),
                                Text('新增品項',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: CupertinoColors.activeBlue)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 品項列表
                      ...List.generate(_items.length, (i) => _buildItemCard(i)),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          onPressed: _save,
                          child: const Text('儲存'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 分隔線
        Container(width: 1, color: Colors.white12),

        // 右：原始 OCR
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 16, 12, 4),
                child: Text('OCR 原始文字',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: SelectableText(
                    _rawOcrText,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12, height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('品項 ${index + 1}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              if (_items.length > 1)
                GestureDetector(
                  onTap: () => setState(() {
                    _items[index].dispose();
                    _items.removeAt(index);
                  }),
                  child: const Icon(CupertinoIcons.minus_circle,
                      size: 18, color: CupertinoColors.systemRed),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _FormField(label: '品名', controller: item.name, maxLines: 2),
          Row(
            children: [
              Expanded(child: _FormField(label: '數量', controller: item.quantity, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _FormField(label: '單價', controller: item.unitPrice, keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _FormField(label: '小計', controller: item.subtotal, keyboardType: TextInputType.number)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: disabled ? Colors.white10 : const Color(0xFF3A3A3C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: disabled ? Colors.white24 : Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  color: disabled ? Colors.white24 : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType keyboardType;

  const _FormField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF3A3A3C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _KeywordField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              placeholderStyle:
                  const TextStyle(fontSize: 13, color: Colors.black38),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
