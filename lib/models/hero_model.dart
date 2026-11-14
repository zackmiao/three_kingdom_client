import 'package:flutter/material.dart';

class HeroSkillModel {
  final String name;
  final String type;
  final String desc;

  HeroSkillModel({required this.name, required this.type, required this.desc});

  bool get isActive => type == 'ACTIVE';
}

/// 服务端下发的武将资料：`名字#势力#体力#扩展包#技能1~技能2`
class HeroModel {
  final String name;
  final String force;
  final int hp;
  final String pack;
  final List<HeroSkillModel> skills;

  HeroModel({
    required this.name,
    required this.force,
    required this.hp,
    required this.pack,
    required this.skills,
  });

  static HeroModel? parse(String token) {
    final p = token.split('#');
    if (p.length < 5) return null;
    final skills = <HeroSkillModel>[];
    if (p[4].trim().isNotEmpty) {
      for (final s in p[4].split('~')) {
        final sp = s.split(':');
        if (sp.isEmpty || sp[0].trim().isEmpty) continue;
        skills.add(HeroSkillModel(
          name: sp[0],
          type: sp.length > 1 ? sp[1] : 'PASSIVE',
          desc: sp.length > 2 ? sp.sublist(2).join(':') : '',
        ));
      }
    }
    return HeroModel(
      name: p[0],
      force: p[1],
      hp: int.tryParse(p[2]) ?? 4,
      pack: p[3],
      skills: skills,
    );
  }

  static List<HeroModel> parseAll(String raw) {
    if (raw.trim().isEmpty) return [];
    return raw
        .split(';')
        .map((t) => HeroModel.parse(t.trim()))
        .whereType<HeroModel>()
        .toList();
  }

  static Color forceColor(String force) {
    switch (force) {
      case '魏':
        return const Color(0xFF4A90D9);
      case '蜀':
        return const Color(0xFFD9534F);
      case '吴':
        return const Color(0xFF3CB371);
      case '群':
        return const Color(0xFFB0883E);
      case '神':
        return const Color(0xFF9B59B6);
      default:
        return const Color(0xFF7A7A7A);
    }
  }

  Color get color => forceColor(force);

  bool get isMou => pack.startsWith('谋攻篇');
}

/// 全局武将池缓存：HERO_LIST 只在进房时下发一次，
/// 缓存后即使切换到对局/回到房间也不用重新请求。
class HeroCatalog {
  static final HeroCatalog instance = HeroCatalog._();
  HeroCatalog._();

  List<HeroModel> heroes = const [];

  void update(String raw) {
    final list = HeroModel.parseAll(raw);
    if (list.isNotEmpty) heroes = list;
  }

  HeroModel? byName(String name) {
    for (final h in heroes) {
      if (h.name == name) return h;
    }
    return null;
  }
}
