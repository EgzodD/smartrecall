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
