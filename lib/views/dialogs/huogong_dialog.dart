import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import '../components/card_face.dart';

/// 火攻的两步界面：
/// 1. 【火攻展示】被火攻的一方挑一张手牌展示（或自己展示给别人看）
/// 2. 【火攻】使用者左边看展示牌、右边挑一张同花色的手牌弃置；没有同花色就一行小字说明落空
class HuoGongDialog {
  static const Color _amber = Color(0xFFFFB74D);
  static const Color _panel = Color(0xFF1B120C);

  static Widget _frame({required Widget child, double maxWidth = 900}) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
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
        child: child,
      ),
    );
  }

  static Widget _title(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department, color: Colors.deepOrangeAccent, size: 20),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: _amber, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// 第一步：选择一张手牌展示
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
          return _frame(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _title('【火攻】请选择一张手牌展示'),
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
                        child: _HoverCard(
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
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  /// 第二步：左边是展示的牌，右边挑同花色弃置
  static void showDiscardSameSuit(
    BuildContext context, {
    required String shownTypeKey,
    required String shownSuitKey,
    required String shownPoint,
    required String shownName,
    required List<CardModel> handCards,
    required Function(int) onSelect,
    required VoidCallback onGiveUp,
  }) {
    final suitName = switch (shownSuitKey) {
      'SPADE' => '黑桃',
      'HEART' => '红桃',
      'CLUB' => '草花',
      'DIAMOND' => '方片',
      _ => '同花色',
    };
    final suitSymbol = switch (shownSuitKey) {
      'SPADE' => '♠',
      'HEART' => '♥',
      'CLUB' => '♣',
      'DIAMOND' => '♦',
      _ => '',
    };
    final candidates =
        handCards.where((c) => c.suitKey == shownSuitKey).toList(growable: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return _frame(
            maxWidth: 980,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _title('【火攻】弃置一张【$suitName】手牌即可造成 1 点火焰伤害'),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 左：被火攻者展示出来的那张牌
                    Column(
                      children: [
                        const Text('展示的牌',
                            style: TextStyle(fontSize: 12, color: Colors.white60)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _panel,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x66FF7043)),
                          ),
                          child: CardFace(
                            typeKey: shownTypeKey,
                            name: shownName,
                            suitSymbol: suitSymbol,
                            points: shownPoint,
                            isRed: shownSuitKey == 'HEART' || shownSuitKey == 'DIAMOND',
                            index: 0,
                            showIndex: false,
                            width: 128,
                            height: 180,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 22),
                    // 右：自己手里同花色的牌
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidates.isEmpty
                              ? '你的牌'
                              : '选一张【$suitName】弃置（${candidates.length} 张可用）',
                          style: TextStyle(
                              fontSize: 12,
                              color: candidates.isEmpty ? Colors.white38 : Colors.white60),
                        ),
                        const SizedBox(height: 6),
                        if (candidates.isEmpty)
                          Container(
                            width: 420,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
                            decoration: BoxDecoration(
                              color: _panel,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('你没有【$suitName】的牌',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white54,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                const Text('火攻发动失效，这张牌不会造成伤害。',
                                    style:
                                        TextStyle(fontSize: 11, color: Colors.white30)),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 190,
                            width: 430,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: candidates.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (_, i) {
                                final c = candidates[i];
                                return _HoverCard(
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    onSelect(c.index);
                                  },
                                  child: CardFace(
                                    typeKey: c.typeKey,
                                    name: c.name,
                                    suitSymbol: c.suitSymbol,
                                    points: c.points,
                                    isRed: c.isRed,
                                    index: c.index,
                                    showIndex: false,
                                    width: 120,
                                    height: 168,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onGiveUp();
                      },
                      child: Text(
                          candidates.isEmpty ? '放弃（火攻落空）' : '不弃置，放弃加伤',
                          style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

/// 悬停时抬起来一点的牌，增强「牌」的手感
class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HoverCard({required this.child, required this.onTap});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: Offset(0, _hover ? -0.045 : 0),
          duration: const Duration(milliseconds: 140),
          child: AnimatedScale(
            scale: _hover ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
