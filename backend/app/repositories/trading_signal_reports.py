"""Read-only SQL boundary for TradingSignal.ReportSnapshot."""

from __future__ import annotations

import base64
import hashlib
import json
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Callable, Dict, List, Optional

from app.core.config import settings
from app.core.db import get_timed_sql_model


@dataclass(frozen=True)
class ReportFilters:
    date_from: Optional[date] = None
    date_to: Optional[date] = None
    strategy_code: Optional[str] = None
    instrument_code: Optional[str] = None
    environment: Optional[str] = None
    report_kind: Optional[str] = None
    search: Optional[str] = None
    limit: int = 50
    cursor: Optional[str] = None
    current_only: bool = False
    public_report_id: Optional[str] = None


class ReportCursorError(ValueError):
    pass


class TradingSignalReportRepository:
    """Deep read-only module: filters, cursor integrity, and SQL stay here."""

    def __init__(self, model_factory: Optional[Callable[[], Any]] = None) -> None:
        self._model_factory = model_factory or (
            lambda: get_timed_sql_model(
                database="StockDB_US",
                connection_timeout=settings.sqlserver_connection_timeout,
                query_timeout=8,
            )
        )

    @staticmethod
    def _filter_hash(filters: ReportFilters) -> str:
        payload = {
            "date_from": filters.date_from.isoformat() if filters.date_from else None,
            "date_to": filters.date_to.isoformat() if filters.date_to else None,
            "strategy_code": filters.strategy_code,
            "instrument_code": filters.instrument_code,
            "environment": filters.environment,
            "report_kind": filters.report_kind,
            "search": filters.search,
            "current_only": filters.current_only,
            "public_report_id": filters.public_report_id,
        }
        return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()

    @classmethod
    def _decode_cursor(cls, value: str, filters: ReportFilters) -> Dict[str, Any]:
        try:
            padded = value + "=" * (-len(value) % 4)
            payload = json.loads(base64.urlsafe_b64decode(padded.encode("ascii")).decode("utf-8"))
            if payload.get("v") != 1 or payload.get("filters") != cls._filter_hash(filters):
                raise ReportCursorError("cursor does not match filters")
            date_value = date.fromisoformat(payload["report_date"])
            generated = datetime.fromisoformat(payload["generated_utc"])
            if not payload.get("public_report_id"):
                raise ValueError("missing public report ID")
            return {"report_date": date_value, "generated_utc": generated.replace(tzinfo=None), "public_report_id": payload["public_report_id"]}
        except ReportCursorError:
            raise
        except Exception as exc:
            raise ReportCursorError("invalid report cursor") from exc

    @classmethod
    def _encode_cursor(cls, filters: ReportFilters, row: Dict[str, Any]) -> str:
        generated = row["generated_utc"]
        if isinstance(generated, datetime) and generated.tzinfo is not None:
            generated = generated.replace(tzinfo=None)
        payload = {
            "v": 1,
            "filters": cls._filter_hash(filters),
            "report_date": row["report_date"].isoformat(),
            "generated_utc": generated.isoformat(),
            "public_report_id": str(row["public_report_id"]),
        }
        return base64.urlsafe_b64encode(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")).decode("ascii").rstrip("=")

    @staticmethod
    def _url(public_report_id: str) -> str:
        from urllib.parse import quote, urlencode

        path = f"/api/trading-signal-reports/{quote(str(public_report_id), safe='')}.html"
        token = settings.trading_signal_report_token.strip()
        return f"{path}?{urlencode({'report_token': token})}" if token else path

    def list(self, filters: ReportFilters) -> tuple[List[Dict[str, Any]], Optional[str]]:
        if not 1 <= filters.limit <= 200:
            raise ValueError("limit must be between 1 and 200")
        clauses = ["1 = 1"]
        values: List[Any] = []
        if filters.date_from:
            clauses.append("r.ReportDate >= ?")
            values.append(filters.date_from)
        if filters.date_to:
            clauses.append("r.ReportDate <= ?")
            values.append(filters.date_to)
        if filters.strategy_code:
            clauses.append("r.StrategyCode = ?")
            values.append(filters.strategy_code)
        if filters.instrument_code:
            clauses.append("(r.SubjectInstrumentCode = ? OR r.ExecutionInstrumentCode = ?)")
            values.extend([filters.instrument_code, filters.instrument_code])
        if filters.environment:
            clauses.append("r.EnvironmentType = ?")
            values.append(filters.environment)
        if filters.report_kind:
            clauses.append("r.ReportKind = ?")
            values.append(filters.report_kind)
        if filters.current_only:
            clauses.append("r.SupersedesReportID IS NULL")
        if filters.public_report_id:
            clauses.append("CONVERT(nvarchar(36), r.PublicReportID) = ?")
            values.append(filters.public_report_id)
        if filters.search:
            search = f"%{filters.search}%"
            clauses.append("(r.StrategyCode LIKE ? OR r.StrategyVersionCode LIKE ? OR r.DeploymentKey LIKE ? OR r.SubjectInstrumentCode LIKE ? OR r.ExecutionInstrumentCode LIKE ? OR r.ReportKind LIKE ? OR r.FileName LIKE ? OR CONVERT(nvarchar(36), r.PublicReportID) LIKE ?)")
            values.extend([search] * 8)
        if filters.cursor:
            cursor = self._decode_cursor(filters.cursor, filters)
            clauses.append("(r.ReportDate < ? OR (r.ReportDate = ? AND r.GeneratedUtc < ?) OR (r.ReportDate = ? AND r.GeneratedUtc = ? AND r.PublicReportID < ?))")
            values.extend([cursor["report_date"], cursor["report_date"], cursor["generated_utc"], cursor["report_date"], cursor["generated_utc"], cursor["public_report_id"]])
        sql = f"""
            SELECT TOP (?)
                r.PublicReportID AS public_report_id, r.ReportKind AS report_kind,
                r.ReportDate AS report_date, r.ObservationDate AS observation_date,
                r.StrategyCode AS strategy_code, r.StrategyVersionCode AS strategy_version_code,
                r.DeploymentKey AS deployment_key, r.EnvironmentType AS environment,
                r.SubjectInstrumentCode AS subject_instrument_code,
                r.ExecutionInstrumentCode AS execution_instrument_code,
                r.Title AS title, r.Summary AS summary, r.FileName AS file_name,
                r.RevisionNo AS revision_no, r.GeneratedUtc AS generated_utc,
                sup.PublicReportID AS supersedes_public_report_id,
                CASE WHEN r.SupersedesReportID IS NULL THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS is_current
            FROM [StockDB_US].[TradingSignal].[ReportSnapshot] AS r
            LEFT JOIN [StockDB_US].[TradingSignal].[ReportSnapshot] AS sup ON sup.ReportSnapshotID = r.SupersedesReportID
            WHERE {' AND '.join(clauses)}
            ORDER BY r.ReportDate DESC, r.GeneratedUtc DESC, r.PublicReportID DESC
        """
        model = self._model_factory()
        try:
            rows = model.execute_read_query(sql, [filters.limit + 1, *values]) or []
        finally:
            model.close()
        normalized = [dict(row) for row in rows[: filters.limit]]
        for row in normalized:
            row["public_report_id"] = str(row["public_report_id"])
            row["supersedes_public_report_id"] = str(row["supersedes_public_report_id"]) if row.get("supersedes_public_report_id") else None
            row["html_url"] = self._url(row["public_report_id"])
        next_cursor = self._encode_cursor(filters, normalized[-1]) if len(rows) > filters.limit and normalized else None
        return normalized, next_cursor

    def latest(self, filters: ReportFilters) -> Optional[Dict[str, Any]]:
        if not filters.strategy_code:
            raise ValueError("strategy_code is required for latest")
        latest_filters = ReportFilters(
            strategy_code=filters.strategy_code,
            instrument_code=filters.instrument_code,
            environment=filters.environment,
            report_kind=filters.report_kind,
            limit=1,
            current_only=True,
        )
        rows, _ = self.list(latest_filters)
        return rows[0] if rows else None

    def html(self, public_report_id: str) -> Optional[Dict[str, Any]]:
        model = self._model_factory()
        try:
            rows = model.execute_read_query(
                "SELECT TOP (1) PublicReportID AS public_report_id, ContentHash AS content_hash, HtmlContent AS html_content FROM [StockDB_US].[TradingSignal].[ReportSnapshot] WHERE PublicReportID = ?",
                [public_report_id],
            ) or []
        finally:
            model.close()
        return dict(rows[0]) if rows else None

    def by_file_name(self, file_name: str, strategy_code: str = "SPX_GEX") -> Optional[Dict[str, Any]]:
        model = self._model_factory()
        try:
            rows = model.execute_read_query(
                """
                SELECT TOP (1) PublicReportID AS public_report_id, ContentHash AS content_hash,
                       HtmlContent AS html_content, FileName AS file_name
                FROM [StockDB_US].[TradingSignal].[ReportSnapshot]
                WHERE StrategyCode = ? AND FileName = ?
                ORDER BY RevisionNo DESC, GeneratedUtc DESC
                """,
                [strategy_code, file_name],
            ) or []
        finally:
            model.close()
        return dict(rows[0]) if rows else None

    def by_date(self, report_date: date, strategy_code: str = "SPX_GEX", public_report_id: Optional[str] = None) -> Optional[Dict[str, Any]]:
        clauses = ["StrategyCode = ?", "ReportDate = ?"]
        values: List[Any] = [strategy_code, report_date]
        if public_report_id:
            clauses.append("CONVERT(nvarchar(36), PublicReportID) = ?")
            values.append(public_report_id)
        model = self._model_factory()
        try:
            rows = model.execute_read_query(
                f"""
                SELECT TOP (1) PublicReportID AS public_report_id, ContentHash AS content_hash,
                       HtmlContent AS html_content, FileName AS file_name
                FROM [StockDB_US].[TradingSignal].[ReportSnapshot]
                WHERE {' AND '.join(clauses)}
                ORDER BY RevisionNo DESC, GeneratedUtc DESC
                """,
                values,
            ) or []
        finally:
            model.close()
        return dict(rows[0]) if rows else None
