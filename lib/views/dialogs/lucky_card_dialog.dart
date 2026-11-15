import 'package:flutter/material.dart';

import '../../models/card_model.dart';
import '../components/card_face.dart';

/// 手气卡弹窗：开局阶段展示当前起手牌，最多可换 4 次。
///
/// 返回 "1" = 换一副新起手牌，"0" = 确定开局。
class LuckyCardDialog extends StatefulWidget {
  final int remaining;
  final List<CardModel> hand;

  const LuckyCardDialog({super.key, required this.remaining, required this.hand});

  static Future<String?> show(
    BuildContext context, {
    required int remaining,
    required List<CardModel> hand,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LuckyCardDialog(remaining: remaining, hand: hand),
    );
  }

  @override
  State<LuckyCardDialog> createState() => _LuckyCardDialogState();
}

class _LuckyCardDialogState extends State<LuckyCardDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 720,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1C24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.45)),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 22)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 24),
                const SizedBox(width: 9),
                const Text('手气卡',
                    style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber[800]!.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('剩余 ${widget.remaining} 次',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const Spacer(),
                Text('现在的起手牌（${widget.hand.length} 张）',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('不满意可以换一副新的起手牌，换牌会把这手牌全部洗回牌堆。',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in widget.hand)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: CardFace(
                            typeKey: c.typeKey,
                            name: c.name,
                            suitSymbol: c.suitSymbol,
                            points: c.points,
                            isRed: c.isRed,
                            index: c.index,
                            showIndex: false,
                            width: 104,
                            height: 148,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.remaining > 0
                        ? () => Navigator.of(context).pop('1')
                        : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.cyanAccent),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.cyanAccent, size: 18),
                    label: Text(widget.remaining > 0 ? '换一副起手牌' : '已用完',
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop('0'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.check, color: Colors.white, size: 18),
                    label: const Text('就用这手牌，开始对局',
                        style: TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
