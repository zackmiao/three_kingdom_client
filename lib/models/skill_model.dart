class SkillModel {
  final String name;
  final String type; // PASSIVE / ACTIVE / TRIGGER
  final String desc;
  /// 当前是否可以发动（次数用完、翻面、标记不足时为 false，按钮置暗）。
  final bool usable;

  SkillModel({
    required this.name,
    required this.type,
    required this.desc,
    this.usable = true,
  });

  bool get isActive => type == 'ACTIVE';

  static const Set<String> _activeNames = {
    '除害', '制衡', '武圣', '乱击', '突袭', '扬威', '国色', '明策', '清正',
    '反间', '据守', '解围', '乱武', '雷击', '颂', '震袭',
  };

  /// 需要玩家手动点按钮发动的技能（ACTIVE 或已知主动/半主动技）。
  bool get isManual => isActive || _activeNames.contains(name);
}
