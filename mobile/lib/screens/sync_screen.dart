import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/storage_service.dart';
import '../services/sync_service.dart';

class SyncScreen extends StatefulWidget {
  final StorageService storage;
  final SyncService syncService;

  const SyncScreen({super.key, required this.storage, required this.syncService});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final count = await widget.syncService.sync(widget.storage);
      setState(() => _status = 'Синхронизировано. Карточек на сервере: $count');
    } catch (e) {
      setState(() => _status = 'Не удалось синхронизироваться: похоже, backend недоступен');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _linkDevice() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    widget.storage.syncId = code;
    setState(() {});
    await _syncNow();
  }

  @override
  Widget build(BuildContext context) {
    final syncId = widget.storage.syncId;
    return Scaffold(
      appBar: AppBar(title: const Text('Синхронизация')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Код этого устройства — введи его на другом устройстве, чтобы объединить колоды:'),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: SelectableText(
                  syncId,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: syncId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Код скопирован')),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _syncNow,
              child: const Text('Синхронизировать сейчас'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Text(_status!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 32),
            const Text('Или введи код другого устройства, чтобы подключиться к его колоде:'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Код устройства'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _busy ? null : _linkDevice, child: const Text('Подключиться')),
          ],
        ),
      ),
    );
  }
}
