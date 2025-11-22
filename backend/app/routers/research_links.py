from fastapi import APIRouter, Query, Depends, HTTPException
from pydantic import BaseModel, HttpUrl
from typing import Any, Dict, List, Optional
from app.routers.auth import verify_credentials
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel


router = APIRouter(prefix="/api", tags=["research-links"])


class ResearchLinkCreate(BaseModel):
    stock_code: str
    url: HttpUrl


class ResearchLink(BaseModel):
    id: int
    stock_code: str
    url: str
    added_at: str
    added_by: Optional[str] = None


class ResearchLinkPage(BaseModel):
    items: List[ResearchLink]
    total: int
    page: int
    page_size: int


def _rows_to_dicts(cursor) -> List[Dict[str, Any]]:
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


@router.get("/research-links", response_model=ResearchLinkPage)
def list_research_links(
    q: Optional[str] = Query(default=None, description="Search by stock code"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=10, ge=1, le=100),
    username: str = Depends(verify_credentials),
) -> ResearchLinkPage:
    try:
        db = SQLServerModel(database="StockDB")
        filters = []
        params: List[Any] = []
        if q:
            filters.append("StockCode LIKE ?")
            params.append(f"%{q}%")

        where_sql = f"WHERE {' AND '.join(filters)}" if filters else ""

        # Total count
        total_rows = db.execute_read_usp(
            f"SELECT COUNT(*) as total FROM [Research].[ResearchLink] {where_sql}",
            tuple(params),
        ) or []
        total = int(total_rows[0]["total"]) if total_rows and "total" in total_rows[0] else 0

        # Pagination query
        offset = (page - 1) * page_size
        rows = db.execute_read_usp(
            f"""
            SELECT
                ResearchLinkID as id,
                StockCode as stock_code,
                Url as url,
                CONVERT(varchar(19), AddedAt, 126) as added_at, -- ISO 8601 without timezone
                AddedBy as added_by
            FROM [Research].[ResearchLink]
            {where_sql}
            ORDER BY AddedAt DESC
            OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
            """,
            tuple(params + [offset, page_size]),
        ) or []

        # Normalize ISO timestamp for frontend
        for r in rows:
            if isinstance(r.get("added_at"), str) and len(r["added_at"]) == 19:
                r["added_at"] += "Z"

        return ResearchLinkPage(items=rows, total=total, page=page, page_size=page_size)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list research links: {str(e)}")


@router.post("/research-links", response_model=ResearchLink)
def create_research_link(
    payload: ResearchLinkCreate,
    username: str = Depends(verify_credentials),
) -> ResearchLink:
    try:
        db = SQLServerModel(database="StockDB")

        # Insert the row
        db.execute_update_usp(
            """
            INSERT INTO [Research].[ResearchLink] (StockCode, Url, AddedBy)
            VALUES (?, ?, ?)
            """,
            (payload.stock_code.strip().upper(), str(payload.url), username),
        )

        # Read back the inserted row (latest match for safety)
        rows = db.execute_read_usp(
            """
            SELECT TOP 1
                ResearchLinkID as id,
                StockCode as stock_code,
                Url as url,
                CONVERT(varchar(19), AddedAt, 126) as added_at,
                AddedBy as added_by
            FROM [Research].[ResearchLink]
            WHERE StockCode = ? AND Url = ?
            ORDER BY AddedAt DESC
            """,
            (payload.stock_code.strip().upper(), str(payload.url)),
        ) or []

        if not rows:
            raise HTTPException(status_code=500, detail="Insert succeeded but could not read back inserted row")

        row = rows[0]
        if isinstance(row.get("added_at"), str) and len(row["added_at"]) == 19:
            row["added_at"] += "Z"

        return row  # type: ignore
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create research link: {str(e)}")


