import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/models/card_model.dart';
import 'package:three_kingdom_client/views/components/card_face.dart';
import 'package:three_kingdom_client/views/components/hand_card_area.dart';

/// 手牌卡面尺寸回归测试。
///
/// 曾经的 bug：喝过【酒】之后，手牌里的【杀】因为额外角标参与了内部布局，
/// 尺寸比其它手牌小一圈。现在所有状态（酒加成 / 两仪 / 潜龙 / 不可打出置暗）
/// 都必须共用 130×182 的固定外框。
void main() {
  CardModel card(
    int index,
    String typeKey,
    String name, {
    bool liangYi = false,
    int qianLongLevel = 0,
  }) {
    return CardModel(
      index: index,
      typeKey: typeKey,
      suitKey: 'SPADE',
      points: '7',
      cardId: 100 + index,
      name: name,
      liangYi: liangYi,
      qianLongLevel: qianLongLevel,
    );
  }

  Future<void> pumpHand(
    WidgetTester tester, {
    required List<CardModel> cards,
    bool shaBonus = false,
    bool Function(CardModel)? isPlayable,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1500, 940);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 1100,
            height: 240,
            child: HandCardArea(
              handCards: cards,
              selectedIndices: const {},
              onCardTap: (_) {},
              isPlayable: isPlayable,
              shaBonus: shaBonus,
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('全部手牌（含酒加成 / 两仪 / 潜龙）共用 130×182 外框', (tester) async {
    final cards = <CardModel>[
      card(0, 'SHA', '杀'),
      card(1, 'SHA', '杀'),
      card(2, 'TAO', '桃', liangYi: true),
      card(3, 'SHAN', '闪', qianLongLevel: 2),
    ];
    await pumpHand(tester, cards: cards, shaBonus: true);

    final faces = find.byType(CardFace);
    expect(faces, findsNWidgets(cards.length));
    for (var i = 0; i < cards.length; i++) {
      final size = tester.getSize(faces.at(i));
      expect(size.width, HandCardArea.cardW, reason: '第 $i 张牌宽度应固定');
      expect(size.height, HandCardArea.cardH, reason: '第 $i 张牌高度应固定');
    }
  });

  testWidgets('不可打出的牌（置暗）尺寸同样不变', (tester) async {
    final cards = <CardModel>[
      card(0, 'SHA', '杀'),
      card(1, 'SHAN', '闪'),
    ];
    await pumpHand(
      tester,
      cards: cards,
      isPlayable: (c) => c.typeKey != 'SHAN',
    );

    final faces = find.byType(CardFace);
    expect(faces, findsNWidgets(cards.length));
    for (var i = 0; i < cards.length; i++) {
      final size = tester.getSize(faces.at(i));
      expect(size.width, HandCardArea.cardW);
      expect(size.height, HandCardArea.cardH);
    }
  });

  testWidgets('悬停放大只影响绘制，不影响布局尺寸', (tester) async {
    final cards = <CardModel>[card(0, 'SHA', '杀'), card(1, 'TAO', '桃')];
    await pumpHand(tester, cards: cards, shaBonus: true);

    final first = find.byType(CardFace).first;
    final before = tester.getSize(first);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(first));
    await tester.pump(const Duration(milliseconds: 200));

    final after = tester.getSize(first);
    expect(after.width, before.width);
    expect(after.height, before.height);
  });

  test('卡面比例固定为 5:7', () {
    expect(CardFace.cardAspect, closeTo(5 / 7, 1e-9));
    expect(CardFace.heightFor(130), closeTo(182, 1e-6));
  });
}
