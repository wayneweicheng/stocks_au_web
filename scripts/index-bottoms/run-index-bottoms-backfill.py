"""Run historical find-index-bottoms jobs with a bounded concurrency of two.

This is an explicit, one-off backfill runner. It is not registered with
Windows Task Scheduler. Jobs are submitted in chronological order and the
next job is submitted only when one of the two active jobs finishes.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import time
from datetime import date, datetime, time as day_time, timedelta, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
REPO_ROOT = Path(__file__).resolve().parents[2]
TERMINAL_SUCCESS = {"succeeded", "success", "completed"}
TERMINAL_FAILURE = {"failed", "failure", "error", "cancelled", "canceled", "timed_out", "timeout"}


class BackfillError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path(__file__).with_name("config.json"))
    parser.add_argument("--start-date", required=True, help="First observation date, YYYY-MM-DD")
    parser.add_argument("--end-date", required=True, help="Last observation date, YYYY-MM-DD")
    parser.add_argument("--at", default="17:00", help="New York local time for every job, HH:MM")
    parser.add_argument("--max-concurrent", type=int, default=2)
    parser.add_argument("--poll-seconds", type=int, default=30)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def resolve_path(value: str | None, base: Path = REPO_ROOT) -> Path:
    if not value:
        return base
    path = Path(value)
    return path if path.is_absolute() else base / path


def load_config(path: Path) -> dict[str, Any]:
    try:
        config = json.loads(path.resolve().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BackfillError(f"Could not read config {path}: {exc}") from exc
    if not isinstance(config, dict):
        raise BackfillError("The job configuration must contain a JSON object")
    for required in ("runner_url", "endpoint", "payload"):
        if required not in config:
            raise BackfillError(f"Missing required config property: {required}")
    return config


def read_dotenv(path: Path, name: str) -> str:
    if not path.exists():
        return ""
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        if key.strip() == name:
            return value.strip().strip('"').strip("'")
    return ""


def get_token(config: dict[str, Any]) -> str:
    name = str(config.get("token_env", "SKILL_RUNNER_API_TOKEN"))
    token = os.environ.get(name, "")
    if not token:
        token = read_dotenv(resolve_path(config.get("token_dotenv", "backend/.env")), name)
    if not token:
        raise BackfillError(f"{name} is not configured")
    return token


def make_logger(log_directory: Path) -> logging.Logger:
    log_directory.mkdir(parents=True, exist_ok=True)
    filename = datetime.now(timezone.utc).strftime("backfill-%Y%m%d-%H%M%S-") + f"{os.getpid()}.log"
    logger = logging.getLogger("index-bottoms-backfill")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    formatter = logging.Formatter("[%(asctime)s] %(levelname)s %(message)s", "%Y-%m-%dT%H:%M:%SZ")
    formatter.converter = time.gmtime
    file_handler = logging.FileHandler(log_directory / filename, encoding="utf-8")
    console_handler = logging.StreamHandler()
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    logger.info("Log file: %s", log_directory / filename)
    return logger


def parse_date(value: str) -> date:
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise BackfillError(f"Invalid date '{value}', expected YYYY-MM-DD") from exc


def parse_time(value: str) -> day_time:
    try:
        return datetime.strptime(value, "%H:%M").time()
    except ValueError as exc:
        raise BackfillError(f"Invalid time '{value}', expected HH:MM") from exc


def target_dates(start: date, end: date) -> list[date]:
    if end < start:
        raise BackfillError("end-date must not be before start-date")
    dates: list[date] = []
    current = start
    while current <= end:
        if current.weekday() < 5:
            dates.append(current)
        current += timedelta(days=1)
    return dates


def make_payload(template: Any, scheduled_at: str) -> Any:
    if isinstance(template, dict):
        return {key: make_payload(value, scheduled_at) for key, value in template.items()}
    if isinstance(template, list):
        return [make_payload(value, scheduled_at) for value in template]
    if isinstance(template, str):
        return template.replace("{{scheduled_time}}", scheduled_at)
    return template


def request_json(config: dict[str, Any], token: str, method: str, path: str, body: Any = None) -> Any:
    runner_url = str(config["runner_url"]).rstrip("/")
    url = path if path.startswith("http") else f"{runner_url}/{path.lstrip('/')}"
    headers = {"Accept": "application/json", "Authorization": f"Bearer {token}"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode("utf-8")
    request = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(request, timeout=int(config.get("http_timeout_seconds", 20))) as response:
            return json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, OSError, json.JSONDecodeError) as exc:
        raise BackfillError(f"request {method} {path} failed: {exc}") from exc


def job_status(result: Any) -> str:
    if isinstance(result, dict):
        for key in ("status", "state", "job_status"):
            value = result.get(key)
            if value:
                return str(value).lower()
        nested = result.get("data")
        if nested is not result:
            return job_status(nested)
    return "unknown"


def job_id(result: Any) -> str:
    if isinstance(result, dict):
        value = result.get("job_id")
        if value:
            return str(value)
        nested = result.get("data")
        if nested is not result:
            return job_id(nested)
    raise BackfillError("skill runner response did not contain a job_id")


def existing_jobs(config: dict[str, Any], token: str) -> dict[str, dict[str, Any]]:
    try:
        result = request_json(config, token, "GET", "/api/jobs?job_type=find-index-bottoms")
    except BackfillError:
        return {}
    items = result if isinstance(result, list) else result.get("data", []) if isinstance(result, dict) else []
    found: dict[str, dict[str, Any]] = {}
    for item in items:
        if not isinstance(item, dict) or item.get("job_type") != "find-index-bottoms":
            continue
        label = str(item.get("label", ""))
        status = job_status(item)
        if label and status in TERMINAL_SUCCESS | {"queued", "running"}:
            found[label] = item
    return found


def run(args: argparse.Namespace) -> int:
    if args.max_concurrent < 1:
        raise BackfillError("max-concurrent must be at least 1")
    config = load_config(args.config)
    log_directory = resolve_path(config.get("log_directory", "logs/index-bottoms-scheduler"))
    logger = make_logger(log_directory)
    start = parse_date(args.start_date)
    end = parse_date(args.end_date)
    run_time = parse_time(args.at)
    dates = target_dates(start, end)
    logger.info("START range=%s..%s weekdays=%d at=%s timezone=America/New_York max_concurrent=%d", start, end, len(dates), run_time, args.max_concurrent)

    token = "" if args.dry_run else get_token(config)
    already_known = {} if args.dry_run else existing_jobs(config, token)
    backfill_template = config.get("backfill_payload", config["payload"])
    pending: list[tuple[date, str]] = []
    for observation_date in dates:
        scheduled_at = f"{observation_date:%Y-%m-%d} {run_time:%H:%M} America/New_York"
        label = scheduled_at
        known = already_known.get(label)
        if known:
            logger.info("SKIP date=%s existing_job=%s status=%s", observation_date, known.get("job_id"), job_status(known))
        else:
            pending.append((observation_date, scheduled_at))

    if args.dry_run:
        for observation_date, scheduled_at in pending:
            print(json.dumps(make_payload(backfill_template, scheduled_at), separators=(",", ":")))
        logger.info("END status=dry-run pending=%d", len(pending))
        return 0

    active: dict[str, tuple[date, str]] = {}
    failed = 0
    completed = 0
    while pending or active:
        while pending and len(active) < args.max_concurrent:
            observation_date, scheduled_at = pending.pop(0)
            payload = make_payload(backfill_template, scheduled_at)
            try:
                response = request_json(config, token, "POST", str(config["endpoint"]), payload)
                current_job_id = job_id(response)
                active[current_job_id] = (observation_date, scheduled_at)
                logger.info("SUBMIT date=%s as_at=%s job_id=%s active=%d", observation_date, scheduled_at, current_job_id, len(active))
            except BackfillError as exc:
                # Stop rather than skipping a date. Existing jobs are detected
                # on the next invocation, so a rerun can safely resume.
                logger.error("SUBMIT_FAILED date=%s as_at=%s error=%s", observation_date, scheduled_at, exc)
                raise

        if not active:
            continue
        time.sleep(max(1, args.poll_seconds))
        for current_job_id, (observation_date, scheduled_at) in list(active.items()):
            try:
                result = request_json(config, token, "GET", f"/api/jobs/{current_job_id}")
                status = job_status(result)
            except BackfillError as exc:
                logger.warning("POLL_FAILED date=%s job_id=%s error=%s", observation_date, current_job_id, exc)
                continue
            if status in TERMINAL_SUCCESS:
                completed += 1
                del active[current_job_id]
                logger.info("COMPLETE date=%s job_id=%s status=%s remaining=%d", observation_date, current_job_id, status, len(active))
            elif status in TERMINAL_FAILURE:
                failed += 1
                del active[current_job_id]
                logger.error("FAILED date=%s job_id=%s status=%s remaining=%d", observation_date, current_job_id, status, len(active))
            else:
                logger.info("WAIT date=%s job_id=%s status=%s active=%d", observation_date, current_job_id, status, len(active))

    status = "success" if failed == 0 else "failed"
    logger.info("END status=%s completed=%d failed=%d", status, completed, failed)
    return 0 if failed == 0 else 3


def main() -> int:
    try:
        return run(parse_args())
    except Exception as exc:  # noqa: BLE001 - persist every backfill failure
        print(f"index-bottoms backfill failed: {exc}", file=os.sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
