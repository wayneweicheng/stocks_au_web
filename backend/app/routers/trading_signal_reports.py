from __future__ import annotations

import hmac
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, Response

from app.core.config import settings
from app.routers.auth import verify_credentials
from app.repositories.trading_signal_reports import ReportFilters, ReportCursorError, TradingSignalReportRepository
from app.schemas.trading_signal_reports import TradingSignalReportItem, TradingSignalReportPage


router = APIRouter(prefix="/api/trading-signal-reports", tags=["trading-signal-reports"])


def _filters(
    date_from: Optional[date],
    date_to: Optional[date],
    strategy_code: Optional[str],
    instrument_code: Optional[str],
    environment: Optional[str],
    report_kind: Optional[str],
    search: Optional[str],
    limit: int,
    cursor: Optional[str],
    public_report_id: Optional[str],
) -> ReportFilters:
    if date_from and date_to and date_from > date_to:
        raise HTTPException(status_code=422, detail="date_from must be on or before date_to")
    return ReportFilters(date_from, date_to, strategy_code, instrument_code, environment, report_kind, search, limit, cursor, public_report_id=public_report_id)


@router.get("", response_model=TradingSignalReportPage)
def list_trading_signal_reports(
    date_from: Optional[date] = Query(default=None),
    date_to: Optional[date] = Query(default=None),
    strategy_code: Optional[str] = Query(default=None),
    instrument_code: Optional[str] = Query(default=None),
    environment: Optional[str] = Query(default=None),
    report_kind: Optional[str] = Query(default=None),
    search: Optional[str] = Query(default=None, max_length=200),
    limit: int = Query(default=50, ge=1, le=200),
    cursor: Optional[str] = Query(default=None),
    public_report_id: Optional[str] = Query(default=None),
    _username: str = Depends(verify_credentials),
) -> TradingSignalReportPage:
    filters = _filters(date_from, date_to, strategy_code, instrument_code, environment, report_kind, search, limit, cursor, public_report_id)
    try:
        rows, next_cursor = TradingSignalReportRepository().list(filters)
    except ReportCursorError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return TradingSignalReportPage(items=[TradingSignalReportItem(**row) for row in rows], next_cursor=next_cursor, limit=limit)


@router.get("/latest", response_model=TradingSignalReportItem)
def latest_trading_signal_report(
    strategy_code: str = Query(...),
    instrument_code: Optional[str] = Query(default=None),
    environment: Optional[str] = Query(default=None),
    report_kind: Optional[str] = Query(default=None),
    _username: str = Depends(verify_credentials),
) -> TradingSignalReportItem:
    try:
        row = TradingSignalReportRepository().latest(ReportFilters(strategy_code=strategy_code, instrument_code=instrument_code, environment=environment, report_kind=report_kind, limit=1))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    if row is None:
        raise HTTPException(status_code=404, detail="Report not found")
    return TradingSignalReportItem(**row)


def _authorize_html(request: Request, report_token: Optional[str]) -> None:
    expected = settings.trading_signal_report_token.strip()
    if expected and report_token is not None and hmac.compare_digest(report_token, expected):
        return
    if expected and report_token is not None and not hmac.compare_digest(report_token, expected):
        raise HTTPException(status_code=403, detail="Report access denied")
    try:
        verify_credentials(request.headers.get("authorization"))
    except HTTPException as exc:
        raise HTTPException(status_code=401, detail="Report access denied", headers={"WWW-Authenticate": "Basic"}) from exc


@router.get("/{public_report_id}.html", response_class=HTMLResponse)
def immutable_trading_signal_report(
    public_report_id: str,
    request: Request,
    report_token: Optional[str] = Query(default=None),
) -> Response:
    _authorize_html(request, report_token)
    row = TradingSignalReportRepository().html(public_report_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Report not found")
    etag = f'"{row["content_hash"]}"'
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304, headers={"ETag": etag})
    return HTMLResponse(
        content=row["html_content"],
        headers={
            "ETag": etag,
            "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; img-src data: https:;",
            "X-Content-Type-Options": "nosniff",
            "Referrer-Policy": "no-referrer",
            "Cache-Control": "public, max-age=31536000, immutable",
        },
    )
