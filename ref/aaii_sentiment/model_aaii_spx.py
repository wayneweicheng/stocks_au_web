"""Model forward S&P 500 returns from weekly AAII sentiment readings."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd


DEFAULT_WORKBOOK = Path(__file__).with_name("sentiment.xls")
HORIZONS = (1, 4, 13, 26)
ALPHAS = (0.0, 0.1, 1.0, 10.0, 100.0)


def load_sentiment(path: Path | str) -> pd.DataFrame:
    """Load valid weekly observations and discard workbook summary rows."""
    frame = pd.read_excel(path, sheet_name="SENTIMENT", header=3, engine="xlrd")
    frame = frame.rename(columns={"Close": "SPX_Close"})
    frame["Date"] = pd.to_datetime(frame["Date"], errors="coerce")
    numeric = ["Bullish", "Neutral", "Bearish", "SPX_Close"]
    for column in numeric:
        frame[column] = pd.to_numeric(frame[column], errors="coerce")
    frame = (
        frame.dropna(subset=["Date", *numeric])
        .sort_values("Date")
        .drop_duplicates("Date", keep="last")
        .reset_index(drop=True)
    )
    return frame[["Date", *numeric]]


def normalize_reading(
    bullish: float, neutral: float, bearish: float
) -> tuple[float, float, float]:
    values = np.asarray([bullish, neutral, bearish], dtype=float)
    if not np.isfinite(values).all() or (values < 0).any():
        raise ValueError("Sentiment values must be finite and non-negative.")
    if values.max() > 1.0:
        values = values / 100.0
    total = float(values.sum())
    if not 0.97 <= total <= 1.03:
        raise ValueError(
            "Bullish, neutral, and bearish must total approximately 1 or 100."
        )
    values = values / total
    return tuple(float(value) for value in values)


def feature_matrix(
    bullish: Iterable[float],
    neutral: Iterable[float],
    bearish: Iterable[float],
) -> np.ndarray:
    bull = np.asarray(bullish, dtype=float)
    neut = np.asarray(neutral, dtype=float)
    bear = np.asarray(bearish, dtype=float)
    spread = bull - bear
    return np.column_stack(
        [
            bull,
            neut,
            bear,
            spread,
            np.abs(spread),
            bull * bull,
            bear * bear,
            bull * bear,
        ]
    )


def _fit_ridge(
    x: np.ndarray, y: np.ndarray, alpha: float
) -> tuple[np.ndarray, float, np.ndarray, np.ndarray]:
    mean = x.mean(axis=0)
    scale = x.std(axis=0)
    scale[scale == 0] = 1.0
    standardized = (x - mean) / scale
    y_mean = float(y.mean())
    centered_y = y - y_mean
    penalty = np.eye(standardized.shape[1]) * alpha
    coefficients = np.linalg.pinv(standardized.T @ standardized + penalty) @ (
        standardized.T @ centered_y
    )
    return coefficients, y_mean, mean, scale


def _predict_ridge(
    model: tuple[np.ndarray, float, np.ndarray, np.ndarray], x: np.ndarray
) -> np.ndarray:
    coefficients, intercept, mean, scale = model
    return intercept + ((x - mean) / scale) @ coefficients


def evaluate_and_predict(
    frame: pd.DataFrame,
    reading: tuple[float, float, float],
    horizons: Iterable[int] = HORIZONS,
) -> list[dict[str, float | int]]:
    x_all = feature_matrix(frame["Bullish"], frame["Neutral"], frame["Bearish"])
    new_x = feature_matrix([reading[0]], [reading[1]], [reading[2]])
    results: list[dict[str, float | int]] = []

    for horizon in horizons:
        forward_return = frame["SPX_Close"].shift(-horizon) / frame["SPX_Close"] - 1
        usable = forward_return.notna().to_numpy()
        x = x_all[usable]
        y = forward_return.to_numpy()[usable].astype(float)
        tune_start = int(len(x) * 0.6)
        test_start = int(len(x) * 0.8)
        tune_train_end = max(20, tune_start - horizon)
        x_tune_train, y_tune_train = x[:tune_train_end], y[:tune_train_end]
        x_tune, y_tune = x[tune_start:test_start], y[tune_start:test_start]

        best_alpha = ALPHAS[0]
        best_mae = float("inf")
        for alpha in ALPHAS:
            candidate = _fit_ridge(x_tune_train, y_tune_train, alpha)
            mae = float(np.mean(np.abs(y_tune - _predict_ridge(candidate, x_tune))))
            if mae < best_mae:
                best_alpha, best_mae = alpha, mae

        evaluation_train_end = max(20, test_start - horizon)
        x_evaluation_train = x[:evaluation_train_end]
        y_evaluation_train = y[:evaluation_train_end]
        x_test, y_test = x[test_start:], y[test_start:]
        validation_model = _fit_ridge(
            x_evaluation_train, y_evaluation_train, best_alpha
        )
        validation_prediction = _predict_ridge(validation_model, x_test)
        residuals = y_test - validation_prediction
        validation_mae = float(np.mean(np.abs(residuals)))
        baseline_mae = float(
            np.mean(np.abs(y_test - y_evaluation_train.mean()))
        )
        directional_accuracy = float(
            np.mean((validation_prediction > 0) == (y_test > 0))
        )

        final_model = _fit_ridge(x, y, best_alpha)
        prediction = float(_predict_ridge(final_model, new_x)[0])
        lower = prediction + float(np.quantile(residuals, 0.10))
        upper = prediction + float(np.quantile(residuals, 0.90))
        probability_positive = float(np.mean(prediction + residuals > 0))

        analog_values = frame.loc[
            usable, ["Bullish", "Neutral", "Bearish"]
        ].to_numpy(dtype=float)
        analog_scale = analog_values.std(axis=0)
        analog_scale[analog_scale == 0] = 1.0
        distances = np.linalg.norm(
            (analog_values - np.asarray(reading)) / analog_scale, axis=1
        )
        neighbor_count = min(50, max(20, len(y) // 40))
        neighbors = np.argsort(distances)[:neighbor_count]
        analog_returns = y[neighbors]

        results.append(
            {
                "horizon_weeks": int(horizon),
                "predicted_return": prediction,
                "interval_10": lower,
                "interval_90": upper,
                "probability_positive": probability_positive,
                "analog_median_return": float(np.median(analog_returns)),
                "analog_positive_rate": float(np.mean(analog_returns > 0)),
                "validation_mae": validation_mae,
                "baseline_mae": baseline_mae,
                "mae_skill": 1.0 - validation_mae / baseline_mae,
                "directional_accuracy": directional_accuracy,
                "alpha": float(best_alpha),
                "validation_rows": int(len(y_test)),
                "analog_count": int(neighbor_count),
            }
        )
    return results


def describe_reading(
    frame: pd.DataFrame, reading: tuple[float, float, float]
) -> dict[str, float | str]:
    bullish, neutral, bearish = reading
    spread = bullish - bearish
    historical_spread = frame["Bullish"] - frame["Bearish"]
    percentile = float((historical_spread <= spread).mean())
    if percentile <= 0.10:
        regime = "extreme bearish sentiment (historically contrarian-positive)"
    elif percentile <= 0.25:
        regime = "bearish sentiment"
    elif percentile >= 0.90:
        regime = "extreme bullish sentiment (historically contrarian-cautious)"
    elif percentile >= 0.75:
        regime = "bullish sentiment"
    else:
        regime = "roughly neutral sentiment"
    return {
        "bullish": bullish,
        "neutral": neutral,
        "bearish": bearish,
        "bull_bear_spread": spread,
        "spread_historical_percentile": percentile,
        "regime": regime,
    }


def build_report(
    workbook: Path | str,
    bullish: float | None = None,
    neutral: float | None = None,
    bearish: float | None = None,
) -> dict:
    frame = load_sentiment(workbook)
    supplied = [bullish, neutral, bearish]
    if all(value is None for value in supplied):
        latest = frame.iloc[-1]
        reading = normalize_reading(
            latest["Bullish"], latest["Neutral"], latest["Bearish"]
        )
        reading_date = latest["Date"].date().isoformat()
        source = "latest workbook row"
    elif all(value is not None for value in supplied):
        reading = normalize_reading(float(bullish), float(neutral), float(bearish))
        reading_date = None
        source = "user supplied"
    else:
        raise ValueError("Supply all three sentiment values or none of them.")
    return {
        "source": source,
        "reading_date": reading_date,
        "history_start": frame["Date"].min().date().isoformat(),
        "history_end": frame["Date"].max().date().isoformat(),
        "observations": int(len(frame)),
        "sentiment": describe_reading(frame, reading),
        "predictions": evaluate_and_predict(frame, reading),
        "note": (
            "Associational estimate, not investment advice. Sentiment has weak and "
            "time-varying predictive power; inspect validation skill and intervals."
        ),
    }


def print_report(report: dict) -> None:
    sentiment = report["sentiment"]
    print(
        f"AAII reading ({report['source']}): "
        f"bullish {sentiment['bullish']:.1%}, "
        f"neutral {sentiment['neutral']:.1%}, "
        f"bearish {sentiment['bearish']:.1%}"
    )
    if report["reading_date"]:
        print(f"Reading date: {report['reading_date']}")
    print(
        f"Meaning: {sentiment['regime']}; bull-bear spread "
        f"{sentiment['bull_bear_spread']:+.1%} "
        f"({sentiment['spread_historical_percentile']:.0%} historical percentile)"
    )
    print()
    print(
        "Horizon  Prediction  10-90% range       P(up)  Analog median  "
        "Validation skill"
    )
    for item in report["predictions"]:
        print(
            f"{item['horizon_weeks']:>3} wk   "
            f"{item['predicted_return']:>+8.2%}   "
            f"{item['interval_10']:>+7.2%} to {item['interval_90']:>+7.2%}   "
            f"{item['probability_positive']:>5.0%}   "
            f"{item['analog_median_return']:>+8.2%}       "
            f"{item['mae_skill']:>+7.1%}"
        )
    print()
    print(report["note"])


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Predict forward S&P 500 returns from AAII sentiment."
    )
    parser.add_argument("--workbook", type=Path, default=DEFAULT_WORKBOOK)
    parser.add_argument("--bullish", type=float)
    parser.add_argument("--neutral", type=float)
    parser.add_argument("--bearish", type=float)
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()
    report = build_report(
        args.workbook, args.bullish, args.neutral, args.bearish
    )
    if args.as_json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report)


if __name__ == "__main__":
    main()
