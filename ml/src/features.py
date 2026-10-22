"""Feature engineering for Half-Life Regression.

Target: half_life = -delta_days / log2(p_recall), the "observed" half-life
of memory implied by a single review event (Settles & Meeder, ACL 2016).

Features:
- right, wrong: sqrt-damped counts of past correct/incorrect attempts
  (sqrt keeps repeated success/failure from dominating linearly, matching
  the original paper's feature design)
- lexeme_difficulty: mean-target-encoded per-lexeme half-life, fit on the
  training split only (stand-in for per-card difficulty)
- pos: one-hot of part-of-speech, looked up per lexeme_id (see
  LexemePosEncoder) rather than parsed from lexeme_string at inference
  time — the backend/app never has lexeme_string for a card, only lexeme_id
- one-hot of learning_language
"""

import re

import numpy as np
import pandas as pd

MIN_HALF_LIFE_DAYS = 15.0 / (24 * 60)  # 15 minutes
MAX_HALF_LIFE_DAYS = 274.0

_POS_PATTERN = re.compile(r"<(\w+)>")


def extract_pos(lexeme_string) -> str:
    """First tag in an Apertium-style lexeme string, e.g.
    'lernt/lernen<vblex><pri><p3><sg>' -> 'vblex'. 'unk' if missing/unparseable."""
    if not isinstance(lexeme_string, str):
        return "unk"
    match = _POS_PATTERN.search(lexeme_string)
    return match.group(1) if match else "unk"


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


class LexemePosEncoder:
    """Maps lexeme_id -> most common part-of-speech tag, fit on train only.

    Like LexemeDifficultyEncoder, this is looked up by lexeme_id rather than
    parsed fresh at inference time: user-created cards never carry a
    Duolingo-style lexeme_string, only a lexeme_id (if any). Unseen
    lexeme_ids fall back to "unk", same as an unrecognized POS tag.
    """

    def __init__(self):
        self.pos_map_ = pd.Series(dtype=object)

    def fit(self, df: pd.DataFrame) -> "LexemePosEncoder":
        if "lexeme_string" in df.columns:
            pos = df["lexeme_string"].map(extract_pos)
            self.pos_map_ = pos.groupby(df["lexeme_id"]).agg(lambda s: s.mode().iat[0])
        return self

    def transform(self, df: pd.DataFrame) -> pd.Series:
        return df["lexeme_id"].map(self.pos_map_).fillna("unk").rename("pos")


def build_features(
    df: pd.DataFrame,
    lexeme_encoder: LexemeDifficultyEncoder,
    pos_encoder: "LexemePosEncoder | None" = None,
) -> pd.DataFrame:
    features = pd.DataFrame(index=df.index)
    features["right"] = np.sqrt(1 + df["history_correct"])
    features["wrong"] = np.sqrt(1 + (df["history_seen"] - df["history_correct"]))
    features["lexeme_difficulty"] = lexeme_encoder.transform(df)

    lang_dummies = pd.get_dummies(df["learning_language"], prefix="lang", dtype=float)
    features = pd.concat([features, lang_dummies], axis=1)

    if pos_encoder is not None:
        pos_dummies = pd.get_dummies(pos_encoder.transform(df), prefix="pos", dtype=float)
        features = pd.concat([features, pos_dummies], axis=1)

    return features
