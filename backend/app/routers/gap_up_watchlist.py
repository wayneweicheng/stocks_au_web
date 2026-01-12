from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any
from datetime import date
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
import logging
import traceback

router = APIRouter(prefix="/api", tags=["gap-up-watchlist"])
logger = logging.getLogger("app.gap_up_watchlist")

# FIXED THRESHOLDS (now embedded in SQL stored procedure)
DEFAULT_GAP_PCT = 6.0          # 6% gap between today's low and yesterday's high
DEFAULT_VOLUME_MULTIPLIER = 5.0  # 5x the 20-day average
DEFAULT_MIN_VOLUME_VALUE = 600000  # $600K minimum volume value
DEFAULT_MIN_PRICE = 0.02       # Minimum price threshold
DEFAULT_CLOSE_LOCATION = 0.5   # (close-low)/(high-low) must be > 0.5


@router.get("/gap-up-watchlist")
def get_gap_up_watchlist(
    observation_date: date = Query(..., alias="date", description="Observation date, e.g. 2026-01-08"),
    refresh: bool = Query(False, description="Refresh data by recalculating stored procedure"),
    username: str = Depends(verify_credentials)
) -> List[Dict[str, Any]]:
    """
    Get gap up watchlist candidates from pre-computed results.

    Returns stocks matching these conditions:
    - Gap up 6%+ (today's low > yesterday's high)
    - Volume surge (5x 20-day average AND >= $600K)
    - Close in upper 50% of day's range
    - Bullish candle (close > open)
    - Close above 60-day high
    - Price above $0.02

    Fixed parameters (embedded in SQL logic):
    - Gap %: 6.0%
    - Volume Multiplier: 5.0x
    - Min Volume Value: $600,000
    - Min Price: $0.02
    - Close Location: 0.5

    Use refresh=true to recalculate results for the observation date.
    """
    try:
        model = get_sql_model()

        # If refresh requested, execute the stored procedure to recalculate
        if refresh:
            logger.info(f"Refreshing gap up watchlist for {observation_date} (user: {username})")
            try:
                refresh_query = "EXEC StockDB.Transform.usp_CalculateGapUpWatchlist @ObservationDate = ?"
                model.execute_write_query(refresh_query, (observation_date,))
                logger.info(f"Successfully refreshed gap up watchlist data")
            except Exception as e:
                logger.error(f"Error refreshing data: {str(e)}")
                # Continue to try reading existing data even if refresh fails
                pass

        # Query pre-computed results
        query = """
        SELECT
            ASXCode AS Symbol,
            Price,
            ChangePercent AS [Change%],
            GapUpPercent AS [GapUp%],
            '$' + FORMAT(VolumeValue, 'N0') AS VolumeVal,
            FORMAT(VolumeRatio, 'N1') + 'x' AS VolRatio,
            FORMAT(CloseLocation * 100, 'N1') + '%' AS CloseLocation,
            HighOf60Days AS [60dHigh],
            CONVERT(VARCHAR(10), ObservationDate, 120) AS Date,
            TomorrowChange AS [1dChange],
            Next2DaysChange AS [2dChange],
            Next5DaysChange AS [5dChange],
            Next10DaysChange AS [10dChange]
        FROM StockDB.Transform.GapUpWatchlist
        WHERE ObservationDate = ?
        ORDER BY GapUpPercent DESC
        """

        logger.info(f"Querying gap up watchlist for {observation_date} (user: {username})")
        results = model.execute_read_query(query, (observation_date,))

        if not results:
            logger.info(f"No results found for {observation_date}. You may need to run the stored procedure with refresh=true")
            return []

        logger.info(f"Found {len(results)} gap up candidates")
        return results

    except Exception as e:
        logger.error(f"Error in gap up watchlist: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
