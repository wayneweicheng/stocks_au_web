"""Generate reusable AAII sentiment findings in Markdown and JSON."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from model_aaii_spx import HORIZONS, build_report, load_sentiment


ROOT = Path(__file__).resolve().parent
WORKBOOK = ROOT / "sentiment.xls"
JSON_OUTPUT = ROOT / "aaii_sentiment_knowledge.json"
MARKDOWN_OUTPUT = ROOT / "FINDINGS.md"


def pct(value: float, digits: int = 1) -> str:
    return f"{value:+.{digits}%}"


def build_historical_findings(frame):
    spread = frame["Bullish"] - frame["Bearish"]
    findings = {
        "sentiment_distribution": {
            "bullish_mean": float(frame["Bullish"].mean()),
            "bullish_median": float(frame["Bullish"].median()),
            "neutral_mean": float(frame["Neutral"].mean()),
            "neutral_median": float(frame["Neutral"].median()),
            "bearish_mean": float(frame["Bearish"].mean()),
            "bearish_median": float(frame["Bearish"].median()),
            "bull_bear_spread_mean": float(spread.mean()),
            "bull_bear_spread_median": float(spread.median()),
            "bull_bear_spread_p10": float(spread.quantile(0.10)),
            "bull_bear_spread_p25": float(spread.quantile(0.25)),
            "bull_bear_spread_p75": float(spread.quantile(0.75)),
            "bull_bear_spread_p90": float(spread.quantile(0.90)),
        },
        "forward_return_baselines": [],
        "spread_regimes": [],
    }

    for horizon in HORIZONS:
        returns = frame["SPX_Close"].shift(-horizon) / frame["SPX_Close"] - 1
        valid = returns.notna()
        values = returns[valid]
        findings["forward_return_baselines"].append(
            {
                "horizon_weeks": horizon,
                "observations": int(valid.sum()),
                "mean_return": float(values.mean()),
                "median_return": float(values.median()),
                "positive_rate": float((values > 0).mean()),
                "p10": float(values.quantile(0.10)),
                "p90": float(values.quantile(0.90)),
                "spread_return_correlation": float(
                    np.corrcoef(spread[valid], values)[0, 1]
                ),
            }
        )

    labels = [
        "most bearish 20%",
        "bearish 20-40%",
        "middle 20%",
        "bullish 60-80%",
        "most bullish 20%",
    ]
    bins = np.quantile(spread, [0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
    bins[0] -= 1e-12
    bins[-1] += 1e-12
    for index, label in enumerate(labels):
        in_regime = (spread > bins[index]) & (spread <= bins[index + 1])
        regime = {
            "label": label,
            "spread_min": float(spread[in_regime].min()),
            "spread_max": float(spread[in_regime].max()),
            "observations": int(in_regime.sum()),
            "forward_returns": [],
        }
        for horizon in HORIZONS:
            returns = frame["SPX_Close"].shift(-horizon) / frame["SPX_Close"] - 1
            values = returns[in_regime & returns.notna()]
            regime["forward_returns"].append(
                {
                    "horizon_weeks": horizon,
                    "mean_return": float(values.mean()),
                    "median_return": float(values.median()),
                    "positive_rate": float((values > 0).mean()),
                }
            )
        findings["spread_regimes"].append(regime)
    return findings


def render_markdown(knowledge: dict) -> str:
    report = knowledge["latest_report"]
    sentiment = report["sentiment"]
    historical = knowledge["historical_findings"]
    distribution = historical["sentiment_distribution"]

    lines = [
        "# AAII Sentiment and S&P 500 Findings",
        "",
        f"Generated from `{knowledge['source_file']}` using "
        f"{report['observations']:,} valid weekly observations from "
        f"{report['history_start']} through {report['history_end']}.",
        "",
        "## Executive conclusion",
        "",
        "AAII sentiment is best used as a market-context and contrarian input, "
        "not as a standalone S&P 500 timing model. Very bearish readings have "
        "historically been followed by somewhat stronger returns, especially "
        "over multi-month horizons, but the relationship is noisy and unstable.",
        "",
        "The fitted model has approximately zero improvement over a simple "
        "historical-average return forecast on held-out data. Its point estimates "
        "must therefore be read together with the wide prediction ranges, nearest "
        "historical analogs, and other market evidence.",
        "",
        "## Latest reading",
        "",
        f"- Date: **{report['reading_date']}**",
        f"- Bullish: **{sentiment['bullish']:.1%}**",
        f"- Neutral: **{sentiment['neutral']:.1%}**",
        f"- Bearish: **{sentiment['bearish']:.1%}**",
        f"- Bull-bear spread: **{pct(sentiment['bull_bear_spread'])}**",
        f"- Historical percentile: **{sentiment['spread_historical_percentile']:.0%}**",
        f"- Classification: **{sentiment['regime']}**",
        "",
        "Interpretation: the reading is near the most bearish 10% of the full "
        "history. Historically this has been a contrarian-positive condition, "
        "but it does not imply that the S&P 500 must rise immediately.",
        "",
        "## Model estimates",
        "",
        "| Horizon | Predicted return | 10-90% range | Probability positive | "
        "Analog median | Analog positive rate | Validation skill |",
        "|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for item in report["predictions"]:
        horizon_label = (
            "1 week"
            if item["horizon_weeks"] == 1
            else f"{item['horizon_weeks']} weeks"
        )
        lines.append(
            f"| {horizon_label} | "
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
            "Validation skill is `1 - model MAE / baseline MAE`. Zero means the "
            "model merely matches the historical-average forecast; negative values "
            "mean it performs worse. The latest results show no meaningful edge.",
            "",
            "## Historical reference",
            "",
            f"- Average bullish share: {distribution['bullish_mean']:.1%}",
            f"- Average neutral share: {distribution['neutral_mean']:.1%}",
            f"- Average bearish share: {distribution['bearish_mean']:.1%}",
            f"- Average bull-bear spread: "
            f"{pct(distribution['bull_bear_spread_mean'])}",
            f"- 10th/90th percentile spread: "
            f"{pct(distribution['bull_bear_spread_p10'])} / "
            f"{pct(distribution['bull_bear_spread_p90'])}",
            "",
            "### Unconditional S&P 500 outcomes",
            "",
            "| Horizon | Mean return | Median return | Positive rate | "
            "10-90% range | Spread correlation |",
            "|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for item in historical["forward_return_baselines"]:
        horizon_label = (
            "1 week"
            if item["horizon_weeks"] == 1
            else f"{item['horizon_weeks']} weeks"
        )
        lines.append(
            f"| {horizon_label} | {pct(item['mean_return'])} | "
            f"{pct(item['median_return'])} | {item['positive_rate']:.0%} | "
            f"{pct(item['p10'])} to {pct(item['p90'])} | "
            f"{item['spread_return_correlation']:+.3f} |"
        )

    lines.extend(
        [
            "",
            "A negative spread correlation is consistent with the contrarian "
            "interpretation: more bullish sentiment tends to precede slightly "
            "weaker returns. Correlation remains small, so sentiment explains only "
            "a limited part of subsequent market variation.",
            "",
            "### Bull-bear spread regimes",
            "",
            "| Sentiment regime | Spread range | 1-week median | 4-week median | "
            "13-week median | 26-week median |",
            "|---|---:|---:|---:|---:|---:|",
        ]
    )
    for regime in historical["spread_regimes"]:
        returns = {
            item["horizon_weeks"]: item
            for item in regime["forward_returns"]
        }
        lines.append(
            f"| {regime['label']} | {pct(regime['spread_min'])} to "
            f"{pct(regime['spread_max'])} | "
            f"{pct(returns[1]['median_return'])} | "
            f"{pct(returns[4]['median_return'])} | "
            f"{pct(returns[13]['median_return'])} | "
            f"{pct(returns[26]['median_return'])} |"
        )

    lines.extend(
        [
            "",
            "## How to use this knowledge",
            "",
            "1. Treat extreme bearish sentiment as a modest contrarian-positive "
            "context signal, strongest conceptually over 13-26 weeks.",
            "2. Treat extreme bullish sentiment as a reason for caution, not an "
            "automatic sell signal.",
            "3. Never use the point forecast without its prediction range. A "
            "positive estimate can still have a materially negative lower bound.",
            "4. Combine sentiment with trend, breadth, volatility, liquidity, "
            "credit conditions, positioning, valuation, and macro regime.",
            "5. Prefer changes and persistence in sentiment over one isolated "
            "weekly observation when building a larger decision system.",
            "6. Re-run the generator after replacing `sentiment.xls`; do not assume "
            "that these exact numbers remain current.",
            "",
            "## Methodology",
            "",
            "- Inputs: weekly bullish, neutral, and bearish AAII shares.",
            "- Targets: forward S&P 500 close-to-close returns at 1, 4, 13, and "
            "26 weeks.",
            "- Features: sentiment shares, bull-bear spread, absolute spread, "
            "squared bullish/bearish terms, and bullish-bearish interaction.",
            "- Model: standardized ridge regression implemented with NumPy.",
            "- Validation: chronological tuning and final held-out evaluation, "
            "with a horizon gap to reduce target leakage from overlapping returns.",
            "- Uncertainty: 10th and 90th percentiles of held-out residuals.",
            "- Analogs: 50 closest historical readings after standardizing the "
            "three sentiment shares.",
            "",
            "## Limitations",
            "",
            "- This is observational association, not causal evidence.",
            "- Forward-return observations overlap, especially at 13 and 26 weeks.",
            "- Market structure and survey behavior can change across decades.",
            "- The S&P 500 has a positive long-run drift, which drives much of the "
            "reported probability of positive returns.",
            "- Prediction intervals describe historical model errors and are not "
            "guaranteed bounds.",
            "- Survey publication timing and the workbook's weekly close alignment "
            "may not match a live trading implementation exactly.",
            "- Results exclude transaction costs, taxes, and execution constraints.",
            "",
            "## Rebuild",
            "",
            "```powershell",
            r".\venv\Scripts\python.exe WebScraping\aaii_sentiment\generate_findings.py",
            "```",
            "",
            "The structured version of these findings is stored in "
            "`aaii_sentiment_knowledge.json` for use by other systems.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> None:
    frame = load_sentiment(WORKBOOK)
    latest_report = build_report(WORKBOOK)
    knowledge = {
        "schema_version": 1,
        "source_file": WORKBOOK.name,
        "purpose": (
            "Reusable knowledge about AAII sentiment and subsequent S&P 500 "
            "performance."
        ),
        "latest_report": latest_report,
        "historical_findings": build_historical_findings(frame),
        "usage_guidance": {
            "primary_use": "market context and contrarian confirmation",
            "not_recommended_as": "standalone trading or market-timing signal",
            "preferred_horizons_weeks": [13, 26],
            "combine_with": [
                "price trend",
                "market breadth",
                "volatility",
                "liquidity",
                "credit conditions",
                "positioning",
                "valuation",
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
