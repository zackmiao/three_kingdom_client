import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import '../components/card_face.dart';

class PinDianDialog {
  static void show(
    BuildContext context,
    String prompt,
    List<CardModel> handCards,
    Function(int selectedIndex) onSelected,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 820),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF241B10), Color(0xFF120C07)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x99FFC94D), width: 1.6),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 22)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on, color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        prompt.isEmpty ? '【拼点】请选择一张手牌参与拼点' : prompt,
                        style: const TextStyle(
                            color: Color(0xFFFFC94D),
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('请挑选一张手牌参与拼点（点数大者胜）',
                    style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 176,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: handCards.map((card) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  onSelected(card.index);
                                },
                                child: CardFace(
                                  typeKey: card.typeKey,
                                  name: card.name,
                                  suitSymbol: card.suitSymbol,
                                  points: card.points,
                                  isRed: card.isRed,
                                  index: card.index,
                                  showIndex: false,
                                  width: 114,
                                  height: 160,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
