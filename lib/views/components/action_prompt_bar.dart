import 'package:flutter/material.dart';

class ActionPromptBar extends StatelessWidget {
  final String prompt;
  final bool isResponding;
  final int selectedCount;
  final bool isZhangBaMode;
  final bool isRenDeMode;
  final bool isZhiHengMode;
  final bool isChuHaiMode;
  final bool hasZhangBaWeapon;
  final bool hasRenDeSkill;
  final bool hasZhiHengSkill;
  final bool hasChuHaiSkill;
  final int secondsLeft;
  final int totalSeconds;
  /// 本次询问只需要指定目标（武圣②、洛神、节钺、解围、雷击、清正、颂…）
  final bool isTargetOnly;
  /// 当前是否已经选中了目标席位
  final bool hasTarget;

  /// 本次询问是「是否发动某个被动技能」（形如 `0 = 放弃，1 = 发动`）：
  /// 直接用本栏的【确定】= 发动、【放弃】= 不发动，不再弹选项弹窗
  final bool isConfirmAsk;

  /// 是否选中了【铁索连环】（选中后可以点「重铸」直接换牌，不必指定目标）
  final bool hasTieSuoSelected;

  /// 必须精确选中的张数（弃牌阶段「需弃 X 张」）：选多选少都不允许提交。
  final int? exactCount;

  final VoidCallback onConfirm;
  final VoidCallback onCancelSelection;
  final VoidCallback onToggleZhangBa;
  final VoidCallback onToggleRenDe;
  final VoidCallback onToggleZhiHeng;
  final VoidCallback onToggleChuHai;
  final VoidCallback onRecastTieSuo;
  final VoidCallback onPass;

  const ActionPromptBar({
    super.key,
    required this.prompt,
    required this.isResponding,
    required this.selectedCount,
    required this.isZhangBaMode,
    required this.isRenDeMode,
    required this.isZhiHengMode,
    required this.isChuHaiMode,
    required this.hasZhangBaWeapon,
    required this.hasRenDeSkill,
    required this.hasZhiHengSkill,
    required this.hasChuHaiSkill,
    required this.onConfirm,
    required this.onCancelSelection,
    required this.onToggleZhangBa,
    required this.onToggleRenDe,
    required this.onToggleZhiHeng,
    required this.onToggleChuHai,
    required this.onPass,
    this.onRecastTieSuo = _noop,
    this.hasTieSuoSelected = false,
    this.secondsLeft = 0,
    this.totalSeconds = 25,
    this.isTargetOnly = false,
    this.hasTarget = false,
    this.isConfirmAsk = false,
    this.exactCount,
  });

  static void _noop() {}

  Widget _skillButton({
    required String label,
    required String activeLabel,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? color : color.withValues(alpha: 0.55),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          side: active ? const BorderSide(color: Colors.yellowAccent, width: 2) : null,
        ),
        onPressed: onTap,
        child: Text(active ? activeLabel : label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _countdown() {
    final ratio = totalSeconds <= 0 ? 0.0 : (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    final color = secondsLeft <= 5 ? Colors.redAccent : Colors.cyanAccent;
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: ratio,
            strokeWidth: 3,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text('$secondsLeft',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 除害 / 选目标 / 是否发动 模式下不需要勾选手牌
    final bool baseCanConfirm =
        isChuHaiMode || selectedCount > 0 || (isTargetOnly && hasTarget) || isConfirmAsk;
    // 弃牌阶段等「需精确 N 张」的场景：选多选少都不允许提交
    final bool countOk = exactCount == null || selectedCount == exactCount;
    final bool canConfirm = baseCanConfirm && countOk;
    // 红色倒计时进度条（响应 / 出牌都需要一眼看出剩余时间）
    final double barRatio =
        totalSeconds <= 0 ? 0.0 : (secondsLeft / totalSeconds).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isResponding ? const Color(0xFF3A1E1E) : const Color(0xFF2B2D3A),
        border: Border(
            top: BorderSide(
                color: isResponding
                    ? const Color(0xFFFF5252)
                    : Colors.amberAccent.withValues(alpha: 0.3),
                width: isResponding ? 2.5 : 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部红色倒计时进度条
          if (totalSeconds > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: barRatio,
                  minHeight: 5,
                  backgroundColor: const Color(0x33FFFFFF),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    secondsLeft <= 5 ? const Color(0xFFFF1744) : const Color(0xFFE53935),
                  ),
                ),
              ),
            ),
          // 第一行：状态徽章 + 倒计时 + 提示文字
          Row(
            children: [
              if (isResponding)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('请响应',
                      style: TextStyle(
                          fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              if (secondsLeft > 0) ...[_countdown(), const SizedBox(width: 8)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isChuHaiMode
                          ? '【除害发动中】点击上方席位指定拼点目标，然后点【确定发动】'
                          : prompt,
                      style: TextStyle(
                        color: isChuHaiMode ? Colors.cyanAccent : Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isTargetOnly && !hasTarget)
                      const Text('↑ 请点击上方任意席位选择目标',
                          style: TextStyle(fontSize: 11, color: Colors.cyanAccent))
                    else if (selectedCount > 0 || exactCount != null)
                      Text(
                          exactCount != null
                              ? '已选 $selectedCount / $exactCount 张${countOk ? "" : "（需选满 $exactCount 张）"}'
                              : '已选 $selectedCount 张${isZhangBaMode ? "（丈八需 2 张）" : ""}',
                          style: TextStyle(
                              fontSize: 10,
                              color: exactCount != null && !countOk
                                  ? Colors.orangeAccent
                                  : Colors.white54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // 第二行：操作按钮整体居中
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (selectedCount > 0)
                TextButton(
                  onPressed: onCancelSelection,
                  child: const Text('取消选择',
                      style: TextStyle(fontSize: 11, color: Colors.white54)),
                ),
              if (hasChuHaiSkill && !isResponding)
                _skillButton(
                  label: '发动【除害】',
                  activeLabel: '取消除害',
                  active: isChuHaiMode,
                  color: Colors.deepOrange[700]!,
                  onTap: onToggleChuHai,
                ),
              if (hasZhiHengSkill && !isResponding)
                _skillButton(
                  label: '制衡',
                  activeLabel: '取消制衡',
                  active: isZhiHengMode,
                  color: Colors.deepPurple,
                  onTap: onToggleZhiHeng,
                ),
              if (hasRenDeSkill && !isResponding)
                _skillButton(
                  label: '仁德',
                  activeLabel: '取消仁德',
                  active: isRenDeMode,
                  color: Colors.teal,
                  onTap: onToggleRenDe,
                ),
              if (hasZhangBaWeapon && !isResponding)
                _skillButton(
                  label: '丈八出杀',
                  activeLabel: '取消丈八',
                  active: isZhangBaMode,
                  color: Colors.brown,
                  onTap: onToggleZhangBa,
                ),
              if (hasTieSuoSelected && !isResponding)
                _skillButton(
                  label: '重铸铁索',
                  activeLabel: '重铸铁索',
                  active: false,
                  color: const Color(0xFF455A64),
                  onTap: onRecastTieSuo,
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canConfirm ? Colors.amber[700] : Colors.grey[700],
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                ),
                onPressed: canConfirm ? onConfirm : null,
                child: Text(
                  isConfirmAsk
                      ? '发动'
                      : (isChuHaiMode
                          ? '确定发动'
                          : (isTargetOnly
                              ? (hasTarget ? '确定目标' : '请选目标')
                              : (exactCount != null
                                  ? '确定 ($selectedCount/$exactCount)'
                                  : (selectedCount > 0
                                      ? '确定 ($selectedCount)'
                                      : '确定')))),
                  style: TextStyle(
                    color: canConfirm ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              // 弃牌阶段（exactCount != null）不可放弃，必须选满张数
              if (exactCount == null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[800],
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  ),
                  onPressed: onPass,
                  child: Text(
                      isConfirmAsk
                          ? '放弃'
                          : (isResponding ? 'PASS/放弃' : '结束出牌'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
