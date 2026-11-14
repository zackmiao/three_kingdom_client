import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/views/components/action_prompt_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Column(children: [child])));

ActionPromptBar _bar({
  required bool hasTarget,
  required VoidCallback onConfirm,
  bool isTargetOnly = true,
  int selectedCount = 0,
}) {
  return ActionPromptBar(
    prompt: '【选择目标】武圣：请点击一名主公以外的其他角色',
    isResponding: false,
    selectedCount: selectedCount,
    isZhangBaMode: false,
    isRenDeMode: false,
    isZhiHengMode: false,
    isChuHaiMode: false,
    hasZhangBaWeapon: false,
    hasRenDeSkill: false,
    hasZhiHengSkill: false,
    hasChuHaiSkill: false,
    isTargetOnly: isTargetOnly,
    hasTarget: hasTarget,
    onConfirm: onConfirm,
    onCancelSelection: () {},
    onToggleZhangBa: () {},
    onToggleRenDe: () {},
    onToggleZhiHeng: () {},
    onToggleChuHai: () {},
    onPass: () {},
  );
}

void main() {
  testWidgets('只选目标的询问：未选目标时确定按钮禁用', (tester) async {
    await tester.pumpWidget(_wrap(_bar(hasTarget: false, onConfirm: () {})));
    expect(find.text('请选目标'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '请选目标'),
    );
    expect(btn.onPressed, isNull);
    expect(find.text('↑ 请点击上方任意席位选择目标'), findsOneWidget);
  });

  testWidgets('只选目标的询问：选好目标后可以确定并触发回调', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(_wrap(_bar(hasTarget: true, onConfirm: () => confirmed = true)));
    expect(find.text('确定目标'), findsOneWidget);
    await tester.tap(find.text('确定目标'));
    await tester.pump();
    expect(confirmed, isTrue);
  });

  testWidgets('普通出牌询问：未选牌时确定按钮禁用，选牌后可用', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(_wrap(_bar(
      hasTarget: false,
      onConfirm: () => confirmed = true,
      isTargetOnly: false,
      selectedCount: 0,
    )));
    final disabled = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '确定'));
    expect(disabled.onPressed, isNull);

    await tester.pumpWidget(_wrap(_bar(
      hasTarget: false,
      onConfirm: () => confirmed = true,
      isTargetOnly: false,
      selectedCount: 1,
    )));
    await tester.tap(find.text('确定 (1)'));
    await tester.pump();
    expect(confirmed, isTrue);
  });
}
