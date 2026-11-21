import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'network/packet.dart';
import 'network/socket_service.dart';
import 'network/command.dart';
import 'services/audio_service.dart';
import 'services/file_dialog.dart';
import 'services/user_service.dart';
import 'views/lobby_screen.dart';
import 'views/dialogs/settings_dialog.dart';

void main() {
  // 预热音频：提前解压 wav 到临时目录，避免第一声牌音卡顿
  unawaited(AudioService.instance.init());
  // 读取本地设置（音量 / 动画速度 / 缩放等）
  unawaited(AppSettings.instance.load());
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _connecting = false;
  String _statusMsg = "";
  StreamSubscription<Packet>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    _ipController.dispose();
    _portController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 建立连接 + 完成握手，返回服务端分配的会话 ID（失败返回 null）
  Future<String?> _handshake(String displayName) async {
    final host = _ipController.text.trim() == "localhost" ? "127.0.0.1" : _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9050;
    final socket = SocketService();
    try {
      await socket.connect(host, port);
    } catch (e) {
      setState(() => _statusMsg = "连接失败: $e");
      return null;
    }

    final myId = "P_${DateTime.now().millisecondsSinceEpoch}";
    socket.playerId = myId;
    socket.playerName = displayName;
    final completer = Completer<String?>();
    _sub?.cancel();
    _sub = socket.packetStream.listen((packet) {
      if (packet.command == Command.CONNECT_SUCCESS && !completer.isCompleted) {
        socket.playerId = packet.data;
        completer.complete(packet.data);
      }
    });
    socket.sendPacket(Packet(
      command: Command.CONNECT_SUCCESS,
      senderId: myId,
      data: displayName,
    ));
    final id = await completer.future.timeout(const Duration(seconds: 8),
        onTimeout: () => null);
    if (id == null) {
      setState(() => _statusMsg = "握手超时，请确认服务端已启动");
      return null;
    }
    return id;
  }

  /// 账号登录 / 注册后进入大厅
  Future<void> _accountAction({required bool register}) async {
    final name = _nameController.text.trim();
    final pwd = _passwordController.text.trim();
    if (name.isEmpty) {
      setState(() => _statusMsg = "请填写账号");
      return;
    }
    if (pwd.length < 3) {
      setState(() => _statusMsg = "密码至少 3 位");
      return;
    }
    setState(() {
      _connecting = true;
      _statusMsg = register ? "正在注册..." : "正在登录...";
    });

    final id = await _handshake(name);
    if (id == null) {
      setState(() => _connecting = false);
      return;
    }
    final socket = SocketService();
    final completer = Completer<String?>();
    final sub = socket.packetStream.listen((packet) {
      if (packet.command == Command.ACCOUNT_RESULT && !completer.isCompleted) {
        completer.complete(packet.data);
      }
    });
    socket.sendPacket(Packet(
      command: register ? Command.REGISTER : Command.LOGIN,
      senderId: id,
      data: "$name|$pwd",
    ));
    final result = await completer.future.timeout(const Duration(seconds: 10),
        onTimeout: () => null);
    await sub.cancel();
    if (result == null) {
      setState(() {
        _connecting = false;
        _statusMsg = "账号服务无响应";
      });
      return;
    }
    if (!result.startsWith("OK")) {
      final reason = result.contains("|") ? result.split("|")[1] : result;
      setState(() {
        _connecting = false;
        _statusMsg = reason;
      });
      return;
    }
    final parts = result.split("|");
    Uint8List? avatar;
    if (parts.length > 2 && parts[2].isNotEmpty) {
      try {
        avatar = base64Decode(parts[2]);
      } catch (_) {
        avatar = null;
      }
    }
    Account.instance.signIn(name, avatarBytes: avatar);
    _enterLobby(id, name);
  }

  /// 游客模式：不注册账号直接玩
  Future<void> _guestEnter() async {
    final name = _nameController.text.trim().isEmpty
        ? "玩家${DateTime.now().second}"
        : _nameController.text.trim();
    setState(() {
      _connecting = true;
      _statusMsg = "正在连接服务端...";
    });
    final id = await _handshake(name);
    if (id == null) {
      setState(() => _connecting = false);
      return;
    }
    Account.instance.signOut();
    _enterLobby(id, name);
  }

  void _enterLobby(String id, String name) {
    _sub?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LobbyScreen(playerId: id, playerName: name),
      ),
    );
  }

  /// 上传头像：选本地图片 → base64 → 发服务端保存
  Future<void> _uploadAvatar() async {
    final path = FileDialog.pickOpenFile(title: '选择头像图片');
    if (path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.length > 1024 * 1024) {
        setState(() => _statusMsg = "图片太大（请选 1MB 以内）");
        return;
      }
      final b64 = base64Encode(bytes);
      final socket = SocketService();
      final completer = Completer<String?>();
      final sub = socket.packetStream.listen((packet) {
        if (packet.command == Command.AVATAR_RESULT && !completer.isCompleted) {
          completer.complete(packet.data);
        }
      });
      socket.sendPacket(Packet(
        command: Command.UPDATE_AVATAR,
        senderId: socket.playerId ?? '',
        data: b64,
      ));
      final result = await completer.future
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      await sub.cancel();
      if (result != null && result.startsWith("OK")) {
        Account.instance.signIn(_nameController.text.trim(), avatarBytes: bytes);
        setState(() => _statusMsg = "头像已更新");
      } else {
        setState(() => _statusMsg = "头像上传失败");
      }
    } catch (e) {
      setState(() => _statusMsg = "读取图片失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Account.instance.avatar;
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 400,
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
                    const Text('三国杀 · 局域网联机',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: Account.instance.loggedIn ? _uploadAvatar : null,
                          child: Tooltip(
                            message: Account.instance.loggedIn
                                ? '点击上传头像'
                                : '登录后可上传头像',
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFF3C3F4A),
                              backgroundImage:
                                  avatar == null ? null : MemoryImage(avatar),
                              child: avatar == null
                                  ? const Icon(Icons.person,
                                      size: 30, color: Colors.white38)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Account.instance.loggedIn
                                    ? '已登录：${Account.instance.name}'
                                    : '未登录（可用游客模式）',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white54),
                              ),
                              const SizedBox(height: 4),
                              if (Account.instance.loggedIn)
                                TextButton(
                                  onPressed: _uploadAvatar,
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 24),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap),
                                  child: const Text('上传头像',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFFFC107))),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ipController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: '服务器 IP 地址 (本机请填 127.0.0.1)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _portController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: '端口 (默认 9050)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: '账号 / 昵称 (1~16 字)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _accountAction(register: false),
                      decoration: const InputDecoration(
                          labelText: '密码 (游客模式可留空)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[800]),
                        onPressed: _connecting
                            ? null
                            : () => _accountAction(register: false),
                        child: _connecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('登录并进入',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _connecting ? null : () => _accountAction(register: true),
                            child: const Text('注册新账号'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _connecting ? null : _guestEnter,
                            child: const Text('游客进入'),
                          ),
                        ),
                      ],
                    ),
                    if (_statusMsg.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(_statusMsg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: IconButton(
              tooltip: '设置',
              icon: const Icon(Icons.settings, color: Colors.white54),
              onPressed: () => SettingsDialog.show(context),
            ),
          ),
        ],
      ),
    );
  }
}
