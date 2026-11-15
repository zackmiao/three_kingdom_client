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

  static const double cardW = 128;
  static const double cardH = 180;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return SizedBox(
        width: 230,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x33FFB300), Colors.transparent]),
              ),
            ),
            const Text('三 国 杀',
                style: TextStyle(
                    color: Color(0x33FFE0B2),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 7)),
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
            padding: EdgeInsets.only(left: i == 0 ? 0 : 14),
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0xAA000000), blurRadius: 18, offset: Offset(0, 6)),
                BoxShadow(color: Color(0x33FFC107), blurRadius: 26, spreadRadius: 1),
              ],
            ),
            child: CardFace(
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
          ),
          // 水印：来源 对 目标
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x88FFC107), width: 1),
            ),
            child: Text(
              card.targetNames.isEmpty
                  ? card.sourceName
                  : '${card.sourceName} 对 ${card.targetNames.join("、")}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFFFFE082), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
