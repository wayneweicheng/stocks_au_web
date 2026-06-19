import logging
from datetime import date, datetime
from decimal import Decimal
from time import perf_counter
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.db import get_sql_model
from app.routers.auth import verify_credentials


logger = logging.getLogger("app.calculated_gex")

router = APIRouter(
    prefix="/api/calculated-gex",
    tags=["calculated-gex"],
    dependencies=[Depends(verify_credentials)],
)


def _json_value(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def _normalize_row(row: Dict[str, Any]) -> Dict[str, Any]:
    return {key: _json_value(value) for key, value in row.items()}


def _as_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _calculate_rsi(rows: List[Dict[str, Any]], periods: int = 4) -> None:
    """Add RSI values in chronological order using the Streamlit page's simple rolling average formula."""
    gains: List[float] = []
    losses: List[float] = []
    previous_close: Optional[float] = None

    for row in rows:
        close = _as_float(row.get("Close"))
        if close is None or previous_close is None:
            gains.append(0.0)
            losses.append(0.0)
            row["RSI"] = None
            previous_close = close
            continue

        delta = close - previous_close
        gains.append(max(delta, 0.0))
        losses.append(max(-delta, 0.0))

        if len(gains) <= periods:
            row["RSI"] = None
        else:
            avg_gain = sum(gains[-periods:]) / periods
            avg_loss = sum(losses[-periods:]) / periods
            if avg_loss == 0:
                row["RSI"] = 100.0 if avg_gain > 0 else 50.0
            else:
                rs = avg_gain / avg_loss
                row["RSI"] = 100 - (100 / (1 + rs))

        previous_close = close


@router.get("")
def get_calculated_gex(
    stock_code: str = Query("QQQ.US", min_length=1, max_length=40),
    date_from: date = Query(...),
    date_to: date = Query(...),
) -> Dict[str, Any]:
    if date_from > date_to:
        raise HTTPException(status_code=422, detail="Date from cannot be after date to")

    normalized_code = stock_code.strip().upper()
    if not normalized_code:
        raise HTTPException(status_code=422, detail="Stock code is required")

    sql = """
        select ASXCode, ObservationDate, NoOfOption, GEX, FormattedGEX, [Close],
               Prev1Close, Prev2Close, FormattedPrev1GEX, SwingIndicator, PotentialSwingIndicator,
               GEXChange, ClosePriceChange
        from StockDB_US.StockData.v_CalculatedGEXPlus_V2
        where ASXCode = convert(varchar(10), ?)
          and ObservationDate >= convert(date, ?)
          and ObservationDate <= convert(date, ?)
        order by ObservationDate asc
        option (recompile)
    """

    started = perf_counter()
    try:
        model = get_sql_model()
        rows = model.execute_read_query(
            sql,
            (normalized_code, date_from.isoformat(), date_to.isoformat()),
        ) or []
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to load calculated GEX data: {exc}")
    query_elapsed = perf_counter() - started
    logger.info(
        "calculated_gex query stock_code=%s date_from=%s date_to=%s rows=%s elapsed_ms=%.1f",
        normalized_code,
        date_from.isoformat(),
        date_to.isoformat(),
        len(rows),
        query_elapsed * 1000.0,
    )

    processing_started = perf_counter()
    data = [_normalize_row(row) for row in rows]
    _calculate_rsi(data)

    gex_values = [
        value
        for value in (_as_float(row.get("GEX")) for row in data)
        if value is not None
    ]
    gex_mean = sum(gex_values) / len(gex_values) if gex_values else None
    if gex_values and len(gex_values) > 1:
        variance = sum((value - gex_mean) ** 2 for value in gex_values) / (len(gex_values) - 1)
        gex_std = variance ** 0.5
    else:
        gex_std = 0.0 if gex_values else None
    processing_elapsed = perf_counter() - processing_started
    logger.info(
        "calculated_gex processing stock_code=%s rows=%s elapsed_ms=%.1f",
        normalized_code,
        len(data),
        processing_elapsed * 1000.0,
    )

    return {
        "stock_code": normalized_code,
        "date_from": date_from.isoformat(),
        "date_to": date_to.isoformat(),
        "count": len(data),
        "gex_mean": gex_mean,
        "gex_std": gex_std,
        "upper_bound": gex_mean + 1.25 * gex_std if gex_mean is not None and gex_std is not None else None,
        "lower_bound": gex_mean - 1.25 * gex_std if gex_mean is not None and gex_std is not None else None,
        "rows": data,
    }
