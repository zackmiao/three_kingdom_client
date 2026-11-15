// 战局界面布局回归测试：不同窗口尺寸下都不应出现溢出/异常。
// 重点覆盖：ScaledStage 等比缩放、底部三分区高度、U 型席位坐标。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/views/components/center_stage_view.dart';
import 'package:three_kingdom_client/views/components/hand_card_area.dart';
import 'package:three_kingdom_client/views/components/table_seat_card.dart';
import 'package:three_kingdom_client/views/game_room_screen.dart';

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(
      home: GameRoomScreen(playerId: 'p1', playerName: '测试员'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('1500x940 设计尺寸下战局界面无溢出', (tester) async {
    await _pumpAt(tester, const Size(1500, 940));
    expect(tester.takeException(), isNull);
    expect(find.byType(GameRoomScreen), findsOneWidget);

    final Rect stage = tester.getRect(find.byType(CenterStageView));
    final Rect hand = tester.getRect(find.byType(HandCardArea));
    // ignore: avoid_print
    print('1500x940 CENTER=$stage hand=$hand');
    // 出牌区横向居中
    expect((stage.center.dx - 750).abs(), lessThan(80));
    // 出牌区落在窗口纵向中部（视觉中心 ±150）
    expect(stage.center.dy, greaterThan(320));
    expect(stage.center.dy, lessThan(620));
    // 手牌区贴底
    expect(hand.bottom, greaterThan(900));
    // 主视角武将卡在右下且已放大
    final me = tester.widgetList<TableSeatCard>(
        find.byType(TableSeatCard));
    final mine = me.where((c) => c.isMe).toList();
    expect(mine.length, 1);
    final Rect meRect = tester.getRect(find.byWidget(mine.first));
    // ignore: avoid_print
    print('1500x940 ME=$meRect');
    expect(meRect.right, greaterThan(1400));
    expect(meRect.width, greaterThanOrEqualTo(170));
  });

  testWidgets('2560x1417 最大化：内容铺满且出牌区居中', (tester) async {
    await _pumpAt(tester, const Size(2560, 1417));
    expect(tester.takeException(), isNull);
    final Rect stage = tester.getRect(find.byType(CenterStageView));
    // ignore: avoid_print
    print('2560x1417 CENTER=$stage');
    expect((stage.center.dx - 1280).abs(), lessThan(120));
    expect(stage.center.dy, greaterThan(500));
    expect(stage.center.dy, lessThan(900));
  });

  testWidgets('1920x1080 全屏下战局界面无溢出', (tester) async {
    await _pumpAt(tester, const Size(1920, 1080));
    expect(tester.takeException(), isNull);
  });

  testWidgets('1000x627 小窗口（150% DPI）下战局界面无溢出', (tester) async {
    await _pumpAt(tester, const Size(1000, 627));
    expect(tester.takeException(), isNull);
  });

  testWidgets('2560x1417 超宽窗口下战局界面无溢出', (tester) async {
    await _pumpAt(tester, const Size(2560, 1417));
    expect(tester.takeException(), isNull);
  });
}
