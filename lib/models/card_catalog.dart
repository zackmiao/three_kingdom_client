import 'package:flutter/material.dart';

/// 手杀风格牌面所需的元数据：牌名、类别、效果说明、类别配色。
class CardInfo {
  final String name;
  final String category; // 基本牌 / 锦囊牌 / 延时锦囊 / 装备牌
  final String desc;
  final Color accent;

  const CardInfo(this.name, this.category, this.desc, this.accent);
}

class CardCatalog {
  static const Color basicColor = Color(0xFFB8860B); // 基本牌：暗金
  static const Color trickColor = Color(0xFF4A63A8); // 锦囊：靛蓝
  static const Color delayColor = Color(0xFF9C27B0); // 延时：紫
  static const Color equipColor = Color(0xFF2E7D32); // 装备：墨绿

  static const Map<String, CardInfo> _map = {
    // ===== 基本牌 =====
    'SHA': CardInfo('杀', '基本牌', '出牌阶段，对攻击范围内一名角色使用，其需打出【闪】，否则受到 1 点伤害',
        basicColor),
    'FIRE_SHA': CardInfo('火杀', '基本牌', '同【杀】，造成火焰伤害（藤甲 +1）', basicColor),
    'THUNDER_SHA': CardInfo('雷杀', '基本牌', '同【杀】，造成雷电伤害', basicColor),
    'SHAN': CardInfo('闪', '基本牌', '当你成为【杀】的目标时，打出一张【闪】以抵消', basicColor),
    'TAO': CardInfo('桃', '基本牌', '出牌阶段回复 1 点体力；濒死时可自救', basicColor),
    'JIU': CardInfo('酒', '基本牌', '本回合下一张【杀】伤害 +1；濒死时回复 1 点体力', basicColor),

    // ===== 普通锦囊 =====
    'GUO_HE_CHAI_QIAO': CardInfo('过河拆桥', '锦囊牌', '弃置目标角色区域内的一张牌', trickColor),
    'SHUN_SHOU_QIAN_YANG': CardInfo('顺手牵羊', '锦囊牌', '获得距离 1 以内一名角色的一张牌', trickColor),
    'WU_ZHONG_SHENG_YOU': CardInfo('无中生有', '锦囊牌', '摸两张牌', trickColor),
    'DUEL': CardInfo('决斗', '锦囊牌', '与目标轮流打出【杀】，先不出者受到 1 点伤害', trickColor),
    'WU_XIE_KE_JI': CardInfo('无懈可击', '锦囊牌', '抵消一张锦囊牌的效果，可被再次无懈', trickColor),
    'NAN_MAN_RU_QIN': CardInfo('南蛮入侵', '锦囊牌', '所有其他角色需打出【杀】，否则受到 1 点伤害', trickColor),
    'WAN_JIAN_QI_FA': CardInfo('万箭齐发', '锦囊牌', '所有其他角色需打出【闪】，否则受到 1 点伤害', trickColor),
    'TAO_YUAN_JIE_YI': CardInfo('桃园结义', '锦囊牌', '所有角色各回复 1 点体力', trickColor),
    'WU_GU_FENG_DENG': CardInfo('五谷丰登', '锦囊牌', '亮出等同存活人数的牌，按顺序各取一张', trickColor),
    'HUO_GONG': CardInfo('火攻', '锦囊牌', '目标展示一张手牌，你弃同花色牌对其造成 1 点火焰伤害', trickColor),
    'TIE_SUO_LIAN_HUAN': CardInfo('铁索连环', '锦囊牌', '横置或重置角色；也可重铸（弃置后摸一张）', trickColor),

    // ===== 延时锦囊 =====
    'LE_BU_SI_SHU': CardInfo('乐不思蜀', '延时锦囊', '判定牌非红桃则跳过出牌阶段', delayColor),
    'BING_LIANG_CUN_DUAN': CardInfo('兵粮寸断', '延时锦囊', '判定牌非草花则跳过摸牌阶段', delayColor),
    'SHAN_DIAN': CardInfo('闪电', '延时锦囊', '判定为黑桃 2~9 则受到 3 点雷电伤害', delayColor),

    // ===== 装备 =====
    'ZHU_GE_LIAN_NU': CardInfo('诸葛连弩', '装备牌', '攻击范围 1，出牌阶段使用【杀】无次数限制', equipColor),
    'ZHANG_BA_SHE_MAO': CardInfo('丈八蛇矛', '装备牌', '攻击范围 3，可将两张手牌当【杀】使用', equipColor),
    'QING_GANG_JIAN': CardInfo('青釭剑', '装备牌', '攻击范围 2，你的【杀】无视目标防具', equipColor),
    'GUAN_SHI_FU': CardInfo('贯石斧', '装备牌', '攻击范围 3，可弃两张牌令被闪避的【杀】强命中', equipColor),
    'BA_GUA_ZHEN': CardInfo('八卦阵', '装备牌', '需要【闪】时可判定，红色则视为打出【闪】', equipColor),
    'REN_WANG_DUN': CardInfo('仁王盾', '装备牌', '黑色【杀】对你无效', equipColor),
    'BAI_YIN_SHI_ZI': CardInfo('白银狮子', '装备牌', '受到大于 1 的伤害时，锁定为 1 点', equipColor),
    'TENG_JIA': CardInfo('藤甲', '装备牌', '普通【杀】【南蛮】【万箭】无效；火焰伤害 +1', equipColor),
    'DEFENSIVE_HORSE': CardInfo('+1马', '装备牌', '其他角色计算与你的距离 +1', equipColor),
    'OFFENSIVE_HORSE': CardInfo('-1马', '装备牌', '你计算与其他角色的距离 -1', equipColor),
  };

  static CardInfo of(String typeKey, String fallbackName) {
    return _map[typeKey] ??
        CardInfo(fallbackName, '牌', '', basicColor);
  }

  /// 由中文牌名反查 typeKey（客户端从播报文本解析牌名时用）
  static String? typeKeyOfName(String name) {
    for (final e in _map.entries) {
      if (e.value.name == name) return e.key;
    }
    return null;
  }
}
