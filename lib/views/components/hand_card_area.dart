import 'package:flutter/material.dart';
import '../../models/card_catalog.dart';
import '../../models/card_model.dart';

/// 手牌横条：只负责渲染卡牌与选中/拖拽交互，表头与按钮由外层操作区提供。
class HandCardArea extends StatelessWidget {
  final List<CardModel> handCards;
  final Set<int> selectedIndices;
  final int maxHandCards;
  final bool enabled;
  final Function(CardModel card) onCardTap;
  final Function(Offset globalPosition, CardModel card)? onCardDragging;
  final VoidCallback? onCardDragEnd;

  const HandCardArea({
    super.key,
    required this.handCards,
    required this.selectedIndices,
    required this.onCardTap,
    this.maxHandCards = 0,
    this.enabled = true,
    this.onCardDragging,
    this.onCardDragEnd,
  });

  static const double cardW = 112;
  static const double cardH = 158;

  Widget _buildCardFace(CardModel card, bool isSelected) {
    final isRed = ['HEART', 'DIAMOND'].contains(card.suitKey);
    final info = CardCatalog.of(card.typeKey, card.name);
    final accent = info.accent;
    final hasTransform = card.asTransformed != "NONE" && card.asTransformed.isNotEmpty;

    return Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBEF), Color(0xFFE9D9B4)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isSelected ? const Color(0xFFFFC94D) : accent,
            width: isSelected ? 3 : 1.6),
        boxShadow: [
          BoxShadow(
            color: isSelected ? const Color(0xAAFFC94D) : Colors.black54,
            blurRadius: isSelected ? 18 : 6,
            offset: Offset(0, isSelected ? -4 : 2),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.72,
        child: Column(
          children: [
            Container(
              height: 17,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              color: accent,
              child: Row(
                children: [
                  Expanded(
                    child: Text(info.category,
                        style: const TextStyle(
                            fontSize: 9.5,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                  ),
                  Text(card.suitSymbol,
                      style: TextStyle(color: isRed ? Colors.pinkAccent : Colors.white, fontSize: 11)),
                  Text(card.points,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                hasTransform ? card.asTransformed : card.name,
                maxLines: 1,
                style: TextStyle(
                  fontSize: (hasTransform ? card.asTransformed : card.name).length > 3 ? 16 : 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2B1B12),
                  height: 1.1,
                ),
              ),
            ),
            if (hasTransform)
              Text('（原：${card.name}）',
                  style: const TextStyle(fontSize: 8.5, color: Color(0xFF6D4C41))),
            const SizedBox(height: 3),
            Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: accent.withValues(alpha: 0.35)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 3, 6, 2),
                child: Text(
                  info.desc,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.5, height: 1.25, color: Color(0xFF4E342E)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 1),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('${card.index}',
                    style: TextStyle(fontSize: 8, color: accent.withValues(alpha: 0.6))),
              ),
            ),
          ],
        ),
      ),
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

        return Padding(
          padding: EdgeInsets.only(
              right: 6, top: isSelected ? 0 : 6, bottom: isSelected ? 8 : 0),
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
                  child: _buildCardFace(card, isSelected),
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
