import 'package:flutter/material.dart';

import 'screens/review_screen.dart';
import 'seed_data.dart';
import 'services/api_service.dart';
import 'services/scheduler.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  if (storage.isEmpty) {
    await storage.putAll(seedDeck());
  }
  runApp(SmartRecallApp(storage: storage));
}

class SmartRecallApp extends StatelessWidget {
  final StorageService storage;

  const SmartRecallApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'smartrecall',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: ReviewScreen(
        storage: storage,
        scheduler: Scheduler(ApiService()),
      ),
    );
  }
}
