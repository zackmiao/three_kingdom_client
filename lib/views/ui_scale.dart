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

  /// 额外的界面缩放（1.0 = 设计基准）。> 1 时界面元素变大、视野变窄；
  /// 由设置界面里的「界面缩放」驱动。
  final double extraScale;

  const ScaledStage({super.key, required this.child, this.extraScale = 1.0});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // 约束无界（例如被放进滚动视图）时不做缩放，直接交给子级布局
      if (!c.hasBoundedWidth || !c.hasBoundedHeight) return child;
      final double extra = extraScale.clamp(0.85, 1.15);
      final double s = stageScaleOf(c) * extra;
      if ((s - 1.0).abs() < 0.002) return SizedBox.expand(child: child);
      // 关键：子级逻辑尺寸 = 父级尺寸 / s，再整体缩放 s 倍，
      // 两个轴都恰好铺满，任何宽高比下都不会出现黑边或留白。
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.center,
          child: SizedBox(
            width: c.maxWidth / s,
            height: c.maxHeight / s,
            child: child,
          ),
        ),
      );
    });
  }
}
