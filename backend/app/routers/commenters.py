from fastapi import APIRouter, Query, Depends, HTTPException
from pydantic import BaseModel
from typing import Any, Dict, List, Optional
from app.routers.auth import verify_credentials
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel


router = APIRouter(prefix="/api", tags=["commenters"])


class CommenterCreate(BaseModel):
    name: str
    description: Optional[str] = None


class CommenterUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None


class Commenter(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    created_at: str
    is_active: bool


class CommenterList(BaseModel):
    items: List[Commenter]
    total: int


@router.get("/commenters", response_model=CommenterList)
def list_commenters(
    include_inactive: bool = Query(default=False, description="Include inactive commenters"),
    username: str = Depends(verify_credentials),
) -> CommenterList:
    try:
        db = SQLServerModel(database="StockDB")

        where_clause = "" if include_inactive else "WHERE IsActive = 1"

        rows = db.execute_read_usp(
            f"""
            SELECT
                CommenterID as id,
                Name as name,
                Description as description,
                CONVERT(varchar(19), CreatedAt, 126) as created_at,
                IsActive as is_active
            FROM [Research].[Commenter]
            {where_clause}
            ORDER BY Name ASC
            """,
            (),
        ) or []

        for r in rows:
            if isinstance(r.get("created_at"), str) and len(r["created_at"]) == 19:
                r["created_at"] += "Z"
            r["is_active"] = bool(r.get("is_active", True))

        return CommenterList(items=rows, total=len(rows))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list commenters: {str(e)}")


@router.post("/commenters", response_model=Commenter)
def create_commenter(
    payload: CommenterCreate,
    username: str = Depends(verify_credentials),
) -> Commenter:
    try:
        db = SQLServerModel(database="StockDB")

        # Check if name already exists
        existing = db.execute_read_usp(
            "SELECT CommenterID FROM [Research].[Commenter] WHERE Name = ?",
            (payload.name.strip(),),
        ) or []

        if existing:
            raise HTTPException(status_code=400, detail="A commenter with this name already exists")

        # Insert the row
        db.execute_update_usp(
            """
            INSERT INTO [Research].[Commenter] (Name, Description)
            VALUES (?, ?)
            """,
            (payload.name.strip(), payload.description),
        )

        # Read back the inserted row
        rows = db.execute_read_usp(
            """
            SELECT TOP 1
                CommenterID as id,
                Name as name,
                Description as description,
                CONVERT(varchar(19), CreatedAt, 126) as created_at,
                IsActive as is_active
            FROM [Research].[Commenter]
            WHERE Name = ?
            ORDER BY CreatedAt DESC
            """,
            (payload.name.strip(),),
        ) or []

        if not rows:
            raise HTTPException(status_code=500, detail="Insert succeeded but could not read back inserted row")

        row = rows[0]
        if isinstance(row.get("created_at"), str) and len(row["created_at"]) == 19:
            row["created_at"] += "Z"
        row["is_active"] = bool(row.get("is_active", True))

        return row  # type: ignore
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create commenter: {str(e)}")


@router.put("/commenters/{commenter_id}", response_model=Commenter)
def update_commenter(
    commenter_id: int,
    payload: CommenterUpdate,
    username: str = Depends(verify_credentials),
) -> Commenter:
    try:
        db = SQLServerModel(database="StockDB")

        # Check if commenter exists
        existing = db.execute_read_usp(
            "SELECT CommenterID FROM [Research].[Commenter] WHERE CommenterID = ?",
            (commenter_id,),
        ) or []

        if not existing:
            raise HTTPException(status_code=404, detail="Commenter not found")

        # Build update query dynamically
        updates = []
        params: List[Any] = []

        if payload.name is not None:
            # Check if new name conflicts with another commenter
            conflict = db.execute_read_usp(
                "SELECT CommenterID FROM [Research].[Commenter] WHERE Name = ? AND CommenterID != ?",
                (payload.name.strip(), commenter_id),
            ) or []
            if conflict:
                raise HTTPException(status_code=400, detail="A commenter with this name already exists")
            updates.append("Name = ?")
            params.append(payload.name.strip())

        if payload.description is not None:
            updates.append("Description = ?")
            params.append(payload.description)

        if payload.is_active is not None:
            updates.append("IsActive = ?")
            params.append(1 if payload.is_active else 0)

        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")

        params.append(commenter_id)
        db.execute_update_usp(
            f"UPDATE [Research].[Commenter] SET {', '.join(updates)} WHERE CommenterID = ?",
            tuple(params),
        )

        # Read back the updated row
        rows = db.execute_read_usp(
            """
            SELECT
                CommenterID as id,
                Name as name,
                Description as description,
                CONVERT(varchar(19), CreatedAt, 126) as created_at,
                IsActive as is_active
            FROM [Research].[Commenter]
            WHERE CommenterID = ?
            """,
            (commenter_id,),
        ) or []

        row = rows[0]
        if isinstance(row.get("created_at"), str) and len(row["created_at"]) == 19:
            row["created_at"] += "Z"
        row["is_active"] = bool(row.get("is_active", True))

        return row  # type: ignore
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update commenter: {str(e)}")
