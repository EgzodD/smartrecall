import '../models/flashcard.dart';
import '../models/subtopic.dart';
import '../models/topic.dart';

/// Pure filtering logic, kept free of Hive so it's unit-testable without
/// platform channels (same reasoning as why scheduler logic is tested
/// directly rather than through StorageService).
///
/// A card with a topicId/subtopicId that isn't found locally (e.g. synced
/// from another device — topics don't sync yet) is treated as active:
/// fail-open, never silently hide content the user can't explain.
bool isCardActive(
  Flashcard card,
  Map<String, Topic> topics,
  Map<String, Subtopic> subtopics,
) {
  if (card.topicId == null) return true;

  final topic = topics[card.topicId];
  if (topic == null) return true;
  if (!topic.enabled) return false;

  if (card.subtopicId == null) return true;
  final subtopic = subtopics[card.subtopicId];
  if (subtopic == null) return true;
  return subtopic.enabled;
}
