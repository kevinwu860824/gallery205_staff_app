import 'package:flutter/material.dart';

class DarkStyleDialog extends StatelessWidget {
  final String title;
  final Widget contentWidget;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String? confirmText;
  final String? cancelText;

  const DarkStyleDialog({
    super.key,
    required this.title,
    required this.contentWidget,
    required this.onCancel,
    required this.onConfirm,
    this.confirmText,
    this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, 
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            contentWidget,
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: Text(cancelText ?? "取消", style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 16)),
                ),
                SizedBox(
                  width: 120, height: 40,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface, 
                      foregroundColor: Theme.of(context).colorScheme.surface, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(confirmText ?? "確認", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
