from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any
from datetime import date
from app.routers.auth import verify_credentials
from app.services.signal_strength_db_service import SignalStrengthDBService
import logging

router = APIRouter(prefix="/api", tags=["signal-strength"])
logger = logging.getLogger("app.signal_strength")


@router.get("/signal-strength")
def get_signal_strengths(
    observation_date: date = Query(..., description="Observation date to retrieve signal strengths for"),
    username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
    """
    Get all signal strength classifications for a given observation date.

    Used by the frontend to display the signal strength matrix visualization.

    Args:
        observation_date: Date to retrieve signal strengths for
        username: Authenticated username (injected by dependency)

    Returns:
        List of signal strength records:
        [
          {
            "stock_code": "NVDA",
            "signal_strength_level": "STRONGLY_BULLISH",
            "created_at": "2025-01-15T10:30:00",
            "updated_at": "2025-01-15T10:30:00"
          },
          ...
        ]
    """
    try:
        db_service = SignalStrengthDBService()
        results = db_service.get_signal_strengths_by_date(observation_date)

        logger.info(
            f"Retrieved {len(results)} signal strength records for {observation_date} (user: {username})"
        )

        return results

    except Exception as e:
        logger.error(f"Error retrieving signal strengths for {observation_date}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve signal strength data")
