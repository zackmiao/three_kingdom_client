class SkillModel {
  final String name;
  final String type; // PASSIVE / ACTIVE
  final String desc;

  SkillModel({
    required this.name,
    required this.type,
    required this.desc,
  });

  bool get isActive => type == 'ACTIVE';
}