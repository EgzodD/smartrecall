import 'package:flutter/material.dart';

import '../models/flashcard.dart';

const supportedLanguages = <String, String>{
  'de': 'немецкий',
  'en': 'английский',
  'es': 'испанский',
  'fr': 'французский',
  'it': 'итальянский',
  'pt': 'португальский',
};

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  String _language = 'de';

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final front = _frontController.text.trim();
    final card = Flashcard(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      lexemeId: front.toLowerCase(),
      learningLanguage: _language,
      front: front,
      back: _backController.text.trim(),
      dueAt: DateTime.now(),
    );
    Navigator.of(context).pop(card);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая карточка')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _frontController,
                decoration: const InputDecoration(labelText: 'Слово / вопрос'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _backController,
                decoration: const InputDecoration(labelText: 'Перевод / ответ'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Язык'),
                items: [
                  for (final entry in supportedLanguages.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) => setState(() => _language = v!),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Добавить')),
            ],
          ),
        ),
      ),
    );
  }
}
