import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import '../../models/hero_model.dart';
import 'hero_portrait.dart';

/// 经典《三国杀》风格的武将卡：
/// 左侧竖排状态条（势力 / 竖排武将名 / 竖向勾玉）+ 立绘 + 身份角标 + 手牌菱形角标 + 底部装备/座次条。
class TableSeatCard extends StatelessWidget {
  final Key? cardKey;
  final String id;
  final String name;
  final String hero;
  final int hp;
  final int maxHp;
  final int handCount;
  final String equips; // 逗号分隔的装备名（可为空项）
  final List<String> judges;
  final List<String> marks;
  final bool isMe;
  final bool isCurrentTurn;
  final String? currentPhaseName;
  final bool isSelectedAsTarget;
  final bool isTargetSelectionMode;
  final String role;
  final String roleLabel;
  final bool alive;
  final int distance;
  final int armor;
  final bool flipped;
  final int seatNo;
  final bool compact; // 紧凑模式（主视角右下角使用）
  final VoidCallback? onTap;
  final Function(CardModel droppedCard, String targetId)? onCardDropped;

  const TableSeatCard({
    super.key,
    this.cardKey,
    required this.id,
    required this.name,
    required this.hero,
    required this.hp,
    required this.maxHp,
    required this.handCount,
    required this.equips,
    required this.judges,
    required this.marks,
    required this.isMe,
    this.isCurrentTurn = false,
    this.currentPhaseName,
    this.isSelectedAsTarget = false,
    this.isTargetSelectionMode = false,
    this.role = "HIDDEN",
    this.roleLabel = "？",
    this.alive = true,
    this.distance = 1,
    this.armor = 0,
    this.flipped = false,
    this.seatNo = 1,
    this.compact = false,
    this.onTap,
    this.onCardDropped,
  });

  static const double w = 150;
  static const double cardH = 200;
  static const double bubbleH = 22;
  static const double h = cardH + bubbleH;

  static const List<String> _cnNums = ['一', '二', '三', '四', '五', '六', '七', '八'];

  Color _roleColor() {
    switch (role) {
      case "MAIN":
        return const Color(0xFFFFC94D);
      case "LOYAL":
        return const Color(0xFF79C7FF);
      case "REBEL":
        return const Color(0xFFFF6B6B);
      case "TRAITOR":
        return const Color(0xFFC08BFF);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _roleChar() {
    switch (role) {
      case "MAIN":
        return '主';
      case "LOYAL":
        return '忠';
      case "REBEL":
        return '反';
      case "TRAITOR":
        return '内';
      default:
        return roleLabel.length > 1 ? '？' : roleLabel;
    }
  }

  static String guessForce(String hero) {
    const shu = ['刘备', '关羽', '张飞', '赵云', '黄忠', '诸葛亮', '周处', '祝融', '孟获', '法正', '庞统'];
    const wei = [
      '曹操', '张辽', '甄姬', '田豫', '夏侯', '郭嘉', '荀彧', '曹仁', '于禁', '曹丕',
      '徐晃', '陈泰', '张郃', '曹洪', '曹爽', '钟会'
    ];
    const wu = ['孙权', '大乔', '小乔', '周瑜', '陆逊', '黄盖', '甘宁', '吕蒙', '孙策', '韩当', '朱然', '程普'];
    for (final n in shu) {
      if (hero.contains(n)) return '蜀';
    }
    for (final n in wei) {
      if (hero.contains(n)) return '魏';
    }
    for (final n in wu) {
      if (hero.contains(n)) return '吴';
    }
    return '群';
  }

  /// 竖向勾玉：颜色随血量比例变化
  Widget _hpDotsVertical() {
    final ratio = maxHp <= 0 ? 0.0 : hp / maxHp;
    final color = ratio > 0.6
        ? const Color(0xFF66BB6A)
        : (ratio > 0.3 ? const Color(0xFFFFCA28) : const Color(0xFFEF5350));
    final count = maxHp.clamp(1, 8);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final filled = i < hp;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.black.withValues(alpha: 0.55),
            border: Border.all(
                color: filled ? Colors.white70 : Colors.white24, width: 0.7),
            boxShadow: filled
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)]
                : null,
          ),
        );
      }),
    );
  }

  Widget _strip() {
    final force = guessForce(hero.replaceFirst('谋', ''));
    return Container(
      width: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HeroModel.forceColor(force).withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.75),
          ],
        ),
        border: const Border(right: BorderSide(color: Color(0x66FFC94D), width: 0.8)),
      ),
      child: Column(
        children: [
          // 势力标
          Container(
            width: 24,
            height: 22,
            color: HeroModel.forceColor(force),
            child: Center(
              child: Text(force,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 3),
          // 竖排武将名
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: hero
                  .split('')
                  .take(4)
                  .map((ch) => Text(ch,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.15)))
                  .toList(),
            ),
          ),
          // 竖向勾玉
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _hpDotsVertical(),
          ),
        ],
      ),
    );
  }

  Widget _equipLabel() {
    final list = equips.isEmpty ? <String>[] : equips.split(',');
    final weapon = list.isNotEmpty && list[0].trim().isNotEmpty && list[0] != '无' ? list[0] : null;
    final armorName =
        list.length > 1 && list[1].trim().isNotEmpty && list[1] != '无' ? list[1] : null;
    if (weapon == null && armorName == null) return const Text('— 无装备 —');
    final parts = <String>[];
    if (weapon != null) parts.add('⚔ $weapon');
    if (armorName != null) parts.add('🛡 $armorName');
    return Text(parts.join('  '), maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  @override
  Widget build(BuildContext context) {
    final isChained = marks.contains("铁索连环※");
    final displayMarks = marks
        .where((m) => m != "铁索连环※" && !m.startsWith('烈弓-'))
        .toList();
    final seatChar =
        seatNo >= 1 && seatNo <= _cnNums.length ? _cnNums[seatNo - 1] : '$seatNo';
    final cardWidth = compact ? 136.0 : w;
    // 紧凑模式需要给底部“思考中”提示留出空间，避免父级高度不足时溢出
    final cardHeight = compact ? 162.0 : cardH;

    final card = DragTarget<CardModel>(
      onWillAcceptWithDetails: (details) => !isMe && alive,
      onAcceptWithDetails: (details) {
        if (onCardDropped != null) onCardDropped!(details.data, id);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty && candidateData.first != null;
        final highlight = isHovered || isSelectedAsTarget;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            key: cardKey,
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: highlight
                    ? const Color(0xFFFF5252)
                    : (isCurrentTurn ? const Color(0xFFFFC94D) : const Color(0x66FFD9A0)),
                width: highlight ? 3 : (isCurrentTurn ? 2.5 : 1.2),
              ),
              boxShadow: [
                if (isCurrentTurn)
                  const BoxShadow(color: Color(0xAAFFB300), blurRadius: 18, spreadRadius: 2),
                BoxShadow(
                    color: highlight ? const Color(0x99FF5252) : Colors.black87,
                    blurRadius: highlight ? 16 : 8,
                    offset: const Offset(0, 3)),
              ],
              color: const Color(0xFF1A1410),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Row(
                  children: [
                    _strip(),
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          HeroPortrait(hero: hero),
                          // 底部渐变，压住名字
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 46,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.85)
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 4,
                            bottom: 22,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isMe ? const Color(0xFF7FE7FF) : Colors.white,
                                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 身份角标（右上）
                Positioned(
                  right: 3,
                  top: 3,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _roleColor().withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black45, width: 0.8),
                    ),
                    child: Center(
                      child: Text(_roleChar(),
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black87,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
                // 手牌数菱形（左下）
                Positioned(
                  left: 27,
                  bottom: 22,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xE6B8860B),
                        border: Border.all(color: const Color(0xFFFFE082), width: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: Center(
                          child: Text('$handCount',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ),
                // 状态角标
                if (distance > 1 && !isMe)
                  Positioned(
                    left: 27,
                    bottom: 46,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3)),
                      child: Text('距$distance',
                          style: const TextStyle(fontSize: 7.5, color: Colors.white70)),
                    ),
                  ),
                if (armor > 0)
                  Positioned(
                    left: 27,
                    bottom: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.lightBlueAccent, width: 0.7),
                      ),
                      child: Text('盾$armor',
                          style: const TextStyle(
                              fontSize: 7.5,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (isChained)
                  const Positioned(
                    right: 4,
                    top: 27,
                    child: Icon(Icons.link, size: 12, color: Color(0xFFFF7043)),
                  ),
                if (flipped)
                  Positioned(
                    right: 4,
                    top: 44,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A148C),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('背面',
                          style: TextStyle(fontSize: 7, color: Colors.white)),
                    ),
                  ),
                if (displayMarks.isNotEmpty)
                  Positioned(
                    left: 26,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xCC8D2F00),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(displayMarks.join(' '),
                          style: const TextStyle(fontSize: 7, color: Colors.white)),
                    ),
                  ),
                // 底部条：装备 + 座次
                Positioned(
                  left: 24,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.black.withValues(alpha: 0.72),
                    child: Row(
                      children: [
                        Expanded(
                          child: DefaultTextStyle(
                            style: const TextStyle(fontSize: 8, color: Colors.white70),
                            child: _equipLabel(),
                          ),
                        ),
                        Text(seatChar,
                            style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                // 判定区
                if (judges.isNotEmpty)
                  Positioned(
                    left: 26,
                    top: 22,
                    child: Row(
                      children: judges
                          .take(3)
                          .map((j) => Container(
                                margin: const EdgeInsets.only(right: 2),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xDD6A1B1B),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(color: Colors.deepOrangeAccent, width: 0.6),
                                ),
                                child: Text(j.length > 2 ? j.substring(0, 2) : j,
                                    style: const TextStyle(fontSize: 6.5, color: Colors.white)),
                              ))
                          .toList(),
                    ),
                  ),
                // 阵亡
                if (!alive)
                  Container(
                    color: Colors.black.withValues(alpha: 0.66),
                    child: const Center(
                      child: Text('阵 亡',
                          style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3)),
                    ),
                  ),
                // 选中/可选
                if (isSelectedAsTarget && alive)
                  const Positioned(
                      right: 3, bottom: 24, child: Icon(Icons.gps_fixed, size: 15, color: Color(0xFFFF5252))),
                if (!isMe && isTargetSelectionMode && !isSelectedAsTarget && alive)
                  Positioned(
                    right: 3,
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                          color: Colors.black87, borderRadius: BorderRadius.circular(2)),
                      child: const Text('可选',
                          style: TextStyle(fontSize: 6.5, color: Color(0xFFFFD54F))),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    return SizedBox(
      width: cardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          card,
          SizedBox(
            height: bubbleH,
            child: isCurrentTurn
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFB8860B), Color(0xFF6D4C00)]),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
                      ),
                      child: Text(
                        '${currentPhaseName ?? "行动"}思考中…',
                        style: const TextStyle(
                            fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
