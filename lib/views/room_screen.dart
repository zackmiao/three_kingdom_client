import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/hero_model.dart';
import '../models/room_member_model.dart';
import '../network/command.dart';
import '../network/packet.dart';
import '../network/socket_service.dart';
import '../services/user_service.dart';
import 'game_room_screen.dart';
import 'hero_book_screen.dart';
import 'lobby_screen.dart';

class RoomScreen extends StatefulWidget {
  final String playerId;
  final String playerName;
  final String initialRoomRaw;

  const RoomScreen({
    super.key,
    required this.playerId,
    required this.playerName,
    required this.initialRoomRaw,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final SocketService _socket = SocketService();
  StreamSubscription<Packet>? _subscription;

  String _roomId = "";
  String _roomName = "";
  int _maxPlayers = 4;
  String _hostId = "";
  String _state = "WAITING";
  String _mode = "IDENTITY";

  /// 房主设置的「出牌/响应思考时间」（秒）；0 = 不限时（测试模式）。
  int _responseSeconds = 25;
  List<RoomMemberModel> _members = [];
  final ValueNotifier<List<HeroModel>> _candidates = ValueNotifier<List<HeroModel>>(const []);
  final Set<String> _avatarRequested = <String>{};
  bool _navigating = false;

  static const Map<String, String> _modeLabels = {
    'IDENTITY': '身份场',
    'TEAM_2V2': '2v2',
    'LANDLORD': '斗地主',
    'TEST': '测试模式',
  };

  /// 房主可切换的模式（测试模式仅内测账号可见）
  ///
  /// 注意：[_modeLabels] 是 `const` 常量字面量，本身是**不可修改**的 map，
  /// 直接对它做 `remove('TEST')` 会抛 `UnsupportedError: Cannot modify unmodifiable map`；
  /// 所以这里先用 `Map<String, String>.of(...)` 复制出一份可变副本再删键。
  Map<String, String> get _visibleModeLabels {
    final labels = Map<String, String>.of(_modeLabels);
    if (!Account.instance.beta) {
      labels.remove('TEST');
    }
    return labels;
  }

  String get _modeLabel => _modeLabels[_mode] ?? '身份场';

  @override
  void initState() {
    super.initState();
    _parseRoomData(widget.initialRoomRaw);
    _maybeGoToGame();

    _subscription = _socket.packetStream.listen((packet) {
      if (!mounted) return;
      if (packet.command == Command.ROOM_SYNC) {
        _parseRoomData(packet.data);
        _requestMissingAvatars();
        setState(() {});
        _maybeGoToGame();
      } else if (packet.command == Command.HERO_LIST) {
        HeroCatalog.instance.update(packet.data);
      } else if (packet.command == Command.HERO_CANDIDATES) {
        // 房间级候选（开局后由对局内的「选将阶段」用 DRAW| 前缀另行下发）
        if (!packet.data.startsWith('DRAW|')) {
          _candidates.value = HeroModel.parseAll(packet.data);
        }
      } else if (packet.command == Command.AVATAR) {
        _onAvatar(packet.data);
      } else if (packet.command == Command.LEAVE_ROOM) {
        _backToLobby();
      }
    });
  }

  /// 房间里有服务器账号的玩家就拉一次头像
  void _requestMissingAvatars() {
    for (final m in _members) {
      if (m.isAi || m.name.isEmpty) continue;
      if (Account.instance.avatarOf(m.name) != null) continue;
      if (_avatarRequested.contains(m.name)) continue;
      _avatarRequested.add(m.name);
      _socket.sendPacket(Packet(
        command: Command.GET_AVATAR,
        senderId: widget.playerId,
        data: m.name,
      ));
    }
  }

  void _onAvatar(String data) {
    final seg = data.split('|');
    if (seg.length < 2 || seg[1].isEmpty) return;
    try {
      Account.instance.cacheAvatar(seg[0], base64Decode(seg[1]));
      setState(() {});
    } catch (_) {
      // 头像数据异常就跳过，不影响房间
    }
  }

  /// 房间席位上的小头像（没有账号头像时用默认人像）
  Widget _memberAvatar(String name) {
    final bytes = Account.instance.avatarOf(name);
    return CircleAvatar(
      radius: 11,
      backgroundColor: const Color(0xFF3C3F4A),
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes == null
          ? const Icon(Icons.person, size: 14, color: Colors.white38)
          : null,
    );
  }

  void _maybeGoToGame() {
    if (_state != "PLAYING" || _navigating) return;
    _navigating = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => GameRoomScreen(playerId: widget.playerId, playerName: widget.playerName),
    ));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _candidates.dispose();
    super.dispose();
  }

  void _parseRoomData(String raw) {
    final parts = raw.split('|');
    if (parts.length < 5) return;

    _roomId = parts[0];
    _roomName = parts[1];
    _maxPlayers = int.tryParse(parts[2]) ?? 4;
    _hostId = parts[3];
    _state = parts[4];
    if (parts.length > 6 && parts[6].trim().isNotEmpty) {
      _mode = parts[6].trim();
    }
    // 第 8 段：房主设置的「出牌/响应思考时间」（秒），0 表示不限时（测试模式）
    if (parts.length > 7 && parts[7].trim().isNotEmpty) {
      _responseSeconds = int.tryParse(parts[7].trim()) ?? _responseSeconds;
    }

    final memRaw = parts.length > 5 ? parts[5].trim() : "";
    _members = memRaw.isEmpty
        ? []
        : memRaw
            .split(';')
            .map((t) => RoomMemberModel.parse(t))
            .whereType<RoomMemberModel>()
            .toList();
  }

  void _setMode(String modeKey) {
    _socket.sendPacket(
        Packet(command: Command.SET_MODE, senderId: widget.playerId, data: modeKey));
  }

  /// 房主调整「响应时间」（每次 ±5 秒，服务端限制 5~600 秒）
  void _bumpResponseSeconds(int delta) {
    final next = (_responseSeconds + delta).clamp(5, 600);
    if (next == _responseSeconds) return;
    _socket.sendPacket(Packet(
        command: Command.SET_ROOM_SETTING,
        senderId: widget.playerId,
        data: '$next'));
  }

  Widget _stepChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x44FFD9A0)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFFFFE0B2), fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _leaveRoom() {
    _socket.sendPacket(Packet(command: Command.LEAVE_ROOM, senderId: widget.playerId, data: "LEAVE"));
    _backToLobby();
  }

  void _backToLobby() {
    if (!mounted || _navigating) return;
    _navigating = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LobbyScreen(playerId: widget.playerId, playerName: widget.playerName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isHost = widget.playerId == _hostId;
    final RoomMemberModel myMember = _members.firstWhere(
      (m) => m.id == widget.playerId,
      orElse: () => RoomMemberModel(
          id: widget.playerId, name: widget.playerName, isAi: false, heroName: "刘备", isReady: false),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF181920),
      appBar: AppBar(
        title: Text(
            '$_roomName ($_roomId)  [$_modeLabel · ${_members.length}/$_maxPlayers 人 · '
            '响应${_responseSeconds <= 0 ? '不限时' : '${_responseSeconds}s'}]'),
        backgroundColor: const Color(0xFF24252E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.redAccent),
          tooltip: '退出房间',
          onPressed: _leaveRoom,
        ),
        actions: [
          if (isHost && _members.length < _maxPlayers)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[800]),
                icon: const Icon(Icons.smart_toy, size: 16, color: Colors.cyanAccent),
                label: const Text('添加AI人机', style: TextStyle(fontSize: 12, color: Colors.white)),
                onPressed: () {
                  _socket.sendPacket(
                      Packet(command: Command.ADD_AI, senderId: widget.playerId, data: "ADD_AI"));
                },
              ),
            ),
          TextButton.icon(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
            label: const Text('退出', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: _leaveRoom,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.82,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _maxPlayers,
              itemBuilder: (context, idx) {
                if (idx >= _members.length) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Center(
                      child: Text('等待加入...', style: TextStyle(color: Colors.white24)),
                    ),
                  );
                }
                final m = _members[idx];
                final bool isThisHost = m.id == _hostId;
                final bool isMe = m.id == widget.playerId;

                return Container(
                  decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF1E2838) : const Color(0xFF262732),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isMe
                              ? Colors.cyanAccent
                              : (isThisHost
                                  ? Colors.amberAccent
                                  : (m.isReady ? Colors.greenAccent : Colors.white24)),
                          width: 2),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _memberAvatar(m.name),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(m.name + (isMe ? " (你)" : ""),
                                      style: TextStyle(
                                          color: isMe ? Colors.cyanAccent : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 出战武将改为开局后选将，房间内不再展示
                            const SizedBox(height: 2),
                            Text(
                                isThisHost
                                    ? "【房主】"
                                    : (m.isAi ? "AI 已就绪" : (m.isReady ? "已就绪" : "未准备")),
                                style: TextStyle(
                                    color: isThisHost
                                        ? Colors.amber
                                        : (m.isReady ? Colors.greenAccent : Colors.redAccent),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (isHost && m.isAi)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                              tooltip: '移除人机',
                              onPressed: () {
                                _socket.sendPacket(
                                    Packet(command: Command.REMOVE_AI, senderId: widget.playerId, data: m.id));
                              },
                            ),
                          ),
                      ],
                    ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFF24252E),
            child: Row(
              children: [
                // 选将在开局后进行，房间里只保留图鉴入口
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x33FFD9A0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.style, color: Color(0xFFFFD9A0), size: 18),
                      const SizedBox(width: 7),
                      Text('开局后选将 · 候选中 ${_candidates.value.length} 名',
                          style: const TextStyle(color: Color(0xFFFFE0B2), fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  icon: const Icon(Icons.menu_book, color: Colors.white70, size: 18),
                  label: const Text('武将图鉴', style: TextStyle(color: Colors.white70)),
                  onPressed: () => HeroBookScreen.show(context),
                ),
                const SizedBox(width: 16),
                if (isHost)
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('模式：',
                              style: TextStyle(color: Colors.white38, fontSize: 12)),
                          for (final entry in _visibleModeLabels.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ModeChip(
                                label: entry.value,
                                selected: _mode == entry.key,
                                onTap: () => _setMode(entry.key),
                              ),
                            ),
                          const SizedBox(width: 6),
                          const Text('响应时间：',
                              style: TextStyle(color: Colors.white38, fontSize: 12)),
                          _stepChip('-', () => _bumpResponseSeconds(-5)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            child: Text(
                              _responseSeconds <= 0 ? '不限时' : '${_responseSeconds}s',
                              style: const TextStyle(
                                  color: Color(0xFFFFD9A0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          _stepChip('+', () => _bumpResponseSeconds(5)),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    if (!isHost)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myMember.isReady ? Colors.grey[700] : Colors.green[700],
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          _socket.sendPacket(
                              Packet(command: Command.TOGGLE_READY, senderId: widget.playerId, data: "TOGGLE"));
                        },
                        child: Text(myMember.isReady ? '取消准备' : '准备就绪',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    if (isHost)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[800],
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        ),
                        onPressed: () {
                          _socket.sendPacket(
                              Packet(command: Command.START_GAME, senderId: widget.playerId, data: "START"));
                        },
                        child: const Text('开始游戏',
                            style: TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 房间底栏的模式选择小按钮（仅房主可见）。
class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.amber[800] : Colors.white10,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.amberAccent : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
