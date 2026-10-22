"""Faithful SM-2 baseline (per-item ease-factor simulation).

Unlike the Leitner-style heuristic in baseline.py (a vectorized
approximation that never needed a real attempt sequence), this replays the
actual SM-2 state machine per (user_id, lexeme_id) pair in timestamp order:
ease factor, repetition count, and the resulting interval.

The dataset has no 0-5 quality scale, only p_recall (fraction correct in a
session), so it's mapped to three SM-2 quality levels: p_recall >= 0.9 ->
quality 5 (perfect), >= 0.6 -> quality 4 (correct but hesitant), else
quality 2 (fail: resets repetitions, interval back to 1 day). Quality 4 is
deliberately the "neutral" tier in SM-2's own ease-factor formula (it leaves
EF unchanged) — collapsing everything non-failing into quality 4 would
freeze the ease factor at 2.5 for almost everyone and defeat the point of
simulating SM-2 at all, so quality 5 is kept distinct to let EF actually
grow for well-known items. This mapping is a documented simplification,
same spirit as the Leitner baseline's — the ease-factor/interval mechanics
themselves are real SM-2, including updating EF on failure (not just
interval/repetitions), which the original algorithm does and which matters
a lot given the few quality levels available here.

Only rows with a prior review of that same item get a prediction: SM-2
needs a previous schedule to say anything about this delta. The first-ever
review of an item is left NaN (same as HLR/Leitner can't meaningfully
predict a first-ever review either, since there's nothing to learn from
yet for that specific item).
"""

import numpy as np
import pandas as pd

from features import MAX_HALF_LIFE_DAYS, MIN_HALF_LIFE_DAYS

# SM-2 (and Anki, which is based on it) implicitly schedules reviews to land
# around ~90% recall probability.
TARGET_RETENTION = 0.9


def _quality_from_p_recall(p_recall: float) -> int:
    if p_recall >= 0.9:
        return 5
    if p_recall >= 0.6:
        return 4
    return 2


def _simulate_group(group: pd.DataFrame) -> pd.Series:
    ease_factor = 2.5
    repetitions = 0
    interval_days = 0.0
    has_prior_review = False
    predictions = []

    for p_recall, delta_days in zip(group["p_recall"], group["delta_days"]):
        if has_prior_review:
            half_life = np.clip(
                -interval_days / np.log2(TARGET_RETENTION),
                MIN_HALF_LIFE_DAYS,
                MAX_HALF_LIFE_DAYS,
            )
            predictions.append(2 ** (-delta_days / half_life))
        else:
            predictions.append(np.nan)

        quality = _quality_from_p_recall(p_recall)
        # Real SM-2 updates the ease factor on every response, pass or fail.
        ease_factor = max(
            1.3, ease_factor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
        )
        if quality < 3:
            repetitions = 0
            interval_days = 1
        else:
            repetitions += 1
            if repetitions == 1:
                interval_days = 1
            elif repetitions == 2:
                interval_days = 6
            else:
                interval_days = interval_days * ease_factor
        has_prior_review = True

    return pd.Series(predictions, index=group.index)


def predict_recall(df: pd.DataFrame) -> pd.Series:
    """df needs user_id, lexeme_id, timestamp, p_recall, delta_days (see
    features.add_half_life_target). Returns predicted recall probability
    per row, NaN where there's no prior review of that item to predict from.
    """
    sorted_df = df.sort_values(["user_id", "lexeme_id", "timestamp"])
    predictions = sorted_df.groupby(["user_id", "lexeme_id"], group_keys=False).apply(
        _simulate_group
    )
    predictions = pd.Series(predictions, dtype=float)
    return predictions.reindex(df.index)
