import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 攻击指示：从出牌者卡片中心射向目标的发光光束。
///
/// [nature] 决定光束配色：普通【杀】赤红、【火杀】炽橙、【雷杀】紫蓝，
/// 其它牌（桃/锦囊等）沿用橙金色。
class TargetArrowPainter extends CustomPainter {
  final Offset? fromOffset;
  final List<Offset> toOffsets;
  final String nature;

  TargetArrowPainter({
    this.fromOffset,
    required this.toOffsets,
    this.nature = 'OTHER',
  });

  static const Color _shaGlow = Color(0x55FF3020);
  static const Color _fireGlow = Color(0x66FF9100);
  static const Color _thunderGlow = Color(0x665C6BC0);
  static const Color _otherGlow = Color(0x55FFB300);
  static const Color _dismantleGlow = Color(0x666A1B9A);
  static const Color _snatchGlow = Color(0x6600BFA5);
  static const Color _duelGlow = Color(0x66FF3D00);

  (Color, Color, Color) get _palette {
    switch (nature) {
      case 'SHA':
        return (const Color(0xFFFF8A80), const Color(0xFFD50000),
            const Color(0xFFFF5252));
      case 'FIRE':
        return (const Color(0xFFFFE082), const Color(0xFFFF6D00),
            const Color(0xFFFFAB40));
      case 'THUNDER':
        return (const Color(0xFFB3E5FC), const Color(0xFF5C6BC0),
            const Color(0xFF8E9BFF));
      case 'DISMANTLE':
        return (const Color(0xFFCE93D8), const Color(0xFF6A1B9A),
            const Color(0xFFAB47BC));
      case 'SNATCH':
        return (const Color(0xFFB2DFDB), const Color(0xFF00796B),
            const Color(0xFF4DD0C4));
      case 'DUEL':
        return (const Color(0xFFFFD180), const Color(0xFFBF360C),
            const Color(0xFFFF7043));
      default:
        return (const Color(0xFFFFE082), const Color(0xFFFF8F00),
            const Color(0xFFFFC107));
    }
  }

  Color get _glowColor {
    switch (nature) {
      case 'SHA':
        return _shaGlow;
      case 'FIRE':
        return _fireGlow;
      case 'THUNDER':
        return _thunderGlow;
      case 'DISMANTLE':
        return _dismantleGlow;
      case 'SNATCH':
        return _snatchGlow;
      case 'DUEL':
        return _duelGlow;
      default:
        return _otherGlow;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final from = fromOffset;
    if (from == null || toOffsets.isEmpty) return;

    final (coreA, coreB, tipColor) = _palette;

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
          ..color = _glowColor
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // 主光束（属性渐变）
      canvas.drawLine(
        start,
        end,
        Paint()
          ..shader = LinearGradient(colors: [coreA, coreB])
              .createShader(Rect.fromPoints(start, end))
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
      canvas.drawPath(tip, Paint()..color = tipColor);
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
            ..color = tipColor
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(start, 2.6, Paint()..color = Colors.white);
      // 目标光点
      canvas.drawCircle(
          end,
          7,
          Paint()
            ..color = _glowColor
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
  }

  @override
  bool shouldRepaint(covariant TargetArrowPainter oldDelegate) {
    return oldDelegate.fromOffset != fromOffset ||
        oldDelegate.nature != nature ||
        oldDelegate.toOffsets.length != toOffsets.length ||
        (oldDelegate.toOffsets.isNotEmpty &&
            toOffsets.isNotEmpty &&
            oldDelegate.toOffsets.first != toOffsets.first);
  }
}
