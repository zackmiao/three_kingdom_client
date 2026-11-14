import 'package:flutter/material.dart';

/// 战况日志：按内容自动着色，方便快速扫读。
class BattleLogView extends StatelessWidget {
  final List<String> logs;
  final ScrollController scrollController;

  const BattleLogView({
    super.key,
    required this.logs,
    required this.scrollController,
  });

  static Color colorOf(String log) {
    if (log.contains('阵亡') || log.contains('受到') || log.contains('濒死')) {
      return const Color(0xFFFF6B6B);
    }
    if (log.contains('回复') || log.contains('护甲') || log.contains('摸')) {
      return const Color(0xFF6BE39B);
    }
    if (log.contains('★') || log.contains('【') && !log.contains('轮')) {
      return const Color(0xFFFFD166);
    }
    if (log.contains('回合') || log.contains('阶段')) {
      return const Color(0xFF7FD1FF);
    }
    return const Color(0xFFBFBFBF);
  }

  static bool boldOf(String log) {
    return log.startsWith('★') || log.startsWith('⚔') || log.startsWith('💀') || log.contains('回合');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121216),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: logs.isEmpty
          ? const Center(
              child: Text('暂无战况', style: TextStyle(color: Colors.white24, fontSize: 12)))
          : ListView.builder(
              controller: scrollController,
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final isTurnHeader = log.contains('>>>>>>>>');
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: isTurnHeader ? 6 : 2),
                  child: Container(
                    padding: isTurnHeader
                        ? const EdgeInsets.symmetric(vertical: 4, horizontal: 6)
                        : EdgeInsets.zero,
                    decoration: isTurnHeader
                        ? BoxDecoration(
                            color: const Color(0xFF1E2430),
                            borderRadius: BorderRadius.circular(4),
                            border: const Border(
                                left: BorderSide(color: Colors.lightBlueAccent, width: 3)),
                          )
                        : null,
                    child: Text(
                      log,
                      style: TextStyle(
                        color: isTurnHeader ? Colors.lightBlueAccent : colorOf(log),
                        fontSize: isTurnHeader ? 12 : 12.5,
                        height: 1.35,
                        fontWeight: boldOf(log) ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
