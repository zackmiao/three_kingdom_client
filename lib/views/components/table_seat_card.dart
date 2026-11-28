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

  /// 目标在攻击范围之外（选中【杀】时置灰并标注「距离不足」）
  final bool isOutOfRange;

  /// 刚刚受到伤害：武将卡边框与光晕短暂闪红
  final bool isHitFlash;

  /// 濒死求桃中（头像压灰 + 红字警示）
  final bool isDying;

  /// 正在等待该角色响应（出闪/出杀/无懈）：呼吸脉冲边框 + 「思考响应中…」气泡
  final bool isWaitingResponse;

  final String role;
  final String roleLabel;
  final bool alive;
  final int distance;
  final int armor;
  final bool flipped;
  final int seatNo;
  final bool compact; // 紧凑模式（主视角右下角使用）
  /// 酒加成（>0 时武将牌泛血色红光，表示下一张【杀】伤害 +N）
  final int wineBonus;
  /// 当前势力（WEI/QUN/SHU/WU/SHEN）：优先于按武将名猜测，支持【篡权】实时变身。
  final String faction;
  /// 护盾值（先于护甲承伤），显示在体力勾玉上方。
  /// 武将牌上扣置的牌数量（【弑龙】【成务】），左上角显示「扣:N」。
  final int exileCount;
  /// 玩家选中一张需要指定目标的牌时：该角色是合法目标 → 头顶显示「跳动宝剑」提示
  final bool showTargetSword;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
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
    this.isOutOfRange = false,
    this.isHitFlash = false,
    this.isDying = false,
    this.isWaitingResponse = false,
    this.role = "HIDDEN",
    this.roleLabel = "？",
    this.alive = true,
    this.distance = 1,
    this.armor = 0,
    this.flipped = false,
    this.seatNo = 1,
    this.compact = false,
    this.wineBonus = 0,
    this.faction = "",
    this.exileCount = 0,
    this.showTargetSword = false,
    this.onTap,
    this.onLongPress,
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
      case "WARM":
      case "LORD":
        return const Color(0xFFFFC94D);
      case "LOYAL":
      case "COLD":
      case "FARMER":
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
      case "WARM":
        return '暖';
      case "COLD":
        return '冷';
      case "LORD":
        return '地';
      case "FARMER":
        return '农';
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

  /// 势力中文（服务端下发 WEI / QUN / SHU / WU / SHEN）
  static String factionCn(String f) {
    switch (f.toUpperCase()) {
      case 'WEI':
        return '魏';
      case 'SHU':
        return '蜀';
      case 'WU':
        return '吴';
      case 'QUN':
        return '群';
      case 'SHEN':
        return '神';
      default:
        return f.isEmpty ? '' : f;
    }
  }

  /// 势力配色：魏蓝 / 群灰金（【篡权】变身）/ 蜀红 / 吴绿 / 神紫
  static Color factionColor(String f) {
    switch (f.toUpperCase()) {
      case 'WEI':
        return const Color(0xFF3D6DB5);
      case 'SHU':
        return const Color(0xFFC0392B);
      case 'WU':
        return const Color(0xFF2E8B57);
      case 'QUN':
        return const Color(0xFF9E8B5A);
      case 'SHEN':
        return const Color(0xFF7E57C2);
      default:
        return const Color(0xFF6D6D6D);
    }
  }

  /// 竖向勾玉：颜色随血量比例变化
  Widget _hpDotsVertical(double k) {
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
          width: 8 * k,
          height: 8 * k,
          margin: EdgeInsets.symmetric(vertical: 1 * k),
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

  /// 护甲徽章：显示在左侧体力勾玉的**上方**
  Widget _armorBadge(double k) {
    return Container(
      width: 20 * k,
      margin: EdgeInsets.only(bottom: 3 * k),
      padding: EdgeInsets.symmetric(vertical: 1 * k),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(4 * k),
        border: Border.all(color: Colors.lightBlueAccent, width: 0.8),
        boxShadow: [
          BoxShadow(
              color: Colors.lightBlueAccent.withValues(alpha: 0.55),
              blurRadius: 5 * k),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🛡', style: TextStyle(fontSize: 7.5 * k, height: 1.1)),
          Text('$armor',
              style: TextStyle(
                  fontSize: 9 * k,
                  height: 1.0,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  /// 花色符号（烈弓记录花色等标记展示用）
  static String _suitGlyph(String key) {
    switch (key.toUpperCase()) {
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
  Widget _strip(double k) {
    final force = faction.isNotEmpty
        ? factionCn(faction)
        : guessForce(hero.replaceFirst('谋', ''));
    final forceColor =
        faction.isNotEmpty ? factionColor(faction) : HeroModel.forceColor(force);
    return Container(
      width: 24 * k,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            forceColor.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.75),
          ],
        ),
        border: const Border(right: BorderSide(color: Color(0x66FFC94D), width: 0.8)),
      ),
      child: Column(
        children: [
          // 势力标
          Container(
            width: 24 * k,
            height: 22 * k,
            color: forceColor,
            child: Center(
              child: Text(force,
                  style: TextStyle(
                      fontSize: 12 * k,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: 3 * k),
          // 竖排武将名
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: hero
                  .split('')
                  .take(4)
                  .map((ch) => Text(ch,
                      style: TextStyle(
                          fontSize: 11 * k,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.15)))
                  .toList(),
            ),
          ),
          // 竖向勾玉（护甲显示在体力上方）
          Padding(
            padding: EdgeInsets.only(bottom: 4 * k),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (armor > 0) _armorBadge(k),
                _hpDotsVertical(k),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 统一解析装备栏：
  /// 服务端对手下发 `WEAPON:青釭剑,ARMOR:八卦阵,DEFENSIVE_HORSE:的卢`，
  /// 自己的席位卡传的是 `武器名,防具名,+1马,-1马` 的裸名字。
  List<String> _equipSlots() {
    final out = List<String>.filled(4, '');
    if (equips.trim().isEmpty) return out;
    var sequential = 0;
    for (final raw in equips.split(',')) {
      final p = raw.trim();
      if (p.isEmpty || p == '无') continue;
      final colon = p.indexOf(':');
      if (colon > 0) {
        final slot = p.substring(0, colon).trim().toUpperCase();
        final value = p.substring(colon + 1).trim();
        if (value.isEmpty || value == '无') continue;
        final idx = switch (slot) {
          'WEAPON' => 0,
          'ARMOR' => 1,
          'DEFENSIVE_HORSE' => 2,
          'OFFENSIVE_HORSE' => 3,
          _ => -1,
        };
        if (idx >= 0) out[idx] = value;
      } else {
        if (sequential < 4) out[sequential] = p;
        sequential++;
      }
    }
    return out;
  }

  /// 标记徽章：社=金色、弑=赤红、颂=紫、酒=暗红、烈弓=青，其余沿用棕色
  Widget _markChip(String label, double k) {
    String text = label;
    late Color bg;
    late Color border;
    if (label.startsWith('社')) {
      final n = label.contains('*') ? label.split('*').last : '1';
      text = '社×$n';
      bg = const Color(0xFFC9A227); // 金色：使命进度
      border = const Color(0xFFFFE082);
    } else if (label.startsWith('弑')) {
      text = '弑';
      bg = const Color(0xFFD32F2F); // 赤红：亲手造就的「弑」
      border = const Color(0xFFFF8A80);
    } else if (label.startsWith('颂')) {
      final n = label.contains('*') ? label.split('*').last : '1';
      text = '颂×$n';
      bg = const Color(0xFF7E57C2);
      border = const Color(0xFFB39DDB);
    } else if (label.startsWith('🍶')) {
      bg = const Color(0xFF8E2B2B);
      border = const Color(0xFFFF7A7A);
    } else if (label.startsWith('烈弓')) {
      bg = const Color(0xFF00796B);
      border = const Color(0xFF4DB6AC);
    } else {
      bg = const Color(0xCC8D2F00);
      border = const Color(0x66FFCC80);
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.2 * k, vertical: 1 * k),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bg, bg.withValues(alpha: 0.78)]),
        borderRadius: BorderRadius.circular(3 * k),
        border: Border.all(color: border, width: 0.8),
        boxShadow: [
          BoxShadow(color: bg.withValues(alpha: 0.55), blurRadius: 4 * k, spreadRadius: 0.3),
        ],
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 7.5 * k,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.05)),
    );
  }

  /// 判定区标记：不同延时锦囊用不同底色，尺寸放大到能看清
  Widget _judgeChip(String name, double k) {
    late final Color bg;
    late final Color border;
    late final String text;
    late final Color fg;
    if (name.contains('乐')) {
      bg = const Color(0xFFE91E63); // 乐不思蜀：粉红
      border = const Color(0xFFFF80AB);
      fg = Colors.white;
      text = '乐';
    } else if (name.contains('兵粮') || name.contains('断粮')) {
      bg = const Color(0xFF1E88E5); // 兵粮寸断：蓝
      border = const Color(0xFF90CAF9);
      fg = Colors.white;
      text = '兵粮';
    } else if (name.contains('闪电')) {
      bg = const Color(0xFF6A1B9A); // 闪电：紫
      border = const Color(0xFFBA68C8);
      fg = Colors.white;
      text = '雷';
    } else if (name.contains('铁索')) {
      bg = const Color(0xFF795548);
      border = const Color(0xFFBCAAA4);
      fg = Colors.white;
      text = '铁索';
    } else {
      bg = const Color(0xFFC62828);
      border = const Color(0xFFEF9A9A);
      fg = Colors.white;
      text = name.length > 2 ? name.substring(0, 2) : name;
    }
    return Tooltip(
      message: name,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4 * k, vertical: 1.5 * k),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [bg, bg.withValues(alpha: 0.72)]),
          borderRadius: BorderRadius.circular(4 * k),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(color: bg.withValues(alpha: 0.55), blurRadius: 5 * k, spreadRadius: 0.5),
          ],
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 8.5 * k, color: fg, fontWeight: FontWeight.w700, height: 1.1)),
      ),
    );
  }

  Widget _equipLabel(double k) {
    final slots = _equipSlots();
    const icons = ['⚔', '🛡', '🐴', '🐎'];
    const tips = ['武器', '+1 马', '-1 马', '防具'];
    final shown = <Widget>[];
    for (var i = 0; i < 4; i++) {
      if (slots[i].isEmpty) continue;
      shown.add(Tooltip(
        message: '${tips[i]}：${slots[i]}',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icons[i], style: TextStyle(fontSize: 9 * k)),
          const SizedBox(width: 1),
          Text(slots[i],
              style: TextStyle(
                  fontSize: 8.5 * k,
                  color: const Color(0xFFFFE0B2),
                  fontWeight: FontWeight.w600)),
        ]),
      ));
    }
    if (shown.isEmpty) {
      return Text('— 无装备 —',
          style: TextStyle(fontSize: 8 * k, color: Colors.white24));
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) SizedBox(width: 5 * k),
            shown[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isChained = marks.contains("铁索连环※");
    final displayMarks = marks
        .where((m) => m != "铁索连环※")
        .map((m) => m.startsWith('烈弓-') ? '烈弓${_suitGlyph(m.substring(3))}' : m)
        .toList();
    if (wineBonus > 0) displayMarks.insert(0, '🍶+$wineBonus');
    final seatChar =
        seatNo >= 1 && seatNo <= _cnNums.length ? _cnNums[seatNo - 1] : '$seatNo';
    final cardWidth = compact ? 180.0 : w;
    // 紧凑模式需要给底部“思考中”提示留出空间，避免父级高度不足时溢出
    final cardHeight = compact ? 240.0 : cardH;
    // 内部元素缩放系数：主视角（compact）放大，让名字/勾玉/角标清晰可读
    final double k = compact ? 1.16 : 1.0;
    final double stripW = 24 * k;
    final double diamondSize = 20 * k;
    final double diamondLeft = stripW + 3;
    final double diamondBottom = 22 * k;
    // 名字左边界必须让开左下角的菱形手牌数，否则会被压住开头几个字
    final double nameLeft = diamondLeft + diamondSize + 4;
    final double statusLeft = stripW + 2;
    final double distBottom = diamondBottom + diamondSize + 4;

    final card = DragTarget<CardModel>(
      onWillAcceptWithDetails: (details) => !isMe && alive,
      onAcceptWithDetails: (details) {
        if (onCardDropped != null) onCardDropped!(details.data, id);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty && candidateData.first != null;
        final highlight = isHovered || isSelectedAsTarget;

        final drunk = wineBonus > 0;
        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            key: cardKey,
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isWaitingResponse
                    ? const Color(0xFF4DD0E1)
                    : (isHitFlash
                        ? const Color(0xFFFF1744)
                        : (isOutOfRange
                            ? const Color(0x55FFFFFF)
                            : (highlight
                                ? const Color(0xFFFF5252)
                                : (isCurrentTurn
                                    ? const Color(0xFFFFC94D)
                                    : (drunk
                                        ? const Color(0xFFFF4D4D)
                                        : const Color(0x66FFD9A0)))))),
                width: isWaitingResponse
                    ? 2.6
                    : (isHitFlash
                        ? 3.2
                        : (highlight ? 3 : ((isCurrentTurn || drunk) ? 2.5 : 1.2))),
              ),
              boxShadow: [
                if (isWaitingResponse)
                  const BoxShadow(
                      color: Color(0xAA4DD0E1), blurRadius: 20, spreadRadius: 3),
                if (isHitFlash)
                  const BoxShadow(
                      color: Color(0xCCFF1744), blurRadius: 26, spreadRadius: 4),
                if (drunk) ...[
                  const BoxShadow(
                      color: Color(0x996B4A00), blurRadius: 22, spreadRadius: 3),
                  const BoxShadow(
                      color: Color(0xAAFFB300), blurRadius: 14, spreadRadius: 1),
                ],
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
                if (isWaitingResponse)
                  const Positioned.fill(child: _WaitingPulse(radius: 9)),
                if (isWaitingResponse)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 2 * k,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 5 * k, vertical: 1.5 * k),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF006064), Color(0xFF26C6DA)]),
                            borderRadius: BorderRadius.circular(8 * k),
                            boxShadow: const [
                              BoxShadow(color: Color(0xAA26C6DA), blurRadius: 8),
                            ],
                          ),
                          child: Text('思考响应中…',
                              style: TextStyle(
                                  fontSize: 8.6 * k,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    _strip(k),
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
                            left: nameLeft,
                            right: 6,
                            bottom: diamondBottom,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11 * k,
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
                  right: 3 * k,
                  top: 3 * k,
                  child: Container(
                    width: 20 * k,
                    height: 20 * k,
                    decoration: BoxDecoration(
                      color: _roleColor().withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black45, width: 0.8),
                    ),
                    child: Center(
                      child: Text(_roleChar(),
                          style: TextStyle(
                              fontSize: 11 * k,
                              color: Colors.black87,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
                // 手牌数菱形（左下）
                Positioned(
                  left: diamondLeft,
                  bottom: diamondBottom,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: diamondSize,
                      height: diamondSize,
                      decoration: BoxDecoration(
                        color: const Color(0xE6B8860B),
                        border: Border.all(color: const Color(0xFFFFE082), width: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: Center(
                          child: Text('$handCount',
                              style: TextStyle(
                                  fontSize: 10 * k,
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
                    left: statusLeft,
                    bottom: distBottom,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3)),
                      child: Text('距$distance',
                          style: TextStyle(fontSize: 7.5 * k, color: Colors.white70)),
                    ),
                  ),
                if (isChained)
                  Positioned(
                    right: 3,
                    top: 26 * k,
                    child: Tooltip(
                      message: '铁索连环（横置）',
                      child: Container(
                        width: 15 * k,
                        height: 15 * k,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFE082), Color(0xFFC08A00)],
                          ),
                          borderRadius: BorderRadius.circular(4 * k),
                          border: Border.all(
                              color: const Color(0xFFFFF3C4), width: 1),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x99FFC107),
                                blurRadius: 8,
                                spreadRadius: 1),
                          ],
                        ),
                        child: Icon(Icons.lock,
                            size: 10 * k, color: const Color(0xFF4A3200)),
                      ),
                    ),
                  ),
                if (flipped)
                  Positioned(
                    right: 4,
                    top: 44 * k,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A148C),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('背面',
                          style: TextStyle(fontSize: 7 * k, color: Colors.white)),
                    ),
                  ),
                // 濒死求桃：整张牌压灰 + 红字警示
                if (isDying)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x77000000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xE6B71C1C),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFFF8A80), width: 1.2),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x99FF1744),
                                    blurRadius: 16,
                                    spreadRadius: 2),
                              ],
                            ),
                            child: Text('濒死求桃',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11 * k,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                          ),
                        ),
                      ),
                    ),
                  ),
                // 左上信息列：扣置牌数量 + 标记（社/弑等）+ 判定区，自上而下自然排布避免互相压字
                Positioned(
                  left: statusLeft,
                  top: 3 * k,
                  right: 2 * k,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (exileCount > 0)
                        Container(
                          margin: EdgeInsets.only(bottom: 2 * k),
                          padding: EdgeInsets.symmetric(
                              horizontal: 3.5 * k, vertical: 1 * k),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFD4AF37), Color(0xFF8D6E1F)]),
                            borderRadius: BorderRadius.circular(3 * k),
                            border: Border.all(color: const Color(0xFFFFE082), width: 0.9),
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0x99FFD54F),
                                  blurRadius: 5 * k,
                                  spreadRadius: 0.5),
                            ],
                          ),
                          child: Text('扣:$exileCount',
                              style: TextStyle(
                                  fontSize: 7.5 * k,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ),
                      if (isOutOfRange)
                        Container(
                          margin: EdgeInsets.only(bottom: 2 * k),
                          padding: EdgeInsets.symmetric(
                              horizontal: 4 * k, vertical: 1.5 * k),
                          decoration: BoxDecoration(
                            color: const Color(0xCC2A2A2A),
                            borderRadius: BorderRadius.circular(3 * k),
                            border: Border.all(color: Colors.white30, width: 0.9),
                          ),
                          child: Text('距离不足',
                              style: TextStyle(
                                  fontSize: 7.5 * k,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700)),
                        ),
                      if (displayMarks.isNotEmpty)
                        Wrap(
                          spacing: 2.5 * k,
                          runSpacing: 2 * k,
                          children:
                              displayMarks.map((m) => _markChip(m, k)).toList(),
                        ),
                      if (judges.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: displayMarks.isEmpty ? 0 : 2 * k),
                          child: Wrap(
                            spacing: 3 * k,
                            runSpacing: 2 * k,
                            children:
                                judges.take(3).map((j) => _judgeChip(j, k)).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                // 底部条：装备 + 座次
                Positioned(
                  left: stripW,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 20 * k,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.black.withValues(alpha: 0.72),
                    child: Row(
                      children: [
                        Expanded(
                          child: DefaultTextStyle(
                            style: TextStyle(fontSize: 8 * k, color: Colors.white70),
                            child: _equipLabel(k),
                          ),
                        ),
                        Text(seatChar,
                            style: TextStyle(
                                fontSize: 9 * k,
                                color: const Color(0xFFFFD54F),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
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
          // 合法可选目标：武将卡正上方悬浮「跳动宝剑」
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              card,
              if (showTargetSword)
                Positioned(
                  top: -16,
                  child: _JumpingSword(size: compact ? 34 : 28),
                ),
            ],
          ),
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

/// 「思考响应中…」呼吸脉冲边框（等待该角色出闪/出杀/出无懈时使用）
class _WaitingPulse extends StatefulWidget {
  const _WaitingPulse({required this.radius});

  final double radius;

  @override
  State<_WaitingPulse> createState() => _WaitingPulseState();
}

class _WaitingPulseState extends State<_WaitingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final v = _c.value;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(
                color: const Color(0xFF4DD0E1).withValues(alpha: 0.35 + 0.55 * v),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF26C6DA).withValues(alpha: 0.20 + 0.45 * v),
                  blurRadius: 10 + 16 * v,
                  spreadRadius: 1 + 2 * v,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
/// 「跳动宝剑」：玩家选中需要指定目标的牌时，在合法可选目标上方上下往复跳动的赤金宝剑
/// （±6px 浮动 + 金色光晕），提示「点这张席位就能指定」。
class _JumpingSword extends StatefulWidget {
  const _JumpingSword({required this.size});

  final double size;

  @override
  State<_JumpingSword> createState() => _JumpingSwordState();
}

class _JumpingSwordState extends State<_JumpingSword>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final double t = Curves.easeInOut.transform(_c.value);
          return Transform.translate(
            offset: Offset(0, -6 + 12 * t),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFF59D), Color(0xFFC9A227)],
                ),
                border: Border.all(color: const Color(0xFFFFD54F), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.55 + 0.35 * t),
                    blurRadius: 10 + 8 * t,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
              child: Icon(
                Icons.gavel,
                size: widget.size * 0.62,
                color: const Color(0xFF4A2E00),
              ),
            ),
          );
        },
      ),
    );
  }
}
