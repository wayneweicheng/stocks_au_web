from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any
from datetime import date
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
import logging
import traceback

router = APIRouter(prefix="/api", tags=["breakout-watchlist"])
logger = logging.getLogger("app.breakout_watchlist")

# FIXED THRESHOLDS (now embedded in SQL stored procedure)
MIN_TURNOVER = 500000   # $500,000 Value Traded
MIN_PCT_GAIN = 8.0      # 8% Gain
MAX_PRICE = 5.00        # Penny stock filter
MAX_DAY2_INCREASE_PCT = 20.0  # Day 2 can be up to 20% higher than Day 1 if both have low volume


@router.get("/breakout-watchlist")
def get_breakout_watchlist(
    observation_date: date = Query(..., alias="date", description="Observation date, e.g. 2026-01-08"),
    refresh: bool = Query(False, description="Refresh data by recalculating stored procedure"),
    username: str = Depends(verify_credentials)
) -> List[Dict[str, Any]]:
    """
    Get breakout watch list candidates from pre-computed results.

    Returns stocks matching these patterns:
    - FRESH BREAKOUT: Stock gained 8%+ on observation date with 2x volume surge
    - CONSOLIDATION: Stock had breakout 2-3 days ago and is now consolidating

    Fixed parameters (embedded in SQL logic):
    - Min Turnover: $500,000
    - Min % Gain: 8.0%
    - Max Price: $5.00
    - Max Day 2 Increase: 20.0%

    Use refresh=true to recalculate results for the observation date.
    """
    try:
        model = get_sql_model()

        # If refresh requested, execute the stored procedure to recalculate
        if refresh:
            logger.info(f"Refreshing breakout watchlist for {observation_date} (user: {username})")
            try:
                refresh_query = "EXEC StockDB.Transform.usp_CalculateBreakoutWatchlist @ObservationDate = ?"
                model.execute_write_query(refresh_query, (observation_date,))
                logger.info(f"Successfully refreshed breakout watchlist data")
            except Exception as e:
                logger.error(f"Error refreshing data: {str(e)}")
                # Continue to try reading existing data even if refresh fails
                pass

        # Query pre-computed results
        query = """
        SELECT
            ASXCode AS Symbol,
            Pattern,
            Price,
            ChangePercent AS [Change%],
            '$' + FORMAT(VolumeValue, 'N0') AS VolumeVal,
            FORMAT(VolumeRatio, 'N1') + 'x' AS VolRatio,
            CONVERT(VARCHAR(10), ObservationDate, 120) AS Date,
            ISNULL(Note, '') AS Note,
            TomorrowChange AS [1dChange],
            Next2DaysChange AS [2dChange],
            Next5DaysChange AS [5dChange],
            Next10DaysChange AS [10dChange]
        FROM StockDB.Transform.BreakoutWatchlist
        WHERE ObservationDate = ?
        ORDER BY
            CASE WHEN Pattern = 'CONSOLIDATION' THEN 1 ELSE 2 END,
            ChangePercent DESC
        """

        logger.info(f"Querying breakout watchlist for {observation_date} (user: {username})")
        results = model.execute_read_query(query, (observation_date,))

        if not results:
            logger.info(f"No results found for {observation_date}. You may need to run the stored procedure with refresh=true")
            return []

        logger.info(f"Found {len(results)} breakout candidates")
        return results

    except Exception as e:
        logger.error(f"Error in breakout watchlist: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
