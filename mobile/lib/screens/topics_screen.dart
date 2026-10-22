import 'package:flutter/material.dart';

import '../models/subtopic.dart';
import '../models/topic.dart';
import '../services/storage_service.dart';

class TopicsScreen extends StatefulWidget {
  final StorageService storage;

  const TopicsScreen({super.key, required this.storage});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  late List<Topic> _topics;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _topics = widget.storage.getTopics());

  Future<void> _addTopic() async {
    final name = await _promptForName('Новая тема');
    if (name == null || name.trim().isEmpty) return;
    await widget.storage.putTopic(
      Topic(id: '${DateTime.now().microsecondsSinceEpoch}', name: name.trim()),
    );
    _refresh();
  }

  Future<void> _addSubtopic(String topicId) async {
    final name = await _promptForName('Новая подтема');
    if (name == null || name.trim().isEmpty) return;
    await widget.storage.putSubtopic(
      Subtopic(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        topicId: topicId,
        name: name.trim(),
      ),
    );
    _refresh();
  }

  Future<String?> _promptForName(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _enableAll() async {
    await widget.storage.enableAllTopics();
    _refresh();
  }

  Future<void> _solo(String topicId) async {
    await widget.storage.soloTopic(topicId);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Темы'),
        actions: [
          TextButton(
            onPressed: _enableAll,
            child: const Text('Включить всё', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _topics.isEmpty
          ? const Center(child: Text('Пока нет тем — добавь первую'))
          : ListView(children: [for (final t in _topics) _topicTile(t)]),
      floatingActionButton: FloatingActionButton(onPressed: _addTopic, child: const Icon(Icons.add)),
    );
  }

  Widget _topicTile(Topic topic) {
    final subtopics = widget.storage.getSubtopics(topic.id);
    return ExpansionTile(
      leading: Checkbox(
        value: topic.enabled,
        onChanged: (v) async {
          await widget.storage.putTopic(topic.copyWith(enabled: v));
          _refresh();
        },
      ),
      title: Text(topic.name),
      trailing: IconButton(
        icon: const Icon(Icons.filter_center_focus),
        tooltip: 'Только эта тема',
        onPressed: () => _solo(topic.id),
      ),
      children: [
        for (final s in subtopics)
          CheckboxListTile(
            value: s.enabled,
            title: Text(s.name),
            onChanged: (v) async {
              await widget.storage.putSubtopic(s.copyWith(enabled: v));
              _refresh();
            },
          ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Добавить подтему'),
          onTap: () => _addSubtopic(topic.id),
        ),
      ],
    );
  }
}
