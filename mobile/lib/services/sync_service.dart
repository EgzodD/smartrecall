import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/flashcard.dart';
import 'storage_service.dart';

/// Pushes local cards to the backend and pulls back the merged (last-write-wins
/// by updatedAt) result, overwriting local storage with it.
///
/// Deletions don't propagate: removing a card locally doesn't remove it on
/// the server or on other devices — out of scope for this MVP.
class SyncService {
  final String baseUrl;
  final Duration timeout;

  SyncService({this.baseUrl = 'http://127.0.0.1:8000', this.timeout = const Duration(seconds: 10)});

  Future<int> sync(StorageService storage) async {
    final localCards = storage.getAll();
    final response = await http
        .post(
          Uri.parse('$baseUrl/sync/${storage.syncId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'cards': localCards.map(_toSyncJson).toList()}),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw SyncException('sync failed: ${response.statusCode} ${response.body}');
    }

    final merged = (jsonDecode(response.body)['cards'] as List)
        .map((json) => _fromSyncJson(json as Map<String, dynamic>))
        .toList();
    await storage.putAll(merged);
    return merged.length;
  }

  Map<String, dynamic> _toSyncJson(Flashcard c) => {
        'id': c.id,
        'lexeme_id': c.lexemeId,
        'learning_language': c.learningLanguage,
        'front': c.front,
        'back': c.back,
        'history_seen': c.historySeen,
        'history_correct': c.historyCorrect,
        'last_reviewed_at': c.lastReviewedAt?.toIso8601String(),
        'due_at': c.dueAt.toIso8601String(),
        'updated_at': c.updatedAt.toIso8601String(),
      };

  Flashcard _fromSyncJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'] as String,
        lexemeId: json['lexeme_id'] as String? ?? (json['id'] as String).toLowerCase(),
        learningLanguage: json['learning_language'] as String? ?? 'de',
        front: json['front'] as String,
        back: json['back'] as String,
        historySeen: json['history_seen'] as int,
        historyCorrect: json['history_correct'] as int,
        lastReviewedAt: json['last_reviewed_at'] == null
            ? null
            : DateTime.parse(json['last_reviewed_at'] as String),
        dueAt: DateTime.parse(json['due_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class SyncException implements Exception {
  final String message;
  SyncException(this.message);

  @override
  String toString() => 'SyncException: $message';
}
