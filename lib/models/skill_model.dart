class SkillModel {
  final String name;
  final String type; // PASSIVE / ACTIVE / TRIGGER / LIMITED
  final String desc;
  /// 当前是否可以发动（次数用完、翻面、标记不足时为 false，按钮置暗）。
  final bool usable;
  /// 剩余可用次数（0 表示该技能没有次数概念）。
  final int remain;
  /// 次数上限（0 表示该技能没有次数概念）。
  final int cap;

  SkillModel({
    required this.name,
    required this.type,
    required this.desc,
    this.usable = true,
    this.remain = 0,
    this.cap = 0,
  });

  bool get isActive => type == 'ACTIVE';

  /// 是否需要在按钮上显示「剩余/上限」（蓄力、限定次数类技能）
  bool get hasCounter => cap > 0;

  static const Set<String> _activeNames = {
    '除害', '制衡', '武圣', '乱击', '突袭', '扬威', '国色', '明策', '清正',
    '反间', '据守', '解围', '乱武', '雷击', '颂', '震袭',
  };

  /// 需要玩家手动点按钮发动的技能（ACTIVE 或已知主动/半主动技）。
  bool get isManual => isActive || _activeNames.contains(name);

  /// 技能类型的中文名（用于长按详情）。
  String get typeLabel {
    switch (type) {
      case 'ACTIVE':
        return '主动技';
      case 'TRIGGER':
        return '触发技';
      case 'LIMITED':
        return '限定技';
      default:
        return '锁定技';
    }
  }
}
