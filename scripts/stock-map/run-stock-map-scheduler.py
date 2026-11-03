"""Submit eligible Stock Maps once per Market Flow observation date.

Invoked every five minutes by Task Scheduler. The daily report window, market-flow
eligibility and persisted per-stock submissions are all checked again on each tick.
A reservation is written before POST so an ambiguous timeout cannot create duplicate jobs.
"""
from __future__ import annotations

import argparse
import base64
import importlib.util
import json
import logging
import os
import re
import sys
import tempfile
import time as time_module
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

COMMON_PATH = Path(__file__).resolve().parents[1] / "skill-runner" / "run-skill-runner-job.py"
SPEC = importlib.util.spec_from_file_location("skill_runner_scheduler", COMMON_PATH)
assert SPEC and SPEC.loader
common = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(common)

SYDNEY = ZoneInfo("Australia/Sydney")
OPEN = time(17, 0)
CLOSE = time(23, 45)
REPORT_DATE = re.compile(r"(\d{4}-\d{2}-\d{2})\s+\d{2}:\d{2}(?::\d{2})?\s+Australia/Sydney", re.I)
ET_FILE_DATE = re.compile(r"stock_map_[A-Z0-9.^-]+_(\d{8})_(\d{4})_ET\.html?$", re.I)


class SubmissionRejected(RuntimeError):
    """The runner explicitly rejected the request, so retrying next tick is safe."""


class SubmissionUncertain(RuntimeError):
    """No reliable runner response; avoid a duplicate submission until reconciled."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true", help="Check read-only eligibility without creating jobs or updating state")
    parser.add_argument("--now-utc", help="Override the time for testing (ISO-8601 UTC)")
    return parser.parse_args()


def normalize_code(value: object) -> str:
    return re.sub(r"\.(?:US|AX)$", "", str(value or "").strip().upper())


def market_flow_date(local_now: datetime) -> date:
    # Same date rule as the Market Flow page's default: previous business day.
    day = local_now.date() - timedelta(days=1)
    while day.weekday() >= 5:
        day -= timedelta(days=1)
    return day


def in_window(local_now: datetime) -> bool:
    # Include the full 23:45 minute: the Windows trigger normally fires at
    # 23:45:01 or later, not at exactly 23:45:00.000000.
    clock_minute = local_now.time().replace(second=0, microsecond=0, tzinfo=None)
    return local_now.weekday() < 5 and OPEN <= clock_minute <= CLOSE


def read_secret(name: str, dotenv_path: Path) -> str:
    return os.environ.get(name, "") or common.read_dotenv(dotenv_path, name)


def request_json(url: str, headers: dict[str, str], timeout: int) -> Any:
    request = Request(url, headers={**headers, "Accept": "application/json"}, method="GET")
    with urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_market_flow_codes(config: dict, observation_date: date) -> set[str]:
    market = config["market_flow"]
    dotenv = common.resolve_path(market.get("credentials_dotenv", "backend/.env"))
    username = read_secret(market.get("username_env", "ADMIN_USERNAME"), dotenv)
    password = read_secret(market.get("password_env", "ADMIN_PASSWORD"), dotenv)
    if not username or not password:
        raise common.ConfigurationError("Market Flow API Basic credentials are not configured")
    url = f"{str(market['base_url']).rstrip('/')}/api/stock-codes?{urlencode({'observation_date': observation_date.isoformat(), 'source_type': 'GEX'})}"
    encoded = base64.b64encode(f"{username}:{password}".encode()).decode("ascii")
    rows = request_json(url, {"Authorization": f"Basic {encoded}"}, int(market.get("timeout_seconds", 20)))
    if not isinstance(rows, list) or any(not isinstance(row, dict) or not isinstance(row.get("stock_code"), str) for row in rows):
        raise RuntimeError("Market Flow stock-codes API returned an invalid list")
    return {normalize_code(row["stock_code"]) for row in rows}


def runner_get(config: dict, token: str, path: str) -> Any:
    url = f"{str(config['runner_url']).rstrip('/')}{path}"
    return request_json(url, {"Authorization": f"Bearer {token}"}, int(config.get("http_timeout_seconds", 20)))


def report_items(value: Any) -> list[dict]:
    if isinstance(value, list):
        rows = value
    elif isinstance(value, dict):
        rows = next((value[key] for key in ("items", "reports", "data", "results") if isinstance(value.get(key), list)), None)
    else:
        rows = None
    if rows is None or any(not isinstance(row, dict) for row in rows):
        raise RuntimeError("Stock Map report listing is unavailable or malformed; refusing to submit duplicate jobs")
    return rows


def report_job_id(item: dict) -> str:
    return str(item.get("job_id") or item.get("id") or item.get("jobId") or "")


def report_filename(item: dict) -> str:
    for key in ("file_name", "filename", "report_file", "report_filename", "report_path", "relative_path", "path", "file"):
        if isinstance(item.get(key), str) and item[key]:
            return str(item[key])
    return ""


def is_html_report(item: dict) -> bool:
    source = " ".join([report_filename(item), *(str(item.get(key) or "") for key in
        ("file_type", "format", "mime_type", "content_type"))])
    return bool(re.search(r"\.html?(?=$|\s|[?#])|text/html|(?:^|\s)html(?:$|\s)", source, re.I))


def report_code(item: dict) -> str:
    for key in ("stock_code", "instrument_code", "symbol", "ticker"):
        if item.get(key):
            return normalize_code(item[key])
    title = str(item.get("title") or item.get("report_title") or "")
    match = re.match(r"^([A-Z0-9.^-]+)(?=[:\s_])", title, re.I)
    if match:
        return normalize_code(match.group(1))
    match = re.search(r"stock_map_([A-Z0-9.^-]+)_\d{8}_\d{4}_ET\.html?", report_filename(item), re.I)
    return normalize_code(match.group(1)) if match else ""


def report_sydney_date(item: dict) -> str:
    for value in (item.get("as_at"), item.get("as_of_sydney"), item.get("title"), item.get("report_title")):
        match = REPORT_DATE.search(str(value or ""))
        if match:
            return match.group(1)
    sydney_timestamp = item.get("as_of_sydney")
    if isinstance(sydney_timestamp, str):
        try:
            parsed = datetime.fromisoformat(sydney_timestamp.replace("Z", "+00:00"))
            if parsed.tzinfo is not None:
                return parsed.astimezone(SYDNEY).date().isoformat()
        except ValueError:
            pass
    # Some runner versions expose only a filename with the New York as-at timestamp.
    match = ET_FILE_DATE.search(report_filename(item).replace("\\", "/").split("/")[-1])
    if match:
        eastern = datetime.strptime("".join(match.groups()), "%Y%m%d%H%M").replace(tzinfo=ZoneInfo("America/New_York"))
        return eastern.astimezone(SYDNEY).date().isoformat()
    return ""


def matching_html_report(reports: list[dict], stock_code: str, run_date: str, job_id: str = "") -> dict | None:
    for item in reports:
        if not is_html_report(item):
            continue
        # When reconciling our own submission, a different report for the same
        # symbol/date is not proof that our job produced an artifact.
        if job_id:
            if report_job_id(item) == job_id:
                return item
        elif report_code(item) == stock_code and report_sydney_date(item) == run_date:
            return item
    return None


def load_state(path: Path) -> dict:
    if not path.exists():
        return {"version": 1, "dates": {}}
    state = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(state, dict) or state.get("version") != 1 or not isinstance(state.get("dates"), dict):
        raise RuntimeError("Processed-state file is invalid; refusing to submit duplicate jobs")
    return state


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix="processed-", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            json.dump(state, file, indent=2, sort_keys=True)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def submit_stock_map_job(config: dict, payload: dict, token: str) -> str:
    url = f"{str(config['runner_url']).rstrip('/')}/{str(config['endpoint']).lstrip('/')}"
    request = Request(url, data=json.dumps(payload).encode("utf-8"), method="POST", headers={
        "Authorization": f"Bearer {token}", "Content-Type": "application/json", "Accept": "application/json"})
    try:
        with urlopen(request, timeout=int(config.get("http_timeout_seconds", 20))) as response:
            body = response.read().decode("utf-8")
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:500]
        raise SubmissionRejected(f"HTTP {exc.code}: {detail or exc.reason}") from exc
    except (URLError, TimeoutError, OSError) as exc:
        raise SubmissionUncertain(f"No definite runner response: {exc}") from exc
    try:
        result = json.loads(body)
    except json.JSONDecodeError as exc:
        if "queue is full" in body.lower() or body.strip().lower().startswith("error"):
            raise SubmissionRejected(body[:500]) from exc
        raise SubmissionUncertain("Runner returned non-JSON response; job acceptance is unknown") from exc
    if isinstance(result, str) and ("queue is full" in result.lower() or result.lower().startswith("error")):
        raise SubmissionRejected(result[:500])
    if isinstance(result, dict) and result.get("job_id"):
        return str(result["job_id"])
    message = str(result.get("message") or "") if isinstance(result, dict) else ""
    if isinstance(result, dict) and (result.get("error") or result.get("detail") or result.get("status") in ("error", "failed", "rejected", "queue_full")
                                     or "queue is full" in message.lower() or message.lower().startswith(("error", "failed", "rejected"))):
        raise SubmissionRejected(str(result.get("error") or result.get("detail") or result.get("message") or result.get("status")))
    raise SubmissionUncertain("Runner response had no job_id or explicit error; job acceptance is unknown")


def job_status(config: dict, token: str, job_id: str) -> str:
    value = runner_get(config, token, f"/api/jobs/{job_id}")
    if not isinstance(value, dict):
        return "unknown"
    nested = value.get("job") if isinstance(value.get("job"), dict) else value
    return str(nested.get("status") or nested.get("state") or "unknown").lower()


def _run_tick(args: argparse.Namespace, config: dict, logger: logging.Logger, log_dir: Path) -> int:
    with common.single_instance(log_dir / "scheduler.lock") as acquired:
        if not acquired:
            logger.info("SKIP another Stock Map scheduler tick is running")
            return 0
        try:
            now_utc = common.parse_now_utc(args.now_utc)
            local_now = now_utc.astimezone(SYDNEY)
            if not in_window(local_now):
                logger.info("SKIP outside Monday-Friday 17:00-23:45 Sydney window now=%s", local_now.isoformat())
                return 0
            date_key = market_flow_date(local_now).isoformat()
            _, stocks, delay = common.get_batch_settings(config)
            stocks = list(dict.fromkeys(normalize_code(stock) for stock in stocks))
            if not all(re.fullmatch(r"[A-Z0-9.^-]+", stock) for stock in stocks):
                raise common.ConfigurationError("Invalid stock code in batch.values")
            logger.info("CHECK date=%s stocks=%s", date_key, ",".join(stocks))
            eligible = fetch_market_flow_codes(config, date.fromisoformat(date_key))
            state_path = common.resolve_path(config.get("processed_state_file", "logs/stock-map-scheduler/processed.json"))
            state = load_state(state_path)
            token_name = str(config.get("token_env", "SKILL_RUNNER_API_TOKEN"))
            token = read_secret(token_name, common.resolve_path(config.get("token_dotenv", "backend/.env")))
            if not token:
                raise common.ConfigurationError(f"{token_name} is not configured")
            reports = report_items(runner_get(config, token, "/api/reports?job_type=stock-map"))
            daily = state["dates"].setdefault(date_key, {})
            if not isinstance(daily, dict):
                raise RuntimeError("Invalid processed state for this observation date")
            failures = False
            attempted_submission = False
            for stock in stocks:
                if not in_window((common.parse_now_utc(args.now_utc) if args.now_utc else datetime.now(timezone.utc)).astimezone(SYDNEY)):
                    logger.info("STOP Sydney processing window has closed")
                    break
                if stock not in eligible:
                    logger.info("SKIP stock=%s date=%s absent from Market Flow GEX stock codes", stock, date_key)
                    continue
                prior = daily.get(stock)
                if prior is not None and not isinstance(prior, dict):
                    raise RuntimeError(f"Invalid processed state for {stock}")
                # Older ticks adopted any same-day HTML (even a manual report)
                # as "reported" without a submitted_at. Such an entry is not
                # evidence of this scheduler's own POST and must not suppress it.
                external_prior = prior if prior and prior.get("status") == "reported" and not prior.get("submitted_at") else None
                if external_prior:
                    prior = None
                external = matching_html_report(reports, stock, local_now.date().isoformat()) if prior is None else None
                external_report_job_id = str((external_prior or {}).get("job_id") or report_job_id(external or {}))
                if external_report_job_id:
                    logger.info("EXTERNAL stock=%s HTML report job_id=%s is not a scheduler submission", stock, external_report_job_id)
                existing = (matching_html_report(reports, stock, local_now.date().isoformat(), str(prior["job_id"]))
                            if prior and prior.get("submitted_at") and prior.get("job_id") else None)
                if existing:
                    if not args.dry_run:
                        daily[stock] = {**(prior or {}), "status": "reported", "job_id": report_job_id(existing),
                                        "processed_at": datetime.now(timezone.utc).isoformat(), "market_flow_date": date_key}
                        save_state(state_path, state)
                    logger.info("SKIP stock=%s existing HTML report job_id=%s", stock, report_job_id(existing))
                    continue
                if prior and prior.get("status") in ("submitting", "uncertain", "submitted", "reported"):
                    if prior.get("status") == "submitted" and prior.get("job_id"):
                        try:
                            status = job_status(config, token, str(prior["job_id"]))
                            if status in ("failed", "error", "cancelled", "canceled", "timed_out"):
                                logger.warning("FAILED stock=%s job_id=%s status=%s; eligible for retry on the next tick", stock, prior["job_id"], status)
                                if not args.dry_run:
                                    daily[stock]["status"] = "failed"
                                    save_state(state_path, state)
                                continue
                        except Exception as exc:  # fail closed on unknown job status
                            logger.warning("SKIP stock=%s job status unavailable: %s", stock, exc)
                            failures = True
                            continue
                    logger.info("SKIP stock=%s already %s job_id=%s", stock, prior["status"], prior.get("job_id", ""))
                    continue
                if attempted_submission and delay and not args.dry_run:
                    logger.info("WAIT seconds=%s before next Stock Map submission", delay)
                    time_module.sleep(delay)
                submission_now = (common.parse_now_utc(args.now_utc) if args.now_utc else datetime.now(timezone.utc)).astimezone(SYDNEY)
                if not in_window(submission_now):
                    logger.info("STOP Sydney processing window closed before submitting stock=%s", stock)
                    break
                payload = common.expand_payload(config["payload"], {
                    "stock_code": stock,
                    "current_time": submission_now.strftime(config.get("current_time", {}).get("format", "%Y-%m-%d %H:%M")),
                    "current_date": submission_now.date().isoformat(), "current_datetime": submission_now.isoformat(),
                })
                if not isinstance(payload, dict):
                    raise common.ConfigurationError("Stock Map payload must be an object")
                if args.dry_run:
                    logger.info("DRY RUN stock=%s payload=%s", stock, json.dumps(payload))
                    continue
                attempted_submission = True
                daily[stock] = {"status": "submitting", "market_flow_date": date_key,
                                "as_at": payload.get("as_at"), "submitted_at": datetime.now(timezone.utc).isoformat()}
                if external_report_job_id:
                    daily[stock]["external_report_job_id"] = external_report_job_id
                save_state(state_path, state)  # reservation before POST (timeout may still have created a job)
                try:
                    job_id = submit_stock_map_job(config, payload, token)
                except SubmissionRejected as exc:
                    if external_prior:
                        daily[stock] = external_prior
                    else:
                        daily.pop(stock, None)
                    save_state(state_path, state)
                    logger.warning("REJECTED stock=%s; no processed state retained; retry on next tick: %s", stock, exc)
                    failures = True
                    continue
                except SubmissionUncertain as exc:
                    daily[stock]["status"] = "uncertain"
                    save_state(state_path, state)
                    logger.error("UNCERTAIN stock=%s; reservation retained to prevent duplicates: %s", stock, exc)
                    failures = True
                    continue
                daily[stock]["status"] = "submitted"
                daily[stock]["job_id"] = job_id
                save_state(state_path, state)
                logger.info("SUBMITTED stock=%s job_id=%s date=%s", stock, job_id, date_key)
            return 3 if failures else 0
        except Exception:
            logger.exception("Stock Map scheduler tick failed; no further jobs submitted")
            return 3


def run(args: argparse.Namespace) -> int:
    config = common.load_config(args.config)
    log_dir = common.resolve_path(config.get("log_directory", "logs/stock-map-scheduler"))
    logger, _ = common.configure_logging(log_dir, config.get("log_filename_format", "scheduler-%Y%m%d-%H%M%S-{pid}.log"))
    try:
        return _run_tick(args, config, logger, log_dir)
    finally:
        for handler in list(logger.handlers):
            logger.removeHandler(handler)
            handler.close()


def main() -> int:
    try:
        return run(parse_args())
    except Exception as exc:
        print(f"Stock Map scheduler failed: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
