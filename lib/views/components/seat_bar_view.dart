import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/opponent_model.dart';

class SeatBarView extends StatelessWidget {
  final List<OpponentModel> opponents;
  final String myName;
  final String myHero;
  final int myHp;
  final int myMaxHp;
  final int myHandCount;
  final String myEquips;
  final List<String> myJudges;
  final List<String> myMarks;

  // 多人目标点选属性
  final Set<String> selectedTargetIds;
  final bool isTargetSelectionMode;
  final Function(String targetId)? onTargetSelect;

  const SeatBarView({
    super.key,
    required this.opponents,
    required this.myName,
    required this.myHero,
    required this.myHp,
    required this.myMaxHp,
    required this.myHandCount,
    required this.myEquips,
    required this.myJudges,
    required this.myMarks,
    this.selectedTargetIds = const {},
    this.isTargetSelectionMode = false,
    this.onTargetSelect,
  });

  Widget _buildCard({
    required String id,
    required String name,
    required String hero,
    required int hp,
    required int maxHp,
    required int handCount,
    required String equips,
    required List<String> judges,
    required List<String> marks,
    required bool isMe,
  }) {
    bool isChained = marks.contains("铁索连环※");
    bool isSelectedAsTarget = selectedTargetIds.contains(id);

    return GestureDetector(
      onTap: () {
        if (!isMe && onTargetSelect != null) {
          onTargetSelect!(id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        transform: Matrix4.rotationZ(isChained ? (math.pi / 18) : 0),
        transformAlignment: Alignment.center,
        width: 165,
        height: 225,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1E2838) : const Color(0xFF262732),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelectedAsTarget
                ? Colors.redAccent // 选为目标时亮红色准星框
                : (isChained
                    ? Colors.deepOrangeAccent
                    : (isMe ? Colors.cyanAccent : Colors.amberAccent.withValues(alpha: 0.7))),
            width: isSelectedAsTarget ? 3.5 : (isChained ? 3.0 : (isMe ? 2.5 : 2.0)),
          ),
          boxShadow: [
            BoxShadow(
              color: isSelectedAsTarget
                  ? Colors.redAccent.withValues(alpha: 0.6)
                  : (isChained
                      ? Colors.redAccent.withValues(alpha: 0.4)
                      : (isMe ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.black54)),
              blurRadius: isSelectedAsTarget ? 12 : 8,
              offset: const Offset(2, 4),
            )
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // 头部信息
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  color: isMe ? Colors.cyan[900]!.withValues(alpha: 0.6) : Colors.black45,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isMe ? '$name (你)' : name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.cyanAccent : Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('HP $hp/$maxHp',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // 专属标记区
                if (marks.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    color: Colors.amber[900]!.withValues(alpha: 0.5),
                    child: Wrap(
                      spacing: 4,
                      children: marks.map((m) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.deepOrangeAccent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            m,
                            style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                // 武将立绘大字区
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: hero == "曹操"
                          ? Colors.blueGrey[900]
                          : hero == "周处"
                              ? Colors.red[950]
                              : hero == "孙权"
                                  ? Colors.deepPurple[900]
                                  : Colors.brown[800],
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            hero.isNotEmpty ? hero.substring(0, 1) : "武",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.cyanAccent : Colors.amberAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(hero,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
                // 装备与判定区
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  color: Colors.black38,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.style, size: 11, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('手牌: $handCount',
                              style: const TextStyle(fontSize: 10, color: Colors.amber)),
                        ],
                      ),
                      Text('装: ${equips.isEmpty ? "无" : equips}',
                          style: const TextStyle(fontSize: 9, color: Colors.white60),
                          overflow: TextOverflow.ellipsis),
                      if (judges.isNotEmpty)
                        Text('判: ${judges.join(",")}',
                            style: const TextStyle(fontSize: 9, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                )
              ],
            ),
            // 铁索连环横置锁链 UI 徽章
            if (isChained)
              Positioned(
                top: 35,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.black.withValues(alpha: 0.75),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link, size: 14, color: Colors.deepOrangeAccent),
                      SizedBox(width: 4),
                      Text(
                        '【横置·连环】',
                        style: TextStyle(
                            color: Colors.deepOrangeAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            // 准星锁定状态提示
            if (isSelectedAsTarget)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.gps_fixed, size: 16, color: Colors.white),
                ),
              ),
            // 选目标提示边框
            if (!isMe && isTargetSelectionMode && !isSelectedAsTarget)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                  child: const Text('点击指定', style: TextStyle(fontSize: 8, color: Colors.amberAccent)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCard(
                id: "ME",
                name: myName,
                hero: myHero,
                hp: myHp,
                maxHp: myMaxHp,
                handCount: myHandCount,
                equips: myEquips,
                judges: myJudges,
                marks: myMarks,
                isMe: true,
              ),
              ...opponents.map((opp) => _buildCard(
                    id: opp.id,
                    name: opp.name,
                    hero: opp.hero,
                    hp: opp.hp,
                    maxHp: opp.maxHp,
                    handCount: opp.handCount,
                    equips: opp.equips,
                    judges: opp.judges.isNotEmpty ? opp.judges.split(',') : [],
                    marks: opp.marks.isNotEmpty ? opp.marks.split(',') : [],
                    isMe: false,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}