import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import 'card_face.dart';

/// 手牌横条（扇形自适应版）：
///
/// * 每张牌固定 130×182（5:7 标准扑克比例），任何状态（可打出 / 置暗 /
///   酒伤害+1 / 两仪 / 潜龙 / 视为X）都用**同一外框**，绝不因角标而缩放；
/// * 角标一律用最外层 Stack 的 Positioned 悬浮叠加，不参与内部排版；
/// * ≤6 张时以 10px 舒适间距居中展示；>6 张时自动算负边距重叠，整体不超出可用宽度；
/// * 悬停或选中的牌放大 1.1 倍、上浮 22px，并在绘制顺序上置顶（不会被右侧邻牌压住）。
class HandCardArea extends StatefulWidget {
  final List<CardModel> handCards;
  final Set<int> selectedIndices;
  final int maxHandCards;
  final bool enabled;
  final Function(CardModel card) onCardTap;
  final Function(Offset globalPosition, CardModel card)? onCardDragging;
  final VoidCallback? onCardDragEnd;

  /// 返回 false 的牌会被置暗（当前询问下不能用来响应的牌）。
  final bool Function(CardModel card)? isPlayable;

  /// 身上有【酒】加成时，手牌里的【杀】右上角标注「伤害+1」
  final bool shaBonus;

  /// 多选场景（弃牌阶段等）：按住并横向滑动时，滑过的手牌会被加入选择。
  /// 参数是该牌的 `CardModel.index`。
  final ValueChanged<int>? onSlideSelect;

  const HandCardArea({
    super.key,
    required this.handCards,
    required this.selectedIndices,
    required this.onCardTap,
    this.maxHandCards = 0,
    this.enabled = true,
    this.onCardDragging,
    this.onCardDragEnd,
    this.isPlayable,
    this.shaBonus = false,
    this.onSlideSelect,
  });

  /// 单张手牌标准外框（全项目共用，禁止在特殊状态分支里改尺寸）
  static const double cardW = CardFace.handW;
  static const double cardH = CardFace.handH;

  /// 少牌时的舒适间距
  static const double comfortGap = 10;

  /// 最多这么多张以内保持舒适间距，超过则自动重叠
  static const int comfortLimit = 6;

  /// 悬停/选中时的放大倍数与上浮距离
  static const double hoverScale = 1.1;
  static const double hoverRise = 22;

  @override
  State<HandCardArea> createState() => _HandCardAreaState();
}

class _HandCardAreaState extends State<HandCardArea> {
  int? _hovered;

  bool _isSha(CardModel c) =>
      c.typeKey == 'SHA' ||
      c.typeKey == 'FIRE_SHA' ||
      c.typeKey == 'THUNDER_SHA';

  /// 卡牌本体 + 所有悬浮角标（外框尺寸恒定，角标不参与排版）
  Widget _cardView(CardModel card, bool isSelected, bool playable, double unit) {
    final bool showShaBonus = widget.shaBonus && _isSha(card);

    Widget face = CardFace(
      typeKey: card.typeKey,
      name: card.name,
      suitSymbol: card.suitSymbol,
      points: card.points,
      isRed: card.isRed,
      index: card.index,
      selected: isSelected,
      width: HandCardArea.cardW,
      height: HandCardArea.cardH,
      asTransformed:
          (card.asTransformed == 'NONE' || card.asTransformed.isEmpty)
              ? null
              : card.asTransformed,
    );

    if (!playable) {
      face = Opacity(
        opacity: 0.34,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.3, 0.3, 0.3, 0, 0, //
            0.3, 0.3, 0.3, 0, 0, //
            0.3, 0.3, 0.3, 0, 0, //
            0, 0, 0, 1, 0, //
          ]),
          child: face,
        ),
      );
    }

    final badges = <Widget>[
      // 酒：伤害+1（右上角悬浮，不挤占牌名与插画）
      if (showShaBonus)
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7043), Color(0xFFD84315)],
              ),
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(color: Color(0x996B4A00), blurRadius: 8),
              ],
            ),
            child: Text('伤害+1',
                style: TextStyle(
                    fontSize: 9.5 * unit,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4)),
          ),
        ),
      // 两仪牌 / 潜龙牌（左侧中部悬浮，避开右上角与底部效果条）
      if (card.liangYi)
        Positioned(
          left: 4,
          bottom: 40,
          child: _SpecialTag(
            text: '两仪×2',
            unit: unit,
            colors: const [Color(0xFFFFD54F), Color(0xFFB8860B)],
          ),
        ),
      if (card.qianLongLevel > 0)
        Positioned(
          left: 4,
          bottom: card.liangYi ? 62 : 40,
          child: _SpecialTag(
            text: '潜龙+${card.qianLongLevel}',
            unit: unit,
            colors: const [Color(0xFFBA68C8), Color(0xFF6A1B9A)],
          ),
        ),
    ];

    return SizedBox(
      width: HandCardArea.cardW,
      height: HandCardArea.cardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [face, ...badges],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.handCards;
    if (cards.isEmpty) {
      return const Center(
        child: Text('手牌区空空如也',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int n = cards.length;
        const double unit = HandCardArea.cardW / CardFace.handW; // = 1
        final double avail = (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width) -
            12;
        final double needed =
            n * HandCardArea.cardW + (n - 1) * HandCardArea.comfortGap;

        final bool overlap =
            n > HandCardArea.comfortLimit || needed > avail;
        final double step = n <= 1
            ? HandCardArea.cardW
            : overlap
                ? ((avail - HandCardArea.cardW) / (n - 1))
                    .clamp(26.0, HandCardArea.cardW + HandCardArea.comfortGap)
                : HandCardArea.cardW + HandCardArea.comfortGap;

        final double totalW =
            (n - 1) * step + HandCardArea.cardW + HandCardArea.hoverRise;
        final bool scrollable = step <= 27 && totalW > avail;

        // 悬停/选中的牌最后绘制 → 始终压在其他牌之上
        final List<int> order = List<int>.generate(n, (i) => i);
        order.sort((a, b) {
          bool ra = _hovered == a || widget.selectedIndices.contains(cards[a].index);
          bool rb = _hovered == b || widget.selectedIndices.contains(cards[b].index);
          if (ra == rb) return a.compareTo(b);
          return ra ? 1 : -1;
        });

        const double stackH =
            HandCardArea.cardH + HandCardArea.hoverRise + 8;

        Widget stack = SizedBox(
          width: math.max(totalW, avail),
          height: stackH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in order)
                Positioned(
                  // 牌堆里可能有同名同花色的牌，Key 必须用「卡牌实例ID + 位置」保证唯一
                  key: ValueKey('hand-${cards[i].index}-$i'),
                  left: i * step + (math.max(totalW, avail) - totalW) / 2,
                  bottom: 0,
                  child: _FanCard(
                    raised: _hovered == i ||
                        widget.selectedIndices.contains(cards[i].index),
                    onHover: (v) => setState(() => _hovered = v ? i : null),
                    child: Listener(
                      onPointerMove: (event) {
                        if (widget.onCardDragging != null) {
                          widget.onCardDragging!(event.position, cards[i]);
                        }
                      },
                      child: Draggable<CardModel>(
                        data: cards[i],
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(
                            opacity: 0.9,
                            child: _cardView(cards[i], true, true, unit),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _cardView(
                            cards[i],
                            false,
                            widget.isPlayable == null ||
                                widget.isPlayable!(cards[i]),
                            unit,
                          ),
                        ),
                        onDragEnd: (_) => widget.onCardDragEnd?.call(),
                        child: GestureDetector(
                          onTap: () => widget.onCardTap(cards[i]),
                          child: _cardView(
                            cards[i],
                            widget.selectedIndices.contains(cards[i].index),
                            widget.isPlayable == null ||
                                widget.isPlayable!(cards[i]),
                            unit,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        if (scrollable) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _withSlideSelect(stack, cards, step, totalW, avail),
          );
        }
        return Center(child: _withSlideSelect(stack, cards, step, totalW, avail));
      },
    );
  }

  /// 给手牌区套上「按住滑动多选」：横向拖过哪张牌，就把哪张牌加入选择。
  Widget _withSlideSelect(
    Widget child,
    List<CardModel> cards,
    double step,
    double totalW,
    double avail,
  ) {
    if (widget.onSlideSelect == null) return child;

    void slideAt(Offset localPosition) {
      if (cards.isEmpty) return;
      final double left = (math.max(totalW, avail) - totalW) / 2;
      final double dx = localPosition.dx - left;
      int i = step <= 0 ? 0 : (dx / step).floor();
      if (i < 0) i = 0;
      if (i > cards.length - 1) i = cards.length - 1;
      widget.onSlideSelect!(cards[i].index);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (d) => slideAt(d.localPosition),
      onPanUpdate: (d) => slideAt(d.localPosition),
      child: child,
    );
  }
}

/// 单张手牌的悬停/选中动效：放大 1.1 倍 + 上浮 22px
class _FanCard extends StatelessWidget {
  final Widget child;
  final bool raised;
  final ValueChanged<bool> onHover;

  const _FanCard({
    required this.child,
    required this.raised,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedSlide(
        offset: Offset(
            0, raised ? -HandCardArea.hoverRise / HandCardArea.cardH : 0),
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: raised ? HandCardArea.hoverScale : 1.0,
          alignment: Alignment.bottomCenter,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: child,
        ),
      ),
    );
  }
}

/// 两仪 / 潜龙 等状态角标（金/紫渐变，白字加粗 + 光晕）
class _SpecialTag extends StatelessWidget {
  final String text;
  final double unit;
  final List<Color> colors;

  const _SpecialTag({
    required this.text,
    required this.unit,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5 * unit, vertical: 2 * unit),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(5 * unit),
        boxShadow: [
          BoxShadow(color: colors.last.withValues(alpha: 0.85), blurRadius: 9),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9 * unit,
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
