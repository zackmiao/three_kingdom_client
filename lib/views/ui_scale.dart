import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// 设计基准分辨率（窗口默认 1500×940）。
///
/// 战局界面所有尺寸都以这个基准手写，窗口比它大时再用
/// [ScaledStage] 整体等比放大，避免"全屏之后按键/字号反而变小"。
const double kDesignW = 1500;
const double kDesignH = 940;

/// 当前窗口相对设计基准的缩放倍率。
///
/// 全屏（1920×1080 等）时 > 1，整块战局等比放大，按键与字号跟着变大；
/// 窗口小于设计基准时按比例缩小，保证布局永远完整不裁切。
double stageScaleOf(BoxConstraints c) {
  if (!c.hasBoundedWidth || !c.hasBoundedHeight) return 1.0;
  final double s =
      math.min(c.maxWidth / kDesignW, c.maxHeight / kDesignH);
  return s.clamp(0.5, 2.2);
}

/// 把 [child] 按 [scale] 等比放大/缩小到铺满父级：内部仍以
/// `父级尺寸 / scale` 的逻辑尺寸布局，因此不会溢出，字号与图片也不会糊
/// （Flutter 的文字是矢量绘制，缩放后依旧清晰）。
class ScaledStage extends StatelessWidget {
  final Widget child;

  const ScaledStage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final double s = stageScaleOf(c);
      if ((s - 1.0).abs() < 0.002) return child;
      return FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: c.maxWidth / s,
          height: c.maxHeight / s,
          child: child,
        ),
      );
    });
  }
}
