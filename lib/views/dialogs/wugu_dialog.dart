import 'package:flutter/material.dart';

class WuGuDialog {
  static void show(BuildContext context, String rawPool, Function(String) onPick) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final items = rawPool.split(';');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2B2C34),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('【五谷丰登】请挑选一张卡牌',
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
            content: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items.map((it) {
                if (!it.contains('=')) return const SizedBox();
                final p = it.split('=');
                final idx = p[0];
                final desc = p[1];
                return InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onPick(idx);
                  },
                  child: Container(
                    width: 125,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      desc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      );
    });
  }
}