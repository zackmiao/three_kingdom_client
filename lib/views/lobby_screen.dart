import 'dart:async';
import 'package:flutter/material.dart';
import '../network/command.dart';
import '../network/packet.dart';
import '../network/socket_service.dart';
import 'hero_book_screen.dart';
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
  final TextEditingController _joinRoomIdController = TextEditingController();
  final TextEditingController _maxPlayersController = TextEditingController(text: "4");
  final TextEditingController _roomIdController = TextEditingController();

  /// 选择的游戏模式：IDENTITY / TEAM_2V2 / LANDLORD
  String _mode = "IDENTITY";

  static const List<_ModeInfo> _modes = [
    _ModeInfo('IDENTITY', '身份场', '主公 / 忠臣 / 反贼 / 内奸', '2~8 人', Colors.amber),
    _ModeInfo('TEAM_2V2', '2v2', '暖方 2 人 对 冷方 2 人', '4 人', Colors.tealAccent),
    _ModeInfo('LANDLORD', '斗地主', '地主 1 人 对 农民 2 人', '3 人', Colors.deepOrangeAccent),
  ];

  _ModeInfo get _curMode => _modes.firstWhere((m) => m.key == _mode, orElse: () => _modes.first);

  void _pickMode(String key) {
    setState(() {
      _mode = key;
      if (key == 'TEAM_2V2') _maxPlayersController.text = "4";
      if (key == 'LANDLORD') _maxPlayersController.text = "3";
    });
  }

  StreamSubscription<Packet>? _subscription;
  StreamSubscription<String>? _disconnectSub;
  bool _busy = false;
  String _status = "";
  /// 大厅可见的房间列表
  List<_RoomInfo> _rooms = const [];

  void _parseRoomList(String raw) {
    final List<_RoomInfo> list = [];
    for (final seg in raw.split(';')) {
      if (seg.trim().isEmpty) continue;
      final p = seg.split('|');
      if (p.length < 6) continue;
      list.add(_RoomInfo(
        id: p[0],
        name: p[1],
        players: int.tryParse(p[2]) ?? 0,
        maxPlayers: int.tryParse(p[3]) ?? 0,
        mode: p[4],
        state: p[5],
      ));
    }
    if (mounted) setState(() => _rooms = list);
  }

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
      } else if (packet.command == Command.ROOM_LIST) {
        _parseRoomList(packet.data);
      }
    });

    _disconnectSub = _socket.disconnectStream.listen((reason) {
      if (!mounted) return;
      _toast(reason, error: true);
    });

    // 进大厅就拉一次房间列表
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRooms());
  }

  void _refreshRooms() {
    if (!_socket.isConnected) return;
    _socket.sendPacket(Packet(
      command: Command.ROOM_LIST,
      senderId: widget.playerId,
      data: "",
    ));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _disconnectSub?.cancel();
    _roomNameController.dispose();
    _joinRoomIdController.dispose();
    _maxPlayersController.dispose();
    _roomIdController.dispose();
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
    final roomId = _roomIdController.text.trim();
    setState(() => _busy = true);
    _socket.sendPacket(Packet(
      command: Command.CREATE_ROOM,
      senderId: widget.playerId,
      data: "$name,$maxPlayers,$_mode,$roomId",
    ));
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _joinRoom([String? roomId]) async {
    if (!await _ensureConnection()) return;
    final rId = (roomId ?? _joinRoomIdController.text).trim();
    // 留空表示自动加入一个还在等待的房间
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
          TextButton.icon(
            onPressed: () => HeroBookScreen.show(context),
            icon: const Icon(Icons.menu_book, color: Colors.amberAccent, size: 18),
            label: const Text('武将图鉴',
                style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          ),
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
                Text('${_curMode.title}：${_curMode.desc}（${_curMode.seatLabel}，可加 AI 补位）',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final m in _modes)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _ModeCard(
                            info: m,
                            selected: _mode == m.key,
                            onTap: () => _pickMode(m.key),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
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
                        enabled: _mode == 'IDENTITY',
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
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 118,
                      child: TextField(
                        controller: _roomIdController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '房间号(可选)',
                          labelStyle: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                          filled: true,
                          fillColor: Colors.black26,
                          isDense: true,
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
                    labelText: '房间号（留空则自动加入可玩房间）',
                    labelStyle: const TextStyle(color: Colors.cyanAccent),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 132,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.cyanAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.flash_on, color: Colors.cyanAccent, size: 18),
                        label: const Text('快速加入',
                            style: TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                        onPressed: () => _joinRoom(''),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('房间列表', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                ),
                Row(children: [
                  Text('共 ${_rooms.length} 个房间',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    tooltip: '刷新列表',
                    onPressed: _refreshRooms,
                    icon: const Icon(Icons.refresh, color: Colors.cyanAccent, size: 18),
                  ),
                ]),
                if (_rooms.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('暂无房间，先创建一个吧',
                        style: TextStyle(color: Colors.white24, fontSize: 12)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 168),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _rooms.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (_, i) {
                        final r = _rooms[i];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: Icon(
                            r.state == 'PLAYING' ? Icons.play_circle : Icons.meeting_room,
                            color: r.state == 'PLAYING' ? Colors.orangeAccent : Colors.amberAccent,
                            size: 18,
                          ),
                          title: Text(r.name,
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                          subtitle: Text('${r.id} · ${r.modeLabel} · ${r.players}/${r.maxPlayers} 人'
                              '${r.state == 'PLAYING' ? ' · 对局中' : ''}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          trailing: r.state == 'PLAYING' || r.players >= r.maxPlayers
                              ? const Text('不可加入',
                                  style: TextStyle(color: Colors.white24, fontSize: 11))
                              : TextButton(
                                  onPressed: () => _joinRoom(r.id),
                                  child: const Text('加入',
                                      style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                                ),
                          onTap: r.state == 'PLAYING' || r.players >= r.maxPlayers
                              ? null
                              : () => _joinRoom(r.id),
                        );
                      },
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

/// 大厅房间列表条目。
class _RoomInfo {
  final String id;
  final String name;
  final int players;
  final int maxPlayers;
  final String mode;
  final String state;

  const _RoomInfo({
    required this.id,
    required this.name,
    required this.players,
    required this.maxPlayers,
    required this.mode,
    required this.state,
  });

  String get modeLabel {
    switch (mode) {
      case 'TEAM_2V2':
        return '2v2';
      case 'LANDLORD':
        return '斗地主';
      default:
        return '身份场';
    }
  }
}

/// 大厅里的模式元数据。
class _ModeInfo {  final String key;
  final String title;
  final String desc;
  final String seatLabel;
  final Color color;

  const _ModeInfo(this.key, this.title, this.desc, this.seatLabel, this.color);
}

class _ModeCard extends StatelessWidget {
  final _ModeInfo info;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? info.color.withValues(alpha: 0.18) : Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? info.color : Colors.white24, width: selected ? 2 : 1),
          boxShadow: [
            if (selected) BoxShadow(color: info.color.withValues(alpha: 0.35), blurRadius: 12),
          ],
        ),
        child: Column(
          children: [
            Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? info.color : Colors.white30, size: 18),
            const SizedBox(height: 4),
            Text(info.title,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(info.seatLabel,
                style: TextStyle(color: selected ? info.color : Colors.white38, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}
