"""
Background Scheduler for Automated Tasks

Uses APScheduler to run background jobs within the FastAPI application.
Currently handles scheduled background tasks.
"""

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.events import EVENT_JOB_ERROR, EVENT_JOB_EXECUTED
from datetime import date, datetime
import logging
import os
import time

logger = logging.getLogger("app.scheduler")

# Global scheduler instance
_scheduler: BackgroundScheduler = None
_is_running: bool = False
_job_state: dict = {}


def _iso(value):
    if value is None:
        return None
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _update_job_state(job_id: str, **values) -> None:
    state = _job_state.setdefault(job_id, {})
    state.update(values)


def get_scheduler() -> BackgroundScheduler:
    """Get the global scheduler instance."""
    global _scheduler
    if _scheduler is None:
        _scheduler = BackgroundScheduler(
            job_defaults={
                'coalesce': True,  # Combine missed runs into one
                'max_instances': 1,  # Only one instance at a time
                'misfire_grace_time': 300  # 5 minutes grace for misfires
            }
        )
    return _scheduler


def job_listener(event):
    """Listener for job execution events."""
    if event.exception:
        logger.error(f"Job {event.job_id} failed with exception: {event.exception}")
    else:
        logger.debug(f"Job {event.job_id} executed successfully")


def gex_auto_insight_job():
    """
    Background job to process pending GEX insights.

    This job runs every 5 minutes and:
    1. Identifies the latest available SPXW observation date (<= today)
    2. Checks which configured stocks have GEX data for that date
    3. Generates LLM predictions for stocks that haven't been processed for that date
    3. Saves signal strength to the database
    """
    from app.services.gex_auto_insight_service import GEXAutoInsightService
    from app.services.gex_data_service import GEXDataService

    job_start = datetime.now()
    _update_job_state(
        "gex_auto_insight",
        running=True,
        last_started_at=job_start,
        last_error=None,
    )
    # Determine the baseline processing date as the most recent SPXW date <= today
    try:
        gex_service = GEXDataService()
        latest_spxw_date = gex_service.get_latest_observation_date("SPXW", date.today())
    except Exception as e:
        latest_spxw_date = None
        _update_job_state("gex_auto_insight", last_error=str(e))
        logger.error(f"[GEX Auto Insight] Failed to resolve latest SPXW date: {e}")

    if latest_spxw_date is None:
        logger.info("[GEX Auto Insight] No SPXW data available up to today; skipping run")
        _update_job_state(
            "gex_auto_insight",
            running=False,
            last_finished_at=datetime.now(),
            last_target_date=None,
            last_pending_count=0,
            last_processed_count=0,
            last_failed_count=0,
        )
        return

    target_date = latest_spxw_date
    _update_job_state("gex_auto_insight", last_target_date=target_date)

    logger.info(f"[GEX Auto Insight] Starting scheduled job for {target_date}")

    try:
        service = GEXAutoInsightService()

        # Get current status
        status = service.get_processing_status(target_date)
        pending_count = status.get("pending_count", 0)
        _update_job_state("gex_auto_insight", last_pending_count=pending_count)

        if pending_count == 0:
            logger.info(f"[GEX Auto Insight] No pending stocks to process for {target_date}")
            _update_job_state(
                "gex_auto_insight",
                running=False,
                last_finished_at=datetime.now(),
                last_processed_count=0,
                last_failed_count=0,
            )
            return

        logger.info(f"[GEX Auto Insight] Found {pending_count} pending stocks to process")

        # Process all pending stocks
        result = service.process_all_pending(target_date, dry_run=False)

        processed = len(result.get("processed", []))
        failed = len(result.get("failed", []))
        _update_job_state(
            "gex_auto_insight",
            last_processed_count=processed,
            last_failed_count=failed,
        )

        duration = (datetime.now() - job_start).total_seconds()
        logger.info(
            f"[GEX Auto Insight] Job completed in {duration:.1f}s: "
            f"{processed} processed, {failed} failed"
        )

        # Log details for processed stocks
        for p in result.get("processed", []):
            logger.info(f"  [OK] {p['stock_code']}: {p.get('signal_strength', 'N/A')}")

        # Log details for failed stocks
        for f in result.get("failed", []):
            logger.warning(f"  [FAIL] {f['stock_code']}: {f.get('error', 'Unknown error')}")

    except Exception as e:
        _update_job_state("gex_auto_insight", last_error=str(e))
        logger.error(f"[GEX Auto Insight] Job failed with error: {e}", exc_info=True)
    finally:
        _update_job_state(
            "gex_auto_insight",
            running=False,
            last_finished_at=datetime.now(),
        )


def discord_market_intelligence_job():
    """Generate the cached rolling 24-hour Discord summary at 4 PM Sydney time."""
    from app.services.discord_market_intelligence_service import (
        DEFAULT_DISCORD_SUMMARY_MODEL,
        DiscordFollowerMarketIntelligenceService,
    )

    logger.info("[Discord Summary] Starting scheduled follower-summary generation")
    try:
        result = DiscordFollowerMarketIntelligenceService().get_latest_or_generate(
            force_regenerate=True,
            model=DEFAULT_DISCORD_SUMMARY_MODEL,
        )
        logger.info(
            "[Discord Summary] Generated follower summary %s using %s messages",
            result["summary_date"],
            result["message_count"],
        )
    except ValueError as exc:
        logger.warning("[Discord Summary] Skipped scheduled generation: %s", exc)
    except Exception as exc:
        logger.error("[Discord Summary] Scheduled generation failed: %s", exc, exc_info=True)


def _persist_volatility_runner_job(job_response: dict) -> dict:
    from app.services.skill_runner_client import call_skill_runner, get_job_json
    from app.services.volatility_options_alerts import VolatilityOptionsAlertService, candidate_alert_message
    from app.services.volatility_options_persistence import VolatilityOptionsStore

    job_id = str(job_response.get("job_id") or "")
    if not job_id:
        raise RuntimeError("skill runner did not return a job_id")
    job = {}
    for _ in range(36):
        job = call_skill_runner("GET", f"/api/jobs/{job_id}") or {}
        if str(job.get("status") or "").lower() in {"succeeded", "failed"}:
            break
        time.sleep(10)
    if str(job.get("status") or "").lower() != "succeeded":
        raise RuntimeError(str(job.get("error") or f"volatility scan job {job_id} did not succeed"))
    audit = get_job_json(job_id)
    report = audit.get("content") if isinstance(audit, dict) else None
    if not isinstance(report, dict):
        raise RuntimeError("volatility scan JSON audit was unavailable")
    store = VolatilityOptionsStore()
    run_id = store.record_completed_scan(report, run_id=job_id, report_path=job.get("report_path"))
    alerts = VolatilityOptionsAlertService(model=store.model)
    threshold = float(os.getenv("VSO_ALERT_MIN_SCORE", "75"))
    for candidate in report.get("candidates") or []:
        if float(candidate.get("trade_score") or 0) < threshold:
            continue
        symbol = str(candidate.get("symbol") or "UNKNOWN")
        alerts.send_once(
            idempotency_key=f"scan:{run_id}:candidate:{candidate.get('rank')}:{symbol}",
            alert_type="VSO_CANDIDATE",
            title=f"VSO candidate review: {symbol}",
            message=candidate_alert_message(candidate),
            severity="normal",
            run_id=run_id,
        )
    return {"job_id": job_id, "run_id": run_id, "candidate_count": len(report.get("candidates") or [])}


def volatility_selective_scan_job():
    """Run the configured research scan and persist/alert its result; never trade."""
    from app.services.skill_runner_client import call_skill_runner
    from app.services.volatility_options_persistence import VolatilityOptionsStore
    from app.services.volatility_options_service import build_scan_snapshot
    from app.services.volatility_options_alerts import VolatilityOptionsAlertService

    state_id = "volatility_selective_scan"
    started = datetime.now()
    _update_job_state(state_id, running=True, last_started_at=started, last_error=None)
    try:
        store = VolatilityOptionsStore()
        safety = store.get_safety_state()
        if bool(safety.get("KillSwitchActive")):
            _update_job_state(state_id, running=False, last_finished_at=datetime.now(), skipped=True, skip_reason=f"kill switch: {safety.get('Reason')}")
            return
        schedule = store.get_schedule()
        if not schedule or not bool(schedule.get("Enabled")):
            _update_job_state(state_id, running=False, last_finished_at=datetime.now(), skipped=True, skip_reason="schedule disabled or not configured")
            return
        snapshot = build_scan_snapshot(
            symbols=str(schedule["Symbols"]),
            account_equity=float(schedule["AccountEquity"]),
            assignment_exposure=float(schedule.get("AssignmentExposure") or 0),
            event_clear_symbols=str(schedule.get("EventClearSymbols") or ""),
            top_n=int(schedule.get("TopN") or 10),
            dte_min=int(schedule.get("DteMin") or 30),
            dte_max=int(schedule.get("DteMax") or 55),
            min_vol_edge=float(schedule.get("MinimumVolatilityEdge") or 0.02),
            risk_budget_pct=float(schedule.get("RiskBudgetPct") or 0.02),
            max_assignment_exposure_pct=float(schedule.get("MaxAssignmentExposurePct") or 0.75),
        )
        response = call_skill_runner("POST", "/api/jobs/volatility-selective-options", {"snapshot": snapshot})
        result = _persist_volatility_runner_job(response)
        _update_job_state(state_id, **result, running=False, last_finished_at=datetime.now())
        logger.info("[VSO] Scheduled scan complete: %s", result)
    except Exception as exc:
        _update_job_state(state_id, running=False, last_finished_at=datetime.now(), last_error=str(exc))
        logger.error("[VSO] Scheduled scan failed: %s", exc, exc_info=True)
        try:
            VolatilityOptionsAlertService().send_once(
                idempotency_key=f"scheduler:vso:failure:{datetime.now():%Y-%m-%d-%H%M}",
                alert_type="VSO_SCAN_FAILURE",
                title="VSO scheduled scan failed",
                message=f"Volatility-selective scan failed: {exc}. No broker action was taken.",
                severity="high",
            )
        except Exception:
            logger.error("[VSO] Could not send scan-failure alert", exc_info=True)


def volatility_selective_manual_monitor_job():
    """Revalue manually entered positions and send review alerts; never trade."""
    from app.services.volatility_options_monitor import monitor_open_positions

    try:
        result = monitor_open_positions()
        _update_job_state("volatility_selective_manual_monitor", last_finished_at=datetime.now(), **result)
        logger.info("[VSO] Manual monitor: %s", result)
    except Exception as exc:
        _update_job_state("volatility_selective_manual_monitor", last_finished_at=datetime.now(), last_error=str(exc))
        logger.error("[VSO] Manual monitor failed: %s", exc, exc_info=True)


def bet_odds_monitor_job():
    """Scan active TAB odds monitors that are due."""
    from app.services.bet_odds_monitor_service import BetOddsMonitorService

    try:
        result = BetOddsMonitorService().scan_due_monitors()
        if result["due"]:
            logger.info(
                "[Bet Odds] Due=%s scanned=%s failed=%s",
                result["due"],
                result["scanned"],
                result["failed"],
            )
    except Exception as exc:
        logger.error("[Bet Odds] Scheduled scan failed: %s", exc, exc_info=True)


def start_scheduler():
    """
    Start the background scheduler with all configured jobs.

    Called during FastAPI startup.
    """
    global _is_running

    if _is_running:
        logger.warning("Scheduler already running, skipping start")
        return

    scheduler = get_scheduler()

    # Add event listener
    scheduler.add_listener(job_listener, EVENT_JOB_EXECUTED | EVENT_JOB_ERROR)

    # GEX Auto Insight processing is manual-only from the market-flow admin tab.

    scheduler.add_job(
        discord_market_intelligence_job,
        trigger=CronTrigger(
            hour=16,
            minute=0,
            timezone="Australia/Sydney",
        ),
        id="discord_market_intelligence",
        name="Discord Follower Messages Summary",
        replace_existing=True,
        misfire_grace_time=3600,
    )

    # SPX scheduling was retired from FastAPI. The generic strategy-runtime
    # heartbeat owns claims, lifecycle, reports, and notifications. Keeping
    # this scheduler focused on unrelated website jobs prevents two owners
    # from sharing the same SPX work identity.

    # Volatility-selective operation is deliberately non-executing. It creates
    # candidate reports, persists audit records, revalues manually entered
    # positions, and sends idempotent review alerts only.
    scheduler.add_job(
        volatility_selective_scan_job,
        trigger=CronTrigger(minute="*/5", hour="10-15", day_of_week="mon-fri", timezone="America/New_York"),
        id="volatility_selective_scan",
        name="Volatility-Selective Research Scan",
        replace_existing=True,
        misfire_grace_time=300,
    )
    scheduler.add_job(
        volatility_selective_manual_monitor_job,
        trigger=CronTrigger(minute="*/5", hour="9-16", day_of_week="mon-fri", timezone="America/New_York"),
        id="volatility_selective_manual_monitor",
        name="Volatility-Selective Manual Position Monitor",
        replace_existing=True,
        misfire_grace_time=300,
    )

    # Bet odds monitor scans are manual-only. Keep bet_odds_monitor_job available
    # for explicit calls, but do not run automatic background checks.

    scheduler.start()
    _is_running = True

    logger.info("Background scheduler started with jobs:")
    for job in scheduler.get_jobs():
        logger.info(f"  - {job.id}: {job.name} (trigger: {job.trigger})")


def stop_scheduler():
    """
    Stop the background scheduler gracefully.

    Called during FastAPI shutdown.
    """
    global _scheduler, _is_running

    if _scheduler is not None and _is_running:
        _scheduler.shutdown(wait=True)
        _is_running = False
        logger.info("Background scheduler stopped")


def get_scheduler_status() -> dict:
    """
    Get the current status of the scheduler and its jobs.

    Returns:
        Dictionary with scheduler status information
    """
    global _scheduler, _is_running

    if _scheduler is None or not _is_running:
        return {
            "running": False,
            "jobs": []
        }

    jobs = []
    for job in _scheduler.get_jobs():
        jobs.append({
            "id": job.id,
            "name": job.name,
            "trigger": str(job.trigger),
            "next_run_time": job.next_run_time.isoformat() if job.next_run_time else None,
            "pending": job.pending,
            "state": {
                key: _iso(value)
                for key, value in _job_state.get(job.id, {}).items()
            }
        })

    return {
        "running": _is_running,
        "jobs": jobs
    }


def trigger_job_now(job_id: str) -> bool:
    """
    Manually trigger a scheduled job to run immediately.

    Args:
        job_id: The ID of the job to trigger

    Returns:
        True if job was triggered, False if job not found
    """
    global _scheduler

    if _scheduler is None:
        return False

    job = _scheduler.get_job(job_id)
    if job is None:
        return False

    job.modify(next_run_time=datetime.now())
    return True
