import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../services/storage_service.dart';

class StatsScreen extends StatelessWidget {
  final StorageService storage;

  const StatsScreen({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    final cards = storage.getAll();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final dueNow = cards.where((c) => !c.dueAt.isAfter(now)).length;
    final reviewedToday = cards
        .where((c) => c.lastReviewedAt != null && c.lastReviewedAt!.isAfter(todayStart))
        .length;

    final totalSeen = cards.fold<int>(0, (sum, c) => sum + c.historySeen);
    final totalCorrect = cards.fold<int>(0, (sum, c) => sum + c.historyCorrect);
    final accuracy = totalSeen == 0 ? null : totalCorrect / totalSeen;

    final upcoming = [...cards]..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Прогресс')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _StatCard(label: 'Всего карточек', value: '${cards.length}'),
              _StatCard(label: 'К повторению', value: '$dueNow'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(label: 'Повторено сегодня', value: '$reviewedToday'),
              _StatCard(
                label: 'Точность',
                value: accuracy == null ? '—' : '${(accuracy * 100).round()}%',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Ближайшие повторения', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final card in upcoming.take(10)) _UpcomingTile(card: card),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final Flashcard card;

  const _UpcomingTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final isDue = !card.dueAt.isAfter(DateTime.now());
    final two = (int n) => n.toString().padLeft(2, '0');
    final due = card.dueAt;
    final when = isDue
        ? 'сейчас'
        : '${two(due.day)}.${two(due.month)} ${two(due.hour)}:${two(due.minute)}';
    return ListTile(
      dense: true,
      title: Text(card.front),
      trailing: Text(when, style: TextStyle(color: isDue ? Colors.teal : Colors.grey)),
    );
  }
}
