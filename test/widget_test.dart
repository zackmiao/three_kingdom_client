import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/main.dart';

void main() {
  testWidgets('登录页可以正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(const ThreeKingdomApp());
    expect(find.text('三国杀 · 局域网联机'), findsOneWidget);
    expect(find.text('进入游戏大厅'), findsOneWidget);
  });
}
