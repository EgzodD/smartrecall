import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/flashcard.dart';
import '../models/subtopic.dart';
import '../models/topic.dart';
import 'topic_filter.dart';

/// Local offline storage for flashcards, backed by Hive.
class StorageService {
  static const _boxName = 'flashcards';
  static const _settingsBoxName = 'settings';
  static const _topicsBoxName = 'topics';
  static const _subtopicsBoxName = 'subtopics';
  late Box<Map> _box;
  late Box _settingsBox;
  late Box<Map> _topicsBox;
  late Box<Map> _subtopicsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _topicsBox = await Hive.openBox<Map>(_topicsBoxName);
    _subtopicsBox = await Hive.openBox<Map>(_subtopicsBoxName);
  }

  /// Sync code that scopes this device's cards on the backend. Generated
  /// once per install; enter the same code on another device to link them.
  String get syncId {
    var id = _settingsBox.get('syncId') as String?;
    if (id == null) {
      id = _generateSyncId();
      _settingsBox.put('syncId', id);
    }
    return id;
  }

  set syncId(String id) => _settingsBox.put('syncId', id);

  String _generateSyncId() {
    final rand = Random.secure();
    return List.generate(8, (_) => rand.nextInt(36).toRadixString(36)).join().toUpperCase();
  }

  bool get isEmpty => _box.isEmpty;

  List<Flashcard> getAll() =>
      _box.values.map((m) => Flashcard.fromMap(m)).toList();

  List<Flashcard> getDue() {
    final now = DateTime.now();
    final topics = {for (final t in getTopics()) t.id: t};
    final subtopics = {for (final s in getAllSubtopics()) s.id: s};
    return getAll()
        .where((c) => !c.dueAt.isAfter(now) && isCardActive(c, topics, subtopics))
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  Future<void> put(Flashcard card) => _box.put(card.id, card.toMap());

  Future<void> putAll(Iterable<Flashcard> cards) => _box.putAll({
        for (final c in cards) c.id: c.toMap(),
      });

  Future<void> delete(String id) => _box.delete(id);

  List<Topic> getTopics() =>
      _topicsBox.values.map((m) => Topic.fromMap(m)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<Subtopic> getAllSubtopics() =>
      _subtopicsBox.values.map((m) => Subtopic.fromMap(m)).toList();

  List<Subtopic> getSubtopics(String topicId) =>
      getAllSubtopics().where((s) => s.topicId == topicId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> putTopic(Topic topic) => _topicsBox.put(topic.id, topic.toMap());

  Future<void> putSubtopic(Subtopic subtopic) =>
      _subtopicsBox.put(subtopic.id, subtopic.toMap());

  Future<void> deleteTopic(String id) async {
    await _topicsBox.delete(id);
    for (final s in getSubtopics(id)) {
      await _subtopicsBox.delete(s.id);
    }
    for (final c in getAll().where((c) => c.topicId == id)) {
      await put(_clearTopic(c));
    }
  }

  Future<void> deleteSubtopic(String id) async {
    await _subtopicsBox.delete(id);
    for (final c in getAll().where((c) => c.subtopicId == id)) {
      await put(_clearSubtopic(c));
    }
  }

  Future<void> enableAllTopics() async {
    for (final t in getTopics()) {
      await putTopic(t.copyWith(enabled: true));
    }
    for (final s in getAllSubtopics()) {
      await putSubtopic(s.copyWith(enabled: true));
    }
  }

  Future<void> soloTopic(String id) async {
    for (final t in getTopics()) {
      await putTopic(t.copyWith(enabled: t.id == id));
    }
    for (final s in getSubtopics(id)) {
      await putSubtopic(s.copyWith(enabled: true));
    }
  }

  // copyWith can't express "clear to null" (same as the rest of Flashcard's
  // fields) — construct directly instead for the one place that needs it.
  Flashcard _clearTopic(Flashcard c) => Flashcard(
        id: c.id,
        lexemeId: c.lexemeId,
        learningLanguage: c.learningLanguage,
        front: c.front,
        back: c.back,
        historySeen: c.historySeen,
        historyCorrect: c.historyCorrect,
        lastReviewedAt: c.lastReviewedAt,
        dueAt: c.dueAt,
        synced: c.synced,
        topicId: null,
        subtopicId: null,
      );

  Flashcard _clearSubtopic(Flashcard c) => Flashcard(
        id: c.id,
        lexemeId: c.lexemeId,
        learningLanguage: c.learningLanguage,
        front: c.front,
        back: c.back,
        historySeen: c.historySeen,
        historyCorrect: c.historyCorrect,
        lastReviewedAt: c.lastReviewedAt,
        dueAt: c.dueAt,
        synced: c.synced,
        topicId: c.topicId,
        subtopicId: null,
      );
}
