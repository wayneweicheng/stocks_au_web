from fastapi import FastAPI, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.routers.order_book import router as order_book_router
from app.routers.ta_scan import router as ta_scan_router
from app.routers.diagnostics import router as diagnostics_router
from app.routers.monitor_stocks import router as monitor_stocks_router
from app.routers.conditional_orders import router as conditional_orders_router
from app.routers.pegasus_invest_opportunities import router as pegasus_invest_opportunities_router
from app.routers.auth import router as auth_router, verify_credentials
from app.routers.pattern_predictions import router as pattern_predictions_router
from app.routers.charts import router as charts_router
from app.routers.pllrs_scanner import router as pllrs_scanner_router
from app.routers.ib_gateway import router as ib_gateway_router
from app.routers.strategy_orders import router as strategy_orders_router
from app.routers.ib_orders import router as ib_orders_router
from app.routers.ib_account import router as ib_account_router
from app.routers.research_links import router as research_links_router
from app.routers.commenters import router as commenters_router
from app.routers.stock_ratings import router as stock_ratings_router
from app.routers.gex_signals import router as gex_signals_router
from app.routers.price_predictions import router as price_predictions_router
from app.routers.stock_codes import router as stock_codes_router
from app.routers.signal_strength import router as signal_strength_router
from app.routers.breakout_watchlist import router as breakout_watchlist_router
from app.routers.breakout_watchlist_us import router as breakout_watchlist_us_router
from app.routers.gap_up_watchlist import router as gap_up_watchlist_router
from app.routers.breakout_consolidation_analysis import router as breakout_consolidation_analysis_router
from app.routers.trading_halt import router as trading_halt_router
from app.routers.notification_users import router as notification_users_router
from app.routers.subscription_types import router as subscription_types_router
from app.routers.user_subscriptions import router as user_subscriptions_router
from app.routers.announcement_analysis import router as announcement_analysis_router
from app.routers.gex_auto_insight import router as gex_auto_insight_router
from app.routers.broker_analysis import router as broker_analysis_router
from app.routers.option_insights import router as option_insights_router
from app.routers.discord_summary import router as discord_summary_router
from app.routers.trading_orders import router as trading_orders_router
from app.routers.option_recommendations import router as option_recommendations_router
from app.routers.option_orders import router as option_orders_router
from app.routers.price_levels_30m import router as price_levels_30m_router
from app.routers.calculated_gex import router as calculated_gex_router
from app.routers.us_market_dashboards import router as us_market_dashboards_router
from app.routers.stock_analysis import router as stock_analysis_router
from app.routers.asx_data_refresh import router as asx_data_refresh_router
from app.routers.index_stock_price_mapping import router as index_stock_price_mapping_router
from app.routers.market_command import router as market_command_router
from app.routers.bet_odds_monitors import router as bet_odds_monitors_router
from app.core.scheduler import start_scheduler, stop_scheduler, get_scheduler_status, trigger_job_now
from app.routers.market_theme_reports import router as market_theme_reports_router
from app.core.scheduler import start_scheduler, stop_scheduler, get_scheduler_status
from contextlib import asynccontextmanager
import logging
import os
from pathlib import Path
import sys
import time
from fastapi.responses import JSONResponse

# ---------------------------------------------------------------------------
# Logging setup
#
# The supervisor script (start-apps.ps1) launches uvicorn via:
#   -RedirectStandardOutput  → backend-<ts>.log          (stdout)
#   -RedirectStandardError   → backend-<ts>-error.log    (stderr)
#
# Python's default StreamHandler and uvicorn's loggers all write to *stderr*,
# which causes INFO noise to flood the -error.log file.
#
# Strategy:
#   • stdout handler  – level INFO+  (normal operational output)
#   • stderr handler  – level WARNING+ only (true errors/warnings)
#
# This way -error.log stays clean (only real problems) and the normal .log
# captures the full INFO stream.
# ---------------------------------------------------------------------------
_LOG_FORMAT = "%(asctime)s %(levelname)s [%(name)s] %(message)s"


class _BelowLevelFilter(logging.Filter):
    def __init__(self, level: int):
        super().__init__()
        self.level = level

    def filter(self, record: logging.LogRecord) -> bool:
        return record.levelno < self.level

# Reconfigure stdout/stderr to UTF-8 so Unicode characters in log messages
# (e.g. checkmarks) don't cause UnicodeEncodeError on Windows cp1252 consoles.
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

_stdout_handler = logging.StreamHandler(sys.stdout)
_stdout_handler.setLevel(logging.DEBUG)
_stdout_handler.setFormatter(logging.Formatter(_LOG_FORMAT))

_stderr_handler = logging.StreamHandler(sys.stderr)
_stderr_handler.setLevel(logging.WARNING)
_stderr_handler.setFormatter(logging.Formatter(_LOG_FORMAT))

_error_log_file = os.environ.get("BACKEND_ERROR_LOG_FILE")
if not _error_log_file:
    repo_root = Path(__file__).resolve().parents[2]
    log_dir = repo_root / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    _error_log_file = str(log_dir / f"backend-out-{time.strftime('%Y%m%d-%H%M%S')}-error.log")

_error_file_handler = logging.FileHandler(_error_log_file, encoding="utf-8")
_error_file_handler.setLevel(logging.ERROR)
_error_file_handler.setFormatter(logging.Formatter(_LOG_FORMAT))

# When stderr is redirected to the same error log by the launcher, keep stderr
# for warnings and non-logging process output while routing logging errors
# through the explicit file handler.
_stderr_handler.addFilter(_BelowLevelFilter(logging.ERROR))

# Configure the root logger so all loggers (uvicorn, app, etc.) inherit this.
_root_logger = logging.getLogger()
if not _root_logger.handlers:
    _root_logger.setLevel(logging.INFO)
    _root_logger.addHandler(_stdout_handler)
    _root_logger.addHandler(_stderr_handler)
    _root_logger.addHandler(_error_file_handler)
else:
    # Handlers already present (e.g. uvicorn configured them) – replace them
    # so we control where output goes.
    _root_logger.handlers.clear()
    _root_logger.setLevel(logging.INFO)
    _root_logger.addHandler(_stdout_handler)
    _root_logger.addHandler(_stderr_handler)
    _root_logger.addHandler(_error_file_handler)

# Suppress overly verbose third-party loggers that add noise at INFO level.
logging.getLogger("uvicorn.access").setLevel(logging.WARNING)

logger = logging.getLogger("app")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    # Startup
    logger.info("Starting background scheduler...")
    start_scheduler()
    yield
    # Shutdown
    logger.info("Stopping background scheduler...")
    stop_scheduler()


app = FastAPI(title="Stocks AU Backend", lifespan=lifespan)

origins = [origin.strip() for origin in settings.allowed_origins.split(",") if origin.strip()]
logger.info("CORS: allow_origins=%s allow_origin_regex=%s", origins, settings.allowed_origin_regex)
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=settings.allowed_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logger.info(
    "Backend startup: SQL driver=%s encrypt=%s trust_cert=%s",
    settings.sqlserver_odbc_driver,
    settings.sqlserver_encrypt,
    settings.sqlserver_trust_server_certificate,
)

@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    start_time = time.perf_counter()
    client_ip = request.headers.get("x-forwarded-for") or (request.client.host if request.client else "?")
    path = request.url.path
    query = request.url.query
    logger.info("REQ %s %s%s from %s", request.method, path, ("?" + query) if query else "", client_ip)
    try:
        response = await call_next(request)
    except Exception as exc:
        duration_ms = (time.perf_counter() - start_time) * 1000.0
        exc_type = type(exc).__name__
        logger.error(
            "ERR %s %s after %.1fms [%s]: %s",
            request.method, path, duration_ms, exc_type, exc,
            exc_info=True,
        )
        return JSONResponse(status_code=500, content={"detail": f"{exc_type}: {exc}"})
    duration_ms = (time.perf_counter() - start_time) * 1000.0
    if response.status_code >= 500:
        logger.error(
            "ERR %s %s after %.1fms [%s]",
            request.method,
            path,
            duration_ms,
            response.status_code,
        )
    logger.info("RES %s %s %s %.1fms", request.method, path, response.status_code, duration_ms)
    return response


@app.get("/healthz")
def healthz():
    return {"status": "ok"}

app.include_router(order_book_router)
app.include_router(ta_scan_router)
app.include_router(diagnostics_router)
app.include_router(monitor_stocks_router)
app.include_router(conditional_orders_router)
app.include_router(pegasus_invest_opportunities_router)
app.include_router(auth_router)
app.include_router(pattern_predictions_router)
app.include_router(charts_router)
app.include_router(pllrs_scanner_router)
app.include_router(ib_gateway_router)
app.include_router(strategy_orders_router)
app.include_router(ib_orders_router)
app.include_router(ib_account_router)
app.include_router(research_links_router)
app.include_router(commenters_router)
app.include_router(stock_ratings_router)
app.include_router(gex_signals_router)
app.include_router(price_predictions_router)
app.include_router(stock_codes_router)
app.include_router(signal_strength_router)
app.include_router(breakout_watchlist_router)
app.include_router(breakout_watchlist_us_router)
app.include_router(gap_up_watchlist_router)
app.include_router(breakout_consolidation_analysis_router)
app.include_router(trading_halt_router)
app.include_router(notification_users_router)
app.include_router(subscription_types_router)
app.include_router(user_subscriptions_router)
app.include_router(announcement_analysis_router)
app.include_router(gex_auto_insight_router)
app.include_router(broker_analysis_router)
app.include_router(option_insights_router)
app.include_router(discord_summary_router)
app.include_router(trading_orders_router)
app.include_router(option_recommendations_router)
app.include_router(option_orders_router)
app.include_router(price_levels_30m_router)
app.include_router(calculated_gex_router)
app.include_router(us_market_dashboards_router)
app.include_router(stock_analysis_router)
app.include_router(asx_data_refresh_router)
app.include_router(index_stock_price_mapping_router)
app.include_router(market_command_router)
app.include_router(bet_odds_monitors_router)
app.include_router(market_theme_reports_router)


@app.get("/api/scheduler/status")
def scheduler_status(username: str = Depends(verify_credentials)):
    """Get the status of the background scheduler and its jobs."""
    return get_scheduler_status()


@app.post("/api/scheduler/jobs/{job_id}/run-now")
def scheduler_run_now(job_id: str, username: str = Depends(verify_credentials)):
    """Ask a scheduled job to run as soon as possible."""
    triggered = trigger_job_now(job_id)
    if not triggered:
        return JSONResponse(status_code=404, content={"detail": f"Scheduler job {job_id} not found"})
    return {"job_id": job_id, "triggered": True}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="127.0.0.1",
        port=3101,
        reload=True,
        reload_dirs=["app"],
        timeout_keep_alive=620,
    )
