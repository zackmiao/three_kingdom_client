// 静态预览入口（大厅/模式选择）：不连服务端也能看界面。
// 运行： flutter run -d windows -t lib/preview_lobby.dart
import 'package:flutter/material.dart';

import 'views/lobby_screen.dart';

void main() {
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lobby Preview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _LobbyPreview(),
    );
  }
}

class _LobbyPreview extends StatelessWidget {
  const _LobbyPreview();

  @override
  Widget build(BuildContext context) {
    return const LobbyScreen(playerId: 'PREVIEW', playerName: '预览玩家');
  }
}
