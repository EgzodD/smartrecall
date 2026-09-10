import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[1] / "data" / "smartrecall.db"

_SCHEMA = """
CREATE TABLE IF NOT EXISTS cards (
    user_id TEXT NOT NULL,
    card_id TEXT NOT NULL,
    lexeme_id TEXT,
    learning_language TEXT,
    front TEXT NOT NULL,
    back TEXT NOT NULL,
    history_seen INTEGER NOT NULL,
    history_correct INTEGER NOT NULL,
    last_reviewed_at TEXT,
    due_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (user_id, card_id)
);

CREATE TABLE IF NOT EXISTS review_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    card_id TEXT NOT NULL,
    lexeme_id TEXT,
    learning_language TEXT,
    history_seen_before INTEGER NOT NULL,
    history_correct_before INTEGER NOT NULL,
    delta_seconds INTEGER,
    remembered INTEGER NOT NULL,
    reviewed_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_review_events_user ON review_events (user_id);
"""


def get_connection() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript(_SCHEMA)
    return conn
