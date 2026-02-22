// lib/features/auth/presentation/widgets/animated_wave_background.dart

import 'package:flutter/material.dart';
import 'package:gallery205_staff_app/core/theme/app_theme.dart';

// ✅ 修正：不再使用 simple_animations，改用 StatefulWidget
class AnimatedWaveBackground extends StatefulWidget {
  const AnimatedWaveBackground({super.key});

  @override
  State<AnimatedWaveBackground> createState() => _AnimatedWaveBackgroundState();
}

// ✅ 修正：加入 SingleTickerProviderStateMixin 來驅動動畫
class _AnimatedWaveBackgroundState extends State<AnimatedWaveBackground>
    with SingleTickerProviderStateMixin {
      
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation1;
  late Animation<Offset> _offsetAnimation2;

  @override
  void initState() {
    super.initState();
    
    // 1. 建立動畫控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // 動畫時長
    )..repeat(reverse: true); // 無限循環 (來回播放)

    // 2. 建立動畫 1 (從左到右)
    _offsetAnimation1 = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: const Offset(1, 0.6),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // 3. 建立動畫 2 (從右到左)
    _offsetAnimation2 = Tween<Offset>(
      begin: const Offset(1, 0.6),
      end: const Offset(0, 0.4),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 修正：使用 AnimatedBuilder 來監聽動畫控制器
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 4. 將動畫的「當前值」傳遞給 CustomPaint
        return CustomPaint(
          painter: WavePainter(
            offset1: _offsetAnimation1.value, // 傳遞 Offset.value
            offset2: _offsetAnimation2.value, // 傳遞 Offset.value
            waveColor: AppColors.loginWaveTop,
          ),
        );
      },
    );
  }
}

// CustomPainter (保持不變，它本來就是正確的)
class WavePainter extends CustomPainter {
  final Offset offset1;
  final Offset offset2;
  final Color waveColor;

  WavePainter({required this.offset1, required this.offset2, required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = waveColor;
    final path = Path();
    path.lineTo(0, size.height * 0.6);

    path.quadraticBezierTo(
      size.width * offset1.dx, size.height * offset1.dy,
      size.width * offset2.dx, size.height * (offset2.dy + 0.1),
    );

    path.quadraticBezierTo(
      size.width * (offset2.dx + 0.5), size.height * (offset2.dy - 0.1),
      size.width, size.height * 0.6,
    );

    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.offset1 != offset1 || oldDelegate.offset2 != offset2;
  }
}