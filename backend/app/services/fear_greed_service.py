from __future__ import annotations

from datetime import date, datetime, timezone
import json
import logging
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional
from urllib.request import Request, urlopen


logger = logging.getLogger("app.fear_greed")

CNN_PAGE_URL = "https://edition.cnn.com/markets/fear-and-greed"
CNN_API_URL = "https://production.dataviz.cnn.io/index/fearandgreed/graphdata/{start_date}"
KNOWLEDGE_PATH = (
    Path(__file__).resolve().parents[3]
    / "ref"
    / "Fear_and_Greed"
    / "fear_greed_knowledge.json"
)


def classify_fear_greed(score: float) -> str:
    if not 0 <= score <= 100:
        raise ValueError("Fear & Greed score must be between 0 and 100")
    if score < 25:
        return "extreme fear"
    if score < 45:
        return "fear"
    if score <= 55:
        return "neutral"
    if score <= 75:
        return "greed"
    return "extreme greed"


def parse_cnn_fear_greed(payload: Dict[str, Any]) -> Dict[str, Any]:
    current = payload.get("fear_and_greed")
    if not isinstance(current, dict):
        raise ValueError("CNN response did not contain fear_and_greed")
    score = float(current["score"])
    timestamp = datetime.fromisoformat(str(current["timestamp"]).replace("Z", "+00:00"))
    return {
        "reading_date": timestamp.date().isoformat(),
        "score": score,
        "rating": str(current.get("rating") or classify_fear_greed(score)).lower(),
        "previous_close": float(current["previous_close"]) if current.get("previous_close") is not None else None,
        "previous_1_week": float(current["previous_1_week"]) if current.get("previous_1_week") is not None else None,
        "previous_1_month": float(current["previous_1_month"]) if current.get("previous_1_month") is not None else None,
        "previous_1_year": float(current["previous_1_year"]) if current.get("previous_1_year") is not None else None,
    }


def _fetch_payload() -> Dict[str, Any]:
    start_date = (datetime.now(timezone.utc).date().replace(day=1)).isoformat()
    request = Request(
        CNN_API_URL.format(start_date=start_date),
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 Chrome/137.0.0.0 Safari/537.36"
            ),
            "Referer": CNN_PAGE_URL,
            "Origin": "https://edition.cnn.com",
            "Accept": "application/json, text/plain, */*",
        },
    )
    with urlopen(request, timeout=10) as response:
        return json.load(response)


def _matching_rating(score: float, regimes: List[Dict[str, Any]]) -> Dict[str, Any]:
    return min(
        regimes,
        key=lambda item: 0.0
        if float(item["score_min"]) <= score <= float(item["score_max"])
        else min(
            abs(score - float(item["score_min"])),
            abs(score - float(item["score_max"])),
        ),
    )


class FearGreedService:
    def __init__(
        self,
        fetcher: Optional[Callable[[], Dict[str, Any]]] = None,
        knowledge_path: Path = KNOWLEDGE_PATH,
    ):
        self.fetcher = fetcher or _fetch_payload
        self.knowledge_path = knowledge_path

    def get_insight(self, as_of: date) -> Dict[str, Any]:
        knowledge = json.loads(self.knowledge_path.read_text(encoding="utf-8"))
        local_report = knowledge["latest_report"]
        local_sentiment = local_report["sentiment"]
        local = {
            "source": "local",
            "reading_date": local_report["reading_date"],
            "score": float(local_sentiment["score"]),
            "rating": str(local_sentiment["rating"]).lower(),
            "previous_close": None,
            "previous_1_week": None,
            "previous_1_month": None,
            "previous_1_year": None,
        }

        live = None
        fetch_error = None
        try:
            live = parse_cnn_fear_greed(self.fetcher())
            live["source"] = "live"
        except Exception as exc:
            fetch_error = str(exc)
            logger.warning("CNN Fear & Greed live refresh failed: %s", exc)

        eligible = [
            reading
            for reading in (local, live)
            if reading and date.fromisoformat(reading["reading_date"]) <= as_of
        ]
        if not eligible:
            return {
                "available": False,
                "reading_date": None,
                "source_url": CNN_PAGE_URL,
                "source_status": "no Fear & Greed reading available on or before requested date",
                "fetch_error": fetch_error,
                "warning": "Historical dates before the local modeled report are not inferred.",
            }

        selected = max(
            eligible,
            key=lambda item: (
                item["reading_date"],
                1 if item.get("source") == "live" else 0,
            ),
        )
        score = float(selected["score"])
        rating = classify_fear_greed(score)
        historical = knowledge["historical_findings"]
        distribution = historical["score_distribution"]
        if score <= float(distribution["p10"]):
            percentile = 10.0
        elif score <= float(distribution["p25"]):
            percentile = 25.0
        elif score >= float(distribution["p90"]):
            percentile = 90.0
        elif score >= float(distribution["p75"]):
            percentile = 75.0
        else:
            percentile = 50.0

        if selected["reading_date"] == local_report["reading_date"] and score == float(
            local_sentiment["score"]
        ):
            predictions = [
                {**item, "method": "nonlinear ridge model and historical analogs"}
                for item in local_report["predictions"]
            ]
        else:
            matched = _matching_rating(score, historical["rating_regimes"])
            baselines = {
                int(item["horizon_trading_days"]): item
                for item in historical["forward_return_baselines"]
            }
            predictions = []
            for result in matched["forward_returns"]:
                horizon = int(result["horizon_trading_days"])
                baseline = baselines[horizon]
                predictions.append(
                    {
                        "horizon_trading_days": horizon,
                        "predicted_return": float(result["median_return"]),
                        "interval_10": float(baseline["p10"]),
                        "interval_90": float(baseline["p90"]),
                        "probability_positive": float(result["positive_rate"]),
                        "analog_median_return": float(result["median_return"]),
                        "analog_positive_rate": float(result["positive_rate"]),
                        "mae_skill": None,
                        "method": f"historical CNN rating: {matched['rating']}",
                    }
                )

        if score < 25:
            contrarian_score = 72.0
            insight = (
                "Extreme fear has historically been contrarian-positive mainly over "
                "20-63 trading days. It does not confirm that an SPX bottom is already in."
            )
        elif score < 45:
            contrarian_score = 62.0
            insight = (
                "Fear is a modest contrarian-positive SPX context. Confirmation from "
                "trend, breadth and volatility remains important."
            )
        elif score > 75:
            contrarian_score = 35.0
            insight = (
                "Extreme greed is a caution flag for SPX risk/reward, not an automatic "
                "short signal."
            )
        elif score > 55:
            contrarian_score = 44.0
            insight = (
                "Greed suggests less attractive contrarian SPX risk/reward, while trend "
                "can continue to dominate."
            )
        else:
            contrarian_score = 50.0
            insight = "Fear & Greed is neutral and adds little independent directional information."

        return {
            "available": True,
            "reading_date": selected["reading_date"],
            "score": round(score, 1),
            "rating": rating,
            "contrarian_score": contrarian_score,
            "historical_percentile": percentile,
            "previous_close": selected.get("previous_close"),
            "previous_1_week": selected.get("previous_1_week"),
            "previous_1_month": selected.get("previous_1_month"),
            "previous_1_year": selected.get("previous_1_year"),
            "insight": insight,
            "predictions": predictions,
            "preferred_horizon_trading_days": 63,
            "source_url": CNN_PAGE_URL,
            "source_status": (
                "live CNN data"
                if selected.get("source") == "live"
                else "local CNN research is newer than live data"
                if live and local["reading_date"] > live["reading_date"]
                else "local CNN research fallback"
            ),
            "live_reading_date": live["reading_date"] if live else None,
            "fetch_error": fetch_error,
            "warning": (
                "CNN history is short and begins in 2021. Use Fear & Greed as coincident "
                "and contrarian context, not a standalone timing signal."
            ),
        }
