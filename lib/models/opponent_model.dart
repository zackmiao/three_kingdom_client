class OpponentModel {
  final String id;
  final String name;
  final String hero;
  final int hp;
  final int maxHp;
  final int handCount;
  final String equips;
  final String judges;
  final String marks; // 专属标记数据
  final String role; // MAIN / LOYAL / REBEL / TRAITOR / HIDDEN
  final bool alive;
  final int distance;
  final int armor;
  final bool flipped;
  final int wineBonus;
  /// 当前势力（WEI / QUN / SHU / WU / SHEN），随【篡权】等技能实时变化。
  final String faction;
  /// 护盾值（先于护甲承伤）。
  final int shield;
  /// 武将牌上扣置的牌数量（【弑龙】【成务】）。
  final int exileCount;

  OpponentModel({
    required this.id,
    required this.name,
    required this.hero,
    required this.hp,
    required this.maxHp,
    required this.handCount,
    required this.equips,
    required this.judges,
    required this.marks,
    this.role = "HIDDEN",
    this.alive = true,
    this.distance = 1,
    this.armor = 0,
    this.flipped = false,
    this.wineBonus = 0,
    this.faction = "",
    this.shield = 0,
    this.exileCount = 0,
  });

  static OpponentModel? parse(String token) {
    if (token.trim().isEmpty) return null;
    final p = token.split('#');
    if (p.length < 8) return null;
    return OpponentModel(
      id: p[0],
      name: p[1],
      hero: p[2],
      hp: int.tryParse(p[3]) ?? 4,
      maxHp: int.tryParse(p[4]) ?? 4,
      handCount: int.tryParse(p[5]) ?? 0,
      equips: p[6],
      judges: p[7],
      marks: p.length > 8 ? p[8] : "",
      role: p.length > 9 ? p[9] : "HIDDEN",
      alive: p.length > 10 ? p[10] == "1" : true,
      distance: p.length > 11 ? (int.tryParse(p[11]) ?? 1) : 1,
      armor: p.length > 12 ? (int.tryParse(p[12]) ?? 0) : 0,
      flipped: p.length > 13 && p[13] == "1",
      wineBonus: p.length > 14 ? (int.tryParse(p[14]) ?? 0) : 0,
      faction: p.length > 15 ? p[15].trim() : "",
      shield: p.length > 16 ? (int.tryParse(p[16]) ?? 0) : 0,
      exileCount: p.length > 17 ? (int.tryParse(p[17]) ?? 0) : 0,
    );
  }

  /// 身份中文名（隐藏身份返回问号）
  String get roleLabel {
    switch (role) {
      case "MAIN":
        return "主公";
      case "LOYAL":
        return "忠臣";
      case "REBEL":
        return "反贼";
      case "TRAITOR":
        return "内奸";
      case "WARM":
        return "暖方";
      case "COLD":
        return "冷方";
      case "LORD":
        return "地主";
      case "FARMER":
        return "农民";
      default:
        return "？";
    }
  }
}
