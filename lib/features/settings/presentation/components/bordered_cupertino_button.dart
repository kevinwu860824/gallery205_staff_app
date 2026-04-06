import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BorderedCupertinoButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const BorderedCupertinoButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final colorScheme = Theme.of(context).colorScheme;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: screenWidth * 0.9,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surface,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 16,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
