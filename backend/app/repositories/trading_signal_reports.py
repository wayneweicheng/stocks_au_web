"""Read-only SQL boundary for TradingSignal.ReportSnapshot."""

from __future__ import annotations

import base64
import hashlib
import json
import re
from dataclasses import dataclass
from datetime import date, datetime, time
from typing import Any, Callable, Dict, List, Optional

from app.core.config import settings
from app.core.db import get_timed_sql_model
from app.services.live_stock_price_service import get_live_stock_prices
from app.spx_gex_strategy.calendar import USCashCalendar


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
    exclude_no_signal: bool = False


class ReportCursorError(ValueError):
    pass


def _json_dict(value: Any) -> Dict[str, Any]:
    if isinstance(value, dict):
        return value
    if not value:
        return {}
    try:
        parsed = json.loads(value) if isinstance(value, str) else value
    except (TypeError, ValueError, json.JSONDecodeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _number(value: Any) -> Optional[float]:
    try:
        return float(value) if value is not None else None
    except (TypeError, ValueError):
        return None


def _data_error_reason(configuration: Any, metrics_json: Any) -> str:
    """Explain an indeterminate DATA_ERROR from persisted signal evidence."""
    metrics = _json_dict(metrics_json)
    for key in ("evaluation_reason", "evaluation_error", "error", "reason"):
        value = metrics.get(key)
        if value:
            return str(value)

    values = _json_dict(metrics.get("metrics"))
    evaluations = _json_dict(metrics.get("trigger_evaluations"))
    missing: set[str] = set()
    definitions = _json_dict(configuration).get("signal_definitions")
    if isinstance(definitions, list):
        for definition in definitions:
            if not isinstance(definition, dict):
                continue
            code = str(definition.get("signal_code") or "")
            # Only actionable predicates are recorded in trigger_evaluations;
            # DATA_ERROR/NO_SIGNAL definitions describe the classification
            # itself and are not missing data inputs.
            if code not in evaluations or evaluations.get(code) is not None:
                continue
            trigger = str(definition.get("trigger_condition") or "")
            references = re.findall(r"\b[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?\b", trigger)
            missing.update(
                reference for reference in references
                if reference.upper() not in {"AND", "OR", "NOT", "TRUE", "FALSE"}
                and values.get(reference) is None
            )
    if missing:
        return "required predicate inputs unavailable: " + ", ".join(sorted(missing))
    return "evaluation failed or returned an indeterminate predicate state"


def _historical_evidence(configuration: Any, classification: Any) -> Optional[Dict[str, Any]]:
    config = _json_dict(configuration)
    wanted = str(classification or "").upper()
    definitions = config.get("signal_definitions")
    if not isinstance(definitions, list):
        return None

    for definition in definitions:
        if not isinstance(definition, dict):
            continue
        candidates = {
            str(definition.get(key) or "").upper()
            for key in ("signal_code", "classification", "display_name")
        }
        if wanted not in candidates:
            continue
        history = definition.get("historical_performance")
        if not isinstance(history, dict) or str(history.get("status") or "").upper() != "AVAILABLE":
            return None
        instances = history.get("instances", history.get("number_of_signal_instances"))
        resolved = history.get("resolved_instances")
        win_rate = _number(history.get("win_rate_pct"))
        if win_rate is None and resolved:
            wins = _number(history.get("wins"))
            if wins is not None:
                win_rate = wins * 100.0 / float(resolved)
        if win_rate is None or instances is None:
            return None
        return {
            "historical_win_rate_pct": win_rate,
            "historical_instances": int(instances),
            "historical_resolved_instances": int(resolved or 0),
            "historical_profit_factor": _number(history.get("profit_factor")),
            "historical_average_return_pct": _number(history.get("average_return_pct")),
        }
    return None


class TradingSignalReportRepository:
    """Deep read-only module: filters, cursor integrity, and SQL stay here."""

    _cash_calendar = USCashCalendar()

    @classmethod
    def _trade_window(cls, report_date: date, holding_period: str) -> tuple[date, Optional[date], datetime | None]:
        tradable_date = cls._cash_calendar.next_session(report_date)
        match = re.fullmatch(r"D(\d+)", holding_period.upper())
        if not match:
            return tradable_date, None, None
        sessions = max(1, int(match.group(1)))
        end_date = cls._cash_calendar.session_offset(tradable_date, sessions - 1)
        return tradable_date, end_date, cls._cash_calendar.cash_close(end_date)

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
            "exclude_no_signal": filters.exclude_no_signal,
        }
        return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()

    @classmethod
    def _decode_cursor(cls, value: str, filters: ReportFilters) -> Dict[str, Any]:
        try:
            padded = value + "=" * (-len(value) % 4)
            payload = json.loads(base64.urlsafe_b64decode(padded.encode("ascii")).decode("utf-8"))
            if payload.get("v") != 1 or payload.get("filters") != cls._filter_hash(filters):
                raise ReportCursorError("cursor does not match filters")
            run_datetime = datetime.fromisoformat(payload["run_datetime"])
            generated = datetime.fromisoformat(payload["generated_utc"])
            if not payload.get("public_report_id"):
                raise ValueError("missing public report ID")
            return {"run_datetime": run_datetime.replace(tzinfo=None), "generated_utc": generated.replace(tzinfo=None), "public_report_id": payload["public_report_id"]}
        except ReportCursorError:
            raise
        except Exception as exc:
            raise ReportCursorError("invalid report cursor") from exc

    @classmethod
    def _encode_cursor(cls, filters: ReportFilters, row: Dict[str, Any]) -> str:
        generated = row["generated_utc"]
        if isinstance(generated, datetime) and generated.tzinfo is not None:
            generated = generated.replace(tzinfo=None)
        run_datetime = row.get("run_scheduled_utc") or generated
        if isinstance(run_datetime, datetime) and run_datetime.tzinfo is not None:
            run_datetime = run_datetime.replace(tzinfo=None)
        payload = {
            "v": 1,
            "filters": cls._filter_hash(filters),
            "run_datetime": run_datetime.isoformat(),
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
            clauses.append("NOT EXISTS (SELECT 1 FROM [StockDB_US].[TradingSignal].[ReportSnapshot] AS newer WHERE newer.SupersedesReportID = r.ReportSnapshotID)")
        if filters.exclude_no_signal:
            clauses.append("ISNULL(sig.Classification, '') <> 'NO_SIGNAL'")
        if filters.public_report_id:
            clauses.append("CONVERT(nvarchar(36), r.PublicReportID) = ?")
            values.append(filters.public_report_id)
        if filters.search:
            search = f"%{filters.search}%"
            clauses.append("(r.StrategyCode LIKE ? OR r.StrategyVersionCode LIKE ? OR r.DeploymentKey LIKE ? OR r.SubjectInstrumentCode LIKE ? OR r.ExecutionInstrumentCode LIKE ? OR r.ReportKind LIKE ? OR r.FileName LIKE ? OR CONVERT(nvarchar(36), r.PublicReportID) LIKE ?)")
            values.extend([search] * 8)
        if filters.cursor:
            cursor = self._decode_cursor(filters.cursor, filters)
            clauses.append("(COALESCE(sr.ScheduledEffectiveUtc, r.GeneratedUtc) < ? OR (COALESCE(sr.ScheduledEffectiveUtc, r.GeneratedUtc) = ? AND r.GeneratedUtc < ?) OR (COALESCE(sr.ScheduledEffectiveUtc, r.GeneratedUtc) = ? AND r.GeneratedUtc = ? AND r.PublicReportID < ?))")
            values.extend([cursor["run_datetime"], cursor["run_datetime"], cursor["generated_utc"], cursor["run_datetime"], cursor["generated_utc"], cursor["public_report_id"]])
        sql = f"""
            SELECT TOP (?)
                r.PublicReportID AS public_report_id, r.ReportKind AS report_kind,
                r.ReportDate AS report_date, r.ObservationDate AS observation_date,
                r.StrategyCode AS strategy_code, r.StrategyVersionCode AS strategy_version_code,
                r.DeploymentKey AS deployment_key, r.EnvironmentType AS environment,
                r.SubjectInstrumentCode AS subject_instrument_code,
                r.ExecutionInstrumentCode AS execution_instrument_code,
                r.Title AS title, r.Summary AS summary, r.FileName AS file_name,
                sig.Classification AS signal_classification,
                r.RevisionNo AS revision_no, r.GeneratedUtc AS generated_utc,
                COALESCE(sr.ScheduledEffectiveUtc, r.GeneratedUtc) AS run_scheduled_utc,
                sup.PublicReportID AS supersedes_public_report_id,
                CASE WHEN NOT EXISTS (SELECT 1 FROM [StockDB_US].[TradingSignal].[ReportSnapshot] AS newer WHERE newer.SupersedesReportID = r.ReportSnapshotID) THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS is_current
            FROM [StockDB_US].[TradingSignal].[ReportSnapshot] AS r
            LEFT JOIN [StockDB_US].[TradingSignal].[Signal] AS sig ON sig.SignalID = r.SignalID
            LEFT JOIN [StockDB_US].[TradingSignal].[ReportSnapshot] AS sup ON sup.ReportSnapshotID = r.SupersedesReportID
            LEFT JOIN [StockDB_US].[TradingSignal].[StrategyRun] AS sr ON sr.StrategyRunID = r.StrategyRunID
            WHERE {' AND '.join(clauses)}
            ORDER BY COALESCE(sr.ScheduledEffectiveUtc, r.GeneratedUtc) DESC, r.GeneratedUtc DESC, r.PublicReportID DESC
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

    def price_performance(
        self,
        instrument_code: str,
        tradable_date: date,
        end_at: Optional[datetime] = None,
        now: Optional[datetime] = None,
    ) -> Dict[str, Any]:
        """Return the price move from a signal's entry date.

        Before a signal's fixed end time, live IB quotes are used during the
        US cash session and the persisted daily close is used outside it. Once
        the signal has ended, the close from its end date is used instead.
        """
        code = instrument_code.strip().upper()
        if not code:
            raise ValueError("instrument_code is required")

        local_now = now or datetime.now(self._cash_calendar.timezone)
        if local_now.tzinfo is None:
            local_now = local_now.replace(tzinfo=self._cash_calendar.timezone)
        else:
            local_now = local_now.astimezone(self._cash_calendar.timezone)

        local_end_at = None
        if end_at is not None:
            local_end_at = (
                end_at.replace(tzinfo=self._cash_calendar.timezone)
                if end_at.tzinfo is None
                else end_at.astimezone(self._cash_calendar.timezone)
            )
        has_ended = local_end_at is not None and local_end_at <= local_now
        end_date = local_end_at.date() if local_end_at is not None else None

        model = self._model_factory()
        try:
            rows = model.execute_read_query(
                """
                SELECT
                    (SELECT TOP (1) [Close]
                     FROM [StockDB_US].[StockData].[PriceHistory] WITH (NOLOCK)
                     WHERE ASXCode = ? AND ObservationDate <= CONVERT(date, ?)
                     ORDER BY ObservationDate DESC) AS latest_close,
                    (SELECT TOP (1) ObservationDate
                     FROM [StockDB_US].[StockData].[PriceHistory] WITH (NOLOCK)
                     WHERE ASXCode = ? AND ObservationDate <= CONVERT(date, ?)
                     ORDER BY ObservationDate DESC) AS latest_close_date,
                    (SELECT TOP (1) [Open]
                     FROM [StockDB_US].[StockData].[PriceHistory] WITH (NOLOCK)
                     WHERE ASXCode = ? AND ObservationDate = CONVERT(date, ?)) AS tradable_date_open_price,
                    (SELECT TOP (1) [Close]
                     FROM [StockDB_US].[StockData].[PriceHistory] WITH (NOLOCK)
                     WHERE ASXCode = ? AND ObservationDate = CONVERT(date, ?)) AS end_date_close
                """,
                [code, local_now.date(), code, local_now.date(), code, tradable_date, code, end_date],
            ) or []
        finally:
            model.close()

        row = dict(rows[0]) if rows else {}
        latest_close = _number(row.get("latest_close"))
        latest_close_date = row.get("latest_close_date")
        is_cash_session_open = (
            self._cash_calendar.is_session(local_now.date())
            and local_now >= datetime.combine(local_now.date(), time(9, 30), tzinfo=self._cash_calendar.timezone)
            and local_now < self._cash_calendar.cash_close(local_now.date())
        )

        close_price = _number(row.get("end_date_close")) if has_ended else latest_close
        close_price_date = end_date if has_ended else latest_close_date
        close_price_source = "end_date_close" if has_ended and close_price is not None else (
            "latest_close" if close_price is not None else None
        )
        if not has_ended and is_cash_session_open:
            quote = get_live_stock_prices([code]).get(code) or {}
            live_price = _number(quote.get("price"))
            if live_price is not None:
                close_price = live_price
                close_price_date = local_now.date()
                close_price_source = str(quote.get("source") or "ib_live")

        open_price = _number(row.get("tradable_date_open_price"))
        change_pct = (
            round((close_price - open_price) * 100.0 / open_price, 2)
            if close_price is not None and open_price not in (None, 0)
            else None
        )
        return {
            "instrument_code": code,
            "tradable_date": tradable_date,
            "tradable_date_open_price": open_price,
            "close_price": close_price,
            "close_price_date": close_price_date,
            "close_price_source": close_price_source,
            "change_pct": change_pct,
        }

    def overview(self, as_of: date, filters: Optional[ReportFilters] = None) -> Dict[str, Any]:
        filters = filters or ReportFilters()
        if not 1 <= filters.limit <= 2000:
            raise ValueError("limit must be between 1 and 2000")

        clauses = [
            "r.ReportDate <= ?",
            "NOT EXISTS (SELECT 1 FROM [StockDB_US].[TradingSignal].[ReportSnapshot] AS newer WHERE newer.SupersedesReportID = r.ReportSnapshotID)",
            "(s.ActionCode IN ('PLAN_ENTRY', 'WATCH') OR UPPER(s.Classification) IN ('DATA_ERROR', 'NO_SIGNAL'))",
            "(UPPER(s.Direction) IN ('LONG', 'SHORT') OR UPPER(s.Classification) IN ('DATA_ERROR', 'NO_SIGNAL'))",
        ]
        values: List[Any] = [as_of]
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

        sql = f"""
            SELECT TOP (?)
                r.PublicReportID AS public_report_id, r.ReportDate AS report_date,
                r.ObservationDate AS observation_date,
                r.StrategyCode AS strategy_code, r.StrategyVersionCode AS strategy_version_code,
                r.DeploymentKey AS deployment_key, r.EnvironmentType AS environment,
                r.SubjectInstrumentCode AS subject_instrument_code,
                r.ExecutionInstrumentCode AS execution_instrument_code,
                r.Title AS title, r.GeneratedUtc AS generated_utc,
                s.Direction AS direction, s.ActionCode AS action_code,
                s.HoldingPeriodCode AS holding_period,
                s.Classification AS signal_classification,
                s.MetricsJson AS signal_metrics_json,
                v.ConfigurationJson AS strategy_configuration_json
            FROM [StockDB_US].[TradingSignal].[ReportSnapshot] AS r
            JOIN [StockDB_US].[TradingSignal].[Signal] AS s ON s.SignalID = r.SignalID
            JOIN [StockDB_US].[TradingSignal].[StrategyVersion] AS v ON v.StrategyVersionID = s.StrategyVersionID
            WHERE {' AND '.join(clauses)}
            ORDER BY r.ReportDate DESC, r.GeneratedUtc DESC, r.PublicReportID DESC
        """
        model = self._model_factory()
        try:
            rows = model.execute_read_query(sql, [filters.limit, *values]) or []
        finally:
            model.close()

        # Keep the latest qualifying report for each strategy/horizon. This
        # retains, for example, a D2 and D5 view for the same instrument while
        # preventing older reports from obscuring the as-of snapshot.
        selected: Dict[tuple[str, str, str], Dict[str, Any]] = {}
        data_errors_by_key: Dict[tuple[str, str, str, str], Dict[str, Any]] = {}
        latest_result_keys: set[tuple[str, str, str, str]] = set()
        for raw_row in rows:
            row = dict(raw_row)
            classification = str(row.get("signal_classification") or "").upper()
            instrument = str(row.get("execution_instrument_code") or row.get("subject_instrument_code") or "").strip()
            error_key = (instrument, str(row.get("strategy_code") or ""), str(row.get("strategy_version_code") or ""), str(row.get("report_date")))
            is_latest_result = bool(instrument) and error_key not in latest_result_keys
            if instrument:
                latest_result_keys.add(error_key)

            if classification == "DATA_ERROR":
                if is_latest_result:
                    data_errors_by_key.setdefault(error_key, {
                        "public_report_id": str(row["public_report_id"]),
                        "report_date": row["report_date"],
                        "observation_date": row.get("observation_date"),
                        "strategy_code": str(row.get("strategy_code") or ""),
                        "strategy_version_code": str(row.get("strategy_version_code") or ""),
                        "deployment_key": str(row.get("deployment_key") or ""),
                        "environment": str(row.get("environment") or ""),
                        "instrument_code": instrument,
                        "signal_classification": classification,
                        "title": str(row.get("title") or ""),
                        "reason": _data_error_reason(row.get("strategy_configuration_json"), row.get("signal_metrics_json")),
                        "html_url": self._url(str(row["public_report_id"])),
                    })
                continue
            evidence = _historical_evidence(row.get("strategy_configuration_json"), row.get("signal_classification"))
            if evidence is None:
                continue
            instrument = str(row.get("execution_instrument_code") or row.get("subject_instrument_code") or "").strip()
            if not instrument:
                continue
            holding_period = str(row.get("holding_period") or "UNKNOWN").upper()
            tradable_date, end_date, end_at = self._trade_window(row["report_date"], holding_period)
            if as_of < tradable_date or (end_date is not None and as_of > end_date):
                continue
            key = (instrument, str(row.get("strategy_code") or ""), holding_period)
            if key in selected:
                continue
            selected[key] = {
                "public_report_id": str(row["public_report_id"]),
                "report_date": row["report_date"],
                "tradable_date": tradable_date,
                "end_date": end_date,
                "end_at": end_at,
                "strategy_code": str(row.get("strategy_code") or ""),
                "strategy_version_code": str(row.get("strategy_version_code") or ""),
                "instrument_code": instrument,
                "direction": str(row.get("direction") or "").upper(),
                "action_code": str(row.get("action_code") or "").upper(),
                "holding_period": holding_period,
                "signal_classification": str(row.get("signal_classification") or ""),
                "title": str(row.get("title") or ""),
                "html_url": self._url(str(row["public_report_id"])),
                **evidence,
            }

        grouped: Dict[str, List[Dict[str, Any]]] = {}
        for signal in selected.values():
            grouped.setdefault(signal["instrument_code"], []).append(signal)

        items = []
        for instrument, signals in grouped.items():
            signals.sort(key=lambda item: (item["report_date"], item["strategy_code"], item["holding_period"]), reverse=True)
            directions = {item["direction"] for item in signals}
            verdict = next(iter(directions)) if len(directions) == 1 else "CONFLICTING"
            items.append({
                "instrument_code": instrument,
                "verdict": verdict,
                "signal_count": len(signals),
                "long_count": sum(item["direction"] == "LONG" for item in signals),
                "short_count": sum(item["direction"] == "SHORT" for item in signals),
                "latest_report_date": max(item["report_date"] for item in signals),
                "signals": signals,
            })
        items.sort(key=lambda item: item["instrument_code"])
        return {"as_of": as_of, "items": items, "data_errors": list(data_errors_by_key.values())}

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
