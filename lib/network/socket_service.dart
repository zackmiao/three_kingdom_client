import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/hero_model.dart';
import 'command.dart';
import 'packet.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  Socket? _socket;
  final _packetController = StreamController<Packet>.broadcast();
  final _disconnectController = StreamController<String>.broadcast();

  Stream<Packet> get packetStream => _packetController.stream;

  /// 连接异常/断开时触发，参数为提示文本。
  Stream<String> get disconnectStream => _disconnectController.stream;

  String? lastHost;
  int? lastPort;
  String? playerId;
  String? playerName;

  bool get isConnected => _socket != null;

  Future<void> connect(String host, int port) async {
    await disconnect();
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    _socket = socket;
    lastHost = host;
    lastPort = port;

    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.trim().isEmpty) return;
        try {
          final packet = Packet.decode(line.trim());
          // 武将池与“当前界面”无关，全局缓存一份，避免界面切换时丢包
          if (packet.command == Command.HERO_LIST) {
            HeroCatalog.instance.update(packet.data);
          }
          _packetController.add(packet);
        } catch (_) {}
      },
      onError: (err) {
        _notifyDisconnect('连接异常: $err');
      },
      onDone: () {
        _notifyDisconnect('与服务端的连接已断开');
      },
      cancelOnError: false,
    );
  }

  /// 断线后自动重连（大厅/房间在操作前调用）。
  Future<bool> ensureConnected() async {
    if (_socket != null) return true;
    final host = lastHost;
    final port = lastPort;
    if (host == null || port == null) return false;
    try {
      await connect(host, port);
      if (playerId != null) {
        sendPacket(Packet(
          command: Command.CONNECT_SUCCESS,
          senderId: playerId!,
          data: playerName ?? '玩家',
        ));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void sendPacket(Packet packet) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.writeln(packet.encode());
      socket.flush();
    } catch (_) {}
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    try {
      socket?.destroy();
    } catch (_) {}
  }

  void _notifyDisconnect(String reason) {
    _socket = null;
    if (!_disconnectController.isClosed) {
      _disconnectController.add(reason);
    }
  }
}
