"""
Broker Analysis API Router
Provides endpoints for broker buy/sell analysis and suggestions
"""
from typing import Any, Dict, List

import pyodbc
from fastapi import APIRouter, HTTPException, Query

from app.core.db import get_db_connection

router = APIRouter(prefix="/api/broker-analysis", tags=["broker-analysis"])


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

        # Get the result set
        columns = [column[0] for column in cursor.description]
        results = []
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))

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
    num_prev_day: int = Query(
        0, ge=0, description="Number of previous days from today"
    ),
    broker_code: str = Query(
        "Macquarie Securities", description="Broker code to filter by"
    ),
) -> List[Dict[str, Any]]:
    """
    Get broker analysis data showing buy suggestions
    Calls: Report.usp_Get_BrokerBuySuggestion

    Parameters:
    - sort_by: Column to sort by
    - num_prev_day: Number of days back from today (0 = today)
    - broker_code: Broker code to analyze
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Execute stored procedure
        cursor.execute("""
            DECLARE @pintErrorNumber INT;
            EXEC Report.usp_Get_BrokerBuySuggestion
                @pvchSortBy = ?,
                @pvchbrokerCode = ?,
                @pintNumPrevDay = ?,
                @pintErrorNumber = @pintErrorNumber OUTPUT;
            SELECT @pintErrorNumber as ErrorNumber;
        """, sort_by, broker_code, num_prev_day)

        # Get the result set
        columns = [column[0] for column in cursor.description]
        results = []
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))

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
