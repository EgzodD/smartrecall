"""Feature engineering for Half-Life Regression.

Target: half_life = -delta_days / log2(p_recall), the "observed" half-life
of memory implied by a single review event (Settles & Meeder, ACL 2016).

Features:
- right, wrong: sqrt-damped counts of past correct/incorrect attempts
  (sqrt keeps repeated success/failure from dominating linearly, matching
  the original paper's feature design)
- lexeme_difficulty: mean-target-encoded per-lexeme half-life, fit on the
  training split only (stand-in for per-card difficulty)
- one-hot of learning_language
"""

import numpy as np
import pandas as pd

MIN_HALF_LIFE_DAYS = 15.0 / (24 * 60)  # 15 minutes
MAX_HALF_LIFE_DAYS = 274.0


def add_half_life_target(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    p = df["p_recall"].clip(lower=1e-4, upper=1 - 1e-4)
    delta_days = df["delta"] / 86400
    df["half_life"] = (-delta_days / np.log2(p)).clip(
        lower=MIN_HALF_LIFE_DAYS, upper=MAX_HALF_LIFE_DAYS
    )
    df["delta_days"] = delta_days
    return df


class LexemeDifficultyEncoder:
    """Mean-target-encodes lexeme_id -> average half_life, fit on train only."""

    def __init__(self, smoothing: float = 10.0):
        self.smoothing = smoothing
        self.global_mean_ = 0.0
        self.lexeme_mean_ = pd.Series(dtype=float)

    def fit(self, df: pd.DataFrame) -> "LexemeDifficultyEncoder":
        self.global_mean_ = float(df["half_life"].mean())
        stats = df.groupby("lexeme_id")["half_life"].agg(["mean", "count"])
        self.lexeme_mean_ = (
            stats["count"] * stats["mean"] + self.smoothing * self.global_mean_
        ) / (stats["count"] + self.smoothing)
        return self

    def transform(self, df: pd.DataFrame) -> pd.Series:
        mapped = df["lexeme_id"].map(self.lexeme_mean_).fillna(self.global_mean_)
        return mapped.rename("lexeme_difficulty")


def build_features(
    df: pd.DataFrame, lexeme_encoder: LexemeDifficultyEncoder
) -> pd.DataFrame:
    features = pd.DataFrame(index=df.index)
    features["right"] = np.sqrt(1 + df["history_correct"])
    features["wrong"] = np.sqrt(1 + (df["history_seen"] - df["history_correct"]))
    features["lexeme_difficulty"] = lexeme_encoder.transform(df)

    lang_dummies = pd.get_dummies(df["learning_language"], prefix="lang", dtype=float)
    features = pd.concat([features, lang_dummies], axis=1)
    return features
