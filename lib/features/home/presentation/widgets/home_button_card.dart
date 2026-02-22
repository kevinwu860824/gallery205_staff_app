// lib/features/home/presentation/widgets/home_button_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:gallery205_staff_app/core/theme/app_theme.dart'; // 引入我們的主題

class HomeButtonCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const HomeButtonCard({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start, 
      mainAxisSize: MainAxisSize.min, 
      children: [
        // 圖示卡片 (64x64)
        SizedBox(
          width: 64,
          height: 64,
          child: Container(
            decoration: BoxDecoration(
              // ✅ 修正 1：使用 Theme cardColor
              color: Theme.of(context).cardColor, 
              borderRadius: BorderRadius.circular(15.0), 
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.1), 
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(15.0), 
                child: Center(
                  child: Icon(
                    icon, 
                    size: 32, 
                    // ✅ 修正 2：使用 Theme iconColor (onSurface often works, or primary)
                    color: Theme.of(context).iconTheme.color ?? Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 間距
        const SizedBox(height: 5), 

        // 文字標籤
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.homeButtonLabel.copyWith(
             color: Theme.of(context).colorScheme.onSurface,
          ), 
          maxLines: 2, 
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}