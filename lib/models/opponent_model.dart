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
      default:
        return "？";
    }
  }
}
