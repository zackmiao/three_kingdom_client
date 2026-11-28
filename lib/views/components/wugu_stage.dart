import 'package:flutter/material.dart';

import '../../models/card_model.dart';
import 'card_face.dart';

/// 【五谷丰登】公共牌池里的一张明牌。
///
/// - [idx] 为服务端池内索引，仅在「轮到我选牌」时有值（回传 `RESPOND_CARD` 用）。
/// - [owner] 非空表示这张牌已经被该角色拿走，展台上置灰盖章。
class WuGuSlot {
  final int? idx;
  final String desc;
  final String typeKey;
  final String suitKey;
  final String point;
  final String? owner;

  const WuGuSlot({
    this.idx,
    required this.desc,
    required this.typeKey,
    required this.suitKey,
    required this.point,
    this.owner,
  });

  bool get taken => owner != null;

  /// 同一张牌的稳定指纹：用于在多轮下发之间把「被拿走的牌」对上原来那一格。
  String get signature => '$desc|$typeKey|$suitKey|$point';

  WuGuSlot copyWith({int? idx, String? owner, bool clearIdx = false}) {
    return WuGuSlot(
      idx: clearIdx ? null : (idx ?? this.idx),
      desc: desc,
      typeKey: typeKey,
      suitKey: suitKey,
      point: point,
      owner: owner ?? this.owner,
    );
  }

  static String suitSymbol(String suitKey) {
    switch (suitKey) {
      case 'SPADE':
        return '♠';
      case 'HEART':
        return '♥';
      case 'CLUB':
        return '♣';
      case 'DIAMOND':
        return '♦';
      default:
        return '';
    }
  }

  bool get isRed => suitKey == 'HEART' || suitKey == 'DIAMOND';

  CardModel toCardModel() {
    return CardModel(
      index: idx ?? 0,
      typeKey: typeKey,
      suitKey: suitKey,
      points: point,
      cardId: -1,
      name: desc,
    );
  }
}

/// 全员共享的五谷丰登选牌台（半透明浮层）。
class WuGuStage extends StatelessWidget {
  const WuGuStage({
    super.key,
    required this.slots,
    required this.statusText,
    required this.canPick,
    required this.slotKeys,
    this.onPick,
  });

  final List<WuGuSlot> slots;
  final String statusText;
  final bool canPick;
  final Map<String, GlobalKey> slotKeys;
  final void Function(WuGuSlot slot)? onPick;

  @override
  Widget build(BuildContext context) {
    final available = slots.where((s) => !s.taken).length;
    final takenCount = slots.length - available;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF2140F08), Color(0xF2261B0E)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canPick ? const Color(0xFFFFD54F) : const Color(0x66C9A227),
          width: canPick ? 2.4 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: canPick
                ? const Color(0x66FFD54F)
                : const Color(0x44000000),
            blurRadius: canPick ? 34 : 18,
            spreadRadius: canPick ? 4 : 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌾', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                '五谷丰登',
                style: TextStyle(
                  color: Color(0xFFFFE0A3),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '剩余 $available 张 · 已被选走 $takenCount 张',
                style: const TextStyle(color: Color(0x99FFE0A3), fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: canPick ? const Color(0x33FFD54F) : const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: canPick ? const Color(0x88FFD54F) : const Color(0x22FFFFFF),
              ),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: canPick ? const Color(0xFFFFE082) : const Color(0xCCFFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final slot in slots) _slotView(slot),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotView(WuGuSlot slot) {
    final key = slotKeys[slot.signature] ?? GlobalKey();
    final clickable = canPick && !slot.taken;
    final card = SizedBox(
      width: 96,
      height: CardFace.heightFor(96),
      child: CardFace(
        typeKey: slot.typeKey,
        name: slot.desc,
        suitSymbol: WuGuSlot.suitSymbol(slot.suitKey),
        points: slot.point,
        isRed: slot.isRed,
        index: slot.idx ?? 0,
        showIndex: false,
        width: 96,
      ),
    );
    return KeyedSubtree(
      key: key,
      child: GestureDetector(
        key: ValueKey('wugu-slot-${slot.signature}'),
        onTap: clickable ? () => onPick?.call(slot) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: slot.taken ? 0.42 : 1,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: clickable
                    ? const Color(0xFFFFD54F)
                    : (slot.taken ? const Color(0x33FFFFFF) : Colors.transparent),
                width: clickable ? 2.2 : 1,
              ),
              boxShadow: clickable
                  ? [
                      const BoxShadow(
                        color: Color(0x66FFC107),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ColorFiltered(
                  colorFilter: slot.taken
                      ? const ColorFilter.matrix(<double>[
                          0.36, 0.36, 0.36, 0, 0,
                          0.36, 0.36, 0.36, 0, 0,
                          0.36, 0.36, 0.36, 0, 0,
                          0, 0, 0, 1, 0,
                        ])
                      : const ColorFilter.matrix(<double>[
                          1, 0, 0, 0, 0,
                          0, 1, 0, 0, 0,
                          0, 0, 1, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                  child: card,
                ),
                if (slot.taken)
                  Positioned.fill(
                    child: Center(
                      child: Transform.rotate(
                        angle: -0.16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC8D1B1B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: Text(
                            '${slot.owner} 已选',
                            style: const TextStyle(
                              color: Color(0xFFFFEBEE),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
