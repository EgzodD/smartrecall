import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../services/scheduler.dart';
import '../services/storage_service.dart';

class ReviewScreen extends StatefulWidget {
  final StorageService storage;
  final Scheduler scheduler;

  const ReviewScreen({super.key, required this.storage, required this.scheduler});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late List<Flashcard> _due;
  bool _revealed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _due = widget.storage.getDue();
    _resyncUnsyncedInBackground();
  }

  void _resyncUnsyncedInBackground() {
    for (final card in widget.storage.getAll().where((c) => !c.synced)) {
      widget.scheduler.resync(card).then((updated) {
        if (updated.synced) widget.storage.put(updated);
      });
    }
  }

  Future<void> _answer(bool remembered) async {
    if (_due.isEmpty || _busy) return;
    setState(() => _busy = true);
    final current = _due.first;
    final updated = await widget.scheduler.reviewCard(current, remembered: remembered);
    await widget.storage.put(updated);
    setState(() {
      _due = widget.storage.getDue();
      _revealed = false;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('smartrecall')),
      body: Center(
        child: _due.isEmpty ? _buildAllDone() : _buildCard(_due.first),
      ),
    );
  }

  Widget _buildAllDone() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Все карточки на сегодня повторены 🎉',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20),
      ),
    );
  }

  Widget _buildCard(Flashcard card) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _revealed = true),
            child: Card(
              elevation: 4,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 160),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(card.front, style: const TextStyle(fontSize: 28)),
                    if (_revealed) ...[
                      const Divider(height: 32),
                      Text(card.back, style: const TextStyle(fontSize: 22, color: Colors.grey)),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('нажми, чтобы посмотреть перевод', style: TextStyle(color: Colors.grey)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_revealed)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : () => _answer(false),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                  child: const Text('Не помню'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _answer(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
                  child: const Text('Помню'),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text('осталось сегодня: ${_due.length}', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
