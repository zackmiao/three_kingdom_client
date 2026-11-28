// 预览界面几何回归：验证出牌结算区落在窗口视觉中心附近、
// 底部操作区与右侧武将/装备区铺满右下角（对应"居中偏下""放大右侧"两条反馈）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/preview.dart';
import 'package:three_kingdom_client/views/components/center_stage_view.dart';
import 'package:three_kingdom_client/views/components/hand_card_area.dart';
import 'package:three_kingdom_client/views/components/table_seat_card.dart';

Future<void> _pump(WidgetTester tester, Size size) async {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: BoardPreview()));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('1500x940：出牌结算区位于视觉中心偏下，右下区域铺满', (tester) async {
    await _pump(tester, const Size(1500, 940));
    expect(tester.takeException(), isNull);

    final Rect stage = tester.getRect(find.byType(CenterStageView));
    // ignore: avoid_print
    print('CENTER_STAGE rect=$stage center=${stage.center}');

    final Rect hand = tester.getRect(find.byType(HandCardArea));
    // ignore: avoid_print
    print('HAND rect=$hand');

    final seats = find.byType(TableSeatCard);
    // ignore: avoid_print
    print('SEATS count=${tester.widgetList(seats).length}');
    for (final e in seats.evaluate()) {
      final r = tester.getRect(find.byWidget(e.widget));
      final card = e.widget as TableSeatCard;
      // ignore: avoid_print
      print('SEAT ${card.name} me=${card.isMe} rect=$r');
    }

    // 出牌区中心：横向居中，纵向在窗口中心附近（允许偏下 120px）
    expect((stage.center.dx - 750).abs(), lessThan(60),
        reason: '出牌区应横向居中，实际 ${stage.center.dx}');
    expect(stage.center.dy, greaterThan(320));
    expect(stage.center.dy, lessThan(600));

    // 手牌区必须落在底部操作区内
    expect(hand.bottom, greaterThan(860));
    // 主视角武将卡必须在右下角
    final me = tester
        .widgetList<TableSeatCard>(seats)
        .firstWhere((c) => c.isMe);
    final Rect meRect = tester.getRect(find.byWidget(me));
    // ignore: avoid_print
    print('ME rect=$meRect');
    expect(meRect.right, greaterThan(1400));
    expect(meRect.bottom, greaterThan(880));
    // compact 放大后尺寸
    expect(meRect.width, greaterThanOrEqualTo(170));
    expect(meRect.height, greaterThanOrEqualTo(230));
  });
}
