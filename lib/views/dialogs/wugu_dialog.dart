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

  static void show(BuildContext context, String rawPool, Function(String) onPick) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final items = rawPool.split(';');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final n = items.length;
          // 牌阵宽度随张数放大，最多一行 5 张
          final perRow = n <= 5 ? n : 5;
          final width = (perRow * 128 + 60).clamp(360, 720).toDouble();
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
                  const Text('点击牌面即可收入手牌',
                      style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: items.map((it) {
                      final seg = it.split('|');
                      final head = seg[0];
                      if (!head.contains('=')) return const SizedBox();
                      final eq = head.indexOf('=');
                      final idx = head.substring(0, eq).trim();
                      final desc = head.substring(eq + 1).trim();
                      final typeKey = seg.length > 1 ? seg[1].trim() : '';
                      final suitKey = seg.length > 2 ? seg[2].trim() : '';
                      final point = seg.length > 3 ? seg[3].trim() : '';
                      final isRed = suitKey == 'HEART' || suitKey == 'DIAMOND';
                      final hasArt = typeKey.isNotEmpty && CardFace.hasArt(typeKey);

                      return _WuGuCard(
                        typeKey: hasArt ? typeKey : null,
                        desc: desc,
                        suitSymbol: _suitSymbol[suitKey] ?? '',
                        points: point,
                        isRed: isRed,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onPick(idx);
                        },
                      );
                    }).toList(),
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

class _WuGuCard extends StatefulWidget {
  final String? typeKey;
  final String desc;
  final String suitSymbol;
  final String points;
  final bool isRed;
  final VoidCallback onTap;

  const _WuGuCard({
    required this.typeKey,
    required this.desc,
    required this.suitSymbol,
    required this.points,
    required this.isRed,
    required this.onTap,
  });

  @override
  State<_WuGuCard> createState() => _WuGuCardState();
}

class _WuGuCardState extends State<_WuGuCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.typeKey != null
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _hover ? const Color(0x99FFC94D) : Colors.black45,
                    blurRadius: _hover ? 16 : 8,
                  ),
                ],
              ),
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}
