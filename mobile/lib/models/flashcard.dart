class Flashcard {
  final String id;
  final String lexemeId;
  final String learningLanguage;
  final String front;
  final String back;
  final int historySeen;
  final int historyCorrect;
  final DateTime? lastReviewedAt;
  final DateTime dueAt;
  final bool synced;
  final DateTime updatedAt;

  Flashcard({
    required this.id,
    required this.lexemeId,
    required this.learningLanguage,
    required this.front,
    required this.back,
    this.historySeen = 0,
    this.historyCorrect = 0,
    this.lastReviewedAt,
    required this.dueAt,
    this.synced = true,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Flashcard copyWith({
    int? historySeen,
    int? historyCorrect,
    DateTime? lastReviewedAt,
    DateTime? dueAt,
    bool? synced,
    DateTime? updatedAt,
  }) {
    return Flashcard(
      id: id,
      lexemeId: lexemeId,
      learningLanguage: learningLanguage,
      front: front,
      back: back,
      historySeen: historySeen ?? this.historySeen,
      historyCorrect: historyCorrect ?? this.historyCorrect,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      dueAt: dueAt ?? this.dueAt,
      synced: synced ?? this.synced,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'lexemeId': lexemeId,
        'learningLanguage': learningLanguage,
        'front': front,
        'back': back,
        'historySeen': historySeen,
        'historyCorrect': historyCorrect,
        'lastReviewedAt': lastReviewedAt?.toIso8601String(),
        'dueAt': dueAt.toIso8601String(),
        'synced': synced,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Flashcard.fromMap(Map<dynamic, dynamic> map) => Flashcard(
        id: map['id'] as String,
        lexemeId: map['lexemeId'] as String,
        learningLanguage: map['learningLanguage'] as String,
        front: map['front'] as String,
        back: map['back'] as String,
        historySeen: map['historySeen'] as int,
        historyCorrect: map['historyCorrect'] as int,
        lastReviewedAt: map['lastReviewedAt'] == null
            ? null
            : DateTime.parse(map['lastReviewedAt'] as String),
        dueAt: DateTime.parse(map['dueAt'] as String),
        synced: map['synced'] as bool? ?? true,
        updatedAt: map['updatedAt'] == null
            ? null
            : DateTime.parse(map['updatedAt'] as String),
      );
}
