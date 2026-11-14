import 'package:flutter/material.dart';
import '../../models/skill_model.dart';

class EquipAndJudgeBar extends StatelessWidget {
  final String weapon;
  final String armor;
  final String defHorse;
  final String offHorse;
  final List<String> judgeCards;
  final List<SkillModel> skills;
  final Function(String skillName)? onSkillTap;

  const EquipAndJudgeBar({
    super.key,
    required this.weapon,
    required this.armor,
    required this.defHorse,
    required this.offHorse,
    required this.judgeCards,
    required this.skills,
    this.onSkillTap,
  });

  Widget _buildEquipSlot(String title, String val, IconData icon) {
    bool hasEquip = val != "无" && val.isNotEmpty;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: hasEquip ? const Color(0xFF2D303E) : Colors.black26,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: hasEquip ? Colors.amber.withValues(alpha: 0.5) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: hasEquip ? Colors.amberAccent : Colors.white38),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$title: $val',
                style: TextStyle(
                  fontSize: 10,
                  color: hasEquip ? Colors.amberAccent : Colors.white54,
                  fontWeight: hasEquip ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF1B1C22),
      child: Column(
        children: [
          // 技能展示栏（可直接点击发动）
          if (skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  const Text('技能: ', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: skills.map((sk) {
                        return GestureDetector(
                          onTap: () {
                            if (onSkillTap != null) onSkillTap!(sk.name);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: sk.name == "除害"
                                  ? Colors.deepOrange[800]
                                  : (sk.type == 'ACTIVE' ? Colors.amber[900] : Colors.teal[900]),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${sk.type == "ACTIVE" || sk.name == "除害" ? "主" : "被"} ${sk.name}',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          // 4 格装备栏
          Row(
            children: [
              _buildEquipSlot('武器', weapon, Icons.colorize),
              _buildEquipSlot('防具', armor, Icons.shield),
              _buildEquipSlot('+1马', defHorse, Icons.pets),
              _buildEquipSlot('-1马', offHorse, Icons.directions_run),
            ],
          ),
        ],
      ),
    );
  }
}