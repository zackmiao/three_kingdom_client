import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

/// 游戏音效 / 角色语音。
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

  static const String _voiceDir = 'assets/audio/voice';
  static const String _sfxDir = 'assets/audio/sfx';

  static const int _sndAsync = 0x0001;
  static const int _sndNoDefault = 0x0002;
  static const int _sndFilename = 0x00020000;

  static const Set<String> _voices = {
    'sha', 'shan', 'tao', 'jiu', 'wuxie', 'guohe', 'shunshou', 'nanman',
    'wanjian', 'wugu', 'taoyuan', 'huogong', 'juedou', 'tiesuo', 'lebu',
    'bingliang', 'shandian', 'zhuangbei', 'panding', 'shoushang', 'wodehuibe',
    'shengli', 'shibai', 'jineng', 'mopai', 'jiuzhu', 'sile', 'chupai',
    // 24 位武将的出场语音：hero_<id>.wav
    'hero_liubei', 'hero_caocao', 'hero_sunquan', 'hero_zhouchu',
    'hero_mou_guanyu', 'hero_mou_zhangliao', 'hero_mou_yuanshao',
    'hero_mou_lvbu', 'hero_mou_huaxiong', 'hero_mou_zhangfei',
    'hero_mou_zhaoyun', 'hero_mou_zhenji', 'hero_mou_daqiao',
    'hero_mou_tianyu', 'hero_mou_huangzhong', 'hero_mou_chengong',
    'hero_mou_caocao', 'hero_mou_zhouyu', 'hero_mou_caoren',
    'hero_mou_yujin', 'hero_mou_jiaxu', 'hero_mou_machao',
    'hero_mou_caopi', 'hero_mou_zhangjiao',
  };

  static const Set<String> _sfx = {
    'play', 'draw', 'damage', 'heal', 'shield', 'judge', 'click', 'turn',
    'win', 'lose', 'skill',
  };

  bool _enabled = Platform.isWindows;
  bool _ready = false;
  DynamicLibrary? _winmm;
  Future<void>? _initFuture;

  final Map<String, String> _paths = {};
  DateTime _lastVoiceAt = DateTime.fromMillisecondsSinceEpoch(0);

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
    await init();
    if (!_ready) return;
    // 语音刚播过时，短的点击声让位，避免互相打断
    if (volume < 1.0 &&
        DateTime.now().difference(_lastVoiceAt).inMilliseconds < 400) {
      return;
    }
    final path = await _ensureAsset('$_sfxDir/$name.wav', 'sfx_$name.wav');
    if (path == null) return;
    _playWinmm(path);
  }

  Future<void> playVoice(String name) async {
    if (!_enabled || !_voices.contains(name)) return;
    await init();
    if (!_ready) return;
    final path = await _ensureAsset('$_voiceDir/$name.wav', 'voice_$name.wav');
    if (path == null) return;
    _lastVoiceAt = DateTime.now();
    _playWinmm(path);
  }

  /// 按卡牌中文名播放对应语音，没有专门语音的牌退回「出牌」气流声
  Future<void> playCard(String cardName) async {
    const map = {
      '杀': 'sha',
      '火杀': 'sha',
      '雷杀': 'sha',
      '闪': 'shan',
      '桃': 'tao',
      '酒': 'jiu',
      '无懈可击': 'wuxie',
      '过河拆桥': 'guohe',
      '顺手牵羊': 'shunshou',
      '南蛮入侵': 'nanman',
      '万箭齐发': 'wanjian',
      '五谷丰登': 'wugu',
      '桃园结义': 'taoyuan',
      '火攻': 'huogong',
      '决斗': 'juedou',
      '铁索连环': 'tiesuo',
      '乐不思蜀': 'lebu',
      '兵粮寸断': 'bingliang',
      '闪电': 'shandian',
    };
    final voice = map[cardName];
    if (voice != null) {
      await playVoice(voice);
    } else {
      await playSfx('play');
      if (cardName.isNotEmpty) await playVoice('zhuangbei');
    }
  }

  /// 武将出场语音：heroName 形如「谋曹操」/「刘备」
  Future<void> playHeroIntro(String heroName) async {
    if (heroName.isEmpty) return;
    final id = _heroIds[heroName];
    if (id == null || id.isEmpty) return;
    await playVoice('hero_$id');
  }

  /// 武将全名 → 立绘/语音 id（与 assets/heroes、assets/audio/voice 同名）
  static const Map<String, String> _heroIds = {
    '刘备': 'liubei',
    '曹操': 'caocao',
    '孙权': 'sunquan',
    '周处': 'zhouchu',
    '谋关羽': 'mou_guanyu',
    '谋张辽': 'mou_zhangliao',
    '谋袁绍': 'mou_yuanshao',
    '谋吕布': 'mou_lvbu',
    '谋华雄': 'mou_huaxiong',
    '谋张飞': 'mou_zhangfei',
    '谋赵云': 'mou_zhaoyun',
    '谋甄姬': 'mou_zhenji',
    '谋大乔': 'mou_daqiao',
    '谋田豫': 'mou_tianyu',
    '谋黄忠': 'mou_huangzhong',
    '谋陈宫': 'mou_chengong',
    '谋曹操': 'mou_caocao',
    '谋周瑜': 'mou_zhouyu',
    '谋曹仁': 'mou_caoren',
    '谋于禁': 'mou_yujin',
    '谋贾诩': 'mou_jiaxu',
    '谋马超': 'mou_machao',
    '谋曹丕': 'mou_caopi',
    '谋张角': 'mou_zhangjiao',
  };
}
