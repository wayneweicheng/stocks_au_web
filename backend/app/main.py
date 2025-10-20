from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.routers.order_book import router as order_book_router
from app.routers.ta_scan import router as ta_scan_router
from app.routers.diagnostics import router as diagnostics_router
from app.routers.monitor_stocks import router as monitor_stocks_router
from app.routers.conditional_orders import router as conditional_orders_router
from app.routers.pegasus_invest_opportunities import router as pegasus_invest_opportunities_router
from app.routers.auth import router as auth_router
from app.routers.pattern_predictions import router as pattern_predictions_router
from app.routers.charts import router as charts_router
from app.routers.pllrs_scanner import router as pllrs_scanner_router
from app.routers.ib_gateway import router as ib_gateway_router
import logging
import time
from fastapi.responses import JSONResponse


logger = logging.getLogger("app")
if not logger.handlers:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    )

app = FastAPI(title="Stocks AU Backend")

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
    logger.info(f"REQ {request.method} {path}{('?' + query) if query else ''} from {client_ip}")
    try:
        response = await call_next(request)
    except Exception as exc:
        duration_ms = (time.perf_counter() - start_time) * 1000.0
        logger.exception(f"ERR {request.method} {path} after {duration_ms:.1f}ms: {exc}")
        return JSONResponse(status_code=500, content={"detail": "Internal Server Error"})
    duration_ms = (time.perf_counter() - start_time) * 1000.0
    logger.info(f"RES {request.method} {path} {response.status_code} {duration_ms:.1f}ms")
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


