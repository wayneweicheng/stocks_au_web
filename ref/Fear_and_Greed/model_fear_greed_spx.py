"""Model forward S&P 500 returns from CNN Fear & Greed readings."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parent
DEFAULT_HISTORY = ROOT / "fear_greed_spx_history.csv"
HORIZONS = (1, 5, 20, 63, 126)
ALPHAS = (0.0, 0.1, 1.0, 10.0, 100.0)


def load_history(path: Path | str = DEFAULT_HISTORY) -> pd.DataFrame:
    frame = pd.read_csv(path, parse_dates=["Date"])
    for column in ["Fear_Greed_Score", "SPX_Close"]:
        frame[column] = pd.to_numeric(frame[column], errors="coerce")
    frame = (
        frame.dropna(subset=["Date", "Fear_Greed_Score", "SPX_Close"])
        .sort_values("Date")
        .drop_duplicates("Date", keep="last")
        .reset_index(drop=True)
    )
    return remove_placeholder_history(frame)


def remove_placeholder_history(frame: pd.DataFrame, minimum_run: int = 10):
    """Remove CNN's early long runs of exact-neutral placeholder values."""
    is_exact_neutral = frame["Fear_Greed_Score"].eq(50.0)
    groups = is_exact_neutral.ne(is_exact_neutral.shift()).cumsum()
    runs = (
        frame[is_exact_neutral]
        .groupby(groups[is_exact_neutral])
        .agg(end_index=("Fear_Greed_Score", lambda values: values.index.max()),
             length=("Fear_Greed_Score", "size"))
    )
    long_runs = runs[runs["length"] >= minimum_run]
    if long_runs.empty:
        return frame.reset_index(drop=True)
    cutoff = int(long_runs["end_index"].max()) + 1
    return frame.iloc[cutoff:].reset_index(drop=True)


def classify_score(score: float) -> str:
    if not 0 <= score <= 100:
        raise ValueError("Fear & Greed score must be between 0 and 100.")
    if score < 25:
        return "extreme fear"
    if score < 45:
        return "fear"
    if score <= 55:
        return "neutral"
    if score <= 75:
        return "greed"
    return "extreme greed"


def feature_matrix(scores: Iterable[float]) -> np.ndarray:
    score = np.asarray(scores, dtype=float)
    centered = (score - 50.0) / 50.0
    return np.column_stack(
        [centered, np.abs(centered), centered**2, centered**3]
    )


def _fit_ridge(x: np.ndarray, y: np.ndarray, alpha: float):
    mean = x.mean(axis=0)
    scale = x.std(axis=0)
    scale[scale == 0] = 1.0
    standardized = (x - mean) / scale
    intercept = float(y.mean())
    penalty = np.eye(standardized.shape[1]) * alpha
    coefficients = np.linalg.pinv(
        standardized.T @ standardized + penalty
    ) @ (standardized.T @ (y - intercept))
    return coefficients, intercept, mean, scale


def _predict(model, x: np.ndarray) -> np.ndarray:
    coefficients, intercept, mean, scale = model
    return intercept + ((x - mean) / scale) @ coefficients


def evaluate_and_predict(
    frame: pd.DataFrame,
    score: float,
    horizons: Iterable[int] = HORIZONS,
) -> list[dict]:
    x_all = feature_matrix(frame["Fear_Greed_Score"])
    new_x = feature_matrix([score])
    results = []

    for horizon in horizons:
        returns = frame["SPX_Close"].shift(-horizon) / frame["SPX_Close"] - 1
        usable = returns.notna().to_numpy()
        x = x_all[usable]
        y = returns.to_numpy()[usable].astype(float)

        tune_start = int(len(x) * 0.6)
        test_start = int(len(x) * 0.8)
        tune_train_end = max(20, tune_start - horizon)
        x_tune_train, y_tune_train = x[:tune_train_end], y[:tune_train_end]
        x_tune, y_tune = x[tune_start:test_start], y[tune_start:test_start]

        best_alpha = ALPHAS[0]
        best_tune_mae = float("inf")
        for alpha in ALPHAS:
            candidate = _fit_ridge(x_tune_train, y_tune_train, alpha)
            mae = float(np.mean(np.abs(y_tune - _predict(candidate, x_tune))))
            if mae < best_tune_mae:
                best_alpha, best_tune_mae = alpha, mae

        evaluation_end = max(20, test_start - horizon)
        x_train, y_train = x[:evaluation_end], y[:evaluation_end]
        x_test, y_test = x[test_start:], y[test_start:]
        validation_model = _fit_ridge(x_train, y_train, best_alpha)
        validation_prediction = _predict(validation_model, x_test)
        residuals = y_test - validation_prediction
        validation_mae = float(np.mean(np.abs(residuals)))
        baseline_mae = float(np.mean(np.abs(y_test - y_train.mean())))

        final_model = _fit_ridge(x, y, best_alpha)
        prediction = float(_predict(final_model, new_x)[0])
        lower = prediction + float(np.quantile(residuals, 0.10))
        upper = prediction + float(np.quantile(residuals, 0.90))

        distances = np.abs(frame.loc[usable, "Fear_Greed_Score"] - score)
        analog_count = min(50, max(20, len(y) // 30))
        analog_indexes = np.argsort(distances.to_numpy())[:analog_count]
        analog_returns = y[analog_indexes]

        results.append(
            {
                "horizon_trading_days": int(horizon),
                "predicted_return": prediction,
                "interval_10": lower,
                "interval_90": upper,
                "probability_positive": float(np.mean(prediction + residuals > 0)),
                "analog_median_return": float(np.median(analog_returns)),
                "analog_positive_rate": float(np.mean(analog_returns > 0)),
                "validation_mae": validation_mae,
                "baseline_mae": baseline_mae,
                "mae_skill": 1.0 - validation_mae / baseline_mae,
                "directional_accuracy": float(
                    np.mean((validation_prediction > 0) == (y_test > 0))
                ),
                "alpha": float(best_alpha),
                "validation_rows": int(len(y_test)),
                "analog_count": int(analog_count),
            }
        )
    return results


def build_report(
    history_path: Path | str = DEFAULT_HISTORY, score: float | None = None
) -> dict:
    frame = load_history(history_path)
    if score is None:
        latest = frame.iloc[-1]
        score = float(latest["Fear_Greed_Score"])
        reading_date = latest["Date"].date().isoformat()
        source = "latest CNN history row"
    else:
        score = float(score)
        reading_date = None
        source = "user supplied"
    rating = classify_score(score)
    percentile = float((frame["Fear_Greed_Score"] <= score).mean())
    return {
        "source": source,
        "reading_date": reading_date,
        "history_start": frame["Date"].min().date().isoformat(),
        "history_end": frame["Date"].max().date().isoformat(),
        "observations": int(len(frame)),
        "sentiment": {
            "score": score,
            "rating": rating,
            "historical_percentile": percentile,
            "contrarian_interpretation": (
                "contrarian-positive" if score < 45 else
                "contrarian-cautious" if score > 55 else
                "neutral"
            ),
        },
        "predictions": evaluate_and_predict(frame, score),
        "note": (
            "Associational estimate, not investment advice. CNN history only "
            "provides a relatively short usable sample beginning in 2021."
        ),
    }


def print_report(report: dict) -> None:
    sentiment = report["sentiment"]
    print(
        f"CNN Fear & Greed ({report['source']}): {sentiment['score']:.1f} "
        f"({sentiment['rating']})"
    )
    if report["reading_date"]:
        print(f"Reading date: {report['reading_date']}")
    print(
        f"Historical percentile: {sentiment['historical_percentile']:.0%}; "
        f"interpretation: {sentiment['contrarian_interpretation']}"
    )
    print()
    print(
        "Horizon  Prediction  10-90% range       P(up)  Analog median  "
        "Validation skill"
    )
    for item in report["predictions"]:
        print(
            f"{item['horizon_trading_days']:>3} day  "
            f"{item['predicted_return']:>+8.2%}   "
            f"{item['interval_10']:>+7.2%} to {item['interval_90']:>+7.2%}   "
            f"{item['probability_positive']:>5.0%}   "
            f"{item['analog_median_return']:>+8.2%}       "
            f"{item['mae_skill']:>+7.1%}"
        )
    print()
    print(report["note"])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--history", type=Path, default=DEFAULT_HISTORY)
    parser.add_argument("--score", type=float)
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()
    report = build_report(args.history, args.score)
    if args.as_json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report)


if __name__ == "__main__":
    main()
