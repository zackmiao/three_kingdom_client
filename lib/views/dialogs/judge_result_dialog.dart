import 'package:flutter/material.dart';
import '../components/card_face.dart';

/// 判定牌展示：不再只是"翻出一张牌"，而是把这张牌花色点数导致的后果一起说清楚。
/// 服务端 payload：玩家|锦囊名|判定牌描述|牌类型KEY|花色KEY|点数|判定含义
class JudgeResultDialog {
  static const Map<String, String> _suitSymbol = {
    'SPADE': '♠',
    'HEART': '♥',
    'CLUB': '♣',
    'DIAMOND': '♦',
  };

  static const Map<String, String> _suitName = {
    'SPADE': '黑桃',
    'HEART': '红桃',
    'CLUB': '草花',
    'DIAMOND': '方片',
  };

  static void show(BuildContext context, String rawData) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final parts = rawData.split('|');
      if (parts.length < 3) return;

      final pName = parts[0].trim();
      final trick = parts[1].trim();
      final cardLabel = parts[2].trim();
      final typeKey = parts.length > 3 ? parts[3].trim() : '';
      final suitKey = parts.length > 4 ? parts[4].trim() : '';
      final point = parts.length > 5 ? parts[5].trim() : '';
      final effect = parts.length > 6 ? parts[6].trim() : '';

      final isRed = suitKey == 'HEART' || suitKey == 'DIAMOND';
      final hasEffect = effect.isNotEmpty;
      // 「判定生效」= 这张牌让锦囊起效了（对玩家不利，用红色）；「判定失效」= 躲过了（绿色）
      final isHit = hasEffect && effect.contains('生效') && !effect.contains('失效');
      final accent = !hasEffect
          ? Colors.amberAccent
          : (isHit ? const Color(0xFFFF6B6B) : const Color(0xFF66BB6A));

      showDialog(
        context: context,
        builder: (ctx) {
          Future.delayed(const Duration(milliseconds: 2600), () {
            if (context.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          });
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 340,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF241B10), Color(0xFF120C07)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.6),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 22)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$pName 的【$trick】判定',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    builder: (_, v, child) => Transform.scale(
                      scale: 0.7 + 0.3 * v.clamp(0.0, 1.0),
                      child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                    ),
                    child: Column(
                      children: [
                        if (typeKey.isNotEmpty && CardFace.hasArt(typeKey))
                          CardFace(
                            typeKey: typeKey,
                            name: cardLabel,
                            suitSymbol: _suitSymbol[suitKey] ?? '',
                            points: point,
                            isRed: isRed,
                            index: 0,
                            showIndex: false,
                            width: 118,
                            height: 166,
                          )
                        else
                          Container(
                            width: 118,
                            height: 166,
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber, width: 2.5),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(cardLabel,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (suitKey.isNotEmpty)
                          Text(
                            '${_suitName[suitKey] ?? ''} ${point.isEmpty ? '' : point}',
                            style: TextStyle(
                                color: isRed ? const Color(0xFFFF8A80) : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (hasEffect)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accent.withValues(alpha: 0.6)),
                      ),
                      child: Text(effect,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: accent, fontSize: 12.5, fontWeight: FontWeight.bold)),
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
