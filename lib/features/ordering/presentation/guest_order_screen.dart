// lib/features/ordering/presentation/guest_order_screen.dart

import 'package:flutter/material.dart';

class GuestOrderScreen extends StatelessWidget {
  const GuestOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("顧客點餐"),
        backgroundColor: const Color(0xFF222222),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Text(
          "功能開發中\nComing Soon",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}