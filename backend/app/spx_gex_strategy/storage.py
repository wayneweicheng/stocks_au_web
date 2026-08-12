from __future__ import annotations

import hashlib
import json
import sqlite3
from contextlib import contextmanager
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Iterator, Mapping

from .models import (
    Direction,
    EnvironmentType,
    PortfolioSnapshot,
    PortfolioState,
    SignalEvaluation,
    TradePlan,
)


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _json(value: Any) -> str:
    return json.dumps(value, separators=(",", ":"), default=str)


def _idempotent_id(key: str) -> str:
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:32]


class StrategyStore:
    """SQLite persistence for idempotent signals, plans, shadow state and events."""

    def __init__(self, path: str | Path) -> None:
        self._memory = str(path) == ":memory:"
        self.path = Path(path)
        self._memory_connection: sqlite3.Connection | None = None
        if self._memory:
            self._memory_connection = sqlite3.connect(":memory:", timeout=15, isolation_level=None)
            self._memory_connection.row_factory = sqlite3.Row
        else:
            self.path.parent.mkdir(parents=True, exist_ok=True)
        self.initialize()

    @contextmanager
    def connection(self) -> Iterator[sqlite3.Connection]:
        if self._memory_connection is not None:
            self._memory_connection.execute("PRAGMA foreign_keys = ON")
            yield self._memory_connection
            return
        connection = sqlite3.connect(self.path, timeout=15, isolation_level=None)
        connection.row_factory = sqlite3.Row
        try:
            connection.execute("PRAGMA foreign_keys = ON")
            yield connection
        finally:
            connection.close()

    def initialize(self) -> None:
        with self.connection() as db:
            db.executescript(
                """
                CREATE TABLE IF NOT EXISTS signals (
                    signal_id TEXT PRIMARY KEY,
                    idempotency_key TEXT NOT NULL UNIQUE,
                    observation_date TEXT NOT NULL,
                    action_date TEXT,
                    actionable_at TEXT,
                    signal_raw TEXT,
                    classification TEXT NOT NULL,
                    trade_allowed INTEGER NOT NULL,
                    skip_reason TEXT,
                    metrics_json TEXT NOT NULL,
                    strategy_version TEXT NOT NULL,
                    environment_type TEXT NOT NULL,
                    git_commit TEXT,
                    config_hash TEXT,
                    data_hash TEXT,
                    base_signal_source_mode TEXT,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS strategy_comparisons (
                    comparison_id TEXT PRIMARY KEY,
                    observation_date TEXT NOT NULL,
                    production_signal_id TEXT NOT NULL REFERENCES signals(signal_id),
                    shadow_signal_id TEXT NOT NULL REFERENCES signals(signal_id),
                    production_strategy_version TEXT NOT NULL,
                    shadow_strategy_version TEXT NOT NULL,
                    environment_type TEXT NOT NULL,
                    production_classification TEXT NOT NULL,
                    shadow_classification TEXT NOT NULL,
                    production_trade_allowed INTEGER NOT NULL,
                    shadow_trade_allowed INTEGER NOT NULL,
                    production_skip_reason TEXT,
                    shadow_skip_reason TEXT,
                    production_actionable_at TEXT,
                    shadow_actionable_at TEXT,
                    production_outcome_status TEXT NOT NULL,
                    production_outcome_json TEXT,
                    shadow_outcome_status TEXT NOT NULL,
                    shadow_outcome_json TEXT,
                    base_signal TEXT,
                    current_sc_gex REAL,
                    sc_threshold_a REAL,
                    sc_low_a INTEGER,
                    sp_share REAL,
                    sp_threshold_a REAL,
                    classification_a TEXT,
                    sc_threshold_b REAL,
                    sc_low_b INTEGER,
                    sp_threshold_b REAL,
                    classification_b TEXT,
                    classification_changed INTEGER,
                    production_variant TEXT,
                    strategy_version TEXT,
                    git_commit TEXT,
                    config_hash TEXT,
                    data_hash TEXT,
                    base_signal_source_mode TEXT,
                    production_hypothetical_outcome_json TEXT,
                    shadow_hypothetical_outcome_json TEXT,
                    portfolio_a_json TEXT,
                    portfolio_b_json TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    UNIQUE (observation_date, production_strategy_version, shadow_strategy_version, environment_type)
                );

                CREATE TABLE IF NOT EXISTS trade_plans (
                    plan_id TEXT PRIMARY KEY,
                    signal_id TEXT NOT NULL UNIQUE REFERENCES signals(signal_id),
                    classification TEXT NOT NULL,
                    status TEXT NOT NULL,
                    observation_date TEXT NOT NULL,
                    action_date TEXT NOT NULL,
                    first_action_at TEXT NOT NULL,
                    direction TEXT NOT NULL,
                    entry_type TEXT NOT NULL,
                    tp_pct REAL,
                    sl_pct REAL,
                    tp_price REAL,
                    sl_price REAL,
                    reference_price REAL,
                    dip_price REAL,
                    planned_exit_at TEXT,
                    entry_price REAL,
                    trade_id TEXT,
                    metadata_json TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS shadow_trades (
                    trade_id TEXT PRIMARY KEY,
                    signal_id TEXT NOT NULL REFERENCES signals(signal_id),
                    plan_id TEXT REFERENCES trade_plans(plan_id),
                    signal_type TEXT NOT NULL,
                    observation_date TEXT NOT NULL,
                    action_date TEXT,
                    entry_timestamp TEXT,
                    entry_price REAL,
                    entry_type TEXT,
                    direction TEXT NOT NULL,
                    quantity REAL,
                    position_notional REAL,
                    tp_pct REAL,
                    tp_price REAL,
                    sl_pct REAL,
                    sl_price REAL,
                    planned_exit_date TEXT,
                    exit_timestamp TEXT,
                    exit_price REAL,
                    exit_reason TEXT,
                    return_pct REAL,
                    pnl_usd REAL,
                    nav_before REAL,
                    nav_after REAL,
                    mfe_pct REAL,
                    mae_pct REAL,
                    bars_held INTEGER,
                    same_bar_ambiguity INTEGER NOT NULL DEFAULT 0,
                    price_source TEXT NOT NULL,
                    strategy_version TEXT NOT NULL,
                    environment_type TEXT NOT NULL,
                    git_commit TEXT,
                    config_hash TEXT,
                    data_hash TEXT,
                    base_signal_source_mode TEXT,
                    status TEXT NOT NULL,
                    actual_status TEXT,
                    actual_entry REAL,
                    actual_exit REAL,
                    actual_quantity REAL,
                    actual_pnl REAL,
                    actual_commission REAL,
                    actual_slippage REAL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS portfolio_state (
                    singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
                    state TEXT NOT NULL,
                    shadow_nav REAL NOT NULL,
                    cash REAL NOT NULL,
                    exposure_factor REAL NOT NULL,
                    active_trade_id TEXT,
                    pending_plan_id TEXT,
                    pending_dip_plan_id TEXT,
                    position_json TEXT,
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS notifications (
                    idempotency_key TEXT PRIMARY KEY,
                    notification_type TEXT NOT NULL,
                    title TEXT NOT NULL,
                    message TEXT NOT NULL,
                    status TEXT NOT NULL,
                    provider_id TEXT,
                    error TEXT,
                    created_at TEXT NOT NULL,
                    sent_at TEXT
                );

                CREATE TABLE IF NOT EXISTS system_events (
                    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_type TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS strategy_reports (
                    report_id TEXT PRIMARY KEY,
                    report_date TEXT NOT NULL,
                    observation_date TEXT,
                    file_name TEXT,
                    report_kind TEXT NOT NULL,
                    strategy_version TEXT NOT NULL,
                    environment_type TEXT NOT NULL,
                    content_hash TEXT NOT NULL,
                    html_content TEXT NOT NULL,
                    generated_at TEXT NOT NULL,
                    UNIQUE (report_date, report_kind, strategy_version, environment_type, content_hash)
                );
                """
            )
            report_columns = {
                row["name"] for row in db.execute("PRAGMA table_info(strategy_reports)").fetchall()
            }
            if "observation_date" not in report_columns:
                db.execute("ALTER TABLE strategy_reports ADD COLUMN observation_date TEXT")
            if "file_name" not in report_columns:
                db.execute("ALTER TABLE strategy_reports ADD COLUMN file_name TEXT")
            self._backfill_report_metadata(db)
            db.execute(
                "CREATE UNIQUE INDEX IF NOT EXISTS ux_strategy_reports_file_name "
                "ON strategy_reports(file_name) WHERE file_name IS NOT NULL"
            )
            db.execute(
                "CREATE INDEX IF NOT EXISTS ix_strategy_reports_generated_at "
                "ON strategy_reports(generated_at DESC)"
            )
            db.execute(
                "CREATE INDEX IF NOT EXISTS ix_strategy_reports_environment_generated_at "
                "ON strategy_reports(environment_type, generated_at DESC)"
            )
            migration_columns = {
                "signals": {
                    "git_commit": "TEXT",
                    "config_hash": "TEXT",
                    "data_hash": "TEXT",
                    "base_signal_source_mode": "TEXT",
                },
                "strategy_comparisons": {
                    "base_signal": "TEXT",
                    "current_sc_gex": "REAL",
                    "sc_threshold_a": "REAL",
                    "sc_low_a": "INTEGER",
                    "sp_share": "REAL",
                    "sp_threshold_a": "REAL",
                    "classification_a": "TEXT",
                    "sc_threshold_b": "REAL",
                    "sc_low_b": "INTEGER",
                    "sp_threshold_b": "REAL",
                    "classification_b": "TEXT",
                    "classification_changed": "INTEGER",
                    "production_variant": "TEXT",
                    "strategy_version": "TEXT",
                    "git_commit": "TEXT",
                    "config_hash": "TEXT",
                    "data_hash": "TEXT",
                    "base_signal_source_mode": "TEXT",
                    "production_hypothetical_outcome_json": "TEXT",
                    "shadow_hypothetical_outcome_json": "TEXT",
                    "portfolio_a_json": "TEXT",
                    "portfolio_b_json": "TEXT",
                },
                "shadow_trades": {
                    "git_commit": "TEXT",
                    "config_hash": "TEXT",
                    "data_hash": "TEXT",
                    "base_signal_source_mode": "TEXT",
                },
            }
            for table, definitions in migration_columns.items():
                existing = {row["name"] for row in db.execute(f"PRAGMA table_info({table})").fetchall()}
                for column, column_type in definitions.items():
                    if column not in existing:
                        db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {column_type}")

    @staticmethod
    def _report_file_name(report_date: date, generated_at: datetime, sequence: int = 1) -> str:
        suffix = "" if sequence == 1 else f"-{sequence:02d}"
        return (
            f"spx-gex-report-{report_date.isoformat()}-"
            f"{generated_at.strftime('%Y%m%d%H%M%S')}{suffix}.html"
        )

    def _backfill_report_metadata(self, db: sqlite3.Connection) -> None:
        rows = db.execute(
            "SELECT report_id, report_date, generated_at, file_name, observation_date "
            "FROM strategy_reports WHERE file_name IS NULL OR observation_date IS NULL ORDER BY generated_at"
        ).fetchall()
        used_names = {str(row["file_name"]) for row in rows if row["file_name"]}
        for row in rows:
            observation_date = row["observation_date"] or row["report_date"]
            file_name = row["file_name"]
            if not file_name:
                generated_at = datetime.fromisoformat(str(row["generated_at"]).replace("Z", "+00:00"))
                report_date = date.fromisoformat(str(row["report_date"]))
                sequence = 1
                file_name = self._report_file_name(report_date, generated_at, sequence)
                while file_name in used_names:
                    sequence += 1
                    file_name = self._report_file_name(report_date, generated_at, sequence)
                used_names.add(file_name)
            db.execute(
                "UPDATE strategy_reports SET observation_date=?, file_name=? WHERE report_id=?",
                (observation_date, file_name, row["report_id"]),
            )

    def ensure_portfolio(self, initial_capital: float, exposure_factor: float) -> None:
        with self.connection() as db:
            db.execute(
                """
                INSERT OR IGNORE INTO portfolio_state
                    (singleton_id, state, shadow_nav, cash, exposure_factor, updated_at)
                VALUES (1, 'FLAT', ?, ?, ?, ?)
                """,
                (initial_capital, initial_capital, exposure_factor, _utc_now()),
            )

    def snapshot(self) -> PortfolioSnapshot:
        with self.connection() as db:
            row = db.execute("SELECT * FROM portfolio_state WHERE singleton_id = 1").fetchone()
        if row is None:
            raise RuntimeError("Portfolio state has not been initialized")
        return PortfolioSnapshot(
            state=PortfolioState(row["state"]),
            shadow_nav=float(row["shadow_nav"]),
            cash=float(row["cash"]),
            exposure_factor=float(row["exposure_factor"]),
            active_trade_id=row["active_trade_id"],
            pending_plan_id=row["pending_plan_id"],
            pending_dip_plan_id=row["pending_dip_plan_id"],
            position=json.loads(row["position_json"]) if row["position_json"] else None,
        )

    def update_portfolio(self, snapshot: PortfolioSnapshot) -> None:
        with self.connection() as db:
            db.execute(
                """
                UPDATE portfolio_state
                SET state=?, shadow_nav=?, cash=?, exposure_factor=?, active_trade_id=?,
                    pending_plan_id=?, pending_dip_plan_id=?, position_json=?, updated_at=?
                WHERE singleton_id=1
                """,
                (
                    snapshot.state.value,
                    snapshot.shadow_nav,
                    snapshot.cash,
                    snapshot.exposure_factor,
                    snapshot.active_trade_id,
                    snapshot.pending_plan_id,
                    snapshot.pending_dip_plan_id,
                    _json(snapshot.position) if snapshot.position else None,
                    _utc_now(),
                ),
            )

    def save_signal(
        self,
        evaluation: SignalEvaluation,
        strategy_version: str,
        environment_type: EnvironmentType,
        provenance_metadata: Mapping[str, Any] | None = None,
        base_signal_source_mode: str | None = None,
    ) -> tuple[str, bool]:
        observation = evaluation.observation
        action_stamp = evaluation.actionable_at.isoformat() if evaluation.actionable_at else "none"
        key = f"{observation.observation_date.isoformat()}|{evaluation.classification.value}|{strategy_version}|{action_stamp}"
        signal_id = _idempotent_id(key)
        metrics = {
            "BC_GEXDelta": observation.bc_gex_delta,
            "BP_GEXDelta": observation.bp_gex_delta,
            "SC_GEXDelta": observation.sc_gex_delta,
            "SP_GEXDelta": observation.sp_gex_delta,
            "SC_GEX": observation.sc_gex,
            "SP_GEX": observation.sp_gex,
            "TotalAbsGEXDelta": observation.total_abs_gex_delta,
            "PutCallRatio": observation.put_call_ratio,
            "CloseChangePct": observation.close_change_pct,
            "PCRChangePct": observation.pcr_change_pct,
            "SP_delta_share": observation.sp_delta_share,
            "SC_rolling_median_60": evaluation.sc_rolling_median_60,
            "SC_percentile_60": evaluation.sc_percentile_60,
            "SP_share_p75_60": evaluation.sp_share_p75_60,
            "SP_share_percentile_60": evaluation.sp_share_percentile_60,
            "prior_5d_nq_return": evaluation.prior_5d_nq_return,
            **observation.derived,
        }
        with self.connection() as db:
            cursor = db.execute(
                """
                INSERT OR IGNORE INTO signals
                    (signal_id, idempotency_key, observation_date, action_date, actionable_at,
                     signal_raw, classification, trade_allowed, skip_reason, metrics_json,
                     strategy_version, environment_type, git_commit, config_hash, data_hash,
                     base_signal_source_mode, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    signal_id,
                    key,
                    observation.observation_date.isoformat(),
                    evaluation.action_date.isoformat() if evaluation.action_date else None,
                    action_stamp if evaluation.actionable_at else None,
                    observation.signal_raw,
                    evaluation.classification.value,
                    int(evaluation.trade_allowed),
                    evaluation.skip_reason,
                    _json(metrics),
                    strategy_version,
                    environment_type.value,
                    (provenance_metadata or {}).get("git_commit"),
                    (provenance_metadata or {}).get("config_hash"),
                    (provenance_metadata or {}).get("data_hash"),
                    base_signal_source_mode or (provenance_metadata or {}).get("base_signal_source_mode"),
                    _utc_now(),
                ),
            )
            inserted = cursor.rowcount == 1
            if not inserted:
                # A rerun can discover a different operational blocker (or
                # recover from one) while retaining the same deterministic
                # signal identity. Refresh the saved decision fields so the
                # next report reflects the current run rather than a stale
                # first-attempt result.
                db.execute(
                    """
                    UPDATE signals
                    SET action_date=?, actionable_at=?, signal_raw=?, classification=?,
                        trade_allowed=?, skip_reason=?, metrics_json=?, environment_type=?,
                        git_commit=?, config_hash=?, data_hash=?, base_signal_source_mode=?
                    WHERE signal_id=?
                    """,
                    (
                        evaluation.action_date.isoformat() if evaluation.action_date else None,
                        action_stamp if evaluation.actionable_at else None,
                        observation.signal_raw,
                        evaluation.classification.value,
                        int(evaluation.trade_allowed),
                        evaluation.skip_reason,
                        _json(metrics),
                        environment_type.value,
                        (provenance_metadata or {}).get("git_commit"),
                        (provenance_metadata or {}).get("config_hash"),
                        (provenance_metadata or {}).get("data_hash"),
                        base_signal_source_mode or (provenance_metadata or {}).get("base_signal_source_mode"),
                        signal_id,
                    ),
                )
            return signal_id, inserted

    def save_plan(self, plan: TradePlan) -> str:
        key = f"plan|{plan.signal_id}|{plan.classification.value}"
        plan_id = _idempotent_id(key)
        now = _utc_now()
        with self.connection() as db:
            db.execute(
                """
                INSERT OR IGNORE INTO trade_plans
                    (plan_id, signal_id, classification, status, observation_date, action_date,
                     first_action_at, direction, entry_type, tp_pct, sl_pct, tp_price, sl_price,
                     reference_price, dip_price, planned_exit_at, entry_price, trade_id,
                     metadata_json, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    plan_id,
                    plan.signal_id,
                    plan.classification.value,
                    plan.status,
                    plan.observation_date.isoformat(),
                    plan.action_date.isoformat(),
                    plan.first_action_at.isoformat(),
                    plan.direction.value,
                    plan.entry_type,
                    plan.tp_pct,
                    plan.sl_pct,
                    plan.tp_price,
                    plan.sl_price,
                    plan.reference_price,
                    plan.dip_price,
                    plan.planned_exit_at.isoformat() if plan.planned_exit_at else None,
                    plan.entry_price,
                    plan.trade_id,
                    _json(plan.metadata),
                    now,
                    now,
                ),
            )
        return plan_id

    def open_plans(self, as_of: datetime | None = None) -> list[sqlite3.Row]:
        with self.connection() as db:
            rows = db.execute(
                "SELECT * FROM trade_plans WHERE status IN ('PLANNED', 'PENDING_GREEN_DIP') ORDER BY first_action_at"
            ).fetchall()
        if as_of is None:
            return rows
        if as_of.tzinfo is None:
            as_of = as_of.replace(tzinfo=timezone.utc)
        active: list[sqlite3.Row] = []
        for row in rows:
            if row["status"] == "PENDING_GREEN_DIP":
                active.append(row)
                continue
            first_action = datetime.fromisoformat(str(row["first_action_at"]))
            if first_action.tzinfo is None:
                first_action = first_action.replace(tzinfo=as_of.tzinfo)
            if first_action <= as_of:
                active.append(row)
        return active

    def plan(self, plan_id: str) -> sqlite3.Row | None:
        with self.connection() as db:
            return db.execute("SELECT * FROM trade_plans WHERE plan_id=?", (plan_id,)).fetchone()

    def plan_id_for_signal(self, signal_id: str) -> str | None:
        with self.connection() as db:
            row = db.execute("SELECT plan_id FROM trade_plans WHERE signal_id=?", (signal_id,)).fetchone()
        return row["plan_id"] if row else None

    def update_plan(self, plan_id: str, **values: Any) -> None:
        allowed = {
            "status", "reference_price", "dip_price", "entry_price", "tp_price", "sl_price", "trade_id", "metadata_json",
            "planned_exit_at", "updated_at",
        }
        unknown = set(values) - allowed
        if unknown:
            raise ValueError(f"Unsupported plan fields: {sorted(unknown)}")
        values.setdefault("updated_at", _utc_now())
        fields = ", ".join(f"{field}=?" for field in values)
        params = list(values.values()) + [plan_id]
        with self.connection() as db:
            db.execute(f"UPDATE trade_plans SET {fields} WHERE plan_id=?", params)

    def insert_trade(self, values: Mapping[str, Any]) -> str:
        trade_id = str(values["trade_id"])
        columns = list(values.keys())
        placeholders = ",".join("?" for _ in columns)
        with self.connection() as db:
            db.execute(
                f"INSERT OR IGNORE INTO shadow_trades ({','.join(columns)}) VALUES ({placeholders})",
                [values[column] for column in columns],
            )
        return trade_id

    def update_trade(self, trade_id: str, **values: Any) -> None:
        values.setdefault("updated_at", _utc_now())
        fields = ", ".join(f"{field}=?" for field in values)
        with self.connection() as db:
            db.execute(f"UPDATE shadow_trades SET {fields} WHERE trade_id=?", [*values.values(), trade_id])

    def trade(self, trade_id: str) -> sqlite3.Row | None:
        with self.connection() as db:
            return db.execute("SELECT * FROM shadow_trades WHERE trade_id=?", (trade_id,)).fetchone()

    def list_trades(self, environment_type: str | None = None) -> list[sqlite3.Row]:
        with self.connection() as db:
            if environment_type:
                return db.execute(
                    "SELECT * FROM shadow_trades WHERE environment_type=? ORDER BY entry_timestamp",
                    (environment_type,),
                ).fetchall()
            return db.execute("SELECT * FROM shadow_trades ORDER BY entry_timestamp").fetchall()

    def recent_signals(
        self,
        limit: int = 50,
        strategy_version: str | None = None,
        environment_type: str | None = None,
    ) -> list[sqlite3.Row]:
        conditions: list[str] = []
        params: list[Any] = []
        if strategy_version:
            conditions.append("strategy_version=?")
            params.append(strategy_version)
        if environment_type:
            conditions.append("environment_type=?")
            params.append(environment_type)
        where = f" WHERE {' AND '.join(conditions)}" if conditions else ""
        params.append(int(limit))
        with self.connection() as db:
            return db.execute(
                f"SELECT * FROM signals{where} "
                "ORDER BY observation_date DESC, created_at DESC LIMIT ?",
                params,
            ).fetchall()

    def save_strategy_comparison(self, values: Mapping[str, Any]) -> str:
        required = {
            "observation_date",
            "production_signal_id",
            "shadow_signal_id",
            "production_strategy_version",
            "shadow_strategy_version",
            "environment_type",
            "production_classification",
            "shadow_classification",
            "production_trade_allowed",
            "shadow_trade_allowed",
            "production_outcome_status",
            "shadow_outcome_status",
        }
        missing = required - set(values)
        if missing:
            raise ValueError(f"Missing strategy comparison fields: {sorted(missing)}")
        key = "|".join(
            (
                str(values["observation_date"]),
                str(values["production_strategy_version"]),
                str(values["shadow_strategy_version"]),
                str(values["environment_type"]),
            )
        )
        comparison_id = _idempotent_id(f"comparison|{key}")
        columns = list(values.keys())
        row_values = [values[column] for column in columns]
        columns.extend(["comparison_id", "created_at", "updated_at"])
        row_values.extend([comparison_id, _utc_now(), _utc_now()])
        placeholders = ",".join("?" for _ in columns)
        with self.connection() as db:
            db.execute(
                f"INSERT OR IGNORE INTO strategy_comparisons ({','.join(columns)}) VALUES ({placeholders})",
                row_values,
            )
        return comparison_id

    def update_strategy_comparison(self, comparison_id: str, **values: Any) -> None:
        allowed = {
            "production_outcome_status",
            "production_outcome_json",
            "shadow_outcome_status",
            "shadow_outcome_json",
            "updated_at",
        }
        unknown = set(values) - allowed
        if unknown:
            raise ValueError(f"Unsupported strategy comparison fields: {sorted(unknown)}")
        if not values:
            return
        values.setdefault("updated_at", _utc_now())
        fields = ", ".join(f"{field}=?" for field in values)
        with self.connection() as db:
            db.execute(
                f"UPDATE strategy_comparisons SET {fields} WHERE comparison_id=?",
                [*values.values(), comparison_id],
            )

    def recent_strategy_comparisons(
        self,
        limit: int = 50,
        environment_type: str | None = None,
        shadow_strategy_version: str | None = None,
    ) -> list[sqlite3.Row]:
        conditions: list[str] = []
        params: list[Any] = []
        if environment_type:
            conditions.append("environment_type=?")
            params.append(environment_type)
        if shadow_strategy_version:
            conditions.append("shadow_strategy_version=?")
            params.append(shadow_strategy_version)
        where = f" WHERE {' AND '.join(conditions)}" if conditions else ""
        params.append(int(limit))
        with self.connection() as db:
            return db.execute(
                f"SELECT * FROM strategy_comparisons{where} "
                "ORDER BY observation_date DESC, created_at DESC LIMIT ?",
                params,
            ).fetchall()

    def save_report(
        self,
        report_date: date,
        html_content: str,
        strategy_version: str,
        environment_type: str,
        report_kind: str = "DAILY_SIGNAL",
        observation_date: date | None = None,
        generated_at: datetime | None = None,
    ) -> str:
        generated_local = generated_at or datetime.now().astimezone()
        if generated_local.tzinfo is None:
            generated_local = generated_local.astimezone()
        generated_utc = generated_local.astimezone(timezone.utc).isoformat()
        stored_html = f"<!-- SPX GEX snapshot generated_at={generated_utc} -->\n{html_content}"
        content_hash = hashlib.sha256(stored_html.encode("utf-8")).hexdigest()
        report_key = "|".join(
            (
                report_date.isoformat(),
                report_kind,
                strategy_version,
                environment_type,
                generated_utc,
                content_hash,
            )
        )
        report_id = _idempotent_id(report_key)
        with self.connection() as db:
            sequence = 1
            file_name = self._report_file_name(report_date, generated_local, sequence)
            while db.execute(
                "SELECT 1 FROM strategy_reports WHERE file_name=? AND report_id<>?",
                (file_name, report_id),
            ).fetchone():
                sequence += 1
                file_name = self._report_file_name(report_date, generated_local, sequence)
            db.execute(
                """
                INSERT OR IGNORE INTO strategy_reports
                    (report_id, report_date, observation_date, file_name, report_kind,
                     strategy_version, environment_type, content_hash, html_content, generated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    report_id,
                    report_date.isoformat(),
                    (observation_date or report_date).isoformat(),
                    file_name,
                    report_kind,
                    strategy_version,
                    environment_type,
                    content_hash,
                    stored_html,
                    generated_utc,
                ),
            )
        return report_id

    def report(self, report_id: str) -> sqlite3.Row | None:
        with self.connection() as db:
            return db.execute("SELECT * FROM strategy_reports WHERE report_id=?", (report_id,)).fetchone()

    def report_for_file_name(
        self,
        file_name: str,
        environment_type: str | None = None,
    ) -> sqlite3.Row | None:
        with self.connection() as db:
            if environment_type:
                return db.execute(
                    "SELECT * FROM strategy_reports WHERE file_name=? AND environment_type=?",
                    (file_name, environment_type),
                ).fetchone()
            return db.execute(
                "SELECT * FROM strategy_reports WHERE file_name=?",
                (file_name,),
            ).fetchone()

    def latest_report(self, environment_type: str | None = None) -> sqlite3.Row | None:
        with self.connection() as db:
            if environment_type:
                return db.execute(
                    "SELECT * FROM strategy_reports WHERE environment_type=? ORDER BY generated_at DESC LIMIT 1",
                    (environment_type,),
                ).fetchone()
            return db.execute("SELECT * FROM strategy_reports ORDER BY generated_at DESC LIMIT 1").fetchone()

    def report_for_date(
        self,
        report_date: date,
        environment_type: str | None = None,
        report_id: str | None = None,
    ) -> sqlite3.Row | None:
        with self.connection() as db:
            if report_id:
                if environment_type:
                    return db.execute(
                        "SELECT * FROM strategy_reports WHERE report_id=? AND report_date=? AND environment_type=?",
                        (report_id, report_date.isoformat(), environment_type),
                    ).fetchone()
                return db.execute(
                    "SELECT * FROM strategy_reports WHERE report_id=? AND report_date=?",
                    (report_id, report_date.isoformat()),
                ).fetchone()
            if environment_type:
                return db.execute(
                    "SELECT * FROM strategy_reports WHERE report_date=? AND environment_type=? ORDER BY generated_at DESC LIMIT 1",
                    (report_date.isoformat(), environment_type),
                ).fetchone()
            return db.execute(
                "SELECT * FROM strategy_reports WHERE report_date=? ORDER BY generated_at DESC LIMIT 1",
                (report_date.isoformat(),),
            ).fetchone()

    def recent_reports(self, limit: int = 100, environment_type: str | None = None) -> list[sqlite3.Row]:
        with self.connection() as db:
            if environment_type:
                return db.execute(
                    "SELECT report_id, report_date, observation_date, file_name, report_kind, strategy_version, environment_type, generated_at FROM strategy_reports WHERE environment_type=? ORDER BY generated_at DESC LIMIT ?",
                    (environment_type, int(limit)),
                ).fetchall()
            return db.execute(
                "SELECT report_id, report_date, observation_date, file_name, report_kind, strategy_version, environment_type, generated_at FROM strategy_reports ORDER BY generated_at DESC LIMIT ?",
                (int(limit),),
            ).fetchall()

    def claim_notification(self, key: str, notification_type: str, title: str, message: str) -> bool:
        now = _utc_now()
        with self.connection() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT status FROM notifications WHERE idempotency_key=?", (key,)).fetchone()
            if row and row["status"] == "SENT":
                db.execute("COMMIT")
                return False
            if row:
                db.execute(
                    "UPDATE notifications SET notification_type=?, title=?, message=?, status='SENDING', error=NULL WHERE idempotency_key=?",
                    (notification_type, title, message, key),
                )
            else:
                db.execute(
                    "INSERT INTO notifications (idempotency_key, notification_type, title, message, status, created_at) VALUES (?, ?, ?, ?, 'SENDING', ?)",
                    (key, notification_type, title, message, now),
                )
            db.execute("COMMIT")
            return True

    def finish_notification(self, key: str, sent: bool, provider_id: str | None = None, error: str | None = None) -> None:
        with self.connection() as db:
            db.execute(
                "UPDATE notifications SET status=?, provider_id=?, error=?, sent_at=? WHERE idempotency_key=?",
                ("SENT" if sent else "FAILED", provider_id, error, _utc_now() if sent else None, key),
            )

    def event(self, event_type: str, payload: Mapping[str, Any]) -> None:
        with self.connection() as db:
            db.execute(
                "INSERT INTO system_events (event_type, payload_json, created_at) VALUES (?, ?, ?)",
                (event_type, _json(dict(payload)), _utc_now()),
            )
