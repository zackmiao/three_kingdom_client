class CardModel {
  final int index;
  final String typeKey;
  final String suitKey;
  final String points; // "A", "2".."10", "J", "Q", "K"
  final int cardId;
  final String name;
  final String asTransformed; // 视作转化牌名称，如 "酒" 或 "NONE"
  /// 两仪牌（司马昭【怠攻】阴态）：本牌效果结算两次。
  final bool liangYi;
  /// 潜龙牌（司马昭【怠攻】阳态）：每层让伤害/回复 +1。
  final int qianLongLevel;

  CardModel({
    required this.index,
    required this.typeKey,
    required this.suitKey,
    required this.points,
    required this.cardId,
    required this.name,
    this.asTransformed = "NONE",
    this.liangYi = false,
    this.qianLongLevel = 0,
  });

  /// 解析服务端数据: 序号#类型#花色#点数字符#ID#中文名#转化名[#两仪#潜龙层数]
  static CardModel? parse(String raw) {
    if (raw.trim().isEmpty) return null;
    final parts = raw.split('#');
    if (parts.length < 6) return null;

    int idx = int.tryParse(parts[0]) ?? 0;
    String tKey = parts[1];
    String sKey = parts[2];
    String pts = parts[3];
    int cId = int.tryParse(parts[4]) ?? 0;
    String cName = parts[5];
    String transformed = parts.length > 6 ? parts[6] : "NONE";
    final liangYi = parts.length > 7 && parts[7].trim() == "1";
    final qianLong = parts.length > 8 ? (int.tryParse(parts[8]) ?? 0) : 0;

    return CardModel(
      index: idx,
      typeKey: tKey,
      suitKey: sKey,
      points: pts,
      cardId: cId,
      name: cName,
      asTransformed: transformed,
      liangYi: liangYi,
      qianLongLevel: qianLong,
    );
  }

  /// 是否带有司马昭系的强化标签（两仪 / 潜龙）
  bool get hasSpecialTag => liangYi || qianLongLevel > 0;

  /// 是否为红色花色（红桃/方块）
  bool get isRed {
    String s = suitKey.toUpperCase();
    return s == 'HEART' || s == 'DIAMOND' || s == '红桃' || s == '方块' || s == '方片';
  }

  /// 获取花色符号
  String get suitSymbol {
    switch (suitKey.toUpperCase()) {
      case 'SPADE':
      case '黑桃':
        return '♠';
      case 'HEART':
      case '红桃':
        return '♥';
      case 'CLUB':
      case '梅花':
      case '草花':
        return '♣';
      case 'DIAMOND':
      case '方块':
      case '方片':
        return '♦';
      default:
        return '♠';
    }
  }

  /// 获取数值点数用于排序 (1..13)
  int get pointValue {
    switch (points.toUpperCase()) {
      case 'A':
        return 1;
      case 'J':
        return 11;
      case 'Q':
        return 12;
      case 'K':
        return 13;
      default:
        return int.tryParse(points) ?? 1;
    }
  }

  /// 类型排序权重
  int get typePriority {
    if (typeKey.contains('SHA')) return 1;
    if (typeKey == 'SHAN') return 2;
    if (typeKey == 'TAO') return 3;
    if (typeKey == 'JIU') return 4;
    if (typeKey.contains('HORSE') || typeKey.contains('ARMOR') || typeKey.contains('WEAPON')) return 5;
    return 6; // 锦囊牌
  }
}