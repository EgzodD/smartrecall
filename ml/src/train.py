"""Train the Half-Life Regression model and compare it against the baseline.

Usage:
    python train.py --data ../data/sample.csv --model-out ../models/hlr_model.joblib
"""

import argparse
import json

import joblib
import numpy as np
import pandas as pd
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error
from sklearn.model_selection import GroupShuffleSplit

import baseline
from features import LexemeDifficultyEncoder, add_half_life_target, build_features


def recall_from_half_life(half_life: pd.Series, delta_days: pd.Series) -> np.ndarray:
    return np.exp2(-delta_days / half_life)


def train_test_split_by_user(df: pd.DataFrame, test_size: float = 0.2, seed: int = 42):
    splitter = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=seed)
    train_idx, test_idx = next(splitter.split(df, groups=df["user_id"]))
    return df.iloc[train_idx].reset_index(drop=True), df.iloc[test_idx].reset_index(drop=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", default="../data/sample.csv")
    parser.add_argument("--model-out", default="../models/hlr_model.joblib")
    args = parser.parse_args()

    df = pd.read_csv(args.data)
    df = add_half_life_target(df)
    train_df, test_df = train_test_split_by_user(df)

    lexeme_encoder = LexemeDifficultyEncoder().fit(train_df)
    x_train = build_features(train_df, lexeme_encoder)
    x_test = build_features(test_df, lexeme_encoder)
    x_test = x_test.reindex(columns=x_train.columns, fill_value=0.0)

    y_train = np.log2(train_df["half_life"])
    model = Ridge(alpha=1.0)
    model.fit(x_train, y_train)

    pred_half_life = np.exp2(model.predict(x_test))
    pred_recall_hlr = recall_from_half_life(pred_half_life, test_df["delta_days"])
    pred_recall_baseline = baseline.predict_recall(test_df)

    mae_hlr = mean_absolute_error(test_df["p_recall"], pred_recall_hlr)
    mae_baseline = mean_absolute_error(test_df["p_recall"], pred_recall_baseline)

    metrics = {
        "n_train": len(train_df),
        "n_test": len(test_df),
        "mae_recall_baseline_leitner": mae_baseline,
        "mae_recall_hlr": mae_hlr,
        "features": list(x_train.columns),
        "coef": dict(zip(x_train.columns, model.coef_.tolist())),
        "intercept": float(model.intercept_),
    }
    print(json.dumps(metrics, indent=2, ensure_ascii=False))

    joblib.dump({"model": model, "lexeme_encoder": lexeme_encoder}, args.model_out)
    print(f"saved model -> {args.model_out}")


if __name__ == "__main__":
    main()
