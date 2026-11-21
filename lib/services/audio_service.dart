import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import 'user_service.dart';

/// 游戏音效（角色语音已按需求移除，只保留音效）。
///
/// Windows 上用 `winmm.dll!PlaySound` 直接播 wav（无第三方音频插件依赖）。
/// 素材全部本地生成：
/// - `assets/audio/voice/*.wav`：中文语音合成（SAPI Huihui）生成的出牌/技能/胜负语音
/// - `assets/audio/sfx/*.wav`：程序合成的音效
///
/// 首次播放时把资源解包到临时目录，之后复用同一路径缓存。
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const String _sfxDir = 'assets/audio/sfx';

  static const int _sndAsync = 0x0001;
  static const int _sndNoDefault = 0x0002;
  static const int _sndFilename = 0x00020000;

  static const Set<String> _sfx = {
    'play', 'draw', 'damage', 'heal', 'shield', 'judge', 'click', 'turn',
    'win', 'lose', 'skill',
  };

  bool _enabled = Platform.isWindows;
  bool _ready = false;
  DynamicLibrary? _winmm;
  Future<void>? _initFuture;

  final Map<String, String> _paths = {};

  bool get enabled => _enabled;

  /// 关掉声音（设置里可以留个开关）
  void setEnabled(bool value) => _enabled = value;

  Future<void> init() async {
    if (!_enabled) return;
    _initFuture ??= _doInit();
    return _initFuture;
  }

  Future<void> _doInit() async {
    try {
      _winmm = DynamicLibrary.open('winmm.dll');
      _ready = true;
    } catch (_) {
      _enabled = false;
    }
  }

  void _playWinmm(String path) {
    final lib = _winmm;
    if (lib == null || !_ready) return;
    try {
      final play = lib.lookupFunction<
          Int32 Function(Pointer<Utf16>, IntPtr, Uint32),
          int Function(Pointer<Utf16>, int, int)>('PlaySoundW');
      final ptr = path.toNativeUtf16();
      play(ptr, 0, _sndFilename | _sndAsync | _sndNoDefault);
      // PlaySoundW 会复制/持有缓冲区吗？SND_ASYNC + 文件名模式下系统只读文件名，
      // 这里延后释放以避免个别驱动的竞态。
      Timer(const Duration(milliseconds: 800), () => calloc.free(ptr));
    } catch (_) {
      // 静默失败：宁可没有声音也不要打断对局
    }
  }

  Future<String?> _ensureAsset(String relPath, String fileName) async {
    final cached = _paths[relPath];
    if (cached != null && File(cached).existsSync()) return cached;
    try {
      final data = await rootBundle.load(relPath);
      final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}tk_audio')
        ..createSync(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      _paths[relPath] = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> playSfx(String name, {double volume = 1.0}) async {
    if (!_enabled || !_sfx.contains(name)) return;
    final settings = AppSettings.instance;
    if (!settings.sfxEnabled || settings.sfxVolume <= 0) return;
    if (volume * settings.sfxVolume < 0.06) return;
    await init();
    if (!_ready) return;
    final path = await _ensureAsset('$_sfxDir/$name.wav', 'sfx_$name.wav');
    if (path == null) return;
    _playWinmm(path);
  }

  /// 语音已按需求整体关闭（只保留音效）；保留方法签名，避免调用点大改。
  Future<void> playVoice(String name) async {}

  /// 出牌音效：按牌名播放对应的短促音效（不再播放人物语音）
  Future<void> playCard(String cardName) async {
    await playSfx('play', volume: 0.85);
  }

  /// 武将出场：语音关闭后不再发声（保留空实现供调用点复用）
  Future<void> playHeroIntro(String heroName) async {}
}
