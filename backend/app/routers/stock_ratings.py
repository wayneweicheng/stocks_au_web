from fastapi import APIRouter, Query, Depends, HTTPException
from pydantic import BaseModel
from typing import Any, Dict, List, Optional
from enum import Enum
from app.routers.auth import verify_credentials
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel


router = APIRouter(prefix="/api", tags=["stock-ratings"])


class RatingType(str, Enum):
    BULLISH = "Bullish"
    NEUTRAL = "Neutral"
    BEARISH = "Bearish"


class StockRatingCreate(BaseModel):
    stock_code: str
    commenter_id: int
    rating: RatingType
    comment: Optional[str] = None
    rating_date: Optional[str] = None  # ISO date string YYYY-MM-DD


class StockRatingUpdate(BaseModel):
    rating: Optional[RatingType] = None
    comment: Optional[str] = None
    rating_date: Optional[str] = None


class StockRating(BaseModel):
    id: int
    stock_code: str
    commenter_id: int
    commenter_name: str
    rating: str
    comment: Optional[str] = None
    rating_date: str
    added_at: str
    added_by: Optional[str] = None


class StockRatingPage(BaseModel):
    items: List[StockRating]
    total: int
    page: int
    page_size: int


class StockSummary(BaseModel):
    stock_code: str
    total_ratings: int
    bullish_count: int
    neutral_count: int
    bearish_count: int
    ratings: List[StockRating]


class TippedStock(BaseModel):
    stock_code: str
    total_ratings: int
    bullish_count: int
    bullish_commenters_count: int
    neutral_count: int
    bearish_count: int
    latest_rating_date: str


class TippedStocksList(BaseModel):
    items: List[TippedStock]
    total: int
    page: int
    page_size: int


@router.get("/stock-ratings", response_model=StockRatingPage)
def list_stock_ratings(
    stock_code: Optional[str] = Query(default=None, description="Filter by stock code"),
    commenter_id: Optional[int] = Query(default=None, description="Filter by commenter"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    username: str = Depends(verify_credentials),
) -> StockRatingPage:
    try:
        db = SQLServerModel(database="StockDB")
        filters = []
        params: List[Any] = []

        if stock_code:
            filters.append("sr.StockCode = ?")
            params.append(stock_code.strip().upper())

        if commenter_id:
            filters.append("sr.CommenterID = ?")
            params.append(commenter_id)

        where_sql = f"WHERE {' AND '.join(filters)}" if filters else ""

        # Total count
        total_rows = db.execute_read_usp(
            f"""
            SELECT COUNT(*) as total
            FROM [Research].[StockRating] sr
            {where_sql}
            """,
            tuple(params),
        ) or []
        total = int(total_rows[0]["total"]) if total_rows and "total" in total_rows[0] else 0

        # Pagination query
        offset = (page - 1) * page_size
        rows = db.execute_read_usp(
            f"""
            SELECT
                sr.StockRatingID as id,
                sr.StockCode as stock_code,
                sr.CommenterID as commenter_id,
                c.Name as commenter_name,
                sr.Rating as rating,
                sr.Comment as comment,
                CONVERT(varchar(10), sr.RatingDate, 23) as rating_date,
                CONVERT(varchar(19), sr.AddedAt, 126) as added_at,
                sr.AddedBy as added_by
            FROM [Research].[StockRating] sr
            INNER JOIN [Research].[Commenter] c ON sr.CommenterID = c.CommenterID
            {where_sql}
            ORDER BY sr.RatingDate DESC, sr.AddedAt DESC
            OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
            """,
            tuple(params + [offset, page_size]),
        ) or []

        for r in rows:
            if isinstance(r.get("added_at"), str) and len(r["added_at"]) == 19:
                r["added_at"] += "Z"

        return StockRatingPage(items=rows, total=total, page=page, page_size=page_size)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list stock ratings: {str(e)}")


@router.get("/stock-ratings/tipped-stocks", response_model=TippedStocksList)
def list_tipped_stocks(
    sort_by: str = Query(default="bullish_commenters", description="Sort by 'bullish_commenters' or 'latest'"),
    sort_dir: str = Query(default="desc", description="Sort direction 'asc' or 'desc' (applies to 'latest')"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=30, ge=1, le=100),
    username: str = Depends(verify_credentials),
) -> TippedStocksList:
    """Get all stocks that have ratings, with aggregated counts"""
    try:
        db = SQLServerModel(database="StockDB")

        # Total distinct stocks
        total_rows = db.execute_read_usp(
            "SELECT COUNT(DISTINCT StockCode) as total FROM [Research].[StockRating]",
            (),
        ) or []
        total = int(total_rows[0]["total"]) if total_rows and "total" in total_rows[0] else 0

        # Validate sort options
        sort_by_normalized = (sort_by or "").lower()
        sort_dir_normalized = (sort_dir or "").lower()
        if sort_by_normalized not in ("bullish_commenters", "latest"):
            sort_by_normalized = "bullish_commenters"
        if sort_dir_normalized not in ("asc", "desc"):
            sort_dir_normalized = "desc"

        # Build ORDER BY safely from whitelist
        if sort_by_normalized == "bullish_commenters":
            order_clause = "ORDER BY COUNT(DISTINCT CASE WHEN Rating = 'Bullish' THEN CommenterID END) DESC, StockCode ASC"
        else:
            # latest
            order_clause = f"ORDER BY MAX(RatingDate) {sort_dir_normalized.upper()}, StockCode ASC"

        offset = (page - 1) * page_size
        rows = db.execute_read_usp(
            f"""
            SELECT
                StockCode as stock_code,
                COUNT(*) as total_ratings,
                SUM(CASE WHEN Rating = 'Bullish' THEN 1 ELSE 0 END) as bullish_count,
                COUNT(DISTINCT CASE WHEN Rating = 'Bullish' THEN CommenterID END) as bullish_commenters_count,
                SUM(CASE WHEN Rating = 'Neutral' THEN 1 ELSE 0 END) as neutral_count,
                SUM(CASE WHEN Rating = 'Bearish' THEN 1 ELSE 0 END) as bearish_count,
                CONVERT(varchar(10), MAX(RatingDate), 23) as latest_rating_date
            FROM [Research].[StockRating]
            GROUP BY StockCode
            {order_clause}
            OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
            """,
            (offset, page_size),
        ) or []

        return TippedStocksList(items=rows, total=total, page=page, page_size=page_size)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list tipped stocks: {str(e)}")


@router.get("/stock-ratings/summary/{stock_code}", response_model=StockSummary)
def get_stock_summary(
    stock_code: str,
    username: str = Depends(verify_credentials),
) -> StockSummary:
    """Get a summary of all ratings for a specific stock"""
    try:
        db = SQLServerModel(database="StockDB")
        normalized_code = stock_code.strip().upper()

        # Get all ratings for this stock
        rows = db.execute_read_usp(
            """
            SELECT
                sr.StockRatingID as id,
                sr.StockCode as stock_code,
                sr.CommenterID as commenter_id,
                c.Name as commenter_name,
                sr.Rating as rating,
                sr.Comment as comment,
                CONVERT(varchar(10), sr.RatingDate, 23) as rating_date,
                CONVERT(varchar(19), sr.AddedAt, 126) as added_at,
                sr.AddedBy as added_by
            FROM [Research].[StockRating] sr
            INNER JOIN [Research].[Commenter] c ON sr.CommenterID = c.CommenterID
            WHERE sr.StockCode = ?
            ORDER BY sr.RatingDate DESC, sr.AddedAt DESC
            """,
            (normalized_code,),
        ) or []

        for r in rows:
            if isinstance(r.get("added_at"), str) and len(r["added_at"]) == 19:
                r["added_at"] += "Z"

        # Calculate counts
        bullish_count = sum(1 for r in rows if r["rating"] == "Bullish")
        neutral_count = sum(1 for r in rows if r["rating"] == "Neutral")
        bearish_count = sum(1 for r in rows if r["rating"] == "Bearish")

        return StockSummary(
            stock_code=normalized_code,
            total_ratings=len(rows),
            bullish_count=bullish_count,
            neutral_count=neutral_count,
            bearish_count=bearish_count,
            ratings=rows,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get stock summary: {str(e)}")


@router.post("/stock-ratings", response_model=StockRating)
def create_stock_rating(
    payload: StockRatingCreate,
    username: str = Depends(verify_credentials),
) -> StockRating:
    try:
        db = SQLServerModel(database="StockDB")

        # Verify commenter exists and is active
        commenter = db.execute_read_usp(
            "SELECT CommenterID, Name FROM [Research].[Commenter] WHERE CommenterID = ? AND IsActive = 1",
            (payload.commenter_id,),
        ) or []

        if not commenter:
            raise HTTPException(status_code=400, detail="Commenter not found or is inactive")

        normalized_code = payload.stock_code.strip().upper()

        # Insert the row
        if payload.rating_date:
            db.execute_update_usp(
                """
                INSERT INTO [Research].[StockRating] (StockCode, CommenterID, Rating, Comment, RatingDate, AddedBy)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (normalized_code, payload.commenter_id, payload.rating.value, payload.comment, payload.rating_date, username),
            )
        else:
            db.execute_update_usp(
                """
                INSERT INTO [Research].[StockRating] (StockCode, CommenterID, Rating, Comment, AddedBy)
                VALUES (?, ?, ?, ?, ?)
                """,
                (normalized_code, payload.commenter_id, payload.rating.value, payload.comment, username),
            )

        # Read back the inserted row
        rows = db.execute_read_usp(
            """
            SELECT TOP 1
                sr.StockRatingID as id,
                sr.StockCode as stock_code,
                sr.CommenterID as commenter_id,
                c.Name as commenter_name,
                sr.Rating as rating,
                sr.Comment as comment,
                CONVERT(varchar(10), sr.RatingDate, 23) as rating_date,
                CONVERT(varchar(19), sr.AddedAt, 126) as added_at,
                sr.AddedBy as added_by
            FROM [Research].[StockRating] sr
            INNER JOIN [Research].[Commenter] c ON sr.CommenterID = c.CommenterID
            WHERE sr.StockCode = ? AND sr.CommenterID = ?
            ORDER BY sr.AddedAt DESC
            """,
            (normalized_code, payload.commenter_id),
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
        raise HTTPException(status_code=500, detail=f"Failed to create stock rating: {str(e)}")


@router.put("/stock-ratings/{rating_id}", response_model=StockRating)
def update_stock_rating(
    rating_id: int,
    payload: StockRatingUpdate,
    username: str = Depends(verify_credentials),
) -> StockRating:
    try:
        db = SQLServerModel(database="StockDB")

        # Check if rating exists
        existing = db.execute_read_usp(
            "SELECT StockRatingID FROM [Research].[StockRating] WHERE StockRatingID = ?",
            (rating_id,),
        ) or []

        if not existing:
            raise HTTPException(status_code=404, detail="Stock rating not found")

        # Build update query dynamically
        updates = []
        params: List[Any] = []

        if payload.rating is not None:
            updates.append("Rating = ?")
            params.append(payload.rating.value)

        if payload.comment is not None:
            updates.append("Comment = ?")
            params.append(payload.comment)

        if payload.rating_date is not None:
            updates.append("RatingDate = ?")
            params.append(payload.rating_date)

        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")

        params.append(rating_id)
        db.execute_update_usp(
            f"UPDATE [Research].[StockRating] SET {', '.join(updates)} WHERE StockRatingID = ?",
            tuple(params),
        )

        # Read back the updated row
        rows = db.execute_read_usp(
            """
            SELECT
                sr.StockRatingID as id,
                sr.StockCode as stock_code,
                sr.CommenterID as commenter_id,
                c.Name as commenter_name,
                sr.Rating as rating,
                sr.Comment as comment,
                CONVERT(varchar(10), sr.RatingDate, 23) as rating_date,
                CONVERT(varchar(19), sr.AddedAt, 126) as added_at,
                sr.AddedBy as added_by
            FROM [Research].[StockRating] sr
            INNER JOIN [Research].[Commenter] c ON sr.CommenterID = c.CommenterID
            WHERE sr.StockRatingID = ?
            """,
            (rating_id,),
        ) or []

        row = rows[0]
        if isinstance(row.get("added_at"), str) and len(row["added_at"]) == 19:
            row["added_at"] += "Z"

        return row  # type: ignore
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update stock rating: {str(e)}")


@router.delete("/stock-ratings/{rating_id}")
def delete_stock_rating(
    rating_id: int,
    username: str = Depends(verify_credentials),
) -> Dict[str, str]:
    try:
        db = SQLServerModel(database="StockDB")

        # Check if rating exists
        existing = db.execute_read_usp(
            "SELECT StockRatingID FROM [Research].[StockRating] WHERE StockRatingID = ?",
            (rating_id,),
        ) or []

        if not existing:
            raise HTTPException(status_code=404, detail="Stock rating not found")

        db.execute_update_usp(
            "DELETE FROM [Research].[StockRating] WHERE StockRatingID = ?",
            (rating_id,),
        )

        return {"message": "Stock rating deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete stock rating: {str(e)}")


@router.delete("/stock-ratings/tipped-stocks/{stock_code}")
def delete_tipped_stock(
    stock_code: str,
    username: str = Depends(verify_credentials),
) -> Dict[str, str]:
    """
    Delete a tipped stock by removing all associated ratings and research links for the stock.
    The stock disappears from the tipped list when no ratings remain.
    """
    try:
        db = SQLServerModel(database="StockDB")
        normalized_code = stock_code.strip().upper()

        # Ensure the stock exists in ratings
        exists_rows = db.execute_read_usp(
            "SELECT TOP 1 1 as exists_flag FROM [Research].[StockRating] WHERE StockCode = ?",
            (normalized_code,),
        ) or []
        if not exists_rows:
            raise HTTPException(status_code=404, detail="Tipped stock not found (no ratings)")

        # Delete research links first, then ratings
        db.execute_update_usp(
            "DELETE FROM [Research].[ResearchLink] WHERE StockCode = ?",
            (normalized_code,),
        )
        db.execute_update_usp(
            "DELETE FROM [Research].[StockRating] WHERE StockCode = ?",
            (normalized_code,),
        )

        return {"message": f"Deleted all ratings and research links for {normalized_code}"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete tipped stock: {str(e)}")
