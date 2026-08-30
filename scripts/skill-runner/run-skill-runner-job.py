"""Submit a configured job to a skill runner.

The JSON configuration is the interface for scheduled skill jobs. It defines
an endpoint and arbitrary JSON payload; payload strings can use the runtime
placeholders documented in the example configuration.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

try:
    import fcntl
except ImportError:  # pragma: no cover - only used on Unix
    fcntl = None

if os.name == "nt":
    import msvcrt
else:  # pragma: no cover - only used on Windows
    msvcrt = None


PLACEHOLDER_PATTERN = re.compile(r"\{\{([a-z_]+)\}\}")
REPO_ROOT = Path(__file__).resolve().parents[2]


class UtcFormatter(logging.Formatter):
    converter = time.gmtime


class ConfigurationError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path, help="Path to the job JSON configuration")
    parser.add_argument("--dry-run", action="store_true", help="Print the expanded payload without submitting it")
    parser.add_argument(
        "--now-utc",
        help="Override the current time for verification, for example 2026-08-28T20:30:00Z",
    )
    return parser.parse_args()


def resolve_path(value: str | None, base: Path = REPO_ROOT) -> Path:
    if not value:
        return base
    path = Path(value)
    return path if path.is_absolute() else base / path


def load_config(path: Path) -> dict[str, Any]:
    try:
        with path.resolve().open(encoding="utf-8") as file:
            config = json.load(file)
    except (OSError, json.JSONDecodeError) as exc:
        raise ConfigurationError(f"Could not read config {path}: {exc}") from exc
    if not isinstance(config, dict):
        raise ConfigurationError("The job configuration must contain a JSON object")
    for required in ("runner_url", "endpoint", "payload"):
        if required not in config:
            raise ConfigurationError(f"Missing required config property: {required}")
    return config


def parse_now_utc(value: str | None) -> datetime:
    if not value:
        return datetime.now(timezone.utc)
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def get_localized_time(now_utc: datetime, timezone_name: str) -> datetime:
    if timezone_name in ("local", "system"):
        return now_utc.astimezone()
    try:
        return now_utc.astimezone(ZoneInfo(timezone_name))
    except ZoneInfoNotFoundError as exc:
        # Windows Python installations do not always include the IANA tzdata
        # package. The registration script requires a Sydney-local host, so
        # this fallback remains DST-aware for the standard configuration.
        if timezone_name == "Australia/Sydney":
            return now_utc.astimezone()
        raise ConfigurationError(
            f"Timezone data for '{timezone_name}' is unavailable; install tzdata or use the local timezone"
        ) from exc


def expand_payload(value: Any, placeholders: dict[str, str]) -> Any:
    if isinstance(value, dict):
        return {key: expand_payload(item, placeholders) for key, item in value.items()}
    if isinstance(value, list):
        return [expand_payload(item, placeholders) for item in value]
    if not isinstance(value, str):
        return value

    def replace(match: re.Match[str]) -> str:
        name = match.group(1)
        if name not in placeholders:
            raise ConfigurationError(f"Unknown payload placeholder: {{{{{name}}}}}")
        return placeholders[name]

    return PLACEHOLDER_PATTERN.sub(replace, value)


def read_dotenv(path: Path, name: str) -> str:
    if not path.exists():
        return ""
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return ""
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        if key.strip() == name:
            return value.strip().strip('"').strip("'")
    return ""


def configure_logging(log_directory: Path, filename_format: str) -> tuple[logging.Logger, Path]:
    log_directory.mkdir(parents=True, exist_ok=True)
    log_filename = datetime.now(timezone.utc).strftime(filename_format).replace("{pid}", str(os.getpid()))
    log_path = log_directory / log_filename
    logger = logging.getLogger("skill-runner-scheduler")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    formatter = UtcFormatter("[%(asctime)s] %(levelname)s %(message)s", datefmt="%Y-%m-%dT%H:%M:%SZ")
    file_handler = logging.FileHandler(log_path, encoding="utf-8")
    console_handler = logging.StreamHandler()
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    return logger, log_path


@contextmanager
def single_instance(lock_path: Path) -> Iterator[bool]:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_file = lock_path.open("a+")
    locked = False
    try:
        lock_file.seek(0)
        lock_file.write("0")
        lock_file.flush()
        lock_file.seek(0)
        if os.name == "nt":
            msvcrt.locking(lock_file.fileno(), msvcrt.LK_NBLCK, 1)
        else:  # pragma: no cover - scheduler runs on Windows
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        locked = True
        yield True
    except (OSError, IOError):
        yield False
    finally:
        if locked:
            try:
                if os.name == "nt":
                    lock_file.seek(0)
                    msvcrt.locking(lock_file.fileno(), msvcrt.LK_UNLCK, 1)
                else:  # pragma: no cover - scheduler runs on Windows
                    fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
            except OSError:
                pass
        lock_file.close()


def submit_job(config: dict[str, Any], payload: dict[str, Any], token: str) -> str:
    runner_url = str(config["runner_url"]).rstrip("/")
    endpoint = str(config["endpoint"])
    url = endpoint if endpoint.startswith("http") else f"{runner_url}/{endpoint.lstrip('/')}"
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    headers.update({str(key): str(value) for key, value in config.get("headers", {}).items()})
    headers["Authorization"] = f"Bearer {token}"
    request = Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
    timeout = int(config.get("http_timeout_seconds", 20))
    try:
        with urlopen(request, timeout=timeout) as response:
            result = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"skill runner request failed: {exc}") from exc
    if not isinstance(result, dict) or not result.get("job_id"):
        raise RuntimeError("skill runner response did not contain a job_id")
    return str(result["job_id"])


def run(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    log_directory = resolve_path(config.get("log_directory", "logs/skill-runner"))
    filename_format = str(config.get("log_filename_format", "scheduler-%Y%m%d-%H%M%S-{pid}.log"))
    logger, log_path = configure_logging(log_directory, filename_format)
    job_name = str(config.get("name", args.config.stem))
    logger.info("START job=%s pid=%s host=%s config=%s log_file=%s", job_name, os.getpid(), os.environ.get("COMPUTERNAME", ""), args.config, log_path)

    lock_path = resolve_path(config.get("lock_file"), log_directory) if config.get("lock_file") else log_directory / "scheduler.lock"
    with single_instance(lock_path) as acquired:
        if not acquired:
            logger.warning("SKIP another instance of job=%s is already running", job_name)
            logger.info("END job=%s status=skipped", job_name)
            return 0

        try:
            now_utc = parse_now_utc(args.now_utc)
            clock = config.get("current_time", {})
            timezone_name = str(clock.get("timezone", "local"))
            localized_now = get_localized_time(now_utc, timezone_name)
            current_format = str(clock.get("format", "%Y-%m-%d %H:%M:%S"))
            placeholders = {
                "current_time": localized_now.strftime(current_format),
                "current_date": localized_now.strftime("%Y-%m-%d"),
                "current_datetime": localized_now.isoformat(),
            }
            payload = expand_payload(config["payload"], placeholders)
            logger.info("RUN job=%s current_time=%s runner=%s", job_name, placeholders["current_time"], config["runner_url"])

            if args.dry_run:
                print(json.dumps(payload, separators=(",", ":")))
                logger.info("END job=%s status=dry-run", job_name)
                return 0

            token_name = str(config.get("token_env", "SKILL_RUNNER_API_TOKEN"))
            token = os.environ.get(token_name, "")
            if not token:
                token_path = resolve_path(config.get("token_dotenv", "backend/.env"))
                token = read_dotenv(token_path, token_name)
            if not token:
                raise ConfigurationError(f"{token_name} is not configured")

            logger.info("SUBMIT job=%s endpoint=%s", job_name, config["endpoint"])
            job_id = submit_job(config, payload, token)
            logger.info("SUCCESS job=%s job_id=%s", job_name, job_id)
            logger.info("END job=%s status=success", job_name)
            return 0
        except Exception as exc:  # noqa: BLE001 - log every scheduled failure
            logger.exception("ERROR job=%s: %s", job_name, exc)
            logger.info("END job=%s status=failed", job_name)
            return 3


def main() -> int:
    try:
        return run(parse_args())
    except Exception as exc:  # Covers config and logging failures before a logger exists.
        print(f"skill-runner scheduler failed: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
