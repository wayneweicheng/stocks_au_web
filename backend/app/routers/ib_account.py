from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Any, Dict, Optional

from app.services.ib_account_service import get_account_risk
from .auth import verify_credentials


router = APIRouter(prefix="/api/ib", tags=["ib-account"], dependencies=[Depends(verify_credentials)])


@router.get("/account-risk")
def account_risk(account: Optional[str] = Query(default=None)) -> Dict[str, Any]:
    try:
        return get_account_risk(account=account)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to load IB account risk: {exc}")
