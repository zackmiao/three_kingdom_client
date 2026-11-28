import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/views/components/wugu_stage.dart';

void main() {
  const slots = [
    WuGuSlot(idx: 0, desc: '杀', typeKey: 'SHA', suitKey: 'SPADE', point: '7'),
    WuGuSlot(idx: 1, desc: '桃', typeKey: 'TAO', suitKey: 'HEART', point: 'Q'),
    WuGuSlot(desc: '闪', typeKey: 'SHAN', suitKey: 'CLUB', point: '3', owner: '人机 1'),
  ];

  Widget host({
    required String status,
    required bool canPick,
    void Function(WuGuSlot slot)? onPick,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: WuGuStage(
            slots: slots,
            statusText: status,
            canPick: canPick,
            slotKeys: const {},
            onPick: onPick,
          ),
        ),
      ),
    );
  }

  testWidgets('展台展示全部明牌，已被选走的牌盖章', (tester) async {
    await tester.pumpWidget(host(status: '正在等待【人机 1】选牌…', canPick: false));
    expect(find.text('五谷丰登'), findsOneWidget);
    expect(find.text('剩余 2 张 · 已被选走 1 张'), findsOneWidget);
    expect(find.text('人机 1 已选'), findsOneWidget);
    expect(find.text('正在等待【人机 1】选牌…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('轮到我时可以点选剩余牌，但不能点已选走的牌', (tester) async {
    final picked = <WuGuSlot>[];
    await tester.pumpWidget(host(
      status: '轮到你了！请点击选择一张牌',
      canPick: true,
      onPick: picked.add,
    ));

    // 已选走的「闪」点了没有反应
    await tester.tap(find.byKey(const ValueKey('wugu-slot-闪|SHAN|CLUB|3')));
    await tester.pump();
    expect(picked, isEmpty);

    // 点「桃」应回调，且带回服务端池内索引
    await tester.tap(find.byKey(const ValueKey('wugu-slot-桃|TAO|HEART|Q')));
    await tester.pump();
    expect(picked.length, 1);
    expect(picked.first.idx, 1);
    expect(picked.first.desc, '桃');
  });

  testWidgets('非当前选牌者点击无效（锁定展示态）', (tester) async {
    final picked = <WuGuSlot>[];
    await tester.pumpWidget(host(
      status: '正在等待【人机 2】选牌…',
      canPick: false,
      onPick: picked.add,
    ));
    await tester.tap(find.byKey(const ValueKey('wugu-slot-杀|SHA|SPADE|7')));
    await tester.pump();
    expect(picked, isEmpty);
  });

  testWidgets('牌池里有两张完全相同的牌时不会触发 Duplicate keys', (tester) async {
    // 同描述、同花色、同点数的两张牌：签名相同，必须靠唯一 keyId 区分
    const dupes = [
      WuGuSlot(idx: 0, desc: '杀', typeKey: 'SHA', suitKey: 'SPADE', point: '7', keyId: 'wugu-0'),
      WuGuSlot(idx: 1, desc: '杀', typeKey: 'SHA', suitKey: 'SPADE', point: '7', keyId: 'wugu-1'),
    ];
    final picked = <WuGuSlot>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: WuGuStage(
            slots: dupes,
            statusText: '轮到你了！请点击选择一张牌',
            canPick: true,
            slotKeys: const {},
            onPick: picked.add,
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('wugu-slot-wugu-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('wugu-slot-wugu-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wugu-slot-wugu-1')));
    await tester.pump();
    expect(picked.length, 1);
    expect(picked.first.idx, 1);
  });
}
