"""Broker Analysis API Router."""
from datetime import date, timedelta
from decimal import Decimal
from typing import Any, Dict, List

import pyodbc
from fastapi import APIRouter, HTTPException, Query

from app.core.db import get_db_connection

router = APIRouter(prefix="/api/broker-analysis", tags=["broker-analysis"])

SORT_OPTIONS = {
    "NetValuevsMC",
    "NetVolumevsTradeVolume",
    "MarketCap",
    "NetValue",
    "ASXCode",
}

BUY_SELL_PERC_SORT_OPTIONS = {
    "Buy Perc Desc",
    "Sell Perc Desc",
}


def _serialise_row_value(value: Any) -> Any:
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, date):
        return value.isoformat()
    return value


def _rows_to_dicts(cursor: pyodbc.Cursor) -> List[Dict[str, Any]]:
    columns = [column[0] for column in cursor.description]
    return [
        {column: _serialise_row_value(value) for column, value in zip(columns, row)}
        for row in cursor.fetchall()
    ]


def _weekday_span(start_date: date, end_date: date) -> int:
    days = 0
    current = end_date
    while current > start_date:
        current -= timedelta(days=1)
        if current.weekday() < 5:
            days += 1
    return days


@router.get("/broker-codes")
async def get_broker_codes() -> List[Dict[str, Any]]:
    """
    Get list of all broker codes
    Calls: Report.usp_GetBrokerCode
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Execute stored procedure
        cursor.execute("""
            DECLARE @pintErrorNumber INT;
            EXEC Report.usp_GetBrokerCode @pintErrorNumber = @pintErrorNumber OUTPUT;
            SELECT @pintErrorNumber as ErrorNumber;
        """)

        results = _rows_to_dicts(cursor)

        if len(results) <= 1:
            cursor.execute("""
                SELECT DISTINCT
                    BrokerCode,
                    BrokerCode AS BrokerName,
                    2 AS RankOrder
                FROM StockData.BrokerReport
                WHERE BrokerCode IS NOT NULL
                    AND LTRIM(RTRIM(BrokerCode)) <> ''
                ORDER BY BrokerCode;
            """)
            broker_report_codes = _rows_to_dicts(cursor)
            if broker_report_codes:
                results = [
                    {
                        "BrokerCode": "All",
                        "BrokerName": "All Brokers",
                        "RankOrder": 1,
                    },
                    *broker_report_codes,
                ]

        cursor.close()
        conn.close()

        return results

    except pyodbc.Error as e:
        raise HTTPException(
            status_code=500, detail=f"Database error: {str(e)}"
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Error fetching broker codes: {str(e)}"
        ) from e


@router.get("/analysis")
async def get_broker_analysis(
    sort_by: str = Query(
        "NetValuevsMC",
        description=(
            "Sort column: NetValuevsMC, NetVolumevsTradeVolume, "
            "MarketCap, NetValue, ASXCode"
        ),
    ),
    start_date: date | None = Query(
        None, description="Inclusive broker observation start date"
    ),
    end_date: date | None = Query(
        None, description="Inclusive broker observation end date"
    ),
    broker_code: str = Query(
        "BelPot", description="Broker code to filter by"
    ),
) -> List[Dict[str, Any]]:
    """
    Get broker analysis data showing buy suggestions
    Calls: Report.usp_Get_BrokerBuySuggestion

    Parameters:
    - sort_by: Column to sort by
    - start_date: Inclusive observation start date
    - end_date: Inclusive observation end date
    - broker_code: Broker code to analyze
    """
    if sort_by not in SORT_OPTIONS:
        raise HTTPException(
            status_code=400,
            detail=f"sort_by must be one of: {', '.join(sorted(SORT_OPTIONS))}",
        )
    if start_date and end_date and start_date > end_date:
        raise HTTPException(
            status_code=400, detail="start_date must be on or before end_date"
        )

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            DECLARE @pintErrorNumber INT;
            EXEC Report.usp_Get_BrokerBuySuggestion
                @pvchSortBy = ?,
                @pvchbrokerCode = ?,
                @pdtStartDate = ?,
                @pdtEndDate = ?,
                @pintErrorNumber = @pintErrorNumber OUTPUT;
            SELECT @pintErrorNumber as ErrorNumber;
        """, sort_by, broker_code, start_date, end_date)

        results = _rows_to_dicts(cursor)

        cursor.close()
        conn.close()

        return results

    except pyodbc.Error as e:
        raise HTTPException(
            status_code=500, detail=f"Database error: {str(e)}"
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Error fetching broker analysis: {str(e)}"
        ) from e


@router.get("/buy-sell-percentage")
async def get_broker_buy_sell_percentage(
    sort_by: str = Query(
        "Buy Perc Desc",
        description="Sort option: Buy Perc Desc or Sell Perc Desc",
    ),
    num_prev_day: int = Query(
        0,
        ge=0,
        le=260,
        description="Number of previous business days before the end date",
    ),
    broker_code: str = Query(
        "BelPot", description="Broker code to filter by"
    ),
    observation_end_date: date | None = Query(
        None,
        description="Observation end date. Omit to use the latest broker observation date.",
    ),
    observation_start_date: date | None = Query(
        None,
        description="Optional start date. When supplied, it is converted to previous weekdays.",
    ),
) -> List[Dict[str, Any]]:
    """
    Get broker buy/sell percentage data.
    Calls: Report.usp_GetBrokerBuySellPerc
    """
    if sort_by not in BUY_SELL_PERC_SORT_OPTIONS:
        raise HTTPException(
            status_code=400,
            detail=(
                "sort_by must be one of: "
                f"{', '.join(sorted(BUY_SELL_PERC_SORT_OPTIONS))}"
            ),
        )
    if (
        observation_start_date
        and observation_end_date
        and observation_start_date > observation_end_date
    ):
        raise HTTPException(
            status_code=400,
            detail="observation_start_date must be on or before observation_end_date",
        )

    effective_num_prev_day = num_prev_day
    if observation_start_date and observation_end_date:
        effective_num_prev_day = _weekday_span(
            observation_start_date, observation_end_date
        )

    effective_end_date = (
        observation_end_date.isoformat() if observation_end_date else "2050-12-12"
    )

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            DECLARE @pintErrorNumber INT;
            EXEC Report.usp_GetBrokerBuySellPerc
                @pvchSortBy = ?,
                @pvchbrokerCode = ?,
                @pintNumPrevDay = ?,
                @pdtObservationDateEnd = ?,
                @pintErrorNumber = @pintErrorNumber OUTPUT;
            SELECT @pintErrorNumber as ErrorNumber;
        """, sort_by, broker_code, effective_num_prev_day, effective_end_date)

        results = _rows_to_dicts(cursor)

        cursor.close()
        conn.close()

        return results

    except pyodbc.Error as e:
        raise HTTPException(
            status_code=500, detail=f"Database error: {str(e)}"
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error fetching broker buy/sell percentage: {str(e)}",
        ) from e
