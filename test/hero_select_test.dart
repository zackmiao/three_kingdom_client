import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/models/hero_model.dart';
import 'package:three_kingdom_client/views/dialogs/hero_select_dialog.dart';

void main() {
  test('HERO_LIST 报文可以解析出武将、势力、体力与技能', () {
    const raw =
        '谋关羽#蜀#4#谋攻篇-能包#武圣:ACTIVE:①你可以将一张手牌当任意一种【杀】使用或打出~义绝:PASSIVE:锁定技，防止致命伤害'
        ';谋吕布#群#5#谋攻篇-能包#无双:PASSIVE:锁定技，你使用的【杀】需要两张【闪】';
    final heroes = HeroModel.parseAll(raw);
    expect(heroes.length, 2);
    expect(heroes.first.name, '谋关羽');
    expect(heroes.first.force, '蜀');
    expect(heroes.first.hp, 4);
    expect(heroes.first.pack, '谋攻篇-能包');
    expect(heroes.first.skills.length, 2);
    expect(heroes.first.skills.first.name, '武圣');
    expect(heroes.first.skills.first.isActive, isTrue);
    expect(heroes.last.hp, 5);
  });

  test('HeroCatalog 缓存后可按名字查找', () {
    HeroCatalog.instance.update('谋张飞#蜀#4#谋攻篇-同包#咆哮:PASSIVE:锁定技');
    expect(HeroCatalog.instance.heroes.length, 1);
    expect(HeroCatalog.instance.byName('谋张飞')?.force, '蜀');
    expect(HeroCatalog.instance.byName('不存在'), isNull);
  });

  testWidgets('选将面板可以选中武将并回调', (WidgetTester tester) async {
    final heroes = [
      HeroModel(
        name: '测试甲',
        force: '蜀',
        hp: 4,
        pack: '谋攻篇-能包',
        skills: [HeroSkillModel(name: '武圣', type: 'ACTIVE', desc: '测试技能描述')],
      ),
      HeroModel(
        name: '测试乙',
        force: '群',
        hp: 5,
        pack: '谋攻篇-同包',
        skills: [HeroSkillModel(name: '咆哮', type: 'PASSIVE', desc: '锁定技，杀无次数限制')],
      ),
    ];

    HeroModel? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => HeroSelectDialog.show(
                ctx,
                heroes,
                currentHero: '测试甲',
                onSelect: (h) => picked = h,
              ),
              child: const Text('打开选将'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('打开选将'));
    await tester.pumpAndSettle();

    // 面板渲染：标题、筛选、武将、确认按钮
    expect(find.text('选择出战武将'), findsOneWidget);
    expect(find.text('确定出战'), findsOneWidget);
    expect(find.text('测试甲'), findsWidgets);
    expect(find.text('测试乙'), findsWidgets);

    // 点选另一名武将并确认
    await tester.tap(find.text('测试乙').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定出战'));
    await tester.pumpAndSettle();

    expect(picked?.name, '测试乙');
  });
}
