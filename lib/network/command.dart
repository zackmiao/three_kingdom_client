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
    ASK_WU_GU
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
