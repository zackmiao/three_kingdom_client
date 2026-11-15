import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/views/components/card_face.dart';

/// 校验 30 张官方牌面素材确实被打进 assets 并且能正常解码，
/// 防止"牌面路径写错 → 静默回退成手绘卡牌"。
void main() {
  const keys = <String>[
    'SHA', 'FIRE_SHA', 'THUNDER_SHA', 'SHAN', 'TAO', 'JIU',
    'GUO_HE_CHAI_QIAO', 'SHUN_SHOU_QIAN_YANG', 'WU_ZHONG_SHENG_YOU', 'DUEL',
    'WU_XIE_KE_JI', 'NAN_MAN_RU_QIN', 'WAN_JIAN_QI_FA', 'TAO_YUAN_JIE_YI',
    'WU_GU_FENG_DENG', 'HUO_GONG', 'TIE_SUO_LIAN_HUAN',
    'LE_BU_SI_SHU', 'BING_LIANG_CUN_DUAN', 'SHAN_DIAN',
    'ZHU_GE_LIAN_NU', 'ZHANG_BA_SHE_MAO', 'QING_GANG_JIAN', 'GUAN_SHI_FU',
    'BA_GUA_ZHEN', 'REN_WANG_DUN', 'BAI_YIN_SHI_ZI', 'TENG_JIA',
    'DEFENSIVE_HORSE', 'OFFENSIVE_HORSE',
  ];

  TestWidgetsFlutterBinding.ensureInitialized();

  test('CardFace.hasArt 覆盖全部 30 种牌', () {
    for (final k in keys) {
      expect(CardFace.hasArt(k), isTrue, reason: '$k 未登记');
    }
    expect(CardFace.hasArt('NOT_A_CARD'), isFalse);
  });

  test('30 张牌面 PNG 都能从 asset bundle 读到', () async {
    for (final k in keys) {
      final data = await rootBundle.load('assets/cards/$k.png');
      expect(data.lengthInBytes, greaterThan(20000),
          reason: '$k.png 太小，可能不是真正的牌面图');
    }
  });

  testWidgets('CardFace 渲染牌面时不会触发 errorBuilder', (tester) async {
    var fellBack = false;
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CardFace(
            typeKey: 'SHA',
            name: '杀',
            suitSymbol: '♠',
            points: '7',
            isRed: false,
            index: 0,
            width: 112,
            height: 158,
          ),
        ),
      ),
    );
    // errorBuilder 命中时会出现 Text('?')
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      if (t.data == '?') fellBack = true;
    }
    expect(fellBack, isFalse);
    expect(find.byType(Image), findsOneWidget);
  });
}
