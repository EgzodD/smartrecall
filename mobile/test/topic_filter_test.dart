import 'package:flutter_test/flutter_test.dart';
import 'package:smartrecall/models/flashcard.dart';
import 'package:smartrecall/models/subtopic.dart';
import 'package:smartrecall/models/topic.dart';
import 'package:smartrecall/services/topic_filter.dart';

Flashcard _card({String? topicId, String? subtopicId}) => Flashcard(
      id: 'c',
      lexemeId: 'c',
      learningLanguage: 'de',
      front: 'f',
      back: 'b',
      dueAt: DateTime.now(),
      topicId: topicId,
      subtopicId: subtopicId,
    );

void main() {
  test('a card with no topic is always active', () {
    expect(isCardActive(_card(), {}, {}), isTrue);
  });

  test('a card under a disabled topic is inactive', () {
    final topics = {'t1': const Topic(id: 't1', name: 'Math', enabled: false)};
    expect(isCardActive(_card(topicId: 't1'), topics, {}), isFalse);
  });

  test('a card under an enabled topic but disabled subtopic is inactive', () {
    final topics = {'t1': const Topic(id: 't1', name: 'Math')};
    final subtopics = {'s1': const Subtopic(id: 's1', topicId: 't1', name: 'Algebra', enabled: false)};
    expect(isCardActive(_card(topicId: 't1', subtopicId: 's1'), topics, subtopics), isFalse);
  });

  test('a card under an enabled topic and enabled subtopic is active', () {
    final topics = {'t1': const Topic(id: 't1', name: 'Math')};
    final subtopics = {'s1': const Subtopic(id: 's1', topicId: 't1', name: 'Algebra')};
    expect(isCardActive(_card(topicId: 't1', subtopicId: 's1'), topics, subtopics), isTrue);
  });

  test('a topic/subtopic not found locally fails open (active)', () {
    expect(isCardActive(_card(topicId: 'missing'), {}, {}), isTrue);
    final topics = {'t1': const Topic(id: 't1', name: 'Math')};
    expect(
      isCardActive(_card(topicId: 't1', subtopicId: 'missing'), topics, {}),
      isTrue,
    );
  });
}
