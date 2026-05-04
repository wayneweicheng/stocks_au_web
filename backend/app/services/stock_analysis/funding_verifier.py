"""Verify funding facts by drilling into a bounded set of announcement sources."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

SKILL_ROOT = Path(r"C:\Repo\midas-touch\ASX-spec-analyzer")
SKILL_RAW_DRILLDOWN_SCRIPT = SKILL_ROOT / "scripts" / "raw_drilldown.py"

APPENDIX_5B_CASH_PATTERNS = [
    re.compile(r"(?is)4\.6\s+cash\s+and\s+cash\s+equivalents\s+at\s+end\s+of\s+period\s+([\d,]+(?:\.\d+)?)"),
    re.compile(r"(?is)5\.5\s+cash\s+and\s+cash\s+equivalents\s+at\s+end\s+of\s+quarter[^\d]*([\d,]+(?:\.\d+)?)"),
    re.compile(r"(?is)8\.4\s+cash\s+and\s+cash\s+equivalents\s+at\s+quarter\s+end[^\d]*([\d,]+(?:\.\d+)?)"),
]
APPENDIX_5B_BURN_PATTERNS = [
    re.compile(r"(?is)8\.3\s+total\s+relevant\s+outgoings[^\d-]*-?\s*([\d,]+(?:\.\d+)?)"),
    re.compile(r"(?is)1\.9\s+net\s+cash\s+from\s*/\s*used\s+in\s+operating\s+activities[^\d-]*-?\s*([\d,]+(?:\.\d+)?)"),
]
APPENDIX_5B_QUARTERS_PATTERN = re.compile(r"(?is)8\.7\s+estimated\s+quarters\s+of\s+funding\s+available[^\d]*([\d,]+(?:\.\d+)?)")
HALF_YEAR_CASH_PATTERN = re.compile(r"(?is)cash\s+and\s+cash\s+equivalents\s+[\d,]+\s+([\d,]+(?:\.\d+)?)")
RAISE_PATTERNS = [
    re.compile(r"(?is)raising\s+([\d,]+(?:\.\d+)?)\s*(million|m)?"),
    re.compile(r"(?is)\b([\d,]+(?:\.\d+)?)\s*(million|m)\b[^.]{0,80}share\s+purchase\s+plan"),
    re.compile(r"(?is)\b([\d,]+(?:\.\d+)?)\s*(million|m)\b[^.]{0,80}tranche\s+2"),
]


def _to_number(raw: str | None) -> float | None:
    if not raw:
        return None
    try:
        return float(str(raw).replace(",", ""))
    except ValueError:
        return None


def _to_millions(raw: str | None, suffix: str | None = None) -> float | None:
    value = _to_number(raw)
    if value is None:
        return None
    suffix_norm = (suffix or "").lower()
    if suffix_norm in {"m", "million"}:
        return value
    return value / 1000.0


def _load_drilldown_payload(text: str) -> Dict[str, Any]:
    return json.loads(text)


def _run_drilldown(run_dir: Path, announcement_id: str) -> Dict[str, Any] | None:
    command = [
        sys.executable,
        str(SKILL_RAW_DRILLDOWN_SCRIPT),
        "--run-dir",
        str(run_dir),
        "--announcement-id",
        str(announcement_id),
        "--fields",
        "AnnDateTime,AnnDescr,AnnURL,AnnContent",
        "--max-rows",
        "1",
        "--max-chars",
        "4000",
    ]
    completed = subprocess.run(
        command,
        cwd=str(SKILL_ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0 or not (completed.stdout or "").strip():
        return None
    try:
        payload = _load_drilldown_payload(completed.stdout)
    except json.JSONDecodeError:
        return None
    rows = payload.get("rows") or []
    if not rows:
        return None
    return rows[0]


def _matches_funding_tag(item: Dict[str, Any], tags: set[str]) -> bool:
    item_tags = set(item.get("tags") or [])
    category = item.get("category")
    title = str(item.get("title") or "").lower()
    return bool(item_tags & tags) or category in tags or any(tag in title for tag in tags)


def _pick_candidate_ids(announcement_compact: Dict[str, Any]) -> List[str]:
    material_events = announcement_compact.get("material_events") or []
    funding = announcement_compact.get("funding") or {}
    ids: List[str] = []

    source_id = funding.get("source_announcement_id")
    if source_id:
        ids.append(str(source_id))

    appendix_id = next(
        (
            item.get("announcement_id")
            for item in material_events
            if _matches_funding_tag(item, {"appendix_5b", "appendix_4c", "quarterly"})
        ),
        None,
    )
    if appendix_id and appendix_id not in ids:
        ids.append(str(appendix_id))

    raise_id = next(
        (
            item.get("announcement_id")
            for item in material_events
            if _matches_funding_tag(item, {"capital_raise", "placement", "share purchase", "spp", "tranche"})
        ),
        None,
    )
    if raise_id and raise_id not in ids:
        ids.append(str(raise_id))

    return ids[:3]


def _extract_appendix5b_metrics(content: str) -> Dict[str, Any]:
    cash = None
    for pattern in APPENDIX_5B_CASH_PATTERNS:
        match = pattern.search(content)
        if match:
            cash = _to_millions(match.group(1))
            if cash is not None:
                break

    burn = None
    for pattern in APPENDIX_5B_BURN_PATTERNS:
        match = pattern.search(content)
        if match:
            burn = _to_millions(match.group(1))
            if burn is not None:
                break

    quarters = None
    match = APPENDIX_5B_QUARTERS_PATTERN.search(content)
    if match:
        quarters = _to_number(match.group(1))

    return {
        "cash_balance_m": cash,
        "burn_m": burn,
        "runway_quarters": quarters,
    }


def _extract_half_year_cash(content: str) -> float | None:
    match = HALF_YEAR_CASH_PATTERN.search(content)
    if not match:
        return None
    return _to_number(match.group(1)) / 1_000_000.0


def _extract_raise_amounts(content: str) -> List[float]:
    amounts: List[float] = []
    for pattern in RAISE_PATTERNS:
        for match in pattern.finditer(content):
            amount = _to_millions(match.group(1), match.group(2) if match.lastindex and match.lastindex >= 2 else None)
            if amount is not None and amount not in amounts:
                amounts.append(amount)
    return amounts


def funding_looks_suspicious(announcement_compact: Dict[str, Any]) -> bool:
    funding = announcement_compact.get("funding") or {}
    latest_cash = funding.get("latest_cash_balance_m")
    runway = funding.get("estimated_runway_months")
    notes = funding.get("notes") or []
    source_title = str(funding.get("source_announcement_title") or "").lower()
    cash_candidates = funding.get("cash_candidates_m") or []
    return bool(
        notes
        or runway in (None, 0)
        or (isinstance(latest_cash, (int, float)) and latest_cash <= 10)
        or "half year report" in source_title
        or len(cash_candidates) >= 4
    )


def verify_funding(run_dir: str, announcement_compact: Dict[str, Any]) -> Dict[str, Any]:
    run_path = Path(run_dir)
    funding = announcement_compact.get("funding") or {}
    verification: Dict[str, Any] = {
        "generated_at": datetime.utcnow().isoformat(),
        "suspicious_compact_funding": funding_looks_suspicious(announcement_compact),
        "compact_funding_snapshot": funding,
        "drilldowns": [],
        "verified": False,
        "notes": [],
    }

    if not verification["suspicious_compact_funding"]:
        verification["verified"] = True
        verification["preferred_cash_balance_m"] = funding.get("latest_cash_balance_m")
        verification["preferred_burn_m"] = funding.get("latest_quarterly_burn_m")
        verification["preferred_runway_months"] = funding.get("estimated_runway_months")
        verification["confidence"] = "medium"
        return verification

    appendix_metrics: Dict[str, Any] = {}
    half_year_cash = None
    raise_amounts: List[Dict[str, Any]] = []
    for announcement_id in _pick_candidate_ids(announcement_compact):
        row = _run_drilldown(run_path, announcement_id)
        if not row:
            continue
        content = str(row.get("AnnContent") or "")
        title = str(row.get("AnnDescr") or "")
        lowered_title = title.lower()
        drilldown_entry = {
            "announcement_id": announcement_id,
            "title": title,
            "date": row.get("AnnDateTime"),
        }
        if "appendix 5b" in lowered_title or "quarterly" in lowered_title:
            appendix_metrics = _extract_appendix5b_metrics(content)
            drilldown_entry["appendix5b_metrics"] = appendix_metrics
        elif "half year report" in lowered_title or "interim financial report" in content.lower():
            half_year_cash = _extract_half_year_cash(content)
            drilldown_entry["half_year_cash_balance_m"] = half_year_cash
        raise_values = _extract_raise_amounts(content)
        if raise_values:
            drilldown_entry["raise_amounts_m"] = raise_values
            raise_amounts.append(
                {
                    "announcement_id": announcement_id,
                    "title": title,
                    "date": row.get("AnnDateTime"),
                    "amounts_m": raise_values,
                }
            )
        verification["drilldowns"].append(drilldown_entry)

    preferred_cash = appendix_metrics.get("cash_balance_m")
    preferred_burn = appendix_metrics.get("burn_m")
    preferred_runway_months = None
    if appendix_metrics.get("runway_quarters") is not None:
        preferred_runway_months = round(float(appendix_metrics["runway_quarters"]) * 3.0, 2)

    if preferred_cash is None:
        preferred_cash = funding.get("latest_cash_balance_m")
    if preferred_burn is None:
        preferred_burn = funding.get("latest_quarterly_burn_m")
    if preferred_runway_months is None:
        preferred_runway_months = funding.get("estimated_runway_months")

    verification.update(
        {
            "verified": preferred_cash is not None,
            "preferred_cash_balance_m": preferred_cash,
            "preferred_burn_m": preferred_burn,
            "preferred_runway_months": preferred_runway_months,
            "appendix5b_cash_balance_m": appendix_metrics.get("cash_balance_m"),
            "appendix5b_burn_m": appendix_metrics.get("burn_m"),
            "appendix5b_runway_quarters": appendix_metrics.get("runway_quarters"),
            "half_year_cash_balance_m": half_year_cash,
            "post_period_raise_events": raise_amounts,
            "confidence": "high" if appendix_metrics.get("cash_balance_m") is not None else "medium",
            "notes": [
                "Preferred funding evidence is derived from bounded announcement drill-downs.",
                "Appendix 5B / quarterly cash-flow evidence is preferred over generic financial reports.",
            ],
        }
    )

    output_path = run_path / "verified_funding.json"
    output_path.write_text(json.dumps(verification, indent=2), encoding="utf-8")
    verification["artifact_path"] = str(output_path)
    return verification
