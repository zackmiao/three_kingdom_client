import 'package:flutter/material.dart';
import '../../models/card_catalog.dart';
import '../components/card_face.dart';

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
          Widget sectionTitle(String text, Color color) => Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 2),
                child: Text(text,
                    style: TextStyle(
                        color: color, fontSize: 12.5, fontWeight: FontWeight.bold)),
              );

          Widget miniCard({
            required String? typeKey,
            required String name,
            required VoidCallback onTap,
          }) {
            return Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 6),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onTap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (typeKey != null && CardFace.hasArt(typeKey))
                        CardFace(
                          typeKey: typeKey,
                          name: name,
                          suitSymbol: '',
                          points: '',
                          isRed: false,
                          index: 0,
                          showIndex: false,
                          showCorner: false,
                          width: 78,
                          height: 110,
                        )
                      else
                        Container(
                          width: 78,
                          height: 110,
                          decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x66FFD9A0)),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(name,
                          style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 620),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF241B10), Color(0xFF120C07)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x99FFC94D), width: 1.6),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 22)],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('请选择 $targetName 的一张牌',
                        style: const TextStyle(
                            color: Color(0xFFFFC94D),
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    sectionTitle('【手牌区】暗置盲选', const Color(0xFFFFD9A0)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(handCount, (index) {
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              onChoice('HAND:$index');
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 62,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF6D2B1F), Color(0xFF2E1108)],
                                    ),
                                    border: Border.all(
                                        color: const Color(0xFFFFD54F), width: 1.2),
                                  ),
                                  child: const Center(
                                    child: Text('三',
                                        style: TextStyle(
                                            color: Color(0x99FFD54F),
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900)),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text('手牌 ${index + 1}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const Divider(color: Colors.white24, height: 22),
                    sectionTitle('【装备区】', const Color(0xFF80CBC4)),
                    if (equipList.isEmpty)
                      const Text('无装备',
                          style: TextStyle(color: Colors.white30, fontSize: 11.5))
                    else
                      Wrap(
                        spacing: 0,
                        children: equipList.map((eq) {
                          final eqParts = eq.split(':');
                          final name = eqParts.length > 1 ? eqParts[1] : eqParts[0];
                          return miniCard(
                            typeKey: CardCatalog.typeKeyOfName(name),
                            name: name,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              onChoice('EQUIP:${eqParts[0]}');
                            },
                          );
                        }).toList(),
                      ),
                    const Divider(color: Colors.white24, height: 22),
                    sectionTitle('【判定区】', const Color(0xFFFFAB91)),
                    if (judgeList.isEmpty)
                      const Text('无延时锦囊',
                          style: TextStyle(color: Colors.white30, fontSize: 11.5))
                    else
                      Wrap(
                        spacing: 0,
                        children: List.generate(judgeList.length, (idx) {
                          final jParts = judgeList[idx].split(':');
                          final name = jParts.length > 1 ? jParts[1] : jParts[0];
                          return miniCard(
                            typeKey: CardCatalog.typeKeyOfName(name),
                            name: name,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              onChoice('JUDGE:$idx');
                            },
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
