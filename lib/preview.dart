// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'models/card_model.dart';
import 'views/components/action_prompt_bar.dart';
import 'views/components/center_stage_view.dart';
import 'views/components/game_background.dart';
import 'views/components/hand_card_area.dart';
import 'views/components/table_seat_card.dart';

/// 界面预览入口：不连服务端，用假数据铺满一桌，便于快速检查布局。
/// 运行：flutter run -d windows -t lib/preview.dart
void main() => runApp(const PreviewApp());

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const BoardPreview(),
    );
  }
}

class BoardPreview extends StatefulWidget {
  const BoardPreview({super.key});

  @override
  State<BoardPreview> createState() => _BoardPreviewState();
}

class _BoardPreviewState extends State<BoardPreview> {
  final Set<int> _selected = {1};

  final List<CardModel> _cards = [
    CardModel(index: 0, typeKey: 'SHA', suitKey: 'SPADE', points: '7', cardId: 11, name: '杀'),
    CardModel(index: 1, typeKey: 'SHAN', suitKey: 'HEART', points: '2', cardId: 12, name: '闪'),
    CardModel(index: 2, typeKey: 'TAO', suitKey: 'DIAMOND', points: 'Q', cardId: 13, name: '桃'),
    CardModel(
        index: 3,
        typeKey: 'WU_ZHONG_SHENG_YOU',
        suitKey: 'HEART',
        points: '9',
        cardId: 14,
        name: '无中生有'),
    CardModel(
        index: 4,
        typeKey: 'ZHU_GE_LIAN_NU',
        suitKey: 'CLUB',
        points: 'A',
        cardId: 15,
        name: '诸葛连弩'),
    CardModel(
        index: 5,
        typeKey: 'LE_BU_SI_SHU',
        suitKey: 'SPADE',
        points: '6',
        cardId: 16,
        name: '乐不思蜀'),
    CardModel(index: 6, typeKey: 'JIU', suitKey: 'SPADE', points: '3', cardId: 17, name: '酒'),
  ];

  Widget _capsule(String text, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55FFD9A0)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0906),
      body: Stack(children: [
        const GameBackground(),
        Column(children: [
          const SizedBox(height: 46),
          Expanded(
            child: Stack(children: [
              // 左
              Positioned(
                left: 10,
                top: 150,
                child: TableSeatCard(
                  id: 'p2',
                  name: '谋曹操',
                  hero: '谋曹操',
                  hp: 3,
                  maxHp: 4,
                  handCount: 4,
                  equips: '青釭剑,八卦阵',
                  judges: const ['乐不思蜀'],
                  marks: const ['治世'],
                  isMe: false,
                  role: 'MAIN',
                  roleLabel: '主公',
                  distance: 1,
                  armor: 2,
                  seatNo: 2,
                ),
              ),
              // 上
              Positioned(
                left: 420,
                top: 2,
                child: TableSeatCard(
                  id: 'p3',
                  name: '谋吕布',
                  hero: '谋吕布',
                  hp: 5,
                  maxHp: 5,
                  handCount: 2,
                  equips: '丈八蛇矛,,, +1马',
                  judges: const [],
                  marks: const ['无双加伤', '铁索连环※'],
                  isMe: false,
                  role: 'REBEL',
                  roleLabel: '反贼',
                  distance: 2,
                  seatNo: 3,
                  isCurrentTurn: true,
                  currentPhaseName: '出牌阶段',
                ),
              ),
              Positioned(
                left: 700,
                top: 2,
                child: TableSeatCard(
                  id: 'p4',
                  name: '谋甄姬',
                  hero: '谋甄姬',
                  hp: 1,
                  maxHp: 3,
                  handCount: 6,
                  equips: '',
                  judges: const ['兵粮寸断'],
                  marks: const ['道兵', '颂'],
                  isMe: false,
                  role: 'HIDDEN',
                  roleLabel: '？',
                  distance: 1,
                  armor: 1,
                  flipped: true,
                  seatNo: 4,
                ),
              ),
              // 右
              Positioned(
                right: 10,
                top: 150,
                child: TableSeatCard(
                  id: 'p5',
                  name: '谋周瑜',
                  hero: '谋周瑜',
                  hp: 2,
                  maxHp: 3,
                  handCount: 3,
                  equips: ',,',
                  judges: const [],
                  marks: const [],
                  isMe: false,
                  role: 'TRAITOR',
                  roleLabel: '内奸',
                  distance: 2,
                  seatNo: 5,
                ),
              ),
              // 中央结算
              Center(
                child: CenterStageView(cards: [
                  PlayedCard(
                      name: '杀',
                      typeKey: 'SHA',
                      sourceName: '谋吕布',
                      targetNames: ['主机玩家']),
                  PlayedCard(
                      name: '闪',
                      typeKey: 'SHAN',
                      sourceName: '主机玩家',
                      targetNames: []),
                ]),
              ),
            ]),
          ),
          // 底部操作区
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xCC150E09), const Color(0xFF0A0705)],
              ),
              border: const Border(top: BorderSide(color: Color(0x55FFC94D), width: 1.2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ActionPromptBar(
                prompt: '【出牌阶段】请选牌并指定目标后点确定（HP:4/4，剩余可出杀:1）',
                isResponding: false,
                selectedCount: _selected.length,
                isZhangBaMode: false,
                isRenDeMode: false,
                isZhiHengMode: false,
                isChuHaiMode: false,
                hasZhangBaWeapon: true,
                hasRenDeSkill: false,
                hasZhiHengSkill: false,
                hasChuHaiSkill: false,
                secondsLeft: 18,
                totalSeconds: 25,
                isTargetOnly: false,
                hasTarget: false,
                onConfirm: () {},
                onCancelSelection: () => setState(() => _selected.clear()),
                onToggleZhangBa: () {},
                onToggleRenDe: () {},
                onToggleZhiHeng: () {},
                onToggleChuHai: () {},
                onPass: () {},
              ),
              SizedBox(
                height: 258,
                child: Row(children: [
                  // 左功能
                  SizedBox(
                    width: 58,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final t in [['按类型', Icons.sort], ['按点数', Icons.sort_by_alpha], ['战况', Icons.receipt_long]])
                          Container(
                            width: 52,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x33FFD9A0)),
                            ),
                            child: Column(children: [
                              Icon(t[1] as IconData, size: 15, color: const Color(0xFFFFE082)),
                              const SizedBox(height: 2),
                              Text(t[0] as String,
                                  style: const TextStyle(fontSize: 9, color: Color(0xCCFFE0B2))),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  // 手牌
                  Expanded(
                    child: Stack(children: [
                      Positioned.fill(
                        child: HandCardArea(
                          handCards: _cards,
                          selectedIndices: _selected,
                          maxHandCards: 4,
                          onCardTap: (c) => setState(() {
                            if (_selected.contains(c.index)) {
                              _selected.remove(c.index);
                            } else {
                              _selected.add(c.index);
                            }
                          }),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x55FFD9A0)),
                          ),
                          child: const Text('手牌 7/4',
                              style: TextStyle(fontSize: 10, color: Color(0xFFFF6B6B))),
                        ),
                      ),
                    ]),
                  ),
                  // 右区
                  SizedBox(
                    width: 172,
                    child: Column(children: [
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: Row(children: [
                          for (final n in ['武圣', '乱击', '清正'])
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFFB8860B),
                                    Color(0xFF6D4C00)
                                  ]),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFFD54F)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('发动',
                                        style: TextStyle(fontSize: 7.5, color: Color(0xFFFFE082))),
                                    Text(n,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            ),
                        ]),
                      ),
                      SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            for (final e in ['⚔', '🛡', '🐎', '🐴'])
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(3, 0, 3, 0),
                                  decoration: BoxDecoration(
                                    color: e == '⚔'
                                        ? const Color(0x55B8860B)
                                        : Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                        color: e == '⚔'
                                            ? const Color(0xFFFFD54F)
                                            : const Color(0x33FFD9A0),
                                        width: 0.7),
                                  ),
                                  child: Center(
                                      child: Text(e,
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: e == '⚔' ? Colors.white : Colors.white24))),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: TableSeatCard(
                            id: 'p1',
                            name: '主机玩家',
                            hero: '谋关羽',
                            hp: 2,
                            maxHp: 4,
                            handCount: 7,
                            equips: '诸葛连弩,',
                            judges: const [],
                            marks: const [],
                            isMe: true,
                            role: 'LOYAL',
                            roleLabel: '忠臣',
                            seatNo: 1,
                            compact: true,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
        // 顶部胶囊
        Positioned(
          left: 12,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x55FFD9A0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('主1  忠1  反2  内1',
                    style: TextStyle(fontSize: 11, color: Color(0xFFFFE082))),
                Text('反贼与内奸全灭则主公方获胜',
                    style: TextStyle(fontSize: 8.5, color: Color(0x99FFE0B2))),
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 8,
          child: Row(children: [
            _capsule('78/22', Icons.layers, const Color(0xFF80DEEA)),
            _capsule('第 3 轮', Icons.autorenew, const Color(0xFFFFD54F)),
            _capsule('存活 4 · 射程 1', Icons.people, const Color(0xFFA5D6A7)),
            _capsule('2/4', Icons.favorite, const Color(0xFFFF6B6B)),
          ]),
        ),
      ]),
    );
  }
}
