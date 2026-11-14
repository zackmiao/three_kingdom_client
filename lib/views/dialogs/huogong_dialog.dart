import 'package:flutter/material.dart';
import '../../models/card_model.dart';

class HuoGongDialog {
  /// 展示手牌选择（用于火攻被目标选择展示）
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
          return AlertDialog(
            backgroundColor: const Color(0xFF2B2C34),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.deepOrangeAccent),
                SizedBox(width: 8),
                Text('【火攻】请选择一张手牌展示', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 320,
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: handCards.length,
                itemBuilder: (context, idx) {
                  final card = handCards[idx];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onSelect(card.index);
                    },
                    child: Container(
                      width: 85,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.deepOrange, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              '${card.suitSymbol} ${card.points}',
                              style: TextStyle(color: card.isRed ? Colors.redAccent : Colors.black87, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(card.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('点选展示', style: TextStyle(fontSize: 10, color: Colors.orange[900])),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    });
  }
}