from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any, Sequence


def _digest(payload: Any) -> str:
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def git_commit(repo_root: str | Path | None = None) -> str:
    try:
        completed = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=str(repo_root) if repo_root else None,
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return "unknown"
    return completed.stdout.strip() or "unknown"


def config_hash(parameters: dict[str, Any]) -> str:
    return _digest(parameters)


def data_hash(observations: Sequence[Any], bars: Sequence[Any]) -> str:
    observation_payload = [
        {
            "observation_date": item.observation_date.isoformat(),
            "bc_gex_delta": item.bc_gex_delta,
            "bp_gex_delta": item.bp_gex_delta,
            "sc_gex_delta": item.sc_gex_delta,
            "sp_gex_delta": item.sp_gex_delta,
            "close": item.close,
            "put_call_ratio": item.put_call_ratio,
            "close_change_pct": item.close_change_pct,
            "pcr_change_pct": item.pcr_change_pct,
            "signal_raw": item.signal_raw,
            "bc_gex": item.bc_gex,
            "bp_gex": item.bp_gex,
            "sc_gex": item.sc_gex,
            "sp_gex": item.sp_gex,
        }
        for item in sorted(observations, key=lambda value: value.observation_date)
    ]
    bar_payload = [
        {
            "timestamp": item.timestamp.isoformat(),
            "open": item.open,
            "high": item.high,
            "low": item.low,
            "close": item.close,
            "symbol": item.symbol,
        }
        for item in sorted(bars, key=lambda value: value.timestamp)
    ]
    return _digest({"observations": observation_payload, "bars": bar_payload})


def provenance(
    parameters: dict[str, Any],
    observations: Sequence[Any],
    bars: Sequence[Any],
    repo_root: str | Path | None = None,
) -> dict[str, str]:
    return {
        "git_commit": git_commit(repo_root),
        "config_hash": config_hash(parameters),
        "data_hash": data_hash(observations, bars),
    }
