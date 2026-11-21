import 'package:flutter/material.dart';

import '../../services/user_service.dart';

/// 设置面板：音效 / 语音 / 动画速度 / 手牌排序 / 战况日志 / 拖拽确认 / 界面缩放
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  AppSettings get _s => AppSettings.instance;

  void _update(VoidCallback fn) {
    setState(fn);
    _s.save();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF241D16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x66FFC107)),
      ),
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFFFFC107), size: 20),
                  SizedBox(width: 8),
                  Text('设置',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFE0B2))),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _switch('音效', '出牌 / 受击 / 判定等提示音',
                        _s.sfxEnabled, (v) => _update(() => _s.sfxEnabled = v)),
                    _slider('音效音量', _s.sfxVolume,
                        _s.sfxEnabled ? (v) => _update(() => _s.sfxVolume = v) : null),
                    _switch('角色语音', '出牌、技能、回合提示的中文语音',
                        _s.voiceEnabled, (v) => _update(() => _s.voiceEnabled = v)),
                    _slider('语音音量', _s.voiceVolume,
                        _s.voiceEnabled ? (v) => _update(() => _s.voiceVolume = v) : null),
                    const Divider(color: Colors.white12, height: 20),
                    _slider('动画速度', _s.animSpeed,
                        (v) => _update(() => _s.animSpeed = v), min: 0.5, max: 2.0),
                    _slider('界面缩放', _s.uiScale,
                        (v) => _update(() => _s.uiScale = v), min: 0.85, max: 1.15),
                    const Divider(color: Colors.white12, height: 20),
                    _switch('手牌自动排序', '收到新牌后按点数从小到大重排',
                        _s.autoSortHand, (v) => _update(() => _s.autoSortHand = v)),
                    _switch('拖拽出牌需要确认', '把牌拖到牌桌中央时先弹确认框',
                        _s.confirmDropPlay, (v) => _update(() => _s.confirmDropPlay = v)),
                    _switch('显示战况日志', '底部左侧保留战况按钮',
                        _s.showBattleLog, (v) => _update(() => _s.showBattleLog = v)),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => _update(_s.resetToDefault),
                    child: const Text('恢复默认',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭',
                        style: TextStyle(color: Color(0xFFFFC107), fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFFFFC107),
      title: Text(title,
          style: const TextStyle(fontSize: 14, color: Color(0xFFFFE0B2))),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.white38)),
    );
  }

  Widget _slider(String title, double value, ValueChanged<double>? onChanged,
      {double min = 0.0, double max = 1.0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(fontSize: 13, color: Color(0xFFFFE0B2))),
            const Spacer(),
            Text('${value.toStringAsFixed(2)}×',
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: const Color(0xFFFFC107),
            inactiveTrackColor: Colors.white24,
            thumbColor: const Color(0xFFFFD54F),
          ),
          child: Slider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
