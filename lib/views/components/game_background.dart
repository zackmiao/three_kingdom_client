// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 古风暖色牌桌背景：赤壁江面渐变 + 暗角 + 水墨波纹（纯绘制，不依赖图片资源）。
class GameBackground extends StatelessWidget {
  const GameBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 底色：深褐 → 暗红 → 墨黑
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A1E12), Color(0xFF2A1610), Color(0xFF120A08)],
            ),
          ),
        ),
        // 上方暖光（像远处火光/夕照）
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.85),
              radius: 1.1,
              colors: [
                const Color(0x66FFB74D),
                const Color(0x33120A08),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // 水墨波纹 + 暗角
        CustomPaint(painter: _RiverPainter()),
      ],
    );
  }
}

class _RiverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 水面横纹
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x14FFD9A0);
    for (int i = 0; i < 14; i++) {
      final y = size.height * (0.42 + i * 0.042);
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 60) {
        path.quadraticBezierTo(x + 15, y - 6, x + 30, y);
        path.quadraticBezierTo(x + 45, y + 6, x + 60, y);
      }
      canvas.drawPath(path, wave);
    }

    // 暗角
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.longestSide * 0.72,
        [Colors.transparent, const Color(0xB3000000)],
        [0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & size, vignette);

    // 中央牌桌暖光晕
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height * 0.46),
        size.shortestSide * 0.42,
        [const Color(0x1FFFC98A), Colors.transparent],
        [0.0, 1.0],
      );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
