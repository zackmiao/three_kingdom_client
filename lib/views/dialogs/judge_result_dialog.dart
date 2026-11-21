import 'package:flutter/material.dart';
import '../components/card_face.dart';

/// 判定牌展示：不再只是"翻出一张牌"，而是把这张牌花色点数导致的后果一起说清楚。
/// 服务端 payload：玩家|锦囊名|判定牌描述|牌类型KEY|花色KEY|点数|判定含义
///
/// 展示节奏（与线上版体感对齐）：
///   0.0s  展台先亮出「正在判定【乐不思蜀】…」
///   1.2s  牌堆顶的判定牌飞入展台放大展示（带翻牌动画）
///   2.4s  结算印章 / 后果说明逐字浮出
///   3.8s  自动关闭
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

  static const Duration _revealDelay = Duration(milliseconds: 1200);
  static const Duration _dismissDelay = Duration(milliseconds: 3800);

  static void show(BuildContext context, String rawData) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final parts = rawData.split('|');
      if (parts.length < 3) return;

      showDialog(
        context: context,
        builder: (ctx) {
          Future.delayed(_dismissDelay, () {
            if (context.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          });
          return Dialog(
            backgroundColor: Colors.transparent,
            child: _JudgeBody(
              playerName: parts[0].trim(),
              trick: parts[1].trim(),
              cardLabel: parts[2].trim(),
              typeKey: parts.length > 3 ? parts[3].trim() : '',
              suitKey: parts.length > 4 ? parts[4].trim() : '',
              point: parts.length > 5 ? parts[5].trim() : '',
              effect: parts.length > 6 ? parts[6].trim() : '',
            ),
          );
        },
      );
    });
  }
}

class _JudgeBody extends StatefulWidget {
  final String playerName;
  final String trick;
  final String cardLabel;
  final String typeKey;
  final String suitKey;
  final String point;
  final String effect;

  const _JudgeBody({
    required this.playerName,
    required this.trick,
    required this.cardLabel,
    required this.typeKey,
    required this.suitKey,
    required this.point,
    required this.effect,
  });

  @override
  State<_JudgeBody> createState() => _JudgeBodyState();
}

class _JudgeBodyState extends State<_JudgeBody> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(JudgeResultDialog._revealDelay, () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final suitKey = widget.suitKey;
    final isRed = suitKey == 'HEART' || suitKey == 'DIAMOND';
    final hasEffect = widget.effect.isNotEmpty;
    // 「判定生效」= 这张牌让锦囊起效了（对玩家不利，用红色）；「判定失效」= 躲过了（绿色）
    final isHit = hasEffect &&
        widget.effect.contains('生效') &&
        !widget.effect.contains('失效');
    final accent = !hasEffect
        ? Colors.amberAccent
        : (isHit ? const Color(0xFFFF6B6B) : const Color(0xFF66BB6A));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
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
          Text(
            widget.playerName,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            _revealed ? '【${widget.trick}】判定结果' : '正在判定【${widget.trick}】…',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (!_revealed)
            const _Judging()
          else
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
                  if (widget.typeKey.isNotEmpty &&
                      CardFace.hasArt(widget.typeKey))
                    CardFace(
                      typeKey: widget.typeKey,
                      name: widget.cardLabel,
                      suitSymbol:
                          JudgeResultDialog._suitSymbol[suitKey] ?? '',
                      points: widget.point,
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
                          child: Text(widget.cardLabel,
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
                      '${JudgeResultDialog._suitName[suitKey] ?? ''} ${widget.point}',
                      style: TextStyle(
                          color:
                              isRed ? const Color(0xFFFF8A80) : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_revealed && hasEffect)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.6)),
              ),
              child: Text(widget.effect,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

/// 判定中的转场：牌堆呼吸 + 「牌堆翻牌中」
class _Judging extends StatelessWidget {
  const _Judging();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 166,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.08),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 96,
              height: 135,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5D2222), Color(0xFF2A1010)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x99FFC107), width: 1.6),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x66FFC107), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: const Center(
                child: Text('三',
                    style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 34,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('牌堆翻牌中…',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
