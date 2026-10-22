# backend

FastAPI-сервис с эндпоинтом `/predict_interval`. Модель (Half-Life
Regression) подгружается один раз при старте из `../ml/models/hlr_model.joblib`.

## Запуск

Сначала нужна обученная модель — если `ml/models/hlr_model.joblib` ещё нет,
обучите её (см. `ml/README.md`):

```bash
cd ../ml && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 src/download_data.py
python3 src/train.py --data data/settles.acl16.learning_traces.13m.csv --model-out models/hlr_model.joblib
```

Затем сам backend:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## `/predict_interval`

```bash
curl -X POST http://127.0.0.1:8000/predict_interval \
  -H "Content-Type: application/json" \
  -d '{"history_seen": 5, "history_correct": 5, "delta": 86400}'
```

- `history_seen`, `history_correct` — сколько раз карточку показывали и сколько раз ответили верно
- `lexeme_id`, `learning_language` — опционально, для более точного предсказания (используются, если карточка/язык встречались в обучающих данных)
- `delta` — опционально, секунды с прошлого повторения; если передан, в ответе будет `recall_probability` на этот момент
- `target_recall` — желаемая вероятность вспоминания к следующему повторению (по умолчанию 0.9), используется для `next_interval_days`

## `/sync/{user_id}`

Хранилище — SQLite (`backend/data/smartrecall.db`, создаётся автоматически,
в git не коммитится). `user_id` — это код устройства из приложения (см.
`mobile/lib/screens/sync_screen.dart`), не настоящий аккаунт.

Клиент шлёт свои карточки, сервер сливает их с тем, что уже есть (побеждает
запись с более новым `updated_at`), и возвращает полный актуальный набор —
клиент полностью заменяет им свою локальную копию.

```bash
curl -X POST http://127.0.0.1:8000/sync/USER123 \
  -H "Content-Type: application/json" \
  -d '{"cards": [{"id": "card1", "front": "das Wasser", "back": "the water", "history_seen": 1, "history_correct": 1, "due_at": "2026-09-12T10:00:00", "updated_at": "2026-09-10T10:00:00"}]}'
```

Удаления не синхронизируются: карточка, удалённая локально, останется на
сервере и на других устройствах — осознанное ограничение MVP.

## `/log_review/{user_id}` и персонализация

Каждый исход повторения (помню/не помню) логируется отдельно от `/sync` —
это нужно для персонализации, а не для синхронизации состояния карточек.
После того как у пользователя накопится ≥5 залогированных повторений,
`/predict_interval` с тем же `user_id` домножает глобальный half-life на
персональный коэффициент (медиана отношения наблюдаемого half-life к тому,
что предсказала бы глобальная модель для тех же событий; клипается в
`[0.3, 3.0]`).

```bash
curl -X POST http://127.0.0.1:8000/log_review/USER123 \
  -H "Content-Type: application/json" \
  -d '{"card_id": "card1", "history_seen_before": 2, "history_correct_before": 2, "delta": 86400, "remembered": true, "reviewed_at": "2026-09-10T10:00:00"}'
```

## Тесты

```bash
pip install -r requirements-dev.txt
pytest -v
```

Тесты не трогают реальную модель и реальную БД: `conftest.py` обучает
крошечную Ridge-модель на синтетических данных по тому же пайплайну
(`ml/src/features.py`), что и `train.py`, и подменяет `MODEL_PATH`/`db.DB_PATH`
на временные — так что `pytest` можно гонять без скачанного датасета и без
обученной продакшен-модели (в т.ч. в CI, см. `.github/workflows/ci.yml`).
