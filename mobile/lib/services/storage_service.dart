import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/flashcard.dart';

/// Local offline storage for flashcards, backed by Hive.
class StorageService {
  static const _boxName = 'flashcards';
  static const _settingsBoxName = 'settings';
  late Box<Map> _box;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
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
    return getAll().where((c) => !c.dueAt.isAfter(now)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  Future<void> put(Flashcard card) => _box.put(card.id, card.toMap());

  Future<void> putAll(Iterable<Flashcard> cards) => _box.putAll({
        for (final c in cards) c.id: c.toMap(),
      });

  Future<void> delete(String id) => _box.delete(id);
}
