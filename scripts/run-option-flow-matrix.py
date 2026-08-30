#!/usr/bin/env python3
"""Submit a bounded, resumable option-flow job matrix to the skill runner."""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from datetime import date, timedelta, timezone, datetime
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

TICKERS = ("QQQ", "SPY", "MU", "AAPL", "AMAT", "AMD", "AMZN", "ASML", "AVGO")
DEFAULT_START = date(2026, 8, 5)
DEFAULT_END = date(2026, 8, 27)
TERMINAL = {"succeeded", "failed"}
ACTIVE = {"queued", "running"}


def read_token() -> str:
    value = ""
    env_path = Path(__file__).resolve().parents[1] / "backend" / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("SKILL_RUNNER_API_TOKEN"):
                value = line.split("=", 1)[1].strip().strip('"').strip("'")
                break
    if not value:
        raise RuntimeError("SKILL_RUNNER_API_TOKEN is not configured")
    return value


def now_utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class MatrixRunner:
    def __init__(self, args: argparse.Namespace) -> None:
        self.base_url = args.runner_url.rstrip("/")
        self.headers = {"Authorization": f"Bearer {read_token()}", "Accept": "application/json"}
        self.state_path = Path(args.state_file)
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        self.log_path = self.state_path.with_suffix(".log")
        self.poll_seconds = args.poll_seconds
        self.submit_delay = args.submit_delay
        self.max_active = args.max_active
        self.top_n = args.top_n
        self.timeout_minutes = args.timeout_minutes
        self.state = self.load_state()

    def log(self, message: str) -> None:
        line = f"[{now_utc()}] {message}"
        print(line, flush=True)
        with self.log_path.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")

    def load_state(self) -> dict:
        if not self.state_path.exists():
            return {"started_at_utc": now_utc(), "items": {}}
        try:
            return json.loads(self.state_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            self.log("State file was invalid; starting a new state file.")
            return {"started_at_utc": now_utc(), "items": {}}

    def save_state(self) -> None:
        temporary = self.state_path.with_suffix(f".tmp.{__import__('os').getpid()}")
        temporary.write_text(json.dumps(self.state, indent=2), encoding="utf-8")
        temporary.replace(self.state_path)

    def request(self, method: str, path: str, payload: dict | None = None) -> tuple[int, object]:
        headers = dict(self.headers)
        body = None
        if payload is not None:
            body = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = Request(f"{self.base_url}{path}", data=body, headers=headers, method=method)
        try:
            with urlopen(request, timeout=30) as response:
                raw = response.read().decode("utf-8")
                return response.status, json.loads(raw) if raw else {}
        except HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            try:
                payload_data = json.loads(raw) if raw else {}
            except json.JSONDecodeError:
                payload_data = {"detail": raw}
            return exc.code, payload_data
        except (TimeoutError, URLError, OSError) as exc:
            raise RuntimeError(str(exc)) from exc

    def list_jobs(self) -> list[dict]:
        status, payload = self.request("GET", "/api/jobs?job_type=analyze-option-flow")
        if status != 200 or not isinstance(payload, list):
            raise RuntimeError(f"job list returned HTTP {status}")
        return [item for item in payload if isinstance(item, dict)]

    def report_is_top30(self, job_id: str) -> bool:
        status, payload = self.request("GET", f"/api/jobs/{job_id}/report")
        if status != 200 or not isinstance(payload, dict):
            return False
        content = str(payload.get("content") or "")
        # The report's ranked table uses a numeric rank column. This avoids
        # treating an older top-10 report as satisfying the requested top-30 run.
        return bool(re.search(r"^\|\s*30\s*\|", content, flags=re.MULTILINE))

    def update_tracked_statuses(self, jobs: list[dict]) -> None:
        by_id = {str(job.get("job_id")): job for job in jobs}
        changed = False
        for item in self.state["items"].values():
            job_id = item.get("job_id")
            if not job_id or job_id not in by_id:
                continue
            status = by_id[job_id].get("status")
            if status and status != item.get("status"):
                item["status"] = status
                item["updated_at_utc"] = now_utc()
                changed = True
        if changed:
            self.save_state()

    def active_tracked_count(self) -> int:
        return sum(item.get("status") in ACTIVE for item in self.state["items"].values())

    def build_targets(self, start: date, end: date) -> list[tuple[str, str]]:
        dates: list[str] = []
        current = start
        while current <= end:
            if current.weekday() < 5:
                dates.append(current.isoformat())
            current += timedelta(days=1)
        return [(ticker, observation_date) for ticker in TICKERS for observation_date in dates]

    def prepare_existing(self, targets: list[tuple[str, str]]) -> list[tuple[str, str]]:
        try:
            jobs = self.list_jobs()
        except RuntimeError as exc:
            self.log(f"Initial job lookup failed: {exc}")
            jobs = []
        self.update_tracked_statuses(jobs)
        by_label: dict[str, list[dict]] = {}
        for job in jobs:
            label = str(job.get("label") or "")
            if label:
                by_label.setdefault(label, []).append(job)

        pending: list[tuple[str, str]] = []
        for ticker, observation_date in targets:
            key = f"{observation_date}:{ticker}"
            item = self.state["items"].get(key)
            if item and item.get("status") in ACTIVE:
                continue
            if item and item.get("status") == "succeeded" and item.get("satisfies_top_n"):
                continue

            candidates = sorted(by_label.get(key, []), key=lambda job: str(job.get("created_at") or ""), reverse=True)
            satisfied = None
            active_job = None
            for job in candidates:
                if job.get("status") in ACTIVE:
                    active_job = job
                    break
                if job.get("status") == "succeeded" and self.report_is_top30(str(job.get("job_id"))):
                    satisfied = job
                    break
            if active_job:
                self.state["items"][key] = {
                    "ticker": ticker,
                    "observation_date": observation_date,
                    "job_id": str(active_job.get("job_id")),
                    "status": active_job.get("status"),
                    "satisfies_top_n": False,
                    "note": "existing active job reused",
                    "updated_at_utc": now_utc(),
                }
                continue
            if satisfied:
                self.state["items"][key] = {
                    "ticker": ticker,
                    "observation_date": observation_date,
                    "job_id": str(satisfied.get("job_id")),
                    "status": "succeeded",
                    "satisfies_top_n": True,
                    "note": "existing report already contains rank 30",
                    "updated_at_utc": now_utc(),
                }
                continue
            pending.append((ticker, observation_date))
        self.save_state()
        return pending

    def wait_for_capacity(self) -> list[dict]:
        while True:
            try:
                jobs = self.list_jobs()
                self.update_tracked_statuses(jobs)
                total_active = sum(job.get("status") in ACTIVE for job in jobs)
                if self.active_tracked_count() < self.max_active and total_active < 3:
                    return jobs
                self.log(f"Runner capacity reached ({total_active} active; {self.active_tracked_count()} tracked); waiting {self.poll_seconds}s.")
            except RuntimeError as exc:
                self.log(f"Capacity/status lookup failed: {exc}; retrying in {self.poll_seconds}s.")
            time.sleep(self.poll_seconds)

    def submit(self, ticker: str, observation_date: str) -> None:
        key = f"{observation_date}:{ticker}"
        payload = {
            "observation_date": observation_date,
            "ticker": ticker,
            "top_n": self.top_n,
            "timeout_minutes": self.timeout_minutes,
        }
        while True:
            try:
                status, response = self.request("POST", "/api/jobs/analyze-option-flow", payload)
                if status == 200 and isinstance(response, dict) and response.get("job_id"):
                    self.state["items"][key] = {
                        "ticker": ticker,
                        "observation_date": observation_date,
                        "job_id": str(response["job_id"]),
                        "status": str(response.get("status") or "queued"),
                        "top_n": self.top_n,
                        "timeout_minutes": self.timeout_minutes,
                        "submitted_at_utc": now_utc(),
                        "satisfies_top_n": True,
                    }
                    self.save_state()
                    self.log(f"Submitted {key} -> {response['job_id']} (top_n={self.top_n}, timeout={self.timeout_minutes}m).")
                    return
                self.log(f"Submission for {key} returned HTTP {status}; retrying in {self.poll_seconds}s.")
            except RuntimeError as exc:
                self.log(f"Submission for {key} failed: {exc}; retrying in {self.poll_seconds}s.")
            time.sleep(self.poll_seconds)

    def run(self, start: date, end: date) -> None:
        targets = self.build_targets(start, end)
        pending = self.prepare_existing(targets)
        self.log(f"Matrix contains {len(targets)} weekday/ticker combinations; {len(pending)} require a top-{self.top_n} submission.")
        for index, (ticker, observation_date) in enumerate(pending, start=1):
            self.wait_for_capacity()
            self.submit(ticker, observation_date)
            self.log(f"Submission progress: {index}/{len(pending)}.")
            if index < len(pending):
                time.sleep(self.submit_delay)

        while self.active_tracked_count():
            try:
                jobs = self.list_jobs()
                self.update_tracked_statuses(jobs)
                self.log(f"Completion monitoring: {len([i for i in self.state['items'].values() if i.get('status') in ACTIVE])} tracked jobs still active.")
            except RuntimeError as exc:
                self.log(f"Completion lookup failed: {exc}")
            if self.active_tracked_count():
                time.sleep(self.poll_seconds)
        self.log("Option-flow matrix submission and completion monitoring finished.")


def parse_date(value: str) -> date:
    return date.fromisoformat(value)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runner-url", default="http://192.168.20.112:3205")
    parser.add_argument("--state-file", default="logs/option-flow-matrix-2026-08-05-to-2026-08-27.json")
    parser.add_argument("--start", default=DEFAULT_START.isoformat())
    parser.add_argument("--end", default=DEFAULT_END.isoformat())
    parser.add_argument("--top-n", type=int, default=30)
    parser.add_argument("--timeout-minutes", type=int, default=90)
    parser.add_argument("--max-active", type=int, default=2)
    parser.add_argument("--poll-seconds", type=int, default=30)
    parser.add_argument("--submit-delay", type=int, default=5)
    args = parser.parse_args()
    if args.max_active < 1 or args.max_active > 2:
        parser.error("--max-active must be between 1 and 2")
    if args.top_n < 1 or args.timeout_minutes < 1:
        parser.error("top_n and timeout_minutes must be positive")
    try:
        MatrixRunner(args).run(parse_date(args.start), parse_date(args.end))
    except KeyboardInterrupt:
        print("Interrupted; state file is resumable.", file=sys.stderr)
        return 130
    except Exception as exc:
        print(f"Fatal matrix runner error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
