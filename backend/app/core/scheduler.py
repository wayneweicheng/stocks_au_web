"""
Background Scheduler for Automated Tasks

Uses APScheduler to run background jobs within the FastAPI application.
Currently handles automatic GEX insight processing every 5 minutes.
"""

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.events import EVENT_JOB_ERROR, EVENT_JOB_EXECUTED
from datetime import date, datetime
import logging

logger = logging.getLogger("app.scheduler")

# Global scheduler instance
_scheduler: BackgroundScheduler = None
_is_running: bool = False


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
    # Determine the baseline processing date as the most recent SPXW date <= today
    try:
        gex_service = GEXDataService()
        latest_spxw_date = gex_service.get_latest_observation_date("SPXW", date.today())
    except Exception as e:
        latest_spxw_date = None
        logger.error(f"[GEX Auto Insight] Failed to resolve latest SPXW date: {e}")

    if latest_spxw_date is None:
        logger.info("[GEX Auto Insight] No SPXW data available up to today; skipping run")
        return

    target_date = latest_spxw_date

    logger.info(f"[GEX Auto Insight] Starting scheduled job for {target_date}")

    try:
        service = GEXAutoInsightService()

        # Get current status
        status = service.get_processing_status(target_date)
        pending_count = status.get("pending_count", 0)

        if pending_count == 0:
            logger.info(f"[GEX Auto Insight] No pending stocks to process for {target_date}")
            return

        logger.info(f"[GEX Auto Insight] Found {pending_count} pending stocks to process")

        # Process all pending stocks
        result = service.process_all_pending(target_date, dry_run=False)

        processed = len(result.get("processed", []))
        failed = len(result.get("failed", []))

        duration = (datetime.now() - job_start).total_seconds()
        logger.info(
            f"[GEX Auto Insight] Job completed in {duration:.1f}s: "
            f"{processed} processed, {failed} failed"
        )

        # Log details for processed stocks
        for p in result.get("processed", []):
            logger.info(f"  ✓ {p['stock_code']}: {p.get('signal_strength', 'N/A')}")

        # Log details for failed stocks
        for f in result.get("failed", []):
            logger.warning(f"  ✗ {f['stock_code']}: {f.get('error', 'Unknown error')}")

    except Exception as e:
        logger.error(f"[GEX Auto Insight] Job failed with error: {e}", exc_info=True)


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

    # Add GEX Auto Insight job - runs every 5 minutes
    scheduler.add_job(
        gex_auto_insight_job,
        trigger=IntervalTrigger(minutes=5),
        id='gex_auto_insight',
        name='GEX Auto Insight Processor',
        replace_existing=True
    )

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
            "pending": job.pending
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

    # Run the job function directly
    job.func()
    return True
