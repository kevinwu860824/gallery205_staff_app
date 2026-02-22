import 'package:flutter/cupertino.dart';

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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: screenWidth * 0.9,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: CupertinoColors.activeBlue, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: CupertinoColors.white,
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: CupertinoColors.activeBlue,
              fontSize: 16,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
