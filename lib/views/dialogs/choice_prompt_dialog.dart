import 'package:flutter/material.dart';

/// 通用的“数值选项”弹窗：从服务端提示里解析 `0 = xxx，1 = yyy` 形式的选项。
/// 用于谋弈、反间、明策、鬼道、狭援等需要玩家做二选一/三选一的技能。
class ChoicePromptDialog {
  static final RegExp _optionRegex = RegExp(r'(\d)\s*=\s*([^，,；;）)\n]+)');

  static List<MapEntry<String, String>> options(String prompt) {
    final list = <MapEntry<String, String>>[];
    for (final m in _optionRegex.allMatches(prompt)) {
      list.add(MapEntry(m.group(1)!, m.group(2)!.trim()));
    }
    return list;
  }

  static bool matches(String prompt) => options(prompt).length >= 2;

  static void show(BuildContext context, String prompt, Function(String) onPick) {
    final opts = options(prompt);
    if (opts.length < 2) return;
    final title = prompt.length > 40 ? '${prompt.substring(0, 40)}…' : prompt;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF23242E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.help_outline, color: Colors.amberAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: opts
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF343748),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onPick(e.key);
                          },
                          child: Text('${e.key}. ${e.value}',
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      );
    });
  }
}
