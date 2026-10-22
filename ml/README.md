# ml

Обучение модели Half-Life Regression на
[Duolingo Spaced Repetition Dataset](https://github.com/duolingo/halflife-regression).

## Структура

- `data/` — сырые и промежуточные данные (не коммитятся, см. `.gitignore`)
- `notebooks/` — EDA, эксперименты, сравнение с baseline SM-2
- `src/` — переиспользуемый код: feature engineering, обучение, экспорт модели

## Метрика

MAE по предсказанной вероятности вспоминания (recall probability) —
сравнение модели с baseline.

## Baseline-модели

- `src/baseline.py` — Leitner-эвристика (box = net correct, half-life = 2^box). Быстрая, векторизованная, но приближение.
- `src/sm2_baseline.py` — **настоящий SM-2**: ease factor + repetitions + interval, честно реплеится последовательно по `(user_id, lexeme_id)`. Предсказывает только там, где у предмета уже было хотя бы одно предыдущее повторение.

На сэмпле (подмножество теста, где у SM-2 вообще есть предсказание):

| модель | MAE |
|---|---|
| Leitner-эвристика | 0.114 |
| SM-2 (настоящий) | 0.124 |
| HLR (Ridge) | 0.103 |

Настоящий SM-2 оказался **хуже** упрощённой Leitner-эвристики — перепроверено
(ease factor обновляется и на провале, три уровня quality вместо двух
бинарных), результат не меняется. Фиксированные константы SM-2 (EF=2.5,
интервалы 1/6 дней) просто не откалиброваны под реальное поведение
пользователей Duolingo — ключевой аргумент в пользу модели, обученной на
данных, а не жёсткого алгоритма. Подробности и код сравнения — в
`notebooks/02_baseline_and_hlr.ipynb`.

## Признаки

- `right`, `wrong` — sqrt-демпфированные счётчики верных/неверных попыток
- `lexeme_difficulty` — mean-target encoding конкретного слова (lexeme_id) по half-life, обучается только на train-сплите
- `pos` — часть речи, извлечённая из `lexeme_string` (`<vblex>`, `<n>`, ...), one-hot; смотрится по `lexeme_id` через `LexemePosEncoder` (не парсится заново при инференсе — у backend никогда нет сырого `lexeme_string` для карточки, только `lexeme_id`)
- язык — one-hot

На full-датасете (`settles.acl16.learning_traces.13m.csv`, тест-сплит по `user_id`)
добавление `pos` **не дало измеримого прироста MAE** (0.156528 → 0.156528,
разница на 7-м знаке) — ожидаемо, потому что тест-сплит делится по
пользователям, а не по словам: те же леммы, что в train, встречаются и в
test, и `lexeme_difficulty` уже покрывает эту информацию для них. Признак
оставлен, потому что его реальная польза — в cold-start случае (слово/карточка,
которых не было в обучающих данных вообще, например собственные карточки
пользователя или контент из другого домена типа математических формул) —
там `lexeme_difficulty` откатывается на глобальное среднее, а `pos`
по крайней мере даёт грубую оценку типа контента. Этот эффект текущий
train/test-сплит не измеряет (нужен был бы сплит с непересекающимся
словарём лексем, не только пользователей) — честно зафиксировано как
ограничение, а не как доказанное улучшение.

## Замыкаем цикл: реальные данные из приложения → переобучение

Backend логирует каждое "Помню"/"Не помню" в `review_events`
(`backend/app/db.py`), но раньше это использовалось только для
`_personal_factor()` — калибровочного коэффициента поверх модели, не для
самого обучения. `src/export_from_backend.py` замыкает цикл:

```bash
cd ml/src
python export_from_backend.py --out ../data/from_backend.csv
```

Экспортирует `review_events` из `backend/data/smartrecall.db` (читает
файл напрямую, без импорта backend-пакета — у ml/ и backend/ разные venv
и разные зависимости по дизайну) в ту же схему, что ожидает `train.py`.

Дообучение — просто `pd.concat` с исходным датасетом перед вызовом
`add_half_life_target`:

```python
import pandas as pd
duolingo = pd.read_csv("data/settles.acl16.learning_traces.13m.csv")
from_app = pd.read_csv("data/from_backend.csv")
combined = pd.concat([duolingo, from_app], ignore_index=True)
combined.to_csv("data/combined.csv", index=False)
```

```bash
python src/train.py --data data/combined.csv --model-out models/hlr_model.joblib
```

У записей из `from_backend.csv` нет `lexeme_string` (у пользовательских
карточек никогда не будет Apertium-тега) — `LexemePosEncoder`/`extract_pos`
уже обрабатывают это как `"unk"`, пайплайн не ломается (проверено на
реальных логах через `/log_review`). На малом количестве реальных событий
заметного сдвига MAE не ждать — смысл шага в том, что механизм есть и
работает, а не в объёме данных, которых пока физически мало (это не
production с множеством пользователей).
