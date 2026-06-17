from __future__ import annotations

from datetime import date, datetime
from html import unescape
import json
import logging
from pathlib import Path
import re
from typing import Any, Callable, Dict, List, Optional, Tuple
from urllib.request import Request, urlopen


logger = logging.getLogger("app.aaii_sentiment")

AAII_RESULTS_URL = "https://www.aaii.com/sentimentsurvey/sent_results"
KNOWLEDGE_PATH = (
    Path(__file__).resolve().parents[3]
    / "ref"
    / "aaii_sentiment"
    / "aaii_sentiment_knowledge.json"
)

_ROW_PATTERN = re.compile(
    r"\b("
    r"Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec"
    r")\s+(\d{1,2})\s+"
    r"(\d+(?:\.\d+)?)%\s+"
    r"(\d+(?:\.\d+)?)%\s+"
    r"(\d+(?:\.\d+)?)%",
    re.IGNORECASE,
)


def _strip_html(value: str) -> str:
    text = re.sub(r"<script\b[^>]*>.*?</script>", " ", value, flags=re.IGNORECASE | re.DOTALL)
    text = re.sub(r"<style\b[^>]*>.*?</style>", " ", text, flags=re.IGNORECASE | re.DOTALL)
    text = re.sub(r"<[^>]+>", " ", text)
    return re.sub(r"\s+", " ", unescape(text)).strip()


def _infer_reported_date(month: str, day: int, today: date) -> date:
    parsed = datetime.strptime(f"{month[:3].title()} {day}", "%b %d")
    candidate = date(today.year, parsed.month, parsed.day)
    if candidate > today:
        candidate = date(today.year - 1, parsed.month, parsed.day)
    return candidate


def parse_latest_aaii_reading(html: str, today: date) -> Dict[str, Any]:
    text = _strip_html(html)
    match = _ROW_PATTERN.search(text)
    if not match:
        raise ValueError("AAII sentiment table was not found in the response")

    reading_date = _infer_reported_date(match.group(1), int(match.group(2)), today)
    values = [float(match.group(index)) / 100.0 for index in (3, 4, 5)]
    total = sum(values)
    if not 0.97 <= total <= 1.03:
        raise ValueError(f"AAII percentages total {total:.3f}, expected approximately 1.0")
    bullish, neutral, bearish = (value / total for value in values)
    return {
        "reading_date": reading_date.isoformat(),
        "bullish": bullish,
        "neutral": neutral,
        "bearish": bearish,
    }


def _fetch_html() -> str:
    request = Request(
        AAII_RESULTS_URL,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 Chrome/124.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml",
        },
    )
    with urlopen(request, timeout=8) as response:
        return response.read().decode(response.headers.get_content_charset() or "utf-8")


def _sentiment_regime(spread: float, historical: Dict[str, Any]) -> Tuple[str, float]:
    distribution = historical["sentiment_distribution"]
    p10 = float(distribution["bull_bear_spread_p10"])
    p25 = float(distribution["bull_bear_spread_p25"])
    p75 = float(distribution["bull_bear_spread_p75"])
    p90 = float(distribution["bull_bear_spread_p90"])
    if spread <= p10:
        return "EXTREME BEARISH / CONTRARIAN POSITIVE", 0.10
    if spread <= p25:
        return "BEARISH / CONTRARIAN SUPPORTIVE", 0.25
    if spread >= p90:
        return "EXTREME BULLISH / CONTRARIAN CAUTIOUS", 0.90
    if spread >= p75:
        return "BULLISH / CONTRARIAN CAUTIOUS", 0.75
    return "NEUTRAL SENTIMENT", 0.50


def _matching_spread_regime(
    spread: float, regimes: List[Dict[str, Any]]
) -> Dict[str, Any]:
    for regime in regimes:
        if float(regime["spread_min"]) <= spread <= float(regime["spread_max"]):
            return regime
    return min(
        regimes,
        key=lambda item: min(
            abs(spread - float(item["spread_min"])),
            abs(spread - float(item["spread_max"])),
        ),
    )


class AAIISentimentService:
    def __init__(
        self,
        fetcher: Optional[Callable[[], str]] = None,
        knowledge_path: Path = KNOWLEDGE_PATH,
    ):
        self.fetcher = fetcher or _fetch_html
        self.knowledge_path = knowledge_path

    def _load_knowledge(self) -> Dict[str, Any]:
        return json.loads(self.knowledge_path.read_text(encoding="utf-8"))

    def get_insight(self, as_of: date) -> Dict[str, Any]:
        knowledge = self._load_knowledge()
        local_report = knowledge["latest_report"]
        local_sentiment = local_report["sentiment"]
        local_reading = {
            "reading_date": local_report["reading_date"],
            "bullish": float(local_sentiment["bullish"]),
            "neutral": float(local_sentiment["neutral"]),
            "bearish": float(local_sentiment["bearish"]),
        }

        live_reading = None
        fetch_error = None
        try:
            live_reading = parse_latest_aaii_reading(self.fetcher(), date.today())
        except Exception as exc:
            fetch_error = str(exc)
            logger.warning("AAII live refresh failed: %s", exc)

        eligible = [
            reading
            for reading in (local_reading, live_reading)
            if reading and date.fromisoformat(reading["reading_date"]) <= as_of
        ]
        if not eligible:
            return {
                "available": False,
                "reading_date": None,
                "source_url": AAII_RESULTS_URL,
                "source_status": "no AAII reading available on or before requested date",
                "live_reading_date": live_reading["reading_date"] if live_reading else None,
                "fetch_error": fetch_error,
                "warning": (
                    "The local AAII package contains only its latest modeled report; "
                    "historical dashboard dates before that report are not inferred."
                ),
            }

        selected = max(eligible, key=lambda item: item["reading_date"])
        selected_is_live = live_reading is not None and selected is live_reading

        bullish = float(selected["bullish"])
        neutral = float(selected["neutral"])
        bearish = float(selected["bearish"])
        spread = bullish - bearish
        historical = knowledge["historical_findings"]
        regime, percentile = _sentiment_regime(spread, historical)

        if selected["reading_date"] == local_report["reading_date"]:
            predictions = [
                {
                    **prediction,
                    "method": "ridge model and historical analogs",
                }
                for prediction in local_report["predictions"]
            ]
        else:
            matched = _matching_spread_regime(spread, historical["spread_regimes"])
            baselines = {
                int(item["horizon_weeks"]): item
                for item in historical["forward_return_baselines"]
            }
            predictions = []
            for result in matched["forward_returns"]:
                horizon = int(result["horizon_weeks"])
                baseline = baselines[horizon]
                predictions.append(
                    {
                        "horizon_weeks": horizon,
                        "predicted_return": float(result["median_return"]),
                        "interval_10": float(baseline["p10"]),
                        "interval_90": float(baseline["p90"]),
                        "probability_positive": float(result["positive_rate"]),
                        "analog_median_return": float(result["median_return"]),
                        "analog_positive_rate": float(result["positive_rate"]),
                        "mae_skill": None,
                        "method": f"historical spread regime: {matched['label']}",
                    }
                )

        preferred = next(
            item for item in predictions if int(item["horizon_weeks"]) == 13
        )
        if spread <= float(
            historical["sentiment_distribution"]["bull_bear_spread_p10"]
        ):
            insight = (
                "Retail sentiment is extremely bearish. Historically this has been "
                "modestly supportive for SPX over 13-26 weeks, but not a reliable "
                "near-term bottom signal."
            )
            score = 68.0
        elif spread >= float(
            historical["sentiment_distribution"]["bull_bear_spread_p90"]
        ):
            insight = (
                "Retail sentiment is extremely bullish. Treat this as a medium-term "
                "caution flag, not an automatic SPX sell signal."
            )
            score = 38.0
        else:
            insight = (
                "AAII sentiment is not at a strong contrarian extreme. Trend, breadth "
                "and volatility should carry more weight."
            )
            score = 50.0

        return {
            "available": True,
            "score": score,
            "reading_date": selected["reading_date"],
            "bullish": round(bullish * 100, 1),
            "neutral": round(neutral * 100, 1),
            "bearish": round(bearish * 100, 1),
            "bull_bear_spread": round(spread * 100, 1),
            "historical_percentile": round(percentile * 100, 0),
            "regime": regime,
            "insight": insight,
            "preferred_horizon_weeks": 13,
            "preferred_prediction": preferred,
            "predictions": predictions,
            "source_url": AAII_RESULTS_URL,
            "source_status": (
                "live AAII page"
                if selected_is_live
                else "local AAII workbook is newer than the live page"
                if live_reading
                and local_reading["reading_date"] > live_reading["reading_date"]
                else "local modeled reading aligned with live AAII page"
                if live_reading
                else "local AAII workbook fallback"
            ),
            "live_reading_date": live_reading["reading_date"] if live_reading else None,
            "fetch_error": fetch_error,
            "warning": (
                "AAII sentiment has weak and time-varying forecasting skill. "
                "Use it as contrarian context, not a standalone timing signal."
            ),
        }
