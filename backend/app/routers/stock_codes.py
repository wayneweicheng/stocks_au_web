from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Dict, Optional
from datetime import date
from app.routers.auth import verify_credentials
from app.core.db import get_sql_model
import logging

router = APIRouter(prefix="/api", tags=["stock-codes"])
logger = logging.getLogger("app.stock_codes")


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
                    WHERE CAST(ObservationDate AS date) = ?
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
                    WHERE CAST(ObservationDate AS date) = ?
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
