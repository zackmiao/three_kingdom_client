// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_const_declarations, unnecessary_brace_in_string_interps
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/card_catalog.dart';
import '../models/card_model.dart';
import '../models/opponent_model.dart';
import '../models/skill_model.dart';
import '../network/command.dart';
import '../network/packet.dart';
import '../network/socket_service.dart';
import 'components/action_prompt_bar.dart';
import 'components/battle_log_view.dart';
import 'components/center_stage_view.dart';
import 'components/game_background.dart';
import 'components/hand_card_area.dart';
import 'components/table_seat_card.dart';
import 'components/target_arrow_painter.dart';
import 'dialogs/choice_prompt_dialog.dart';
import 'dialogs/huogong_dialog.dart';
import 'dialogs/judge_result_dialog.dart';
import 'dialogs/pindian_dialog.dart';
import 'dialogs/target_zone_dialog.dart';
import 'dialogs/wugu_dialog.dart';
import 'lobby_screen.dart';
import 'room_screen.dart';

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
  int _hp = 4;
  int _maxHp = 4;
  String _deckInfo = "0/0";
  String _myRole = "LOYAL";
  String _myRoleCn = "忠臣";
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

  String _weapon = "无";
  String _armor = "无";
  String _defHorse = "无";
  String _offHorse = "无";
  List<String> _judgeAreaCards = [];
  List<String> _myMarks = [];

  final Set<int> _selectedIndices = {};
  final Set<String> _selectedTargetIds = {};

  /// 中央结算区当前展示的牌（支持同时展示，如【杀】与【闪】）
  final List<PlayedCard> _shownCards = [];
  String? _activeCardSourceId;
  List<String> _activeCardTargetIds = [];
  List<String> _activeCardTargetNames = [];
  Timer? _cardDisplayTimer;

  /// 可用主动技（右下角金色按钮）
  static const Set<String> _activeSkillNames = {
    '武圣', '乱击', '突袭', '扬威', '国色', '明策',
    '清正', '反间', '据守', '解围', '乱武', '雷击', '颂'
  };

  bool _isZhangBaMode = false;
  bool _isRenDeMode = false;
  bool _isZhiHengMode = false;
  bool _isChuHaiMode = false;
  String? _activeSkill; // 谋攻篇主动技：武圣 / 乱击 / 突袭 / 国色 / 明策 / 反间 / 据守 ...
  String? _skillParam;  // 技能额外参数（清正的花色、颂的标记数）

  bool _isMyTurn = false;
  String? _askPrompt;
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
        WuGuDialog.show(context, packet.data, _sendResponse);
        break;
      case Command.SHOW_JUDGE_RESULT:
        JudgeResultDialog.show(context, packet.data);
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
          _selectedIndices.clear();
          _selectedTargetIds.clear();
          _isZhangBaMode = false;
          _isRenDeMode = false;
          _isZhiHengMode = false;
          _isChuHaiMode = false;
        });
        _startCountdown();

        if (ChoicePromptDialog.matches(packet.data)) {
          ChoicePromptDialog.show(context, packet.data, (v) => _sendResponse(v));
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

  void _startCountdown() {
    _countdownTimer?.cancel();
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
    // 伤害 / 回复 / 护甲 飘字
    final dmg = RegExp(r'受到 (\d+) 点伤害').firstMatch(log);
    if (dmg != null) _flash('-${dmg.group(1)}', Colors.redAccent);
    final heal = RegExp(r'回复 (\d+) 点体力').firstMatch(log);
    if (heal != null) _flash('+${heal.group(1)}', Colors.greenAccent);
    final shield = RegExp(r'抵消了 (\d+) 点伤害').firstMatch(log);
    if (shield != null) _flash('🛡${shield.group(1)}', Colors.lightBlueAccent);

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
  }

  String? _findPlayerIdByName(String name) {
    if (name.contains(widget.playerName)) return widget.playerId;
    for (final opp in _opponents) {
      if (name.contains(opp.name)) return opp.id;
    }
    return null;
  }

  void _parseState(String raw) {
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
            : skStr.split(',').map((sk) {
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
      }
      if (part.startsWith('TURN:')) _turnPlayerId = part.substring(5);
      if (part.startsWith('PHASE:')) _currentPhaseName = part.substring(6);
      if (part.startsWith('ROLE:')) _myRole = part.substring(5);
      if (part.startsWith('ROLECN:')) _myRoleCn = part.substring(7);
      if (part.startsWith('ALIVE:')) _aliveCount = int.tryParse(part.substring(6)) ?? 1;
      if (part.startsWith('ROUND:')) _roundNo = int.tryParse(part.substring(6)) ?? 1;
      if (part.startsWith('TIMEOUT:')) _timeoutSeconds = int.tryParse(part.substring(8)) ?? 25;
      if (part.startsWith('MAXHAND:')) _maxHandCards = int.tryParse(part.substring(8)) ?? 0;
      if (part.startsWith('RANGE:')) _attackRange = int.tryParse(part.substring(6)) ?? 1;
      if (part.startsWith('ARMOR:')) _myArmor = int.tryParse(part.substring(6)) ?? 0;
      if (part.startsWith('FLIP:')) _myFlipped = part.substring(5) == '1';
    }
    _isDead = _hp <= 0;
    _isMyTurn = _turnPlayerId == widget.playerId;
    if (_turnPlayerId != _lastTurnId) {
      _lastTurnId = _turnPlayerId;
      if (_turnPlayerId == widget.playerId && _turnPlayerId.isNotEmpty) {
        _showBanner('你的回合');
      }
    }
    setState(() {});
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

  void _showBanner(String text) {
    setState(() {
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
      body: Stack(
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
    );
  }

  // ---------- 顶部胶囊 ----------

  Widget _buildIdentityPanel() {
    int main = 0, loyal = 0, rebel = 0, traitor = 0;
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
          Row(children: [
            pill('主', main, const Color(0xFFFFC94D)),
            pill('忠', loyal, const Color(0xFF79C7FF)),
            pill('反', rebel, const Color(0xFFFF6B6B)),
            pill('内', traitor, const Color(0xFFC08BFF)),
          ]),
          const SizedBox(height: 3),
          const Text('反贼与内奸全灭则主公方获胜',
              style: TextStyle(fontSize: 8.5, color: Color(0x99FFE0B2))),
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
        Text(_deckInfo, style: const TextStyle(fontSize: 11.5, color: Color(0xFF80DEEA))),
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
        return TableSeatCard(
          cardKey: ValueKey(o.id),
          id: o.id,
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
              painter: TargetArrowPainter(fromOffset: beamFrom, toOffsets: beamTo),
            ),
          ),
          for (final e in pos.entries)
            if (_opponents.any((o) => o.id == e.key))
              Positioned(
                left: e.value.dx,
                top: e.value.dy,
                child: seatWidget(_opponents.firstWhere((o) => o.id == e.key)),
              ),
          Center(child: CenterStageView(cards: _shownCards)),
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
              secondsLeft: _secondsLeft,
              totalSeconds: _countdownTotal,
              isTargetOnly: _isTargetOnlyPrompt,
              hasTarget: _selectedTargetIds.isNotEmpty,
              onConfirm: _onConfirmAction,
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
              onPass: () => _sendResponse('PASS'),
            ),
          SizedBox(
            height: 258,
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
                          handCards: _handCards,
                          selectedIndices: _selectedIndices,
                          maxHandCards: _maxHandCards,
                          enabled: _askPrompt != null,
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
          tool(Icons.receipt_long, '战况', () => _scaffoldKey.currentState?.openEndDrawer()),
        ],
      ),
    );
  }

  Widget _buildRightZone() {
    final activeSkills = _skills
        .where((s) => _activeSkillNames.contains(s.name))
        .map((s) => s.name)
        .toList();

    return SizedBox(
      width: 172,
      child: Column(
        children: [
          // 主动技能（大号金色按钮）
          if (activeSkills.isNotEmpty)
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final n in activeSkills)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: GestureDetector(
                        onTap: () => _onSkillTap(n),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: _activeSkill == n
                                ? [const Color(0xFFFFB300), const Color(0xFFE65100)]
                                : [const Color(0xFFB8860B), const Color(0xFF6D4C00)]),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: _activeSkill == n
                                    ? Colors.yellowAccent
                                    : const Color(0xFFFFD54F),
                                width: _activeSkill == n ? 2 : 1),
                            boxShadow: const [
                              BoxShadow(color: Color(0x66FFB300), blurRadius: 8)
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('发动', style: TextStyle(fontSize: 7.5, color: Colors.amber[100])),
                              Text(n,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (activeSkills.contains('国色'))
                    GestureDetector(
                      onTap: () => _sendResponse('GUOSECLEAR'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5D4037),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFD54F), width: 1),
                        ),
                        child: const Center(
                          child: Text('弃乐',
                              style: TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // 装备缩略
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (final e in [
                  ['⚔', _weapon],
                  ['🛡', _armor],
                  ['🐎', _offHorse],
                  ['🐴', _defHorse],
                ])
                  Expanded(
                    child: Tooltip(
                      message: e[1],
                      child: Container(
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: e[1] != '无'
                              ? const Color(0x55B8860B)
                              : Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                              color: e[1] != '无'
                                  ? const Color(0xFFFFD54F)
                                  : const Color(0x33FFD9A0),
                              width: 0.7),
                        ),
                        child: Center(
                          child: Text(e[0],
                              style: TextStyle(
                                  fontSize: 9,
                                  color: e[1] != '无'
                                      ? Colors.white
                                      : Colors.white24)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 主视角武将卡
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TableSeatCard(
                id: widget.playerId,
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
                seatNo: 1,
                compact: true,
                isCurrentTurn: _turnPlayerId == widget.playerId,
                currentPhaseName:
                    _turnPlayerId == widget.playerId ? _currentPhaseName : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 特效与日志 ----------

  List<Widget> _buildEffects() {
    return [
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
    ];
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
