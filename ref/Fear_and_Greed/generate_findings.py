"""Generate reusable CNN Fear & Greed findings in Markdown and JSON."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

from model_fear_greed_spx import HORIZONS, build_report, load_history


ROOT = Path(__file__).resolve().parent
HISTORY = ROOT / "fear_greed_spx_history.csv"
JSON_OUTPUT = ROOT / "fear_greed_knowledge.json"
MARKDOWN_OUTPUT = ROOT / "FINDINGS.md"


def pct(value: float) -> str:
    return f"{value:+.1%}"


def build_historical_findings(frame):
    findings = {
        "score_distribution": {
            "mean": float(frame["Fear_Greed_Score"].mean()),
            "median": float(frame["Fear_Greed_Score"].median()),
            "p10": float(frame["Fear_Greed_Score"].quantile(0.10)),
            "p25": float(frame["Fear_Greed_Score"].quantile(0.25)),
            "p75": float(frame["Fear_Greed_Score"].quantile(0.75)),
            "p90": float(frame["Fear_Greed_Score"].quantile(0.90)),
        },
        "forward_return_baselines": [],
        "rating_regimes": [],
    }
    for horizon in HORIZONS:
        returns = frame["SPX_Close"].shift(-horizon) / frame["SPX_Close"] - 1
        valid = returns.notna()
        values = returns[valid]
        findings["forward_return_baselines"].append(
            {
                "horizon_trading_days": horizon,
                "observations": int(valid.sum()),
                "mean_return": float(values.mean()),
                "median_return": float(values.median()),
                "positive_rate": float((values > 0).mean()),
                "p10": float(values.quantile(0.10)),
                "p90": float(values.quantile(0.90)),
                "score_return_correlation": float(
                    np.corrcoef(frame.loc[valid, "Fear_Greed_Score"], values)[0, 1]
                ),
            }
        )

    order = ["extreme fear", "fear", "neutral", "greed", "extreme greed"]
    for rating in order:
        in_regime = frame["Fear_Greed_Score_Rating"].eq(rating)
        regime = {
            "rating": rating,
            "observations": int(in_regime.sum()),
            "score_min": float(frame.loc[in_regime, "Fear_Greed_Score"].min()),
            "score_max": float(frame.loc[in_regime, "Fear_Greed_Score"].max()),
            "forward_returns": [],
        }
        for horizon in HORIZONS:
            returns = frame["SPX_Close"].shift(-horizon) / frame["SPX_Close"] - 1
            values = returns[in_regime & returns.notna()]
            regime["forward_returns"].append(
                {
                    "horizon_trading_days": horizon,
                    "mean_return": float(values.mean()),
                    "median_return": float(values.median()),
                    "positive_rate": float((values > 0).mean()),
                }
            )
        findings["rating_regimes"].append(regime)
    return findings


def render_markdown(knowledge: dict) -> str:
    report = knowledge["latest_report"]
    sentiment = report["sentiment"]
    historical = knowledge["historical_findings"]
    lines = [
        "# CNN Fear & Greed Index and S&P 500 Findings",
        "",
        f"Generated from CNN chart data using {report['observations']:,} usable "
        f"daily observations from {report['history_start']} through "
        f"{report['history_end']}.",
        "",
        "Sources:",
        "",
        "- https://edition.cnn.com/markets/fear-and-greed",
        "- https://production.dataviz.cnn.io/index/fearandgreed/graphdata/",
        "",
        "## Executive conclusion",
        "",
        "The CNN Fear & Greed Index is useful as a coincident market-state and "
        "contrarian context indicator. In this sample, extreme fear was followed "
        "by stronger typical S&P 500 returns mainly around 20 to 63 trading days. "
        "The effect is weak at short horizons and does not persist cleanly to "
        "126 trading days, so this is not a dependable timing tool.",
        "",
        "The history available from CNN is short and begins with synthetic neutral "
        "placeholders. The analysis starts on January 22, 2021, excluding 90 "
        "pre-cutoff rows, including 83 exact-50 observations. Conclusions are "
        "therefore less robust than studies based on several complete cycles.",
        "",
        "## Latest reading",
        "",
        f"- Date: **{report['reading_date']}**",
        f"- Score: **{sentiment['score']:.1f} / 100**",
        f"- CNN rating: **{sentiment['rating']}**",
        f"- Historical percentile: **{sentiment['historical_percentile']:.0%}**",
        f"- Interpretation: **{sentiment['contrarian_interpretation']}**",
        "",
        "## Model estimates",
        "",
        "| Horizon | Predicted return | 10-90% range | Probability positive | "
        "Analog median | Analog positive rate | Validation skill |",
        "|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for item in report["predictions"]:
        lines.append(
            f"| {item['horizon_trading_days']} trading days | "
            f"{pct(item['predicted_return'])} | "
            f"{pct(item['interval_10'])} to {pct(item['interval_90'])} | "
            f"{item['probability_positive']:.0%} | "
            f"{pct(item['analog_median_return'])} | "
            f"{item['analog_positive_rate']:.0%} | "
            f"{pct(item['mae_skill'])} |"
        )
    lines.extend(
        [
            "",
            "Validation skill is `1 - model MAE / historical-mean baseline MAE`. "
            "Near-zero or negative skill means the score does not add a reliable "
            "forecasting edge in the held-out period.",
            "",
            "The positive lower bound shown for 126 trading days should not be "
            "treated as strong evidence: that model has negative validation skill "
            "and its held-out period occurred within a limited market sample.",
            "",
            "## Historical reference",
            "",
            f"- Mean score: {historical['score_distribution']['mean']:.1f}",
            f"- Median score: {historical['score_distribution']['median']:.1f}",
            f"- 10th/90th percentile: "
            f"{historical['score_distribution']['p10']:.1f} / "
            f"{historical['score_distribution']['p90']:.1f}",
            "",
            "### Unconditional S&P 500 outcomes",
            "",
            "| Horizon | Mean return | Median return | Positive rate | "
            "10-90% range | Score correlation |",
            "|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for item in historical["forward_return_baselines"]:
        lines.append(
            f"| {item['horizon_trading_days']} days | "
            f"{pct(item['mean_return'])} | {pct(item['median_return'])} | "
            f"{item['positive_rate']:.0%} | {pct(item['p10'])} to "
            f"{pct(item['p90'])} | {item['score_return_correlation']:+.3f} |"
        )
    lines.extend(
        [
            "",
            "### Outcomes by CNN rating",
            "",
            "| Rating | Observations | 1-day median | 5-day median | "
            "20-day median | 63-day median | 126-day median |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for regime in historical["rating_regimes"]:
        values = {
            item["horizon_trading_days"]: item
            for item in regime["forward_returns"]
        }
        lines.append(
            f"| {regime['rating']} | {regime['observations']} | "
            f"{pct(values[1]['median_return'])} | "
            f"{pct(values[5]['median_return'])} | "
            f"{pct(values[20]['median_return'])} | "
            f"{pct(values[63]['median_return'])} | "
            f"{pct(values[126]['median_return'])} |"
        )
    lines.extend(
        [
            "",
            "## How to use this knowledge",
            "",
            "1. Use extreme fear as a contrarian-positive context signal, mainly "
            "for multi-week or multi-month horizons rather than the next session.",
            "2. Use extreme greed as a caution flag, not an automatic short signal.",
            "3. Distinguish level from direction: a low but rising score can describe "
            "a different regime from a low and still-falling score.",
            "4. Require confirmation from trend, breadth, volatility, credit, "
            "liquidity, positioning, and macro conditions.",
            "5. Always carry the uncertainty range and validation skill into any "
            "downstream system using the point estimate.",
            "6. Refresh the history before reuse because CNN may revise both current "
            "and historical values.",
            "",
            "## Methodology",
            "",
            "- CNN's chart endpoint supplies both daily index scores and aligned "
            "S&P 500 closes.",
            "- Duplicate dates are reduced to the last observation.",
            "- Two long early runs fixed at exactly 50 are treated as placeholders.",
            "- Forward close-to-close returns use 1, 5, 20, 63, and 126 trading days.",
            "- A nonlinear ridge model uses score level, distance from neutral, "
            "squared score, and cubic score.",
            "- Hyperparameters and final evaluation use chronological splits with "
            "a horizon gap to reduce overlap leakage.",
            "- Prediction ranges use held-out residuals; analogs use the 50 nearest "
            "historical scores.",
            "",
            "## Limitations",
            "",
            "- Usable history begins in 2021 and does not span many full market cycles.",
            "- Forward returns overlap, particularly at 63 and 126 trading days.",
            "- The index embeds market-price and volatility inputs, so association "
            "with subsequent returns is not independent of recent price action.",
            "- CNN can change methodology, category thresholds, endpoint structure, "
            "or historical values without notice.",
            "- Historical residual ranges are not guaranteed future bounds.",
            "- Results exclude costs, taxes, execution constraints, and live timing.",
            "",
            "## Refresh",
            "",
            "```powershell",
            r".\venv\Scripts\python.exe WebScraping\Fear_and_Greed\download_history.py",
            r".\venv\Scripts\python.exe WebScraping\Fear_and_Greed\generate_findings.py",
            "```",
            "",
            "Structured knowledge is stored in `fear_greed_knowledge.json`.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> None:
    raw_frame = pd.read_csv(HISTORY, parse_dates=["Date"])
    frame = load_history(HISTORY)
    excluded = raw_frame[raw_frame["Date"] < frame["Date"].min()]
    knowledge = {
        "schema_version": 1,
        "sources": [
            "https://edition.cnn.com/markets/fear-and-greed",
            "https://production.dataviz.cnn.io/index/fearandgreed/graphdata/",
        ],
        "purpose": (
            "Reusable knowledge about CNN Fear & Greed readings and subsequent "
            "S&P 500 performance."
        ),
        "data_quality": {
            "raw_history_start": "2020-09-14",
            "usable_history_start": frame["Date"].min().date().isoformat(),
            "excluded_pre_cutoff_rows": int(len(excluded)),
            "excluded_exact_50_rows": int(
                excluded["Fear_Greed_Score"].eq(50.0).sum()
            ),
            "placeholder_rule": (
                "Exclude history through the last initial run of at least 10 "
                "consecutive exact-neutral scores of 50."
            ),
        },
        "latest_report": build_report(HISTORY),
        "historical_findings": build_historical_findings(frame),
        "usage_guidance": {
            "primary_use": "market context and contrarian confirmation",
            "not_recommended_as": "standalone trading or market-timing signal",
            "preferred_horizons_trading_days": [20, 63, 126],
            "combine_with": [
                "price trend",
                "market breadth",
                "volatility",
                "credit conditions",
                "liquidity",
                "positioning",
                "macro regime",
            ],
        },
    }
    JSON_OUTPUT.write_text(
        json.dumps(knowledge, indent=2) + "\n", encoding="utf-8"
    )
    MARKDOWN_OUTPUT.write_text(render_markdown(knowledge), encoding="utf-8")
    print(f"Wrote {MARKDOWN_OUTPUT}")
    print(f"Wrote {JSON_OUTPUT}")


if __name__ == "__main__":
    main()
