import 'models/flashcard.dart';

/// Starter deck so the app has something to review on first launch.
/// lexemeId here doesn't match a real Duolingo dataset lexeme (it's a new
/// deck), so the model just falls back to the global average difficulty —
/// still fine, this is what happens for any new card in production too.
List<Flashcard> seedDeck() {
  final now = DateTime.now();
  const words = <(String, String)>[
    ('der Hund', 'the dog'),
    ('die Katze', 'the cat'),
    ('das Haus', 'the house'),
    ('lernen', 'to learn'),
    ('sprechen', 'to speak'),
    ('das Wasser', 'the water'),
    ('die Zeit', 'the time'),
    ('groß', 'big'),
    ('klein', 'small'),
    ('schnell', 'fast'),
  ];

  return [
    for (final (front, back) in words)
      Flashcard(
        id: front,
        lexemeId: front.toLowerCase(),
        learningLanguage: 'de',
        front: front,
        back: back,
        dueAt: now,
      ),
  ];
}
