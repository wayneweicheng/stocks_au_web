"""Submit one SPX Map job when SPXW appears in the Market Flow GEX list.

Run every five minutes by Task Scheduler during the weekday Sydney evening
window. Eligibility is rechecked each tick; accepted or ambiguous submissions
are durably recorded so later ticks cannot submit duplicates.
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
TARGET_CODE = "SPXW"


class SubmissionRejected(RuntimeError):
    """The runner explicitly rejected the request; the next eligible tick may retry."""


class SubmissionUncertain(RuntimeError):
    """Runner acceptance is unknown; retain state to prevent duplicate submission."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true", help="Check eligibility without submitting or changing state")
    parser.add_argument("--now-utc", help="Override the current time for testing (ISO-8601 UTC)")
    return parser.parse_args()


def normalize_code(value: object) -> str:
    return re.sub(r"\.(?:US|AX)$", "", str(value or "").strip().upper())


def market_flow_date(local_now: datetime) -> date:
    day = local_now.date() - timedelta(days=1)
    while day.weekday() >= 5:
        day -= timedelta(days=1)
    return day


def in_window(local_now: datetime) -> bool:
    minute = local_now.time().replace(second=0, microsecond=0, tzinfo=None)
    return local_now.weekday() < 5 and OPEN <= minute <= CLOSE


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
    query = urlencode({"observation_date": observation_date.isoformat(), "source_type": "GEX"})
    url = f"{str(market['base_url']).rstrip('/')}/api/stock-codes?{query}"
    encoded = base64.b64encode(f"{username}:{password}".encode()).decode("ascii")
    rows = request_json(url, {"Authorization": f"Basic {encoded}"}, int(market.get("timeout_seconds", 20)))
    if not isinstance(rows, list) or any(not isinstance(row, dict) or not isinstance(row.get("stock_code"), str) for row in rows):
        raise RuntimeError("Market Flow stock-codes API returned an invalid list")
    return {normalize_code(row["stock_code"]) for row in rows}


def load_state(path: Path) -> dict:
    if not path.exists():
        return {"version": 1, "dates": {}}
    state = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(state, dict) or state.get("version") != 1 or not isinstance(state.get("dates"), dict):
        raise RuntimeError("Processed-state file is invalid; refusing to risk duplicate SPX Map jobs")
    return state


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix="processed-spx-", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            json.dump(state, file, indent=2, sort_keys=True)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def submit_spx_map_job(config: dict, payload: dict, token: str) -> str:
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
    if isinstance(result, dict) and result.get("job_id"):
        return str(result["job_id"])
    message = str(result.get("message") or "") if isinstance(result, dict) else str(result or "")
    if isinstance(result, dict) and (result.get("error") or result.get("detail") or result.get("status") in ("error", "failed", "rejected", "queue_full")
                                    or "queue is full" in message.lower() or message.lower().startswith(("error", "failed", "rejected"))):
        raise SubmissionRejected(str(result.get("error") or result.get("detail") or message or result.get("status")))
    if isinstance(result, str) and ("queue is full" in result.lower() or result.lower().startswith("error")):
        raise SubmissionRejected(result[:500])
    raise SubmissionUncertain("Runner response had no job_id or explicit error; job acceptance is unknown")


def run_tick(args: argparse.Namespace, config: dict, logger: logging.Logger, log_dir: Path) -> int:
    with common.single_instance(log_dir / "scheduler.lock") as acquired:
        if not acquired:
            logger.info("SKIP another SPX Map scheduler tick is running")
            return 0
        try:
            now_utc = common.parse_now_utc(args.now_utc)
            local_now = now_utc.astimezone(SYDNEY)
            if not in_window(local_now):
                logger.info("SKIP outside Monday-Friday 17:00-23:45 Sydney window now=%s", local_now.isoformat())
                return 0

            observation_date = market_flow_date(local_now)
            date_key = observation_date.isoformat()
            logger.info("CHECK stock=%s Market Flow GEX date=%s", TARGET_CODE, date_key)
            eligible = fetch_market_flow_codes(config, observation_date)
            if TARGET_CODE not in eligible:
                logger.info("SKIP stock=%s absent from Market Flow GEX stock codes date=%s", TARGET_CODE, date_key)
                return 0

            state_path = common.resolve_path(config.get("processed_state_file", "logs/spx-map-scheduler/processed.json"))
            state = load_state(state_path)
            prior = state["dates"].get(date_key)
            if prior is not None and not isinstance(prior, dict):
                raise RuntimeError(f"Invalid processed state for observation date {date_key}")
            if prior and prior.get("status") in ("submitting", "uncertain", "submitted", "sent"):
                logger.info("SKIP stock=%s already %s date=%s job_id=%s", TARGET_CODE, prior["status"], date_key, prior.get("job_id", ""))
                return 0

            token_name = str(config.get("token_env", "SKILL_RUNNER_API_TOKEN"))
            token = read_secret(token_name, common.resolve_path(config.get("token_dotenv", "backend/.env")))
            if not token:
                raise common.ConfigurationError(f"{token_name} is not configured")
            submission_now = common.parse_now_utc(args.now_utc) if args.now_utc else datetime.now(timezone.utc)
            submission_sydney = submission_now.astimezone(SYDNEY)
            payload = common.expand_payload(config["payload"], {
                "current_time": submission_sydney.strftime(config.get("current_time", {}).get("format", "%Y-%m-%d %H:%M")),
                "current_date": submission_sydney.date().isoformat(),
                "current_datetime": submission_sydney.isoformat(),
            })
            if not isinstance(payload, dict):
                raise common.ConfigurationError("SPX Map payload must be an object")
            if args.dry_run:
                logger.info("DRY RUN eligible stock=%s observation_date=%s payload=%s", TARGET_CODE, date_key, json.dumps(payload))
                return 0

            reservation = {"status": "submitting", "stock_code": TARGET_CODE,
                           "observation_date": date_key, "as_at": payload.get("as_at"),
                           "reserved_at_utc": datetime.now(timezone.utc).isoformat()}
            state["dates"][date_key] = reservation
            save_state(state_path, state)
            try:
                job_id = submit_spx_map_job(config, payload, token)
            except SubmissionRejected as exc:
                state["dates"].pop(date_key, None)
                save_state(state_path, state)
                logger.warning("REJECTED stock=%s date=%s; will retry next eligible tick: %s", TARGET_CODE, date_key, exc)
                return 3
            except SubmissionUncertain as exc:
                reservation["status"] = "uncertain"
                reservation["error"] = str(exc)
                save_state(state_path, state)
                logger.error("UNCERTAIN stock=%s date=%s; reservation retained to prevent duplicates: %s", TARGET_CODE, date_key, exc)
                return 3

            reservation["status"] = "submitted"
            reservation["job_id"] = job_id
            reservation["submitted_at_utc"] = datetime.now(timezone.utc).isoformat()
            save_state(state_path, state)
            logger.info("SUBMITTED stock=%s date=%s job_id=%s", TARGET_CODE, date_key, job_id)
            return 0
        except Exception:
            logger.exception("SPX Map scheduler tick failed; no further jobs submitted")
            return 3


def run(args: argparse.Namespace) -> int:
    config = common.load_config(args.config)
    log_dir = common.resolve_path(config.get("log_directory", "logs/spx-map-scheduler"))
    logger, _ = common.configure_logging(log_dir, config.get("log_filename_format", "scheduler-%Y%m%d-%H%M%S-{pid}.log"))
    try:
        return run_tick(args, config, logger, log_dir)
    finally:
        for handler in list(logger.handlers):
            logger.removeHandler(handler)
            handler.close()


def main() -> int:
    try:
        return run(parse_args())
    except Exception as exc:
        print(f"SPX Map scheduler failed: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
