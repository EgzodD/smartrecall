import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI
from pydantic import BaseModel

# Monorepo layout: the trained model was pickled from ml/src, so that
# directory must be importable to unpickle its LexemeDifficultyEncoder.
ML_SRC_DIR = Path(__file__).resolve().parents[2] / "ml" / "src"
sys.path.insert(0, str(ML_SRC_DIR))

from features import MAX_HALF_LIFE_DAYS, MIN_HALF_LIFE_DAYS, build_features  # noqa: E402

MODEL_PATH = Path(__file__).resolve().parents[2] / "ml" / "models" / "hlr_model.joblib"

app = FastAPI(title="smartrecall")
_artifact = joblib.load(MODEL_PATH)
_model = _artifact["model"]
_lexeme_encoder = _artifact["lexeme_encoder"]
_feature_columns = _artifact["feature_columns"]


class PredictIntervalRequest(BaseModel):
    history_seen: int
    history_correct: int
    lexeme_id: str | None = None
    learning_language: str | None = None
    delta: int | None = None  # seconds since last review; omit if reviewing for the first time
    target_recall: float = 0.9  # desired recall probability at the next review


class PredictIntervalResponse(BaseModel):
    half_life_days: float
    recall_probability: float | None
    next_interval_days: float


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/predict_interval", response_model=PredictIntervalResponse)
def predict_interval(request: PredictIntervalRequest) -> PredictIntervalResponse:
    row = pd.DataFrame(
        [
            {
                "history_seen": request.history_seen,
                "history_correct": request.history_correct,
                "lexeme_id": request.lexeme_id,
                "learning_language": request.learning_language,
            }
        ]
    )
    features = build_features(row, _lexeme_encoder).reindex(
        columns=_feature_columns, fill_value=0.0
    )
    log2_half_life = _model.predict(features)[0]
    half_life_days = float(
        np.clip(2**log2_half_life, MIN_HALF_LIFE_DAYS, MAX_HALF_LIFE_DAYS)
    )

    recall_probability = None
    if request.delta is not None:
        delta_days = request.delta / 86400
        recall_probability = float(2 ** (-delta_days / half_life_days))

    next_interval_days = -half_life_days * np.log2(request.target_recall)

    return PredictIntervalResponse(
        half_life_days=half_life_days,
        recall_probability=recall_probability,
        next_interval_days=float(next_interval_days),
    )
