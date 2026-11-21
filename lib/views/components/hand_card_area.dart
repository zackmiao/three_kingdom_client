import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import 'card_face.dart';

/// 手牌横条：只负责渲染卡牌与选中/拖拽交互，表头与按钮由外层操作区提供。
class HandCardArea extends StatelessWidget {
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
  });

  static const double cardW = 112;
  static const double cardH = 158;

  Widget _buildCardFace(CardModel card, bool isSelected) {
    final face = CardFace(
      typeKey: card.typeKey,
      name: card.name,
      suitSymbol: card.suitSymbol,
      points: card.points,
      isRed: card.isRed,
      index: card.index,
      selected: isSelected,
      width: cardW,
      height: cardH,
      asTransformed: (card.asTransformed == 'NONE' || card.asTransformed.isEmpty)
          ? null
          : card.asTransformed,
    );
    final bool isSha = card.typeKey == 'SHA' ||
        card.typeKey == 'FIRE_SHA' ||
        card.typeKey == 'THUNDER_SHA';
    final bool showShaBonus = shaBonus && isSha;
    if (!card.hasSpecialTag && !showShaBonus) return face;
    return Stack(
      children: [
        face,
        if (card.hasSpecialTag)
          Positioned(left: 4, bottom: 6, child: _specialBadge(card)),
        if (showShaBonus)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF7043), Color(0xFFD84315)]),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFFE0B2), width: 0.9),
                boxShadow: const [
                  BoxShadow(color: Color(0x99FF6D00), blurRadius: 8, spreadRadius: 1),
                ],
              ),
              child: const Text('伤害+1',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
            ),
          ),
      ],
    );
  }

  /// 司马昭系强化牌角标：两仪牌（金，效果结算两次）/ 潜龙牌（紫，伤害与回复 +层数）
  Widget _specialBadge(CardModel card) {
    final bool liangYi = card.liangYi;
    final String text = liangYi ? '两仪×2' : '潜龙+${card.qianLongLevel}';
    final List<Color> colors = liangYi
        ? const [Color(0xFFFFD54F), Color(0xFFB8860B)]
        : const [Color(0xFFBA68C8), Color(0xFF6A1B9A)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 0.9),
        boxShadow: [
          BoxShadow(
              color: colors.first.withValues(alpha: 0.85),
              blurRadius: 8,
              spreadRadius: 1),
        ],
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 9.5,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.05,
              shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (handCards.isEmpty) {
      return const Center(
        child: Text('暂无手牌', style: TextStyle(color: Colors.white24, fontSize: 12)),
      );
    }
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
      itemCount: handCards.length,
      itemBuilder: (context, index) {
        final card = handCards[index];
        final isSelected = selectedIndices.contains(card.index);
        final bool playable = isPlayable == null || isPlayable!(card);

        return Padding(
          padding: EdgeInsets.only(
              right: 6, top: isSelected || !playable ? 0 : 6,
              bottom: isSelected ? 8 : 0),
          child: Listener(
            onPointerMove: (event) {
              if (onCardDragging != null) onCardDragging!(event.position, card);
            },
            child: Draggable<CardModel>(
              data: card,
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(opacity: 0.9, child: _buildCardFace(card, true)),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: _buildCardFace(card, false)),
              onDragEnd: (details) {
                if (onCardDragEnd != null) onCardDragEnd!();
              },
              child: _HoverLift(
                child: GestureDetector(
                  onTap: () => onCardTap(card),
                  child: playable
                      ? _buildCardFace(card, isSelected)
                      : Opacity(
                          opacity: 0.34,
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.matrix(<double>[
                              0.3, 0.3, 0.3, 0, 0,
                              0.3, 0.3, 0.3, 0, 0,
                              0.3, 0.3, 0.3, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                            child: _buildCardFace(card, isSelected),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HoverLift extends StatefulWidget {
  final Widget child;
  const _HoverLift({required this.child});

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.06 : 1.0,
        alignment: Alignment.bottomCenter,
        duration: const Duration(milliseconds: 110),
        child: AnimatedPadding(
          padding: EdgeInsets.only(bottom: _hover ? 6 : 0),
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}
