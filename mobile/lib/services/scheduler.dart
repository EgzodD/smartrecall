import '../models/flashcard.dart';
import 'api_service.dart';

/// Turns a review outcome into an updated card (new history + next due date).
///
/// Prefers the backend's Half-Life Regression prediction; if the backend is
/// unreachable (offline), falls back to a simple doubling/reset heuristic and
/// marks the card unsynced so [resync] can pick it up once back online.
class Scheduler {
  final ApiService api;

  Scheduler(this.api);

  Future<Flashcard> reviewCard(Flashcard card, {required bool remembered}) async {
    final now = DateTime.now();
    final newHistorySeen = card.historySeen + 1;
    final newHistoryCorrect = card.historyCorrect + (remembered ? 1 : 0);

    try {
      final prediction = await api.predictInterval(
        historySeen: newHistorySeen,
        historyCorrect: newHistoryCorrect,
        lexemeId: card.lexemeId,
        learningLanguage: card.learningLanguage,
      );
      return card.copyWith(
        historySeen: newHistorySeen,
        historyCorrect: newHistoryCorrect,
        lastReviewedAt: now,
        dueAt: now.add(_daysToDuration(prediction.nextIntervalDays)),
        synced: true,
      );
    } catch (_) {
      final previousIntervalDays = card.lastReviewedAt == null
          ? 1
          : card.dueAt.difference(card.lastReviewedAt!).inDays.clamp(1, 30);
      final fallbackDays = remembered ? (previousIntervalDays * 2).clamp(1, 30) : 1;
      return card.copyWith(
        historySeen: newHistorySeen,
        historyCorrect: newHistoryCorrect,
        lastReviewedAt: now,
        dueAt: now.add(Duration(days: fallbackDays)),
        synced: false,
      );
    }
  }

  /// Retries scheduling for cards that fell back to the offline heuristic,
  /// replacing their due date with a real model prediction once reachable.
  Future<Flashcard> resync(Flashcard card) async {
    if (card.synced || card.lastReviewedAt == null) return card;
    try {
      final prediction = await api.predictInterval(
        historySeen: card.historySeen,
        historyCorrect: card.historyCorrect,
        lexemeId: card.lexemeId,
        learningLanguage: card.learningLanguage,
      );
      return card.copyWith(
        dueAt: card.lastReviewedAt!.add(_daysToDuration(prediction.nextIntervalDays)),
        synced: true,
      );
    } catch (_) {
      return card;
    }
  }

  Duration _daysToDuration(double days) =>
      Duration(seconds: (days * 86400).round());
}
