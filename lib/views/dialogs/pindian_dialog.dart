import 'package:flutter/material.dart';
import '../../models/card_model.dart';

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
        return AlertDialog(
          backgroundColor: const Color(0xFF262732),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.amberAccent, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prompt.isEmpty ? '【拼点】请选择一张手牌参与拼点' : prompt,
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('请挑选一张手牌参与拼点（点数大者胜）：', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                // 关键修复：加入水平滚动条并优化单张卡牌尺寸，保证 5~10+ 张手牌完整显示
                SizedBox(
                  height: 145,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: handCards.map((card) {
                          bool isRed = card.suitKey == 'HEART' ||
                              card.suitKey == 'DIAMOND' ||
                              card.suitKey == '红桃' ||
                              card.suitKey == '方片';
                          Color themeColor = isRed ? Colors.redAccent : Colors.black87;

                          return GestureDetector(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              onSelected(card.index);
                            },
                            child: Container(
                              width: 95,
                              height: 135,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amberAccent, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 3))
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 6,
                                    left: 8,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card.suitSymbol,
                                          style: TextStyle(color: themeColor, fontSize: 13, height: 1.0),
                                        ),
                                        Text(
                                          card.points,
                                          style: TextStyle(
                                            color: themeColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Text(
                                        card.name,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.brown[900],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 6,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Text(
                                        '点数: ${card.pointValue}',
                                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                                      ),
                                    ),
                                  ),
                                ],
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