import 'package:flutter_test/flutter_test.dart';
import 'package:three_kingdom_client/models/prompt_rules.dart';

void main() {
  group('响应阶段提示判定（D1：决斗不再把手牌全亮）', () {
    test('决斗「请打出 1 张【杀】回应」要求出杀', () {
      expect(promptAsksSha('【决斗】谋曹操 对你发起决斗，请打出 1 张【杀】回应（放弃点 PASS）:'), isTrue);
    });

    test('决斗需要两张杀时同样要求出杀', () {
      expect(promptAsksSha('【决斗】谋华雄 对你发起决斗，请打出 2 张【杀】回应（放弃点 PASS）:'), isTrue);
    });

    test('南蛮「请打出一张【杀】抵抗」要求出杀', () {
      expect(promptAsksSha('【南蛮入侵】请打出一张【杀】抵抗（放弃点 PASS）:'), isTrue);
    });

    test('万箭要求【闪】时不要求出杀', () {
      expect(promptAsksSha('【万箭齐发】请打出一张【闪】抵挡（放弃点 PASS）:'), isFalse);
      expect(promptAsksShan('【万箭齐发】请打出一张【闪】抵挡（放弃点 PASS）:'), isTrue);
    });

    test('火攻弃牌与濒死求桃不算要求出杀', () {
      expect(promptAsksSha('【火攻】请弃置一张【红桃】手牌以造成 1 点火焰伤害（放弃点 PASS）:'), isFalse);
      expect(promptAsksSha('【濒死求桃】谋曹操 濒死(2)，是否使用一张【桃】救援？放弃请点 PASS:'), isFalse);
    });

    test('龙胆「视为【杀】使用」的要求出杀', () {
      expect(promptAsksSha('请选择一张【闪】视为【杀】使用'), isTrue);
    });

    test('出牌阶段提示不要求出杀', () {
      expect(promptAsksSha('【出牌阶段】请出牌（剩余可出杀:1）：'), isFalse);
    });
  });
}
