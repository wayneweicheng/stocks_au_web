from fastapi import APIRouter, Depends, HTTPException
from typing import List, Dict
from app.routers.auth import verify_credentials
from app.core.db import get_sql_model
import logging

router = APIRouter(prefix="/api", tags=["stock-codes"])
logger = logging.getLogger("app.stock_codes")


@router.get("/stock-codes")
def get_stock_codes(
    username: str = Depends(verify_credentials),
) -> List[Dict[str, str]]:
    """
    Returns list of stock codes with their latest observation dates.

    Returns:
        List of dicts with stock_code and latest_date
    """
    try:
        sql_model = get_sql_model()

        query = """
            SELECT ASXCode, MAX(ObservationDate) as LatestObservationDate
            FROM StockDB_US.Analysis.GEX_Features
            GROUP BY ASXCode
            ORDER BY ASXCode
        """

        rows = sql_model.execute_read_usp(query, ())

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
