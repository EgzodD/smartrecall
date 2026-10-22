class Subtopic {
  final String id;
  final String topicId;
  final String name;
  final bool enabled;

  const Subtopic({
    required this.id,
    required this.topicId,
    required this.name,
    this.enabled = true,
  });

  Subtopic copyWith({String? name, bool? enabled}) => Subtopic(
        id: id,
        topicId: topicId,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'topicId': topicId, 'name': name, 'enabled': enabled};

  factory Subtopic.fromMap(Map<dynamic, dynamic> map) => Subtopic(
        id: map['id'] as String,
        topicId: map['topicId'] as String,
        name: map['name'] as String,
        enabled: map['enabled'] as bool? ?? true,
      );
}
