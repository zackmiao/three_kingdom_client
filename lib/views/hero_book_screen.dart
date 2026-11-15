import 'package:flutter/material.dart';

import '../models/hero_model.dart';
import 'components/hero_portrait.dart';

/// 武将图鉴：大厅/房间里都能打开，浏览全部武将的将面、势力、体力与技能原文。
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
  String _pack = '全部';

  @override
  Widget build(BuildContext context) {
    final all = HeroCatalog.instance.heroes;
    final packs = <String>{'全部'};
    for (final h in all) {
      packs.add(h.pack);
    }
    final list = _pack == '全部' ? all : all.where((h) => h.pack == _pack).toList();

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
                      for (final p in packs)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(p),
                            selected: _pack == p,
                            selectedColor: Colors.amber[800],
                            backgroundColor: const Color(0xFF2A2B36),
                            labelStyle: TextStyle(
                              color: _pack == p ? Colors.white : Colors.white70,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setState(() => _pack = p),
                          ),
                        ),
                      const Spacer(),
                      Text('${list.length} 位',
                          style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 168,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.60,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _HeroCard(hero: list[i]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final HeroModel hero;

  const _HeroCard({required this.hero});

  @override
  Widget build(BuildContext context) {
    final color = hero.color;
    return InkWell(
      onTap: () => _showDetail(context, hero),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                child: HeroPortrait(hero: hero.name),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hero.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('${hero.force} · ${hero.hp} 血 · ${hero.pack}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, HeroModel hero) {
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
                    child: SizedBox(width: 96, height: 132, child: HeroPortrait(hero: hero.name)),
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
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final s in hero.skills)
                              Chip(
                                label: Text(s.name,
                                    style: const TextStyle(fontSize: 11, color: Colors.white)),
                                backgroundColor:
                                    s.isActive ? Colors.amber.shade800 : const Color(0xFF2F3140),
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
                              style: const TextStyle(fontSize: 12.5, height: 1.45),
                              children: [
                                TextSpan(
                                  text: '【${s.name}】${s.isActive ? '主动技' : '锁定/触发技'}  ',
                                  style: const TextStyle(
                                      color: Colors.amberAccent, fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: s.desc, style: const TextStyle(color: Colors.white70)),
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
                  child: const Text('关闭', style: TextStyle(color: Colors.amberAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
