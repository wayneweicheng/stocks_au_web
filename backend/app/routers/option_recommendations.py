from datetime import date
from math import erf, exp, log, sqrt
from typing import Any, Dict, List, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from app.routers.auth import verify_credentials


router = APIRouter(prefix="/api", tags=["option-recommendations"])
DB_NAME = "StockDB_US"
RISK_FREE_RATE = 0.045
DOWN_MOVE_IV_EXPANSION = 0.02
UP_MOVE_IV_CRUSH = -0.01
MAX_IV_SHIFT = 0.10


class RepriceSTORequest(BaseModel):
    recommendation_id: int = Field(..., gt=0)
    target_price: float = Field(..., gt=0)


class RepriceSTOResponse(BaseModel):
    ok: bool
    recommendation_id: int
    target_price: float
    sto_limit_price: float
    base_case: float
    optimistic: float
    conservative: float
    adjusted_iv: float
    contract_iv: float
    skew_adjustment: float
    directional_iv_adjustment: float
    total_iv_shift: float


def _to_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _to_int(value: Any, default: int = 0) -> int:
    if value is None:
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _normalize_iv(iv: float) -> float:
    # The strategy stores IV as a decimal. This guard handles percent-shaped data.
    return iv / 100.0 if iv > 3 else iv


def _normal_cdf(value: float) -> float:
    return 0.5 * (1 + erf(value / sqrt(2)))


def _price_put(strike: float, spot: float, iv: float, dte: int) -> float:
    if strike <= 0 or spot <= 0 or iv <= 0 or dte <= 0:
        return 0.0

    time_to_expiry_years = dte / 365.0
    sqrt_time = sqrt(time_to_expiry_years)
    d1 = (log(spot / strike) + (RISK_FREE_RATE + 0.5 * iv**2) * time_to_expiry_years) / (iv * sqrt_time)
    d2 = d1 - iv * sqrt_time
    return max(strike * exp(-RISK_FREE_RATE * time_to_expiry_years) * _normal_cdf(-d2) - spot * _normal_cdf(-d1), 0.0)


def _expiry_key(value: Any) -> date:
    return value.date() if hasattr(value, "date") else value


def _build_iv_surface(rows: List[Dict[str, Any]]) -> Tuple[Dict[date, List[float]], Dict[Tuple[date, float], float]]:
    strikes_by_expiry: Dict[date, List[float]] = {}
    iv_grid: Dict[Tuple[date, float], float] = {}

    for row in rows:
        expiry = _expiry_key(row.get("ExpiryDate"))
        strike = _to_float(row.get("Strike"))
        iv = _normalize_iv(_to_float(row.get("IV")))
        if expiry is None or strike <= 0 or iv <= 0:
            continue
        strikes_by_expiry.setdefault(expiry, []).append(strike)
        iv_grid[(expiry, strike)] = iv

    for expiry, strikes in strikes_by_expiry.items():
        strikes_by_expiry[expiry] = sorted(set(strikes))

    return strikes_by_expiry, iv_grid


def _nearest_strike_index(strikes: List[float], target: float) -> int:
    if not strikes:
        return 0
    return min(range(len(strikes)), key=lambda index: abs(strikes[index] - target))


def _skew_slope(
    strikes_by_expiry: Dict[date, List[float]],
    iv_grid: Dict[Tuple[date, float], float],
    target_strike: float,
    expiry: date,
    window: int = 2,
) -> float:
    strikes = strikes_by_expiry.get(expiry, [])
    if len(strikes) < 2:
        return 0.0

    target_index = _nearest_strike_index(strikes, target_strike)
    nearby_strikes = strikes[max(0, target_index - window): min(len(strikes), target_index + window + 1)]
    points = [(strike, iv_grid[(expiry, strike)]) for strike in nearby_strikes if (expiry, strike) in iv_grid]

    if len(points) < 2:
        return 0.0

    x_mean = sum(strike for strike, _ in points) / len(points)
    y_mean = sum(iv for _, iv in points) / len(points)
    numerator = sum((strike - x_mean) * (iv - y_mean) for strike, iv in points)
    denominator = sum((strike - x_mean) ** 2 for strike, _ in points)
    return 0.0 if abs(denominator) < 1e-10 else numerator / denominator


def _contract_from_row(row: Dict[str, Any]) -> Dict[str, Any]:
    bid = _to_float(row.get("Bid"))
    ask = _to_float(row.get("Ask"))
    mid = (bid + ask) / 2 if bid > 0 or ask > 0 else _to_float(row.get("Theo"))
    spread_pct = (ask - bid) / mid if mid > 0 else 0.0
    return {
        "symbol": row.get("OptionSymbol"),
        "strike": _to_float(row.get("Strike")),
        "expiry": _expiry_key(row.get("ExpiryDate")),
        "dte": _to_int(row.get("DTE")),
        "bid": bid,
        "ask": ask,
        "mid": mid,
        "iv": _normalize_iv(_to_float(row.get("IV"))),
        "open_interest": _to_int(row.get("OpenInterest")),
        "spread_pct": spread_pct,
    }


@router.get("/option-recommendations/dates")
def get_option_recommendation_dates(
    limit: int = Query(180, ge=1, le=1000),
    username: str = Depends(verify_credentials),
) -> List[str]:
    query = f"""
    SELECT DISTINCT TOP ({int(limit)}) TradingDate
    FROM [Analysis].[v_CSPPriceLadder]
    WHERE TradingDate IS NOT NULL
    ORDER BY TradingDate DESC
    """

    try:
        model = SQLServerModel(database=DB_NAME)
        rows = model.execute_read_query(query, ()) or []
        return [
            row["TradingDate"].isoformat()
            for row in rows
            if row.get("TradingDate") is not None
        ]
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/option-recommendations")
def get_option_recommendations(
    trading_date: date = Query(..., alias="trading_date", description="Trading date filter in YYYY-MM-DD format"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
    query = """
    SELECT
        *
    FROM (
        SELECT
            *,
            DENSE_RANK() OVER (
                PARTITION BY Ticker
                ORDER BY OptionSymbol
            ) AS OptionRankForTicker
        FROM [Analysis].[v_CSPPriceLadder]
        WHERE TradingDate = ?
    ) ranked
    WHERE OptionRankForTicker <= 4
    ORDER BY Ticker, OptionSymbol, STOLimitPrice
    """

    try:
        model = SQLServerModel(database=DB_NAME)
        return model.execute_read_query(query, (trading_date,)) or []
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/option-recommendations/reprice-sto", response_model=RepriceSTOResponse)
def reprice_sto_limit(
    payload: RepriceSTORequest,
    username: str = Depends(verify_credentials),
) -> RepriceSTOResponse:
    recommendation_query = """
    SELECT TOP 1
        RecommendationID,
        ObservationDate,
        Ticker,
        OptionSymbol,
        Strike,
        Expiry,
        DTE,
        CurrentPrice
    FROM [Analysis].[CSPRecommendations]
    WHERE RecommendationID = ?
    """

    chain_query = """
    SELECT
        OptionSymbol,
        ASXCode,
        Strike,
        PorC,
        ExpiryDate,
        Expiry,
        Bid,
        BidSize,
        Ask,
        AskSize,
        IV,
        OpenInterest,
        Volume,
        Delta,
        Gamma,
        Theta,
        Vega,
        RHO,
        Theo,
        DATEDIFF(day, ?, ExpiryDate) as DTE
    FROM [StockData].[v_OptionDelayedQuote_V2]
    WHERE ASXCode = ?
      AND ObservationDate = ?
      AND PorC = 'P'
      AND DATEDIFF(day, ?, ExpiryDate) BETWEEN ? AND ?
      AND Bid IS NOT NULL
      AND Ask IS NOT NULL
      AND OpenInterest >= ?
    ORDER BY ExpiryDate, Strike
    """

    exact_contract_query = """
    SELECT TOP 1
        OptionSymbol,
        ASXCode,
        Strike,
        PorC,
        ExpiryDate,
        Expiry,
        Bid,
        BidSize,
        Ask,
        AskSize,
        IV,
        OpenInterest,
        Volume,
        Delta,
        Gamma,
        Theta,
        Vega,
        RHO,
        Theo,
        DATEDIFF(day, ?, ExpiryDate) as DTE
    FROM [StockData].[v_OptionDelayedQuote_V2]
    WHERE OptionSymbol = ?
      AND ObservationDate = ?
      AND PorC = 'P'
    """

    try:
        model = SQLServerModel(database=DB_NAME)
        recommendation_rows = model.execute_read_query(recommendation_query, (payload.recommendation_id,)) or []
        if not recommendation_rows:
            raise HTTPException(status_code=404, detail="Recommendation not found")

        recommendation = recommendation_rows[0]
        observation_date = recommendation["ObservationDate"]
        ticker = recommendation["Ticker"]
        option_symbol = recommendation["OptionSymbol"]
        current_price = _to_float(recommendation["CurrentPrice"])
        if current_price <= 0:
            raise HTTPException(status_code=422, detail="Recommendation has invalid current underlying price")

        chain_rows = model.execute_read_query(
            chain_query,
            (
                observation_date,
                ticker,
                observation_date,
                observation_date,
                14,
                28,
                100,
            ),
        ) or []

        contract_row: Optional[Dict[str, Any]] = next(
            (row for row in chain_rows if row.get("OptionSymbol") == option_symbol),
            None,
        )

        if contract_row is None:
            exact_rows = model.execute_read_query(
                exact_contract_query,
                (observation_date, option_symbol, observation_date),
            ) or []
            if exact_rows:
                contract_row = exact_rows[0]
                chain_rows.append(contract_row)

        if contract_row is None:
            raise HTTPException(status_code=404, detail="Option quote not found in v_OptionDelayedQuote_V2")

        contract = _contract_from_row(contract_row)
        if contract["iv"] <= 0:
            raise HTTPException(status_code=422, detail="Option quote has invalid IV")

        strikes_by_expiry, iv_grid = _build_iv_surface(chain_rows)
        price_move_pct = (payload.target_price - current_price) / current_price
        skew_slope = _skew_slope(strikes_by_expiry, iv_grid, contract["strike"], contract["expiry"])
        target_moneyness_ratio = contract["strike"] / payload.target_price
        effective_strike = target_moneyness_ratio * current_price
        strike_equivalent_shift = effective_strike - contract["strike"]
        iv_skew_adjustment = skew_slope * strike_equivalent_shift

        if price_move_pct < 0:
            iv_directional = DOWN_MOVE_IV_EXPANSION * abs(price_move_pct) / 0.05
        else:
            iv_directional = UP_MOVE_IV_CRUSH * price_move_pct / 0.05

        total_iv_shift = max(min(iv_skew_adjustment + iv_directional, MAX_IV_SHIFT), -MAX_IV_SHIFT)
        adjusted_iv = max(contract["iv"] + total_iv_shift, 0.05)

        base_case = _price_put(contract["strike"], payload.target_price, adjusted_iv, contract["dte"])
        optimistic = _price_put(contract["strike"], payload.target_price, max(adjusted_iv - 0.02, 0.05), contract["dte"])
        conservative = _price_put(contract["strike"], payload.target_price, adjusted_iv + 0.02, contract["dte"])

        return RepriceSTOResponse(
            ok=True,
            recommendation_id=payload.recommendation_id,
            target_price=round(payload.target_price, 4),
            sto_limit_price=round(conservative, 2),
            base_case=round(base_case, 4),
            optimistic=round(optimistic, 4),
            conservative=round(conservative, 4),
            adjusted_iv=round(adjusted_iv, 6),
            contract_iv=round(contract["iv"], 6),
            skew_adjustment=round(iv_skew_adjustment, 6),
            directional_iv_adjustment=round(iv_directional, 6),
            total_iv_shift=round(total_iv_shift, 6),
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
