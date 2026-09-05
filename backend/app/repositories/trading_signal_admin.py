"""SQL-backed read model and guarded production notification toggle."""

from __future__ import annotations

import json
import csv
import hashlib
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Dict, Iterable, List, Optional

from app.core.config import settings
from app.core.db import get_db_connection, get_timed_sql_model


class ProductionDeploymentNotFound(ValueError):
    pass


def _json_object(value: Any) -> Dict[str, Any]:
    if isinstance(value, dict):
        return value
    if not value:
        return {}
    try:
        parsed = json.loads(value) if isinstance(value, str) else value
        return parsed if isinstance(parsed, dict) else {}
    except (TypeError, ValueError, json.JSONDecodeError):
        return {}


def _trade_fingerprint(record: Dict[str, Any]) -> str:
    payload = json.dumps(record, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _date_part(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text[:10] if text else None


def _metadata_values(metadata: Iterable[Dict[str, Any]], keys: Iterable[str]) -> List[str]:
    for item in metadata:
        for key in keys:
            value = item.get(key)
            if isinstance(value, str) and value.strip():
                return [value.strip()]
            if isinstance(value, (list, tuple)):
                values = [str(entry).strip() for entry in value if str(entry).strip()]
                if values:
                    return values
    return []


def _descriptor_signals(configuration: Dict[str, Any]) -> List[Dict[str, Any]]:
    values = configuration.get("signal_definitions")
    if not isinstance(values, list):
        return []
    normalized: List[Dict[str, Any]] = []
    for value in values:
        if not isinstance(value, dict):
            continue
        signal = dict(value)
        definition = signal.get("strategy_definition") or signal.get("definition")
        if isinstance(definition, dict):
            pieces = [definition.get("purpose"), definition.get("rationale")]
            definition = " ".join(str(piece).strip() for piece in pieces if piece)
        signal["strategy_definition"] = str(definition or "Not recorded in strategy metadata")

        confidence = signal.get("confidence")
        if isinstance(confidence, dict):
            # Strategy packets keep both the research label and score; the
            # admin response exposes the display label and score separately.
            signal["confidence"] = str(confidence.get("label") or "UNKNOWN")
            score = confidence.get("score")
            try:
                signal["confidence_score"] = float(score) if score is not None else None
            except (TypeError, ValueError):
                signal["confidence_score"] = None
        elif confidence is None:
            signal["confidence"] = "UNKNOWN"
            signal.setdefault("confidence_score", None)
        else:
            signal["confidence"] = str(confidence)
            signal.setdefault("confidence_score", None)

        exits = signal.get("exit_conditions")
        normalized_exits: List[Dict[str, Any]] = []
        if isinstance(exits, list):
            for item in exits:
                if isinstance(item, dict):
                    normalized_exits.append({
                        "kind": str(item.get("kind") or "CONTRACT"),
                        "description": str(item.get("description") or item.get("rule") or "Not recorded"),
                        "horizon": item.get("horizon"),
                    })
                elif item is not None:
                    description = str(item)
                    horizon_match = re.search(r"\bD\d+\b", description.upper())
                    normalized_exits.append({
                        "kind": "CONTRACT",
                        "description": description,
                        "horizon": horizon_match.group(0) if horizon_match else None,
                    })
        signal["exit_conditions"] = normalized_exits
        signal["historical_performance"] = dict(signal.get("historical_performance") or {})
        normalized.append(signal)

    # Some one-signal packets publish their frozen statistics in the sibling
    # historical-performance summary rather than repeating them inside the
    # signal definition. Surface that same median in the admin signal row.
    summary = configuration.get("historical_performance_summary")
    actionable = [
        signal for signal in normalized
        if str(signal.get("action") or "").upper() in {"PLAN_ENTRY", "WATCH"}
        and str(signal.get("signal_code") or "").upper() not in {"DATA_ERROR", "NO_SIGNAL"}
    ]
    if isinstance(summary, dict) and len(actionable) == 1:
        history = actionable[0]["historical_performance"]
        if history.get("median_return_pct") is None and summary.get("median_return_pct") is not None:
            history["median_return_pct"] = summary["median_return_pct"]

    return normalized


def _terminal_horizon(configuration: Dict[str, Any], signal_code: str | None = None) -> str:
    for signal in _descriptor_signals(configuration):
        if signal_code and str(signal.get("signal_code") or "").upper() != signal_code.upper():
            continue
        historical = signal.get("historical_performance")
        if isinstance(historical, dict) and historical.get("measurement_horizon"):
            return str(historical["measurement_horizon"]).upper()
    horizons = configuration.get("outcome_horizons")
    for signal in _descriptor_signals(configuration):
        if signal_code and str(signal.get("signal_code") or "").upper() != signal_code.upper():
            continue
        holding_period = str(signal.get("holding_period") or "").upper()
        if holding_period.startswith("CUSTOM"):
            return "CUSTOM"
    return str(horizons[-1]).upper() if isinstance(horizons, list) and horizons else "D5"


def _model_builder_historical_performance(descriptor: Dict[str, Any]) -> Dict[str, Any]:
    """Normalize the frozen model-builder statistics for the admin API.

    Historical research is intentionally independent from runtime outcome rows.
    Runtime rows belong in the simulated production-performance section and must
    not replace the packet's published research sample.
    """
    historical = dict(descriptor.get("historical_performance") or {})
    # Research packets use the descriptive field name
    # ``number_of_signal_instances``; the web contract deliberately exposes a
    # compact ``instances`` field.  Normalize packet metadata before Pydantic
    # validation so model-builder statistics are visible even when no runtime
    # outcome rows have been finalized yet.
    if "instances" not in historical:
        historical["instances"] = historical.get("number_of_signal_instances") or historical.get("instances_resolved") or historical.get("resolved_denominator") or 0
    source_range = historical.get("source_date_range")
    if isinstance(source_range, dict):
        historical.setdefault("sample_start", source_range.get("start"))
        historical.setdefault("sample_end", source_range.get("end"))
    historical.setdefault("measurement_horizon", descriptor.get("holding_period") or "CUSTOM")
    historical.setdefault("source_reference", historical.get("per_instance_ledger_reference") or "strategy packet historical-performance.json")
    historical.setdefault("as_of_utc", historical.get("as_of") or "NOT_AVAILABLE")
    historical.setdefault("notes", historical.get("sample_size_limitations") or historical.get("status") or "Model-builder historical statistics")
    historical.setdefault("status", "NOT_AVAILABLE")
    historical.setdefault("instances", 0)
    historical["status"] = str(historical.get("status") or "NOT_AVAILABLE").upper()
    historical.setdefault("source_kind", "MODEL_BUILDER_PACKET")
    return historical


def _descriptor_stats(
    signals: Iterable[Dict[str, Any]],
    portfolio_summary: Dict[str, Any] | None = None,
) -> Dict[str, Any]:
    """Aggregate packet research stats without mixing them into live outcomes."""
    if isinstance(portfolio_summary, dict) and any(
        portfolio_summary.get(key) is not None
        for key in ("resolved_trade_count", "instances_resolved", "resolved_denominator")
    ):
        resolved = int(
            portfolio_summary.get("resolved_trade_count")
            or portfolio_summary.get("instances_resolved")
            or portfolio_summary.get("resolved_denominator")
            or 0
        )
        return {
            "instances": resolved,
            "resolved_instances": resolved,
            "unresolved_instances": int(portfolio_summary.get("unresolved_trade_count") or portfolio_summary.get("unresolved_instances") or 0),
            "wins": int(portfolio_summary.get("wins") or 0),
            "losses": int(portfolio_summary.get("losses") or 0),
            "win_rate_pct": float(portfolio_summary["win_rate_pct"]) if portfolio_summary.get("win_rate_pct") is not None else None,
            "profit_factor": float(portfolio_summary["profit_factor"]) if portfolio_summary.get("profit_factor") is not None else None,
            "average_return_pct": float(portfolio_summary["average_return_pct"]) if portfolio_summary.get("average_return_pct") is not None else None,
            "median_return_pct": float(portfolio_summary["median_return_pct"]) if portfolio_summary.get("median_return_pct") is not None else None,
            "gross_profit_pct": float(portfolio_summary["gross_profit_pct_points"]) if portfolio_summary.get("gross_profit_pct_points") is not None else None,
            "gross_loss_pct": -float(portfolio_summary["gross_loss_pct_points"]) if portfolio_summary.get("gross_loss_pct_points") is not None else None,
            "source": "MODEL_BUILDER_PACKET",
            "source_reference": "historical-performance.json#performance + historical-instance-ledger.json",
        }
    histories = [dict(signal.get("historical_performance") or {}) for signal in signals]
    histories = [item for item in histories if str(item.get("status") or "").upper() == "AVAILABLE"]
    instances = sum(int(item.get("instances") or item.get("number_of_signal_instances") or 0) for item in histories)
    resolved_instances = sum(
        int(item.get("resolved_instances"))
        if item.get("resolved_instances") is not None
        else int(item.get("wins") or 0) + int(item.get("losses") or 0)
        for item in histories
    )
    unresolved_instances = sum(int(item.get("unresolved_instances") or 0) for item in histories)
    wins = sum(int(item.get("wins") or 0) for item in histories)
    losses = sum(int(item.get("losses") or 0) for item in histories)
    gross_profit = sum(
        float(
            item.get("gross_profit_return_sum")
            if item.get("gross_profit_return_sum") is not None
            else item.get("gross_profit_return_units")
            if item.get("gross_profit_return_units") is not None
            else item.get("gross_profit_pct") or 0
        )
        for item in histories
    )
    gross_loss = sum(
        abs(
            float(
                item.get("gross_loss_return_sum_abs")
                if item.get("gross_loss_return_sum_abs") is not None
                else item.get("gross_loss_return_units")
                if item.get("gross_loss_return_units") is not None
                else item.get("gross_loss_pct") or 0
            )
        )
        for item in histories
    )
    average_returns = [float(item["average_return_pct"]) for item in histories if item.get("average_return_pct") is not None]
    median_returns = [float(item["median_return_pct"]) for item in histories if item.get("median_return_pct") is not None]
    return {
        "instances": instances,
        "resolved_instances": resolved_instances,
        "unresolved_instances": unresolved_instances,
        "wins": wins,
        "losses": losses,
        "win_rate_pct": round(wins * 100.0 / resolved_instances, 4) if resolved_instances else None,
        "profit_factor": round(gross_profit / gross_loss, 4) if gross_loss else None,
        "average_return_pct": round(sum(average_returns) / len(average_returns), 4) if average_returns else None,
        "median_return_pct": round(sum(median_returns) / len(median_returns), 4) if median_returns else None,
        "gross_profit_pct": round(gross_profit, 4) if histories else None,
        "gross_loss_pct": round(-gross_loss, 4) if histories else None,
        "source": "MODEL_BUILDER_PACKET",
        "source_reference": "historical-performance.json + historical-instance-ledger.json",
    }


def _historical_trade_ledger(
    configuration: Dict[str, Any],
    strategy_code: str,
    version_code: str,
    deduplication_by_fingerprint: Optional[Dict[str, str]] = None,
) -> List[Dict[str, Any]]:
    """Return immutable model-builder trade records for the admin detail view.

    Newer SQL catalogues may carry the ledger in ConfigurationJson. The local
    packet fallback keeps already-provisioned catalogues readable until their
    next idempotent provisioning run, without using manual TradePlan data.
    """
    ledger = configuration.get("historical_trade_ledger") or configuration.get("per_instance_ledger")
    if not ledger:
        packet_root = Path(__file__).resolve().parents[2] / "data" / "strategy_runtime"
        for filename in ("historical-instance-ledger.json", "per-instance-ledger.json"):
            for path in sorted(packet_root.glob(f"*/{filename}")):
                try:
                    candidate = json.loads(path.read_text(encoding="utf-8"))
                except (OSError, TypeError, ValueError, json.JSONDecodeError):
                    continue
                if (
                    str(candidate.get("strategy_code") or "") == str(strategy_code)
                    and str(candidate.get("version_code") or "") == str(version_code)
                ):
                    ledger = candidate
                    break
            if ledger:
                break
    if not ledger:
        packet_root = Path(__file__).resolve().parents[2] / "data" / "strategy_runtime"
        for path in sorted(packet_root.glob("*/historical-instance-ledger.csv")):
            try:
                descriptor_path = path.parent / "strategy.descriptor.json"
                descriptor = json.loads(descriptor_path.read_text(encoding="utf-8"))
                if (
                    str(descriptor.get("strategy_code") or "") == str(strategy_code)
                    and str(descriptor.get("version_code") or "") == str(version_code)
                ):
                    with path.open("r", encoding="utf-8", newline="") as stream:
                        ledger = {"records": list(csv.DictReader(stream))}
                    break
            except (OSError, TypeError, ValueError, json.JSONDecodeError, csv.Error):
                continue
    records = ledger.get("records") if isinstance(ledger, dict) else ledger
    if not isinstance(records, list):
        return []
    # The repaired SPXW -> QQQ packet stores return/MFE/MAE as fractional
    # returns (0.004 means +0.40%), while older packets store percentage
    # points (0.40 means +0.40%).  Normalize at the API boundary so the
    # frontend formatter has one stable unit.
    fractional_returns = str(strategy_code).upper() == "SPX_GEX_QQQ_V1"

    def optional_value(value: Any) -> Any:
        if value is None or (isinstance(value, str) and not value.strip()):
            return None
        return value

    def percentage_points(value: Any) -> Any:
        value = optional_value(value)
        if value is None or not fractional_returns:
            return value
        try:
            return float(value) * 100.0
        except (TypeError, ValueError):
            return value

    normalized: List[Dict[str, Any]] = []
    for record in records:
        if not isinstance(record, dict):
            continue
        feature_fields = {
            key: record.get(key)
            for key in (
                "signal_raw", "close_change_pct", "put_call_ratio", "pcr_change_pct",
                "sc_gex_current", "sc_gex_threshold_median60", "sc_gex_percentile60",
                "sp_delta_share", "sp_delta_share_threshold_p75_60", "sp_delta_share_percentile60",
                "prior_5d_nq_return", "price_source", "execution_instrument", "proxy_instrument",
                "source_revision", "portfolio_decision",
            )
            if record.get(key) is not None
        }
        entry_timestamp = record.get("entry_timestamp") or record.get("entry_time")
        exit_timestamp = record.get("exit_timestamp") or record.get("exit_time")
        normalized.append({
            "signal_code": str(record.get("signal_code") or ""),
            "market_date": str(record.get("market_date") or ""),
            "direction": str(record.get("direction") or ""),
            "entry_date": _date_part(entry_timestamp) or _date_part(record.get("market_date")),
            "exit_date": _date_part(exit_timestamp) or _date_part(entry_timestamp) or _date_part(record.get("market_date")),
            "deduplication_group_id": (deduplication_by_fingerprint or {}).get(_trade_fingerprint(record)),
            "entry_timestamp": entry_timestamp,
            "entry_price": optional_value(record.get("entry_price")),
            "exit_timestamp": exit_timestamp,
            "exit_price": optional_value(record.get("exit_price")),
            "exit_reason": str(record.get("exit_reason") or ""),
            "gross_return_pct": percentage_points(
                record.get("gross_return_pct")
                if optional_value(record.get("gross_return_pct")) is not None
                else record.get("return_pct")
            ),
            "return_pct": percentage_points(record.get("return_pct")),
            "mfe_pct": percentage_points(record.get("mfe_pct")),
            "mae_pct": percentage_points(record.get("mae_pct")),
            "bars_held": optional_value(record.get("bars_held")),
            "same_bar_ambiguity": bool(record.get("same_bar_ambiguity") if record.get("same_bar_ambiguity") is not None else record.get("ambiguous")),
            "status": str(record.get("status") or record.get("candidate_outcome_status") or ""),
            "features": record.get("features") if isinstance(record.get("features"), dict) else feature_fields,
        })
    return normalized


def _stats(rows: Iterable[Dict[str, Any]], value_key: str = "directional_return_pct") -> Dict[str, Any]:
    values = [float(row[value_key]) for row in rows if row.get(value_key) is not None]
    wins = sum(1 for value in values if value > 0)
    losses = sum(1 for value in values if value < 0)
    gross_profit = sum(value for value in values if value > 0)
    gross_loss = sum(value for value in values if value < 0)
    from statistics import mean, median

    return {
        "instances": len(values),
        "wins": wins,
        "losses": losses,
        "win_rate_pct": round(wins * 100.0 / len(values), 4) if values else None,
        "profit_factor": round(gross_profit / abs(gross_loss), 4) if gross_loss else None,
        "average_return_pct": round(mean(values), 4) if values else None,
        "median_return_pct": round(median(values), 4) if values else None,
        "gross_profit_pct": round(gross_profit, 4) if values else None,
        "gross_loss_pct": round(gross_loss, 4) if values else None,
    }


def _actual_return(direction: Optional[str], entry: Any, exit: Any) -> Optional[float]:
    if entry is None or exit is None or float(entry) == 0:
        return None
    value = (float(exit) - float(entry)) / float(entry) * 100.0
    return round(value if str(direction or "").upper() == "LONG" else -value, 4)


class TradingSignalAdminRepository:
    """Deep module for the strategy catalogue, performance, and safe toggles."""

    @staticmethod
    def _instrument_values(stock_code: Optional[str]) -> List[str]:
        normalized = str(stock_code or "").strip().upper()
        if not normalized:
            return []
        values = {normalized}
        if normalized.endswith(".US"):
            values.add(normalized[:-3])
        else:
            values.add(f"{normalized}.US")
        if normalized == "SPX":
            values.update({"SPXW", "SPXW.US"})
        return sorted(values)

    def __init__(self, model_factory: Optional[Callable[[], Any]] = None, connection_factory: Optional[Callable[..., Any]] = None) -> None:
        self._model_factory = model_factory or (
            lambda: get_timed_sql_model(
                database="StockDB_US",
                connection_timeout=settings.sqlserver_connection_timeout,
                query_timeout=settings.trading_signal_admin_query_timeout,
            )
        )
        self._connection_factory = connection_factory or get_db_connection

    def _read_catalog_rows(
        self,
        model: Any,
        *,
        stock_code: Optional[str] = None,
        signal_code: Optional[str] = None,
    ) -> Dict[str, List[Dict[str, Any]]]:
        definitions = model.execute_read_query(
            """
            SELECT StrategyDefinitionID AS strategy_definition_id, StrategyCode AS strategy_code,
                   DisplayName AS display_name, Description AS description, IsEnabled AS is_enabled,
                   CreatedUtc AS created_utc
            FROM [StockDB_US].[TradingSignal].[StrategyDefinition]
            ORDER BY StrategyCode
            """,
            [],
        ) or []
        version_filters = ["defn.IsEnabled = 1", "v.Status <> 'RETIRED'"]
        version_values: List[Any] = []
        instrument_values = self._instrument_values(stock_code)
        if instrument_values:
            placeholders = ", ".join("?" for _ in instrument_values)
            version_filters.append(f"""
                EXISTS (
                    SELECT 1
                    FROM [StockDB_US].[TradingSignal].[StrategyDeployment] AS filter_deployment
                    JOIN [StockDB_US].[TradingSignal].[StrategyInstrumentRole] AS filter_role
                      ON filter_role.StrategyDeploymentID = filter_deployment.StrategyDeploymentID
                    WHERE filter_deployment.StrategyVersionID = v.StrategyVersionID
                      AND UPPER(filter_role.InstrumentCode) IN ({placeholders})
                )
            """)
            version_values.extend(instrument_values)
        if signal_code and signal_code.strip():
            version_filters.append("""
                EXISTS (
                    SELECT 1
                    FROM [StockDB_US].[TradingSignal].[Signal] AS filter_signal
                    WHERE filter_signal.StrategyVersionID = v.StrategyVersionID
                      AND UPPER(filter_signal.Classification) = ?
                )
            """)
            version_values.append(signal_code.strip().upper())

        versions = model.execute_read_query(
            f"""
            SELECT v.StrategyVersionID AS strategy_version_id, v.StrategyDefinitionID AS strategy_definition_id,
                   v.VersionCode AS version_code, v.ImplementationKey AS implementation_key,
                   v.ConfigurationJson AS configuration_json, v.ResearchMetadataJson AS research_metadata_json,
                   v.Status AS status, v.CreatedUtc AS created_utc,
                   d.StrategyDeploymentID AS strategy_deployment_id, d.DeploymentKey AS deployment_key,
                   d.EnvironmentType AS environment, d.IsEnabled AS is_enabled,
                   d.ExecutionEnabled AS execution_enabled, d.NotificationEnabled AS notification_enabled,
                   d.ConfigurationJson AS deployment_configuration_json,
                   COALESCE((
                       SELECT hd.TradeFingerprint AS trade_fingerprint,
                              CONVERT(nvarchar(36), hd.DeduplicationGroupID) AS deduplication_group_id
                       FROM [StockDB_US].[TradingSignal].[HistoricalTradeDeduplication] AS hd
                       WHERE hd.StrategyVersionID = v.StrategyVersionID
                       FOR JSON PATH
                   ), '[]') AS historical_trade_deduplication_json,
                   eval_schedule.TimeZoneName AS evaluation_timezone_name,
                   eval_schedule.LocalTime AS evaluation_local_time,
                   eval_schedule.CadenceSeconds AS evaluation_cadence_seconds,
                   eval_schedule.ScheduleJson AS evaluation_schedule_json
            FROM [StockDB_US].[TradingSignal].[StrategyVersion] AS v
            JOIN [StockDB_US].[TradingSignal].[StrategyDefinition] AS defn
              ON defn.StrategyDefinitionID = v.StrategyDefinitionID
            LEFT JOIN [StockDB_US].[TradingSignal].[StrategyDeployment] AS d
              ON d.StrategyVersionID = v.StrategyVersionID
            LEFT JOIN (
                SELECT s.StrategyDeploymentID, s.TimeZoneName, s.LocalTime, s.CadenceSeconds, s.ScheduleJson,
                       ROW_NUMBER() OVER (
                           PARTITION BY s.StrategyDeploymentID
                           ORDER BY s.StrategyScheduleID
                       ) AS schedule_row_number
                FROM [StockDB_US].[TradingSignal].[StrategySchedule] AS s
                WHERE s.RunKind = 'EVALUATE' AND s.IsEnabled = 1
            ) AS eval_schedule
              ON eval_schedule.StrategyDeploymentID = d.StrategyDeploymentID
             AND eval_schedule.schedule_row_number = 1
            WHERE {' AND '.join(version_filters)}
            ORDER BY defn.StrategyCode, v.CreatedUtc DESC, d.StrategyDeploymentID
            """,
            version_values,
        ) or []
        roles = model.execute_read_query(
            """
            SELECT StrategyDeploymentID AS strategy_deployment_id, InstrumentCode AS instrument_code,
                   RoleCode AS role_code
            FROM [StockDB_US].[TradingSignal].[StrategyInstrumentRole]
            """,
            [],
        ) or []
        directions = model.execute_read_query(
            """
            SELECT s.StrategyVersionID AS strategy_version_id, UPPER(s.Direction) AS direction,
                   UPPER(s.Classification) AS classification
            FROM [StockDB_US].[TradingSignal].[Signal] AS s
            WHERE s.Direction IN ('LONG', 'SHORT') OR s.Classification IS NOT NULL
            GROUP BY s.StrategyVersionID, UPPER(s.Direction), UPPER(s.Classification)
            """,
            [],
        ) or []
        outcomes = model.execute_read_query(
            """
            WITH ranked AS (
                SELECT so.SignalID AS signal_id, so.HorizonCode AS horizon_code,
                       so.DirectionalReturnPct AS directional_return_pct,
                   s.StrategyVersionID AS strategy_version_id,
                   s.Classification AS classification,
                   o.StrategyDeploymentID AS strategy_deployment_id,
                   d.EnvironmentType AS environment,
                   o.MarketDate AS market_date,
                       ROW_NUMBER() OVER (
                           PARTITION BY so.SignalID, so.HorizonCode
                           ORDER BY so.RevisionNo DESC, so.SignalOutcomeID DESC
                       ) AS row_number
                FROM [StockDB_US].[TradingSignal].[SignalOutcome] AS so
                JOIN [StockDB_US].[TradingSignal].[Signal] AS s ON s.SignalID = so.SignalID
                JOIN [StockDB_US].[TradingSignal].[Observation] AS o ON o.ObservationID = s.ObservationID
                JOIN [StockDB_US].[TradingSignal].[StrategyDeployment] AS d ON d.StrategyDeploymentID = o.StrategyDeploymentID
                WHERE so.FinalizedUtc IS NOT NULL
                  AND so.NullReason IS NULL
                  AND so.DirectionalReturnPct IS NOT NULL
            )
            SELECT ranked.strategy_version_id, ranked.strategy_deployment_id,
                   ranked.signal_id, ranked.classification, ranked.market_date,
                   ranked.horizon_code, ranked.directional_return_pct
            FROM ranked
            JOIN [StockDB_US].[TradingSignal].[Signal] AS signal ON signal.SignalID = ranked.signal_id
            WHERE ranked.row_number = 1 AND signal.ActionCode = 'PLAN_ENTRY'
            """,
            [],
        ) or []
        executions = model.execute_read_query(
            """
            SELECT p.TradePlanID AS trade_plan_id, s.SignalID AS signal_id,
                   s.StrategyVersionID AS strategy_version_id, v.VersionCode AS strategy_version_code,
                   d.StrategyDeploymentID AS strategy_deployment_id,
                   d.DeploymentKey AS deployment_key, o.MarketDate AS market_date,
                   s.Classification AS classification, s.Direction AS direction,
                   p.ExecutionInstrumentCode AS execution_instrument_code, COALESCE(p.PlanStatus, 'NOT_ENTERED') AS plan_status,
                   p.PlannedEntryUtc AS planned_entry_utc, p.PlannedExitUtc AS planned_exit_utc,
                   p.ActualEntryUtc AS actual_entry_utc, p.ActualEntryPrice AS actual_entry_price,
                   p.ActualExitUtc AS actual_exit_utc, p.ActualExitPrice AS actual_exit_price,
                   p.ExitReason AS exit_reason,
                   outcome.HorizonCode AS outcome_horizon,
                   outcome.FinalizedUtc AS outcome_finalized_utc,
                   outcome.DirectionalReturnPct AS simulated_return_pct,
                   outcome.ReferencePrice AS simulated_reference_price,
                   outcome.HorizonClose AS simulated_exit_price,
                   TRY_CONVERT(decimal(19,8), JSON_VALUE(outcome.SourceManifestJson, '$.outcome.entry_price')) AS simulated_entry_price,
                   JSON_VALUE(outcome.SourceManifestJson, '$.outcome.exit_reason') AS simulated_exit_reason
            FROM [StockDB_US].[TradingSignal].[Signal] AS s
            JOIN [StockDB_US].[TradingSignal].[StrategyVersion] AS v ON v.StrategyVersionID = s.StrategyVersionID
            JOIN [StockDB_US].[TradingSignal].[Observation] AS o ON o.ObservationID = s.ObservationID
            JOIN [StockDB_US].[TradingSignal].[StrategyDeployment] AS d ON d.StrategyDeploymentID = o.StrategyDeploymentID
            LEFT JOIN [StockDB_US].[TradingSignal].[ExecutionBook] AS b
              ON b.StrategyDeploymentID = d.StrategyDeploymentID AND b.EnvironmentType = d.EnvironmentType
            LEFT JOIN [StockDB_US].[TradingSignal].[TradePlan] AS p
              ON p.SignalID = s.SignalID AND p.ExecutionBookID = b.ExecutionBookID
            LEFT JOIN (
                SELECT ranked.SignalID, ranked.HorizonCode, ranked.FinalizedUtc,
                       ranked.DirectionalReturnPct, ranked.ReferencePrice,
                       ranked.HorizonClose, ranked.SourceManifestJson
                FROM (
                    SELECT so.SignalID, so.HorizonCode, so.FinalizedUtc,
                           so.DirectionalReturnPct, so.ReferencePrice,
                           so.HorizonClose, so.SourceManifestJson,
                           ROW_NUMBER() OVER (
                               PARTITION BY so.SignalID
                               ORDER BY CASE WHEN so.HorizonCode = COALESCE(signal_for_outcome.HoldingPeriodCode, 'D5') THEN 0 ELSE 1 END,
                                        so.RevisionNo DESC, so.SignalOutcomeID DESC
                           ) AS outcome_row_number
                    FROM [StockDB_US].[TradingSignal].[SignalOutcome] AS so
                    JOIN [StockDB_US].[TradingSignal].[Signal] AS signal_for_outcome
                      ON signal_for_outcome.SignalID = so.SignalID
                    WHERE so.FinalizedUtc IS NOT NULL AND so.NullReason IS NULL
                ) AS ranked
                WHERE ranked.outcome_row_number = 1
            ) AS outcome ON outcome.SignalID = s.SignalID
            WHERE LOWER(d.DeploymentKey) LIKE '%production%'
              AND d.EnvironmentType <> 'MIGRATION_SHADOW'
              AND v.Status <> 'RETIRED'
              AND s.ActionCode = 'PLAN_ENTRY'
            """ + (f"""
              AND EXISTS (
                  SELECT 1
                  FROM [StockDB_US].[TradingSignal].[StrategyInstrumentRole] AS filter_role
                  WHERE filter_role.StrategyDeploymentID = d.StrategyDeploymentID
                    AND UPPER(filter_role.InstrumentCode) IN ({', '.join('?' for _ in instrument_values)})
              )
            """ if instrument_values else "") + (" AND UPPER(s.Classification) = ?\n" if signal_code and signal_code.strip() else "") + """
            ORDER BY s.SignalID DESC
            """,
            instrument_values + ([signal_code.strip().upper()] if signal_code and signal_code.strip() else []),
        ) or []
        return {
            "definitions": [dict(row) for row in definitions],
            "versions": [dict(row) for row in versions],
            "roles": [dict(row) for row in roles],
            "directions": [dict(row) for row in directions],
            "outcomes": [dict(row) for row in outcomes],
            "executions": [dict(row) for row in executions],
        }

    @staticmethod
    def _is_production(row: Dict[str, Any]) -> bool:
        return "production" in str(row.get("deployment_key") or "").lower() and str(row.get("environment") or "").upper() != "MIGRATION_SHADOW"

    def list_strategies(
        self,
        *,
        stock_code: Optional[str] = None,
        signal_code: Optional[str] = None,
    ) -> Dict[str, Any]:
        model = self._model_factory()
        try:
            data = self._read_catalog_rows(model, stock_code=stock_code, signal_code=signal_code)
        finally:
            model.close()

        definition_by_id = {int(row["strategy_definition_id"]): row for row in data["definitions"]}
        active_versions = [
            row for row in data["versions"]
            if str(row.get("status") or "").upper() != "RETIRED"
        ]
        roles_by_deployment: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
        for row in data["roles"]:
            roles_by_deployment[int(row["strategy_deployment_id"])].append(row)
        directions_by_version: Dict[int, List[str]] = defaultdict(list)
        signal_names_by_version: Dict[int, List[str]] = defaultdict(list)
        for row in data["directions"]:
            if row.get("direction"):
                directions_by_version[int(row["strategy_version_id"])].append(str(row["direction"]).upper())
            if row.get("classification"):
                signal_names_by_version[int(row["strategy_version_id"])].append(str(row["classification"]).upper())
        configuration_by_version = {
            int(row["strategy_version_id"]): _json_object(row.get("configuration_json"))
            for row in active_versions
        }
        outcomes_by_version: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
        outcomes_by_signal: Dict[tuple[int, str], List[Dict[str, Any]]] = defaultdict(list)
        outcomes_by_deployment: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
        for row in data["outcomes"]:
            version_id = int(row["strategy_version_id"])
            signal_code = str(row.get("classification") or "").upper()
            horizon = str(row.get("horizon_code") or "").upper()
            if horizon and horizon != _terminal_horizon(configuration_by_version.get(version_id, {}), signal_code):
                continue
            if str(row.get("environment") or "").upper() == "BACKTEST":
                outcomes_by_version[version_id].append(row)
                if signal_code:
                    outcomes_by_signal[(version_id, signal_code)].append(row)
            if row.get("strategy_deployment_id") is not None:
                outcomes_by_deployment[int(row["strategy_deployment_id"])].append(row)
        executions_by_deployment_key: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        for row in data["executions"]:
            calculated = row.get("simulated_return_pct")
            row["actual_return_pct"] = float(calculated) if calculated is not None else None
            row["outcome_status"] = "FINALIZED" if calculated is not None else "WAITING_MARKET_DATA"
            row["execution_mode"] = "SIMULATED_MARKET_OUTCOME"
            row["calculated_entry_price"] = row.get("simulated_entry_price") or row.get("simulated_reference_price")
            row["calculated_exit_price"] = row.get("simulated_exit_price")
            row["calculated_exit_reason"] = row.get("simulated_exit_reason")
            executions_by_deployment_key[str(row["deployment_key"])].append(row)
        deployments_by_version: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
        for row in active_versions:
            if row.get("strategy_deployment_id") is not None:
                deployments_by_version[int(row["strategy_version_id"])].append(row)

        stocks: Dict[str, Dict[int, Dict[str, Any]]] = defaultdict(dict)
        for row in active_versions:
            definition = definition_by_id.get(int(row["strategy_definition_id"]), {})
            version_id = int(row["strategy_version_id"])
            config = _json_object(row.get("configuration_json"))
            research = _json_object(row.get("research_metadata_json"))
            metadata = [config, research]
            descriptor_signals = _descriptor_signals(config)
            for descriptor in descriptor_signals:
                signal_code = str(descriptor.get("signal_code") or "").upper()
                descriptor["historical_performance"] = _model_builder_historical_performance(descriptor)
            deployment_rows = deployments_by_version.get(version_id, [])
            role_rows = [role for deployment in deployment_rows for role in roles_by_deployment.get(int(deployment["strategy_deployment_id"]), [])]
            subject_roles = [role for role in role_rows if str(role.get("role_code") or "").upper() == "SUBJECT"]
            grouping_roles = subject_roles or [role for role in role_rows if str(role.get("role_code") or "").upper() == "SOURCE"]
            grouping_roles = grouping_roles or [role for role in role_rows if str(role.get("role_code") or "").upper() == "EXECUTION"]
            stock_codes = sorted({str(role.get("instrument_code")).strip() for role in grouping_roles if role.get("instrument_code")})
            if not stock_codes:
                fallback = config.get("subject_instrument_code") or config.get("instrument_code") or "UNSPECIFIED"
                stock_codes = [str(fallback)]
            stock_codes = ["SPX" if code.upper() in {"SPXW", "SPXW.US"} else code for code in stock_codes]
            definition_value = config.get("strategy_definition") or config.get("definition")
            if isinstance(definition_value, dict):
                definition_value = " ".join(
                    str(piece).strip()
                    for piece in (definition_value.get("purpose"), definition_value.get("rationale"))
                    if piece
                )
            definition_text = [str(definition_value).strip()] if definition_value else _metadata_values(metadata, ("strategy_definition",))
            trigger_conditions = _metadata_values(metadata, ("trigger_conditions", "trigger_condition", "entry_conditions", "entry_rule"))
            if not trigger_conditions:
                trigger_conditions = sorted({str(item.get("trigger_condition")) for item in descriptor_signals if item.get("trigger_condition")})
            exit_conditions = _metadata_values(metadata, ("exit_conditions", "exit_condition"))
            if not exit_conditions:
                exit_conditions = sorted({
                    str(exit_item.get("description"))
                    for item in descriptor_signals
                    for exit_item in item.get("exit_conditions", [])
                    if isinstance(exit_item, dict) and exit_item.get("description")
                })
            for stock_code in stock_codes:
                version_payload = stocks[stock_code].get(version_id)
                if version_payload is None:
                    model_builder_stats = _descriptor_stats(
                        descriptor_signals,
                        config.get("historical_performance_summary") if isinstance(config.get("historical_performance_summary"), dict) else None,
                    )
                    historical_stats = model_builder_stats
                    # Legacy versions may not carry packet research metadata.
                    # Preserve their existing runtime-outcome fallback, while
                    # never allowing it to replace published packet statistics.
                    if not model_builder_stats["instances"] and outcomes_by_version.get(version_id):
                        historical_stats = _stats(outcomes_by_version[version_id])
                    try:
                        deduplication_rows = json.loads(row.get("historical_trade_deduplication_json") or "[]")
                    except (TypeError, ValueError, json.JSONDecodeError):
                        deduplication_rows = []
                    deduplication_by_fingerprint = {
                        str(item.get("trade_fingerprint")): str(item.get("deduplication_group_id"))
                        for item in deduplication_rows
                        if isinstance(item, dict) and item.get("trade_fingerprint") and item.get("deduplication_group_id")
                    }
                    version_payload = {
                        "strategy_version_id": version_id,
                        "strategy_code": str(definition.get("strategy_code") or ""),
                        "display_name": str(definition.get("display_name") or definition.get("strategy_code") or "Strategy"),
                        "version_code": str(row["version_code"]),
                        "implementation_key": row.get("implementation_key"),
                        "status": str(row.get("status") or ""),
                        "created_utc": row.get("created_utc"),
                        "strategy_definition": definition_text[0] if definition_text else str(definition.get("description") or definition.get("display_name") or "Not recorded in strategy metadata"),
                        "trigger_conditions": trigger_conditions,
                        "exit_conditions": exit_conditions,
                        "signal_names": sorted(set(signal_names_by_version.get(version_id, []))),
                        "signals": descriptor_signals,
                        "directions": sorted(set(directions_by_version.get(version_id, [])) | {str(value).upper() for value in config.get("directions", []) if value}),
                        "configuration": config,
                        "historical_trades": _historical_trade_ledger(
                            config,
                            str(definition.get("strategy_code") or ""),
                            str(row.get("version_code") or ""),
                            deduplication_by_fingerprint,
                        ),
                        # Prefer the model-builder's frozen packet result. The
                        # runtime fallback is only for legacy versions with no
                        # packet statistics at all.
                        "historical_stats": historical_stats,
                        "deployments": [],
                    }
                    if not version_payload["directions"]:
                        version_payload["directions"] = ["UNKNOWN"]
                    stocks[stock_code][version_id] = version_payload
                existing_deployment_ids = {deployment["strategy_deployment_id"] for deployment in version_payload["deployments"]}
                for deployment in deployment_rows:
                    deployment_id = int(deployment["strategy_deployment_id"])
                    if deployment_id in existing_deployment_ids:
                        continue
                    production = self._is_production(deployment)
                    schedule_json = _json_object(deployment.get("evaluation_schedule_json"))
                    deployment_payload = {
                        "strategy_deployment_id": deployment_id,
                        "deployment_key": str(deployment["deployment_key"]),
                        "environment": str(deployment["environment"]),
                        "is_enabled": bool(deployment.get("is_enabled")),
                        "notification_enabled": bool(deployment.get("notification_enabled")),
                        "execution_enabled": bool(deployment.get("execution_enabled")),
                        "is_production": production,
                        "notification_only": not bool(deployment.get("execution_enabled")),
                        "evaluation_schedule": {
                            "timezone_name": str(deployment["evaluation_timezone_name"]) if deployment.get("evaluation_timezone_name") else None,
                            "local_time": str(deployment["evaluation_local_time"]) if deployment.get("evaluation_local_time") else None,
                            "cadence_seconds": int(deployment["evaluation_cadence_seconds"]) if deployment.get("evaluation_cadence_seconds") is not None else None,
                            "interval_minutes": int(schedule_json["interval_minutes"]) if schedule_json.get("interval_minutes") is not None else None,
                            "window_end": str(schedule_json["window_end"]) if schedule_json.get("window_end") else None,
                        },
                        "production_stats": _stats(outcomes_by_deployment.get(deployment_id, [])) if production else _stats([]),
                        "executions": executions_by_deployment_key.get(str(deployment["deployment_key"]), []),
                    }
                    version_payload["deployments"].append(deployment_payload)

        stock_payload = [
            {"stock_code": stock_code, "strategies": list(versions.values())}
            for stock_code, versions in sorted(stocks.items())
        ]
        all_versions = [version for stock in stock_payload for version in stock["strategies"]]
        production_deployments = [deployment for version in all_versions for deployment in version["deployments"] if deployment["is_production"]]
        return {
            "generated_utc": datetime.now(timezone.utc),
            "stocks": stock_payload,
            "strategy_count": len(all_versions),
            "production_deployment_count": len(production_deployments),
            "enabled_production_deployment_count": sum(1 for deployment in production_deployments if deployment["is_enabled"]),
        }

    def set_production_enabled(self, deployment_id: int, enabled: bool, actor: str) -> Dict[str, Any]:
        connection = self._connection_factory(database="StockDB_US", connection_timeout=settings.sqlserver_connection_timeout)
        try:
            connection.timeout = 10
            cursor = connection.cursor()
            row = cursor.execute(
                """
                SELECT d.StrategyDeploymentID AS strategy_deployment_id, d.DeploymentKey AS deployment_key,
                       d.EnvironmentType AS environment, d.IsEnabled AS is_enabled,
                       d.NotificationEnabled AS notification_enabled, d.ExecutionEnabled AS execution_enabled
                FROM [StockDB_US].[TradingSignal].[StrategyDeployment] AS d WITH (UPDLOCK, HOLDLOCK)
                JOIN [StockDB_US].[TradingSignal].[StrategyVersion] AS v ON v.StrategyVersionID = d.StrategyVersionID
                JOIN [StockDB_US].[TradingSignal].[StrategyDefinition] AS defn ON defn.StrategyDefinitionID = v.StrategyDefinitionID
                WHERE d.StrategyDeploymentID = ? AND defn.IsEnabled = 1
                  AND LOWER(d.DeploymentKey) LIKE '%production%'
                  AND d.EnvironmentType <> 'MIGRATION_SHADOW'
                """,
                [deployment_id],
            ).fetchone()
            if row is None:
                raise ProductionDeploymentNotFound("Only enabled production deployments can be changed")
            columns = [column[0] for column in cursor.description]
            current = dict(zip(columns, row))
            cursor.execute(
                """
                UPDATE [StockDB_US].[TradingSignal].[StrategyDeployment]
                SET IsEnabled = ?, NotificationEnabled = ?, ExecutionEnabled = 0
                WHERE StrategyDeploymentID = ?
                """,
                [1 if enabled else 0, 1 if enabled else 0, deployment_id],
            )
            payload = json.dumps({
                "actor": actor,
                "deployment_id": deployment_id,
                "deployment_key": current["deployment_key"],
                "previous_is_enabled": bool(current["is_enabled"]),
                "new_is_enabled": enabled,
                "previous_notification_enabled": bool(current["notification_enabled"]),
                "new_notification_enabled": enabled,
                "execution_enabled": False,
            }, separators=(",", ":"))
            cursor.execute(
                """
                INSERT INTO [StockDB_US].[TradingSignal].[AuditEvent] (EventType, Source, PayloadJson)
                VALUES (?, ?, ?)
                """,
                ["STRATEGY_PRODUCTION_TOGGLE", "WEB_ADMIN", payload],
            )
            connection.commit()
            return {
                "strategy_deployment_id": deployment_id,
                "deployment_key": current["deployment_key"],
                "environment": current["environment"],
                "is_enabled": enabled,
                "notification_enabled": enabled,
                "execution_enabled": False,
                "is_production": True,
                "notification_only": True,
                "production_stats": _stats([]),
                "executions": [],
            }
        except Exception:
            connection.rollback()
            raise
        finally:
            try:
                cursor.close()
            except (UnboundLocalError, AttributeError):
                pass
            connection.close()
