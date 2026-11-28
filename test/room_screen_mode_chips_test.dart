import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/services/user_service.dart';
import 'package:three_kingdom_client/views/room_screen.dart';

/// 回归测试：房间页的「模式切换 chips」依赖 `_visibleModeLabels`。
/// 该 getter 曾对 `const` 的 `_modeLabels` 直接 `..remove('TEST')`，
/// 运行时会抛 `UnsupportedError: Cannot modify unmodifiable map`；
/// 现在改为先 `Map<String, String>.of(...)` 复制再删除，本测试保证不再回归。
void main() {
  const roomRaw =
      'ROOM_888|测试房|4|p1|WAITING|p1#甲#false#刘备#true|IDENTITY';

  testWidgets('房间页在非内测账号下渲染模式切换（不抛 UnsupportedError）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RoomScreen(
          playerId: 'p1',
          playerName: '甲',
          initialRoomRaw: roomRaw,
        ),
      ),
    );
    await tester.pump();

    // 关键：构建过程中读取 _visibleModeLabels，若 map 不可修改会在这里抛异常
    expect(tester.takeException(), isNull);

    // 非内测：不应出现「测试模式」切换按钮，其余三种模式都在
    expect(find.text('身份场'), findsWidgets);
    expect(find.text('2v2'), findsWidgets);
    expect(find.text('斗地主'), findsWidgets);
    expect(find.text('测试模式'), findsNothing);
  });

  testWidgets('内测账号下模式切换包含「测试模式」', (tester) async {
    Account.instance.setBeta(true);
    addTearDown(() => Account.instance.setBeta(false));

    await tester.pumpWidget(
      const MaterialApp(
        home: RoomScreen(
          playerId: 'p1',
          playerName: '甲',
          initialRoomRaw: roomRaw,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('测试模式'), findsWidgets);
  });

  testWidgets('房间设置第 8 段（响应时间）会显示在标题与房主调节区', (tester) async {
    const roomRawWithSetting =
        'ROOM_889|设置房|4|p1|WAITING|p1#甲#false#刘备#true|IDENTITY|45';
    await tester.pumpWidget(
      const MaterialApp(
        home: RoomScreen(
          playerId: 'p1',
          playerName: '甲',
          initialRoomRaw: roomRawWithSetting,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // 房主：标题栏与调节区都显示 45s，并且有 ± 按钮
    expect(find.textContaining('响应45s'), findsWidgets);
    expect(find.text('响应时间：'), findsOneWidget);
    expect(find.text('45s'), findsWidgets);
    expect(find.text('-'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
  });
}
