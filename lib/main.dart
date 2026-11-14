import 'dart:async';

import 'package:flutter/material.dart';
import 'network/packet.dart';
import 'network/socket_service.dart';
import 'network/command.dart';
import 'views/lobby_screen.dart';

void main() {
  runApp(const ThreeKingdomApp());
}

class ThreeKingdomApp extends StatelessWidget {
  const ThreeKingdomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '三国杀局域网联机',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E24),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _ipController = TextEditingController(text: "127.0.0.1");
  final TextEditingController _portController = TextEditingController(text: "9050");
  final TextEditingController _nameController = TextEditingController(text: "玩家1");
  bool _connecting = false;
  String _statusMsg = "";

  void _connect() async {
    setState(() {
      _connecting = true;
      _statusMsg = "正在连接服务端...";
    });

    final host = _ipController.text.trim() == "localhost" ? "127.0.0.1" : _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9050;
    final socket = SocketService();

    try {
      await socket.connect(host, port);
    } catch (e) {
      setState(() {
        _connecting = false;
        _statusMsg = "连接失败: $e";
      });
      return;
    }

    // 连接成功后，立即先注册全局包监听
    String myId = "P_${DateTime.now().millisecondsSinceEpoch}";
    socket.playerId = myId;
    socket.playerName = _nameController.text.trim();
    late final StreamSubscription sub;
    sub = socket.packetStream.listen((packet) {
      if (packet.command == Command.CONNECT_SUCCESS && mounted) {
        socket.playerId = packet.data; // 以服务端回传的会话 ID 为准
        sub.cancel(); // 取消登录监听，避免与大厅流冲突
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LobbyScreen(
              playerId: packet.data,
              playerName: _nameController.text.trim(),
            ),
          ),
        );
      }
    });

    // 发送登录/握手包
    socket.sendPacket(Packet(
      command: Command.CONNECT_SUCCESS,
      senderId: myId,
      data: _nameController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2B2C34),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('三国杀 · 局域网联机', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: '服务器 IP 地址 (本机请填 127.0.0.1)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _portController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: '端口 (默认 9050)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: '玩家昵称', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                  onPressed: _connecting ? null : _connect,
                  child: _connecting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('进入游戏大厅', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              if (_statusMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(_statusMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                )
            ],
          ),
        ),
      ),
    );
  }
}