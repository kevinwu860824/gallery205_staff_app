import 'package:flutter/material.dart';

/// Release 模式下發生未捕獲錯誤時顯示的 fallback 畫面
/// 取代 Flutter 預設的紅色錯誤畫面
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: Color(0xFFFF9F0A),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '系統發生錯誤',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '錯誤已自動回報，\n請重新啟動應用程式。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      // 重新啟動 app（回到根路由）
                      runApp(const _RestartWidget());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A84FF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('重新啟動'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestartWidget extends StatelessWidget {
  const _RestartWidget();

  @override
  Widget build(BuildContext context) {
    // 觸發 app 重新啟動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      (context as Element).markNeedsBuild();
    });
    return const SizedBox.shrink();
  }
}
