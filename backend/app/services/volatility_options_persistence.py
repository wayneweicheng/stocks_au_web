from __future__ import annotations

import json
import logging
import uuid
from datetime import date, datetime, timezone
from typing import Any, Mapping

from app.core.db import get_sql_model

logger = logging.getLogger("app.volatility_options.persistence")


def _json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), default=str)


def _value(row: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in row and row[key] is not None:
            return row[key]
    return None


def new_run_id(prefix: str = "vso") -> str:
    return f"{prefix}-{datetime.now(timezone.utc):%Y%m%d%H%M%S}-{uuid.uuid4().hex[:12]}"


class VolatilityOptionsStore:
    """Deep persistence interface for scans, candidates, manual positions, and alerts."""

    def __init__(self, model: Any | None = None) -> None:
        self.model = model or get_sql_model()

    def save_backtest_dataset(self, dataset: Mapping[str, Any], run_id: str) -> None:
        snapshots = dataset.get("snapshots") if isinstance(dataset.get("snapshots"), list) else []
        dates = [str(item.get("as_at"))[:10] for item in snapshots if isinstance(item, Mapping) and item.get("as_at")]
        self.model.execute_update_usp(
            """
            INSERT INTO [Analysis].[VolatilitySelectiveBacktestDataset]
                (RunId, DatasetName, StartDate, EndDate, Source, DatasetJson)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                run_id,
                dataset.get("dataset_name"),
                min(dates) if dates else None,
                max(dates) if dates else None,
                _value(dataset.get("source") or {}, "option_history") if isinstance(dataset.get("source"), Mapping) else None,
                _json(dataset),
            ),
        )

    def record_completed_scan(
        self,
        report: Mapping[str, Any],
        *,
        run_id: str | None = None,
        report_path: str | None = None,
    ) -> str:
        run_id = run_id or new_run_id()
        summary = report.get("summary") if isinstance(report.get("summary"), Mapping) else {}
        portfolio = report.get("portfolio") if isinstance(report.get("portfolio"), Mapping) else {}
        candidates = report.get("candidates") if isinstance(report.get("candidates"), list) else []
        underlyings = report.get("underlying_audit") if isinstance(report.get("underlying_audit"), list) else []
        as_at = str(report.get("as_at") or datetime.now(timezone.utc).isoformat())
        evidence_cutoff = self._date_or_none(as_at)
        self.model.execute_update_usp(
            """
            INSERT INTO [Analysis].[VolatilitySelectiveScan]
                (RunId, AsAt, EvidenceCutoff, Mode, Status, Symbols, AccountEquity,
                 AssignmentExposure, CandidateCount, DisplayedCandidateCount, ReportPath,
                 SummaryJson, CompletedAt)
            VALUES (?, TRY_CONVERT(datetimeoffset(0), ?), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, getutcdate())
            """,
            (
                run_id,
                as_at,
                evidence_cutoff,
                str(report.get("mode") or "research_shadow"),
                "SUCCEEDED",
                ",".join(str(item.get("symbol")) for item in underlyings if isinstance(item, Mapping) and item.get("symbol")),
                _value(report, "account_equity"),
                _value(portfolio, "assignment_exposure"),
                _value(summary, "candidates_passing"),
                _value(summary, "candidates_displayed"),
                report_path,
                _json(summary),
            ),
        )
        for underlying in underlyings:
            if not isinstance(underlying, Mapping):
                continue
            features = underlying.get("features") if isinstance(underlying.get("features"), Mapping) else {}
            self.model.execute_update_usp(
                """
                INSERT INTO [Analysis].[VolatilitySelectiveSnapshot]
                    (RunId, Symbol, AsAt, EvidenceCutoff, Spot, ForecastRV,
                     ForecastUncertainty, ATMIV, TermStructure, Regime, SnapshotJson)
                VALUES (?, TRY_CONVERT(datetimeoffset(0), ?), ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    run_id,
                    as_at,
                    evidence_cutoff,
                    _value(underlying, "spot"),
                    _value(features, "forecast_rv"),
                    _value(features, "forecast_uncertainty"),
                    _value(features, "atm_iv"),
                    _value(features, "term_structure"),
                    _value(features, "regime"),
                    _json(underlying),
                ),
            )
        for candidate in candidates:
            if not isinstance(candidate, Mapping):
                continue
            self._insert_candidate(run_id, candidate)
        return run_id

    def record_failed_scan(self, error: str, *, run_id: str | None = None, as_at: str | None = None) -> str:
        run_id = run_id or new_run_id()
        self.model.execute_update_usp(
            """
            INSERT INTO [Analysis].[VolatilitySelectiveScan]
                (RunId, AsAt, Mode, Status, ErrorMessage, CompletedAt)
            VALUES (?, TRY_CONVERT(datetimeoffset(0), ?), 'research_shadow', 'FAILED', ?, getutcdate())
            """,
            (run_id, as_at or datetime.now(timezone.utc).isoformat(), error[:2000]),
        )
        return run_id

    def _insert_candidate(self, run_id: str, candidate: Mapping[str, Any]) -> None:
        self.model.execute_update_usp(
            """
            INSERT INTO [Analysis].[VolatilitySelectiveCandidate]
                (RunId, [Rank], Symbol, Strategy, Expiration, DTE, ShortOption,
                 ShortStrike, LongOption, LongStrike, Credit, TradeScore, VolatilityEdge,
                 ForecastRV, ShortIV, PutSkew, Delta, Gamma, Theta, Vega, MaxLoss,
                 WorstScenarioLoss, CVaR95, AssignmentNotional, Decision, CandidateJson)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                run_id,
                _value(candidate, "rank"),
                _value(candidate, "symbol"),
                _value(candidate, "strategy"),
                _value(candidate, "expiration"),
                _value(candidate, "dte"),
                _value(candidate, "short_option"),
                _value(candidate, "short_strike"),
                _value(candidate, "long_option"),
                _value(candidate, "long_strike"),
                _value(candidate, "credit"),
                _value(candidate, "trade_score"),
                _value(candidate, "volatility_edge"),
                _value(candidate, "forecast_rv"),
                _value(candidate, "short_iv"),
                _value(candidate, "put_skew"),
                _value(candidate, "delta"),
                _value(candidate, "gamma"),
                _value(candidate, "theta"),
                _value(candidate, "vega"),
                _value(candidate, "max_loss"),
                _value(candidate, "worst_scenario_loss"),
                _value(candidate, "stress_cvar_95"),
                _value(candidate, "assignment_notional"),
                _value(candidate, "decision") or "PASS",
                _json(candidate),
            ),
        )

    def list_scans(self, limit: int = 50) -> list[dict[str, Any]]:
        bounded = max(1, min(int(limit), 500))
        return self.model.execute_read_query(
            f"""
            SELECT TOP {bounded} ScanId, RunId, AsAt, EvidenceCutoff, Mode, Status, Symbols,
                   AccountEquity, AssignmentExposure, CandidateCount,
                   DisplayedCandidateCount, ReportPath, SummaryJson, ErrorMessage,
                   CreatedAt, CompletedAt
            FROM [Analysis].[VolatilitySelectiveScan] WITH (NOLOCK)
            ORDER BY CreatedAt DESC
            """,
            (),
        ) or []

    def list_candidates(self, run_id: str | None = None, limit: int = 100) -> list[dict[str, Any]]:
        bounded = max(1, min(int(limit), 500))
        clauses = "WHERE RunId = ?" if run_id else ""
        values: tuple[Any, ...] = (run_id,) if run_id else ()
        return self.model.execute_read_query(
            f"""
            SELECT TOP {bounded} CandidateId, RunId, [Rank], Symbol, Strategy, Expiration, DTE,
                   ShortOption, ShortStrike, LongOption, LongStrike, Credit, TradeScore,
                   VolatilityEdge, ForecastRV, ShortIV, PutSkew, Delta, Gamma, Theta,
                   Vega, MaxLoss, WorstScenarioLoss, CVaR95, AssignmentNotional,
                   Decision, CandidateJson, CreatedAt
            FROM [Analysis].[VolatilitySelectiveCandidate] WITH (NOLOCK)
            {clauses}
            ORDER BY CreatedAt DESC, [Rank]
            """,
            values,
        ) or []

    def create_manual_position(self, payload: Mapping[str, Any]) -> int:
        result = self.model.execute_read_usp(
            """
            INSERT INTO [Analysis].[VolatilitySelectiveManualPosition]
                (RunId, CandidateId, Symbol, Strategy, ShortOption, LongOption, Expiration,
                 ShortStrike, LongStrike, Quantity, EntryCredit, EntrySpot,
                 ProfitCaptureTarget, TimeExitDTE, RiskDeltaExit, Notes)
            OUTPUT INSERTED.PositionId
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                payload.get("run_id"), payload.get("candidate_id"), payload["symbol"], payload["strategy"],
                payload["short_option"], payload.get("long_option"), payload["expiration"],
                payload["short_strike"], payload.get("long_strike"), payload["quantity"],
                payload["entry_credit"], payload.get("entry_spot"),
                payload.get("profit_capture_target", 0.60), payload.get("time_exit_dte", 14),
                payload.get("risk_delta_exit", 0.45), payload.get("notes"),
            ),
        ) or []
        if result and result[0].get("PositionId") is not None:
            return int(result[0]["PositionId"])
        rows = self.model.execute_read_query(
            "SELECT TOP 1 PositionId FROM [Analysis].[VolatilitySelectiveManualPosition] WHERE Symbol = ? ORDER BY PositionId DESC",
            (payload["symbol"],),
        ) or []
        if not rows:
            raise RuntimeError("Manual position was not persisted")
        return int(rows[0]["PositionId"])

    def get_safety_state(self) -> dict[str, Any]:
        rows = self.model.execute_read_query(
            "SELECT TOP 1 StateId, KillSwitchActive, Reason, UpdatedBy, UpdatedAt FROM [Analysis].[VolatilitySelectiveSafetyState] WITH (NOLOCK) WHERE StateId = 1",
            (),
        ) or []
        return rows[0] if rows else {"StateId": 1, "KillSwitchActive": False, "Reason": "Safety state table is not configured"}

    def set_kill_switch(self, active: bool, reason: str, updated_by: str) -> dict[str, Any]:
        self.model.execute_update_usp(
            """
            UPDATE [Analysis].[VolatilitySelectiveSafetyState]
            SET KillSwitchActive = ?, Reason = ?, UpdatedBy = ?, UpdatedAt = getutcdate()
            WHERE StateId = 1
            """,
            (active, reason[:2000], updated_by[:200]),
        )
        return self.get_safety_state()

    def get_schedule(self, schedule_name: str = "default") -> dict[str, Any] | None:
        rows = self.model.execute_read_query(
            "SELECT TOP 1 * FROM [Configuration].[VolatilitySelectiveSchedule] WITH (NOLOCK) WHERE ScheduleName = ?",
            (schedule_name,),
        ) or []
        return rows[0] if rows else None

    def upsert_schedule(self, payload: Mapping[str, Any], schedule_name: str = "default") -> dict[str, Any]:
        self.model.execute_update_usp(
            """
            MERGE [Configuration].[VolatilitySelectiveSchedule] AS target
            USING (SELECT ? AS ScheduleName) AS source
            ON target.ScheduleName = source.ScheduleName
            WHEN MATCHED THEN UPDATE SET
                Enabled = ?, Symbols = ?, EventClearSymbols = ?, AccountEquity = ?,
                AssignmentExposure = ?, TopN = ?, DteMin = ?, DteMax = ?,
                MinimumVolatilityEdge = ?, RiskBudgetPct = ?, MaxAssignmentExposurePct = ?,
                Timezone = ?, UpdatedAt = getutcdate()
            WHEN NOT MATCHED THEN INSERT
                (ScheduleName, Enabled, Symbols, EventClearSymbols, AccountEquity,
                 AssignmentExposure, TopN, DteMin, DteMax, MinimumVolatilityEdge,
                 RiskBudgetPct, MaxAssignmentExposurePct, Timezone)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            (
                schedule_name,
                payload.get("enabled", False), payload["symbols"], payload.get("event_clear_symbols"),
                payload["account_equity"], payload.get("assignment_exposure", 0), payload.get("top_n", 10),
                payload.get("dte_min", 30), payload.get("dte_max", 55), payload.get("min_vol_edge", 0.02),
                payload.get("risk_budget_pct", 0.02), payload.get("max_assignment_exposure_pct", 0.75),
                payload.get("timezone", "America/New_York"),
                schedule_name, payload.get("enabled", False), payload["symbols"], payload.get("event_clear_symbols"),
                payload["account_equity"], payload.get("assignment_exposure", 0), payload.get("top_n", 10),
                payload.get("dte_min", 30), payload.get("dte_max", 55), payload.get("min_vol_edge", 0.02),
                payload.get("risk_budget_pct", 0.02), payload.get("max_assignment_exposure_pct", 0.75),
                payload.get("timezone", "America/New_York"),
            ),
        )
        result = self.get_schedule(schedule_name)
        if result is None:
            raise RuntimeError("Volatility-selective schedule was not persisted")
        return result

    def list_manual_positions(self, status: str | None = "OPEN") -> list[dict[str, Any]]:
        if status:
            return self.model.execute_read_query(
                """
                SELECT PositionId, RunId, CandidateId, Symbol, Strategy, ShortOption, LongOption,
                       Expiration, ShortStrike, LongStrike, Quantity, EntryCredit, EntrySpot,
                       ProfitCaptureTarget, TimeExitDTE, RiskDeltaExit, Status, CurrentSpot,
                       CurrentIV, CurrentValue, UnrealizedPnL, ExitRecommendation,
                       LastMonitoredAt, ClosedAt, CloseReason, Notes, CreatedAt, UpdatedAt
                FROM [Analysis].[VolatilitySelectiveManualPosition] WITH (NOLOCK)
                WHERE Status = ? ORDER BY Expiration, Symbol, PositionId
                """,
                (status,),
            ) or []
        return self.model.execute_read_query(
            "SELECT * FROM [Analysis].[VolatilitySelectiveManualPosition] WITH (NOLOCK) ORDER BY PositionId DESC",
            (),
        ) or []

    def update_manual_position(self, position_id: int, updates: Mapping[str, Any]) -> None:
        allowed = {
            "current_spot": "CurrentSpot", "current_iv": "CurrentIV", "current_value": "CurrentValue",
            "current_delta": "CurrentDelta", "current_gamma": "CurrentGamma", "current_theta": "CurrentTheta", "current_vega": "CurrentVega",
            "unrealized_pnl": "UnrealizedPnL", "exit_recommendation": "ExitRecommendation",
            "status": "Status", "closed_at": "ClosedAt", "close_reason": "CloseReason",
        }
        assignments: list[str] = []
        values: list[Any] = []
        for key, column in allowed.items():
            if key in updates:
                assignments.append(f"[{column}] = ?")
                values.append(updates[key])
        if not assignments:
            return
        assignments.append("[UpdatedAt] = getutcdate()")
        values.append(position_id)
        self.model.execute_update_usp(
            f"UPDATE [Analysis].[VolatilitySelectiveManualPosition] SET {', '.join(assignments)} WHERE PositionId = ?",
            tuple(values),
        )

    @staticmethod
    def _date_or_none(value: str) -> date | None:
        try:
            return date.fromisoformat(value[:10])
        except (TypeError, ValueError):
            return None
