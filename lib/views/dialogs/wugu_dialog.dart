import 'package:flutter/material.dart';
import '../components/card_face.dart';

/// 【五谷丰登】选牌：用真实牌面（CardFace）铺成牌阵，而不是绘制的老版卡牌。
/// 服务端 payload：`idx=描述|牌类型KEY|花色KEY|点数;...`
class WuGuDialog {
  static const Map<String, String> _suitSymbol = {
    'SPADE': '♠',
    'HEART': '♥',
    'CLUB': '♣',
    'DIAMOND': '♦',
  };

  /// 服务端 payload：未被选走的牌是 `idx=描述|typeKey|suitKey|point`，
  /// 已被别人选走的牌是 `t|玩家名|描述|typeKey|suitKey|point`
  /// （能看到别人选了什么，只是不能再选）
  static void show(BuildContext context, String rawPool, Function(String) onPick) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final items = rawPool
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final taken = <_WuGuTaken>[];
      final pool = <String>[];
      for (final it in items) {
        if (it.startsWith('t|')) {
          final seg = it.split('|');
          taken.add(_WuGuTaken(
            owner: seg.length > 1 ? seg[1].trim() : '',
            desc: seg.length > 2 ? seg[2].trim() : '',
            typeKey: seg.length > 3 ? seg[3].trim() : '',
            suitKey: seg.length > 4 ? seg[4].trim() : '',
            point: seg.length > 5 ? seg[5].trim() : '',
          ));
        } else {
          pool.add(it);
        }
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final n = pool.length;
          // 牌阵宽度随张数放大，最多一行 5 张
          final perRow = n <= 5 ? n : 5;
          final total = perRow + taken.length;
          final width = (total * 108 + 80).clamp(380, 900).toDouble();

          void pick(String idx) {
            Navigator.of(ctx).pop();
            onPick(idx);
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: width.toDouble(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF241B10), Color(0xFF120C07)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x99FFC94D), width: 1.6),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 24)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('【五谷丰登】请挑选一张牌',
                      style: TextStyle(
                          color: Color(0xFFFFC94D),
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                      '还剩 ${pool.length} 张可选 · 已被选走 ${taken.length} 张（灰掉的不能再选）',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10.5)),
                  if (taken.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                        '已被选走：${taken.map((t) => '${t.owner.isEmpty ? '他人' : t.owner}→${t.desc}').join('、')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF9E8B5A), fontSize: 10)),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      // 已经被别人选走的牌：按下去 + 变灰 + 「谁 已选」
                      for (final t in taken)
                        _WuGuCard(
                          typeKey: CardFace.hasArt(t.typeKey) ? t.typeKey : null,
                          desc: t.desc,
                          suitSymbol: _suitSymbol[t.suitKey] ?? '',
                          points: t.point,
                          isRed: t.suitKey == 'HEART' || t.suitKey == 'DIAMOND',
                          taken: true,
                          takenLabel: t.owner.isEmpty ? '已选' : '${t.owner} 已选',
                          onTap: () {},
                        ),
                      for (final it in pool)
                        Builder(builder: (_) {
                          final seg = it.split('|');
                          final head = seg[0];
                          if (!head.contains('=')) return const SizedBox();
                          final eq = head.indexOf('=');
                          final idx = head.substring(0, eq).trim();
                          final desc = head.substring(eq + 1).trim();
                          final typeKey = seg.length > 1 ? seg[1].trim() : '';
                          final suitKey = seg.length > 2 ? seg[2].trim() : '';
                          final point = seg.length > 3 ? seg[3].trim() : '';

                          return _WuGuCard(
                            typeKey: CardFace.hasArt(typeKey) ? typeKey : null,
                            desc: desc,
                            suitSymbol: _suitSymbol[suitKey] ?? '',
                            points: point,
                            isRed: suitKey == 'HEART' || suitKey == 'DIAMOND',
                            selectedLabel: '选择',
                            onTap: () => pick(idx),
                          );
                        }),
                    ],
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

class _WuGuTaken {
  final String owner;
  final String desc;
  final String typeKey;
  final String suitKey;
  final String point;

  const _WuGuTaken({
    required this.owner,
    required this.desc,
    required this.typeKey,
    required this.suitKey,
    required this.point,
  });
}

class _WuGuCard extends StatefulWidget {
  final String? typeKey;
  final String desc;
  final String suitSymbol;
  final String points;
  final bool isRed;
  /// 已经被选走（按下、灰掉、不可点）
  final bool taken;
  /// 已被选走时显示的角标文案（「谋曹操 已选」）
  final String takenLabel;
  /// 右下角的操作标签（「选择」）
  final String? selectedLabel;
  final VoidCallback onTap;

  const _WuGuCard({
    required this.typeKey,
    required this.desc,
    required this.suitSymbol,
    required this.points,
    required this.isRed,
    required this.onTap,
    this.taken = false,
    this.takenLabel = '已选',
    this.selectedLabel,
  });

  @override
  State<_WuGuCard> createState() => _WuGuCardState();
}

class _WuGuCardState extends State<_WuGuCard> {
  bool _hover = false;

  Widget _buildFace() {
    return widget.typeKey != null
        ? CardFace(
            typeKey: widget.typeKey!,
            name: widget.desc,
            suitSymbol: widget.suitSymbol,
            points: widget.points,
            isRed: widget.isRed,
            index: 0,
            showIndex: false,
            width: 116,
            height: 163,
          )
        : Container(
            width: 116,
            height: 163,
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(widget.desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5)),
              ),
            ),
          );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.7)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, color: fg, fontWeight: FontWeight.bold, height: 1.2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 已经被选走的牌：整体按下 6px + 灰度 + 变暗 + 「已选」角标，不可再点
    if (widget.taken) {
      return Transform.translate(
        offset: const Offset(0, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.38,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.35, 0.35, 0.35, 0, 0,
                  0.35, 0.35, 0.35, 0, 0,
                  0.35, 0.35, 0.35, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: _buildFace(),
              ),
            ),
            const SizedBox(height: 4),
            _badge(widget.takenLabel, const Color(0x33FFFFFF), Colors.white38),
          ],
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: Offset(0, _hover ? -0.05 : 0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: _hover ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: _hover ? const Color(0x99FFC94D) : Colors.black45,
                        blurRadius: _hover ? 16 : 8,
                      ),
                    ],
                  ),
                  child: _buildFace(),
                ),
                const SizedBox(height: 4),
                if (widget.selectedLabel != null)
                  _badge(widget.selectedLabel!,
                      _hover ? const Color(0xFFFFC94D) : const Color(0x33FFC94D),
                      _hover ? Colors.black87 : const Color(0xFFFFC94D))
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
