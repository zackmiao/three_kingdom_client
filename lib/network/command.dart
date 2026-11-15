// 与服务端 com.threekingdom.network.protocol.Command 保持一致
// ignore_for_file: constant_identifier_names
enum Command {
    CONNECT_SUCCESS,
    DISCONNECT,
    BROADCAST_MSG,

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
    // 房间玩法模式：IDENTITY / TEAM_2V2 / LANDLORD
    SET_MODE,
    // 抽将候选：`;` 分隔的武将序列化串（最多 3 名）
    HERO_CANDIDATES,
    // 重新抽取候选武将
    REROLL_HERO,

    // 终局结算
    GAME_OVER,

    SYNC_STATE,
    // 结构化出牌广播：sourceId|sourceName|typeKey|suitKey|point|cardName|targetId:targetName,...
    CARD_PLAYED,
    ASK_ACTION,
    ASK_RESPONSE,
    RESPOND_CARD,
    SHOW_JUDGE_RESULT,
    ASK_TARGET_ZONE,
    ASK_WU_GU,
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
