import 'package:flutter/material.dart';

class SplitBillScreen extends StatelessWidget {
  final String groupKey;
  final String? seat;
  final List<dynamic>? orders;

  const SplitBillScreen({
    super.key, 
    required this.groupKey, 
    this.seat, 
    this.orders
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("拆單")),
      body: const Center(child: Text("功能開發中")),
    );
  }
}