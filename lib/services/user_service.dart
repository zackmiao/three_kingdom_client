import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 极简设置项：全部存在用户目录下的 JSON 里（不引入 shared_preferences 等插件）。
class AppSettings {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  /// 音效总开关与音量（0~1）
  bool sfxEnabled = true;
  double sfxVolume = 0.8;

  /// 语音总开关与音量（0~1）
  bool voiceEnabled = true;
  double voiceVolume = 1.0;

  /// 动画速度倍率：0.5 = 慢一倍，2.0 = 快一倍（飞行时长 = 基准 / 倍率）
  double animSpeed = 1.0;

  /// 手牌是否自动按点数排序（收到新牌时）
  bool autoSortHand = true;

  /// 是否在右侧保留战况日志按钮
  bool showBattleLog = true;

  /// 出牌/弃牌时是否需要二次确认（拖拽出牌）
  bool confirmDropPlay = false;

  /// 界面整体缩放（0.85 ~ 1.15），在 ScaledStage 之外再乘一层
  double uiScale = 1.0;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static File get _file {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return File('$base\\ThreeKingdomsLAN\\settings.json');
  }

  Future<void> load() async {
    try {
      final f = _file;
      if (!await f.exists()) return;
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      sfxEnabled = map['sfxEnabled'] as bool? ?? sfxEnabled;
      sfxVolume = (map['sfxVolume'] as num?)?.toDouble() ?? sfxVolume;
      voiceEnabled = map['voiceEnabled'] as bool? ?? voiceEnabled;
      voiceVolume = (map['voiceVolume'] as num?)?.toDouble() ?? voiceVolume;
      animSpeed = (map['animSpeed'] as num?)?.toDouble() ?? animSpeed;
      autoSortHand = map['autoSortHand'] as bool? ?? autoSortHand;
      showBattleLog = map['showBattleLog'] as bool? ?? showBattleLog;
      confirmDropPlay = map['confirmDropPlay'] as bool? ?? confirmDropPlay;
      uiScale = (map['uiScale'] as num?)?.toDouble() ?? uiScale;
      revision.value++;
    } catch (_) {
      // 设置文件损坏时用默认值，不影响进游戏
    }
  }

  Future<void> save() async {
    try {
      final f = _file;
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({
        'sfxEnabled': sfxEnabled,
        'sfxVolume': sfxVolume,
        'voiceEnabled': voiceEnabled,
        'voiceVolume': voiceVolume,
        'animSpeed': animSpeed,
        'autoSortHand': autoSortHand,
        'showBattleLog': showBattleLog,
        'confirmDropPlay': confirmDropPlay,
        'uiScale': uiScale,
      }));
    } catch (_) {
      // 写不进去也不影响这一局
    }
    revision.value++;
  }

  void resetToDefault() {
    sfxEnabled = true;
    sfxVolume = 0.8;
    voiceEnabled = true;
    voiceVolume = 1.0;
    animSpeed = 1.0;
    autoSortHand = true;
    showBattleLog = true;
    confirmDropPlay = false;
    uiScale = 1.0;
    save();
  }
}

/// 当前登录的账号 + 头像缓存
class Account {
  Account._();

  static final Account instance = Account._();

  String? name;
  Uint8List? avatar;

  /// 其他玩家的头像缓存（用户名 → 图片字节）
  final Map<String, Uint8List> avatars = {};

  bool get loggedIn => name != null && name!.isNotEmpty;

  void signIn(String userName, {Uint8List? avatarBytes}) {
    name = userName;
    if (avatarBytes != null) avatar = avatarBytes;
    revision.value++;
  }

  void signOut() {
    name = null;
    avatar = null;
    revision.value++;
  }

  void cacheAvatar(String userName, Uint8List bytes) {
    avatars[userName] = bytes;
    revision.value++;
  }

  Uint8List? avatarOf(String userName) {
    if (loggedIn && userName == name) return avatar;
    return avatars[userName];
  }

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
}
