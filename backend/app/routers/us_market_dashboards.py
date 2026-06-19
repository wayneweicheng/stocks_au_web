import logging
import statistics
from datetime import date
from decimal import Decimal
from time import perf_counter
from typing import Any, Dict, List, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.db import get_sql_model
from app.routers.auth import verify_credentials


router = APIRouter(
    prefix="/api/us-market-dashboards",
    tags=["us-market-dashboards"],
    dependencies=[Depends(verify_credentials)],
)

logger = logging.getLogger(__name__)
SLOW_QUERY_SECONDS = 2.0


def _json_value(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, date):
        return value.isoformat()
    return value


def _rows(rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [{key: _json_value(value) for key, value in row.items()} for row in rows]


def _float(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _date_str(value: Any) -> str:
    if isinstance(value, date):
        return value.isoformat()
    return str(value or "")


def _date_value(value: Any) -> Optional[date]:
    if isinstance(value, date):
        return value
    try:
        return date.fromisoformat(str(value)[:10])
    except (TypeError, ValueError):
        return None


def _round(value: Optional[float], digits: int) -> Optional[float]:
    return round(value, digits) if value is not None else None


def _query(sql: str, params: Tuple[Any, ...]) -> List[Dict[str, Any]]:
    try:
        return get_sql_model().execute_read_query(sql, params) or []
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Database query failed: {exc}")


def _timed_query(label: str, sql: str, params: Tuple[Any, ...]) -> List[Dict[str, Any]]:
    started = perf_counter()
    rows = _query(sql, params)
    elapsed = perf_counter() - started
    log = logger.warning if elapsed >= SLOW_QUERY_SECONDS else logger.info
    log(
        "us_market_dashboards query label=%s elapsed_ms=%.1f rows=%s slow=%s",
        label,
        elapsed * 1000.0,
        len(rows),
        elapsed >= SLOW_QUERY_SECONDS,
    )
    return rows


def _option_gex_metrics(raw_rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    rows = [dict(row) for row in raw_rows if row.get("CapitalType") is not None]
    by_cap: Dict[str, List[Dict[str, Any]]] = {}
    by_date: Dict[str, List[Dict[str, Any]]] = {}
    for row in rows:
        row["_date_key"] = _date_str(row.get("ObservationDate"))
        row["_gex"] = _float(row.get("GEXDelta")) or 0.0
        row["_abs_gex"] = abs(row["_gex"])
        by_cap.setdefault(str(row.get("CapitalType")), []).append(row)
        by_date.setdefault(row["_date_key"], []).append(row)

    stats_by_cap: Dict[str, Dict[str, Any]] = {}
    for cap, cap_rows in by_cap.items():
        values = [row["_abs_gex"] for row in cap_rows]
        stats_by_cap[cap] = {
            "min": min(values) if values else None,
            "max": max(values) if values else None,
            "avg": sum(values) / len(values) if values else None,
            "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
            "count": len(values),
        }
        cumulative = 0.0
        for row in sorted(cap_rows, key=lambda item: _date_str(item.get("ObservationDate"))):
            cumulative += row["_gex"]
            row["_cumulative"] = cumulative

    totals_by_date: Dict[str, Dict[str, Optional[float]]] = {}
    for date_key, date_rows in by_date.items():
        total = sum(row["_abs_gex"] for row in date_rows)
        bc = sum(row["_abs_gex"] for row in date_rows if row.get("CapitalType") == "BC")
        bp = sum(row["_abs_gex"] for row in date_rows if row.get("CapitalType") == "BP")
        totals_by_date[date_key] = {
            "total": total,
            "buy_call_perc": None if total == 0 else bc * 100.0 / total,
            "buy_put_perc": None if total == 0 else bp * 100.0 / total,
        }

    output: List[Dict[str, Any]] = []
    for row in rows:
        cap = str(row.get("CapitalType"))
        cap_stats = stats_by_cap[cap]
        date_totals = totals_by_date[row["_date_key"]]
        total_gex = date_totals["total"] or 0.0
        buy_call_perc = date_totals["buy_call_perc"]
        buy_put_perc = date_totals["buy_put_perc"]
        min_gex = cap_stats["min"]
        max_gex = cap_stats["max"]
        avg_gex = cap_stats["avg"]
        stdev_gex = cap_stats["stdev"] or 0.0
        norm = None
        if min_gex is not None and max_gex is not None and max_gex - min_gex > 0:
            norm = (row["_abs_gex"] - min_gex) / (max_gex - min_gex)
        z_score = None
        if avg_gex is not None and stdev_gex != 0:
            z_score = (row["_abs_gex"] - avg_gex) / stdev_gex
        output.append(
            {
                "ObservationDate": row.get("ObservationDate"),
                "NormGEXDelta": _round(norm, 4),
                "ZScoreGEXDelta": _round(z_score, 4),
                "CapitalType": row.get("CapitalType"),
                "GEXDelta": row["_abs_gex"],
                "CumulativeDelta": abs(row.get("_cumulative") or 0.0),
                "GEXDeltaPerc": _round(0.0 if total_gex == 0 else row["_abs_gex"] * 100.0 / total_gex, 2),
                "PutCallRatio": None if not buy_call_perc else buy_put_perc / buy_call_perc if buy_put_perc is not None else None,
                "Close": row.get("Close"),
                "VWAP": row.get("VWAP"),
                "AvgGEXDelta": avg_gex,
                "NumObs": cap_stats["count"],
                "ASXCode": row.get("ASXCode"),
            }
        )
    return output


@router.get("/market-clv-trend")
def market_clv_trend(
    date_from: Optional[date] = Query(default=None),
    date_to: Optional[date] = Query(default=None),
    market_cap: List[str] = Query(default=[]),
) -> Dict[str, Any]:
    if date_from and date_to and date_from > date_to:
        raise HTTPException(status_code=422, detail="Date from cannot be after date to")

    bounds = _query(
        """
        select min(ObservationDate) as min_date, max(ObservationDate) as max_date
        from StockDB_US.Transform.MarketCLVTrend with(nolock)
        """,
        (),
    )
    max_date = bounds[0].get("max_date") if bounds else None
    effective_to = date_to or max_date

    where = ["1 = 1"]
    params: List[Any] = []
    if date_from:
        where.append("ObservationDate >= convert(date, ?)")
        params.append(date_from.isoformat())
    elif effective_to:
        where.append("ObservationDate >= dateadd(year, -1, ?)")
        params.append(_json_value(effective_to))
    if effective_to:
        where.append("ObservationDate <= convert(date, ?)")
        params.append(_json_value(effective_to))
    if market_cap:
        where.append(f"MarketCap in ({','.join(['?'] * len(market_cap))})")
        params.extend(market_cap)

    rows = _rows(
        _query(
            f"""
            select ObservationDate, Sector, MarketCap, CLV, CLVMA5, CLVMA10, CLVMA20,
                   VarCLVMA5, VarCLVMA10, VarCLVMA20, SPX
            from StockDB_US.Transform.MarketCLVTrend with(nolock)
            where {' and '.join(where)}
            order by ObservationDate asc, MarketCap desc, Sector asc
            """,
            tuple(params),
        )
    )
    caps = _rows(
        _query(
            """
            select distinct MarketCap
            from StockDB_US.Transform.MarketCLVTrend with(nolock)
            where MarketCap is not null
            order by MarketCap desc
            """,
            (),
        )
    )
    return {
        "date_from": date_from.isoformat() if date_from else None,
        "date_to": _json_value(effective_to),
        "market_caps": [row["MarketCap"] for row in caps],
        "count": len(rows),
        "rows": rows,
    }


@router.get("/gamma-wall")
def gamma_wall(
    stock_code: str = Query("QQQ.US", min_length=1, max_length=40),
    observation_date: Optional[date] = Query(default=None),
) -> Dict[str, Any]:
    code = stock_code.strip().upper()
    if not code:
        raise HTTPException(status_code=422, detail="Stock code is required")

    if observation_date:
        effective_date = observation_date.isoformat()
    else:
        latest = _query(
            """
            select max(ObservationDate) as observation_date
            from StockDB_US.Transform.v_GammaWall with(nolock)
            where ASXCode = convert(varchar(10), ?)
            """,
            (code,),
        )
        effective_date = _json_value(latest[0].get("observation_date")) if latest else None

    if not effective_date:
        return {"stock_code": code, "observation_date": None, "by_strike": [], "by_expiry": []}

    by_strike = _rows(
        _query(
            """
            select Strike, sum(CallGamma) as CallGamma, sum(PutGamma) as PutGamma,
                   sum(CallGamma + PutGamma) as NetGamma, max([Close]) as [Close]
            from StockDB_US.Transform.v_GammaWall with(nolock)
            where ASXCode = convert(varchar(10), ?)
              and ObservationDate = convert(date, ?)
            group by Strike
            order by Strike asc
            """,
            (code, effective_date),
        )
    )
    by_expiry = _rows(
        _query(
            """
            select ExpiryDate, sum(CallGamma) as CallGamma, sum(PutGamma) as PutGamma,
                   sum(CallGamma + PutGamma) as NetGamma, max([Close]) as [Close]
            from StockDB_US.Transform.v_GammaWallByExpiryDate with(nolock)
            where ASXCode = convert(varchar(10), ?)
              and ObservationDate = convert(date, ?)
            group by ExpiryDate
            order by ExpiryDate asc
            """,
            (code, effective_date),
        )
    )
    return {
        "stock_code": code,
        "observation_date": effective_date,
        "close": by_strike[0].get("Close") if by_strike else None,
        "by_strike": by_strike,
        "by_expiry": by_expiry,
    }


@router.get("/net-gex-vs-close")
def net_gex_vs_close(
    stock_code: str = Query("QQQ.US", min_length=1, max_length=40),
    date_from: Optional[date] = Query(default=None),
    date_to: Optional[date] = Query(default=None),
) -> Dict[str, Any]:
    if date_from and date_to and date_from > date_to:
        raise HTTPException(status_code=422, detail="Date from cannot be after date to")

    code = stock_code.strip().upper()
    if not code:
        raise HTTPException(status_code=422, detail="Stock code is required")

    latest = _query(
        """
        select max(ObservationDate) as observation_date
        from StockDB_US.Transform.v_OptionNetExposureAggregate with(nolock)
        where ASXCode = convert(varchar(10), ?)
        """,
        (code,),
    )
    effective_to = date_to or (latest[0].get("observation_date") if latest else None)

    where = ["ASXCode = convert(varchar(10), ?)"]
    params: List[Any] = [code]
    if date_from:
        where.append("ObservationDate >= convert(date, ?)")
        params.append(date_from.isoformat())
    elif effective_to:
        where.append("ObservationDate >= dateadd(year, -1, convert(date, ?))")
        params.append(_json_value(effective_to))
    if effective_to:
        where.append("ObservationDate <= convert(date, ?)")
        params.append(_json_value(effective_to))

    rows = _rows(
        _query(
            f"""
            select ObservationDate, max([Close]) as [Close],
                   max(Prev1Close) as Prev1Close,
                   max(TotalCallGamma) as TotalCallGamma,
                   max(TotalPutGamma) as TotalPutGamma,
                   max(TotalNetGamma) as TotalNetGamma,
                   max(Prev1TotalNetGamma) as Prev1TotalNetGamma,
                   max(TotalNetGammaChange) as TotalNetGammaChange,
                   max(CloseChange) as CloseChange
            from StockDB_US.Transform.v_OptionNetExposureAggregate with(nolock)
            where {' and '.join(where)}
            group by ObservationDate
            order by ObservationDate asc
            """,
            tuple(params),
        )
    )
    latest_strikes = _rows(
        _query(
            """
            select top (80) Strike, CallGamma, PutGamma, NetGamma, Exposure, [Close], ObservationDate
            from StockDB_US.Transform.v_OptionNetExposureAggregate with(nolock)
            where ASXCode = convert(varchar(10), ?)
              and ObservationDate = convert(date, ?)
            order by abs(NetGamma) desc
            """,
            (code, _json_value(effective_to)),
        )
    ) if effective_to else []

    return {
        "stock_code": code,
        "date_from": date_from.isoformat() if date_from else None,
        "date_to": _json_value(effective_to),
        "count": len(rows),
        "rows": rows,
        "latest_strikes": latest_strikes,
    }


@router.get("/net-gex-vs-price-change")
def net_gex_vs_price_change(
    stock_code: str = Query("QQQ.US", min_length=1, max_length=40),
    date_from: Optional[date] = Query(default=None),
    date_to: Optional[date] = Query(default=None),
) -> Dict[str, Any]:
    return net_gex_vs_close(stock_code=stock_code, date_from=date_from, date_to=date_to)


@router.get("/option-gex-delta-capital-type")
def option_gex_delta_capital_type(
    stock_code: str = Query("QQQ.US", min_length=1, max_length=40),
    date_from: Optional[date] = Query(default=None),
    date_to: Optional[date] = Query(default=None),
    capital_type: List[str] = Query(default=[]),
) -> Dict[str, Any]:
    if date_from and date_to and date_from > date_to:
        raise HTTPException(status_code=422, detail="Date from cannot be after date to")

    code = stock_code.strip().upper()
    if not code:
        raise HTTPException(status_code=422, detail="Stock code is required")

    endpoint_started = perf_counter()

    latest = _timed_query(
        "option_gex_delta_capital_type.latest_observation_date",
        """
        select max(ObservationDate) as observation_date
        from StockDB_US.Transform.OptionGEXChangeCapitalType with(nolock)
        where ASXCode = convert(varchar(10), ?)
          and [Close] is not null
        """,
        (code,),
    )
    effective_to = date_to or (latest[0].get("observation_date") if latest else None)

    all_capital_types = _rows(
        _timed_query(
            "option_gex_delta_capital_type.capital_types",
            """
            select distinct CapitalType
            from StockDB_US.Transform.OptionGEXChangeCapitalType with(nolock)
            where ASXCode = convert(varchar(10), ?)
              and CapitalType is not null
            order by CapitalType asc
            """,
            (code,),
        )
    )

    raw_rows = _timed_query(
        "option_gex_delta_capital_type.raw_rows",
        """
        select ObservationDate, ASXCode, GEXDelta, CapitalType, [Close], VWAP
        from StockDB_US.Transform.OptionGEXChangeCapitalType with(nolock)
        where ASXCode = convert(varchar(10), ?)
          and CapitalType is not null
        order by CapitalType asc, ObservationDate asc
        """,
        (code,),
    )
    rows = _rows(_option_gex_metrics(raw_rows))
    effective_from = date_from
    if not effective_from and effective_to:
        effective_to_date = _date_value(effective_to)
        if effective_to_date:
            effective_from = date.fromordinal(effective_to_date.toordinal() - 180)
    selected_capital_types = set(capital_type)
    rows = [
        row
        for row in rows
        if row.get("Close") is not None
        and (not effective_from or (_date_value(row.get("ObservationDate")) or date.min) >= effective_from)
        and (not effective_to or (_date_value(row.get("ObservationDate")) or date.max) <= (_date_value(effective_to) or date.max))
        and (not selected_capital_types or str(row.get("CapitalType")) in selected_capital_types)
    ]
    rows.sort(key=lambda row: (_date_str(row.get("ObservationDate")), str(row.get("CapitalType") or "")))

    processing_started = perf_counter()
    by_cap: Dict[str, List[Dict[str, Any]]] = {}
    for row in rows:
        by_cap.setdefault(str(row.get("CapitalType") or ""), []).append(row)

    for cap_rows in by_cap.values():
        cap_rows.sort(key=lambda row: str(row.get("ObservationDate") or ""))
        for index, row in enumerate(cap_rows):
            previous = cap_rows[index - 1] if index > 0 else None
            prev_close = _float(previous.get("Close")) if previous else None
            prev_pcr = _float(previous.get("PutCallRatio")) if previous else None
            close = _float(row.get("Close"))
            pcr = _float(row.get("PutCallRatio"))
            close_change = None
            pcr_change = None
            swing = None
            if previous and prev_close not in (None, 0) and close is not None:
                close_change = round((close - prev_close) * 100.0 / prev_close, 3)
            if previous and prev_pcr is not None and pcr is not None:
                pcr_change = 0.0 if prev_pcr == 0 else round((pcr - prev_pcr) * 100.0 / prev_pcr, 3)
            if close is not None and prev_close is not None and pcr_change is not None:
                if close > prev_close and pcr_change > 5:
                    swing = 0
                elif close < prev_close and pcr_change < -5:
                    swing = 1
                elif close_change is not None and abs(close_change) < 0.1 and pcr_change > 20:
                    swing = 0
                elif close_change is not None and abs(close_change) < 0.1 and pcr_change < -20:
                    swing = 1
            row["CloseChange"] = close_change
            row["PCRChange"] = pcr_change
            row["Swing"] = swing
    processing_elapsed = perf_counter() - processing_started
    processing_log = logger.warning if processing_elapsed >= SLOW_QUERY_SECONDS else logger.info
    processing_log(
        "us_market_dashboards step label=%s elapsed_ms=%.1f rows=%s slow=%s",
        "option_gex_delta_capital_type.swing_processing",
        processing_elapsed * 1000.0,
        len(rows),
        processing_elapsed >= SLOW_QUERY_SECONDS,
    )

    capital_types = [str(row.get("CapitalType")) for row in all_capital_types if row.get("CapitalType") is not None]

    raw_pre_rows = _timed_query(
        "option_gex_delta_capital_type.raw_pre_rows",
        """
        select ObservationDate, ASXCode, GEXDelta, CapitalType, [Close], VWAP
        from StockDB_US.Transform.OptionGEXChangeCapitalType_Pre with(nolock)
        where ASXCode = convert(varchar(10), ?)
          and CapitalType is not null
        order by CapitalType asc, ObservationDate asc
        """,
        (code,),
    )
    current_metrics = _option_gex_metrics(raw_rows)
    pre_metrics = _option_gex_metrics(raw_pre_rows)
    cutoff = date.fromordinal(date.today().toordinal() - 180)
    current_map = {
        (_date_str(row.get("ObservationDate")), str(row.get("CapitalType"))): row
        for row in current_metrics
        if (_date_value(row.get("ObservationDate")) or date.min) > cutoff
    }
    pre_map = {
        (_date_str(row.get("ObservationDate")), str(row.get("CapitalType"))): row
        for row in pre_metrics
        if (_date_value(row.get("ObservationDate")) or date.min) > cutoff
    }
    table_dates = sorted(
        {
            date_key
            for date_key, cap in list(current_map.keys()) + list(pre_map.keys())
            if cap == "BC"
        }
    )
    table_rows = []
    previous_close = None
    previous_bc_perc = None
    for date_key in table_dates:
        bc = current_map.get((date_key, "BC"))
        bp = current_map.get((date_key, "BP"))
        bc_pre = pre_map.get((date_key, "BC"))
        bp_pre = pre_map.get((date_key, "BP"))
        close = _float(bc.get("Close")) if bc else None
        bc_perc = _float(bc.get("GEXDeltaPerc")) if bc else None
        insight = None
        if bc_perc is not None and previous_bc_perc is not None and close is not None and previous_close is not None:
            if bc_perc < 48 and (bc_perc * 1.1) < previous_bc_perc and (close * 1.003) > previous_close:
                insight = "Down"
            elif bc_perc > 52 and (bc_perc * 0.9) > previous_bc_perc and (close * 0.997) < previous_close:
                insight = "Up"
        table_rows.append(
            {
                "ObservationDate": date_key,
                "GEXInsight": insight,
                "BC_GEXDeltaPerc": bc.get("GEXDeltaPerc") if bc else None,
                "BC_GEXDeltaPerc_Pre": bc_pre.get("GEXDeltaPerc") if bc_pre else None,
                "BP_GEXDeltaPerc": bp.get("GEXDeltaPerc") if bp else None,
                "BP_GEXDeltaPerc_Pre": bp_pre.get("GEXDeltaPerc") if bp_pre else None,
                "Close": bc.get("Close") if bc else None,
                "PreviousClose": previous_close,
                "VWAP": bc.get("VWAP") if bc else None,
                "AvgGEXDelta": bc.get("AvgGEXDelta") if bc else None,
                "NumObs": bc.get("NumObs") if bc else None,
                "ASXCode": bc.get("ASXCode") if bc else code,
            }
        )
        previous_close = close if close is not None else previous_close
        previous_bc_perc = bc_perc if bc_perc is not None else previous_bc_perc
    table_rows = _rows(list(reversed(table_rows))[:200])

    endpoint_elapsed = perf_counter() - endpoint_started
    endpoint_log = logger.warning if endpoint_elapsed >= SLOW_QUERY_SECONDS else logger.info
    endpoint_log(
        "us_market_dashboards endpoint label=%s elapsed_ms=%.1f rows=%s table_rows=%s slow=%s",
        "option_gex_delta_capital_type.total",
        endpoint_elapsed * 1000.0,
        len(rows),
        len(table_rows),
        endpoint_elapsed >= SLOW_QUERY_SECONDS,
    )

    return {
        "stock_code": code,
        "date_from": date_from.isoformat() if date_from else None,
        "date_to": _json_value(effective_to),
        "capital_types": capital_types,
        "count": len(rows),
        "rows": rows,
        "table_rows": table_rows,
    }
