// 与服务端 com.threekingdom.network.protocol.Command 保持一致
// ignore_for_file: constant_identifier_names
enum Command {
    CONNECT_SUCCESS,
    DISCONNECT,
    BROADCAST_MSG,

    // 注册：data = `用户名|密码`，回复 ACCOUNT_RESULT
    REGISTER,
    // 登录：data = `用户名|密码`，回复 ACCOUNT_RESULT
    LOGIN,
    // 账号结果：`OK|用户名|头像base64` 或 `FAIL|原因`
    ACCOUNT_RESULT,
    // 上传头像：data = 图片 base64，回复 AVATAR_RESULT
    UPDATE_AVATAR,
    // 头像上传结果：`OK` 或 `FAIL|原因`
    AVATAR_RESULT,
    // 请求某人头像：data = 用户名，回复 AVATAR
    GET_AVATAR,
    // 某人头像：`用户名|base64`
    AVATAR,

    CREATE_ROOM,
    JOIN_ROOM,
    LEAVE_ROOM,
    ROOM_SYNC,
    HERO_LIST,
    SELECT_HERO,
    TOGGLE_READY,
    ADD_AI,
    REMOVE_AI,
    START_GAME,
  /// 测试模式：给自己发一张牌（data 为空则从牌堆摸一张）
  TEST_GRANT_CARD,
  /// 测试模式：附身到某个座位（data = 座位 id，空则回到自己）
  TEST_POSSESS,
    // 房间玩法模式：IDENTITY / TEAM_2V2 / LANDLORD
    SET_MODE,
    // 抽将候选：`;` 分隔的武将序列化串（最多 3 名）
    HERO_CANDIDATES,
    // 重新抽取候选武将
    REROLL_HERO,
    // 大厅房间列表：`房间号|房间名|人数|上限|模式key|状态`，`;` 分隔
    ROOM_LIST,

    // 终局结算
    GAME_OVER,

    SYNC_STATE,
    // 结构化出牌广播：sourceId|sourceName|typeKey|suitKey|point|cardName|targetId:targetName,...
    CARD_PLAYED,
    // 手牌数量变化（别人摸牌/失去牌）：playerId|playerName|delta
    CARD_FLOW,
    // 明牌事件（过河拆桥/顺手牵羊/火攻）：ownerId|ownerName|typeKey|suitKey|point|cardName|action
    CARD_REVEALED,
  CARD_TRANSFER,

  /// 服务端等待某玩家响应（出闪/杀/无懈）：data = 玩家ID，空串表示清空。
  WAITING_RESPONSE,
    ASK_ACTION,
    ASK_RESPONSE,
    RESPOND_CARD,
    SHOW_JUDGE_RESULT,
    ASK_TARGET_ZONE,
    ASK_WU_GU,
    // 五谷丰登共享选牌台：pickerId#pickerName#ASK|PICK|SKIP|END#items
    WU_GU_POOL,
    // 手气卡：`剩余次数|idx#typeKey#suitKey#point#id#name#NONE;...`，回 RESPOND_CARD "1"/"0"
    ASK_LUCKY
}

extension CommandExtension on Command {
  String toCommandString() {
    return name;
  }

  static Command fromString(String str) {
    return Command.values.firstWhere(
      (e) => e.name == str,
      orElse: () => Command.BROADCAST_MSG,
    );
  }
}
