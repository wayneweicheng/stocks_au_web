from fastapi import APIRouter
from typing import Any, Dict
import os
import pyodbc
from app.core.db import get_sql_model
from app.core.config import settings


router = APIRouter(prefix="/debug", tags=["diagnostics"])


@router.get("/info")
def debug_info() -> Dict[str, Any]:
    info: Dict[str, Any] = {}

    # Environment summary (mask sensitive)
    info["env"] = {
        "sql_server_host": os.getenv("sql_server_host", ""),
        "sql_server_port": os.getenv("sql_server_port", ""),
        "sql_server_database": os.getenv("sql_server_database", ""),
        "sql_server_user": os.getenv("sql_server_user", ""),
        "allowed_origins": os.getenv("allowed_origins", ""),
    }

    # Drivers
    try:
        info["odbc_drivers"] = pyodbc.drivers()
    except Exception as e:
        info["odbc_drivers_error"] = str(e)

    # Attempt connection using helper
    try:
        model = get_sql_model()
        # lightweight ping: select 1
        result = model.execute_read_query("select 1 as ok", ())
        info["connection"] = {"ok": True, "result": result}
    except Exception as e:
        info["connection"] = {"ok": False, "error": str(e)}

    # Settings snapshot (non-sensitive)
    info["settings"] = {
        "database": settings.sqlserver_database,
        "port": settings.sqlserver_port,
    }

    return info


