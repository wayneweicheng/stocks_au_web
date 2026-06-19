"""Orchestration and persistence for stock analysis reports."""

from __future__ import annotations

import json
import logging
import subprocess
import sys
import tempfile
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any, Dict, List, Optional

from app.core.db import get_db_connection, get_sql_model
from app.services.stock_analysis.funding_verifier import verify_funding
from app.services.stock_analysis.report_generator import generate_report

logger = logging.getLogger("app.stock_analysis")

DEFAULT_STOCK_ANALYSIS_MODEL = "deepseek/deepseek-v4-flash"
SKILL_ROOT = Path(r"C:\Repo\midas-touch\ASX-spec-analyzer")
SKILL_CONTEXT_PACK_SCRIPT = SKILL_ROOT / "scripts" / "run_asx_context_pack.py"


def _parse_iso_date(value: str) -> date:
    return date.fromisoformat(value)


def validate_transform_broker_coverage(raw_data: Dict[str, Any]) -> None:
    setup_rows = raw_data.get("broker_setup", []) or []
    historical_rows = raw_data.get("broker_historical", []) or []
    micro_rows = raw_data.get("broker_microstructure", []) or []
    broker_effective_date = _parse_iso_date(raw_data["broker_effective_date"])
    setup_snapshot_date = raw_data.get("broker_setup_snapshot_date")
    micro_snapshot_date = raw_data.get("broker_micro_snapshot_date")

    if len(setup_rows) < 5:
        raise ValueError(
            f"Transform broker coverage insufficient: setup rows={len(setup_rows)}; require at least 5."
        )
    if len(micro_rows) < 3:
        raise ValueError(
            f"Transform broker coverage insufficient: micro rows={len(micro_rows)}; require at least 3."
        )
    if not historical_rows:
        raise ValueError("Transform broker coverage insufficient: BrokerHistoricalPerformance snapshot is missing.")

    latest_setup_day = max(
        (row.get("TradeDate") for row in setup_rows if row.get("TradeDate")),
        default=None,
    )
    latest_micro_day = max(
        (row.get("ObservationDate") for row in micro_rows if row.get("ObservationDate")),
        default=None,
    )
    latest_evidence_raw = max(
        [value for value in [latest_setup_day, latest_micro_day] if value is not None],
        default=None,
    )
    if latest_evidence_raw is None:
        raise ValueError(
            "Transform broker coverage insufficient: no setup or micro evidence day available "
            f"(setup_snapshot_date={setup_snapshot_date}, micro_snapshot_date={micro_snapshot_date})."
        )

    latest_evidence_day = _parse_iso_date(str(latest_evidence_raw)[:10])
    if latest_evidence_day < broker_effective_date:
        raise ValueError(
            "Transform broker data is stale versus broker effective date "
            f"({latest_evidence_day.isoformat()} < {broker_effective_date.isoformat()}). "
            f"latest_setup_day={latest_setup_day}, latest_micro_day={latest_micro_day}, "
            f"setup_snapshot_date={setup_snapshot_date}, micro_snapshot_date={micro_snapshot_date}."
        )


def normalize_stock_code(stock_code: str) -> str:
    code = (stock_code or "").strip().upper()
    if not code:
        return code
    return code if code.endswith(".AX") else f"{code}.AX"


def _coerce_datetime(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)


def _coerce_date(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, date):
        return value.isoformat()
    return str(value)


def _json_default(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


_RATING_NORMALIZATION_MAP = {
    "strongly bullish": "Strongly Bullish",
    "mildly bullish": "Mildly Bullish",
    "bullish": "Bullish",
    "neutral": "Neutral",
    "strongly bearish": "Strongly Bearish",
    "mildly bearish": "Mildly Bearish",
    "bearish": "Bearish",
}


def _normalize_rating_label(value: Any, *, max_length: int = 50) -> Optional[str]:
    if value is None:
        return None
    label = str(value).strip()
    if not label:
        return None

    lower_label = label.lower()
    for candidate, normalized in _RATING_NORMALIZATION_MAP.items():
        if candidate in lower_label:
            return normalized[:max_length]

    if len(label) > max_length:
        logger.warning("Truncating overlong stock analysis rating label: %r", label)
        return label[:max_length]
    return label


def _load_json_file(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def _extract_broker_blocker_notes(blockers: List[str]) -> List[str]:
    return [item for item in blockers if "broker_compact.py failed" in item or "broker_digest.py failed" in item]


def _build_neutral_broker_compact(skill_context_pack: Dict[str, Any]) -> Dict[str, Any]:
    blocker_notes = _extract_broker_blocker_notes(skill_context_pack.get("blockers", []) or [])
    broker_effective_date = skill_context_pack.get("broker_effective_date")
    return {
        "asx_code": skill_context_pack.get("asx_market_code") or skill_context_pack.get("asx_code"),
        "generated_at_utc": datetime.utcnow().isoformat(),
        "broker_mode_requested": "transform_only",
        "broker_mode_used": "transform_blocked_neutral",
        "transform_fallback_reason": blocker_notes[0] if blocker_notes else "Transform broker artifact unavailable.",
        "coverage": skill_context_pack.get("coverage", {}).get("broker"),
        "rating": {
            "label": "Neutral",
            "score_0_100": 50,
            "score_interpretation": "Broker scoring blocked by transform freshness gate; neutralized for aggregation.",
            "heuristic_signal_score": None,
            "notes": blocker_notes[:4]
            or ["Transform-only broker evidence was unavailable for this as-at window; broker treated as Neutral."],
            "transform_calibration_note": None,
        },
        "signals": {
            "accumulation_top": [],
            "preferred_accumulator": None,
            "retreat_window": None,
            "category_flow_last_10d": None,
            "tank_days_recent": [],
            "capitulation_events_recent": [],
            "seller_exhaustion_recent": [],
        },
        "transform": {
            "available": False,
            "result": None,
            "diagnostics": {
                "broker_effective_date": broker_effective_date,
                "blocker": blocker_notes[0] if blocker_notes else None,
            },
        },
        "llm_input_policy": {
            "send_raw_broker_day_report_to_llm": False,
            "raw_drill_down_only": True,
        },
    }


def _build_context_pack_from_skill_bundle(
    stock_code: str,
    stock_code_base: str,
    observation_date: date,
    skill_context_pack: Dict[str, Any],
    announcement_compact: Dict[str, Any],
    price_ta_compact: Dict[str, Any],
    broker_compact: Dict[str, Any],
) -> Dict[str, Any]:
    return {
        "metadata": {
            "stock_code": skill_context_pack.get("asx_market_code") or stock_code,
            "stock_code_base": skill_context_pack.get("asx_base_code") or stock_code_base,
            "observation_date": observation_date.isoformat(),
            "effective_trade_date": skill_context_pack.get("effective_trade_date"),
            "broker_effective_date": skill_context_pack.get("broker_effective_date"),
        },
        "data_coverage": skill_context_pack.get("coverage", {}),
        "preliminary_scores": skill_context_pack.get("scores", {}),
        "blockers": skill_context_pack.get("blockers", []),
        "warnings": skill_context_pack.get("warnings", []),
        "artifact_manifest": skill_context_pack.get("compact_artifacts", {}),
        "analysis_inputs": {
            "announcement_material_events": len(announcement_compact.get("material_events", [])),
            "technical_label": price_ta_compact.get("technical_label"),
            "broker_rating_preliminary": ((broker_compact.get("rating") or {}).get("score_0_100")),
        },
    }


def load_skill_context_bundle(stock_code: str, observation_date: date) -> Dict[str, Any]:
    if not SKILL_CONTEXT_PACK_SCRIPT.exists():
        raise FileNotFoundError(f"Skill script not found: {SKILL_CONTEXT_PACK_SCRIPT}")

    exports_root = SKILL_ROOT / "exports"
    exports_root.mkdir(parents=True, exist_ok=True)
    run_dir = Path(
        tempfile.mkdtemp(
            prefix=f"stock_analysis_{stock_code.replace('.', '_')}_{observation_date.isoformat()}_",
            dir=str(exports_root),
        )
    )

    command = [
        sys.executable,
        str(SKILL_CONTEXT_PACK_SCRIPT),
        "--asx-code",
        stock_code,
        "--as-at-date",
        observation_date.isoformat(),
        "--broker-mode",
        "transform_only",
        "--trust-server-certificate",
        "--output-dir",
        str(run_dir),
    ]
    completed = subprocess.run(
        command,
        cwd=str(SKILL_ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    announcement_compact = _load_json_file(run_dir / "announcement_compact.json")
    price_ta_compact = _load_json_file(run_dir / "price_ta_compact.json")
    broker_compact = _load_json_file(run_dir / "broker_compact.json")
    liquidity_compact = _load_json_file(run_dir / "liquidity_compact.json")
    context_pack = _load_json_file(run_dir / "context_pack.json")

    if not context_pack:
        if completed.returncode != 0:
            message = (completed.stderr or completed.stdout).strip() or "Unknown skill execution failure"
            raise RuntimeError(f"ASX-spec-analyzer context-pack run failed: {message}")
        raise RuntimeError("ASX-spec-analyzer did not produce context_pack.json")

    if completed.returncode != 0:
        logger.warning(
            "ASX-spec-analyzer context-pack exited non-zero for %s on %s; proceeding with partial bundle. stdout=%s stderr=%s",
            stock_code,
            observation_date,
            (completed.stdout or "").strip(),
            (completed.stderr or "").strip(),
        )

    if not broker_compact:
        broker_compact = _build_neutral_broker_compact(context_pack)

    return {
        "run_directory": str(run_dir),
        "context_pack": context_pack,
        "announcement_compact": announcement_compact,
        "price_ta_compact": price_ta_compact,
        "broker_compact": broker_compact,
        "liquidity_compact": liquidity_compact,
    }


def list_tipped_stocks_for_analysis(observation_date: Optional[date] = None) -> List[Dict[str, Any]]:
    """
    List ALL tipped stocks with their report ratings and processing status for a specific date.

    Args:
        observation_date: If provided, check for reports and processing status for this specific date.
                         If None, shows the most recent report/rating regardless of date.
    """
    db = get_sql_model()
    logger.info("list_tipped_stocks_for_analysis called with observation_date=%s", observation_date)

    if observation_date:
        # Query for specific observation date - shows ALL stocks, with report/status if available
        rows = db.execute_read_query(
            """
            WITH StockRatingSummary AS (
                SELECT
                    StockCode,
                    COUNT(*) AS total_ratings,
                    SUM(CASE WHEN Rating = 'Bullish' THEN 1 ELSE 0 END) AS bullish_count
                FROM [Research].[StockRating]
                GROUP BY StockCode
            )
            SELECT
                srs.StockCode AS stock_code,
                srs.total_ratings,
                srs.bullish_count,
                CONVERT(varchar(10), price_latest.lastPriceDate, 23) AS lastPriceDate,
                CAST(price_stats.avg_trade_value_20d AS decimal(20, 2)) AS avg_trade_value_20d,
                CONVERT(varchar(10), rpt.ObservationDate, 23) AS latest_analysis_date,
                rating.OverallScore AS overall_score,
                rating.OverallRating AS overall_rating,
                processing.Status AS processing_status,
                processing.ProcessingID AS processing_id
            FROM StockRatingSummary srs
            OUTER APPLY (
                SELECT MAX(ph.ObservationDate) AS lastPriceDate
                FROM [StockData].[PriceHistory] ph
                WHERE ph.ASXCode IN (srs.StockCode, REPLACE(srs.StockCode, '.AX', ''), REPLACE(srs.StockCode, '.AX', '') + '.AX')
                  AND ph.ObservationDate <= convert(date, ?)
            ) price_latest
            OUTER APPLY (
                SELECT AVG(CAST(recent_prices.[Value] AS decimal(20, 4))) AS avg_trade_value_20d
                FROM (
                    SELECT TOP 20 ph.[Value]
                    FROM [StockData].[PriceHistory] ph
                    WHERE ph.ASXCode IN (srs.StockCode, REPLACE(srs.StockCode, '.AX', ''), REPLACE(srs.StockCode, '.AX', '') + '.AX')
                      AND ph.ObservationDate <= convert(date, ?)
                      AND ph.[Value] IS NOT NULL
                    ORDER BY ph.ObservationDate DESC
                ) recent_prices
            ) price_stats
            LEFT JOIN [Research].[StockAnalysisReport] rpt
                ON rpt.StockCode = srs.StockCode
                AND rpt.ObservationDate = convert(date, ?)
            LEFT JOIN [Research].[StockAnalysisReportRating] rating
                ON rating.ReportID = rpt.ReportID
            LEFT JOIN [Research].[StockAnalysisProcessing] processing
                ON processing.StockCode = srs.StockCode
                AND processing.ObservationDate = convert(date, ?)
                AND processing.Status IN ('Pending', 'Processing')
            ORDER BY srs.bullish_count DESC, srs.total_ratings DESC, srs.StockCode ASC
            """,
            (observation_date, observation_date, observation_date, observation_date),
        ) or []
    else:
        # Query for latest report regardless of date
        rows = db.execute_read_query(
            """
            WITH StockRatingSummary AS (
                SELECT
                    StockCode,
                    COUNT(*) AS total_ratings,
                    SUM(CASE WHEN Rating = 'Bullish' THEN 1 ELSE 0 END) AS bullish_count
                FROM [Research].[StockRating]
                GROUP BY StockCode
            ),
            LatestReports AS (
                SELECT
                    StockCode,
                    MAX(ObservationDate) AS MaxObservationDate
                FROM [Research].[StockAnalysisReport]
                GROUP BY StockCode
            )
            SELECT
                srs.StockCode AS stock_code,
                srs.total_ratings,
                srs.bullish_count,
                CONVERT(varchar(10), price_latest.lastPriceDate, 23) AS lastPriceDate,
                CAST(price_stats.avg_trade_value_20d AS decimal(20, 2)) AS avg_trade_value_20d,
                CONVERT(varchar(10), lr.MaxObservationDate, 23) AS latest_analysis_date,
                rating.OverallScore AS overall_score,
                rating.OverallRating AS overall_rating,
                NULL AS processing_status,
                NULL AS processing_id
            FROM StockRatingSummary srs
            OUTER APPLY (
                SELECT MAX(ph.ObservationDate) AS lastPriceDate
                FROM [StockData].[PriceHistory] ph
                WHERE ph.ASXCode IN (srs.StockCode, REPLACE(srs.StockCode, '.AX', ''), REPLACE(srs.StockCode, '.AX', '') + '.AX')
            ) price_latest
            OUTER APPLY (
                SELECT AVG(CAST(recent_prices.[Value] AS decimal(20, 4))) AS avg_trade_value_20d
                FROM (
                    SELECT TOP 20 ph.[Value]
                    FROM [StockData].[PriceHistory] ph
                    WHERE ph.ASXCode IN (srs.StockCode, REPLACE(srs.StockCode, '.AX', ''), REPLACE(srs.StockCode, '.AX', '') + '.AX')
                      AND ph.[Value] IS NOT NULL
                    ORDER BY ph.ObservationDate DESC
                ) recent_prices
            ) price_stats
            LEFT JOIN LatestReports lr
                ON lr.StockCode = srs.StockCode
            LEFT JOIN [Research].[StockAnalysisReport] rpt
                ON rpt.StockCode = srs.StockCode
                AND rpt.ObservationDate = lr.MaxObservationDate
            LEFT JOIN [Research].[StockAnalysisReportRating] rating
                ON rating.ReportID = rpt.ReportID
            ORDER BY srs.bullish_count DESC, srs.total_ratings DESC, srs.StockCode ASC
            """,
            (),
        ) or []

    return rows


def get_active_processing(stock_code: str, observation_date: date) -> Optional[Dict[str, Any]]:
    db = get_sql_model()
    rows = db.execute_read_query(
        """
        SELECT TOP 1
            ProcessingID AS processing_id,
            StockCode AS stock_code,
            ObservationDate AS observation_date,
            Status AS status,
            StartedAt AS started_at,
            CompletedAt AS completed_at,
            ErrorMessage AS error_message,
            RequestedBy AS requested_by,
            Model AS model
        FROM [Research].[StockAnalysisProcessing]
        WHERE StockCode = convert(varchar(20), ?)
          AND ObservationDate = convert(date, ?)
          AND Status IN ('Pending', 'Processing')
        ORDER BY ProcessingID DESC
        """,
        (stock_code, observation_date),
    ) or []
    if not rows:
        return None
    row = rows[0]
    existing_report = get_report(stock_code, observation_date)
    if existing_report is not None:
        row["status"] = "Completed"
    row["observation_date"] = _coerce_date(row.get("observation_date"))
    row["started_at"] = _coerce_datetime(row.get("started_at"))
    row["completed_at"] = _coerce_datetime(row.get("completed_at"))
    return row


def create_processing_record(
    stock_code: str,
    observation_date: date,
    requested_by: Optional[str],
    model: str,
) -> int:
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO [Research].[StockAnalysisProcessing]
                (StockCode, ObservationDate, Status, RequestedBy, Model)
                OUTPUT INSERTED.ProcessingID
            VALUES (?, ?, 'Pending', ?, ?);
            """,
            (stock_code, observation_date, requested_by, model),
        )
        row = cursor.fetchone()
        conn.commit()
        if not row:
            raise RuntimeError("Failed to create processing record")
        return int(row[0])
    finally:
        conn.close()


def mark_processing_started(processing_id: int) -> None:
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            UPDATE [Research].[StockAnalysisProcessing]
            SET Status = 'Processing',
                StartedAt = ISNULL(StartedAt, GETDATE()),
                CompletedAt = NULL,
                ErrorMessage = NULL
            WHERE ProcessingID = ?
            """,
            (processing_id,),
        )
        conn.commit()
    finally:
        conn.close()


def update_processing_progress(processing_id: int, message: str) -> None:
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            UPDATE [Research].[StockAnalysisProcessing]
            SET ErrorMessage = ?
            WHERE ProcessingID = ?
            """,
            (message[:4000], processing_id),
        )
        conn.commit()
    finally:
        conn.close()


def mark_processing_completed(processing_id: int) -> None:
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            UPDATE [Research].[StockAnalysisProcessing]
            SET Status = 'Completed',
                CompletedAt = GETDATE(),
                ErrorMessage = NULL
            WHERE ProcessingID = ?
            """,
            (processing_id,),
        )
        conn.commit()
    finally:
        conn.close()


def mark_processing_error(processing_id: int, error_message: str) -> None:
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            UPDATE [Research].[StockAnalysisProcessing]
            SET Status = 'Error',
                CompletedAt = GETDATE(),
                ErrorMessage = ?
            WHERE ProcessingID = ?
            """,
            (error_message[:4000], processing_id),
        )
        conn.commit()
    finally:
        conn.close()


def get_processing_status(processing_id: int) -> Optional[Dict[str, Any]]:
    db = get_sql_model()
    rows = db.execute_read_query(
        """
        SELECT TOP 1
            p.ProcessingID AS processing_id,
            p.StockCode AS stock_code,
            p.ObservationDate AS observation_date,
            p.Status AS status,
            p.StartedAt AS started_at,
            p.CompletedAt AS completed_at,
            p.ErrorMessage AS error_message,
            p.RequestedBy AS requested_by,
            p.Model AS model,
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM [Research].[StockAnalysisReport] r
                    WHERE r.StockCode = p.StockCode
                      AND r.ObservationDate = p.ObservationDate
                ) THEN CAST(1 AS bit)
                ELSE CAST(0 AS bit)
            END AS report_available
        FROM [Research].[StockAnalysisProcessing] p
        WHERE p.ProcessingID = ?
        """,
        (processing_id,),
    ) or []
    if not rows:
        return None
    row = rows[0]
    row["observation_date"] = _coerce_date(row.get("observation_date"))
    row["started_at"] = _coerce_datetime(row.get("started_at"))
    row["completed_at"] = _coerce_datetime(row.get("completed_at"))
    row["report_available"] = bool(row.get("report_available"))
    if row["report_available"] and row.get("status") in {"Pending", "Processing"}:
        row["status"] = "Completed"
        row["error_message"] = None
    return row


def upsert_report(
    stock_code: str,
    observation_date: date,
    report_markdown: str,
    report_json: Dict[str, Any],
    model: str,
    processed_by: Optional[str],
    tokens_used: int,
    processing_time_seconds: float,
) -> None:
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            MERGE [Research].[StockAnalysisReport] AS target
            USING (
                SELECT
                    CAST(? AS varchar(20)) AS StockCode,
                    CAST(? AS date) AS ObservationDate
            ) AS source
            ON target.StockCode = source.StockCode
               AND target.ObservationDate = source.ObservationDate
            WHEN MATCHED THEN
                UPDATE SET
                    ReportMarkdown = ?,
                    ReportJSON = ?,
                    Model = ?,
                    Status = 'Completed',
                    ProcessedAt = GETDATE(),
                    ProcessedBy = ?,
                    TokensUsed = ?,
                    ProcessingTimeSeconds = ?
            WHEN NOT MATCHED THEN
                INSERT (
                    StockCode,
                    ObservationDate,
                    ReportMarkdown,
                    ReportJSON,
                    Model,
                    Status,
                    ProcessedAt,
                    ProcessedBy,
                    TokensUsed,
                    ProcessingTimeSeconds
                )
                VALUES (?, ?, ?, ?, ?, 'Completed', GETDATE(), ?, ?, ?)
            OUTPUT INSERTED.ReportID;
            """,
            (
                stock_code,
                observation_date,
                report_markdown,
                json.dumps(report_json, default=_json_default),
                model,
                processed_by,
                tokens_used,
                processing_time_seconds,
                stock_code,
                observation_date,
                report_markdown,
                json.dumps(report_json, default=_json_default),
                model,
                processed_by,
                tokens_used,
                processing_time_seconds,
            ),
        )
        row = cursor.fetchone()
        report_id = int(row[0]) if row else None
        conn.commit()

        # Upsert ratings if available
        if report_id:
            scores = report_json.get("scores", {})
            if scores:
                try:
                    upsert_report_ratings(
                        report_id=report_id,
                        stock_code=stock_code,
                        observation_date=observation_date,
                        scores=scores,
                    )
                except Exception:
                    logger.exception(
                        "Failed to persist structured report ratings for %s on %s (report_id=%s)",
                        stock_code,
                        observation_date,
                        report_id,
                    )
    finally:
        conn.close()


def upsert_report_ratings(
    report_id: int,
    stock_code: str,
    observation_date: date,
    scores: Dict[str, Any],
) -> None:
    """Store structured ratings extracted from the report."""
    normalized_scores = {
        "overall_score": scores.get("overall_score"),
        "overall_rating": _normalize_rating_label(scores.get("overall_rating")),
        "fundamental_score": scores.get("fundamental_score"),
        "fundamental_rating": _normalize_rating_label(scores.get("fundamental_rating")),
        "newsflow_score": scores.get("newsflow_score"),
        "newsflow_rating": _normalize_rating_label(scores.get("newsflow_rating")),
        "technical_score": scores.get("technical_score"),
        "technical_rating": _normalize_rating_label(scores.get("technical_rating")),
        "broker_score": scores.get("broker_score"),
        "broker_rating": _normalize_rating_label(scores.get("broker_rating")),
    }

    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            MERGE [Research].[StockAnalysisReportRating] AS target
            USING (
                SELECT CAST(? AS int) AS ReportID
            ) AS source
            ON target.ReportID = source.ReportID
            WHEN MATCHED THEN
                UPDATE SET
                    StockCode = ?,
                    ObservationDate = ?,
                    OverallScore = ?,
                    OverallRating = ?,
                    FundamentalScore = ?,
                    FundamentalRating = ?,
                    NewsflowScore = ?,
                    NewsflowRating = ?,
                    TechnicalScore = ?,
                    TechnicalRating = ?,
                    BrokerScore = ?,
                    BrokerRating = ?
            WHEN NOT MATCHED THEN
                INSERT (
                    ReportID,
                    StockCode,
                    ObservationDate,
                    OverallScore,
                    OverallRating,
                    FundamentalScore,
                    FundamentalRating,
                    NewsflowScore,
                    NewsflowRating,
                    TechnicalScore,
                    TechnicalRating,
                    BrokerScore,
                    BrokerRating
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            (
                report_id,
                stock_code,
                observation_date,
                normalized_scores.get("overall_score"),
                normalized_scores.get("overall_rating"),
                normalized_scores.get("fundamental_score"),
                normalized_scores.get("fundamental_rating"),
                normalized_scores.get("newsflow_score"),
                normalized_scores.get("newsflow_rating"),
                normalized_scores.get("technical_score"),
                normalized_scores.get("technical_rating"),
                normalized_scores.get("broker_score"),
                normalized_scores.get("broker_rating"),
                report_id,
                stock_code,
                observation_date,
                normalized_scores.get("overall_score"),
                normalized_scores.get("overall_rating"),
                normalized_scores.get("fundamental_score"),
                normalized_scores.get("fundamental_rating"),
                normalized_scores.get("newsflow_score"),
                normalized_scores.get("newsflow_rating"),
                normalized_scores.get("technical_score"),
                normalized_scores.get("technical_rating"),
                normalized_scores.get("broker_score"),
                normalized_scores.get("broker_rating"),
            ),
        )
        conn.commit()
    finally:
        conn.close()


def get_report(stock_code: str, observation_date: date) -> Optional[Dict[str, Any]]:
    normalized_code = normalize_stock_code(stock_code)
    db = get_sql_model()
    rows = db.execute_read_query(
        """
        SELECT TOP 1
            ReportID AS report_id,
            StockCode AS stock_code,
            ObservationDate AS observation_date,
            ReportMarkdown AS report_markdown,
            ReportJSON AS report_json,
            Model AS model,
            Status AS status,
            ProcessedAt AS processed_at,
            ProcessedBy AS processed_by,
            TokensUsed AS tokens_used,
            ProcessingTimeSeconds AS processing_time_seconds
        FROM [Research].[StockAnalysisReport]
        WHERE StockCode = convert(varchar(20), ?)
          AND ObservationDate = convert(date, ?)
        ORDER BY ReportID DESC
        """,
        (normalized_code, observation_date),
    ) or []
    if not rows:
        return None
    row = rows[0]
    row["observation_date"] = _coerce_date(row.get("observation_date"))
    row["processed_at"] = _coerce_datetime(row.get("processed_at"))
    if isinstance(row.get("report_json"), str) and row["report_json"]:
        try:
            row["report_json"] = json.loads(row["report_json"])
        except json.JSONDecodeError:
            logger.warning("Could not decode report_json for report_id=%s", row.get("report_id"))
    return row


async def run_stock_analysis(
    processing_id: int,
    stock_code: str,
    observation_date: date,
    model: str,
    requested_by: Optional[str],
) -> None:
    normalized_code = normalize_stock_code(stock_code)
    try:
        mark_processing_started(processing_id)
        update_processing_progress(processing_id, "Step 1/5: Building ASX-spec-analyzer context bundle...")

        skill_bundle = load_skill_context_bundle(normalized_code, observation_date)
        update_processing_progress(processing_id, "Step 2/6: Loading compact artifacts and broker status...")
        skill_context_pack = skill_bundle["context_pack"]
        announcement_compact = skill_bundle["announcement_compact"]
        price_ta_compact = skill_bundle["price_ta_compact"]
        broker_compact = skill_bundle["broker_compact"]
        liquidity_compact = skill_bundle["liquidity_compact"]

        if not announcement_compact or not price_ta_compact or not liquidity_compact:
            raise RuntimeError(
                "ASX-spec-analyzer bundle is incomplete: announcement, price/TA, or liquidity compact is missing."
            )

        context_pack = _build_context_pack_from_skill_bundle(
            stock_code=normalized_code,
            stock_code_base=normalized_code.replace(".AX", ""),
            observation_date=observation_date,
            skill_context_pack=skill_context_pack,
            announcement_compact=announcement_compact,
            price_ta_compact=price_ta_compact,
            broker_compact=broker_compact,
        )
        update_processing_progress(processing_id, "Step 3/6: Verifying funding evidence against source announcements...")
        verified_funding = verify_funding(skill_bundle["run_directory"], announcement_compact)
        context_pack["verified_funding_available"] = bool(verified_funding.get("verified"))
        context_pack["verified_funding_summary"] = {
            "preferred_cash_balance_m": verified_funding.get("preferred_cash_balance_m"),
            "preferred_burn_m": verified_funding.get("preferred_burn_m"),
            "preferred_runway_months": verified_funding.get("preferred_runway_months"),
            "confidence": verified_funding.get("confidence"),
        }
        update_processing_progress(processing_id, "Step 4/6: Preparing report-writer prompt and verification context...")

        update_processing_progress(processing_id, "Step 5/6: Running final report-writer LLM roundtrip...")
        markdown_report, report_json, tokens_used, processing_time = await generate_report(
            run_directory=skill_bundle["run_directory"],
            context_pack=context_pack,
            announcement_compact=announcement_compact,
            price_ta_compact=price_ta_compact,
            broker_compact=broker_compact,
            liquidity_compact=liquidity_compact,
            verified_funding=verified_funding,
            model=model,
        )
        update_processing_progress(processing_id, "Step 6/6: Saving final report...")

        upsert_report(
            stock_code=normalized_code,
            observation_date=observation_date,
            report_markdown=markdown_report,
            report_json=report_json,
            model=model,
            processed_by=requested_by,
            tokens_used=tokens_used,
            processing_time_seconds=processing_time,
        )
        update_processing_progress(processing_id, "Completed.")
        mark_processing_completed(processing_id)
    except Exception as exc:
        logger.exception(
            "Stock analysis processing failed for %s on %s (processing_id=%s)",
            normalized_code,
            observation_date,
            processing_id,
        )
        mark_processing_error(processing_id, str(exc))
        raise
