"""Leitner-style heuristic baseline.

Stand-in for classic fixed-schedule algorithms (SM-2, Leitner boxes): the
implied half-life doubles for every net correct attempt and halves for every
net incorrect one. This is an approximation — SM-2 proper works off a live
ease-factor sequence we don't have here, since the dataset only carries
cumulative history_seen/history_correct at review time, not the full
per-attempt trace. Documented as such rather than presented as literal SM-2.
"""

import numpy as np
import pandas as pd

from features import MAX_HALF_LIFE_DAYS, MIN_HALF_LIFE_DAYS


def predict_half_life(df: pd.DataFrame) -> pd.Series:
    net_correct = 2 * df["history_correct"] - df["history_seen"]
    hl = np.exp2(net_correct.clip(lower=-10, upper=10))
    return hl.clip(lower=MIN_HALF_LIFE_DAYS, upper=MAX_HALF_LIFE_DAYS)


def predict_recall(df: pd.DataFrame) -> pd.Series:
    hl = predict_half_life(df)
    return np.exp2(-df["delta_days"] / hl)
