import 'package:flutter/material.dart';

class JudgeResultDialog {
  static void show(BuildContext context, String rawData) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final parts = rawData.split('|');
      if (parts.length < 3) return;
      final pName = parts[0];
      final judgeType = parts[1];
      final cardDesc = parts[2];

      showDialog(
        context: context,
        builder: (ctx) {
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (context.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          });
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text('$pName 进行【$judgeType】判定',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        cardDesc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('正在结算判定结果...', style: TextStyle(color: Colors.white54, fontSize: 12))
              ],
            ),
          );
        },
      );
    });
  }
}