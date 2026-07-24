from typing import Any, Dict, List, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import json
import logging
import time

from fastapi import HTTPException

from app.core.config import settings


SKILL_RUNNER_REQUEST_TIMEOUT_SECONDS = 180
logger = logging.getLogger(__name__)


def call_skill_runner(method: str, path: str, payload: Optional[Dict[str, Any]] = None) -> Any:
    token = settings.skill_runner_api_token.strip()
    if not token:
        raise HTTPException(status_code=500, detail="SKILL_RUNNER_API_TOKEN is not configured")

    body = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    base_url = settings.skill_runner_api_base_url.rstrip("/")
    request = Request(f"{base_url}{path}", data=body, headers=headers, method=method)
    started = time.perf_counter()
    try:
        with urlopen(request, timeout=SKILL_RUNNER_REQUEST_TIMEOUT_SECONDS) as response:
            raw = response.read().decode("utf-8")
            elapsed_ms = (time.perf_counter() - started) * 1000.0
            logger.info(
                "Skill runner %s %s -> %s %.1fms",
                method,
                path,
                response.status,
                elapsed_ms,
            )
    except HTTPError as exc:
        elapsed_ms = (time.perf_counter() - started) * 1000.0
        raw = exc.read().decode("utf-8", errors="replace")
        detail: Any = raw
        try:
            detail_data = json.loads(raw)
            detail = detail_data.get("detail") or detail_data
        except Exception:
            pass
        logger.error(
            "Skill runner %s %s -> %s %.1fms detail=%r",
            method,
            path,
            exc.code,
            elapsed_ms,
            detail,
        )
        raise HTTPException(status_code=exc.code, detail=detail)
    except URLError as exc:
        elapsed_ms = (time.perf_counter() - started) * 1000.0
        logger.error("Skill runner %s %s connection failed after %.1fms: %s", method, path, elapsed_ms, exc.reason)
        raise HTTPException(status_code=502, detail=f"Skill runner connection failed: {exc.reason}")
    except TimeoutError:
        elapsed_ms = (time.perf_counter() - started) * 1000.0
        logger.error("Skill runner %s %s timed out after %.1fms", method, path, elapsed_ms)
        raise HTTPException(
            status_code=504,
            detail=f"Skill runner request timed out after {SKILL_RUNNER_REQUEST_TIMEOUT_SECONDS} seconds",
        )

    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"raw": raw}


def list_reports(job_type: str) -> Any:
    return call_skill_runner("GET", f"/api/reports?{urlencode({'job_type': job_type})}")


def get_job_report(job_id: str) -> Any:
    return call_skill_runner("GET", f"/api/jobs/{job_id}/report")


def get_first_value(item: Dict[str, Any], keys: List[str]) -> Optional[Any]:
    for key in keys:
        value = item.get(key)
        if value is not None and value != "":
            return value
    return None


def extract_report_items(data: Any) -> List[Dict[str, Any]]:
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    if not isinstance(data, dict):
        return []

    for key in ("items", "reports", "data", "results"):
        value = data.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
    return []


def extract_report_content(data: Any) -> str:
    if isinstance(data, str):
        return data
    if isinstance(data, dict):
        content = get_first_value(data, ["content", "report_markdown", "markdown", "report", "text"])
        if content is not None:
            return str(content)
    return json.dumps(data, indent=2, ensure_ascii=False)
