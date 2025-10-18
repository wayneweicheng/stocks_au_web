from fastapi import FastAPI
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


app = FastAPI(title="Stocks AU Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in settings.allowed_origins.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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


