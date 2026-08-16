"""Read-only legacy aliases backed by the generic TradingSignal catalog.

This module intentionally contains no SPX calculation, scheduler, IB, SQLite,
notification, or report-rendering code. It exists only while old links are
being retired; new UI links use /api/trading-signal-reports.
"""

from __future__ import annotations

import hmac
from datetime import date
from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import HTMLResponse

from app.core.config import settings
from app.repositories.trading_signal_reports import ReportFilters, TradingSignalReportRepository


router = APIRouter(prefix="/api/spx-gex", tags=["spx-gex-compatibility"])


def _check_report_token(report_token: str | None) -> None:
    expected = (settings.trading_signal_report_token or settings.spx_gex_report_token).strip()
    if expected and not hmac.compare_digest(report_token or "", expected):
        raise HTTPException(status_code=403, detail="Report access denied")


def _url(row: dict[str, Any]) -> str:
    return str(row.get("html_url") or f"/api/trading-signal-reports/{row['public_report_id']}.html")


@router.get("/report.html", response_class=HTMLResponse)
def spx_gex_html_report(report_token: str | None = Query(default=None)) -> HTMLResponse:
    _check_report_token(report_token)
    row = TradingSignalReportRepository().latest(ReportFilters(strategy_code="SPX_GEX", limit=1, current_only=True))
    if row is None:
        raise HTTPException(status_code=404, detail="SPX GEX report not found")
    html = TradingSignalReportRepository().html(row["public_report_id"])
    if html is None:
        raise HTTPException(status_code=404, detail="SPX GEX report not found")
    return HTMLResponse(html["html_content"])


@router.get("/reports")
def spx_gex_report_archive(
    limit: int = Query(default=100, ge=1, le=500),
    report_token: str | None = Query(default=None),
) -> dict[str, Any]:
    _check_report_token(report_token)
    rows, _ = TradingSignalReportRepository().list(ReportFilters(strategy_code="SPX_GEX", limit=min(limit, 200)))
    return {
        "items": [
            {
                "report_id": row["public_report_id"],
                "report_date": row["report_date"],
                "as_of_date": row["report_date"],
                "observation_date": row["observation_date"],
                "file_name": row["file_name"],
                "report_kind": row["report_kind"],
                "strategy_version": row["strategy_version_code"],
                "environment_type": row["environment"],
                "generated_at": row["generated_utc"],
                "url": _url(row),
            }
            for row in rows
        ]
    }


@router.get("/reports/{report_name}", response_class=HTMLResponse)
def spx_gex_historical_report(
    report_name: str,
    request: Request,
    report_id: str | None = Query(default=None),
    report_token: str | None = Query(default=None),
) -> HTMLResponse:
    del request
    _check_report_token(report_token)
    repository = TradingSignalReportRepository()
    if report_name.startswith("spx-gex-report-") and report_name.endswith(".html"):
        row = repository.by_file_name(report_name)
    else:
        try:
            legacy_date = date.fromisoformat(report_name.removesuffix(".html"))
        except ValueError as exc:
            raise HTTPException(status_code=404, detail="Historical SPX GEX report not found") from exc
        row = repository.by_date(legacy_date, public_report_id=report_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Historical SPX GEX report not found")
    return HTMLResponse(row["html_content"], headers={"Content-Disposition": f'inline; filename="{row.get("file_name") or "report.html"}"'})


@router.get("/live-nq")
def retired_spx_gex_live_nq() -> None:
    raise HTTPException(status_code=410, detail="Live SPX GEX execution endpoints have been retired; use the generic report catalog")
