import 'package:flutter/material.dart';

import '../models/hero_model.dart';
import '../models/hero_tier.dart';
import 'components/hero_portrait.dart';

/// 武将图鉴：按强度分级展示（BOSS / 强 / 中 / 弱 / 废物），而不是按扩展包。
/// 为后续的「自制武将」「BOSS 武将」预留了档位（见 [HeroTiers.overrides]）。
class HeroBookScreen extends StatefulWidget {
  const HeroBookScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HeroBookScreen()),
    );
  }

  @override
  State<HeroBookScreen> createState() => _HeroBookScreenState();
}

class _HeroBookScreenState extends State<HeroBookScreen> {
  HeroTier? _tier;

  @override
  Widget build(BuildContext context) {
    final all = HeroCatalog.instance.heroes;
    final groups = <HeroTier, List<HeroModel>>{};
    for (final h in all) {
      groups.putIfAbsent(HeroTiers.of(h), () => <HeroModel>[]).add(h);
    }
    final visibleTiers = HeroTiers.displayOrder
        .where((t) => groups[t] != null && (_tier == null || _tier == t))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF14151B),
      appBar: AppBar(
        title: Text('武将图鉴 · 共 ${all.length} 位'),
        backgroundColor: const Color(0xFF24252E),
        elevation: 0,
      ),
      body: all.isEmpty
          ? const Center(
              child: Text('尚未获取武将数据，请确认已连接服务端',
                  style: TextStyle(color: Colors.white54)),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _tierChip('全部', null, all.length, Colors.amber),
                      for (final t in HeroTiers.displayOrder)
                        if (groups[t] != null)
                          _tierChip(t.label, t, groups[t]!.length,
                              Color(t.colorValue)),
                      const Spacer(),
                      Text('按强度分级',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      for (final t in visibleTiers) ...[
                        _sectionHeader(t, groups[t]!.length),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final h in groups[t]!)
                              SizedBox(
                                width: 158,
                                height: 258,
                                child: _HeroCard(hero: h, tier: t),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tierChip(String label, HeroTier? tier, int count, Color color) {
    final selected = _tier == tier;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label $count'),
        selected: selected,
        selectedColor: color.withValues(alpha: 0.8),
        backgroundColor: const Color(0xFF2A2B36),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => setState(() => _tier = tier),
      ),
    );
  }

  Widget _sectionHeader(HeroTier tier, int count) {
    final color = Color(tier.colorValue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(tier.label,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text('${tier.tag} 级 · $count 位',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final HeroModel hero;
  final HeroTier tier;

  const _HeroCard({required this.hero, required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = hero.color;
    final tierColor = Color(tier.colorValue);
    return InkWell(
      onTap: () => _showDetail(context, hero, tier),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.75), width: 1.4),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF23242E), Color(0xFF15161C)],
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(9)),
                    child: HeroPortrait(hero: hero.name),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hero.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      Text('${hero.force} · ${hero.hp} 血',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                        color: tierColor.withValues(alpha: 0.5), blurRadius: 8)
                  ],
                ),
                child: Text(tier.tag,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, HeroModel hero, HeroTier tier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1D1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 560),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                        width: 96,
                        height: 132,
                        child: HeroPortrait(hero: hero.name)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hero.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('${hero.force}势力 · 体力 ${hero.hp} · ${hero.pack}',
                            style: TextStyle(color: hero.color, fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(tier.colorValue).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('强度：${tier.label}（${tier.tag}）',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final s in hero.skills)
                              Chip(
                                label: Text(s.name,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white)),
                                backgroundColor: s.isActive
                                    ? Colors.amber.shade800
                                    : const Color(0xFF2F3140),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in hero.skills)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RichText(
                            text: TextSpan(
                              style:
                                  const TextStyle(fontSize: 12.5, height: 1.45),
                              children: [
                                TextSpan(
                                  text:
                                      '【${s.name}】${s.isActive ? '主动技' : '锁定/触发技'}  ',
                                  style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                    text: s.desc,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('关闭',
                      style: TextStyle(color: Colors.amberAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
