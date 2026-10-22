"""Export logged review_events from the backend's SQLite DB into a CSV that
ml/src/train.py can consume — closes the loop between real app usage and
model training (previously review_events only fed the backend's
post-hoc personal_factor calibration, never the model itself).

Usage:
    python export_from_backend.py --out ../data/from_backend.csv

Reads backend/data/smartrecall.db directly (read-only) rather than
importing the backend package: ml/ and backend/ have separate venvs/
dependency sets by design (ml doesn't have FastAPI installed, backend
doesn't have scikit-learn), and this script only needs the DB file path
and the review_events schema, both cheap to duplicate here rather than
cross-import.
"""

import argparse
import sqlite3
from pathlib import Path

import pandas as pd

DEFAULT_DB_PATH = (
    Path(__file__).resolve().parents[2] / "backend" / "data" / "smartrecall.db"
)


def export(db_path: Path) -> pd.DataFrame:
    conn = sqlite3.connect(db_path)
    try:
        rows = pd.read_sql_query(
            """
            SELECT user_id, lexeme_id, learning_language,
                   history_seen_before, history_correct_before,
                   delta_seconds, remembered, reviewed_at
            FROM review_events
            WHERE delta_seconds IS NOT NULL
            """,
            conn,
        )
    finally:
        conn.close()

    return pd.DataFrame(
        {
            "p_recall": rows["remembered"].astype(float),
            "delta": rows["delta_seconds"],
            "timestamp": pd.to_datetime(rows["reviewed_at"]).astype("int64") // 10**9,
            "user_id": rows["user_id"],
            "learning_language": rows["learning_language"],
            "lexeme_id": rows["lexeme_id"],
            "history_seen": rows["history_seen_before"],
            "history_correct": rows["history_correct_before"],
        }
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB_PATH)
    parser.add_argument("--out", type=Path, default="../data/from_backend.csv")
    args = parser.parse_args()

    if not args.db.exists():
        raise SystemExit(f"no database at {args.db} — has the backend logged any reviews yet?")

    df = export(args.db)
    df.to_csv(args.out, index=False)
    print(f"exported {len(df)} review events -> {args.out}")


if __name__ == "__main__":
    main()
