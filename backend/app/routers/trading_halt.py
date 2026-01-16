from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any, Optional
from app.core.db import get_sql_model
from app.routers.auth import verify_credentials
import logging
import traceback

router = APIRouter(prefix="/api", tags=["trading-halt"])
logger = logging.getLogger("app.trading_halt")


@router.get("/trading-halt")
def get_trading_halt(
    sort_by: str = Query("Ann Date", alias="sortBy", description="Sort by: 'Ann Date' or 'MC'"),
    username: str = Depends(verify_credentials)
) -> List[Dict[str, Any]]:
    """
    Get current trading halt stocks from ASX.

    Sort options:
    - 'Ann Date': Sort by announcement date (most recent first)
    - 'MC': Sort by market cap (largest first)
    """
    try:
        model = get_sql_model()

        logger.info(f"Fetching trading halt data, sortBy={sort_by} (user: {username})")

        # Call the stored procedure
        query = "EXEC Report.usp_GetTradingHalt @pvchSortBy = ?"
        results = model.execute_read_query(query, (sort_by,))

        if not results:
            logger.info("No trading halt stocks found")
            return []

        logger.info(f"Found {len(results)} trading halt stocks")
        return results

    except Exception as e:
        logger.error(f"Error fetching trading halt data: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
