from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="smartrecall")


class PredictIntervalRequest(BaseModel):
    history_seen: int
    history_correct: int
    delta: int  # seconds since last review


class PredictIntervalResponse(BaseModel):
    half_life_days: float
    recall_probability: float
    next_interval_days: float


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/predict_interval", response_model=PredictIntervalResponse)
def predict_interval(_request: PredictIntervalRequest) -> PredictIntervalResponse:
    raise NotImplementedError("model not loaded yet")
