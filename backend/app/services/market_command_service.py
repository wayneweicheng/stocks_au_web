from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime
from typing import Any, Dict, Iterable, List, Optional, Tuple
import logging
import math

from app.core.db import get_sql_model


logger = logging.getLogger("app.market_command")


def _number(value: Any) -> Optional[float]:
    try:
        result = float(value)
        return result if math.isfinite(result) else None
    except (TypeError, ValueError):
        return None


def _clamp(value: float, minimum: float = 0.0, maximum: float = 100.0) -> float:
    return max(minimum, min(maximum, value))


def _iso(value: Any) -> Optional[str]:
    if value is None:
        return None
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _normalize_symbol(value: Any, market: str) -> str:
    symbol = str(value or "").strip().upper()
    if market == "US" and symbol.endswith(".US"):
        return symbol[:-3]
    if market == "ASX" and symbol.endswith(".AX"):
        return symbol[:-3]
    return symbol


def _regime_label(score: float) -> str:
    if score >= 62:
        return "BULLISH"
    if score <= 38:
        return "BEARISH"
    return "NEUTRAL"


def _direction_from_text(value: Any) -> str:
    text = str(value or "").upper()
    if any(token in text for token in ("STRONGLY_BULLISH", "BULLISH", "SWING UP", "BUY", "LONG")):
        return "BULLISH"
    if any(token in text for token in ("STRONGLY_BEARISH", "BEARISH", "SWING DOWN", "SELL", "SHORT")):
        return "BEARISH"
    return "NEUTRAL"


def _signal_strength(value: Any) -> float:
    text = str(value or "").upper().replace(" ", "_")
    return {
        "STRONGLY_BULLISH": 92.0,
        "BULLISH": 75.0,
        "NEUTRAL": 50.0,
        "NOT_DETERMINED": 45.0,
        "BEARISH": 25.0,
        "STRONGLY_BEARISH": 8.0,
    }.get(text, 50.0)


def _interpolate_score(value: float, anchors: List[Tuple[float, float]]) -> float:
    value = _clamp(value, anchors[0][0], anchors[-1][0])
    for index in range(1, len(anchors)):
        upper_value, upper_score = anchors[index]
        lower_value, lower_score = anchors[index - 1]
        if value <= upper_value:
            position = (value - lower_value) / (upper_value - lower_value)
            return lower_score + position * (upper_score - lower_score)
    return anchors[-1][1]


def score_vix_regime(vix: float, bullish_structure: bool) -> Tuple[float, str]:
    if bullish_structure:
        score = _interpolate_score(
            vix,
            [
                (12.0, 68.0),
                (15.0, 78.0),
                (18.0, 72.0),
                (22.0, 44.0),
                (25.0, 35.0),
                (30.0, 65.0),
                (35.0, 78.0),
                (40.0, 85.0),
            ],
        )
        if vix < 18:
            phase = "bull-market grind"
        elif vix < 25:
            phase = "rising volatility"
        elif vix < 30:
            phase = "selloff / early bottoming"
        else:
            phase = "capitulation / bottoming"
    else:
        score = _interpolate_score(
            vix,
            [
                (12.0, 65.0),
                (18.0, 58.0),
                (22.0, 42.0),
                (25.0, 32.0),
                (30.0, 22.0),
                (35.0, 15.0),
                (40.0, 10.0),
            ],
        )
        phase = "elevated risk" if vix >= 25 else "weak-market volatility"
    return round(score, 1), phase


def analyze_us_breadth(row: Dict[str, Any]) -> Tuple[float, str, Dict[str, Any]]:
    equal_weight_change = _number(row.get("TodayAverageChange"))
    if equal_weight_change is None:
        equal_weight_change = _number(row.get("TodayValueChange"))
    spx_change = _number(row.get("TodayChange"))
    advancers = _number(row.get("NumAdv"))
    decliners = _number(row.get("NumDec"))
    above_sma50 = _number(row.get("PercentageAboveSMA50"))
    above_sma200 = _number(row.get("PercentageAboveSMA200"))

    participation = None
    if advancers is not None and decliners is not None and advancers + decliners > 0:
        participation = advancers / (advancers + decliners)

    leadership_gap = None
    if equal_weight_change is not None and spx_change is not None:
        leadership_gap = equal_weight_change - spx_change

    score_inputs: List[Tuple[float, float]] = []
    if participation is not None:
        score_inputs.append((participation * 100, 0.40))
    if equal_weight_change is not None:
        score_inputs.append((_clamp(50 + equal_weight_change * 20), 0.25))
    if leadership_gap is not None:
        score_inputs.append((_clamp(50 + leadership_gap * 20), 0.15))
    if above_sma50 is not None:
        score_inputs.append((_clamp(above_sma50), 0.12))
    if above_sma200 is not None:
        score_inputs.append((_clamp(above_sma200), 0.08))
    total_weight = sum(weight for _, weight in score_inputs)
    score = (
        sum(value * weight for value, weight in score_inputs) / total_weight
        if total_weight > 0
        else 50.0
    )

    if (
        spx_change is not None
        and spx_change > 0
        and (
            (equal_weight_change is not None and equal_weight_change < 0)
            or (participation is not None and participation < 0.40)
        )
    ):
        state = "NARROW ADVANCE"
        explanation = "SPX is up, but most stocks are not participating."
    elif (
        spx_change is not None
        and spx_change >= 0
        and leadership_gap is not None
        and leadership_gap <= -0.50
        and participation is not None
        and participation < 0.50
    ):
        state = "CAP-WEIGHT LEADERSHIP"
        explanation = "Large stocks are lifting SPX faster than the typical constituent."
    elif (
        spx_change is not None
        and spx_change < 0
        and equal_weight_change is not None
        and equal_weight_change > 0
        and participation is not None
        and participation >= 0.50
    ):
        state = "RESILIENT BREADTH"
        explanation = "The average stock is stronger than the headline index."
    elif (
        equal_weight_change is not None
        and equal_weight_change > 0
        and participation is not None
        and participation >= 0.60
    ):
        state = "BROAD ADVANCE"
        explanation = "Gains are supported by broad constituent participation."
    elif (
        equal_weight_change is not None
        and equal_weight_change < 0
        and participation is not None
        and participation <= 0.40
    ):
        state = "BROAD DECLINE"
        explanation = "Losses are widespread across SPX constituents."
    else:
        state = "MIXED BREADTH"
        explanation = "Participation and index direction are not strongly aligned."

    diagnostics = {
        "state": state,
        "explanation": explanation,
        "equal_weight_change": round(equal_weight_change, 2) if equal_weight_change is not None else None,
        "spx_change": round(spx_change, 2) if spx_change is not None else None,
        "leadership_gap": round(leadership_gap, 2) if leadership_gap is not None else None,
        "advancers": int(advancers) if advancers is not None else None,
        "decliners": int(decliners) if decliners is not None else None,
        "advance_percentage": round(participation * 100, 1) if participation is not None else None,
        "percentage_above_sma50": round(above_sma50, 1) if above_sma50 is not None else None,
        "percentage_above_sma200": round(above_sma200, 1) if above_sma200 is not None else None,
        "trend_as_of": _iso(row.get("TrendObservationDate")),
    }
    return round(_clamp(score), 1), f"{state}: {explanation}", diagnostics


def score_regime_components(components: Iterable[Dict[str, Any]]) -> Tuple[float, float]:
    usable = [
        component
        for component in components
        if component.get("available") and _number(component.get("score")) is not None
    ]
    if not usable:
        return 50.0, 0.0
    total_weight = sum(float(component.get("weight") or 0) for component in usable)
    if total_weight <= 0:
        return 50.0, 0.0
    score = sum(
        float(component["score"]) * float(component.get("weight") or 0)
        for component in usable
    ) / total_weight
    expected_weight = sum(float(component.get("weight") or 0) for component in components)
    coverage = total_weight / expected_weight if expected_weight > 0 else 0.0
    confidence = _clamp(coverage * (55 + abs(score - 50) * 0.9))
    return round(_clamp(score), 1), round(confidence, 1)


def rank_option_strategies(
    *,
    direction: str,
    opportunity_score: float,
    regime_label: str,
    market: str,
    gex_regime: Optional[str] = None,
) -> List[Dict[str, Any]]:
    direction = direction.upper()
    conviction = _clamp(abs(opportunity_score - 50) * 2)
    aligned = direction == regime_label
    positive_gex = gex_regime == "POSITIVE"
    negative_gex = gex_regime == "NEGATIVE"

    candidates: List[Tuple[str, float, str, List[str], List[str]]] = []
    if direction == "BULLISH":
        candidates.extend(
            [
                (
                    "BULL_CALL_SPREAD",
                    68 + conviction * 0.20 + (7 if aligned else -4),
                    "Defined-risk bullish exposure with a bounded upside target.",
                    ["Directional upside", "Defined maximum loss", "Less premium than a long call"],
                    ["Profit is capped", "Requires a liquid two-leg chain"],
                ),
                (
                    "LONG_CALL",
                    58 + conviction * 0.28 + (5 if negative_gex else 0),
                    "Convex upside exposure when a strong move is expected.",
                    ["Unlimited upside", "Defined premium risk"],
                    ["Time decay", "Can be expensive when implied volatility is high"],
                ),
                (
                    "CASH_SECURED_PUT",
                    66 + (8 if positive_gex else 0) + (5 if opportunity_score < 82 else -3),
                    "Income or discounted share entry for a moderately bullish view.",
                    ["Benefits from time decay", "Can enter shares below spot"],
                    ["Assignment requires cash for 100 shares", "Stock-like downside below breakeven"],
                ),
                (
                    "BULL_PUT_SPREAD",
                    64 + (8 if positive_gex else 0) + (4 if aligned else 0),
                    "Defined-risk premium selling when support is expected to hold.",
                    ["Positive theta", "Defined maximum loss"],
                    ["Loss can exceed credit", "Avoid ahead of unresolved binary events"],
                ),
            ]
        )
    elif direction == "BEARISH":
        candidates.extend(
            [
                (
                    "BEAR_PUT_SPREAD",
                    68 + conviction * 0.20 + (7 if aligned else -4),
                    "Defined-risk downside exposure with a bounded target.",
                    ["Directional downside", "Defined maximum loss", "Lower cost than a long put"],
                    ["Profit is capped", "Requires a liquid two-leg chain"],
                ),
                (
                    "LONG_PUT",
                    58 + conviction * 0.28 + (5 if negative_gex else 0),
                    "Convex downside protection or speculation for a sharp decline.",
                    ["Defined premium risk", "Benefits from a fast downside move"],
                    ["Time decay", "Volatility may already be expensive"],
                ),
                (
                    "BEAR_CALL_SPREAD",
                    64 + (6 if positive_gex else 0) + (4 if aligned else 0),
                    "Defined-risk premium selling when upside is expected to remain capped.",
                    ["Positive theta", "Defined maximum loss"],
                    ["Sharp rallies can create losses", "Avoid illiquid wings"],
                ),
            ]
        )
    else:
        candidates.extend(
            [
                (
                    "IRON_CONDOR",
                    72 + (10 if positive_gex else -8) + (5 if regime_label == "NEUTRAL" else -8),
                    "Defined-risk range trade for stable, mean-reverting conditions.",
                    ["Positive theta", "Wide configurable profit zone", "Defined maximum loss"],
                    ["Vulnerable to breakouts", "Four liquid legs are required"],
                ),
                (
                    "IRON_BUTTERFLY",
                    62 + (8 if positive_gex else -10) + (5 if regime_label == "NEUTRAL" else -8),
                    "Tighter range trade around a strong price magnet.",
                    ["Defined risk", "Higher credit than a comparable condor"],
                    ["Narrow profitable region", "Pin and expiration risk"],
                ),
            ]
        )

    if market != "US":
        return []

    ranked = sorted(candidates, key=lambda item: item[1], reverse=True)[:3]
    return [
        {
            "strategy": strategy,
            "suitability_score": round(_clamp(score), 1),
            "summary": summary,
            "reasons": reasons,
            "risks": risks,
            "requires_chain_validation": True,
        }
        for strategy, score, summary, reasons, risks in ranked
        if score >= 45
    ]


class MarketCommandService:
    def __init__(self, model: Any = None):
        self.model = model or get_sql_model()

    def _query(self, sql: str, params: tuple = ()) -> List[Dict[str, Any]]:
        try:
            return self.model.execute_read_query(sql, params) or []
        except Exception as exc:
            logger.warning("Market command query failed: %s", exc)
            return []

    def _component(
        self,
        name: str,
        weight: float,
        row: Optional[Dict[str, Any]],
        score: Optional[float],
        detail: str,
        source: str,
        diagnostics: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        return {
            "name": name,
            "weight": weight,
            "score": round(_clamp(score), 1) if score is not None else None,
            "available": row is not None and score is not None,
            "detail": detail,
            "source": source,
            "as_of": _iso(row.get("ObservationDate")) if row else None,
            "diagnostics": diagnostics,
        }

    def get_regime(self, observation_date: date, market: str) -> Dict[str, Any]:
        market = market.upper()
        return (
            self._get_us_regime(observation_date)
            if market == "US"
            else self._get_asx_regime(observation_date)
        )

    def _get_us_regime(self, observation_date: date) -> Dict[str, Any]:
        gex_rows = self._query(
            """
            SELECT TOP 1 *
            FROM StockDB_US.Analysis.GEX_Features
            WHERE UPPER(REPLACE(REPLACE(ASXCode, '.US', ''), '.AX', '')) IN ('SPXW', 'SPX', 'SPY')
              AND ObservationDate <= ?
            ORDER BY
                ObservationDate DESC,
                CASE UPPER(REPLACE(REPLACE(ASXCode, '.US', ''), '.AX', ''))
                    WHEN 'SPXW' THEN 0
                    WHEN 'SPX' THEN 1
                    ELSE 2
                END
            """,
            (observation_date,),
        )
        breadth_rows = self._query(
            """
            SELECT TOP 1
                lb.*,
                bl.NumAdv,
                bl.NumDec
            FROM StockDB_US.Transform.LeadingBreath AS lb
            LEFT JOIN StockDB_US.Transform.BreathLine AS bl
              ON lb.ObservationDate = bl.ObservationDate
            WHERE lb.ObservationDate <= ?
            ORDER BY lb.ObservationDate DESC
            """,
            (observation_date,),
        )
        breadth_trend_rows = self._query(
            """
            SELECT TOP 1
                ObservationDate AS TrendObservationDate,
                PercentageAboveSMA50,
                PercentageAboveSMA200
            FROM StockDB_US.StockData.SPX500Overview
            WHERE ObservationDate <= ?
            ORDER BY ObservationDate DESC
            """,
            (observation_date,),
        )
        clv_rows = self._query(
            """
            SELECT TOP 1 *
            FROM StockDB_US.Transform.MarketCLVTrend
            WHERE ObservationDate <= ?
            ORDER BY ObservationDate DESC, NumObservation DESC
            """,
            (observation_date,),
        )

        gex = gex_rows[0] if gex_rows else None
        breadth = breadth_rows[0] if breadth_rows else None
        if breadth and breadth_trend_rows:
            breadth = {**breadth, **breadth_trend_rows[0]}
        clv = clv_rows[0] if clv_rows else None

        trend_score = None
        if gex:
            trend_score = 50.0
            trend_score += 18 if _number(gex.get("Price_Above_SMA20")) == 1 else -12
            trend_score += 14 if _number(gex.get("Price_Above_SMA50")) == 1 else -10
            trend_score += 10 if _number(gex.get("SMA20_Above_SMA50")) == 1 else -8
            if _number(gex.get("Is_Swing_Up")) == 1:
                trend_score += 8
            if _number(gex.get("Is_Swing_Down")) == 1:
                trend_score -= 8

        breadth_score = None
        breadth_detail = "Unavailable"
        breadth_diagnostics = None
        if breadth:
            breadth_score, breadth_detail, breadth_diagnostics = analyze_us_breadth(breadth)

        vix = _number(gex.get("VIX")) if gex else None
        volatility_score = None
        volatility_detail = "Unavailable"
        if vix is not None:
            bullish_structure = (
                _number(gex.get("Price_Above_SMA50")) == 1
                and _number(gex.get("SMA20_Above_SMA50")) == 1
            )
            volatility_score, volatility_phase = score_vix_regime(vix, bullish_structure)
            volatility_detail = f"VIX {vix:.1f} - {volatility_phase}"

        gex_value = _number(gex.get("GEX")) if gex else None
        gex_score = None
        if gex_value is not None:
            gex_score = 65 if gex_value > 0 else 35
            if _number(gex.get("GEX_Turned_Positive")) == 1:
                gex_score += 12
            if _number(gex.get("GEX_Turned_Negative")) == 1:
                gex_score -= 12

        dark_pool_ratio = _number(gex.get("Stock_DarkPoolBuySellRatio")) if gex else None
        dark_pool_score = None
        if dark_pool_ratio is not None:
            dark_pool_score = 50 + (dark_pool_ratio - 1.0) * 22

        clv_score = None
        if clv:
            clv_value = _number(clv.get("CLV"))
            clv_ma5 = _number(clv.get("CLVMA5"))
            clv_ma20 = _number(clv.get("CLVMA20"))
            if clv_value is not None:
                clv_score = 50 + clv_value * 22
                if clv_ma5 is not None and clv_ma20 is not None:
                    clv_score += 8 if clv_ma5 > clv_ma20 else -8

        components = [
            self._component("Trend", 25, gex, trend_score, "SPX trend, moving averages and swing state.", "GEX_Features"),
            self._component(
                "Breadth",
                20,
                breadth,
                breadth_score,
                breadth_detail,
                "LeadingBreath + BreathLine",
                breadth_diagnostics,
            ),
            self._component("Volatility", 15, gex, volatility_score, volatility_detail, "GEX_Features"),
            self._component("GEX", 15, gex, gex_score, "Positive gamma favours mean reversion; negative gamma favours larger moves.", "GEX_Features"),
            self._component("Dark Pool", 10, gex, dark_pool_score, f"Buy/sell ratio {dark_pool_ratio:.2f}" if dark_pool_ratio is not None else "Unavailable", "GEX_Features"),
            self._component("CLV / Flow", 15, clv, clv_score, "Market close-location-value trend.", "MarketCLVTrend"),
        ]
        return self._finish_regime("US", observation_date, components, gex)

    def _get_asx_regime(self, observation_date: date) -> Dict[str, Any]:
        clv_rows = self._query(
            """
            SELECT TOP 1 *
            FROM StockDB.Transform.MarketCLVTrend
            WHERE ObservationDate <= ?
            ORDER BY ObservationDate DESC, NumObservation DESC
            """,
            (observation_date,),
        )
        breadth_rows = self._query(
            """
            SELECT TOP 1
                ObservationDate,
                AVG(CAST(GainLossPecentage AS float)) AS AverageChange,
                AVG(CASE WHEN GainLossPecentage > 0 THEN 1.0 ELSE 0.0 END) AS AdvanceRatio,
                AVG(CASE WHEN [Close] > MovingAverage20d THEN 1.0 ELSE 0.0 END) AS AboveSMA20Ratio,
                AVG(CASE WHEN [Close] > MovingAverage60d THEN 1.0 ELSE 0.0 END) AS AboveSMA60Ratio
            FROM StockDB.Alert.StockStatsHistoryPlusCurrent
            WHERE ObservationDate <= ?
            GROUP BY ObservationDate
            ORDER BY ObservationDate DESC
            """,
            (observation_date,),
        )
        dark_rows = self._query(
            """
            SELECT TOP 1 *
            FROM StockDB.StockData.v_DarkPoolIndex
            WHERE ObservationDate <= ? AND IndexCode IN ('XJO', 'XAO')
            ORDER BY CASE WHEN IndexCode = 'XJO' THEN 0 ELSE 1 END, ObservationDate DESC
            """,
            (observation_date,),
        )

        clv = clv_rows[0] if clv_rows else None
        breadth = breadth_rows[0] if breadth_rows else None
        dark = dark_rows[0] if dark_rows else None

        trend_score = None
        if clv:
            index_change = _number(clv.get("XAOChange"))
            clv_ma5 = _number(clv.get("CLVMA5"))
            clv_ma20 = _number(clv.get("CLVMA20"))
            trend_score = 50 + (index_change or 0) * 8
            if clv_ma5 is not None and clv_ma20 is not None:
                trend_score += 15 if clv_ma5 > clv_ma20 else -15

        breadth_score = None
        if breadth:
            advance_ratio = _number(breadth.get("AdvanceRatio"))
            above_20 = _number(breadth.get("AboveSMA20Ratio"))
            above_60 = _number(breadth.get("AboveSMA60Ratio"))
            breadth_score = (
                (advance_ratio or 0.5) * 40
                + (above_20 or 0.5) * 35
                + (above_60 or 0.5) * 25
            )

        dark_score = None
        if dark:
            dix = _number(dark.get("Dix"))
            swing = str(dark.get("SwingIndicator") or "").lower()
            dark_score = 50 + ((dix or 0.5) - 0.5) * 80
            if "up" in swing:
                dark_score += 10
            elif "down" in swing:
                dark_score -= 10

        clv_score = None
        if clv:
            value = _number(clv.get("CLV"))
            clv_score = 50 + (value or 0) * 25

        components = [
            self._component("Trend", 35, clv, trend_score, "XAO change and CLV trend.", "MarketCLVTrend"),
            self._component("Breadth", 35, breadth, breadth_score, "Advancers and shares above moving averages.", "StockStatsHistoryPlusCurrent"),
            self._component("Dark Pool", 15, dark, dark_score, "XJO/XAO dark-pool index and swing state.", "v_DarkPoolIndex"),
            self._component("CLV / Flow", 15, clv, clv_score, "ASX close-location-value trend.", "MarketCLVTrend"),
        ]
        return self._finish_regime("ASX", observation_date, components, None)

    def _finish_regime(
        self,
        market: str,
        requested_date: date,
        components: List[Dict[str, Any]],
        gex: Optional[Dict[str, Any]],
    ) -> Dict[str, Any]:
        score, confidence = score_regime_components(components)
        label = _regime_label(score)
        available_dates = [component["as_of"] for component in components if component.get("as_of")]
        as_of = max(available_dates) if available_dates else None
        positives = [
            component["name"]
            for component in components
            if component.get("available") and float(component["score"]) >= 58
        ]
        negatives = [
            component["name"]
            for component in components
            if component.get("available") and float(component["score"]) <= 42
        ]
        implication = (
            "Prefer long setups and buying controlled pullbacks."
            if label == "BULLISH"
            else "Reduce long exposure and favour defensive or bearish setups."
            if label == "BEARISH"
            else "Keep position sizes smaller and demand stronger stock-specific confirmation."
        )
        gex_value = _number(gex.get("GEX")) if gex else None
        return {
            "market": market,
            "requested_date": requested_date.isoformat(),
            "as_of": as_of,
            "label": label,
            "score": score,
            "confidence": confidence,
            "components": components,
            "supporting_factors": positives,
            "conflicting_factors": negatives,
            "trading_implication": implication,
            "gex_regime": "POSITIVE" if gex_value is not None and gex_value > 0 else "NEGATIVE" if gex_value is not None else None,
        }

    def get_opportunities(
        self,
        observation_date: date,
        market: str,
        regime: Dict[str, Any],
        limit: int = 25,
    ) -> List[Dict[str, Any]]:
        market = market.upper()
        evidence: List[Dict[str, Any]] = []
        if market == "ASX":
            evidence.extend(self._asx_breakouts(observation_date))
            evidence.extend(self._asx_gap_ups(observation_date))
            evidence.extend(self._asx_pllrs(observation_date))
            evidence.extend(self._asx_patterns(observation_date))
            evidence.extend(self._asx_ratings(observation_date))
        else:
            evidence.extend(self._us_signal_strength(observation_date))
            evidence.extend(self._us_gex_setups(observation_date))

        grouped: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        for item in evidence:
            symbol = _normalize_symbol(item.get("symbol"), market)
            if symbol:
                grouped[symbol].append(item)

        results = [
            self._aggregate_opportunity(symbol, market, items, regime)
            for symbol, items in grouped.items()
        ]
        results.sort(key=lambda item: item["score"], reverse=True)
        return results[:limit]

    def _evidence(
        self,
        symbol: Any,
        source: str,
        direction: str,
        strength: float,
        observed_at: Any,
        reasons: List[str],
        risks: Optional[List[str]] = None,
        horizon: str = "2-10d",
    ) -> Dict[str, Any]:
        return {
            "symbol": symbol,
            "source": source,
            "direction": direction,
            "strength": round(_clamp(strength), 1),
            "observed_at": _iso(observed_at),
            "reasons": reasons,
            "risks": risks or [],
            "horizon": horizon,
        }

    def _asx_breakouts(self, observation_date: date) -> List[Dict[str, Any]]:
        rows = self._query(
            """
            SELECT ASXCode, Pattern, ChangePercent, VolumeValue, VolumeRatio, ObservationDate
            FROM StockDB.Transform.BreakoutWatchlist
            WHERE ObservationDate = (
                SELECT MAX(ObservationDate)
                FROM StockDB.Transform.BreakoutWatchlist
                WHERE ObservationDate <= ?
            )
            """,
            (observation_date,),
        )
        result = []
        for row in rows:
            change = _number(row.get("ChangePercent")) or 0
            ratio = _number(row.get("VolumeRatio")) or 1
            strength = 60 + min(change, 20) * 0.8 + min(ratio, 6) * 3
            risks = ["Price may be extended"] if change >= 15 else []
            result.append(self._evidence(
                row.get("ASXCode"), "BREAKOUT", "BULLISH", strength,
                row.get("ObservationDate"),
                [str(row.get("Pattern") or "Breakout"), f"Volume ratio {ratio:.1f}x", f"Change {change:.1f}%"],
                risks,
            ))
        return result

    def _asx_gap_ups(self, observation_date: date) -> List[Dict[str, Any]]:
        rows = self._query(
            """
            SELECT ASXCode, ChangePercent, GapUpPercent, VolumeRatio, CloseLocation, ObservationDate
            FROM StockDB.Transform.GapUpWatchlist
            WHERE ObservationDate = (
                SELECT MAX(ObservationDate)
                FROM StockDB.Transform.GapUpWatchlist
                WHERE ObservationDate <= ?
            )
            """,
            (observation_date,),
        )
        return [
            self._evidence(
                row.get("ASXCode"), "GAP_UP", "BULLISH",
                62 + min(_number(row.get("GapUpPercent")) or 0, 15) + min(_number(row.get("VolumeRatio")) or 1, 8) * 2,
                row.get("ObservationDate"),
                [
                    f"Gap {_number(row.get('GapUpPercent')) or 0:.1f}%",
                    f"Volume ratio {_number(row.get('VolumeRatio')) or 0:.1f}x",
                ],
                ["Gap may retrace"] if (_number(row.get("ChangePercent")) or 0) > 15 else [],
                "1-5d",
            )
            for row in rows
        ]

    def _asx_pllrs(self, observation_date: date) -> List[Dict[str, Any]]:
        rows = self._query(
            """
            SELECT TOP 200 ObservationDate, ASXCode, TodayPriceChange, TradeValue,
                AggressorBuyRatio, EntryPrice, TargetPrice, StopPrice
            FROM StockDB.Analysis.v_PLLRSScannerResults
            WHERE MeetsCriteria = 1 AND ObservationDate = (
                SELECT MAX(ObservationDate)
                FROM StockDB.Analysis.v_PLLRSScannerResults
                WHERE ObservationDate <= ?
            )
            ORDER BY TradeValue DESC
            """,
            (observation_date,),
        )
        result = []
        for row in rows:
            buy_ratio = _number(row.get("AggressorBuyRatio"))
            strength = 68 + ((buy_ratio - 0.5) * 30 if buy_ratio is not None else 0)
            result.append(self._evidence(
                row.get("ASXCode"), "PLLRS", "BULLISH", strength,
                row.get("ObservationDate"),
                ["PLLRS criteria met", f"Aggressor buy ratio {buy_ratio:.2f}" if buy_ratio is not None else "Trade setup available"],
                [],
                "2-20d",
            ))
        return result

    def _asx_patterns(self, observation_date: date) -> List[Dict[str, Any]]:
        rows = self._query(
            """
            SELECT TOP 200 PredictionDate, ASXCode, ConfidenceScore, EffectiveConfidence,
                Prediction, NextDayBias, RiskLevel
            FROM StockDB.Analysis.PatternPredictionResults
            WHERE PredictionDate = (
                SELECT MAX(PredictionDate)
                FROM StockDB.Analysis.PatternPredictionResults
                WHERE PredictionDate <= ?
            ) AND ConfidenceScore >= 0.70
            ORDER BY ConfidenceScore DESC
            """,
            (observation_date,),
        )
        result = []
        for row in rows:
            direction = _direction_from_text(row.get("Prediction") or row.get("NextDayBias"))
            confidence = _number(row.get("EffectiveConfidence")) or _number(row.get("ConfidenceScore")) or 0.5
            result.append(self._evidence(
                row.get("ASXCode"), "PATTERN", direction, confidence * 100,
                row.get("PredictionDate"),
                [str(row.get("Prediction") or row.get("NextDayBias") or "Pattern prediction"), f"Confidence {confidence:.0%}"],
                [f"Risk: {row.get('RiskLevel')}"] if row.get("RiskLevel") else [],
            ))
        return result

    def _asx_ratings(self, observation_date: date) -> List[Dict[str, Any]]:
        rows = self._query(
            """
            SELECT StockCode, MAX(RatingDate) AS ObservationDate,
                SUM(CASE WHEN Rating = 'Bullish' THEN 1 ELSE 0 END) AS BullishCount,
                SUM(CASE WHEN Rating = 'Neutral' THEN 1 ELSE 0 END) AS NeutralCount,
                SUM(CASE WHEN Rating = 'Bearish' THEN 1 ELSE 0 END) AS BearishCount,
                COUNT(DISTINCT CASE WHEN Rating = 'Bullish' THEN CommenterID END) AS BullishCommenters
            FROM StockDB.Research.StockRating
            WHERE RatingDate <= ? AND RatingDate >= DATEADD(day, -120, ?)
            GROUP BY StockCode
            """,
            (observation_date, observation_date),
        )
        result = []
        for row in rows:
            bullish = int(row.get("BullishCount") or 0)
            bearish = int(row.get("BearishCount") or 0)
            total = bullish + bearish + int(row.get("NeutralCount") or 0)
            direction = "BULLISH" if bullish > bearish else "BEARISH" if bearish > bullish else "NEUTRAL"
            strength = 50 + (bullish - bearish) / max(total, 1) * 35
            result.append(self._evidence(
                row.get("StockCode"), "RESEARCH", direction, strength,
                row.get("ObservationDate"),
                [f"{bullish} bullish / {bearish} bearish ratings", f"{int(row.get('BullishCommenters') or 0)} bullish commenters"],
                [],
                "5-60d",
            ))
        return result

    def _us_signal_strength(self, observation_date: date) -> List[Dict[str, Any]]:
        rows = self._query(
            """
            SELECT StockCode, ObservationDate, SignalStrengthLevel, SourceType,
                BuyDipRange, SellRipRange
            FROM StockDB_US.Analysis.SignalStrength
            WHERE ObservationDate = (
                SELECT MAX(ObservationDate)
                FROM StockDB_US.Analysis.SignalStrength
                WHERE ObservationDate <= ?
            )
            """,
            (observation_date,),
        )
        return [
            self._evidence(
                row.get("StockCode"), str(row.get("SourceType") or "SIGNAL"),
                _direction_from_text(row.get("SignalStrengthLevel")),
                _signal_strength(row.get("SignalStrengthLevel")),
                row.get("ObservationDate"),
                [str(row.get("SignalStrengthLevel") or "Signal strength")],
                [],
                "1-10d",
            )
            for row in rows
        ]

    def _us_gex_setups(self, observation_date: date) -> List[Dict[str, Any]]:
        rows = self._query(
            """
            SELECT ObservationDate, ASXCode, GEX, GEX_ZScore, SwingIndicator,
                PotentialSwingIndicator, Golden_Setup, Setup_Trend_Dip,
                Setup_Dual_Squeeze, Setup_Volatility_Crush
            FROM StockDB_US.Analysis.GEX_Features
            WHERE ObservationDate = (
                SELECT MAX(ObservationDate)
                FROM StockDB_US.Analysis.GEX_Features
                WHERE ObservationDate <= ?
            ) AND ASXCode <> 'SPXW'
            """,
            (observation_date,),
        )
        result = []
        for row in rows:
            direction = _direction_from_text(row.get("SwingIndicator") or row.get("PotentialSwingIndicator"))
            strength = 58.0
            reasons = []
            for field, label in [
                ("Golden_Setup", "Golden setup"),
                ("Setup_Trend_Dip", "Trend dip"),
                ("Setup_Dual_Squeeze", "Dual squeeze"),
                ("Setup_Volatility_Crush", "Volatility crush"),
            ]:
                if _number(row.get(field)) == 1:
                    reasons.append(label)
                    strength += 8
            if not reasons:
                reasons.append(str(row.get("SwingIndicator") or row.get("PotentialSwingIndicator") or "GEX setup"))
            result.append(self._evidence(
                row.get("ASXCode"), "GEX_SETUP", direction, strength,
                row.get("ObservationDate"), reasons, [], "1-20d",
            ))
        return result

    def _aggregate_opportunity(
        self,
        symbol: str,
        market: str,
        evidence: List[Dict[str, Any]],
        regime: Dict[str, Any],
    ) -> Dict[str, Any]:
        bullish = [item for item in evidence if item["direction"] == "BULLISH"]
        bearish = [item for item in evidence if item["direction"] == "BEARISH"]
        bull_weight = sum(item["strength"] - 50 for item in bullish)
        bear_weight = sum(item["strength"] - 50 for item in bearish)
        direction = "BULLISH" if bull_weight > bear_weight else "BEARISH" if bear_weight > bull_weight else "NEUTRAL"
        directional = bullish if direction == "BULLISH" else bearish if direction == "BEARISH" else evidence
        base = sum(item["strength"] for item in directional) / max(len(directional), 1)
        independent_sources = len({item["source"] for item in directional})
        conflict_count = len(bearish if direction == "BULLISH" else bullish)
        regime_fit = direction == regime.get("label")
        score = base + min(independent_sources - 1, 4) * 5 + (6 if regime_fit else -4 if regime.get("label") != "NEUTRAL" else 0)
        score -= conflict_count * 5
        score = round(_clamp(score), 1)

        reasons = []
        risks = []
        for item in sorted(evidence, key=lambda entry: entry["strength"], reverse=True):
            reasons.extend(f"{item['source']}: {reason}" for reason in item["reasons"][:2])
            risks.extend(item["risks"])
        horizons = [item["horizon"] for item in directional]
        option_strategies = rank_option_strategies(
            direction=direction,
            opportunity_score=score,
            regime_label=str(regime.get("label") or "NEUTRAL"),
            market=market,
            gex_regime=regime.get("gex_regime"),
        )
        return {
            "symbol": symbol,
            "market": market,
            "score": score,
            "direction": direction,
            "horizon": horizons[0] if horizons else "Unknown",
            "source_count": len({item["source"] for item in evidence}),
            "sources": sorted({item["source"] for item in evidence}),
            "regime_fit": "STRONG" if regime_fit else "NEUTRAL" if regime.get("label") == "NEUTRAL" else "CONFLICTING",
            "reasons": reasons[:8],
            "risks": list(dict.fromkeys(risks))[:5],
            "evidence": evidence,
            "option_strategies": option_strategies,
        }

    def get_summary(
        self, observation_date: date, limit: int = 20, market: Optional[str] = None
    ) -> Dict[str, Any]:
        from app.services.aaii_sentiment_service import AAIISentimentService
        from app.services.discord_market_intelligence_service import (
            DiscordFollowerMarketIntelligenceService,
        )
        from app.services.fear_greed_service import FearGreedService

        markets = (market.upper(),) if market else ("ASX", "US")
        regimes = {
            market: self.get_regime(observation_date, market)
            for market in markets
        }
        response = {
            "requested_date": observation_date.isoformat(),
            "generated_at": datetime.utcnow().isoformat() + "Z",
            "regimes": regimes,
            "opportunities": {
                market: self.get_opportunities(observation_date, market, regimes[market], limit)
                for market in markets
            },
        }
        if "US" in markets:
            response["sentiment"] = AAIISentimentService().get_insight(observation_date)
            response["fear_greed"] = FearGreedService().get_insight(observation_date)
            response["market_intelligence"] = (
                DiscordFollowerMarketIntelligenceService().get_dashboard_digest(observation_date)
            )
        return response
