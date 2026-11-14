// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'card_face.dart';

/// 一张正在结算展示的牌
class PlayedCard {
  final String name;
  final String? typeKey;
  final String sourceName;
  final List<String> targetNames;
  final String? points;
  final String? suit;

  PlayedCard({
    required this.name,
    this.typeKey,
    required this.sourceName,
    this.targetNames = const [],
    this.points,
    this.suit,
  });
}

/// 中央结算区：横向排开的牌流（可同时展示多张，如【杀】与响应的【闪】），
/// 牌下方压印「来源 对 目标」水印。
class CenterStageView extends StatelessWidget {
  final List<PlayedCard> cards;

  const CenterStageView({super.key, required this.cards});

  static const double cardW = 104;
  static const double cardH = 146;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return SizedBox(
        width: 190,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x33FFB300), Colors.transparent]),
              ),
            ),
            const Text('三 国 杀',
                style: TextStyle(
                    color: Color(0x33FFE0B2),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6)),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < cards.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
            child: _CardWithWatermark(card: cards[i], index: i),
          ),
      ],
    );
  }
}

class _CardWithWatermark extends StatelessWidget {
  final PlayedCard card;
  final int index;

  const _CardWithWatermark({required this.card, required this.index});

  @override
  Widget build(BuildContext context) {
    final isRed = card.suit == 'HEART' || card.suit == 'DIAMOND';

    return TweenAnimationBuilder<double>(
      key: ValueKey('${card.name}-${card.sourceName}-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: 0.6 + 0.4 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 使用官方牌面
          CardFace(
            typeKey: card.typeKey ?? '',
            name: card.name,
            suitSymbol: isRed ? '♥' : '♠',
            points: card.points ?? '',
            isRed: isRed,
            index: 0,
            width: CenterStageView.cardW,
            height: CenterStageView.cardH,
            showIndex: false,
            showCorner: card.points != null,
          ),
          // 水印：来源 对 目标
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0x66FFC107), width: 0.8),
            ),
            child: Text(
              card.targetNames.isEmpty
                  ? card.sourceName
                  : '${card.sourceName} 对 ${card.targetNames.join("、")}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFFFFE082), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
