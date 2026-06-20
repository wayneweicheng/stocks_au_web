from typing import Any, Dict, List, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import json

from fastapi import HTTPException

from app.core.config import settings


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
    try:
        with urlopen(request, timeout=60) as response:
            raw = response.read().decode("utf-8")
    except HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        detail: Any = raw
        try:
            detail_data = json.loads(raw)
            detail = detail_data.get("detail") or detail_data
        except Exception:
            pass
        raise HTTPException(status_code=exc.code, detail=detail)
    except URLError as exc:
        raise HTTPException(status_code=502, detail=f"Skill runner connection failed: {exc.reason}")
    except TimeoutError:
        raise HTTPException(status_code=504, detail="Skill runner request timed out")

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
