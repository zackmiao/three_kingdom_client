class RoomMemberModel {
  final String id;
  final String name;
  final bool isAi;
  final String heroName;
  final bool isReady;

  RoomMemberModel({
    required this.id,
    required this.name,
    required this.isAi,
    required this.heroName,
    required this.isReady,
  });

  static RoomMemberModel parse(String raw) {
    final parts = raw.split('#');
    return RoomMemberModel(
      id: parts[0],
      name: parts[1],
      isAi: parts[2] == "1",
      heroName: parts.length > 3 ? parts[3] : "刘备",
      isReady: parts.length > 4 && parts[4] == "1",
    );
  }
}