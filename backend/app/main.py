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
from app.core.scheduler import start_scheduler, stop_scheduler, get_scheduler_status
from contextlib import asynccontextmanager
import logging
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

# Configure the root logger so all loggers (uvicorn, app, etc.) inherit this.
_root_logger = logging.getLogger()
if not _root_logger.handlers:
    _root_logger.setLevel(logging.INFO)
    _root_logger.addHandler(_stdout_handler)
    _root_logger.addHandler(_stderr_handler)
else:
    # Handlers already present (e.g. uvicorn configured them) – replace them
    # so we control where output goes.
    _root_logger.handlers.clear()
    _root_logger.setLevel(logging.INFO)
    _root_logger.addHandler(_stdout_handler)
    _root_logger.addHandler(_stderr_handler)

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


@app.get("/api/scheduler/status")
def scheduler_status(username: str = Depends(verify_credentials)):
    """Get the status of the background scheduler and its jobs."""
    return get_scheduler_status()


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

