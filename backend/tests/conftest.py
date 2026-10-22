import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import pytest
from fastapi.testclient import TestClient
from sklearn.linear_model import Ridge

# Same monorepo-path trick as app/main.py: needed to build a fixture model
# with the real feature pipeline (and to unpickle it afterwards).
ML_SRC_DIR = Path(__file__).resolve().parents[2] / "ml" / "src"
sys.path.insert(0, str(ML_SRC_DIR))

from features import (  # noqa: E402
    LexemeDifficultyEncoder,
    LexemePosEncoder,
    add_half_life_target,
    build_features,
)


def _make_fixture_model(path: Path) -> None:
    """Fits a tiny real Ridge/HLR model on synthetic data, using the exact
    same feature pipeline as ml/src/train.py, so tests exercise real
    inference code rather than a mock. The synthetic half-life is built to
    genuinely depend on history_correct/history_seen, so a monotonicity
    assertion (more correct answers -> longer half-life) is a meaningful
    check, not a tautology.
    """
    rng = np.random.default_rng(0)
    n = 300
    history_seen = rng.integers(1, 20, size=n)
    history_correct = rng.integers(0, history_seen + 1)
    delta = rng.integers(3600, 30 * 86400, size=n)
    lexeme_ids = [f"word{i}" for i in range(15)]
    pos_tags = ["n", "vblex", "adj"]
    lexeme_pos = {lid: pos_tags[i % len(pos_tags)] for i, lid in enumerate(lexeme_ids)}
    lexeme_id = rng.choice(lexeme_ids, size=n)
    learning_language = rng.choice(["de", "en", "es"], size=n)

    true_hl_days = 1 + 15 * (history_correct / np.maximum(history_seen, 1))
    delta_days = delta / 86400
    noise = rng.normal(0, 0.03, size=n)
    p_recall = np.clip(2 ** (-delta_days / true_hl_days) + noise, 0.01, 0.99)

    df = pd.DataFrame(
        {
            "p_recall": p_recall,
            "delta": delta,
            "history_seen": history_seen,
            "history_correct": history_correct,
            "lexeme_id": lexeme_id,
            "lexeme_string": [f"x/x<{lexeme_pos[lid]}>" for lid in lexeme_id],
            "learning_language": learning_language,
        }
    )
    df = add_half_life_target(df)

    lexeme_encoder = LexemeDifficultyEncoder().fit(df)
    pos_encoder = LexemePosEncoder().fit(df)
    x = build_features(df, lexeme_encoder, pos_encoder)
    y = np.log2(df["half_life"])

    model = Ridge(alpha=1.0)
    model.fit(x, y)

    joblib.dump(
        {
            "model": model,
            "lexeme_encoder": lexeme_encoder,
            "pos_encoder": pos_encoder,
            "feature_columns": list(x.columns),
            "languages": sorted(df["learning_language"].unique().tolist()),
        },
        path,
    )


@pytest.fixture
def client(tmp_path, monkeypatch):
    from app import db, main

    monkeypatch.setattr(db, "DB_PATH", tmp_path / "test.db")

    model_path = tmp_path / "fixture_model.joblib"
    _make_fixture_model(model_path)
    monkeypatch.setattr(main, "MODEL_PATH", model_path)

    with TestClient(main.app) as test_client:
        yield test_client
