import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/views/components/action_prompt_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 900, child: child))),
    );

ActionPromptBar _bar({
  required int selected,
  int? exactCount,
  String prompt = '【弃牌阶段】你的手牌超过上限，请弃置 2 张手牌（已选 0 / 2 张）',
  VoidCallback? onConfirm,
  VoidCallback? onPass,
}) {
  return ActionPromptBar(
    prompt: prompt,
    isResponding: false,
    selectedCount: selected,
    isZhangBaMode: false,
    isRenDeMode: false,
    isZhiHengMode: false,
    isChuHaiMode: false,
    hasZhangBaWeapon: false,
    hasRenDeSkill: false,
    hasZhiHengSkill: false,
    hasChuHaiSkill: false,
    onConfirm: onConfirm ?? () {},
    onCancelSelection: () {},
    onToggleZhangBa: () {},
    onToggleRenDe: () {},
    onToggleZhiHeng: () {},
    onToggleChuHai: () {},
    onPass: onPass ?? () {},
    exactCount: exactCount,
  );
}

void main() {
  testWidgets('弃牌阶段：未选满时【确定】不可点击', (tester) async {
    var confirmCount = 0;
    await tester.pumpWidget(_wrap(_bar(selected: 1, exactCount: 2, onConfirm: () => confirmCount++)));

    final confirm = find.text('确定 (1/2)');
    expect(confirm, findsOneWidget);

    await tester.tap(confirm);
    await tester.pump();
    expect(confirmCount, 0, reason: '只选了 1 张，按钮应被禁用');
  });

  testWidgets('弃牌阶段：选满后【确定】可点击并回调', (tester) async {
    var confirmCount = 0;
    await tester.pumpWidget(_wrap(_bar(selected: 2, exactCount: 2, onConfirm: () => confirmCount++)));

    final confirm = find.text('确定 (2/2)');
    expect(confirm, findsOneWidget);

    await tester.tap(confirm);
    await tester.pump();
    expect(confirmCount, 1);
  });

  testWidgets('弃牌阶段：不显示「结束出牌 / 放弃」按钮（不可跳过）', (tester) async {
    await tester.pumpWidget(_wrap(_bar(selected: 0, exactCount: 2)));
    expect(find.text('结束出牌'), findsNothing);
    expect(find.text('放弃'), findsNothing);
    expect(find.text('PASS/放弃'), findsNothing);
  });

  testWidgets('非弃牌询问仍然保留「结束出牌」按钮', (tester) async {
    await tester.pumpWidget(_wrap(_bar(
      selected: 0,
      prompt: '出牌阶段，请出牌',
    )));
    expect(find.text('结束出牌'), findsOneWidget);
  });
}
