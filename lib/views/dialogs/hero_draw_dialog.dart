import 'package:flutter/material.dart';

import '../../models/hero_model.dart';
import '../components/hero_portrait.dart';
import '../hero_book_screen.dart';

/// 开局抽将：从服务端抽到的 3 名候选武将里挑一位出战。
///
/// 候选列表由房间界面持有（重新抽取后服务端会再下发 HERO_CANDIDATES），
/// 这里用 ValueNotifier 跟随刷新，避免关掉弹窗再重开。
class HeroDrawDialog extends StatefulWidget {
  final ValueNotifier<List<HeroModel>> candidates;
  final String currentHero;
  final void Function(HeroModel hero) onPick;
  final VoidCallback? onReroll;
  final String title;
  final bool dismissible;

  const HeroDrawDialog({
    super.key,
    required this.candidates,
    required this.currentHero,
    required this.onPick,
    this.onReroll,
    this.title = '抽取武将',
    this.dismissible = true,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueNotifier<List<HeroModel>> candidates,
    required String currentHero,
    required void Function(HeroModel hero) onPick,
    VoidCallback? onReroll,
    String title = '抽取武将',
    bool dismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: dismissible,
      builder: (_) => HeroDrawDialog(
        candidates: candidates,
        currentHero: currentHero,
        onPick: onPick,
        onReroll: onReroll,
        title: title,
        dismissible: dismissible,
      ),
    );
  }

  @override
  State<HeroDrawDialog> createState() => _HeroDrawDialogState();
}

class _HeroDrawDialogState extends State<HeroDrawDialog> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: const Color(0xFF1B1C24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: (size.width - 80).clamp(420.0, 900.0),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        child: ValueListenableBuilder<List<HeroModel>>(
          valueListenable: widget.candidates,
          builder: (context, list, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.style, color: Colors.amberAccent, size: 22),
                    const SizedBox(width: 8),
                    Text(widget.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Text('从 ${list.length} 张候选将面中选择出战武将',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('正在抽将…', style: TextStyle(color: Colors.white54)),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < list.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          child: _DrawCard(
                            hero: list[i],
                            selected: list[i].name == widget.currentHero,
                            delayMs: i * 90,
                            onTap: () {
                              widget.onPick(list[i]);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (widget.onReroll != null)
                      TextButton.icon(
                        onPressed: widget.onReroll,
                        icon: const Icon(Icons.refresh, size: 18, color: Colors.cyanAccent),
                        label: const Text('重新抽取', style: TextStyle(color: Colors.cyanAccent)),
                      ),
                    TextButton.icon(
                      onPressed: () => HeroBookScreen.show(context),
                      icon: const Icon(Icons.menu_book, size: 18, color: Colors.white70),
                      label: const Text('武将图鉴', style: TextStyle(color: Colors.white70)),
                    ),
                    const Spacer(),
                    if (widget.dismissible)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('稍后再选', style: TextStyle(color: Colors.white54)),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawCard extends StatelessWidget {
  final HeroModel hero;
  final bool selected;
  final int delayMs;
  final VoidCallback onTap;

  const _DrawCard({
    required this.hero,
    required this.selected,
    required this.delayMs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = hero.color;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delayMs),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.82 + 0.18 * t.clamp(0.0, 1.2), child: child),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 178,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.amberAccent : color.withValues(alpha: 0.7),
              width: selected ? 2.4 : 1.4,
            ),
            boxShadow: [
              if (selected)
                const BoxShadow(color: Color(0x88FFC107), blurRadius: 16, spreadRadius: 1),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF262833), Color(0xFF14151B)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: SizedBox(height: 200, child: HeroPortrait(hero: hero.name)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(hero.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (selected)
                          const Icon(Icons.check_circle, size: 14, color: Colors.amberAccent),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${hero.force} · ${hero.hp} 血',
                        style: TextStyle(color: color, fontSize: 11)),
                    const SizedBox(height: 5),
                    for (final s in hero.skills)
                      Text('· ${s.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: s.isActive ? Colors.amberAccent : Colors.white60,
                              fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
