import 'hero_model.dart';

/// 武将强度分级（图鉴按此分档，而不是按扩展包）。
///
/// 目前只有标准包与谋攻篇，所以：
/// - 标准包（标将）→ 废物
/// - 谋攻篇（谋将）→ 弱
/// 后续要加自制武将 / BOSS 武将时，只需要在 [overrides] 里登记，
/// 或者把新包的默认档位加到 [_packTier] 里即可。
enum HeroTier {
  boss('BOSS', '神将', 0xFFE53935),
  strong('S', '强', 0xFFFF7043),
  medium('A', '中', 0xFFFFC107),
  weak('B', '弱', 0xFF66BB6A),
  trash('C', '废物', 0xFF90A4AE);

  const HeroTier(this.tag, this.label, this.colorValue);

  /// 卡片角标里的短标签
  final String tag;

  /// 中文档位名
  final String label;

  final int colorValue;
}

class HeroTiers {
  HeroTiers._();

  /// 手工登记（优先级最高）：自制武将、BOSS 武将都放这里
  static final Map<String, HeroTier> overrides = <String, HeroTier>{
    // 例：
    // '自制·吕布': HeroTier.boss,
    // 'BOSS·董卓': HeroTier.boss,
  };

  /// 扩展包 → 默认档位
  static final Map<String, HeroTier> _packTier = <String, HeroTier>{
    '标准': HeroTier.trash,
    '谋攻篇': HeroTier.weak,
  };

  static HeroTier of(HeroModel hero) {
    final manual = overrides[hero.name];
    if (manual != null) return manual;
    for (final entry in _packTier.entries) {
      if (hero.pack.startsWith(entry.key)) return entry.value;
    }
    // 未知扩展包（未来的自制/BOSS 包）默认按「中」处理，避免直接掉到废物
    return HeroTier.medium;
  }

  /// 图鉴优先展示的高档位在前
  static const List<HeroTier> displayOrder = <HeroTier>[
    HeroTier.boss,
    HeroTier.strong,
    HeroTier.medium,
    HeroTier.weak,
    HeroTier.trash,
  ];
}
