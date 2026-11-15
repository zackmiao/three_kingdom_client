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
  });

  static const double cardW = 112;
  static const double cardH = 158;

  Widget _buildCardFace(CardModel card, bool isSelected) {
    return CardFace(
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
