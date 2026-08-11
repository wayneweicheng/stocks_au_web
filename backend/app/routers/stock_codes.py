from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Dict, Optional
from datetime import date
from pydantic import BaseModel
from app.routers.auth import verify_credentials
from app.core.db import get_sql_model
import logging

router = APIRouter(prefix="/api", tags=["stock-codes"])
logger = logging.getLogger("app.stock_codes")
OPTION_FLOW_AGGREGATE_QUERY_TIMEOUT_SECONDS = 60


class OptionFlowAggregateRow(BaseModel):
    ASXCode: str
    NumRecords: int
    NumOptions: int
    in_market_flow: bool = False


class OptionFlowAggregatesResponse(BaseModel):
    trades: List[OptionFlowAggregateRow]
    bidask: List[OptionFlowAggregateRow]


def _set_option_flow_aggregate_query_timeout(sql_model) -> None:
    cursor = getattr(sql_model, "cursor", None)
    if cursor is not None and hasattr(cursor, "timeout"):
        cursor.timeout = OPTION_FLOW_AGGREGATE_QUERY_TIMEOUT_SECONDS


def _build_option_flow_aggregate_query(view_name: str) -> str:
    """Build an aggregate query with a same-ticker, same-date Market Flow join."""
    return f"""
        SELECT option_rows.ASXCode,
               COUNT(*) AS NumRecords,
               COUNT(DISTINCT option_rows.OptionSymbol) AS NumOptions,
               CAST(CASE WHEN market_flow.ASXCode IS NULL THEN 0 ELSE 1 END AS bit) AS in_market_flow
        FROM {view_name} AS option_rows WITH (NOLOCK)
        LEFT JOIN (
            SELECT ASXCode, ObservationDate
            FROM StockDB_US.Analysis.GEX_Features WITH (NOLOCK)
            WHERE ObservationDate = convert(date, ?)
            GROUP BY ASXCode, ObservationDate
        ) AS market_flow
          ON market_flow.ASXCode = option_rows.ASXCode
         AND market_flow.ObservationDate = option_rows.ObservationDate
        WHERE option_rows.ObservationDate = convert(date, ?)
        GROUP BY option_rows.ASXCode, option_rows.ObservationDate, market_flow.ASXCode
        ORDER BY option_rows.ASXCode
    """


def _get_option_flow_aggregate_rows(sql_model, view_name: str, observation_date: date) -> List[Dict]:
    query = _build_option_flow_aggregate_query(view_name)
    return sql_model.execute_read_query(query, (observation_date, observation_date))


@router.get("/stock-codes")
def get_stock_codes(
    observation_date: Optional[date] = Query(None, alias="observation_date", description="Optional filter: only include codes that have data on this date (YYYY-MM-DD)"),
    source_type: str = Query("GEX", description="Data source for stock codes: GEX or OPTION_TRADES"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, str]]:
    """
    Returns list of stock codes.
    - If observation_date is provided, only return codes that have data on that date.
      latest_date will reflect the latest row for that code on that date (i.e. the same date).
    - If observation_date is not provided, return all codes with their overall latest dates.

    Returns:
        List of dicts with stock_code and latest_date
    """
    try:
        sql_model = get_sql_model()

        source = (source_type or "GEX").upper()
        if source == "OPTION_TRADES":
            if observation_date:
                query = """
                    SELECT ASXCode, MAX(ObservationDate) as LatestObservationDate
                    FROM StockDB_US.StockData.v_OptionTrade
                    WHERE ObservationDate = convert(date, ?)
                      AND Size > 300
                    GROUP BY ASXCode
                    ORDER BY ASXCode
                """
                rows = sql_model.execute_read_query(query, (observation_date,))
            else:
                query = """
                    SELECT ASXCode, MAX(ObservationDate) as LatestObservationDate
                    FROM StockDB_US.StockData.v_OptionTrade
                    WHERE Size > 300
                    GROUP BY ASXCode
                    ORDER BY ASXCode
                """
                rows = sql_model.execute_read_query(query, ())
        else:
            if observation_date:
                query = """
                    SELECT ASXCode, MAX(ObservationDate) as LatestObservationDate
                    FROM StockDB_US.Analysis.GEX_Features
                    WHERE ObservationDate = convert(date, ?)
                    GROUP BY ASXCode
                    ORDER BY ASXCode
                """
                # Use execute_read_query to pass parameters safely
                rows = sql_model.execute_read_query(query, (observation_date,))
            else:
                query = """
                    SELECT ASXCode, MAX(ObservationDate) as LatestObservationDate
                    FROM StockDB_US.Analysis.GEX_Features
                    GROUP BY ASXCode
                    ORDER BY ASXCode
                """
                # Keep existing behavior for the unfiltered list
                rows = sql_model.execute_read_query(query, ())

        result = []
        for row in rows:
            stock_code = row.get("ASXCode", "")
            latest_date = row.get("LatestObservationDate")

            # Format date as string
            if latest_date:
                if hasattr(latest_date, 'strftime'):
                    latest_date_str = latest_date.strftime('%Y-%m-%d')
                else:
                    latest_date_str = str(latest_date)[:10]
            else:
                latest_date_str = "N/A"

            result.append({
                "stock_code": stock_code,
                "latest_date": latest_date_str
            })

        logger.info(f"Retrieved {len(result)} stock codes")
        return result

    except Exception as e:
        logger.error(f"Failed to retrieve stock codes: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve stock codes")


@router.get("/option-flow-aggregates", response_model=OptionFlowAggregatesResponse)
def get_option_flow_aggregates(
    observation_date: date = Query(..., alias="observation_date", description="Observation date (YYYY-MM-DD)"),
    username: str = Depends(verify_credentials),
) -> OptionFlowAggregatesResponse:
    """
    Returns aggregated counts by ASXCode for option trades and option bid/ask on the given observation_date.

    Response shape:
    {
      "trades": [ { "ASXCode": "ABC", "NumRecords": 123, "NumOptions": 45, "in_market_flow": true }, ... ],
      "bidask": [ { "ASXCode": "ABC", "NumRecords": 234, "NumOptions": 67, "in_market_flow": true }, ... ]
    }
    """
    try:
        sql_model = get_sql_model()
        _set_option_flow_aggregate_query_timeout(sql_model)

        trades = _get_option_flow_aggregate_rows(
            sql_model,
            "StockDB_US.StockData.v_OptionTrade",
            observation_date,
        )
        bidask = _get_option_flow_aggregate_rows(
            sql_model,
            "StockDB_US.StockData.v_OptionBidAsk",
            observation_date,
        )

        return OptionFlowAggregatesResponse(
            trades=trades,
            bidask=bidask,
        )
    except Exception as e:
        logger.error(f"Failed to retrieve option flow aggregates: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve option flow aggregates")
