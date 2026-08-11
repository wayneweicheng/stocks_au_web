from __future__ import annotations

import hmac
from datetime import date
from typing import Any
from urllib.parse import quote, urlencode

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import HTMLResponse

from app.core.config import settings
from app.spx_gex_strategy.ib_market_data import get_live_nq_snapshot
from app.spx_gex_strategy.report import render_html_report
from app.spx_gex_strategy.service import SPXGEXStrategyService

router = APIRouter(prefix="/api/spx-gex", tags=["spx-gex-strategy"])


def _check_report_token(report_token: str | None) -> None:
    expected = (settings.spx_gex_report_token or "").strip()
    if expected and not hmac.compare_digest(report_token or "", expected):
        raise HTTPException(status_code=403, detail="Invalid report token")


def _snapshot_url(report_date: str, report_id: str, file_name: str | None = None) -> str:
    query: dict[str, str] = {}
    token = (settings.spx_gex_report_token or "").strip()
    if token:
        query["report_token"] = token
    if file_name:
        path = f"/api/spx-gex/reports/{quote(file_name)}"
    else:
        path = f"/api/spx-gex/reports/{report_date}.html"
        query["report_id"] = report_id
    return path + (f"?{urlencode(query)}" if query else "")


@router.get("/report.html", response_class=HTMLResponse)
def spx_gex_html_report(report_token: str | None = Query(default=None)) -> HTMLResponse:
    """Read-only latest report suitable for the Pushover link."""
    _check_report_token(report_token)
    service = SPXGEXStrategyService()
    live_nq: dict[str, Any] | None = None
    if settings.spx_gex_require_live_nq:
        try:
            live_nq = get_live_nq_snapshot()
        except Exception:
            live_nq = None
    return HTMLResponse(
        render_html_report(
            service.store,
            service.strategy_version,
            live_nq,
            archive_links=[
                {
                    **{key: row[key] for key in row.keys()},
                    "url": _snapshot_url(row["report_date"], row["report_id"], row["file_name"]),
                }
                for row in service.store.recent_reports(100, service.environment_type.value)
            ],
        )
    )


@router.get("/reports")
def spx_gex_report_archive(
    limit: int = Query(default=100, ge=1, le=500),
    report_token: str | None = Query(default=None),
) -> dict[str, Any]:
    """List immutable daily report snapshots, newest first."""
    _check_report_token(report_token)
    service = SPXGEXStrategyService()
    items = []
    for row in service.store.recent_reports(limit, service.environment_type.value):
        items.append(
            {
                "report_id": row["report_id"],
                "report_date": row["report_date"],
                "as_of_date": row["report_date"],
                "observation_date": row["observation_date"],
                "file_name": row["file_name"],
                "report_kind": row["report_kind"],
                "strategy_version": row["strategy_version"],
                "environment_type": row["environment_type"],
                "generated_at": row["generated_at"],
                "url": _snapshot_url(row["report_date"], row["report_id"], row["file_name"]),
            }
        )
    return {"items": items}


@router.get("/reports/{report_name}", response_class=HTMLResponse)
def spx_gex_historical_report(
    report_name: str,
    report_id: str | None = Query(default=None),
    report_token: str | None = Query(default=None),
) -> HTMLResponse:
    """Return an immutable report snapshot for a completed US session."""
    _check_report_token(report_token)
    service = SPXGEXStrategyService()
    if report_name.startswith("spx-gex-report-") and report_name.endswith(".html"):
        row = service.store.report_for_file_name(report_name, service.environment_type.value)
    else:
        try:
            legacy_date = date.fromisoformat(report_name.removesuffix(".html"))
        except ValueError as exc:
            raise HTTPException(status_code=404, detail="Historical SPX GEX report not found") from exc
        row = service.store.report_for_date(legacy_date, service.environment_type.value, report_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Historical SPX GEX report not found")
    return HTMLResponse(
        row["html_content"],
        headers={"Content-Disposition": f'inline; filename="{row["file_name"]}"'},
    )


@router.get("/live-nq")
def spx_gex_live_nq() -> dict[str, Any]:
    """Show the IB CONTFUT NQ quote and its percentage move versus yesterday."""
    try:
        return get_live_nq_snapshot()
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
