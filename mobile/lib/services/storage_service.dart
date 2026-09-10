import 'package:hive_flutter/hive_flutter.dart';

import '../models/flashcard.dart';

/// Local offline storage for flashcards, backed by Hive.
class StorageService {
  static const _boxName = 'flashcards';
  late Box<Map> _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
  }

  bool get isEmpty => _box.isEmpty;

  List<Flashcard> getAll() =>
      _box.values.map((m) => Flashcard.fromMap(m)).toList();

  List<Flashcard> getDue() {
    final now = DateTime.now();
    return getAll().where((c) => !c.dueAt.isAfter(now)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  Future<void> put(Flashcard card) => _box.put(card.id, card.toMap());

  Future<void> putAll(Iterable<Flashcard> cards) => _box.putAll({
        for (final c in cards) c.id: c.toMap(),
      });
}
