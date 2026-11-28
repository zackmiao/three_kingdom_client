/// 客户端的「这张牌能不能指定这名角色」目标校验（与服务端 CardPlayDispatcher 保持一致的规则）。
///
/// 服务端仍是最终裁决者，这里只用来：
/// 1. 提前把不合法目标压暗；
/// 2. 给合法目标显示「跳动宝剑」提示。
library;

/// 一名角色的目标判定上下文。
class TargetContext {
  final String id;
  final String name;
  final bool isMe;
  final bool alive;

  /// 与服务端一致的「实际距离」（含马匹/技能修正）。
  final int distance;
  final int handCount;
  final int equipCount;
  final int judgeCount;

  /// 判定区里已有的延时锦囊名字（中文，例如 乐不思蜀 / 兵粮寸断）。
  final List<String> judgeNames;

  const TargetContext({
    required this.id,
    required this.name,
    required this.isMe,
    required this.alive,
    required this.distance,
    required this.handCount,
    required this.equipCount,
    required this.judgeCount,
    this.judgeNames = const [],
  });

  int get regionCount => handCount + equipCount + judgeCount;
}

const Set<String> _shaTypes = {'SHA', 'FIRE_SHA', 'THUNDER_SHA'};

/// 无需指定单体目标的牌（选中后直接点【确定】或拖到桌面打出）。
const Set<String> noTargetCards = {
  'TAO',
  'JIU',
  'WU_ZHONG_SHENG_YOU',
  'SHAN_DIAN',
  'NAN_MAN_RU_QIN',
  'WAN_JIAN_QI_FA',
  'TAO_YUAN_JIE_YI',
  'WU_GU_FENG_DENG',
  'ZHU_GE_LIAN_NU',
  'ZHANG_BA_SHE_MAO',
  'QING_GANG_JIAN',
  'GUAN_SHI_FU',
  'BA_GUA_ZHEN',
  'REN_WANG_DUN',
  'BAI_YIN_SHI_ZI',
  'TENG_JIA',
  'DEFENSIVE_HORSE',
  'OFFENSIVE_HORSE',
};

/// 需要指定单体目标（或多目标）的牌。
bool cardNeedsTarget(String typeKey) {
  if (noTargetCards.contains(typeKey)) return false;
  if (typeKey.isEmpty || typeKey == 'NONE') return false;
  return true;
}

/// 返回 null 表示可以指定该目标；否则返回不可指定的原因（用于提示）。
///
/// [attackRange] 我的攻击范围；[wuShengLocked] 是否已用【武圣】锁定该目标
/// （锁定后无视距离，最多三张【杀】）。
String? targetBlockReason(
  String typeKey,
  TargetContext t, {
  required int attackRange,
  bool wuShengLocked = false,
}) {
  if (!t.alive) return '${t.name} 已阵亡';
  if (_shaTypes.contains(typeKey)) {
    if (t.isMe) return '不能对自己使用【杀】';
    if (!wuShengLocked && t.distance > attackRange) {
      return '${t.name} 距离 ${t.distance} 超出攻击范围 $attackRange';
    }
    return null;
  }
  switch (typeKey) {
    case 'DUEL':
      if (t.isMe) return '【决斗】不能对自己使用';
      return null;
    case 'GUO_HE_CHAI_QIAO':
      if (t.isMe) return '【过河拆桥】不能对自己使用';
      if (t.regionCount == 0) return '${t.name} 手牌、装备区、判定区都是空的';
      return null;
    case 'SHUN_SHOU_QIAN_YANG':
      if (t.isMe) return '【顺手牵羊】不能对自己使用';
      if (t.distance > 1) return '${t.name} 距离 ${t.distance}，【顺手牵羊】只能对距离 1 以内';
      if (t.regionCount == 0) return '${t.name} 手牌、装备区、判定区都是空的';
      return null;
    case 'LE_BU_SI_SHU':
      if (t.isMe) return '【乐不思蜀】不能对自己使用';
      if (t.judgeNames.any((n) => n.contains('乐不思蜀'))) {
        return '${t.name} 判定区已有【乐不思蜀】';
      }
      return null;
    case 'BING_LIANG_CUN_DUAN':
      if (t.isMe) return '【兵粮寸断】不能对自己使用';
      if (t.distance > 1) return '${t.name} 距离 ${t.distance}，【兵粮寸断】只能对距离 1 以内';
      if (t.judgeNames.any((n) => n.contains('兵粮寸断'))) {
        return '${t.name} 判定区已有【兵粮寸断】';
      }
      return null;
    case 'HUO_GONG':
      if (t.handCount == 0) return '${t.name} 没有手牌，【火攻】无法指定';
      return null;
    case 'TIE_SUO_LIAN_HUAN':
      return null; // 任意存活角色（含自己），最多 2 名
    default:
      return t.isMe ? '这张牌不能指定自己' : null;
  }
}
