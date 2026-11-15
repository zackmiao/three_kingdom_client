import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import '../components/card_face.dart';

class HuoGongDialog {
  /// 展示手牌选择（用于火攻被目标选择展示）—— 直接铺真实牌面
  static void showSelectCardToExpose(
    BuildContext context,
    List<CardModel> handCards,
    Function(int) onSelect,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 760),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A1710), Color(0xFF120C07)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x99FF7043), width: 1.6),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 22)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          color: Colors.deepOrangeAccent, size: 20),
                      SizedBox(width: 6),
                      Text('【火攻】请选择一张手牌展示',
                          style: TextStyle(
                              color: Color(0xFFFFB74D),
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 172,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: handCards.length,
                      itemBuilder: (context, idx) {
                        final card = handCards[idx];
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                onSelect(card.index);
                              },
                              child: CardFace(
                                typeKey: card.typeKey,
                                name: card.name,
                                suitSymbol: card.suitSymbol,
                                points: card.points,
                                isRed: card.isRed,
                                index: card.index,
                                showIndex: false,
                                width: 112,
                                height: 158,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
