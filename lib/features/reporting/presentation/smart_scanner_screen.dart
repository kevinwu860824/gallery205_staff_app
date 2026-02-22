// lib/features/reporting/presentation/smart_scanner_screen.dart

// ✅ 雙重偵測版：同時分析 QR Code 與 OCR 文字，完美支援台灣電子發票與傳統收據



import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'; // ✅ 新增

import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:go_router/go_router.dart';



// ----------------------------------------------------------------

// 1. 資料模型

// ----------------------------------------------------------------

class ScannedItem {

  final String name;

  final double amount;

  final String category;



  ScannedItem({required this.name, required this.amount, required this.category});

}



class SmartScannerScreen extends StatefulWidget {

  const SmartScannerScreen({super.key});



  @override

  State<SmartScannerScreen> createState() => _SmartScannerScreenState();

}



class _SmartScannerScreenState extends State<SmartScannerScreen> {

  bool _isProcessing = false;

  String _statusText = "Tap the camera icon to scan";

  List<ScannedItem> _items = [];

  double _totalAmount = 0.0;



  // ⚠️ 請填入您的 API Key

  final String _apiKey = 'AIzaSyClj4C-U2xo5RlBz5OdZFtiqMASGEYDJls'; 



  // ----------------------------------------------------------------

  // 2. 核心邏輯

  // ----------------------------------------------------------------

  Future<void> _scanReceipt() async {

    setState(() {

      _isProcessing = true;

      _statusText = "Camera opening...";

      _items = []; 

      _totalAmount = 0;

    });



    // 定義辨識器

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

    final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]); // 只掃 QR Code



    try {

      // A. 拍照

      final ImagePicker picker = ImagePicker();

      final XFile? photo = await picker.pickImage(source: ImageSource.camera);



      if (photo == null) {

        setState(() {

          _isProcessing = false;

          _statusText = "Scan cancelled";

        });

        return;

      }



      final inputImage = InputImage.fromFilePath(photo.path);

      

      setState(() => _statusText = "Analyzing Image (OCR + QR)...");



      // B. 雙軌並行偵測 (同時跑 OCR 和 QR 掃描)

      final results = await Future.wait([

        textRecognizer.processImage(inputImage), // Index 0: OCR

        barcodeScanner.processImage(inputImage), // Index 1: Barcode

      ]);



      final RecognizedText ocrResult = results[0] as RecognizedText;

      final List<Barcode> barcodeResult = results[1] as List<Barcode>;



      String extractedText = ocrResult.text;

      String qrCodeContent = "";



      // 提取 QR Code 內容 (台灣發票通常有兩個 QR，我們會把讀到的都串起來)

      for (var barcode in barcodeResult) {

        if (barcode.rawValue != null) {

          qrCodeContent += " [QR Data]: ${barcode.rawValue}\n";

        }

      }

      

      // 釋放資源

      await textRecognizer.close(); 

      await barcodeScanner.close();



      // 如果兩者都沒讀到

      if (extractedText.isEmpty && qrCodeContent.isEmpty) {

        throw Exception("圖片中未發現文字或 QR Code");

      }



      setState(() => _statusText = "AI Processing...");



      // C. Gemini AI 綜合分析

      final model = GenerativeModel(model: 'gemini-2.0-flash-001', apiKey: _apiKey);

      

      // 這是一個「混合型 Prompt」，同時餵給它 OCR 和 QR 的資料

      final prompt = '''

        你是一個台灣酒吧的專業會計助手。請根據提供的「OCR 文字」和「QR Code 數據」來分析這張單據。

        

        [資料來源]

        1. **OCR 文字**: 來自發票上的印刷字體。

        2. **QR Code**: 來自台灣電子發票的二維碼 (可能包含明細)。

        

        [任務目標]

        請整合兩邊的資訊，提取出消費品項與金額，並判斷類別 (COGS 或 OPEX)。

        *優先使用 QR Code 中的明細資訊*，如果 QR Code 只有編碼沒有明細，則依賴 OCR 文字。

        

        [分類規則]

        - **COGS (成本)**: 酒類 (威士忌, 啤酒), 食材 (牛奶, 水果, 肉), 冰塊。

        - **OPEX (費用)**: 雜項 (衛生紙, 清潔劑), 水電, 運費, 文具, 服務費。

        

        [輸出格式]

        只回傳純 JSON 陣列，範例：

        [{"name": "品項", "amount": 100, "category": "COGS"}]

        

        --- 輸入資料開始 ---

        

        【QR Code 掃描結果】:

        $qrCodeContent

        

        【OCR 文字辨識結果】:

        $extractedText

        

        --- 輸入資料結束 ---

      ''';



      final content = [Content.text(prompt)];

      final response = await model.generateContent(content);

      

      String? jsonString = response.text;

      

      if (jsonString != null) {

        jsonString = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();

        

        final List<dynamic> data = jsonDecode(jsonString);

        List<ScannedItem> newItems = [];

        double newTotal = 0;



        for(var item in data) {

           double amt = (item['amount'] as num? ?? 0).toDouble();

           newItems.add(ScannedItem(

             name: item['name'] ?? 'Unknown', 

             amount: amt, 

             category: item['category'] ?? 'OPEX'

           ));

           newTotal += amt;

        }

        

        if (mounted) {

          setState(() {

            _items = newItems;

            _totalAmount = newTotal;

            _statusText = "Analysis Complete!";

            _isProcessing = false;

          });

        }

      }



    } catch (e) {

      if (mounted) {

        setState(() {

          _isProcessing = false;

          _statusText = "Error: $e";

        });

        _showDebugDialog("Error", e.toString());

      }

    }

  }

  

  void _showDebugDialog(String title, String content) {

    showCupertinoDialog(

      context: context,

      builder: (ctx) => CupertinoAlertDialog(

        title: Text(title),

        content: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 12))),

        actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(ctx))],

      ),

    );

  }



  // ----------------------------------------------------------------

  // 3. UI 介面 (保持不變)

  // ----------------------------------------------------------------

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFF000000),

      appBar: AppBar(

        title: const Text('Smart Scanner', style: TextStyle(color: Colors.white)),

        backgroundColor: const Color(0xFF000000),

        iconTheme: const IconThemeData(color: Colors.white),

        actions: [

          IconButton(

            icon: const Icon(CupertinoIcons.camera_viewfinder, size: 28),

            onPressed: _isProcessing ? null : _scanReceipt,

          ),

        ],

      ),

      body: Column(

        children: [

          Container(

            width: double.infinity,

            padding: const EdgeInsets.all(16),

            color: const Color(0xFF222222),

            child: Text(

              _statusText,

              textAlign: TextAlign.center,

              style: const TextStyle(color: Colors.grey, fontSize: 14),

            ),

          ),

          if (_items.isNotEmpty)

            Container(

              padding: const EdgeInsets.symmetric(vertical: 20),

              child: Column(

                children: [

                  const Text("Total Amount", style: TextStyle(color: Colors.white, fontSize: 14)),

                  const SizedBox(height: 5),

                  Text("\$${_totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),

                ],

              ),

            ),

          Expanded(

            child: ListView.builder(

              itemCount: _items.length,

              itemBuilder: (context, index) {

                final item = _items[index];

                final isCOGS = item.category.toUpperCase() == 'COGS';

                return Container(

                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(

                    color: const Color(0xFF222222),

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(color: isCOGS ? Colors.orange.withOpacity(0.5) : Colors.blue.withOpacity(0.5), width: 1),

                  ),

                  child: Row(

                    children: [

                      Container(

                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                        decoration: BoxDecoration(color: isCOGS ? Colors.orange : Colors.blue, borderRadius: BorderRadius.circular(4)),

                        child: Text(item.category, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),

                      ),

                      const SizedBox(width: 12),

                      Expanded(child: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 16))),

                      Text("\$${item.amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),

                    ],

                  ),

                );

              },

            ),

          ),

          if (_items.isNotEmpty)

            Padding(

              padding: const EdgeInsets.all(16.0),

              child: SizedBox(

                width: double.infinity,

                height: 50,

                child: ElevatedButton(

                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),

                  onPressed: () {

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved! (Mock)')));

                    context.pop();

                  },

                  child: const Text('Confirm & Save', style: TextStyle(color: Colors.black, fontSize: 18)),

                ),

              ),

            ),

        ],

      ),

    );

  }

}