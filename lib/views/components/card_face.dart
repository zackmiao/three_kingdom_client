import 'package:flutter/material.dart';
import '../../models/card_catalog.dart';

/// 真实牌面渲染（贴近实体三国杀卡面）：
///
/// ```
/// ┌──────────────────┐
/// │ ♥   【杀】        │  ← 左上角竖排花色+点数（8px 安全内边距）
/// │ K                │     顶部居中大号宋体/楷体牌名
/// │                  │
/// │    卡面插画        │  ← 官方牌面图等比铺满，不横向挤压
/// │                  │
/// │ ╭──────────────╮ │
/// │ │ 半透明羊皮纸效果简述 │ │  ← 深棕色小字，不遮挡插画
/// │ ╰──────────────╯ │
/// └──────────────────┘
/// ```
///
/// 尺寸铁律：**所有**调用方共用固定外框（默认 130×182，5:7 标准扑克比例），
/// 高一律由宽推导（`width * 1.4`），任何角标（伤害+1 / 两仪 / 潜龙 / 视为X）
/// 都只做 `Positioned` 悬浮叠加，绝不参与内部的 Column 高度分配 —— 这是之前
/// 「喝了酒之后【杀】看起来小一圈」的根因。
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

  /// 兼容参数：为保证全项目比例一致，实际高度一律按 [heightFor] 由宽度推导
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
    this.width = handW,
    this.height = handH,
    this.asTransformed,
    this.showCorner = true,
  });

  /// 手牌标准尺寸：130×182（宽高比 5:7，标准扑克牌比例）
  static const double handW = 130;
  static const double handH = 182;

  /// 5:7 标准卡牌比例
  static const double cardAspect = 5 / 7;

  /// 由宽度推导出的牌高（130 → 182）
  static double heightFor(double width) => width / cardAspect;

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

  /// 楷体/宋体优先，缺字时回落到系统默认
  static const List<String> _cnFonts = <String>[
    'KaiTi',
    'STKaiti',
    'SimSun',
    'Songti SC',
  ];

  @override
  Widget build(BuildContext context) {
    final double w = width;
    final double h = heightFor(w);
    // 所有内部字号/间距都按宽度等比缩放，改尺寸不会破坏排版
    final double unit = w / handW;
    final info = CardCatalog.of(typeKey, name);
    final accent = info.accent;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 * unit),
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
          // ---------- 1. 卡面插画（等比铺满，不横向挤压） ----------
          Image.asset(
            'assets/cards/$typeKey.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) =>
                _drawnFallback(info, accent, unit),
          ),

          // 顶部/底部压暗，保证牌名与效果简述始终清晰
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: h * 0.22,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.42),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ---------- 2. 左上角：花色 + 点数竖排 ----------
          if (showCorner && (suitSymbol.isNotEmpty || points.isNotEmpty))
            Positioned(
              left: 8 * unit,
              top: 8 * unit,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    suitSymbol,
                    style: TextStyle(
                      fontSize: 15 * unit,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: isRed
                          ? const Color(0xFFFF8A80)
                          : const Color(0xFFF5F5F5),
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    points,
                    style: TextStyle(
                      fontSize: 17 * unit,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      color: isRed
                          ? const Color(0xFFFF8A80)
                          : const Color(0xFFF5F5F5),
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ---------- 3. 顶部居中：大号牌名（楷体/宋体） ----------
          Positioned(
            left: 42 * unit,
            right: 42 * unit,
            top: 7 * unit,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 6 * unit, vertical: 2 * unit),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xE6F5E6C8),
                    Color(0xCCE8D5A9),
                  ],
                ),
                borderRadius: BorderRadius.circular(4 * unit),
                border: Border.all(
                    color: const Color(0x99A1885A), width: 0.8 * unit),
              ),
              child: Text(
                '【$name】',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _cnFonts.first,
                  fontFamilyFallback: _cnFonts.sublist(1),
                  fontSize: 17 * unit,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: const Color(0xFF3E2723),
                ),
              ),
            ),
          ),

          // ---------- 4. 底部：半透明羊皮纸效果简述 ----------
          if (info.desc.isNotEmpty)
            Positioned(
              left: 5 * unit,
              right: 5 * unit,
              bottom: 5 * unit,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    6 * unit, 3 * unit, 6 * unit, 3 * unit),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xD9F3E7C8),
                      Color(0xC4E5D3A6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4 * unit),
                  border: Border.all(
                      color: const Color(0x66A1885A), width: 0.7 * unit),
                ),
                child: Text(
                  info.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _cnFonts.first,
                    fontFamilyFallback: _cnFonts.sublist(1),
                    fontSize: 8.8 * unit,
                    height: 1.18,
                    color: const Color(0xFF4E342E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ---------- 5. 右上角：视为X 转化角标（悬浮，不占排版） ----------
          if (asTransformed != null && asTransformed!.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 5 * unit, vertical: 2 * unit),
                decoration: BoxDecoration(
                  color: const Color(0xE6E65100),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8 * unit)),
                ),
                child: Text('视为$asTransformed',
                    style: TextStyle(
                        fontSize: 8.5 * unit,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),

          // ---------- 6. 右下角：手牌序号（悬浮，不占排版） ----------
          if (showIndex)
            Positioned(
              right: 4 * unit,
              bottom: (info.desc.isNotEmpty ? 5 : 3) * unit,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 3 * unit),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(3 * unit),
                ),
                child: Text('$index',
                    style: TextStyle(
                        fontSize: 8.5 * unit, color: Colors.white70)),
              ),
            ),
        ],
      ),
    );
  }

  /// 缺图时的绘制牌面（原来的样式，作为兜底）
  Widget _drawnFallback(CardInfo info, Color accent, double unit) {
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
            height: 16 * unit,
            padding: EdgeInsets.symmetric(horizontal: 5 * unit),
            color: accent,
            child: Row(children: [
              Expanded(
                child: Text(info.category,
                    style: TextStyle(
                        fontSize: 9 * unit,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: Text(name,
                  style: TextStyle(
                      fontFamily: _cnFonts.first,
                      fontFamilyFallback: _cnFonts.sublist(1),
                      fontSize: 22 * unit,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2B1B12))),
            ),
          ),
          SizedBox(height: 8 * unit),
        ],
      ),
    );
  }
}
