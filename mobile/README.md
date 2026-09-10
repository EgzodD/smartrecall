# mobile

Flutter-приложение: карточки, кнопки "Помню"/"Не помню", офлайн-хранение
(Hive), синхронизация с backend.

## Как это работает

- `lib/models/flashcard.dart` — модель карточки (слово, история попыток, дата следующего повторения)
- `lib/services/storage_service.dart` — локальное хранилище на Hive, офлайн по умолчанию
- `lib/services/api_service.dart` — запрос к backend `/predict_interval`
- `lib/services/scheduler.dart` — после ответа "помню/не помню" запрашивает у модели интервал до следующего повторения; если backend недоступен — считает интервал по простой эвристике (удвоение/сброс) и помечает карточку `synced: false`, чтобы досчитать через модель при следующем подключении
- `lib/services/sync_service.dart` — синхронизация с backend `/sync/{user_id}` (push + merge + pull за один запрос)
- `lib/screens/deck_screen.dart`, `add_card_screen.dart` — свои карточки: список, добавление, удаление свайпом
- `lib/screens/stats_screen.dart` — прогресс: всего карточек, к повторению, точность, ближайшие повторения
- `lib/screens/sync_screen.dart` — код устройства для синхронизации между устройствами
- `lib/seed_data.dart` — стартовая колода из 10 немецких слов, чтобы было что повторять сразу после установки

## Запуск

Backend должен быть поднят на `http://127.0.0.1:8000` (см. `../backend/README.md`) —
без него приложение работает в офлайн-режиме с фолбэк-интервалами.

```bash
flutter pub get
flutter run -d macos   # или -d chrome / -d <device-id>
```

## Тесты

```bash
flutter analyze
flutter test
```
