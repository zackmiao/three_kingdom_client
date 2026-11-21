import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../network/command.dart';
import '../../network/packet.dart';
import '../../network/socket_service.dart';
import '../../services/file_dialog.dart';
import '../../services/user_service.dart';
import 'settings_dialog.dart';

/// 玩家个人信息：头像、账号、内测权限、上传头像、进入设置、退出登录。
///
/// 连上服务器之后（大厅 / 房间）随时可以打开。
class ProfileDialog extends StatefulWidget {
  const ProfileDialog({
    super.key,
    required this.playerName,
    this.onSignOut,
  });

  /// 当前显示名（游客模式下没有账号，只有名字）
  final String playerName;
  final VoidCallback? onSignOut;

  static Future<void> show(
    BuildContext context, {
    required String playerName,
    VoidCallback? onSignOut,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ProfileDialog(playerName: playerName, onSignOut: onSignOut),
    );
  }

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  bool _uploading = false;

  Future<void> _uploadAvatar() async {
    if (!Account.instance.loggedIn) {
      _toast('游客模式不能上传头像，请用账号登录后再试');
      return;
    }
    final path = FileDialog.pickOpenFile(title: '选择头像图片');
    if (path == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.length > 1024 * 1024) {
        _toast('图片太大（请选 1MB 以内）');
        return;
      }
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
        data: base64Encode(bytes),
      ));
      final result = await completer.future
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      await sub.cancel();
      if (!mounted) return;
      if (result != null && result.startsWith('OK')) {
        Account.instance.signIn(
          Account.instance.name ?? widget.playerName,
          avatarBytes: bytes,
          isBeta: Account.instance.beta,
        );
        _toast('头像已更新');
      } else {
        _toast(result == null ? '头像上传超时' : result.replaceFirst('FAIL|', ''));
      }
    } catch (e) {
      _toast('读取图片失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Account.instance.revision,
      builder: (context, _, __) {
        final acc = Account.instance;
        final loggedIn = acc.loggedIn;
        final name = loggedIn ? acc.name! : widget.playerName;
        final Uint8List? avatar = acc.avatar;
        return Dialog(
          backgroundColor: const Color(0xFF241C15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0x66FFD9A0)),
          ),
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0xFF3A2C1E),
                      Color(0xFF241C15),
                    ]),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFFFFD9A0), size: 20),
                      const SizedBox(width: 8),
                      const Text('个人信息',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.white54,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: loggedIn && !_uploading ? _uploadAvatar : null,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFFFD9A0), width: 2),
                            color: const Color(0xFF3A2C1E),
                          ),
                          child: ClipOval(
                            child: avatar == null
                                ? const Icon(Icons.person,
                                    size: 44, color: Colors.white38)
                                : Image.memory(avatar, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                ),
                                if (acc.beta) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0x33FFC107),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0x88FFC107)),
                                    ),
                                    child: const Text('内测权限',
                                        style: TextStyle(
                                            color: Color(0xFFFFD54F),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            _row('账号', loggedIn ? acc.name! : '游客（未登录）',
                                color: loggedIn
                                    ? Colors.white70
                                    : Colors.orangeAccent),
                            _row('测试模式',
                                acc.beta ? '可用（可自选武将）' : '不可用（需内测权限）',
                                color: acc.beta
                                    ? const Color(0xFF9CCC65)
                                    : Colors.white38),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            (loggedIn && !_uploading) ? _uploadAvatar : null,
                        icon: _uploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.image, size: 16),
                        label: const Text('上传头像'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => SettingsDialog.show(context),
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('设置'),
                      ),
                      if (loggedIn)
                        OutlinedButton.icon(
                          onPressed: () {
                            Account.instance.signOut();
                            Navigator.of(context).pop();
                            widget.onSignOut?.call();
                          },
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text('退出登录'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
