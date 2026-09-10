import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../services/storage_service.dart';
import 'add_card_screen.dart';

class DeckScreen extends StatefulWidget {
  final StorageService storage;

  const DeckScreen({super.key, required this.storage});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  late List<Flashcard> _cards;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _cards = widget.storage.getAll()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    });
  }

  Future<void> _addCard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddCardScreen(
          onSave: (card) async {
            await widget.storage.put(card);
            _refresh();
          },
        ),
      ),
    );
    _refresh();
  }

  Future<void> _deleteCard(Flashcard card) async {
    await widget.storage.delete(card.id);
    _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Удалено: ${card.front}'),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () async {
            await widget.storage.put(card);
            _refresh();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Моя колода')),
      body: _cards.isEmpty
          ? const Center(child: Text('Пока пусто — добавь первую карточку'))
          : ListView.builder(
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];
                final isDue = !card.dueAt.isAfter(DateTime.now());
                return Dismissible(
                  key: ValueKey(card.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.shade100,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete),
                  ),
                  onDismissed: (_) => _deleteCard(card),
                  child: ListTile(
                    title: Text('${card.front} — ${card.back}'),
                    subtitle: Text(
                      isDue
                          ? 'пора повторить'
                          : 'повторение: ${_formatDate(card.dueAt)}',
                    ),
                    trailing: Text('${card.historyCorrect}/${card.historySeen}'),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCard,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}
