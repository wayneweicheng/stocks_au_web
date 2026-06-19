from __future__ import annotations

import asyncio
import logging
import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.db import get_db_connection
from app.routers.auth import verify_credentials
from app.routers.stock_analysis import submit_stock_analysis_task
from app.services.stock_analysis.analysis_service import (
    DEFAULT_STOCK_ANALYSIS_MODEL,
    create_processing_record,
    get_active_processing,
    get_report,
    normalize_stock_code as normalize_analysis_stock_code,
)


router = APIRouter(prefix="/api/asx-data-refresh", tags=["asx-data-refresh"])
logger = logging.getLogger("app.asx_data_refresh")

STOCKS_COLLECTING_ROOT = Path(r"C:\Repo\stocks_collecting")
MAX_OUTPUT_CHARS = 12000

StageStatus = Literal["pending", "running", "completed", "failed"]
JobStatus = Literal["queued", "running", "completed", "failed"]


class RefreshRequest(BaseModel):
    stock_code: str = Field(..., min_length=1)


class ReportRequest(BaseModel):
    model: str = DEFAULT_STOCK_ANALYSIS_MODEL


class StageResponse(BaseModel):
    key: str
    label: str
    status: StageStatus
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    detail: Optional[str] = None
    output: Optional[str] = None


class RefreshResponse(BaseModel):
    job_id: int
    stock_code: str
    observation_date: str
    start_date: str
    end_date: str
    requested_by: Optional[str] = None
    status: JobStatus
    created_at: Optional[str] = None
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    error_message: Optional[str] = None
    report_available: bool = False
    report_id: Optional[int] = None
    report_model: Optional[str] = None
    report_processed_at: Optional[str] = None
    report_processing_id: Optional[int] = None
    report_processing_status: Optional[str] = None
    stages: List[StageResponse]


class RefreshListResponse(BaseModel):
    items: List[RefreshResponse]
    total: int
    observation_date: str


_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="asx-data-refresh")


def _normalize_stock_code(value: str) -> str:
    code = value.strip().upper()
    if code.endswith(".AX"):
        code = code[:-3]
    if not re.fullmatch(r"[A-Z0-9]{2,6}", code):
        raise HTTPException(status_code=400, detail="Enter a valid ASX code, for example BHP or BHP.AX.")
    return code


def _subtract_working_days(end: date, days: int) -> date:
    current = end
    remaining = days
    while remaining > 0:
        current -= timedelta(days=1)
        if current.weekday() < 5:
            remaining -= 1
    return current


def _coerce_dt(value: Any) -> Optional[str]:
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


def _trim_output(stdout: str, stderr: str) -> str:
    combined = "\n".join(part for part in [stdout.strip(), stderr.strip()] if part)
    if len(combined) <= MAX_OUTPUT_CHARS:
        return combined
    return combined[-MAX_OUTPUT_CHARS:]


def _rows_to_dicts(cursor) -> List[Dict[str, Any]]:
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def _ensure_tables() -> None:
    with get_db_connection("StockDB") as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            IF SCHEMA_ID('Research') IS NULL
                EXEC('CREATE SCHEMA [Research]');

            IF OBJECT_ID('[Research].[ASXDataRefreshJob]', 'U') IS NULL
            BEGIN
                CREATE TABLE [Research].[ASXDataRefreshJob] (
                    [JobID] int IDENTITY(1,1) NOT NULL,
                    [StockCode] varchar(20) NOT NULL,
                    [ObservationDate] date NOT NULL,
                    [StartDate] date NOT NULL,
                    [EndDate] date NOT NULL,
                    [Status] varchar(20) NOT NULL DEFAULT 'queued',
                    [CreatedAt] datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
                    [StartedAt] datetime2(0) NULL,
                    [CompletedAt] datetime2(0) NULL,
                    [ErrorMessage] nvarchar(max) NULL,
                    [RequestedBy] varchar(50) NULL,
                    CONSTRAINT [PK_ASXDataRefreshJob] PRIMARY KEY CLUSTERED ([JobID] ASC)
                );
                CREATE INDEX [IX_ASXDataRefreshJob_ObservationDate] ON [Research].[ASXDataRefreshJob] ([ObservationDate]);
                CREATE INDEX [IX_ASXDataRefreshJob_StockDate] ON [Research].[ASXDataRefreshJob] ([StockCode], [ObservationDate]);
            END;

            IF OBJECT_ID('[Research].[ASXDataRefreshStage]', 'U') IS NULL
            BEGIN
                CREATE TABLE [Research].[ASXDataRefreshStage] (
                    [StageID] int IDENTITY(1,1) NOT NULL,
                    [JobID] int NOT NULL,
                    [StageKey] varchar(50) NOT NULL,
                    [StageLabel] varchar(100) NOT NULL,
                    [Status] varchar(20) NOT NULL DEFAULT 'pending',
                    [StartedAt] datetime2(0) NULL,
                    [CompletedAt] datetime2(0) NULL,
                    [Detail] nvarchar(max) NULL,
                    [Output] nvarchar(max) NULL,
                    [SortOrder] int NOT NULL,
                    CONSTRAINT [PK_ASXDataRefreshStage] PRIMARY KEY CLUSTERED ([StageID] ASC),
                    CONSTRAINT [FK_ASXDataRefreshStage_Job] FOREIGN KEY ([JobID])
                        REFERENCES [Research].[ASXDataRefreshJob] ([JobID]) ON DELETE CASCADE
                );
                CREATE UNIQUE INDEX [IX_ASXDataRefreshStage_Job_StageKey] ON [Research].[ASXDataRefreshStage] ([JobID], [StageKey]);
            END;
            """
        )
        conn.commit()


def _create_job_record(stock_code: str, start: date, end: date, requested_by: str) -> int:
    _ensure_tables()
    with get_db_connection("StockDB") as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO [Research].[ASXDataRefreshJob]
                (StockCode, ObservationDate, StartDate, EndDate, Status, RequestedBy)
                OUTPUT INSERTED.JobID
            VALUES (?, ?, ?, ?, 'queued', ?);
            """,
            (stock_code, end, start, end, requested_by),
        )
        row = cursor.fetchone()
        if not row:
            raise RuntimeError("Failed to create ASX data refresh job.")
        job_id = int(row[0])
        stages = [
            ("price_history", "Price history batch", 1),
            ("broker_trades", "Broker trade report collection", 2),
            ("broker_transform", "Broker enhancement transform", 3),
        ]
        cursor.executemany(
            """
            INSERT INTO [Research].[ASXDataRefreshStage]
                (JobID, StageKey, StageLabel, Status, SortOrder)
            VALUES (?, ?, ?, 'pending', ?);
            """,
            [(job_id, key, label, sort_order) for key, label, sort_order in stages],
        )
        conn.commit()
        return job_id


def _update_job(job_id: int, **updates: Any) -> None:
    if not updates:
        return
    assignments = ", ".join(f"{key} = ?" for key in updates)
    values = list(updates.values()) + [job_id]
    with get_db_connection("StockDB") as conn:
        cursor = conn.cursor()
        cursor.execute(f"UPDATE [Research].[ASXDataRefreshJob] SET {assignments} WHERE JobID = ?", values)
        conn.commit()


def _update_stage(job_id: int, stage_key: str, **updates: Any) -> None:
    if not updates:
        return
    assignments = ", ".join(f"{key} = ?" for key in updates)
    values = list(updates.values()) + [job_id, stage_key]
    with get_db_connection("StockDB") as conn:
        cursor = conn.cursor()
        cursor.execute(
            f"UPDATE [Research].[ASXDataRefreshStage] SET {assignments} WHERE JobID = ? AND StageKey = ?",
            values,
        )
        conn.commit()


def _get_job_row(job_id: int) -> Optional[Dict[str, Any]]:
    _ensure_tables()
    with get_db_connection("StockDB") as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT
                j.JobID AS job_id,
                j.StockCode AS stock_code,
                j.ObservationDate AS observation_date,
                j.StartDate AS start_date,
                j.EndDate AS end_date,
                j.RequestedBy AS requested_by,
                j.Status AS status,
                j.CreatedAt AS created_at,
                j.StartedAt AS started_at,
                j.CompletedAt AS completed_at,
                j.ErrorMessage AS error_message,
                rpt.ReportID AS report_id,
                rpt.Model AS report_model,
                rpt.ProcessedAt AS report_processed_at,
                processing.ProcessingID AS report_processing_id,
                processing.Status AS report_processing_status
            FROM [Research].[ASXDataRefreshJob] j
            OUTER APPLY (
                SELECT TOP 1 r.ReportID, r.Model, r.ProcessedAt
                FROM [Research].[StockAnalysisReport] r
                WHERE r.StockCode IN (j.StockCode, j.StockCode + '.AX')
                  AND r.ObservationDate = j.ObservationDate
                ORDER BY r.ProcessedAt DESC
            ) rpt
            OUTER APPLY (
                SELECT TOP 1 p.ProcessingID, p.Status
                FROM [Research].[StockAnalysisProcessing] p
                WHERE p.StockCode IN (j.StockCode, j.StockCode + '.AX')
                  AND p.ObservationDate = j.ObservationDate
                  AND p.Status IN ('Pending', 'Processing')
                ORDER BY p.ProcessingID DESC
            ) processing
            WHERE j.JobID = ?;
            """,
            (job_id,),
        )
        rows = _rows_to_dicts(cursor)
        return rows[0] if rows else None


def _get_stage_rows(job_id: int) -> List[Dict[str, Any]]:
    with get_db_connection("StockDB") as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT
                StageKey AS [key],
                StageLabel AS label,
                Status AS status,
                StartedAt AS started_at,
                CompletedAt AS completed_at,
                Detail AS detail,
                Output AS output
            FROM [Research].[ASXDataRefreshStage]
            WHERE JobID = ?
            ORDER BY SortOrder ASC;
            """,
            (job_id,),
        )
        return _rows_to_dicts(cursor)


def _serialize_job(row: Dict[str, Any], stages: List[Dict[str, Any]]) -> RefreshResponse:
    return RefreshResponse(
        job_id=int(row["job_id"]),
        stock_code=str(row["stock_code"]),
        observation_date=_coerce_date(row["observation_date"]) or "",
        start_date=_coerce_date(row["start_date"]) or "",
        end_date=_coerce_date(row["end_date"]) or "",
        requested_by=row.get("requested_by"),
        status=str(row["status"]),
        created_at=_coerce_dt(row.get("created_at")),
        started_at=_coerce_dt(row.get("started_at")),
        completed_at=_coerce_dt(row.get("completed_at")),
        error_message=row.get("error_message"),
        report_available=row.get("report_id") is not None,
        report_id=row.get("report_id"),
        report_model=row.get("report_model"),
        report_processed_at=_coerce_dt(row.get("report_processed_at")),
        report_processing_id=row.get("report_processing_id"),
        report_processing_status=row.get("report_processing_status"),
        stages=[
            StageResponse(
                key=str(stage["key"]),
                label=str(stage["label"]),
                status=str(stage["status"]),
                started_at=_coerce_dt(stage.get("started_at")),
                completed_at=_coerce_dt(stage.get("completed_at")),
                detail=stage.get("detail"),
                output=stage.get("output"),
            )
            for stage in stages
        ],
    )


def _get_job(job_id: int) -> RefreshResponse:
    row = _get_job_row(job_id)
    if not row:
        raise HTTPException(status_code=404, detail="Refresh job not found")
    return _serialize_job(row, _get_stage_rows(job_id))


def _run_command(job_id: int, stage_key: str, command: List[str], cwd: Path) -> None:
    command_display = " ".join(command)
    _update_stage(
        job_id,
        stage_key,
        Status="running",
        StartedAt=datetime.utcnow(),
        CompletedAt=None,
        Detail=f"{command_display} (cwd: {cwd})",
        Output=None,
    )
    logger.info("Running ASX refresh stage %s for job %s: %s", stage_key, job_id, command_display)
    completed = subprocess.run(
        command,
        cwd=str(cwd),
        env={
            **os.environ,
            "PYTHONIOENCODING": "utf-8",
            "PYTHONUTF8": "1",
        },
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )
    output = _trim_output(completed.stdout or "", completed.stderr or "")
    if completed.returncode != 0:
        _update_stage(job_id, stage_key, Status="failed", CompletedAt=datetime.utcnow(), Output=output)
        raise RuntimeError(f"{stage_key} failed with exit code {completed.returncode}")

    _update_stage(
        job_id,
        stage_key,
        Status="completed",
        CompletedAt=datetime.utcnow(),
        Output=output or "Completed successfully.",
    )


def _build_transform_sql(stock_code: str, start_date: str, end_date: str) -> str:
    escaped_stock_code = stock_code.replace("'", "''")
    return f"""
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @pStartDate date = '{start_date}';
DECLARE @pEndDate date = '{end_date}';
DECLARE @pPhase1LookbackTradingDays int = 504;
DECLARE @pPhase23TriggerMode varchar(20) = 'HYBRID';
DECLARE @pPhase23LookbackCalendarDays int = 30;
DECLARE @pPhase23PersistArchive bit = 0;
DECLARE @pvchStockCodeList varchar(max) = '{escaped_stock_code}';

IF @pStartDate > @pEndDate
BEGIN
    THROW 50001, '@pStartDate must be <= @pEndDate', 1;
END;

DECLARE @d date = @pStartDate;
DECLARE @runlog TABLE
(
    AsOfDate date NOT NULL,
    Status varchar(20) NOT NULL,
    ErrorMessage nvarchar(4000) NULL,
    CompletedAt datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);

WHILE @d <= @pEndDate
BEGIN
    BEGIN TRY
        EXEC Transform.usp_RefreshBrokerEnhancePhase1
            @pAsOfDate = @d,
            @pLookbackTradingDays = @pPhase1LookbackTradingDays,
            @pvchStockCodeList = @pvchStockCodeList;

        EXEC Transform.usp_RefreshBrokerEnhancePhase23
            @pAsOfDate = @d,
            @pTriggerMode = @pPhase23TriggerMode,
            @pLookbackCalendarDays = @pPhase23LookbackCalendarDays,
            @pPersistArchive = @pPhase23PersistArchive,
            @pvchStockCodeList = @pvchStockCodeList;

        INSERT INTO @runlog (AsOfDate, Status) VALUES (@d, 'OK');
    END TRY
    BEGIN CATCH
        INSERT INTO @runlog (AsOfDate, Status, ErrorMessage) VALUES (@d, 'FAILED', ERROR_MESSAGE());
    END CATCH;
    SET @d = DATEADD(DAY, 1, @d);
END;

SELECT
    CONVERT(varchar(10), AsOfDate, 23) AS AsOfDate,
    Status,
    ErrorMessage,
    CONVERT(varchar(19), CompletedAt, 126) AS CompletedAt
FROM @runlog
ORDER BY AsOfDate;

SELECT
    COUNT(*) AS TotalDays,
    SUM(CASE WHEN Status = 'OK' THEN 1 ELSE 0 END) AS DaysOK,
    SUM(CASE WHEN Status = 'FAILED' THEN 1 ELSE 0 END) AS DaysFailed,
    CONVERT(varchar(10), @pStartDate, 23) AS StartDate,
    CONVERT(varchar(10), @pEndDate, 23) AS EndDate
FROM @runlog;
"""


def _get_latest_trading_date(stock_code: str, observation_date: str) -> str:
    with get_db_connection("StockDB") as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT CONVERT(varchar(10), MAX(ph.ObservationDate), 23) AS trading_date
            FROM [StockData].[PriceHistory] ph
            WHERE ph.ASXCode IN (convert(varchar(10), ?), convert(varchar(10), ?))
              AND ph.ObservationDate <= convert(date, ?);
            """,
            (stock_code, f"{stock_code}.AX", observation_date),
        )
        row = cursor.fetchone()
        trading_date = row[0] if row else None
        if not trading_date:
            raise RuntimeError(
                f"No trading date found in StockData.PriceHistory for {stock_code} on or before {observation_date}."
            )
        return str(trading_date)


def _run_transform_sql(job_id: int, stock_code: str, start_date: str, end_date: str) -> None:
    stage_key = "broker_transform"
    trading_date = _get_latest_trading_date(stock_code, end_date)
    _update_stage(
        job_id,
        stage_key,
        Status="running",
        StartedAt=datetime.utcnow(),
        CompletedAt=None,
        Detail=(
            f"Transform broker enhancement in StockDB for {stock_code}. "
            f"Observation date {end_date}; using latest trading date {trading_date}."
        ),
        Output=None,
    )
    output_lines: List[str] = []
    sql = _build_transform_sql(stock_code, trading_date, trading_date)
    try:
        with get_db_connection("StockDB") as conn:
            cursor = conn.cursor()
            cursor.execute(sql)
            result_index = 1
            while True:
                if cursor.description:
                    columns = [column[0] for column in cursor.description]
                    rows = cursor.fetchall()
                    output_lines.append(f"Result set {result_index}: {len(rows)} row(s)")
                    output_lines.append(", ".join(columns))
                    for row in rows:
                        output_lines.append(", ".join("" if value is None else str(value) for value in row))
                    result_index += 1
                if not cursor.nextset():
                    break
            conn.commit()
    except Exception as exc:
        output = "\n".join(output_lines)
        _update_stage(job_id, stage_key, Status="failed", CompletedAt=datetime.utcnow(), Output=output)
        raise RuntimeError(f"broker transform failed: {exc}") from exc

    _update_stage(
        job_id,
        stage_key,
        Status="completed",
        CompletedAt=datetime.utcnow(),
        Output="\n".join(output_lines) or "Completed successfully.",
    )


def _run_refresh_job(job_id: int) -> None:
    row = _get_job_row(job_id)
    if not row:
        logger.error("ASX data refresh job %s disappeared before execution", job_id)
        return

    stock_code = str(row["stock_code"])
    start_date = _coerce_date(row["start_date"]) or ""
    end_date = _coerce_date(row["end_date"]) or ""

    _update_job(job_id, Status="running", StartedAt=datetime.utcnow(), CompletedAt=None, ErrorMessage=None)
    try:
        _run_command(
            job_id,
            "price_history",
            [
                "poetry",
                "run",
                "python",
                "src/price_engine/run_daily_batch.py",
                "--database",
                "StockDB",
                "--symbols",
                stock_code,
                "--start-date",
                start_date,
                "--end-date",
                end_date,
            ],
            STOCKS_COLLECTING_ROOT,
        )
        _run_command(
            job_id,
            "broker_trades",
            [
                "poetry",
                "run",
                "python",
                "src/broker_trade_transaction/collect_trade_report_enhanced.py",
                "--mode",
                "working-days",
                "--working-days",
                "10",
                "--stock-codes",
                stock_code,
            ],
            STOCKS_COLLECTING_ROOT,
        )
        _run_transform_sql(job_id, stock_code, start_date, end_date)
        _update_job(job_id, Status="completed", CompletedAt=datetime.utcnow())
    except Exception as exc:
        logger.exception("ASX data refresh job failed: %s", job_id)
        _update_job(job_id, Status="failed", CompletedAt=datetime.utcnow(), ErrorMessage=str(exc))


def _run_stock_analysis_task(
    processing_id: int,
    stock_code: str,
    observation_date: date,
    model: str,
    requested_by: Optional[str],
) -> None:
    from app.services.stock_analysis.analysis_service import run_stock_analysis

    asyncio.run(
        run_stock_analysis(
            processing_id=processing_id,
            stock_code=stock_code,
            observation_date=observation_date,
            model=model,
            requested_by=requested_by,
        )
    )


@router.post("/jobs", response_model=RefreshResponse)
def create_refresh_job(
    payload: RefreshRequest,
    username: str = Depends(verify_credentials),
) -> RefreshResponse:
    stock_code = _normalize_stock_code(payload.stock_code)
    end = date.today()
    start = _subtract_working_days(end, 5)
    try:
        job_id = _create_job_record(stock_code, start, end, username)
        _executor.submit(_run_refresh_job, job_id)
        return _get_job(job_id)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Failed to create ASX data refresh job")
        raise HTTPException(status_code=500, detail=f"Failed to create ASX data refresh job: {exc}") from exc


@router.get("/jobs", response_model=RefreshListResponse)
def list_refresh_jobs(
    observation_date: Optional[date] = Query(default=None),
    username: str = Depends(verify_credentials),
) -> RefreshListResponse:
    del username
    _ensure_tables()
    target_date = observation_date or date.today()
    with get_db_connection("StockDB") as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT JobID
            FROM [Research].[ASXDataRefreshJob]
            WHERE ObservationDate = convert(date, ?)
            ORDER BY CreatedAt DESC, JobID DESC;
            """,
            (target_date,),
        )
        job_ids = [int(row[0]) for row in cursor.fetchall()]
    items = [_get_job(job_id) for job_id in job_ids]
    return RefreshListResponse(items=items, total=len(items), observation_date=target_date.isoformat())


@router.get("/jobs/{job_id}", response_model=RefreshResponse)
def get_refresh_job(
    job_id: int,
    username: str = Depends(verify_credentials),
) -> RefreshResponse:
    del username
    return _get_job(job_id)


@router.post("/jobs/{job_id}/report", response_model=RefreshResponse)
def generate_refresh_report(
    job_id: int,
    payload: ReportRequest,
    username: str = Depends(verify_credentials),
) -> RefreshResponse:
    job = _get_job(job_id)
    if job.status != "completed":
        raise HTTPException(status_code=400, detail="Data refresh must complete before generating a report.")

    report_stock_code = normalize_analysis_stock_code(job.stock_code)
    observation_date = date.fromisoformat(job.observation_date)
    existing_report = get_report(report_stock_code, observation_date)
    if existing_report is not None:
        return _get_job(job_id)

    active = get_active_processing(report_stock_code, observation_date)
    if active:
        submit_stock_analysis_task(
            processing_id=int(active["processing_id"]),
            stock_code=str(active["stock_code"]),
            observation_date=observation_date,
            model=str(active.get("model") or payload.model),
            requested_by=str(active.get("requested_by") or username),
        )
        return _get_job(job_id)

    processing_id = create_processing_record(
        stock_code=report_stock_code,
        observation_date=observation_date,
        requested_by=username,
        model=payload.model,
    )
    submit_stock_analysis_task(
        processing_id=processing_id,
        stock_code=report_stock_code,
        observation_date=observation_date,
        model=payload.model,
        requested_by=username,
    )
    return _get_job(job_id)
