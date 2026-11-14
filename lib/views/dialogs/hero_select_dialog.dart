import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/hero_model.dart';
import '../components/hero_portrait.dart';

/// 选将面板：将面立绘 + 势力/体力 + 技能说明，支持按扩展包筛选。
class HeroSelectDialog {
  static void show(
    BuildContext context,
    List<HeroModel> heroes, {
    String title = '选择出战武将',
    String? currentHero,
    required Function(HeroModel hero) onSelect,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (heroes.isEmpty) return;

      String packFilter = '全部';
      HeroModel? picked = heroes.firstWhere(
        (h) => h.name == currentHero,
        orElse: () => heroes.first,
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setDialogState) {
            final screen = MediaQuery.of(ctx).size;
            final dlgWidth = math.min(880.0, screen.width - 48);
            final dlgHeight = math.min(620.0, screen.height - 72);
            final columns = math.max(3, math.min(8, (dlgWidth / 150).floor()));
            final packs = <String>['全部', ...{for (final h in heroes) h.pack}];
            final list = packFilter == '全部'
                ? heroes
                : heroes.where((h) => h.pack == packFilter).toList();

            return Dialog(
              backgroundColor: const Color(0xFF1B1C24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: dlgWidth,
                height: dlgHeight,
                child: Column(
                  children: [
                    // 顶部标题
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF24252E),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.military_tech, color: Colors.amberAccent),
                          const SizedBox(width: 8),
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.amberAccent, fontSize: 17, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    // 扩展包筛选
                    SizedBox(
                      height: 46,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        children: packs
                            .map((p) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(p, style: const TextStyle(fontSize: 12)),
                                    selected: packFilter == p,
                                    selectedColor: Colors.amber[800],
                                    backgroundColor: Colors.white10,
                                    labelStyle: TextStyle(
                                        color: packFilter == p ? Colors.white : Colors.white70),
                                    onSelected: (_) => setDialogState(() => packFilter = p),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final h = list[i];
                          final selected = picked?.name == h.name;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setDialogState(() => picked = h),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: selected ? Colors.amberAccent : Colors.white24,
                                    width: selected ? 2.5 : 1),
                                color: Colors.black26,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  HeroPortrait(hero: h.name),
                                  // 底部信息条
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black87],
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(h.name,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold)),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 3, vertical: 0.5),
                                                decoration: BoxDecoration(
                                                    color: h.color.withValues(alpha: 0.35),
                                                    borderRadius: BorderRadius.circular(3),
                                                    border: Border.all(color: h.color)),
                                                child: Text(h.force,
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        color: h.color,
                                                        fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 3),
                                              Text('♥${h.hp}',
                                                  style: const TextStyle(
                                                      fontSize: 9, color: Colors.redAccent)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // 谋攻篇角标
                                  if (h.isMou)
                                    Positioned(
                                      top: 3,
                                      left: 3,
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                        decoration: BoxDecoration(
                                            color: Colors.deepOrange[800],
                                            borderRadius: BorderRadius.circular(3)),
                                        child: const Text('谋',
                                            style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  if (selected)
                                    const Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Icon(Icons.check_circle,
                                          size: 16, color: Colors.amberAccent),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // 底部技能说明 + 确定
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF24252E),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Column(
                              children: [
                                Text(picked?.name ?? '',
                                    style: TextStyle(
                                        color: (picked?.color ?? Colors.white),
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                                Text('体力 ${picked?.hp ?? 4}',
                                    style: const TextStyle(fontSize: 11, color: Colors.white54)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 84,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: (picked?.skills ?? [])
                                      .map((s) => Padding(
                                            padding: const EdgeInsets.only(bottom: 3),
                                            child: Text.rich(TextSpan(children: [
                                              TextSpan(
                                                  text: '【${s.name}】',
                                                  style: const TextStyle(
                                                      color: Colors.amberAccent,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold)),
                                              TextSpan(
                                                  text: s.desc,
                                                  style: const TextStyle(
                                                      color: Colors.white70, fontSize: 11)),
                                            ])),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[800],
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                            ),
                            onPressed: picked == null
                                ? null
                                : () {
                                    Navigator.of(ctx).pop();
                                    onSelect(picked!);
                                  },
                            child: const Text('确定出战',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      );
    });
  }
}
