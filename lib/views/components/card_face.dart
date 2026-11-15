import 'package:flutter/material.dart';
import '../../models/card_catalog.dart';

/// 真实牌面渲染：使用 assets/cards/<TYPE_KEY>.jpg 的官方牌面图，
/// 叠加左上角花色点数、转化标记与选中光效；缺图时退化为绘制的牌面。
class CardFace extends StatelessWidget {
  final String typeKey;
  final String name;
  final String suitSymbol;
  final String points;
  final bool isRed;
  final int index;
  final bool selected;
  final bool showIndex;
  final double width;
  final double height;
  final String? asTransformed;
  /// 是否显示左上角花色点数（结算区的牌可能没有花色信息）
  final bool showCorner;

  const CardFace({
    super.key,
    required this.typeKey,
    required this.name,
    required this.suitSymbol,
    required this.points,
    required this.isRed,
    required this.index,
    this.selected = false,
    this.showIndex = true,
    this.width = 112,
    this.height = 158,
    this.asTransformed,
    this.showCorner = true,
  });

  static bool hasArt(String typeKey) => _known.contains(typeKey);

  static const Set<String> _known = {
    'SHA', 'FIRE_SHA', 'THUNDER_SHA', 'SHAN', 'TAO', 'JIU',
    'GUO_HE_CHAI_QIAO', 'SHUN_SHOU_QIAN_YANG', 'WU_ZHONG_SHENG_YOU', 'DUEL',
    'WU_XIE_KE_JI', 'NAN_MAN_RU_QIN', 'WAN_JIAN_QI_FA', 'TAO_YUAN_JIE_YI',
    'WU_GU_FENG_DENG', 'HUO_GONG', 'TIE_SUO_LIAN_HUAN',
    'LE_BU_SI_SHU', 'BING_LIANG_CUN_DUAN', 'SHAN_DIAN',
    'ZHU_GE_LIAN_NU', 'ZHANG_BA_SHE_MAO', 'QING_GANG_JIAN', 'GUAN_SHI_FU',
    'BA_GUA_ZHEN', 'REN_WANG_DUN', 'BAI_YIN_SHI_ZI', 'TENG_JIA',
    'DEFENSIVE_HORSE', 'OFFENSIVE_HORSE',
  };

  @override
  Widget build(BuildContext context) {
    final info = CardCatalog.of(typeKey, name);
    final accent = info.accent;

    final face = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: selected ? const Color(0xFFFFC94D) : accent,
            width: selected ? 3 : 1.4),
        boxShadow: [
          BoxShadow(
            color: selected ? const Color(0xCCFFC94D) : Colors.black54,
            blurRadius: selected ? 18 : 7,
            offset: Offset(0, selected ? -4 : 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 牌面图（等比铺满）
          Image.asset(
            'assets/cards/$typeKey.png',
            fit: BoxFit.fill,
            // 牌面素材为 200×281 无损 PNG（比例 0.712，与 112×158 基本一致，不会拉伸变形）
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => _drawnFallback(info, accent),
          ),
          // 左上角花色点数徽章
          if (showCorner)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(8)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(suitSymbol,
                    style: TextStyle(
                        fontSize: 11, color: isRed ? const Color(0xFFFF8A80) : Colors.white)),
                const SizedBox(width: 1),
                Text(points,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white, fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
          // 转化角标
          if (asTransformed != null && asTransformed!.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xE6E65100),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                ),
                child: Text('视为$asTransformed',
                    style: const TextStyle(
                        fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          if (showIndex)
            Positioned(
              right: 3,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('$index',
                    style: const TextStyle(fontSize: 8.5, color: Colors.white70)),
              ),
            ),
        ],
      ),
    );

    return face;
  }

  /// 缺图时的绘制牌面（原来的样式，作为兜底）
  Widget _drawnFallback(CardInfo info, Color accent) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBEF), Color(0xFFE9D9B4)],
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 16,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            color: accent,
            child: Row(children: [
              Expanded(
                child: Text(info.category,
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B1B12))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
            child: Text(info.desc,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 8, height: 1.2, color: Color(0xFF4E342E))),
          ),
        ],
      ),
    );
  }
}
