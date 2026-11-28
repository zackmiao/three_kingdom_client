/// 服务端「询问应答」提示串的判定规则。
///
/// 服务端在不同时机用的措辞并不统一（见 README 的响应阶段约定）：
/// - 南蛮入侵：`【南蛮入侵】请打出一张【杀】抵抗（放弃点 PASS）:`
/// - 决斗：    `【决斗】A 对你发起决斗，请打出 1 张【杀】回应（放弃点 PASS）:`
/// - 万箭齐发：`【万箭齐发】请打出一张【闪】抵挡（放弃点 PASS）:`
/// - 火攻：    `【火攻】请弃置一张【红桃】手牌以造成 1 点火焰伤害（放弃点 PASS）:`
///
/// 早期客户端只认 `打出【杀】` / `一张【杀】` / `视为【杀】` 三种写法，
/// 导致决斗提示（`请打出 1 张【杀】回应`）没被识别，响应阶段手牌全亮、误点即判失败。
library;

/// 该提示是否要求「打出一张【杀】」。
bool promptAsksSha(String prompt) {
  if (!prompt.contains('【杀】')) return false;
  // 「视为【杀】」优先：龙胆/武圣的转换提示里可能同时出现【闪】
  if (prompt.contains('视为【杀】')) return true;
  if (prompt.contains('【闪】')) return false;
  return prompt.contains('打出') ||
      prompt.contains('抵抗') ||
      prompt.contains('回应');
}

/// 该提示是否要求「打出一张【闪】」。
bool promptAsksShan(String prompt) {
  if (!prompt.contains('【闪】')) return false;
  return prompt.contains('打出') || prompt.contains('抵挡') || prompt.contains('回应');
}
