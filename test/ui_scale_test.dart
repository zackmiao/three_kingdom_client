import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/views/ui_scale.dart';

void main() {
  test('设计基准下不缩放', () {
    const c = BoxConstraints.tightFor(width: kDesignW, height: kDesignH);
    expect(stageScaleOf(c), closeTo(1.0, 0.002));
  });

  test('全屏放大：1920x1080 → 1.149', () {
    const c = BoxConstraints.tightFor(width: 1920, height: 1080);
    // min(1920/1500, 1080/940) = min(1.28, 1.1489) = 1.1489
    expect(stageScaleOf(c), closeTo(1.1489, 0.002));
  });

  test('窗口偏小时等比缩小，而不是裁切', () {
    const c = BoxConstraints.tightFor(width: 1000, height: 627);
    // min(0.6667, 0.6670) = 0.6667
    expect(stageScaleOf(c), closeTo(0.6667, 0.002));
  });

  test('极小窗口有下限保护', () {
    const c = BoxConstraints.tightFor(width: 200, height: 200);
    expect(stageScaleOf(c), closeTo(0.5, 0.001));
  });

  test('无界约束时退化为 1.0', () {
    expect(stageScaleOf(const BoxConstraints()), 1.0);
  });

  testWidgets('ScaledStage 把子控件放进 父级/缩放比 的逻辑空间', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.reset);

    Size? inner;
    await tester.pumpWidget(
      ScaledStage(
        child: LayoutBuilder(builder: (context, c) {
          inner = Size(c.maxWidth, c.maxHeight);
          return const SizedBox.expand();
        }),
      ),
    );
    expect(inner, isNotNull);
    // 1920 / 1.1489 ≈ 1671.2
    expect(inner!.width, closeTo(1671.2, 2.0));
    // 1080 / 1.1489 ≈ 940
    expect(inner!.height, closeTo(940.0, 2.0));
  });
}
