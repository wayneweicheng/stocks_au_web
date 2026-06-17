from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional
import json
import re

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.routers.auth import verify_credentials


router = APIRouter(prefix="/api", tags=["market-theme-reports"])

REPORT_DIR = Path("llm_output") / "market-theme-reports"
INDEX_PATH = REPORT_DIR / "index.json"
MAX_REPORT_BYTES = 2 * 1024 * 1024
_FILENAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.md$")


class MarketThemeReportCreate(BaseModel):
    content: str = Field(..., min_length=1)
    filename: Optional[str] = None
    title: Optional[str] = None
    created_at: Optional[str] = None


class MarketThemeReportSummary(BaseModel):
    filename: str
    title: str
    created_at: str
    size_bytes: int
    uploaded_by: Optional[str] = None


class MarketThemeReportDetail(MarketThemeReportSummary):
    content: str


class MarketThemeReportPage(BaseModel):
    items: List[MarketThemeReportSummary]


def _ensure_report_dir() -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)


def _load_index() -> List[Dict[str, object]]:
    if not INDEX_PATH.exists():
        return []
    try:
        data = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    except Exception:
        return []
    return data if isinstance(data, list) else []


def _write_index(items: List[Dict[str, object]]) -> None:
    _ensure_report_dir()
    INDEX_PATH.write_text(json.dumps(items, indent=2, ensure_ascii=False), encoding="utf-8")


def _validate_filename(filename: str) -> str:
    name = Path(filename).name
    if name != filename or not _FILENAME_RE.match(name):
        raise HTTPException(status_code=400, detail="Invalid markdown filename")
    return name


def _default_filename() -> str:
    return "market-themes-{}.md".format(datetime.now(timezone.utc).strftime("%Y-%m-%d_%H%M%S"))


def _default_title(filename: str) -> str:
    stem = filename[:-3] if filename.endswith(".md") else filename
    return stem.replace("-", " ").replace("_", " ").title()


def _read_content(filename: str) -> str:
    path = REPORT_DIR / _validate_filename(filename)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Report not found")
    return path.read_text(encoding="utf-8")


@router.get("/market-theme-reports", response_model=MarketThemeReportPage)
def list_market_theme_reports(username: str = Depends(verify_credentials)) -> MarketThemeReportPage:
    _ensure_report_dir()
    index_by_file = {
        str(item.get("filename")): item
        for item in _load_index()
        if item.get("filename")
    }
    summaries: List[MarketThemeReportSummary] = []

    for path in REPORT_DIR.glob("*.md"):
        filename = path.name
        meta = index_by_file.get(filename, {})
        created_at = str(meta.get("created_at") or datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat())
        summaries.append(
            MarketThemeReportSummary(
                filename=filename,
                title=str(meta.get("title") or _default_title(filename)),
                created_at=created_at,
                size_bytes=path.stat().st_size,
                uploaded_by=meta.get("uploaded_by"),
            )
        )

    summaries.sort(key=lambda item: item.created_at, reverse=True)
    return MarketThemeReportPage(items=summaries)


@router.get("/market-theme-reports/{filename}", response_model=MarketThemeReportDetail)
def get_market_theme_report(
    filename: str,
    username: str = Depends(verify_credentials),
) -> MarketThemeReportDetail:
    summaries = list_market_theme_reports(username=username).items
    summary = next((item for item in summaries if item.filename == filename), None)
    if summary is None:
        raise HTTPException(status_code=404, detail="Report not found")

    return MarketThemeReportDetail(**summary.dict(), content=_read_content(filename))


@router.post("/market-theme-reports", response_model=MarketThemeReportSummary)
def create_market_theme_report(
    payload: MarketThemeReportCreate,
    username: str = Depends(verify_credentials),
) -> MarketThemeReportSummary:
    content_bytes = payload.content.encode("utf-8")
    if len(content_bytes) > MAX_REPORT_BYTES:
        raise HTTPException(status_code=413, detail="Report is too large")

    filename = _validate_filename(payload.filename or _default_filename())
    _ensure_report_dir()
    path = REPORT_DIR / filename
    path.write_text(payload.content, encoding="utf-8")

    created_at = payload.created_at or datetime.now(timezone.utc).isoformat()
    title = payload.title or _default_title(filename)
    item = {
        "filename": filename,
        "title": title,
        "created_at": created_at,
        "size_bytes": len(content_bytes),
        "uploaded_by": username,
    }

    index = [existing for existing in _load_index() if existing.get("filename") != filename]
    index.append(item)
    index.sort(key=lambda existing: str(existing.get("created_at", "")), reverse=True)
    _write_index(index)

    return MarketThemeReportSummary(**item)
