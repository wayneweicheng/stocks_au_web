from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.routers.order_book import router as order_book_router
from app.routers.ta_scan import router as ta_scan_router
from app.routers.diagnostics import router as diagnostics_router


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


