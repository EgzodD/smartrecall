# ml

Обучение модели Half-Life Regression на
[Duolingo Spaced Repetition Dataset](https://github.com/duolingo/halflife-regression).

## Структура

- `data/` — сырые и промежуточные данные (не коммитятся, см. `.gitignore`)
- `notebooks/` — EDA, эксперименты, сравнение с baseline SM-2
- `src/` — переиспользуемый код: feature engineering, обучение, экспорт модели

## Метрика

MAE по предсказанной вероятности вспоминания (recall probability) —
сравнение модели с baseline SM-2.
