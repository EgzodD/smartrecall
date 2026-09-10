import 'package:flutter_test/flutter_test.dart';
import 'package:smartrecall/models/flashcard.dart';
import 'package:smartrecall/services/api_service.dart';
import 'package:smartrecall/services/scheduler.dart';

void main() {
  test('falls back to a local heuristic when the backend is unreachable', () async {
    // Port 1 refuses connections immediately, simulating "offline".
    final scheduler = Scheduler(ApiService(baseUrl: 'http://127.0.0.1:1'));
    final card = Flashcard(
      id: 'test',
      lexemeId: 'test',
      learningLanguage: 'de',
      front: 'front',
      back: 'back',
      dueAt: DateTime.now(),
    );

    final updated = await scheduler.reviewCard(card, remembered: true);

    expect(updated.synced, isFalse);
    expect(updated.historySeen, 1);
    expect(updated.historyCorrect, 1);
    expect(updated.dueAt.isAfter(DateTime.now()), isTrue);
  });
}
