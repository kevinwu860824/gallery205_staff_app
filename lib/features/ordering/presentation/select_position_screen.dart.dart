import 'package:flutter/material.dart';

class SelectPositionScreen extends StatelessWidget {
  final String area;
  const SelectPositionScreen({super.key, required this.area});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("選擇位置")),
      body: const Center(child: Text("此功能已由新版桌圖取代")),
    );
  }
}