import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 攻击指示：从出牌者卡片中心射向目标的橙金色发光光束。
class TargetArrowPainter extends CustomPainter {
  final Offset? fromOffset;
  final List<Offset> toOffsets;

  TargetArrowPainter({this.fromOffset, required this.toOffsets});

  @override
  void paint(Canvas canvas, Size size) {
    final from = fromOffset;
    if (from == null || toOffsets.isEmpty) return;

    for (final to in toOffsets) {
      final delta = to - from;
      final dist = delta.distance;
      if (dist < 1) continue;
      final dir = delta / dist;
      final start = from + dir * 18;
      final end = to - dir * 26;

      // 外发光
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0x55FFB300)
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // 主光束（橙金渐变）
      canvas.drawLine(
        start,
        end,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFFF8F00)],
          ).createShader(Rect.fromPoints(start, end))
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );

      // 箭头
      final angle = math.atan2(delta.dy, delta.dx);
      const arrowLen = 16.0;
      final p1 = end;
      final p2 = end -
          Offset(math.cos(angle - 0.45), math.sin(angle - 0.45)) * arrowLen;
      final p3 = end -
          Offset(math.cos(angle + 0.45), math.sin(angle + 0.45)) * arrowLen;
      final tip = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      canvas.drawPath(
        tip,
        Paint()..color = const Color(0xFFFFC107),
      );
      canvas.drawPath(
        tip,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFFF3CD),
      );

      // 起点光点
      canvas.drawCircle(
          start,
          6,
          Paint()
            ..color = const Color(0xFFFFD54F)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(start, 2.6, Paint()..color = Colors.white);
      // 目标光点
      canvas.drawCircle(
          end,
          7,
          Paint()
            ..color = const Color(0x66FF6D00)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
  }

  @override
  bool shouldRepaint(covariant TargetArrowPainter oldDelegate) {
    return oldDelegate.fromOffset != fromOffset ||
        oldDelegate.toOffsets.length != toOffsets.length ||
        (oldDelegate.toOffsets.isNotEmpty &&
            toOffsets.isNotEmpty &&
            oldDelegate.toOffsets.first != toOffsets.first);
  }
}
