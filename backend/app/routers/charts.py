from fastapi import APIRouter, HTTPException, Query, Depends
from fastapi.responses import FileResponse
from typing import Optional
from pathlib import Path
import os
from app.core.config import settings
from app.routers.auth import verify_credentials


router = APIRouter(prefix="/charts", tags=["charts"])


def resolve_chart_path(relative_or_full_path: str) -> Path:
    base = settings.chart_base_url.strip()
    # If the provided path is absolute, try it directly; otherwise, join with base
    candidate = Path(relative_or_full_path)
    if candidate.is_absolute():
        return candidate
    if not base:
        return candidate
    return Path(base) / relative_or_full_path


@router.get("")
def get_chart(
    path: str = Query(..., description="Relative or absolute chart file path"),
    username: str = Depends(verify_credentials),
):
    try:
        full_path = resolve_chart_path(path)
        # Basic path traversal protection: resolve and ensure inside base if base provided
        base = settings.chart_base_url.strip()
        if base:
            base_path = Path(base).resolve()
            resolved = full_path.resolve()
            if base_path not in resolved.parents and resolved != base_path:
                raise HTTPException(status_code=400, detail="Invalid chart path")

        if not full_path.exists() or not full_path.is_file():
            raise HTTPException(status_code=404, detail="Chart not found")

        # Let FastAPI infer media type; common chart formats: png, jpg, svg, etc.
        return FileResponse(str(full_path))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


