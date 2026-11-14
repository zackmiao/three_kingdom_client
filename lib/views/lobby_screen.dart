import 'dart:async';
import 'package:flutter/material.dart';
import '../network/command.dart';
import '../network/packet.dart';
import '../network/socket_service.dart';
import 'room_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String playerId;
  final String playerName;

  const LobbyScreen({super.key, required this.playerId, required this.playerName});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final SocketService _socket = SocketService();
  final TextEditingController _roomNameController = TextEditingController(text: "三国杀标准房间");
  final TextEditingController _joinRoomIdController = TextEditingController(text: "ROOM_888");
  final TextEditingController _maxPlayersController = TextEditingController(text: "4");

  StreamSubscription<Packet>? _subscription;
  StreamSubscription<String>? _disconnectSub;
  bool _busy = false;
  String _status = "";

  @override
  void initState() {
    super.initState();
    _socket.playerId ??= widget.playerId;
    _socket.playerName ??= widget.playerName;

    _subscription = _socket.packetStream.listen((packet) {
      if (!mounted) return;
      if (packet.command == Command.ROOM_SYNC) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => RoomScreen(
            playerId: widget.playerId,
            playerName: widget.playerName,
            initialRoomRaw: packet.data,
          ),
        ));
      } else if (packet.command == Command.BROADCAST_MSG) {
        setState(() => _status = packet.data);
        if (packet.data.contains("ERROR") || packet.data.contains("无法") || packet.data.contains("暂无")) {
          _toast(packet.data, error: true);
        }
      }
    });

    _disconnectSub = _socket.disconnectStream.listen((reason) {
      if (!mounted) return;
      _toast(reason, error: true);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _disconnectSub?.cancel();
    _roomNameController.dispose();
    _joinRoomIdController.dispose();
    _maxPlayersController.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : Colors.teal,
      duration: const Duration(seconds: 3),
    ));
  }

  /// 断线后自动重连，保证「返回大厅再开一局」可用
  Future<bool> _ensureConnection() async {
    if (_socket.isConnected) return true;
    setState(() => _busy = true);
    final ok = await _socket.ensureConnected();
    if (!mounted) return ok;
    setState(() {
      _busy = false;
      _status = ok ? "已重新连接到服务端" : "重连失败，请返回登录页重新连接";
    });
    if (!ok) _toast("重连失败，请返回登录页重新连接", error: true);
    return ok;
  }

  Future<void> _createRoom() async {
    if (!await _ensureConnection()) return;
    String name = _roomNameController.text.trim();
    if (name.isEmpty) name = "三国杀房间";
    final maxPlayers = (int.tryParse(_maxPlayersController.text.trim()) ?? 4).clamp(2, 8);
    setState(() => _busy = true);
    _socket.sendPacket(Packet(
      command: Command.CREATE_ROOM,
      senderId: widget.playerId,
      data: "$name,$maxPlayers",
    ));
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _joinRoom() async {
    if (!await _ensureConnection()) return;
    String rId = _joinRoomIdController.text.trim();
    if (rId.isEmpty) {
      _toast("请输入要加入的房间号");
      return;
    }
    _socket.sendPacket(Packet(command: Command.JOIN_ROOM, senderId: widget.playerId, data: rId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181920),
      appBar: AppBar(
        title: Text('游戏大厅 - 欢迎您，${widget.playerName}'),
        backgroundColor: const Color(0xFF24252E),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(children: [
              Icon(Icons.circle,
                  size: 10, color: _socket.isConnected ? Colors.greenAccent : Colors.redAccent),
              const SizedBox(width: 6),
              Text(_socket.isConnected ? "已连接" : "未连接",
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF262732),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.meeting_room, color: Colors.amberAccent, size: 28),
                    SizedBox(width: 10),
                    Text('创建或加入房间',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('身份场：主公 / 忠臣 / 反贼 / 内奸，支持 2~8 人（可加 AI 补位）',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _roomNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '房间名称',
                          labelStyle: const TextStyle(color: Colors.amberAccent),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _maxPlayersController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '人数',
                          labelStyle: const TextStyle(color: Colors.amberAccent),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add_box, color: Colors.white),
                    label: Text(_busy ? '处理中...' : '创建房间',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: _busy ? null : _createRoom,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18.0),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('或者加入已有房间', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                ),
                TextField(
                  controller: _joinRoomIdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '房间号',
                    labelStyle: const TextStyle(color: Colors.cyanAccent),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.login, color: Colors.white),
                    label: const Text('加入房间',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: _joinRoom,
                  ),
                ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(_status,
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                        textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
