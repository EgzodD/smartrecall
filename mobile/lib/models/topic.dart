class Topic {
  final String id;
  final String name;
  final bool enabled;

  const Topic({required this.id, required this.name, this.enabled = true});

  Topic copyWith({String? name, bool? enabled}) => Topic(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'enabled': enabled};

  factory Topic.fromMap(Map<dynamic, dynamic> map) => Topic(
        id: map['id'] as String,
        name: map['name'] as String,
        enabled: map['enabled'] as bool? ?? true,
      );
}
