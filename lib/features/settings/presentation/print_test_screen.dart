import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrintTestScreen extends StatelessWidget {
  const PrintTestScreen({super.key});

  Future<void> _sendTestPrint() async {
    const printerIp = '192.168.1.99'; // 修改為你實際的出單機 IP
    const printerPort = 9100;

    final testMessage = <int>[
      ...utf8.encode('Hello World!\n'),
      0x1B, 0x64, 0x02, // ESC d 2 → 換兩行
      0x1D, 0x56, 0x41, 0x10 // ESC/POS 切紙指令
    ];

    try {
      final socket = await Socket.connect(printerIp, printerPort, timeout: Duration(seconds: 5));
      socket.add(testMessage);
      await socket.flush();
      await socket.close();
    } catch (e) {
      print('出單失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('出單測試'),
        backgroundColor: CupertinoColors.systemGrey6,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: CupertinoButton.filled(
          child: const Text('列印測試單'),
          onPressed: _sendTestPrint,
        ),
      ),
    );
  }
}
