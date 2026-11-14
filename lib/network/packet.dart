import 'command.dart';

class Packet {
  final Command command;
  final String senderId;
  final String data;

  Packet({
    required this.command,
    required this.senderId,
    required this.data,
  });

  String encode() {
    return '${command.name}|$senderId|$data';
  }

  String serialize() => encode();

  static Packet decode(String raw) {
    if (raw.isEmpty) {
      return Packet(command: Command.BROADCAST_MSG, senderId: "UNKNOWN", data: "");
    }
    final parts = raw.split('|');
    if (parts.length < 3) {
      return Packet(command: Command.BROADCAST_MSG, senderId: "UNKNOWN", data: raw);
    }
    final cmd = CommandExtension.fromString(parts[0]);
    final sender = parts[1];
    final data = parts.sublist(2).join('|');
    return Packet(command: cmd, senderId: sender, data: data);
  }

  static Packet deserialize(String raw) => decode(raw);
}