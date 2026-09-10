import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI
from pydantic import BaseModel

from . import db

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


class SyncCard(BaseModel):
    id: str
    lexeme_id: str | None = None
    learning_language: str | None = None
    front: str
    back: str
    history_seen: int
    history_correct: int
    last_reviewed_at: str | None = None
    due_at: str
    updated_at: str


class SyncRequest(BaseModel):
    cards: list[SyncCard]


class SyncResponse(BaseModel):
    cards: list[SyncCard]


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/sync/{user_id}", response_model=SyncResponse)
def sync(user_id: str, request: SyncRequest) -> SyncResponse:
    """Last-write-wins sync: merge the client's cards into storage (by
    updated_at), then return the full current set for this user_id so the
    client can overwrite its local state with the merged result."""
    conn = db.get_connection()
    with conn:
        for card in request.cards:
            existing = conn.execute(
                "SELECT updated_at FROM cards WHERE user_id = ? AND card_id = ?",
                (user_id, card.id),
            ).fetchone()
            if existing is not None and existing["updated_at"] >= card.updated_at:
                continue
            conn.execute(
                """
                INSERT INTO cards (
                    user_id, card_id, lexeme_id, learning_language, front, back,
                    history_seen, history_correct, last_reviewed_at, due_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (user_id, card_id) DO UPDATE SET
                    lexeme_id=excluded.lexeme_id,
                    learning_language=excluded.learning_language,
                    front=excluded.front,
                    back=excluded.back,
                    history_seen=excluded.history_seen,
                    history_correct=excluded.history_correct,
                    last_reviewed_at=excluded.last_reviewed_at,
                    due_at=excluded.due_at,
                    updated_at=excluded.updated_at
                """,
                (
                    user_id,
                    card.id,
                    card.lexeme_id,
                    card.learning_language,
                    card.front,
                    card.back,
                    card.history_seen,
                    card.history_correct,
                    card.last_reviewed_at,
                    card.due_at,
                    card.updated_at,
                ),
            )

    rows = conn.execute(
        "SELECT * FROM cards WHERE user_id = ?", (user_id,)
    ).fetchall()
    conn.close()

    return SyncResponse(
        cards=[
            SyncCard(
                id=row["card_id"],
                lexeme_id=row["lexeme_id"],
                learning_language=row["learning_language"],
                front=row["front"],
                back=row["back"],
                history_seen=row["history_seen"],
                history_correct=row["history_correct"],
                last_reviewed_at=row["last_reviewed_at"],
                due_at=row["due_at"],
                updated_at=row["updated_at"],
            )
            for row in rows
        ]
    )


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
