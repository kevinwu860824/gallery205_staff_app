import 'package:flutter/material.dart';

class EditOrderScreen extends StatelessWidget {
  final String? tableName;
  const EditOrderScreen({super.key, this.tableName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("編輯訂單 ${tableName ?? ''}")),
      body: const Center(child: Text("功能開發中")),
    );
  }
}