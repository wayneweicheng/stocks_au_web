from datetime import date
from decimal import Decimal
from typing import Any, Dict, List, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.db import get_sql_model
from app.routers.auth import verify_credentials


router = APIRouter(
    prefix="/api/us-market-dashboards",
    tags=["us-market-dashboards"],
    dependencies=[Depends(verify_credentials)],
)


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


def _query(sql: str, params: Tuple[Any, ...]) -> List[Dict[str, Any]]:
    try:
        return get_sql_model().execute_read_query(sql, params) or []
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Database query failed: {exc}")


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
        where.append("ObservationDate >= ?")
        params.append(date_from.isoformat())
    elif effective_to:
        where.append("ObservationDate >= dateadd(year, -1, ?)")
        params.append(_json_value(effective_to))
    if effective_to:
        where.append("ObservationDate <= ?")
        params.append(_json_value(effective_to))
    if market_cap:
        where.append(f"MarketCap in ({','.join(['?'] * len(market_cap))})")
        params.extend(market_cap)

    all_capital_types = _rows(
        _query(
            """
            select distinct CapitalType
            from StockDB_US.Transform.v_OptionGexChangeCapitalType with(nolock)
            where UPPER(ASXCode) = UPPER(?)
              and CapitalType is not null
            order by CapitalType asc
            """,
            (code,),
        )
    )

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
            where UPPER(ASXCode) = UPPER(?)
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
            where UPPER(ASXCode) = UPPER(?)
              and ObservationDate = ?
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
            where UPPER(ASXCode) = UPPER(?)
              and ObservationDate = ?
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
        where UPPER(ASXCode) = UPPER(?)
        """,
        (code,),
    )
    effective_to = date_to or (latest[0].get("observation_date") if latest else None)

    where = ["UPPER(ASXCode) = UPPER(?)"]
    params: List[Any] = [code]
    if date_from:
        where.append("ObservationDate >= ?")
        params.append(date_from.isoformat())
    elif effective_to:
        where.append("ObservationDate >= dateadd(year, -1, ?)")
        params.append(_json_value(effective_to))
    if effective_to:
        where.append("ObservationDate <= ?")
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
            where UPPER(ASXCode) = UPPER(?)
              and ObservationDate = ?
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

    latest = _query(
        """
        select max(ObservationDate) as observation_date
        from StockDB_US.Transform.v_OptionGexChangeCapitalType with(nolock)
        where UPPER(ASXCode) = UPPER(?)
          and [Close] is not null
        """,
        (code,),
    )
    effective_to = date_to or (latest[0].get("observation_date") if latest else None)

    where = ["UPPER(ASXCode) = UPPER(?)", "[Close] is not null"]
    params: List[Any] = [code]
    if date_from:
        where.append("ObservationDate >= ?")
        params.append(date_from.isoformat())
    elif effective_to:
        where.append("ObservationDate >= dateadd(day, -180, ?)")
        params.append(_json_value(effective_to))
    if effective_to:
        where.append("ObservationDate <= ?")
        params.append(_json_value(effective_to))
    if capital_type:
        where.append(f"CapitalType in ({','.join(['?'] * len(capital_type))})")
        params.extend(capital_type)

    rows = _rows(
        _query(
            f"""
            select ObservationDate, NormGEXDelta, ZScoreGEXDelta, CapitalType,
                   abs(GEXDelta) as GEXDelta, abs(CumulativeDelta) as CumulativeDelta,
                   GEXDeltaPerc, PutCallRatio, [Close], VWAP, AvgGEXDelta, NumObs, ASXCode
            from StockDB_US.Transform.v_OptionGexChangeCapitalType with(nolock)
            where {' and '.join(where)}
            order by ObservationDate asc, CapitalType asc
            """,
            tuple(params),
        )
    )

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

    capital_types = [str(row.get("CapitalType")) for row in all_capital_types if row.get("CapitalType") is not None]

    table_rows = _rows(
        _query(
            """
            with current_gex as (
                select *
                from StockDB_US.Transform.v_OptionGexChangeCapitalType with(nolock)
                where UPPER(ASXCode) = UPPER(?)
                  and ObservationDate > dateadd(day, -180, getdate())
            ),
            pre_gex as (
                select *
                from StockDB_US.Transform.v_OptionGexChangeCapitalType_Pre with(nolock)
                where UPPER(ASXCode) = UPPER(?)
                  and ObservationDate > dateadd(day, -180, getdate())
            ),
            base_data as (
                select x.ObservationDate,
                       a.GEXDeltaPerc as BC_GEXDeltaPerc,
                       c.GEXDeltaPerc as BC_GEXDeltaPerc_Pre,
                       b.GEXDeltaPerc as BP_GEXDeltaPerc,
                       d.GEXDeltaPerc as BP_GEXDeltaPerc_Pre,
                       a.[Close], a.VWAP, a.AvgGEXDelta, a.NumObs, a.ASXCode
                from (
                    select ObservationDate, ASXCode from current_gex where CapitalType = 'BC'
                    union
                    select ObservationDate, ASXCode from pre_gex where CapitalType = 'BC'
                ) as x
                left join current_gex as a on x.ASXCode = a.ASXCode and x.ObservationDate = a.ObservationDate and a.CapitalType = 'BC'
                left join current_gex as b on x.ASXCode = b.ASXCode and x.ObservationDate = b.ObservationDate and b.CapitalType = 'BP'
                left join pre_gex as c on x.ASXCode = c.ASXCode and x.ObservationDate = c.ObservationDate and c.CapitalType = 'BC'
                left join pre_gex as d on x.ASXCode = d.ASXCode and x.ObservationDate = d.ObservationDate and d.CapitalType = 'BP'
            ),
            lagged_data as (
                select *, lag([Close]) over (order by ObservationDate asc) as PreviousClose,
                       lag(BC_GEXDeltaPerc) over (order by ObservationDate asc) as Prev_BC_GEXDeltaPerc
                from base_data
            )
            select top (200) ObservationDate,
                   case
                       when BC_GEXDeltaPerc < 48 and (BC_GEXDeltaPerc * 1.1) < Prev_BC_GEXDeltaPerc and ([Close] * 1.003) > PreviousClose then 'Down'
                       when BC_GEXDeltaPerc > 52 and (BC_GEXDeltaPerc * 0.9) > Prev_BC_GEXDeltaPerc and ([Close] * 0.997) < PreviousClose then 'Up'
                       else null
                   end as GEXInsight,
                   BC_GEXDeltaPerc, BC_GEXDeltaPerc_Pre, BP_GEXDeltaPerc, BP_GEXDeltaPerc_Pre,
                   [Close], PreviousClose, VWAP, AvgGEXDelta, NumObs, ASXCode
            from lagged_data
            order by ObservationDate desc
            """,
            (code, code),
        )
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
