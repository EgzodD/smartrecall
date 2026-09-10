import 'dart:convert';

import 'package:http/http.dart' as http;

class PredictionResult {
  final double halfLifeDays;
  final double? recallProbability;
  final double nextIntervalDays;
  final double? personalFactor;

  const PredictionResult({
    required this.halfLifeDays,
    required this.recallProbability,
    required this.nextIntervalDays,
    this.personalFactor,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) =>
      PredictionResult(
        halfLifeDays: (json['half_life_days'] as num).toDouble(),
        recallProbability: (json['recall_probability'] as num?)?.toDouble(),
        nextIntervalDays: (json['next_interval_days'] as num).toDouble(),
        personalFactor: (json['personal_factor'] as num?)?.toDouble(),
      );
}

/// Talks to the smartrecall FastAPI backend.
///
/// Default points at localhost, which only works when the backend runs on
/// the same machine as the Flutter host (macOS desktop / iOS simulator).
/// On a physical device or Android emulator, pass the reachable host in.
class ApiService {
  final String baseUrl;
  final Duration timeout;

  ApiService({this.baseUrl = 'http://127.0.0.1:8000', this.timeout = const Duration(seconds: 5)});

  Future<PredictionResult> predictInterval({
    required int historySeen,
    required int historyCorrect,
    String? lexemeId,
    String? learningLanguage,
    int? deltaSeconds,
    double targetRecall = 0.9,
    String? userId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/predict_interval'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'history_seen': historySeen,
            'history_correct': historyCorrect,
            if (lexemeId != null) 'lexeme_id': lexemeId,
            if (learningLanguage != null) 'learning_language': learningLanguage,
            if (deltaSeconds != null) 'delta': deltaSeconds,
            'target_recall': targetRecall,
            if (userId != null) 'user_id': userId,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw ApiException('predict_interval failed: ${response.statusCode} ${response.body}');
    }
    return PredictionResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Best-effort: logs a review outcome so the backend can later personalize
  /// this user's predictions. Failures are the caller's problem to ignore.
  Future<void> logReview({
    required String userId,
    required String cardId,
    String? lexemeId,
    String? learningLanguage,
    required int historySeenBefore,
    required int historyCorrectBefore,
    int? deltaSeconds,
    required bool remembered,
    required DateTime reviewedAt,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/log_review/$userId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'card_id': cardId,
            if (lexemeId != null) 'lexeme_id': lexemeId,
            if (learningLanguage != null) 'learning_language': learningLanguage,
            'history_seen_before': historySeenBefore,
            'history_correct_before': historyCorrectBefore,
            if (deltaSeconds != null) 'delta': deltaSeconds,
            'remembered': remembered,
            'reviewed_at': reviewedAt.toIso8601String(),
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw ApiException('log_review failed: ${response.statusCode} ${response.body}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
