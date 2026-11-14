import 'package:flutter/material.dart';

class TargetZoneDialog {
  static void show(BuildContext context, String rawData, Function(String) onChoice) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final parts = rawData.split('|');
      if (parts.length < 2) return;
      final targetName = parts[0];
      final subParts = parts[1].split(';');

      final handCount = int.tryParse(subParts[0]) ?? 0;
      final equipStr = subParts.length > 1 ? subParts[1] : "";
      final judgeStr = subParts.length > 2 ? subParts[2] : "";

      final equipList = equipStr.isNotEmpty ? equipStr.split(',') : <String>[];
      final judgeList = judgeStr.isNotEmpty ? judgeStr.split(',') : <String>[];

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2B2C34),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text('请选择 $targetName 的一张牌', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('【手牌区】(暗置盲选)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: List.generate(handCount, (index) {
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900]),
                        icon: const Icon(Icons.style, size: 16, color: Colors.amber),
                        label: Text('手牌 ${index + 1}'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onChoice('HAND:$index');
                        },
                      );
                    }),
                  ),
                  const Divider(color: Colors.white24, height: 20),

                  const Text('【装备区】', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (equipList.isEmpty)
                    const Text('无装备', style: TextStyle(color: Colors.white30))
                  else
                    Wrap(
                      spacing: 8,
                      children: equipList.map((eq) {
                        final eqParts = eq.split(':');
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800]),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onChoice('EQUIP:${eqParts[0]}');
                          },
                          child: Text(eqParts.length > 1 ? eqParts[1] : eqParts[0]),
                        );
                      }).toList(),
                    ),
                  const Divider(color: Colors.white24, height: 20),

                  const Text('【判定区】', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (judgeList.isEmpty)
                    const Text('无延时锦囊', style: TextStyle(color: Colors.white30))
                  else
                    Wrap(
                      spacing: 8,
                      children: List.generate(judgeList.length, (idx) {
                        final jParts = judgeList[idx].split(':');
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[800]),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onChoice('JUDGE:$idx');
                          },
                          child: Text(jParts.length > 1 ? jParts[1] : jParts[0]),
                        );
                      }),
                    ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}