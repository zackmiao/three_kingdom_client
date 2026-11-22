// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_declarations, unnecessary_brace_in_string_interps
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/card_catalog.dart';
import '../models/card_model.dart';
import '../models/hero_model.dart';
import '../models/opponent_model.dart';
import '../models/skill_model.dart';
import '../network/command.dart';
import '../network/packet.dart';
import '../network/socket_service.dart';
import '../services/audio_service.dart';
import '../services/user_service.dart';
import 'components/action_prompt_bar.dart';
import 'components/battle_log_view.dart';
import 'components/card_face.dart';
import 'components/center_stage_view.dart';
import 'components/game_background.dart';
import 'components/hand_card_area.dart';
import 'components/table_seat_card.dart';
import 'components/target_arrow_painter.dart';
import 'dialogs/choice_prompt_dialog.dart';
import 'dialogs/hero_draw_dialog.dart';
import 'dialogs/hero_select_dialog.dart';
import 'dialogs/huogong_dialog.dart';
import 'dialogs/judge_result_dialog.dart';
import 'dialogs/lucky_card_dialog.dart';
import 'dialogs/pindian_dialog.dart';
import 'dialogs/settings_dialog.dart';
import 'dialogs/target_zone_dialog.dart';
import 'dialogs/wugu_dialog.dart';
import 'lobby_screen.dart';
import 'room_screen.dart';
import 'ui_scale.dart';

class GameRoomScreen extends StatefulWidget {
  final String playerId;
  final String playerName;

  const GameRoomScreen({super.key, required this.playerId, required this.playerName});

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SocketService _socket = SocketService();
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Packet>? _subscription;

  // ===== 服务端同步的状态 =====
  String _heroName = "未选将";
  /// 已经播过出场语音的武将（避免每次同步都念一遍）
  String _introPlayedHero = "";
  int _hp = 4;
  int _maxHp = 4;
  String _deckInfo = "0/0";
  String _myRole = "LOYAL";
  String _myRoleCn = "忠臣";
  /// 游戏模式：IDENTITY / TEAM_2V2 / LANDLORD（服务端 SYNC_STATE 的 MODE 字段）
  String _gameMode = "IDENTITY";
  int _roundNo = 1;
  int _timeoutSeconds = 25;
  int _maxHandCards = 0;
  int _myArmor = 0;
  int _aliveCount = 1;
  int _attackRange = 1;
  bool _myFlipped = false;

  String _turnPlayerId = "";
  String _currentPhaseName = "准备";

  List<CardModel> _handCards = [];
  List<SkillModel> _skills = [];
  List<OpponentModel> _opponents = [];

  /// 每个席位的位置引用（用于「牌从谁那里飞出来」的动画）
  final Map<String, GlobalKey> _seatKeys = <String, GlobalKey>{};
  GlobalKey _seatKeyOf(String id) =>
      _seatKeys.putIfAbsent(id, () => GlobalKey());

  String _weapon = "无";
  String _armor = "无";
  String _defHorse = "无";
  String _offHorse = "无";
  List<String> _judgeAreaCards = [];
  List<String> _myMarks = [];

  /// 酒加成（>0 时主视角武将卡显示红色血气）
  int _wineBonus = 0;

  /// 我的势力（WEI/QUN/...，随【篡权】等技能变化）、护盾、武将牌扣置牌数量
  String _myFaction = "";
  int _myExileCount = 0;

  /// 全场上扣置于武将牌上的牌（【弑龙】【成务】产生），用于成务选牌弹窗
  List<_ExiledCardInfo> _exiledCards = const [];

  /// 对手技能表：playerId -> 技能列表（长按对方武将牌查看）
  Map<String, List<SkillModel>> _oppSkills = {};

  final Set<int> _selectedIndices = {};
  final Set<String> _selectedTargetIds = {};

  /// 中央结算区当前展示的牌（支持同时展示，如【杀】与【闪】）
  final List<PlayedCard> _shownCards = [];
  String? _activeCardSourceId;
  List<String> _activeCardTargetIds = [];
  List<String> _activeCardTargetNames = [];
  Timer? _cardDisplayTimer;

  /// 当前结算中牌的属性：SHA / FIRE / THUNDER / OTHER（决定攻击光束配色）
  String _activeNature = 'OTHER';

  /// 出牌代次：用于忽略上一张牌遗留的延迟动画
  int _cardGen = 0;

  /// 本次【杀】已被【闪】抵消（中央盖「已抵消」印章）
  bool _dodgedStamp = false;

  /// 正在等待目标响应【闪】
  bool _waitingForDodge = false;

  /// 刚刚受击的玩家（武将卡闪红）
  final Set<String> _hitSeats = <String>{};

  /// 爆炸/爆点特效（火攻命中、传导等）
  final List<_Burst> _bursts = <_Burst>[];
  int _burstSeq = 0;

  /// 拖动/选中【杀】时鼠标的舞台坐标（用于画动态准星线）
  Offset? _aimPos;

  /// 当前选中的【杀】类牌（普通杀/火杀/雷杀），没有则返回 null
  CardModel? _aimShaCard() {
    for (final c in _handCards) {
      if (_selectedIndices.contains(c.index) && _isShaNature(c.typeKey)) {
        return c;
      }
    }
    return null;
  }

  /// 群体锦囊横幅（南蛮入侵 / 万箭齐发）
  String? _aoeBanner;

  bool _isZhangBaMode = false;
  bool _isRenDeMode = false;
  bool _isZhiHengMode = false;
  bool _isChuHaiMode = false;
  String? _activeSkill; // 谋攻篇主动技：武圣 / 乱击 / 突袭 / 国色 / 明策 / 反间 / 据守 ...
  String? _skillParam;  // 技能额外参数（清正的花色、颂的标记数）
  /// 【成务】指定消耗武将牌上的哪一张扣置牌（cardId，为空则由服务端取第一张）
  int? _chengWuCardId;

  bool _isMyTurn = false;
  String? _askPrompt;

  /// 本次询问是「是否发动某技能」（`0 = 放弃，1 = 发动`）：用底部提示栏的
  /// 【发动】/【放弃】按钮直接应答，不弹选项框
  bool _isConfirmAsk = false;
  bool _isResponding = false;
  bool _isDiscardPhase = false;
  bool _isDead = false;

  int _secondsLeft = 0;
  int _countdownTotal = 25;
  Timer? _countdownTimer;

  // ==== 特效状态 ====
  String? _flashText;
  Color _flashColor = Colors.redAccent;
  int _flashSeq = 0;
  bool _bannerVisible = false;
  String _bannerText = '';
  String _lastTurnId = '';

  String? _latestRoomRaw;
  bool _gameOverShown = false;
  bool _leaving = false;

  // ==== 牌滑动动画 ====
  final GlobalKey _stageKey = GlobalKey();
  final GlobalKey _deckKey = GlobalKey();
  final GlobalKey _handKey = GlobalKey();
  final GlobalKey _equipKey = GlobalKey();
  final GlobalKey _centerKey = GlobalKey();
  final List<_FlyingCard> _flying = [];
  int _flyingSeq = 0;
  /// 席位飘字（掉血 / 回复 / 护甲），直接落在对应武将头顶
  final List<_SeatFloat> _seatFloats = [];
  int _seatFloatSeq = 0;
  bool _hasSynced = false;
  DateTime _lastCardPlayedAt = DateTime.fromMillisecondsSinceEpoch(0);
  PlayedCard? _lastTextPlayed;
  DateTime _lastTextPlayedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _subscription = _socket.packetStream.listen(_handlePacket);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _cardDisplayTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ==================== 网络 ====================

  void _handlePacket(Packet packet) {
    if (!mounted) return;
    switch (packet.command) {
      case Command.GAME_OVER:
        _stopCountdown();
        _playResultAudio(packet.data);
        _showGameOverDialog(packet.data);
        break;
      case Command.ROOM_SYNC:
        final parts = packet.data.split('|');
        if (parts.length > 4 && parts[4] == "WAITING") {
          _latestRoomRaw = packet.data;
        }
        break;
      case Command.ASK_TARGET_ZONE:
        TargetZoneDialog.show(context, packet.data, _sendResponse);
        break;
      case Command.ASK_WU_GU:
        // 五谷丰登：清掉上一阶段的提示并隐藏操作栏，避免「确定 / 结束出牌」
        // 把上一阶段的响应当成五谷的答案发出去（服务端会静默取第一张牌）
        _stopCountdown();
        setState(() {
          _askPrompt = null;
          _isResponding = false;
          _isConfirmAsk = false;
          _isMyTurn = false;
          _selectedIndices.clear();
          _selectedTargetIds.clear();
          _isZhangBaMode = false;
        });
        // 同一轮内的多次五谷选牌共享历史：已选走的牌按下去标记「已选」
        WuGuDialog.show(context, packet.data, _sendResponse);
        break;
      case Command.ASK_LUCKY:
        _handleLuckyPrompt(packet.data);
        break;
      case Command.HERO_CANDIDATES:
        // 只有对局内的「选将阶段」才带 DRAW| 前缀；房间级候选（ROOM_SYNC 下发）不弹窗
        if (packet.data.startsWith('DRAW|')) {
          _handleHeroCandidates(packet.data.substring(5));
        }
        break;
      case Command.SHOW_JUDGE_RESULT:
        // 判定牌：从牌堆飞一张牌到被判定的角色身上，再弹判定结果
        AudioService.instance.playSfx('judge');
        _spawnJudgeFlight(packet.data);
        JudgeResultDialog.show(context, packet.data);
        break;
      case Command.CARD_PLAYED:
        _handleCardPlayed(packet.data);
        break;
      case Command.CARD_FLOW:
        _handleCardFlow(packet.data);
        break;
      case Command.CARD_REVEALED:
        _handleCardRevealed(packet.data);
        break;
      case Command.BROADCAST_MSG:
        _parseBroadcastLog(packet.data);
        setState(() => _logs.add(packet.data));
        _scrollToBottom();
        break;
      case Command.SYNC_STATE:
        _parseState(packet.data);
        break;
      case Command.ASK_ACTION:
        setState(() {
          _isMyTurn = true;
          _isResponding = false;
          _isConfirmAsk = false;
          _isDiscardPhase = packet.data.contains("弃牌阶段");
          _askPrompt = packet.data;
          _selectedIndices.clear();
          _selectedTargetIds.clear();
          _isZhangBaMode = false;
          _isRenDeMode = false;
          _isZhiHengMode = false;
          _isChuHaiMode = false;
        });
        _startCountdown();
        break;
      case Command.ASK_RESPONSE:
        setState(() {
          _isResponding = true;
          _isDiscardPhase = false;
          _askPrompt = packet.data;
          // 「0 = 放弃，1 = 发动」这类被动技能询问：走底部【发动】/【放弃】按钮
          _isConfirmAsk = RegExp(r'0\s*=\s*放弃').hasMatch(packet.data);
          _selectedIndices.clear();
          _selectedTargetIds.clear();
          _isZhangBaMode = false;
          _isRenDeMode = false;
          _isZhiHengMode = false;
          _isChuHaiMode = false;
        });
        _startCountdown();

        if (ChoicePromptDialog.matches(packet.data) && !_isConfirmAsk) {
          ChoicePromptDialog.show(context, packet.data, (v) => _sendResponse(v));
        } else if (packet.data.contains("【火攻】请弃置")) {
          // 火攻第二步：左边展示牌、右边挑同花色弃置
          final token = packet.data.split('|');
          if (token.length >= 5) {
            HuoGongDialog.showDiscardSameSuit(
              context,
              shownTypeKey: token[1],
              shownSuitKey: token[2],
              shownPoint: token[3],
              shownName: token[4],
              handCards: _handCards,
              onSelect: (idx) => _sendResponse(idx.toString()),
              onGiveUp: () => _sendResponse('PASS'),
            );
          }
        } else if (packet.data.contains("火攻展示")) {
          HuoGongDialog.showSelectCardToExpose(
              context, _handCards, (idx) => _sendResponse(idx.toString()));
        } else if (packet.data.contains("拼点")) {
          PinDianDialog.show(context, packet.data, _handCards, (idx) => _sendResponse(idx.toString()));
        }
        break;
      default:
        break;
    }
  }

  /// 开局选将：服务端 payload 为 3 名候选武将的序列化串（`;` 连接）。
  /// 选中后把武将名作为回应发回去，服务端据此设定出战武将。
  Future<void> _handleHeroCandidates(String data) async {
    final heroes = HeroModel.parseAll(data);
    if (heroes.isEmpty) {
      _sendResponse('PASS');
      return;
    }

    final testMode = _gameMode == 'TEST';
    setState(() {
      _askPrompt = testMode
          ? "选将阶段（测试模式）：可从全部 ${heroes.length} 名武将中自选"
          : "选将阶段：请从 ${heroes.length} 名候选中选择本局出战的武将";
      _isMyTurn = false;
      _isResponding = false;
      _selectedIndices.clear();
      _selectedTargetIds.clear();
    });

    // 测试模式候选是全部武将：直接用带筛选的完整武将网格自选
    if (heroes.length > 8) {
      final done = Completer<String?>();
      HeroSelectDialog.show(
        context,
        heroes,
        title: '选择出战武将（测试模式）',
        currentHero: _heroName,
        onSelect: (h) {
          if (!done.isCompleted) done.complete(h.name);
        },
      );
      final picked = await done.future
          .timeout(const Duration(minutes: 3), onTimeout: () => null);
      if (!mounted) return;
      setState(() => _askPrompt = "");
      _sendResponse(picked ?? heroes.first.name);
      return;
    }

    final notifier = ValueNotifier<List<HeroModel>>(heroes);
    String chosen = heroes.first.name;
    await HeroDrawDialog.show(
      context,
      candidates: notifier,
      currentHero: _heroName,
      title: '选择出战武将',
      dismissible: false,
      onPick: (h) => chosen = h.name,
    );
    notifier.dispose();
    if (!mounted) return;
    setState(() => _askPrompt = "");
    _sendResponse(chosen);
  }

  /// 手气卡询问：服务端 payload 形如 `手气卡剩余 4 张|序号#类型#花色#点数#ID#中文名#NONE;...`
  /// 回 "1" = 换一副起手牌，"0" = 就用这手牌。
  Future<void> _handleLuckyPrompt(String data) async {
    final sep = data.indexOf('|');
    final head = sep >= 0 ? data.substring(0, sep) : data;
    final tail = sep >= 0 ? data.substring(sep + 1) : '';

    int remaining = 0;
    final m = RegExp(r'(\d+)').firstMatch(head);
    if (m != null) remaining = int.tryParse(m.group(1)!) ?? 0;

    final hand = tail
        .split(';')
        .where((t) => t.trim().isNotEmpty)
        .map((t) => CardModel.parse(t))
        .whereType<CardModel>()
        .toList();

    setState(() {
      _askPrompt = "手气卡：剩余 $remaining 次换牌机会，不满意可以再换一副起手牌";
      _isMyTurn = false;
      _isResponding = false;
      _selectedIndices.clear();
      _selectedTargetIds.clear();
    });

    final ans = await LuckyCardDialog.show(context, remaining: remaining, hand: hand);
    if (!mounted) return;
    setState(() => _askPrompt = "");
    _sendResponse(ans ?? '0');
  }

  /// 结构化出牌广播（服务端 CARD_PLAYED）：
  /// sourceId|sourceName|typeKey|suitKey|point|cardName|targetId:targetName,...
  /// 有了它，中央展示的就是「真正打出的那张牌」，不需要再从中文播报里猜。
  void _handleCardPlayed(String data) {
    final parts = data.split('|');
    if (parts.length < 6) return;
    final sourceId = parts[0].trim();
    final sourceName = parts[1].trim();
    final typeKeyRaw = parts[2].trim();
    final suitKey = parts[3].trim();
    final point = parts[4].trim();
    final cardName = parts[5].trim();

    final targetNames = <String>[];
    final targetIds = <String>[];
    if (parts.length > 6 && parts[6].trim().isNotEmpty) {
      for (final seg in parts[6].split(',')) {
        final kv = seg.trim().split(':');
        if (kv.isEmpty || kv[0].trim().isEmpty) continue;
        targetIds.add(kv[0].trim());
        if (kv.length > 1) targetNames.add(kv[1].trim());
      }
    }

    _lastCardPlayedAt = DateTime.now();
    // 出牌语音：杀 / 闪 / 桃 / 酒 / 各锦囊都有对应语音，装备等退回气流声
    AudioService.instance.playCard(cardName);
    final played = PlayedCard(
      name: cardName,
      typeKey: typeKeyRaw.isEmpty ? CardCatalog.typeKeyOfName(cardName) : typeKeyRaw,
      sourceName: sourceName,
      targetNames: targetNames,
      suit: suitKey.isEmpty ? null : suitKey,
      points: point.isEmpty ? null : point,
    );

    final resolvedTypeKey =
        typeKeyRaw.isEmpty ? (CardCatalog.typeKeyOfName(cardName) ?? '') : typeKeyRaw;
    final nature = _natureOf(resolvedTypeKey);
    final gen = ++_cardGen;
    setState(() {
      // 同一次出牌可能先到中文播报、后到结构化广播：把猜出来的那张撤掉，避免中央重复
      final guess = _lastTextPlayed;
      if (guess != null &&
          DateTime.now().difference(_lastTextPlayedAt).inMilliseconds < 900 &&
          guess.sourceName == sourceName) {
        _shownCards.remove(guess);
        _lastTextPlayed = null;
      }
      _activeCardSourceId = sourceId.isEmpty ? _findPlayerIdByName(sourceName) : sourceId;
      _activeCardTargetNames = List<String>.from(targetNames);
      _activeNature = nature;
      // 目标光束逐个点亮，形成「按座次依次扫射」的节奏
      _activeCardTargetIds = <String>[];
      _dodgedStamp = false;
      _waitingForDodge = _isShaNature(nature) && targetIds.isNotEmpty;
      _shownCards.add(played);
      while (_shownCards.length > 4) {
        _shownCards.removeAt(0);
      }
    });
    for (var i = 0; i < targetIds.length; i++) {
      Future.delayed(Duration(milliseconds: 120 * i), () {
        if (!mounted || gen != _cardGen) return;
        setState(() => _activeCardTargetIds.add(targetIds[i]));
      });
    }
    if (_waitingForDodge) {
      Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _waitingForDodge = false);
      });
    }
    // 群体锦囊：屏幕上方展开横幅（战象奔腾 / 箭雨阵）
    String? bannerText;
    if (resolvedTypeKey == 'NAN_MAN_RU_QIN') bannerText = '🐘 南蛮入侵';
    if (resolvedTypeKey == 'WAN_JIAN_QI_FA') bannerText = '🏹 万箭齐发';
    if (resolvedTypeKey == 'TAO_YUAN_JIE_YI') bannerText = '🌸 桃园结义';
    if (bannerText != null) {
      setState(() => _aoeBanner = bannerText);
      Timer(const Duration(milliseconds: 1700), () {
        if (mounted && _aoeBanner == bannerText) {
          setState(() => _aoeBanner = null);
        }
      });
    }
    Timer(const Duration(milliseconds: 3400), () {
      if (mounted) setState(() => _shownCards.remove(played));
    });

    // 出牌动画：牌从出牌者席位飞向中央结算区（所有人出牌都有这个「牌感」）
    final srcId = sourceId.isEmpty ? _findPlayerIdByName(sourceName) : sourceId;
    if (srcId != null && srcId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final seatKey = _seatKeys[srcId];
        final from = seatKey == null ? null : _stageCenterOf(seatKey);
        if (from == null) return;
        _spawnFlight(
          fromPos: from,
          dest: 'center',
          typeKey: played.typeKey,
          name: cardName,
          suitSymbol: _suitSymbolOf(suitKey),
          points: point,
          isRed: suitKey == 'HEART' || suitKey == 'DIAMOND',
          width: 86,
          height: 122,
          arc: 46,
        );
      });
    }
    _cardDisplayTimer?.cancel();
    _cardDisplayTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() {
          _activeCardTargetNames.clear();
          _activeCardSourceId = null;
          _activeCardTargetIds.clear();
        });
      }
    });
  }

  // ==================== 牌滑动动画 ====================

  /// 由牌的类型键推导属性（决定攻击光束的颜色：赤红 / 炽橙 / 紫蓝）
  String _natureOf(String typeKey) {
    switch (typeKey) {
      case 'FIRE_SHA':
        return 'FIRE';
      case 'THUNDER_SHA':
        return 'THUNDER';
      case 'SHA':
        return 'SHA';
      case 'GUO_HE_CHAI_QIAO':
        return 'DISMANTLE';
      case 'SHUN_SHOU_QIAN_YANG':
        return 'SNATCH';
      case 'DUEL':
        return 'DUEL';
      default:
        return 'OTHER';
    }
  }

  /// 是否是【杀】类（普通杀 / 火杀 / 雷杀）
  bool _isShaNature(String nature) =>
      nature == 'SHA' || nature == 'FIRE' || nature == 'THUNDER';

  /// 从「杀【黑桃5】」这类播报文本里还原牌的类型键（用于飞行卡面）
  String _typeKeyOfLabel(String label) {
    final cleaned = label.replaceAll(RegExp(r'【.*?】'), '').trim();
    final key = CardCatalog.typeKeyOfName(cleaned.isEmpty ? label : cleaned);
    return key ?? 'SHA';
  }

  /// 属性对应的主色（用于光束、飘字与提示）
  static Color _natureColor(String nature) {
    switch (nature) {
      case 'SHA':
        return const Color(0xFFFF5252);
      case 'FIRE':
        return const Color(0xFFFF9100);
      case 'THUNDER':
        return const Color(0xFF8E9BFF);
      default:
        return const Color(0xFFFFC107);
    }
  }

  /// 取某个控件在战局舞台坐标系里的中心点（ScaledStage 内部空间）
  Offset? _stageCenterOf(GlobalKey key) {
    final stageBox = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (stageBox == null || box == null || !stageBox.hasSize || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero), ancestor: stageBox);
  }

  /// 从 fromPos 飞向 toPos 的一张牌（typeKey 为 null 时画牌背，用于摸牌）
  void _spawnFlight({
    Offset? fromPos,
    Offset? toPos,
    required String dest,
    String? typeKey,
    String name = '',
    String suitSymbol = '',
    String points = '',
    bool isRed = true,
    double width = 76,
    double height = 107,
    int delayMs = 0,
    double arc = 30,
  }) {
    final from = fromPos ?? _stageCenterOf(_deckKey);
    Offset? to = toPos;
    if (to == null) {
      if (dest == 'hand') to = _stageCenterOf(_handKey);
      if (dest == 'equip') to = _stageCenterOf(_equipKey);
      if (dest == 'center') to = _stageCenterOf(_centerKey);
      if (dest == 'deck') to = _stageCenterOf(_deckKey);
      if (dest == 'stage') to = _stageCenterOf(_stageKey);
    }
    if (from == null || to == null) return;
    final f = _FlyingCard(
      seq: _flyingSeq++,
      from: from,
      to: to,
      typeKey: typeKey,
      name: name,
      suitSymbol: suitSymbol,
      points: points,
      isRed: isRed,
      width: width,
      height: height,
      delayMs: delayMs,
      arc: arc,
    );
    setState(() => _flying.add(f));
  }

  void _removeFlight(_FlyingCard f) {
    if (!mounted) return;
    setState(() => _flying.remove(f));
  }

  /// 判定：一张牌从牌堆飞向被判定的角色（payload `玩家|锦囊|牌描述|typeKey|suitKey|point|effect`）
  void _spawnJudgeFlight(String data) {
    final seg = data.split('|');
    if (seg.length < 5) return;
    final who = seg[0].trim();
    final typeKey = seg[3].trim();
    final suitKey = seg[4].trim();
    final point = seg.length > 5 ? seg[5].trim() : '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = _findPlayerIdByName(who) ?? widget.playerId;
      final to = _stageCenterOf(_seatKeyOf(id));
      if (to == null) return;
      _spawnFlight(
        toPos: to,
        dest: 'seat',
        typeKey: CardFace.hasArt(typeKey) ? typeKey : null,
        suitSymbol: _suitSymbolOf(suitKey),
        points: point,
        isRed: suitKey == 'HEART' || suitKey == 'DIAMOND',
        width: 78,
        height: 110,
        arc: 44,
      );
    });
  }

  /// 在某个角色头顶飘一条数字（掉血 -1 / 回复 +1 / 护甲 🛡）。找不到人就退回屏幕中央。
  /// 受击时让该玩家的武将卡边框闪红 520ms
  void _flashSeat(String playerName) {    final id = _findPlayerIdByName(playerName);
    if (id == null || !mounted) return;
    setState(() => _hitSeats.add(id));
    Timer(const Duration(milliseconds: 520), () {
      if (mounted) setState(() => _hitSeats.remove(id));
    });
  }

  /// 在指定玩家的武将卡位置炸开一个光团（火攻命中 / 属性传导）
  void _spawnBurst(String playerName, Color color) {
    final id = _findPlayerIdByName(playerName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pos = id == null
          ? _stageCenterOf(_seatKeyOf(widget.playerId))
          : _stageCenterOf(_seatKeyOf(id));
      if (pos == null) return;
      final b = _Burst(seq: _burstSeq++, pos: pos, color: color);
      setState(() => _bursts.add(b));
    });
  }

  Widget _buildBurst(_Burst b) {
    return Positioned(
      left: b.pos.dx - 48,
      top: b.pos.dy - 48,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeOut,
          onEnd: () {
            if (mounted) setState(() => _bursts.remove(b));
          },
          builder: (ctx, p, child) {
            return Opacity(
              opacity: (1.0 - p).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.35 + p * 1.75,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      b.color.withValues(alpha: 0.95),
                      b.color.withValues(alpha: 0.25),
                      Colors.transparent,
                    ], stops: const [0.0, 0.55, 1.0]),
                    boxShadow: [
                      BoxShadow(
                        color: b.color.withValues(alpha: 0.65 * (1.0 - p)),
                        blurRadius: 34,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _spawnSeatFloat(String playerName, String text, Color color) {    final id = _findPlayerIdByName(playerName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Offset? pos;
      if (id != null) pos = _stageCenterOf(_seatKeyOf(id));
      pos ??= _stageCenterOf(_seatKeyOf(widget.playerId));
      if (pos == null) {
        _flash(text, color);
        return;
      }
      final f = _SeatFloat(seq: _seatFloatSeq++, pos: pos, text: text, color: color);
      setState(() => _seatFloats.add(f));
      Timer(const Duration(milliseconds: 1150), () {
        if (mounted) setState(() => _seatFloats.remove(f));
      });
    });
  }

  Widget _buildFlight(_FlyingCard f) {
    // 设置里的「动画速度」直接作用在飞行时长上（2.0 = 快一倍）
    final speed = AppSettings.instance.animSpeed.clamp(0.5, 2.0);
    final moveMs = 460.0 / speed;
    final delayMs = f.delayMs / speed;
    final total = moveMs + delayMs;
    final card = f.typeKey == null
        ? _FlightCardBack(width: f.width, height: f.height)
        : CardFace(
            typeKey: f.typeKey!,
            name: f.name,
            suitSymbol: f.suitSymbol,
            points: f.points,
            isRed: f.isRed,
            index: 0,
            showIndex: false,
            width: f.width,
            height: f.height,
          );
    return TweenAnimationBuilder<double>(
      key: ValueKey(f.seq),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: total.round()),
      curve: Curves.linear,
      onEnd: () => _removeFlight(f),
      builder: (_, raw, child) {
        final p = ((raw * total - delayMs) / moveMs).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(p);
        final pos = Offset.lerp(f.from, f.to, eased)!;
        final lift = -math.sin(eased * math.pi) * f.arc;
        final scale = 1.15 - 0.35 * eased;
        final opacity = p < 0.88 ? 1.0 : (1.0 - (p - 0.88) / 0.12).clamp(0.0, 1.0);
        return Positioned(
          left: pos.dx - f.width / 2,
          top: pos.dy - f.height / 2 + lift,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
      child: card,
    );
  }

  void _startCountdown() {
    // 无懈可击是并发询问，服务端只等 5 秒，倒计时要与之一致
    final total = (_askPrompt != null && _askPrompt!.contains("无懈可击")) ? 5 : _timeoutSeconds;
    setState(() {
      _countdownTotal = total;
      _secondsLeft = total;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft = _secondsLeft - 1);
      if (_secondsLeft <= 0) {
        timer.cancel();
        // 超时由服务端自动 PASS，这里只收起界面
        setState(() {
          _askPrompt = null;
          _isResponding = false;
          _selectedIndices.clear();
          _selectedTargetIds.clear();
        });
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted) setState(() => _secondsLeft = 0);
  }

  void _showGameOverDialog(String detail) {
    if (_gameOverShown) return;
    _gameOverShown = true;
    setState(() {
      _askPrompt = null;
      _isResponding = false;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF262732),
        title: const Text('🏆 对局结算',
            style: TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(detail, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _safeExitToLobby();
            },
            child: const Text('退出到大厅', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
            onPressed: () {
              Navigator.of(ctx).pop();
              _backToRoom();
            },
            child: const Text('返回房间', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _backToRoom() {
    if (_leaving) return;
    final raw = _latestRoomRaw;
    if (raw == null) {
      _safeExitToLobby();
      return;
    }
    _leaving = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RoomScreen(
        playerId: widget.playerId,
        playerName: widget.playerName,
        initialRoomRaw: raw,
      ),
    ));
  }

  void _safeExitToLobby() {
    if (_leaving) return;
    _leaving = true;
    _stopCountdown();
    _socket.sendPacket(Packet(command: Command.LEAVE_ROOM, senderId: widget.playerId, data: "SURRENDER"));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LobbyScreen(playerId: widget.playerId, playerName: widget.playerName),
      ),
      (route) => false,
    );
  }

  // ==================== 状态解析 ====================

  void _parseBroadcastLog(String log) {
    final audio = AudioService.instance;
    // 【决斗】轮流出杀：每次有人打出【杀】，从该玩家席位飞一张【杀】到中央
    final duelPlay = RegExp(r'^(.+?)\s*打出\s*(.+?)继续决斗。').firstMatch(log);
    if (duelPlay != null) {
      final who = duelPlay.group(1)!.trim();
      final label = duelPlay.group(2)!.trim();
      audio.playSfx('play', volume: 0.8);
      _spawnSeatFloat(who, '斩！', const Color(0xFFFFAB40));
      final id = _playerMentioned(who);
      final seatKey = id == null ? null : _seatKeys[id];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final from = seatKey == null ? null : _stageCenterOf(seatKey);
        _spawnFlight(
          fromPos: from,
          dest: 'center',
          typeKey: _typeKeyOfLabel(label),
          name: label.replaceAll(RegExp(r'【.*?】'), ''),
          width: 72,
          height: 102,
          arc: 40,
        );
      });
    }

    // 防具触发提示：八卦阵 / 仁王盾 / 藤甲 / 白银狮子
    for (final entry in const {
      '【八卦阵】': '八卦阵判定',
      '【仁王盾】': '仁王盾生效',
      '【藤甲】': '藤甲生效',
      '【白银狮子】': '白银狮子',
    }.entries) {
      if (log.contains(entry.key)) {
        final who = _playerMentioned(log);
        audio.playSfx('shield', volume: 0.7);
        if (who != null) {
          _spawnSeatFloat(who, entry.value, const Color(0xFF90CAF9));
        }
        break;
      }
    }

    // 【闪】抵消：中央盖「已抵消」印章，攻击光束同时消散
    if (log.contains('躲避了攻击')) {
      final who = _playerMentioned(log);
      audio.playSfx('shield');
      setState(() {
        _dodgedStamp = true;
        _waitingForDodge = false;
        _activeCardTargetIds.clear();
      });
      if (who != null) {
        _spawnSeatFloat(who, '已抵消', const Color(0xFF80DEEA));
      }
      Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _dodgedStamp = false);
      });
    }
    if (log.contains('伤害') || log.contains('防止')) {
      if (_waitingForDodge && mounted) {
        setState(() => _waitingForDodge = false);
      }
    }
    // 伤害 / 回复 / 护甲 飘字：落在当事人武将卡头上（找不到人再退回屏幕中央）
    final dmg = RegExp(r'受到\s*(\d+)\s*点(?:传导)?伤害').firstMatch(log);
    if (dmg != null) {
      audio.playSfx('damage');
      final who = _playerMentioned(log);
      final color = log.contains('传导') ? const Color(0xFFB39DDB) : Colors.redAccent;
      if (who != null) {
        _flashSeat(who);
        _spawnSeatFloat(who, '-${dmg.group(1)}', color);
        // 属性爆点：火焰（火杀/火攻）橙红爆团，雷电紫蓝，铁索传导淡紫
        if (log.contains('火焰') || log.contains('火攻')) {
          _spawnBurst(who, const Color(0xFFFF6D00));
        } else if (log.contains('雷')) {
          _spawnBurst(who, const Color(0xFF7C4DFF));
        } else if (log.contains('传导')) {
          _spawnBurst(who, const Color(0xFFB39DDB));
        }
      } else {
        _flash('-${dmg.group(1)}', color);
      }
    }
    final heal = RegExp(r'回复\s*(\d+)\s*点体力').firstMatch(log);
    if (heal != null) {
      audio.playSfx('heal');
      final who = _playerMentioned(log);
      if (who != null) {
        _spawnSeatFloat(who, '+${heal.group(1)}', Colors.greenAccent);
        // 治愈光点：从中央结算区飞回被治疗者的武将卡
        final hid = _findPlayerIdByName(who);
        final seatKey = hid == null ? null : _seatKeys[hid];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _spawnFlight(
            dest: 'seat',
            toPos: seatKey == null ? null : _stageCenterOf(seatKey),
            fromPos: _stageCenterOf(_centerKey),
            typeKey: 'TAO',
            name: '桃',
            width: 60,
            height: 85,
            arc: 26,
          );
        });
      } else {
        _flash('+${heal.group(1)}', Colors.greenAccent);
      }
    }
    final shield = RegExp(r'抵消了\s*(\d+)\s*点伤害').firstMatch(log);
    if (shield != null) {
      audio.playSfx('shield');
      final who = _playerMentioned(log);
      if (who != null) {
        _spawnSeatFloat(who, '🛡${shield.group(1)}', Colors.lightBlueAccent);
      } else {
        _flash('🛡${shield.group(1)}', Colors.lightBlueAccent);
      }
    }
    final armorGain = RegExp(r'获得\s*(\d+)\s*点【护甲】').firstMatch(log);
    if (armorGain != null) {
      audio.playSfx('shield');
      final who = _playerMentioned(log);
      if (who != null) {
        _spawnSeatFloat(who, '+🛡${armorGain.group(1)}', const Color(0xFF64B5F6));
      } else {
        _flash('+🛡${armorGain.group(1)}', const Color(0xFF64B5F6));
      }
    }
    _animateCardFeel(log);

    // 五谷丰登：别人选走了哪张牌（旁观者也能看到「谁拿了什么」）
    final wuguPick = RegExp(r'^(.+?)\s*挑选了\s*(.+?)$').firstMatch(log.trim());
    if (wuguPick != null) {
      final picker = wuguPick.group(1)!.trim();
      final what = wuguPick.group(2)!.trim();
      audio.playSfx('draw', volume: 0.5);
      _flash('$picker 选走了 $what', const Color(0xFFFFC94D));
      _spawnSeatFloat(picker, what, const Color(0xFFFFC94D));
    }

    if (log.contains("使用了") || log.contains("打出") || log.contains("装备了")) {
      String? cardName;
      const allCardTypes = [
        "火杀", "雷杀", "杀", "闪", "桃", "酒", "过河拆桥", "顺手牵羊", "无中生有", "决斗",
        "南蛮入侵", "万箭齐发", "桃园结义", "五谷丰登", "火攻", "铁索连环", "兵粮寸断", "乐不思蜀", "闪电",
        "诸葛连弩", "丈八蛇矛", "青釭剑", "贯石斧", "八卦阵", "仁王盾", "白银狮子", "藤甲", "+1马", "-1马"
      ];

      for (final type in allCardTypes) {
        if (log.contains(type)) {
          cardName = type;
          break;
        }
      }

      if (cardName != null) {
        // 提取发起者名字：去掉前缀符号后，截到「对 / 使用了 / 打出 / 装备了」之前
        String srcName = log
            .replaceAll(RegExp(r'^[^【]*?(?=[\u4e00-\u9fa5A-Za-z0-9(（])'), '')
            .split(RegExp(r'\s*(?:对\s|使用了|打出|装备了)'))[0]
            .replaceAll(RegExp(r'^[★⚔🍶📢🏹🌸🌾🔥⛓🈲🛡⚡💀❤🏅⚖🔮🔄☠\s]+'), '')
            .trim();
        List<String> tgNames = [];
        final tgMatch = RegExp(r'对 (.*?) (使用|发起)').firstMatch(log);
        if (tgMatch != null && tgMatch.group(1) != null) {
          tgNames.add(tgMatch.group(1)!.trim());
        }

        _cardDisplayTimer?.cancel();
        final String cardNameStr = cardName;
        // 从播报里解析牌的花色与点数（如「杀【黑桃K】」）
        String? playedSuit;
        String? playedPoints;
        final labelMatch =
            RegExp(r'【(黑桃|红桃|草花|方片)(A|2|3|4|5|6|7|8|9|10|J|Q|K)】').firstMatch(log);
        if (labelMatch != null) {
          playedSuit = switch (labelMatch.group(1)!) {
            '黑桃' => 'SPADE',
            '红桃' => 'HEART',
            '草花' => 'CLUB',
            _ => 'DIAMOND',
          };
          playedPoints = labelMatch.group(2);
        }
        final playedCard = PlayedCard(
          name: cardNameStr,
          typeKey: CardCatalog.typeKeyOfName(cardNameStr),
          sourceName: srcName,
          targetNames: List<String>.from(tgNames),
          suit: playedSuit,
          points: playedPoints,
        );
        // 已经收到服务端的结构化 CARD_PLAYED（含真实牌名/花色/点数）时，不再用播报文本猜牌
        if (DateTime.now().difference(_lastCardPlayedAt).inMilliseconds < 800) {
          return;
        }
        _lastTextPlayed = playedCard;
        _lastTextPlayedAt = DateTime.now();
        setState(() {
          _activeCardTargetNames = tgNames;
          _activeCardSourceId = _findPlayerIdByName(srcName);
          _activeCardTargetIds =
              tgNames.map((n) => _findPlayerIdByName(n)).whereType<String>().toList();
          _shownCards.add(playedCard);
          while (_shownCards.length > 4) {
            _shownCards.removeAt(0);
          }
        });
        // 展示 3.4 秒后移出结算区
        Timer(const Duration(milliseconds: 3400), () {
          if (mounted) setState(() => _shownCards.remove(playedCard));
        });

        _cardDisplayTimer = Timer(const Duration(milliseconds: 3200), () {
          if (mounted) {
            setState(() {
              _activeCardTargetNames.clear();
              _activeCardSourceId = null;
              _activeCardTargetIds.clear();
            });
          }
        });
      }
    }

    // 技能发动：播报「★ X 发动了技能【Y】」时放技能音效 + 语音
    if (log.contains('发动了技能') || log.contains('发动了【')) {
      audio.playSfx('skill');
      audio.playVoice('jineng');
    }
  }

  String _suitSymbolOf(String suitKey) {
    switch (suitKey) {
      case 'SPADE':
        return '♠';
      case 'HEART':
        return '♥';
      case 'CLUB':
        return '♣';
      case 'DIAMOND':
        return '♦';
      default:
        return '';
    }
  }

  String? _findPlayerIdByName(String name) {
    if (name.contains(widget.playerName)) return widget.playerId;
    for (final opp in _opponents) {
      if (name.contains(opp.name)) return opp.id;
    }
    return null;
  }

  /// 播报里出现的角色名（取最先出现的那一个）
  String? _playerMentioned(String log) {
    final candidates = <String>[
      _heroName,
      widget.playerName,
      for (final o in _opponents) o.name,
      for (final o in _opponents) o.hero,
    ].where((s) => s.isNotEmpty && s != '未选将').toSet().toList();
    String? best;
    var bestIdx = 1 << 30;
    for (final c in candidates) {
      final i = log.indexOf(c);
      if (i >= 0 && i < bestIdx) {
        bestIdx = i;
        best = c;
      }
    }
    return best;
  }

  /// 让「摸牌 / 弃牌 / 装备」这些播报也飞牌（不只自己，所有人都有）
  void _animateCardFeel(String log) {
    final who = _playerMentioned(log);
    final whoId = who == null ? null : _findPlayerIdByName(who);
    final isSelf = whoId != null && whoId == widget.playerId;

    // ---- 摸牌 ----
    final draw = RegExp(r'摸了\s*(\d+)\s*张牌').firstMatch(log);
    if (draw != null && !isSelf) {
      final n = (int.tryParse(draw.group(1)!) ?? 1).clamp(1, 5);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || whoId == null) return;
        final pos = _stageCenterOf(_seatKeyOf(whoId));
        if (pos == null) return;
        for (var i = 0; i < n; i++) {
          _spawnFlight(
            toPos: pos,
            dest: 'seat',
            width: 58,
            height: 82,
            delayMs: i * 70,
            arc: 30,
          );
        }
      });
    }

    // ---- 弃牌 ----
    final discard = RegExp(r'弃置(?:了)?\s*(\d+)\s*张').firstMatch(log);
    if (discard != null && !isSelf) {
      final n = (int.tryParse(discard.group(1)!) ?? 1).clamp(1, 4);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || whoId == null) return;
        final pos = _stageCenterOf(_seatKeyOf(whoId));
        if (pos == null) return;
        for (var i = 0; i < n; i++) {
          _spawnFlight(
            fromPos: pos,
            dest: 'deck',
            width: 58,
            height: 82,
            delayMs: i * 60,
            arc: 22,
          );
        }
      });
    }

    // ---- 装备（别人的装备也要看得见：牌从他席位飞起来 + 席位卡底部条同步） ----
    final equip = RegExp(r'装备了\s*(?:【(.+?)】|(\S+))').firstMatch(log);
    if (equip != null && !isSelf) {
      final name = (equip.group(1) ?? equip.group(2) ?? '').trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || whoId == null) return;
        final pos = _stageCenterOf(_seatKeyOf(whoId));
        if (pos == null) return;
        _spawnFlight(
          fromPos: pos,
          toPos: Offset(pos.dx, pos.dy + 40),
          dest: 'seat',
          typeKey: CardCatalog.typeKeyOfName(name),
          name: name,
          width: 62,
          height: 88,
          arc: 12,
        );
      });
    }
  }

  void _parseState(String raw) {
    final prevHandCount = _handCards.length;
    final Map<String, int> prevOppHand = {
      for (final o in _opponents) o.id: o.handCount
    };
    final prevWeapon = _weapon;
    final prevArmor = _armor;
    final prevDefHorse = _defHorse;
    final prevOffHorse = _offHorse;
    final parts = raw.split('|');
    for (String part in parts) {
      if (part.startsWith('武将:')) _heroName = part.substring(3);
      if (part.startsWith('HP:')) {
        final hpParts = part.substring(3).split('/');
        _hp = int.tryParse(hpParts[0]) ?? 4;
        _maxHp = int.tryParse(hpParts.length > 1 ? hpParts[1] : "4") ?? 4;
      }
      if (part.startsWith('DECK:')) _deckInfo = part.substring(5);
      if (part.startsWith('SKILLS:')) {
        final skStr = part.substring(7);
        _skills = skStr.isEmpty
            ? []
            : skStr.split(';').map((sk) {
                // 新格式：名字#类型#可用性(1/0)#剩余#上限#描述 ；兼容旧格式 名字:类型:描述
                if (sk.contains('#')) {
                  final sp = sk.split('#');
                  final hasCounter = sp.length > 5;
                  return SkillModel(
                      name: sp[0],
                      type: sp.length > 1 ? sp[1] : 'PASSIVE',
                      usable: sp.length > 2 ? sp[2] != '0' : true,
                      remain: hasCounter ? (int.tryParse(sp[3]) ?? 0) : 0,
                      cap: hasCounter ? (int.tryParse(sp[4]) ?? 0) : 0,
                      desc: hasCounter
                          ? sp.sublist(5).join('#')
                          : (sp.length > 3 ? sp.sublist(3).join('#') : ''));
                }
                final sp = sk.split(':');
                return SkillModel(
                    name: sp[0],
                    type: sp.length > 1 ? sp[1] : 'PASSIVE',
                    desc: sp.length > 2 ? sp[2] : '');
              }).toList();
      }
      if (part.startsWith('EQUIP:')) {
        final eqStr = part.substring(6);
        _weapon = "无";
        _armor = "无";
        _defHorse = "无";
        _offHorse = "无";
        if (eqStr.isNotEmpty) {
          for (String eq in eqStr.split(',')) {
            final ep = eq.split(':');
            if (ep.length >= 2) {
              if (ep[0] == 'WEAPON') _weapon = ep[1];
              if (ep[0] == 'ARMOR') _armor = ep[1];
              if (ep[0] == 'DEFENSIVE_HORSE') _defHorse = ep[1];
              if (ep[0] == 'OFFENSIVE_HORSE') _offHorse = ep[1];
            }
          }
        }
      }
      if (part.startsWith('JUDGE:')) {
        final jStr = part.substring(6);
        _judgeAreaCards = jStr.isEmpty ? [] : jStr.split(',').toList();
      }
      if (part.startsWith('MARKS:')) {
        final mStr = part.substring(6);
        _myMarks = mStr.isEmpty ? [] : mStr.split(',').toList();
      }
      if (part.startsWith('OPPONENTS:')) {
        final oppContent = part.substring(10).trim();
        _opponents = oppContent.isEmpty
            ? []
            : oppContent
                .split(';')
                .map((t) => OpponentModel.parse(t))
                .whereType<OpponentModel>()
                .toList();
      }
      if (part.startsWith('CARDS:')) {
        final cardsContent = part.substring(6).trim();
        _handCards = cardsContent.isEmpty
            ? []
            : cardsContent
                .split(';')
                .map((t) => CardModel.parse(t))
                .whereType<CardModel>()
                .toList();
        // 设置里开了「手牌自动排序」就按点数从大到小（A 最大）重排
        if (AppSettings.instance.autoSortHand) {
          _handCards.sort((a, b) => b.pointValue.compareTo(a.pointValue));
        }
      }
      if (part.startsWith('TURN:')) _turnPlayerId = part.substring(5);
      if (part.startsWith('PHASE:')) _currentPhaseName = part.substring(6);
      if (part.startsWith('ROLE:')) _myRole = part.substring(5);
      if (part.startsWith('ROLECN:')) _myRoleCn = part.substring(7);
      if (part.startsWith('MODE:')) _gameMode = part.substring(5);
      if (part.startsWith('WINE:')) _wineBonus = int.tryParse(part.substring(5)) ?? 0;
      if (part.startsWith('OPPSKILLS:')) {
        final raw = part.substring(10).trim();
        _oppSkills = {};
        if (raw.isNotEmpty) {
          for (final seg in raw.split(';')) {
            final idx = seg.indexOf(':');
            if (idx <= 0) continue;
            final id = seg.substring(0, idx);
            final list = seg.substring(idx + 1);
            _oppSkills[id] = list.isEmpty
                ? <SkillModel>[]
                : list.split(',').map((s) {
                    final sp = s.split('#');
                    return SkillModel(
                      name: sp.isNotEmpty ? sp[0] : '',
                      type: sp.length > 1 ? sp[1] : 'PASSIVE',
                      desc: sp.length > 2 ? sp.sublist(2).join('#') : '',
                    );
                  }).toList();
          }
        }
      }
      if (part.startsWith('ALIVE:')) _aliveCount = int.tryParse(part.substring(6)) ?? 1;
      if (part.startsWith('ROUND:')) _roundNo = int.tryParse(part.substring(6)) ?? 1;
      if (part.startsWith('TIMEOUT:')) _timeoutSeconds = int.tryParse(part.substring(8)) ?? 25;
      if (part.startsWith('MAXHAND:')) _maxHandCards = int.tryParse(part.substring(8)) ?? 0;
      if (part.startsWith('RANGE:')) _attackRange = int.tryParse(part.substring(6)) ?? 1;
      if (part.startsWith('ARMOR:')) _myArmor = int.tryParse(part.substring(6)) ?? 0;
      if (part.startsWith('FLIP:')) _myFlipped = part.substring(5) == '1';
      if (part.startsWith('FACTION:')) _myFaction = part.substring(8).trim();
      if (part.startsWith('EXILE:')) _myExileCount = int.tryParse(part.substring(6)) ?? 0;
      if (part.startsWith('EXILECARDS:')) {
        final raw = part.substring(11).trim();
        _exiledCards = <_ExiledCardInfo>[];
        if (raw.isNotEmpty && raw != '-') {
          for (final seg in raw.split(';')) {
            final sp = seg.split('#');
            if (sp.length < 6) continue;
            _exiledCards.add(_ExiledCardInfo(
              ownerId: sp[0],
              typeKey: sp[1],
              name: sp[2],
              suitKey: sp[3],
              point: sp[4],
              cardId: int.tryParse(sp[5]) ?? 0,
            ));
          }
        }
      }
    }
    _isDead = _hp <= 0;
    _isMyTurn = _turnPlayerId == widget.playerId;
    // 选好将后念一次出场语音（每位武将一句）
    if (_heroName.isNotEmpty && _heroName != '未选将' && _heroName != _introPlayedHero) {
      _introPlayedHero = _heroName;
      AudioService.instance.playHeroIntro(_heroName);
    }
    if (_turnPlayerId != _lastTurnId) {
      _lastTurnId = _turnPlayerId;
      if (_turnPlayerId == widget.playerId && _turnPlayerId.isNotEmpty) {
        _showBanner('你的回合');
        AudioService.instance.playSfx('turn');
        AudioService.instance.playVoice('wodehuibe');
      }
    }
    setState(() {});

    // 摸牌 / 装备的滑动动画（首帧同步不播，避免开局一堆牌乱飞）
    if (_hasSynced) {
      final gained = _handCards.length - prevHandCount;
      if (gained > 0) {
        final n = math.min(gained, 5);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          for (int i = 0; i < n; i++) {
            _spawnFlight(dest: 'hand', delayMs: i * 65, arc: 34);
          }
        });
      } else if (_handCards.length < prevHandCount) {
        // 弃牌：牌从手牌区飞到弃牌堆（刚打出过牌时不播，避免和出牌动画打架）
        final bool justPlayed =
            DateTime.now().difference(_lastCardPlayedAt).inMilliseconds < 700;
        if (!justPlayed) {
          final n = math.min(prevHandCount - _handCards.length, 4);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final from = _stageCenterOf(_handKey);
            if (from == null) return;
            for (int i = 0; i < n; i++) {
              _spawnFlight(
                fromPos: from,
                dest: 'deck',
                delayMs: i * 60,
                arc: 22,
                width: 58,
                height: 82,
              );
            }
          });
        }
      }
      // 其他玩家摸牌：同样要有「牌飞过去」的感觉
      for (final o in _opponents) {
        final before = prevOppHand[o.id];
        if (before == null) continue;
        final gained = o.handCount - before;
        if (gained <= 0) continue;
        final n = math.min(gained, 3);
        final seatKey = _seatKeys[o.id];
        if (seatKey == null) continue;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final to = _stageCenterOf(seatKey);
          for (int i = 0; i < n; i++) {
            _spawnFlight(
              dest: 'seat',
              toPos: to,
              delayMs: 40 + i * 70,
              arc: 30,
              width: 62,
              height: 88,
            );
          }
        });
      }
      final equipNow = <String, String>{
        'WEAPON': _weapon,
        'ARMOR': _armor,
        'DEF': _defHorse,
        'OFF': _offHorse,
      };
      final equipPrev = <String, String>{
        'WEAPON': prevWeapon,
        'ARMOR': prevArmor,
        'DEF': prevDefHorse,
        'OFF': prevOffHorse,
      };
      equipNow.forEach((slot, name) {
        if (name != '无' && name != equipPrev[slot]) {
          final key = CardCatalog.typeKeyOfName(name);
          final old = equipPrev[slot];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // 旧装备被替换：从装备区飞向弃牌堆
            if (old != null && old != '无' && old.isNotEmpty) {
              _spawnFlight(
                dest: 'deck',
                fromPos: _stageCenterOf(_equipKey),
                typeKey: CardCatalog.typeKeyOfName(old),
                name: old,
                arc: 22,
                width: 62,
                height: 88,
              );
            }
            _spawnFlight(
              dest: 'equip',
              fromPos: _stageCenterOf(_stageKey),
              typeKey: key,
              name: name,
              delayMs: 60,
              arc: 18,
              width: 68,
              height: 96,
            );
          });
        }
      });
    }
    _hasSynced = true;
  }

  // ==================== 交互 ====================

  bool _isCardRequiringTarget(CardModel card) {
    final type = card.typeKey;
    return type.contains('SHA') ||
        type == 'DUEL' ||
        type == 'GUO_HE_CHAI_QIAO' ||
        type == 'SHUN_SHOU_QIAN_YANG' ||
        type == 'HUO_GONG' ||
        type == 'BING_LIANG_CUN_DUAN' ||
        type == 'LE_BU_SI_SHU';
  }

  void _onConfirmAction() {
    // 服务端要求选择目标（【选择目标】前缀）
    if (_askPrompt != null && _askPrompt!.contains('【选择目标】')) {
      if (_selectedTargetIds.isEmpty) {
        _showToast("请先在上方席位点击一名目标角色！");
        return;
      }
      _sendResponse(_selectedTargetIds.first);
      return;
    }

    // 谋攻篇主动技
    if (_activeSkill != null) {
      final list = _selectedIndices.toList()..sort();
      final target = _selectedTargetIds.isEmpty ? null : _selectedTargetIds.first;
      switch (_activeSkill) {
        case '武圣':
          if (list.isEmpty || target == null) {
            _showToast("【武圣】请选择一张手牌并指定目标");
            return;
          }
          _sendResponse('WUSHENG:${list.first}:$target');
          return;
        case '国色':
          if (list.isEmpty || target == null) {
            _showToast("【国色】请选择一张♦牌并指定目标");
            return;
          }
          _sendResponse('GUOSE:${list.first}:$target');
          return;
        case '明策':
          if (list.isEmpty || target == null) {
            _showToast("【明策】请选择一张手牌并指定目标");
            return;
          }
          _sendResponse('MINGCE:${list.first}:$target');
          return;
        case '乱击':
          if (list.length != 2) {
            _showToast("【乱击】请恰好选择两张手牌");
            return;
          }
          _sendResponse('LUANJI:${list[0]},${list[1]}');
          return;
        case '突袭':
          if (list.isEmpty) {
            _showToast("【突袭】请选择任意张要弃置的手牌");
            return;
          }
          _sendResponse('TUXI:${list.join(",")}');
          return;
        case '反间':
          if (list.isEmpty || target == null) {
            _showToast("【反间】请选择一张手牌并指定目标");
            return;
          }
          _sendResponse('FANJIAN:${list.first}:$target');
          return;
        case '清正':
          if (target == null) {
            _showToast("【清正】请指定一名其他角色");
            return;
          }
          _sendResponse('QINGZHENG:${_skillParam ?? '0'}:$target');
          return;
        case '颂':
          if (target == null) {
            _showToast("【颂】请指定一名角色");
            return;
          }
          _sendResponse('SONG:${_skillParam ?? '2'}:$target');
          return;
        case '据守':
          _sendResponse(list.isEmpty ? 'JUSHOU' : 'JUSHOU:${list.join(",")}');
          return;
        case '解围':
          if (target == null) {
            _showToast("【解围】请指定一名其他角色");
            return;
          }
          _sendResponse('JIEWEI:$target');
          return;
        case '雷击':
          if (target == null) {
            _showToast("【雷击】请指定一名其他角色");
            return;
          }
          _sendResponse('LEIJI:$target');
          return;
        case '弑龙':
          if (target == null) {
            _showToast("【弑龙】请指定一名其他角色");
            return;
          }
          _sendResponse('SHILONG:$target');
          return;
        case '推弑':
          if (target == null) {
            _showToast("【推弑】请指定一名没有【镇主】的角色进行拼点");
            return;
          }
          _sendResponse('TUISHI:$target');
          return;
        case '筹伐':
          if (target == null) {
            _showToast("【筹伐】请指定一名有手牌的角色");
            return;
          }
          _sendResponse('CHOUFA:$target');
          return;
        case '篡权':
          _sendResponse('CUANQUAN:${_skillParam ?? '1'}');
          return;
        case '成务':
          final chengWuType = _skillParam ?? 'SHA';
          final chengWuSuffix = _chengWuCardId == null ? '' : ':$_chengWuCardId';
          if (chengWuType == 'NAN_MAN_RU_QIN' || chengWuType == 'WAN_JIAN_QI_FA') {
            _sendResponse('CHENGWU:$chengWuType$chengWuSuffix');
            return;
          }
          if (target == null) {
            _showToast("【成务】请指定一名目标角色");
            return;
          }
          _sendResponse('CHENGWU:$chengWuType:$target$chengWuSuffix');
          return;
        default:
          break;
      }
    }

    if (_isChuHaiMode) {
      if (_selectedTargetIds.isEmpty) {
        _showToast("【除害】请先在上方席位中点击指定一名拼点目标！");
        return;
      }
      _sendResponse('CHUHAI:${_selectedTargetIds.first}');
      return;
    }

    if (_selectedIndices.isEmpty) return;
    final list = _selectedIndices.toList()..sort();

    if (_isDiscardPhase || (_askPrompt != null && _askPrompt!.contains("贯石斧"))) {
      _sendResponse(list.join(','));
      return;
    }
    if (_isZhangBaMode) {
      if (list.length != 2) {
        _showToast("【丈八蛇矛】请恰好选择两张手牌");
        return;
      }
      if (_selectedTargetIds.isEmpty) {
        _showToast("【丈八蛇矛】请先在上方席位中点击指定出杀目标！");
        return;
      }
      _sendResponse('ZHANGBA:${_selectedTargetIds.first}:${list[0]},${list[1]}');
      return;
    }
    if (_isRenDeMode) {
      if (_selectedTargetIds.isEmpty) {
        _showToast("【仁德】请先点击一名要给予手牌的角色！");
        return;
      }
      _sendResponse('RENDE:${list.join(",")}:${_selectedTargetIds.first}');
      return;
    }
    if (_isZhiHengMode) {
      _sendResponse('ZHIHENG:${list.join(",")}');
      return;
    }
    if (_isResponding) {
      _sendResponse(list.first.toString());
      return;
    }

    final cIdx = list.first;
    final card = _handCards.firstWhere((c) => c.index == cIdx,
        orElse: () => CardModel(
            index: cIdx,
            typeKey: 'NONE',
            suitKey: 'SPADE',
            points: '1',
            cardId: 0,
            name: '未知'));

    if (card.typeKey == 'TIE_SUO_LIAN_HUAN') {
      if (_selectedTargetIds.isEmpty) {
        _sendResponse('TIESUO_RECAST:$cIdx');
      } else {
        _sendResponse('$cIdx:${_selectedTargetIds.join(",")}');
      }
    } else if (_isCardRequiringTarget(card)) {
      if (_selectedTargetIds.isEmpty) {
        _showToast("请先在圆桌上点击指定目标！");
        return;
      }
      _sendResponse('$cIdx:${_selectedTargetIds.first}');
    } else {
      _sendResponse(cIdx.toString());
    }
  }

  void _onCardDroppedToTarget(CardModel card, String targetId) {
    if (!_isMyTurn || _isResponding || _isDiscardPhase) return;
    _sendResponse('${card.index}:$targetId');
  }

  /// 结算音效：赢了放胜利语音，输了放败北
  void _playResultAudio(String data) {
    final audio = AudioService.instance;
    final win = data.contains('获胜');
    audio.playVoice(win ? 'shengli' : 'shibai');
    audio.playSfx(win ? 'win' : 'lose');
  }

  /// 把牌拖到出牌区：不需要指定目标的牌（装备、无中生有、南蛮…）直接打出，
  /// 需要目标的牌自动选中并提示去点/拖目标。
  void _playCardByDrop(CardModel card) {
    if (_isDiscardPhase) {
      setState(() => _selectedIndices
        ..clear()
        ..add(card.index));
      _showToast('已选择【${card.name}】，点「确定」弃置');
      return;
    }
    if (!_isMyTurn && !_isResponding) {
      _showToast('现在还轮不到你出牌');
      return;
    }
    if (_isCardRequiringTarget(card)) {
      setState(() => _selectedIndices
        ..clear()
        ..add(card.index));
      _showToast('【${card.name}】需要目标：点圆桌上的角色，或把牌拖到他身上');
      return;
    }
    if (AppSettings.instance.confirmDropPlay) {
      _confirmDropPlay(card);
      return;
    }
    _sendResponse(card.index.toString());
  }

  /// 设置里开了「拖拽出牌需要确认」时，弹一个轻量确认框
  Future<void> _confirmDropPlay(CardModel card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF241D16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x66FFC107)),
        ),
        title: const Text('确认出牌',
            style: TextStyle(fontSize: 16, color: Color(0xFFFFE0B2))),
        content: Text('确定要打出【${card.name}${card.suitSymbol}${card.points}】吗？',
            style: const TextStyle(fontSize: 13, color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('再想想', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('出牌',
                style: TextStyle(color: Color(0xFFFFC107))),
          ),
        ],
      ),
    );
    if (ok == true) _sendResponse(card.index.toString());
  }

  /// 手牌数量变化：别人摸牌 / 失去牌时，牌要从牌堆飞过去或从他的席位飞走
  void _handleCardFlow(String data) {
    final seg = data.split('|');
    if (seg.length < 3) return;
    final id = seg[0].trim();
    final delta = int.tryParse(seg[2].trim()) ?? 0;
    if (id.isEmpty || delta == 0 || id == widget.playerId) return;
    final n = delta.abs().clamp(1, 5);
    AudioService.instance
        .playSfx(delta > 0 ? 'draw' : 'play', volume: 0.6);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pos = _stageCenterOf(_seatKeyOf(id));
      if (pos == null) return;
      for (var i = 0; i < n; i++) {
        _spawnFlight(
          fromPos: delta < 0 ? pos : null,
          toPos: delta < 0 ? null : pos,
          dest: delta < 0 ? 'deck' : 'seat',
          width: 58,
          height: 82,
          delayMs: i * 60,
          arc: delta < 0 ? 22 : 30,
        );
      }
    });
  }

  /// 明牌事件（过河拆桥 / 顺手牵羊 / 火攻弃牌）
  /// payload: `原主ID|原主名|发起者ID|发起者名|typeKey|suitKey|point|牌名|action`
  /// 不再弹任何提示框，只在牌桌上显示这张牌 + 把它从一个人那里滑到另一个人那里。
  void _handleCardRevealed(String data) {
    final seg = data.split('|');
    if (seg.length < 9) return;
    final ownerId = seg[0].trim();
    final ownerName = seg[1].trim();
    final actorId = seg[2].trim();
    final actorName = seg[3].trim();
    final typeKey = seg[4].trim();
    final suitKey = seg[5].trim();
    final point = seg[6].trim();
    final cardName = seg[7].trim();
    final gained = seg[8].trim() == 'GAIN';

    // 只有「牌的主人」或「拿到牌的人」才有资格看到正面，其他人在牌桌上看到牌背
    final me = widget.playerId;
    final faceUp = ownerId == me || actorId == me || actorId.isEmpty;
    if (faceUp) {
      AudioService.instance.playCard(cardName);
      final revealed = PlayedCard(
        name: cardName,
        typeKey: typeKey,
        sourceName: ownerName,
        targetNames: [gained ? (actorName.isEmpty ? '已被拿走' : '被 $actorName 拿走')
            : '已被弃置'],
        points: point,
        suit: suitKey,
      );
      setState(() {
        _shownCards.add(revealed);
        if (_shownCards.length > 4) _shownCards.removeAt(0);
      });
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (!mounted) return;
        setState(() => _shownCards.remove(revealed));
      });
    } else {
      AudioService.instance.playSfx('play', volume: 0.5);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final from = _stageCenterOf(_seatKeyOf(ownerId));
      if (from == null) return;
      // 终点：拿到牌的人（就是发起者）→ 自己就飞向手牌区，别人就飞向他的席位；
      // 被弃置的牌则飞向弃牌堆。
      Offset? to;
      if (gained) {
        to = actorId == me ? _stageCenterOf(_handKey) : _stageCenterOf(_seatKeyOf(actorId));
        to ??= _stageCenterOf(_deckKey);
      }
      _spawnFlight(
        fromPos: from,
        toPos: to,
        dest: gained ? 'hand' : 'deck',
        typeKey: faceUp && CardFace.hasArt(typeKey) ? typeKey : null,
        suitSymbol: faceUp ? _suitSymbolOf(suitKey) : '',
        points: faceUp ? point : '',
        isRed: suitKey == 'HEART' || suitKey == 'DIAMOND',
        width: 80,
        height: 112,
        arc: 40,
      );
    });
  }


  void _onSkillTap(String name) {
    if (name == '扬威') {
      _sendResponse('YANGWEI');
      return;
    }
    if (name == '乱武') {
      _sendResponse('LUANWU');
      return;
    }
    if (name == '清正') {
      _pickSuit();
      return;
    }
    if (name == '颂') {
      _pickSongCost();
      return;
    }
    if (name == '篡权') {
      _pickCuanQuanAura();
      return;
    }
    if (name == '成务') {
      _pickChengWuType();
      return;
    }
    setState(() {
      _activeSkill = _activeSkill == name ? null : name;
      _selectedIndices.clear();
      _selectedTargetIds.clear();
      _isZhangBaMode = false;
      _isRenDeMode = false;
      _isZhiHengMode = false;
      _isChuHaiMode = false;
    });
  }

  void _pickSuit() {
    const suits = ['♠ 黑桃', '♥ 红桃', '♣ 草花', '♦ 方片'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23242E),
        title: const Text('【清正】选择一种花色',
            style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(suits.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF343748)),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _skillParam = '$i';
                      _activeSkill = '清正';
                      _selectedIndices.clear();
                      _selectedTargetIds.clear();
                    });
                  },
                  child: Text(suits[i], style: const TextStyle(color: Colors.white)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 【篡权】：选择要开启的全局光环。
  void _pickCuanQuanAura() {
    const options = <List<String>>[
      ['0', '① 专政：全员体力调为 1、清空护盾；除司马昭外使用锦囊需额外弃一张手牌'],
      ['1', '② 群起：全员体力上限调为 1 并获得等量护盾；全场所有伤害 +1'],
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23242E),
        title: const Text('【篡权】开启哪一种光环？',
            style: TextStyle(
                color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(options.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                width: 420,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF343748),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _skillParam = options[i][0];
                      _activeSkill = '篡权';
                      _selectedIndices.clear();
                      _selectedTargetIds.clear();
                    });
                  },
                  child: Text(options[i][1],
                      style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 【成务】：先看武将牌上的扣置牌（可指定消耗哪一张），再选择当作哪一种伤害牌使用。
  void _pickChengWuType() {
    const types = <List<String>>[
      ['SHA', '普通【杀】'],
      ['FIRE_SHA', '【火杀】'],
      ['THUNDER_SHA', '【雷杀】'],
      ['DUEL', '【决斗】'],
      ['HUO_GONG', '【火攻】'],
      ['NAN_MAN_RU_QIN', '【南蛮入侵】（群体，无需指定目标）'],
      ['WAN_JIAN_QI_FA', '【万箭齐发】（群体，无需指定目标）'],
    ];
    final exiled = _exiledCards;
    int? picked = exiled.isEmpty ? null : exiled.first.cardId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF23242E),
          title: const Text('【成务】动用武将牌上的扣置牌',
              style: TextStyle(
                  color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exiled.isEmpty
                      ? '武将牌上没有扣置牌，无法发动【成务】。'
                      : '扣置于武将牌上的牌（点击选中要消耗的那张）：',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
                if (exiled.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: exiled.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final ec = exiled[i];
                          final bool on = picked == ec.cardId;
                          return GestureDetector(
                            onTap: () => setDialogState(() => picked = ec.cardId),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: on ? Colors.amber : Colors.transparent,
                                    width: 2),
                                boxShadow: on
                                    ? [
                                        const BoxShadow(
                                            color: Color(0x66FFC107),
                                            blurRadius: 12,
                                            spreadRadius: 1)
                                      ]
                                    : null,
                              ),
                              child: CardFace(
                                typeKey: ec.typeKey,
                                name: ec.name,
                                suitSymbol: _suitSymbolOf(ec.suitKey),
                                points: ec.point,
                                isRed: ec.suitKey == 'HEART' || ec.suitKey == 'DIAMOND',
                                index: i + 1,
                                showIndex: false,
                                width: 68,
                                height: 96,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const Text('当作哪一种伤害牌使用？',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(types.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: exiled.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(ctx).pop();
                                      setState(() {
                                        _skillParam = types[i][0];
                                        _chengWuCardId = picked;
                                        _activeSkill = '成务';
                                        _selectedIndices.clear();
                                        _selectedTargetIds.clear();
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF343748),
                                  disabledBackgroundColor: const Color(0xFF2A2A33)),
                              child: Text(types[i][1],
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12.5)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickSongCost() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23242E),
        title: const Text('【颂】移去多少个标记？',
            style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF343748)),
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _skillParam = '2';
                  _activeSkill = '颂';
                  _selectedTargetIds.clear();
                });
              },
              child: const Text('2 个【颂】→ 令一名角色摸三张牌',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF343748)),
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _skillParam = '3';
                  _activeSkill = '颂';
                  _selectedTargetIds.clear();
                });
              },
              child: const Text('3 个【颂】→ 令一名角色回复 1 点体力',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF343748)),
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickZhuiSiTarget();
              },
              child: const Text('4 个【颂】→ 追思一名已阵亡角色的技能',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// 【颂·4个】追思：只能选择已阵亡的角色，追思其技能并失去【行殇】
  void _pickZhuiSiTarget() {
    final dead = _opponents.where((o) => !o.alive).toList();
    if (dead.isEmpty) {
      _showToast('【追思】当前没有已阵亡的角色可以追思');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF23242E),
        title: const Text('【追思】选择一名已阵亡的角色',
            style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in dead)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF343748)),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _sendResponse('SONG:4:${o.id}');
                    },
                    child: Text(
                        '${o.hero.isNotEmpty ? o.hero : o.name}（已阵亡）',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _flash(String text, Color color) {
    setState(() {
      _flashText = text;
      _flashColor = color;
      _flashSeq++;
    });
    Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _flashText = null);
    });
  }

  /// 判断这张牌现在能不能用：不能用的一律置暗（响应阶段看能不能响应，出牌阶段看次数/条件）。
  bool _isCardPlayableNow(CardModel card) {
    final prompt = _askPrompt;
    final bool isSha = card.typeKey == 'SHA' ||
        card.typeKey == 'FIRE_SHA' ||
        card.typeKey == 'THUNDER_SHA';

    // 选了主动技以后可以用任意牌当技能消耗（或由技能做转化），不做置暗
    if (_activeSkill != null) {
      if (_isResponding) {
        if (prompt != null && prompt.contains('【闪】') && !prompt.contains('视为【杀】')) {
          // 武圣/龙胆/倾国 之类可以把某些牌当闪用
          if (_activeSkill == '武圣') return card.isRed;
          if (_activeSkill == '龙胆' || _activeSkill == '倾国') return true;
          return card.typeKey == 'SHAN';
        }
        if (prompt != null &&
            (prompt.contains('打出【杀】') ||
                prompt.contains('一张【杀】') ||
                prompt.contains('视为【杀】'))) {
          if (isSha) return true;
          if (_activeSkill == '武圣') return card.isRed;
          if (_activeSkill == '龙胆') return card.typeKey == 'SHAN';
          return false;
        }
      }
      return true;
    }

    if (_isResponding && prompt != null && prompt.isNotEmpty) {
      // 「打出/使用一张【闪】」
      if (prompt.contains('【闪】') && !prompt.contains('视为【杀】')) {
        if (card.typeKey == 'SHAN') return true;
        // 龙胆：杀可当闪
        return isSha && _skills.any((s) => s.name == '龙胆');
      }
      // 「打出/使用【杀】」
      if (prompt.contains('打出【杀】') ||
          prompt.contains('一张【杀】') ||
          prompt.contains('视为【杀】')) {
        if (isSha) return true;
        // 龙胆：闪可当杀
        if (card.typeKey == 'SHAN' && _skills.any((s) => s.name == '龙胆')) return true;
        return false;
      }
      // 「使用【桃】/【酒】」
      if (prompt.contains('【桃】')) {
        return card.typeKey == 'TAO' || (card.typeKey == 'JIU' && prompt.contains('【酒】'));
      }
      // 「使用【无懈可击】」
      if (prompt.contains('【无懈可击】')) {
        return card.typeKey == 'WU_XIE_KE_JI';
      }
      return true;
    }

    // ---- 自己出牌阶段：不能用的牌直接暗下去 ----
    if (!_isMyTurn) return true;
    if (card.typeKey == 'SHAN' || card.typeKey == 'WU_XIE_KE_JI') return false;
    if (card.typeKey == 'TAO') return _hp < _maxHp;
    if (isSha) return _shaLeft > 0;
    if (card.typeKey == 'JIU') return _shaLeft > 0 || _hp < _maxHp;
    return true;
  }

  /// 出牌阶段剩余可出杀次数（从服务端提示里取，解析失败当作无限）
  int get _shaLeft => _shaLeftFromPrompt();

  /// 从出牌阶段提示里取「剩余可出杀」
  int _shaLeftFromPrompt() {
    final p = _askPrompt;
    if (p == null) return 99;
    if (p.contains('剩余可出杀:无限')) return 99;
    final m = RegExp(r'剩余可出杀:(\d+)').firstMatch(p);
    return m == null ? 99 : (int.tryParse(m.group(1)!) ?? 99);
  }

  /// 长按技能按钮：显示技能详情与当前是否可以发动。
  void _showSkillDesc(SkillModel sk) {
    final typeLabel = switch (sk.type) {
      'ACTIVE' => '主动技',
      'TRIGGER' => '触发技',
      'LIMITED' => '限定技',
      _ => '锁定技',
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2118),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFFFD54F), width: 1.2)),
        title: Row(
          children: [
            Text(sk.name,
                style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w900,
                    fontSize: 19)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x33FFD54F),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0x66FFD54F)),
              ),
              child: Text(typeLabel,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFFFE082))),
            ),
            const Spacer(),
            Text(sk.usable ? '可以发动' : '本回合已发动',
                style: TextStyle(
                    fontSize: 11.5,
                    color: sk.usable ? Colors.greenAccent : Colors.white38)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Text(sk.desc.isEmpty ? '（暂无描述）' : sk.desc,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13.5, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 长按对手武将牌：查看其技能（含被动/锁定技）
  void _showOpponentSkills(OpponentModel o) {
    final skills = _oppSkills[o.id] ?? const <SkillModel>[];
    _showSkillListDialog(
      title: o.hero.isNotEmpty ? o.hero : o.name,
      subtitle: '${o.name} 的技能',
      skills: skills,
    );
  }

  /// 技能总览弹窗：所有技能（含被动/锁定技）都可在这里读到完整描述
  void _showSkillListDialog({
    required String title,
    required String subtitle,
    required List<SkillModel> skills,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2118),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFFFD54F), width: 1.2)),
        title: Row(children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 19)),
          ),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        ]),
        content: SizedBox(
          width: 460,
          child: skills.isEmpty
              ? const Text('（没有可查看的技能）',
                  style: TextStyle(color: Colors.white54, fontSize: 13))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final sk in skills)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0x1AFFFFFF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: sk.isManual
                                    ? const Color(0x66FFD54F)
                                    : Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(sk.name,
                                    style: TextStyle(
                                        color: sk.isManual
                                            ? const Color(0xFFFFE082)
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(width: 8),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0x22FFD54F),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0x44FFD54F)),
                                  ),
                                  child: Text(sk.typeLabel,
                                      style: const TextStyle(
                                          fontSize: 10.5, color: Color(0xFFFFE082))),
                                ),
                                const Spacer(),
                                if (sk.hasCounter)
                                  Text('${sk.remain}/${sk.cap}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.cyanAccent)),
                              ]),
                              const SizedBox(height: 6),
                              Text(sk.desc.isEmpty ? '（暂无描述）' : sk.desc,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12.5, height: 1.5)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showBanner(String text) {    setState(() {
      _bannerText = text;
      _bannerVisible = true;
    });
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _bannerVisible = false);
    });
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.deepOrangeAccent,
      duration: const Duration(seconds: 2),
    ));
  }

  void _sendResponse(String text) {
    _stopCountdown();
    _socket.sendPacket(Packet(command: Command.RESPOND_CARD, senderId: widget.playerId, data: text));
    setState(() {
      _askPrompt = null;
      _isResponding = false;
      _selectedIndices.clear();
      _selectedTargetIds.clear();
      _isZhangBaMode = false;
      _isRenDeMode = false;
      _isZhiHengMode = false;
      _isChuHaiMode = false;
      _activeSkill = null;
      _skillParam = null;
      _chengWuCardId = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }


  /// 当前询问是否只需要指定目标（不需要选牌）
  bool get _isTargetOnlyPrompt {
    if (_askPrompt != null && _askPrompt!.contains('【选择目标】')) return true;
    const targetOnlySkills = {'解围', '雷击', '清正', '颂', '明策'};
    return _activeSkill != null && targetOnlySkills.contains(_activeSkill);
  }



  @override
  // ==================== 布局：沉浸式战局 ====================

  @override
  Widget build(BuildContext context) {
    final hasZhangBa = _weapon.contains('丈八蛇矛');
    final hasRenDe = _skills.any((s) => s.name == '仁德');
    final hasZhiHeng = _skills.any((s) => s.name == '制衡');
    final hasChuHai = _skills.any((s) => s.name == '除害');
    final isDrunk = _myMarks.any((m) => m.contains('酒'));

    final isTargetSelecting = _isChuHaiMode ||
        _isZhangBaMode ||
        _isRenDeMode ||
        _activeSkill != null ||
        (_askPrompt != null && _askPrompt!.contains('【选择目标】')) ||
        (_selectedIndices.isNotEmpty &&
            !_isResponding &&
            !_isDiscardPhase &&
            _handCards.any((c) => _selectedIndices.contains(c.index) &&
                (_isCardRequiringTarget(c) || c.typeKey == 'TIE_SUO_LIAN_HUAN')));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0D0906),
      endDrawer: _buildLogDrawer(),
      // 窗口放大（尤其全屏）时整体等比放大，键盘区/卡牌/字号一起变大
      body: ScaledStage(
        extraScale: AppSettings.instance.uiScale,
        child: MouseRegion(
          onHover: _aimShaCard() == null
              ? null
              : (e) => setState(() => _aimPos = e.localPosition),
          onExit: (_) {
            if (_aimPos != null) setState(() => _aimPos = null);
          },
          child: Stack(
            key: _stageKey,
          children: [
            const GameBackground(),
            Column(
              children: [
                const SizedBox(height: 46),
                Expanded(child: _buildBoard(isTargetSelecting)),
                _buildBottomBar(hasZhangBa, hasRenDe, hasZhiHeng, hasChuHai),
              ],
            ),
            // 左上：身份局势
            Positioned(left: 12, top: 8, child: _buildIdentityPanel()),
            // 右上：牌堆 / 轮次 / 倒计时
            Positioned(right: 12, top: 8, child: _buildStatusCapsule(isDrunk)),
            // 特效层
            ..._buildEffects(),
          ],
          ),
        ),
      ),
    );
  }

  // ---------- 顶部胶囊 ----------

  Widget _buildIdentityPanel() {
    int main = 0, loyal = 0, rebel = 0, traitor = 0;
    int warm = 0, cold = 0, lord = 0, farmer = 0;
    void count(String role) {
      switch (role) {
        case 'MAIN':
          main++;
          break;
        case 'LOYAL':
          loyal++;
          break;
        case 'REBEL':
          rebel++;
          break;
        case 'TRAITOR':
          traitor++;
          break;
        case 'WARM':
          warm++;
          break;
        case 'COLD':
          cold++;
          break;
        case 'LORD':
          lord++;
          break;
        case 'FARMER':
          farmer++;
          break;
      }
    }

    count(_myRole);
    for (final o in _opponents) {
      if (o.alive || o.role != 'HIDDEN') count(o.role);
    }

    Widget pill(String label, int n, Color color) => Container(
          margin: const EdgeInsets.only(right: 5),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.85), width: 0.8),
          ),
          child: Text('$label$n',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        );

    late final List<Widget> pills;
    late final String hint;
    if (_gameMode == 'TEAM_2V2') {
      pills = [
        pill('暖方', warm, const Color(0xFFFFC94D)),
        pill('冷方', cold, const Color(0xFF79C7FF)),
      ];
      hint = '一方全员阵亡则另一方获胜';
    } else if (_gameMode == 'LANDLORD') {
      pills = [
        pill('地主', lord, const Color(0xFFFFC94D)),
        pill('农民', farmer, const Color(0xFF79C7FF)),
      ];
      hint = '地主阵亡则农民获胜';
    } else {
      pills = [
        pill('主', main, const Color(0xFFFFC94D)),
        pill('忠', loyal, const Color(0xFF79C7FF)),
        pill('反', rebel, const Color(0xFFFF6B6B)),
        pill('内', traitor, const Color(0xFFC08BFF)),
      ];
      hint = '反贼与内奸全灭则主公方获胜';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55FFD9A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: pills),
          const SizedBox(height: 3),
          Text(hint, style: const TextStyle(fontSize: 8.5, color: Color(0x99FFE0B2))),
        ],
      ),
    );
  }

  Widget _buildStatusCapsule(bool isDrunk) {
    Widget sep() => Container(
        width: 1, height: 12, margin: const EdgeInsets.symmetric(horizontal: 7),
        color: const Color(0x44FFD9A0));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x55FFD9A0)),
      ),
      child: Row(children: [
        const Icon(Icons.layers, size: 13, color: Color(0xFF80DEEA)),
        const SizedBox(width: 4),
        Text(_deckInfo, key: _deckKey, style: const TextStyle(fontSize: 11.5, color: Color(0xFF80DEEA))),
        sep(),
        const Icon(Icons.autorenew, size: 13, color: Color(0xFFFFD54F)),
        const SizedBox(width: 4),
        Text('第 $_roundNo 轮', style: const TextStyle(fontSize: 11.5, color: Color(0xFFFFD54F))),
        sep(),
        const Icon(Icons.people, size: 13, color: Color(0xFFA5D6A7)),
        const SizedBox(width: 3),
        Text('存活 $_aliveCount · 射程 $_attackRange',
            style: const TextStyle(fontSize: 11, color: Color(0xFFA5D6A7))),
        sep(),
        Icon(Icons.favorite, size: 13, color: const Color(0xFFFF6B6B)),
        const SizedBox(width: 3),
        Text('$_hp/$_maxHp',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        if (_myArmor > 0) ...[
          const SizedBox(width: 5),
          const Icon(Icons.shield, size: 12, color: Color(0xFF64B5F6)),
          Text('$_myArmor',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64B5F6))),
        ],
        if (isDrunk) ...[
          const SizedBox(width: 5),
          const Icon(Icons.local_bar, size: 12, color: Color(0xFFFFB74D)),
        ],
        if (_secondsLeft > 0) ...[
          sep(),
          SizedBox(
            width: 18,
            height: 18,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: _countdownTotal <= 0
                    ? 0
                    : (_secondsLeft / _countdownTotal).clamp(0.0, 1.0),
                strokeWidth: 2.4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                    _secondsLeft <= 5 ? Colors.redAccent : Colors.cyanAccent),
              ),
              Text('$_secondsLeft',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
        const SizedBox(width: 4),
        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF262732),
                title: const Text('退出对局？',
                    style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                content: const Text('退出后将离开房间并返回大厅。',
                    style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('取消', style: TextStyle(color: Colors.white54))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _safeExitToLobby();
                    },
                    child: const Text('退出', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
          child: const Icon(Icons.power_settings_new, size: 15, color: Color(0xFFEF9A9A)),
        ),
      ]),
    );
  }

  // ---------- 牌桌 ----------

  Widget _buildBoard(bool isTargetSelecting) {
    return LayoutBuilder(builder: (context, c) {
      final double sw = TableSeatCard.w;
      final double sh = TableSeatCard.h;
      final double boardW = c.maxWidth;
      final double boardH = c.maxHeight;

      // 席位划分：左 1 / 上 若干 / 右 1
      final others = _opponents;
      final leftSeat = others.isNotEmpty && others.length >= 2 ? others.first : null;
      final rightSeat = others.length >= 2 ? others.last : null;
      final topSeats = others.length >= 3
          ? others.sublist(1, others.length - 1)
          : (others.length == 1 ? others : <OpponentModel>[]);

      final Map<String, Offset> pos = {};
      if (leftSeat != null) {
        pos[leftSeat.id] = Offset(10, math.max(0, (boardH - sh) / 2));
      }
      if (rightSeat != null) {
        pos[rightSeat.id] = Offset(boardW - sw - 10, math.max(0, (boardH - sh) / 2));
      }
      for (int i = 0; i < topSeats.length; i++) {
        final double x0 = sw + 24;
        final double x1 = boardW - sw - 24 - sw;
        double x;
        if (topSeats.length == 1) {
          x = boardW / 2 - sw / 2;
        } else {
          final double span = math.max(0, x1 - x0);
          x = x0 + span * i / (topSeats.length - 1);
        }
        pos[topSeats[i].id] = Offset(x.clamp(0, math.max(0, boardW - sw)), 2);
      }

      Offset centerOf(String id) {
        final p = pos[id];
        if (p == null) return Offset(boardW / 2, boardH / 2);
        return p + Offset(sw / 2, TableSeatCard.cardH / 2);
      }

      // 攻击光束
      Offset? beamFrom;
      final List<Offset> beamTo = [];
      if (_activeCardSourceId != null && _activeCardTargetIds.isNotEmpty) {
        beamFrom = _activeCardSourceId == widget.playerId
            ? Offset(boardW - sw / 2 - 12, boardH - 6)
            : centerOf(_activeCardSourceId!);
        for (final id in _activeCardTargetIds) {
          if (id == widget.playerId) {
            beamTo.add(Offset(boardW - sw / 2 - 12, boardH - 6));
          } else {
            beamTo.add(centerOf(id));
          }
        }
      } else if (isTargetSelecting && _selectedTargetIds.isNotEmpty) {
        beamFrom = Offset(boardW - sw / 2 - 12, boardH - 6);
        for (final id in _selectedTargetIds) {
          beamTo.add(centerOf(id));
        }
      }

      Widget seatWidget(OpponentModel o) {
        final isOppTurn = _turnPlayerId == o.id;
        // 选中【杀】类牌时，距离超出攻击范围的目标置灰并标注「距离不足」
        final bool selectingSha = isTargetSelecting &&
            _selectedIndices.any((i) => _handCards.any((c) =>
                c.index == i &&
                (c.typeKey == 'SHA' ||
                    c.typeKey == 'FIRE_SHA' ||
                    c.typeKey == 'THUNDER_SHA')));
        final bool outOfRange =
            selectingSha && o.alive && o.distance > _attackRange;
        return TableSeatCard(
          cardKey: ValueKey(o.id),
          id: o.id,
          isOutOfRange: outOfRange,
          isHitFlash: _hitSeats.contains(o.id),
          isDying: o.alive && o.hp <= 0,
          name: o.name,
          hero: o.hero,
          hp: o.hp,
          maxHp: o.maxHp,
          handCount: o.handCount,
          equips: o.equips,
          judges: o.judges.isNotEmpty ? o.judges.split(',') : [],
          marks: o.marks.isNotEmpty ? o.marks.split(',') : [],
          isMe: false,
          role: o.role,
          roleLabel: o.roleLabel,
          alive: o.alive,
          distance: o.distance,
          armor: o.armor,
          flipped: 0 > 1 ? false : o.flipped,
          wineBonus: o.wineBonus,
          faction: o.faction,
          exileCount: o.exileCount,
          onLongPress: () => _showOpponentSkills(o),
          seatNo: _opponents.indexOf(o) + 2,
          isCurrentTurn: isOppTurn,
          currentPhaseName: isOppTurn ? _currentPhaseName : null,
          isSelectedAsTarget: _selectedTargetIds.contains(o.id),
          isTargetSelectionMode: isTargetSelecting,
          onCardDropped: (card, targetId) => _onCardDroppedToTarget(card, targetId),
          onTap: () {
            setState(() {
              final isTieSuo = _selectedIndices.isNotEmpty &&
                  _handCards.any((c) =>
                      _selectedIndices.contains(c.index) && c.typeKey == 'TIE_SUO_LIAN_HUAN');
              if (isTieSuo) {
                if (_selectedTargetIds.contains(o.id)) {
                  _selectedTargetIds.remove(o.id);
                } else if (_selectedTargetIds.length < 2) {
                  _selectedTargetIds.add(o.id);
                }
              } else {
                if (_selectedTargetIds.contains(o.id)) {
                  _selectedTargetIds.clear();
                } else {
                  _selectedTargetIds.clear();
                  _selectedTargetIds.add(o.id);
                }
              }
            });
          },
        );
      }

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: TargetArrowPainter(
                fromOffset: beamFrom,
                toOffsets: beamTo,
                nature: _activeNature,
              ),
            ),
          ),
          for (final e in pos.entries)
            if (_opponents.any((o) => o.id == e.key))
              Positioned(
                left: e.value.dx,
                top: e.value.dy,
                child: KeyedSubtree(
                  key: _seatKeyOf(e.key),
                  child: seatWidget(_opponents.firstWhere((o) => o.id == e.key)),
                ),
              ),
          // 出牌结算区：放到窗口的视觉正中心略偏下
          // （牌桌可用区在窗口上部 46..~557，居中用 0.5 会偏高，故用 0.70
          //   使卡牌中心落在窗口纵向中心下方约 10px）
          // 这里同时是「拖牌到前面直接打出」的放置目标
          Align(
            alignment: const Alignment(0, 0.70),
            child: DragTarget<CardModel>(
              onWillAcceptWithDetails: (d) =>
                  _isMyTurn || _isResponding || _isDiscardPhase,
              onAcceptWithDetails: (d) => _playCardByDrop(d.data),
              builder: (ctx, candidates, rejected) {
                final hot = candidates.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: hot ? const Color(0xFFFFC107) : Colors.transparent,
                        width: 2),
                    boxShadow: hot
                        ? const [
                            BoxShadow(color: Color(0x66FFC107), blurRadius: 22)
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          KeyedSubtree(
                            key: _centerKey,
                            child: CenterStageView(cards: _shownCards),
                          ),
                          if (_dodgedStamp) _buildDodgeStamp(),
                        ],
                      ),
                      if (_waitingForDodge) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xCC2B2118),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _natureColor(_activeNature)
                                    .withValues(alpha: 0.7)),
                          ),
                          child: Text(
                            '等待 ${_activeCardTargetNames.isEmpty ? '目标' : _activeCardTargetNames.join('、')} 响应【闪】…',
                            style: TextStyle(
                              color: _natureColor(_activeNature),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          // 群体锦囊横幅
          if (_aoeBanner != null)
            Positioned(
              top: 34,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xCC8D6E1F), Color(0xCC3E2723)]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFFD54F), width: 1.6),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x99FFB300),
                            blurRadius: 24,
                            spreadRadius: 2),
                      ],
                    ),
                    child: Text(
                      _aoeBanner!,
                      style: const TextStyle(
                        color: Color(0xFFFFF3CD),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 他人对我出牌时的红框警示
          if (_activeCardTargetIds.contains(widget.playerId))
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.75), width: 5),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  // ---------- 底部操作区 ----------

  /// 中央结算区的「已抵消」印章（青白描边、微倾）
  Widget _buildDodgeStamp() {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.18,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF80DEEA), width: 3),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0x3300BCD4),
            boxShadow: const [
              BoxShadow(color: Color(0x6600BCD4), blurRadius: 18),
            ],
          ),
          child: const Text(
            '已 抵 消',
            style: TextStyle(
              color: Color(0xFF80DEEA),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool hasZhangBa, bool hasRenDe, bool hasZhiHeng, bool hasChuHai) {
    final overLimit = _maxHandCards > 0 && _handCards.length > _maxHandCards;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xCC150E09), const Color(0xFF0A0705)],
        ),
        border: const Border(top: BorderSide(color: Color(0x55FFC94D), width: 1.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_askPrompt != null)
            ActionPromptBar(
              prompt: _askPrompt!,
              isResponding: _isResponding,
              selectedCount: _selectedIndices.length,
              isZhangBaMode: _isZhangBaMode,
              isRenDeMode: _isRenDeMode,
              isZhiHengMode: _isZhiHengMode,
              isChuHaiMode: _isChuHaiMode,
              hasZhangBaWeapon: hasZhangBa,
              hasRenDeSkill: hasRenDe,
              hasZhiHengSkill: hasZhiHeng,
              hasChuHaiSkill: hasChuHai,
              hasTieSuoSelected: _selectedIndices.any((i) => _handCards
                  .any((c) => c.index == i && c.typeKey == 'TIE_SUO_LIAN_HUAN')),
              onRecastTieSuo: () {
                // 铁索连环没选目标时点这里 = 重铸（弃置此牌摸一张）
                final c = _handCards.firstWhere(
                  (x) =>
                      x.typeKey == 'TIE_SUO_LIAN_HUAN' &&
                      _selectedIndices.contains(x.index),
                  orElse: () => _handCards.firstWhere(
                      (x) => x.typeKey == 'TIE_SUO_LIAN_HUAN',
                      orElse: () => _handCards.first),
                );
                _sendResponse('TIESUO_RECAST:${c.index}');
              },
              secondsLeft: _secondsLeft,
              totalSeconds: _countdownTotal,
              isTargetOnly: _isTargetOnlyPrompt,
              hasTarget: _selectedTargetIds.isNotEmpty,
              isConfirmAsk: _isConfirmAsk,
              onConfirm: _isConfirmAsk
                  ? () => _sendResponse('1')
                  : _onConfirmAction,
              onCancelSelection: () {
                setState(() {
                  _selectedIndices.clear();
                  _selectedTargetIds.clear();
                  _isZhangBaMode = false;
                  _isRenDeMode = false;
                  _isZhiHengMode = false;
                  _isChuHaiMode = false;
                });
              },
              onToggleZhangBa: () {
                setState(() {
                  _isZhangBaMode = !_isZhangBaMode;
                  _isRenDeMode = false;
                  _isZhiHengMode = false;
                  _isChuHaiMode = false;
                  _activeSkill = null;
                  _selectedIndices.clear();
                  _selectedTargetIds.clear();
                });
              },
              onToggleRenDe: () {
                setState(() {
                  _isRenDeMode = !_isRenDeMode;
                  _isZhangBaMode = false;
                  _isZhiHengMode = false;
                  _isChuHaiMode = false;
                  _activeSkill = null;
                  _selectedIndices.clear();
                  _selectedTargetIds.clear();
                });
              },
              onToggleZhiHeng: () {
                setState(() {
                  _isZhiHengMode = !_isZhiHengMode;
                  _isZhangBaMode = false;
                  _isRenDeMode = false;
                  _isChuHaiMode = false;
                  _activeSkill = null;
                  _selectedIndices.clear();
                  _selectedTargetIds.clear();
                });
              },
              onToggleChuHai: () {
                setState(() {
                  _isChuHaiMode = !_isChuHaiMode;
                  _isZhangBaMode = false;
                  _isRenDeMode = false;
                  _isZhiHengMode = false;
                  _activeSkill = null;
                  _selectedIndices.clear();
                  _selectedTargetIds.clear();
                });
              },
              onPass: () => _sendResponse(_isConfirmAsk ? '0' : 'PASS'),
            ),
          SizedBox(
            height: 330,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLeftTools(),
                // 手牌
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: HandCardArea(
                          key: _handKey,
                          handCards: _handCards,
                          selectedIndices: _selectedIndices,
                          maxHandCards: _maxHandCards,
                          enabled: _askPrompt != null,
                          isPlayable: _isCardPlayableNow,
                          shaBonus: _myMarks.any((m) => m.contains('酒')),
                          onCardTap: (card) {
                            if (_askPrompt == null) return;
                            setState(() {
                              final canMultiSelect = _isDiscardPhase ||
                                  _isRenDeMode ||
                                  _isZhiHengMode ||
                                  _activeSkill == '乱击' ||
                                  _activeSkill == '突袭' ||
                                  (_askPrompt != null && _askPrompt!.contains("贯石斧"));
                              if (canMultiSelect) {
                                if (_selectedIndices.contains(card.index)) {
                                  _selectedIndices.remove(card.index);
                                } else {
                                  _selectedIndices.add(card.index);
                                }
                              } else if (_isZhangBaMode) {
                                if (_selectedIndices.contains(card.index)) {
                                  _selectedIndices.remove(card.index);
                                } else if (_selectedIndices.length < 2) {
                                  _selectedIndices.add(card.index);
                                }
                              } else {
                                if (_selectedIndices.contains(card.index)) {
                                  _selectedIndices.clear();
                                  _selectedTargetIds.clear();
                                } else {
                                  _selectedIndices.clear();
                                  _selectedIndices.add(card.index);
                                  _selectedTargetIds.clear();
                                }
                              }
                            });
                          },
                        ),
                      ),
                      // 手牌上限指示
                      Positioned(
                        left: 8,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: overLimit
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0x55FFD9A0)),
                          ),
                          child: Text(
                            '手牌 ${_handCards.length}/${_maxHandCards}',
                            style: TextStyle(
                                fontSize: 10,
                                color: overLimit
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xCCFFE0B2),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildRightZone(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftTools() {
    Widget tool(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
      return InkWell(
        onTap: onTap,
        child: Container(
          width: 52,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? const Color(0x66B8860B)
                : Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: active ? const Color(0xFFFFD54F) : const Color(0x33FFD9A0)),
          ),
          child: Column(children: [
            Icon(icon, size: 15, color: const Color(0xFFFFE082)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 9, color: Color(0xCCFFE0B2))),
          ]),
        ),
      );
    }

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          tool(Icons.sort, '按类型', () {
            setState(() => _handCards.sort((a, b) => a.typePriority.compareTo(b.typePriority)));
          }),
          tool(Icons.sort_by_alpha, '按点数', () {
            setState(() => _handCards.sort((a, b) => a.pointValue.compareTo(b.pointValue)));
          }),
          if (AppSettings.instance.showBattleLog)
            tool(Icons.receipt_long, '战况', () => _scaffoldKey.currentState?.openEndDrawer()),
          tool(Icons.settings, '设置', () => SettingsDialog.show(context)),
        ],
      ),
    );
  }

  Widget _buildRightZone() {
    // 展示全部技能（含锁定/被动技），被动技点击只能查看描述
    final manualSkills = _skills;
    // 技能多的武将（如司马昭 13 技）改用更紧凑的按钮，避免横向挤爆右栏
    final bool compactSkills = manualSkills.length > 6;
    final double chipPadH = compactSkills ? 9 : 13;
    final double chipPadV = compactSkills ? 3 : 5;
    final double skillNameSize = compactSkills ? 12.5 : 15;
    final double skillBadgeSize = compactSkills ? 7.5 : 8.5;

    return SizedBox(
      width: 400,
      child: Column(
        children: [
          // 技能按钮（主动技可发动；不可发动时置暗；长按/点击被动技查看描述）
          if (manualSkills.isNotEmpty)
            Container(
              height: compactSkills ? 50 : 58,
              padding: EdgeInsets.fromLTRB(6, compactSkills ? 4 : 6, 6, 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final sk in manualSkills)
                    Padding(
                      padding: EdgeInsets.only(right: compactSkills ? 5 : 8),
                      child: GestureDetector(
                        onTap: () {
                          // 被动/锁定技不可发动，点一下只看完整描述
                          if (!sk.isManual) {
                            _showSkillDesc(sk);
                            return;
                          }
                          // 次数用完的技能按钮已经置暗，点了不做任何事（不再弹「已发动」提示）
                          if (!sk.usable) return;
                          _onSkillTap(sk.name);
                        },
                        onLongPress: () => _showSkillDesc(sk),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: chipPadH, vertical: chipPadV),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: !sk.isManual
                                ? [const Color(0xFF3A3A3A), const Color(0xFF232323)]
                                : (!sk.usable
                                    ? [const Color(0xFF3E3E3E), const Color(0xFF1F1F1F)]
                                    : _activeSkill == sk.name
                                        ? [const Color(0xFFFFB300), const Color(0xFFE65100)]
                                        : [const Color(0xFFB8860B), const Color(0xFF6D4C00)])),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: !sk.isManual
                                    ? Colors.white24
                                    : (!sk.usable
                                        ? Colors.white24
                                        : _activeSkill == sk.name
                                            ? Colors.yellowAccent
                                            : const Color(0xFFFFD54F)),
                                width: _activeSkill == sk.name ? 2 : 1),
                            boxShadow: (!sk.isManual || !sk.usable)
                                ? null
                                : (_isResponding
                                    ? const [
                                        BoxShadow(
                                            color: Color(0x99FFC107), blurRadius: 14)
                                      ]
                                    : const [
                                        BoxShadow(
                                            color: Color(0x66FFB300), blurRadius: 8)
                                      ]),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                  !sk.isManual
                                      ? (sk.hasCounter
                                          ? '${sk.remain}/${sk.cap}'
                                          : '被动')
                                      : (!sk.usable
                                          ? (sk.hasCounter
                                              ? '${sk.remain}/${sk.cap}'
                                              : '已用')
                                          : (sk.hasCounter
                                              ? '${sk.remain}/${sk.cap}'
                                              : (_isResponding ? '可用' : '发动'))),
                                  style: TextStyle(
                                      fontSize: skillBadgeSize,
                                      color: (!sk.isManual || !sk.usable)
                                          ? Colors.white38
                                          : Colors.amber[100])),
                              Text(sk.name,
                                  style: TextStyle(
                                      fontSize: skillNameSize,
                                      color: (!sk.isManual || !sk.usable)
                                          ? Colors.white38
                                          : Colors.white,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (manualSkills.any((s) => s.name == '国色'))
                    GestureDetector(
                      onTap: () => _sendResponse('GUOSECLEAR'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5D4037),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: const Color(0xFFFFD54F), width: 1),
                        ),
                        child: const Center(
                          child: Text('弃乐',
                              style: TextStyle(fontSize: 13, color: Colors.white)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // 装备栏（卡片左侧竖排 4 格）+ 主视角武将卡
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  key: _equipKey,
                  width: 136,
                  padding: const EdgeInsets.only(right: 8, bottom: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildEquipSlot('⚔', '武器', _weapon),
                      _buildEquipSlot('🛡', '防具', _armor),
                      _buildEquipSlot('🐎', '-1 马', _offHorse),
                      _buildEquipSlot('🐴', '+1 马', _defHorse),
                    ],
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: KeyedSubtree(
                      key: _seatKeyOf(widget.playerId),
                      child: TableSeatCard(
                        id: widget.playerId,
                        isHitFlash: _hitSeats.contains(widget.playerId),
                        isDying: _hp <= 0,
                        name: widget.playerName,
                        hero: _heroName,
                        hp: _hp,
                        maxHp: _maxHp,
                        handCount: _handCards.length,
                        equips: [_weapon, _armor, _defHorse, _offHorse].join(','),
                        judges: _judgeAreaCards,
                        marks: _myMarks,
                        isMe: true,
                        role: _myRole,
                        roleLabel: _myRoleCn,
                        alive: !_isDead,
                        armor: _myArmor,
                        flipped: _myFlipped,
                        wineBonus: _wineBonus,
                        faction: _myFaction,
                        exileCount: _myExileCount,
                        onLongPress: () => _showSkillListDialog(
                            title: _heroName.isEmpty ? '我的技能' : _heroName,
                            skills: _skills,
                            subtitle: '我的技能'),
                        seatNo: 1,
                        compact: true,
                        isCurrentTurn: _turnPlayerId == widget.playerId,
                        currentPhaseName:
                            _turnPlayerId == widget.playerId ? _currentPhaseName : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 主视角装备栏的一格（图标 + 槽位名 + 装备名）
  Widget _buildEquipSlot(String icon, String label, String name) {
    final bool has = name != '无' && name.isNotEmpty;
    return Tooltip(
      message: has ? '$label：$name' : '$label：未装备',
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: has
                ? [const Color(0x66B8860B), const Color(0x33150E09)]
                : [Colors.black.withValues(alpha: 0.4), Colors.black.withValues(alpha: 0.25)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: has ? const Color(0xFFFFD54F) : const Color(0x33FFD9A0),
              width: has ? 1.1 : 0.8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Center(
                child: Text(icon,
                    style: TextStyle(
                        fontSize: 19, color: has ? Colors.white : Colors.white24)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 9, color: Color(0x99FFE0B2))),
                  Text(has ? name : '未装备',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: has ? const Color(0xFFFFF3C4) : Colors.white24,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 特效与日志 ----------

  List<Widget> _buildEffects() {
    final aimCard = _aimShaCard();
    return [
      // 拖动/选中【杀】时的动态准星线：从主武将卡拉向鼠标
      if (aimCard != null && _aimPos != null)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _AimLinePainter(
                from: _stageCenterOf(_seatKeyOf(widget.playerId)) ??
                    const Offset(1180, 720),
                to: _aimPos!,
                color: _natureColor(_natureOf(aimCard.typeKey)),
              ),
            ),
          ),
        ),
      if (_bannerVisible)
        Positioned(
          top: 52,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFB87400), Color(0xFF7A3E00)]),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.amberAccent, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x88FFB300), blurRadius: 24)
                  ],
                ),
                child: Text(_bannerText,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4)),
              ),
            ),
          ),
        ),
      if (_flashText != null)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_flashSeq),
                tween: Tween(begin: 0.7, end: 1.7),
                duration: const Duration(milliseconds: 900),
                builder: (_, v, child) => Opacity(
                  opacity: (2.0 - v).clamp(0.0, 1.0),
                  child: Transform.scale(scale: v, child: child),
                ),
                child: Text(
                  _flashText!,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: _flashColor,
                    shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ),
        ),
      // 牌滑动层（摸牌 / 出牌 / 弃牌 / 装备）
      for (final f in _flying) _buildFlight(f),
      // 席位飘字层（掉血 -1 / 回复 +1 / 护甲 🛡，落在对应武将头上）
      for (final f in _seatFloats) _buildSeatFloat(f),
      // 爆点层（火攻命中 / 属性传导）
      for (final b in _bursts) _buildBurst(b),
    ];
  }

  Widget _buildSeatFloat(_SeatFloat f) {
    return Positioned(
      left: f.pos.dx - 40,
      top: f.pos.dy - 52,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(f.seq),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1100),
          builder: (_, v, child) => Opacity(
            opacity: v < 0.75 ? 1.0 : (1.0 - (v - 0.75) / 0.25).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -26 * v),
              child: Transform.scale(scale: 0.9 + 0.5 * v.clamp(0.0, 0.6), child: child),
            ),
          ),
          child: SizedBox(
            width: 80,
            child: Text(
              f.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: f.color,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF14100C),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
            color: const Color(0xFF231A12),
            child: const Row(
              children: [
                Icon(Icons.history_edu, color: Colors.amberAccent),
                SizedBox(width: 8),
                Text('战况记录',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(child: BattleLogView(logs: _logs, scrollController: _scrollController)),
        ],
      ),
    );
  }
}

/// 席位飘字（掉血 / 回复 / 护甲），坐标是舞台内的绝对位置
class _SeatFloat {
  final int seq;
  final Offset pos;
  final String text;
  final Color color;

  const _SeatFloat({
    required this.seq,
    required this.pos,
    required this.text,
    required this.color,
  });
}

/// 选中/拖动【杀】时从主武将卡拉出的动态准星线
class _AimLinePainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;

  const _AimLinePainter({
    required this.from,
    required this.to,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final delta = to - from;
    final len = delta.distance;
    if (len < 8) return;

    // 外发光
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: 0.32)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 虚线主束
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    const dash = 11.0;
    const gap = 7.0;
    var travelled = 0.0;
    final unit = delta / len;
    while (travelled < len) {
      final end = (travelled + dash).clamp(0.0, len);
      canvas.drawLine(
        from + unit * travelled,
        from + unit * end,
        dashPaint,
      );
      travelled += dash + gap;
    }

    // 准星端点
    canvas.drawCircle(
      to,
      15,
      Paint()
        ..color = color.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      to,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      to,
      2.6,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _AimLinePainter old) =>
      old.from != from || old.to != to || old.color != color;
}

/// 一个爆点光团（火攻命中 / 属性传导）
class _Burst {
  final int seq;
  final Offset pos;
  final Color color;

  const _Burst({required this.seq, required this.pos, required this.color});
}

/// 一张正在飞行的牌（摸牌时 typeKey 为 null → 画牌背）
class _FlyingCard {
  final int seq;
  final Offset from;
  final Offset to;
  final String? typeKey;
  final String name;
  final String suitSymbol;
  final String points;
  final bool isRed;
  final double width;
  final double height;
  final int delayMs;
  final double arc;

  const _FlyingCard({
    required this.seq,
    required this.from,
    required this.to,
    this.typeKey,
    this.name = '',
    this.suitSymbol = '',
    this.points = '',
    this.isRed = true,
    this.width = 76,
    this.height = 107,
    this.delayMs = 0,
    this.arc = 30,
  });
}

class _FlightCardBack extends StatelessWidget {
  final double width;
  final double height;

  const _FlightCardBack({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D2B1F), Color(0xFF2E1108)],
        ),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.4),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
      ),
      child: Center(
        child: Text('三',
            style: TextStyle(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.75),
                fontSize: height * 0.28,
                fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// 扣置于武将牌上的牌（【弑龙】【成务】产生），用于成务选牌弹窗
class _ExiledCardInfo {
  final String ownerId; // 扣置在哪名角色的武将牌上
  final String typeKey;
  final String name;
  final String suitKey; // SPADE / HEART / CLUB / DIAMOND
  final String point;
  final int cardId;

  const _ExiledCardInfo({
    required this.ownerId,
    required this.typeKey,
    required this.name,
    required this.suitKey,
    required this.point,
    required this.cardId,
  });
}
