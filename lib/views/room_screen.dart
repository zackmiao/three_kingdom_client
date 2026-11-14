import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hero_model.dart';
import '../models/room_member_model.dart';
import '../network/command.dart';
import '../network/packet.dart';
import '../network/socket_service.dart';
import 'components/hero_portrait.dart';
import 'dialogs/hero_select_dialog.dart';
import 'game_room_screen.dart';
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
  List<RoomMemberModel> _members = [];
  List<HeroModel> _heroes = HeroCatalog.instance.heroes;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _parseRoomData(widget.initialRoomRaw);
    _maybeGoToGame();

    _subscription = _socket.packetStream.listen((packet) {
      if (!mounted) return;
      if (packet.command == Command.ROOM_SYNC) {
        _parseRoomData(packet.data);
        setState(() {});
        _maybeGoToGame();
      } else if (packet.command == Command.HERO_LIST) {
        HeroCatalog.instance.update(packet.data);
        setState(() => _heroes = HeroCatalog.instance.heroes);
      } else if (packet.command == Command.LEAVE_ROOM) {
        _backToLobby();
      }
    });
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

    final memRaw = parts.length > 5 ? parts[5].trim() : "";
    _members = memRaw.isEmpty
        ? []
        : memRaw
            .split(';')
            .map((t) => RoomMemberModel.parse(t))
            .whereType<RoomMemberModel>()
            .toList();
  }

  void _showChangeHeroDialog({String? targetMemberId, String? targetTitle}) {
    if (_heroes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('武将列表还没同步到本机，请点“准备/取消准备”刷新一次房间状态'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ));
      // 主动刷新：切换一次准备状态会让服务端重新下发房间同步与武将池
      _socket.sendPacket(Packet(
          command: Command.TOGGLE_READY, senderId: widget.playerId, data: "REFRESH"));
      return;
    }

    final occupiedHeroes = _members
        .where((m) => m.id != (targetMemberId ?? widget.playerId))
        .map((m) => m.heroName)
        .toSet();
    final available = _heroes.where((h) => !occupiedHeroes.contains(h.name)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('所有可选武将均已被挑选'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final myHero = _members
        .firstWhere((m) => m.id == (targetMemberId ?? widget.playerId),
            orElse: () => _members.first)
        .heroName;

    HeroSelectDialog.show(
      context,
      available,
      title: targetTitle ?? '挑选出战武将（不可重复）',
      currentHero: myHero,
      onSelect: (hero) {
        if (targetMemberId != null && targetMemberId != widget.playerId) {
          _socket.sendPacket(Packet(
              command: Command.SELECT_HERO,
              senderId: widget.playerId,
              data: '$targetMemberId:${hero.name}'));
        } else {
          _socket.sendPacket(
              Packet(command: Command.SELECT_HERO, senderId: widget.playerId, data: hero.name));
        }
      },
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
        title: Text('$_roomName ($_roomId)  [${_members.length}/$_maxPlayers 人]'),
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

                return GestureDetector(
                  onTap: () {
                    if (isHost && m.isAi) {
                      _showChangeHeroDialog(
                          targetMemberId: m.id, targetTitle: '为【${m.name}】选择出战武将');
                    }
                  },
                  child: Container(
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
                            Text(m.name + (isMe ? " (你)" : ""),
                                style: TextStyle(
                                    color: isMe ? Colors.cyanAccent : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 74,
                                height: 100,
                                child: HeroPortrait(hero: m.heroName),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('出战: 【${m.heroName}】',
                                style: const TextStyle(
                                    color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            if (isHost && m.isAi)
                              const Text('(点击换将)', style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                            const SizedBox(height: 4),
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
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: const Color(0xFF24252E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[800],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  icon: const Icon(Icons.switch_account, color: Colors.white),
                  label: Text('更换武将 (当前: ${myMember.heroName})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _showChangeHeroDialog(),
                ),
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
