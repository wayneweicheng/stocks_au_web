"""Report-backed index-bottom timeline with cutoff-safe SPY/QQQ forward closes.

All source bar timestamps in StockDB_US.PriceHistoryTimeFrame are New York local
wall times. Never use a job's generation time to price a historical report.
"""
from __future__ import annotations

from bisect import bisect_right
from datetime import date, datetime, time, timedelta
import math
import re
from typing import Any, Mapping, Sequence
from zoneinfo import ZoneInfo

from app.spx_gex_strategy.calendar import USCashCalendar
from app.services.saved_price_levels_service import (
    _close_saved_price_levels_model, _execute_saved_price_levels_query, _open_saved_price_levels_model,
)

ET = ZoneInfo("America/New_York")
SYDNEY = ZoneInfo("Australia/Sydney")
HORIZONS = (1, 2, 3, 5, 10)
CALENDAR = USCashCalendar()


def parse_as_at(value: str | None) -> datetime | None:
    """Parse the requested analysis cutoff, not a generated/completed timestamp."""
    if not value:
        return None
    match = re.search(r"(20\d{2}-\d{2}-\d{2})[ T](\d{1,2}):(\d{2})(?::\d{2})?\s*(am|pm)?", value, re.I)
    if not match:
        return None
    timezone = SYDNEY if "sydney" in value.lower() else ET
    hour = int(match[2])
    meridiem = (match[4] or "").lower()
    if meridiem == "pm" and hour < 12:
        hour += 12
    elif meridiem == "am" and hour == 12:
        hour = 0
    return datetime.fromisoformat(f"{match[1]}T{hour:02}:{match[3]}").replace(tzinfo=timezone).astimezone(ET)


def report_as_at(label: str | None, content: str) -> datetime | None:
    for line in content.splitlines()[:35]:
        if re.search(r"\b(as[- ]at|requested (?:cutoff|analysis time)|historical cutoff)\b", line, re.I):
            parsed = parse_as_at(line)
            if parsed:
                return parsed
    return parse_as_at(label)


def _plain(value: str) -> str:
    return re.sub(r"[`*_#]", "", value).strip(" -–—\t\r\n").replace(" � ", " — ")


def parse_report_state(content: str) -> dict[str, Any]:
    """Extract the report's stated conclusion; never synthesize a new trading state."""
    section = re.search(r"(?im)^##\s+(?:(?:official|overall|executive)\s+)?state\b[^\n]*\n([\s\S]*?)(?=^##\s|\Z)", content)
    if not section:
        section = re.search(
            r"(?im)^##\s+(?:cutoff and state|timestamps and state|time and state|executive (?:assessment|conclusion)|core completed-cash state|determination|conclusion|final assessment)\b[^\n]*\n([\s\S]*?)(?=^##\s|\Z)",
            content,
        )
    block = section[1].strip() if section else content[:1800]
    plain = re.sub(r"[`*_#]", "", block)
    # A core statement wins over a separate SPY- or QQQ-only verdict.
    patterns = (
        r"(?im)^\s*(?:[->]\s*)?(?:official\s+)?core\s+state\s*:\s*([^\n]+)",
        r"(?im)^\s*(?:[->]\s*)?(?:official(?:\s+completed-cash|\s+model)?|combined|overall|latest-usable|current)?\s*state\s*:\s*([^\n]+)",
        r"(?im)^\s*[->]\s*overall\s+assessment\s*:\s*([^\n]+)",
    )
    state = ""
    for pattern in patterns:
        found = re.search(pattern, plain)
        if found:
            state = _plain(found[0]).removeprefix("- ").removeprefix("> ")
            break
    if not state:
        combined = re.search(r"(?im)^\|\s*(?:combined assessment|overall)\s*\|\s*([^|]+)", block)
        if combined:
            state = f"Combined assessment: {_plain(combined[1])}"
    if not state:
        # Some older reports put the official decision above the first H2.
        opening = re.sub(r"[`*_#]", "", content[:1800])
        opening_state = re.search(r"(?im)^\s*(?:[->]\s*)?(?:official\s+)?(?:core\s+|completed-cash\s+)?state\s*:\s*([^\n]+)", opening)
        if opening_state:
            state = _plain(opening_state[0])
    if not state:
        table_states = {}
        for row in block.splitlines():
            cells = [cell.strip() for cell in row.split("|")]
            if len(cells) >= 4 and any(name in cells[1].upper() for name in ("SPY", "QQQ", "S&P 500", "NASDAQ-100")):
                symbol = "SPY" if "SPY" in cells[1].upper() or "S&P 500" in cells[1].upper() else "QQQ"
                if re.search(r"(?i)(no setup|early watch|oversold convergence|provisional reversal|confirmed reversal|failed/renewed pressure)", cells[2]):
                    table_states[symbol] = _plain(cells[2])
        if len(table_states) == 2:
            state = f"SPY: {table_states['SPY']}; QQQ: {table_states['QQQ']}"
    if not state:
        for line in block.splitlines():
            candidate = _plain(line)
            if not candidate or candidate.startswith(("|", "Requested", "Latest usable", "Data through", "Equivalent cutoff")):
                continue
            if re.search(r"(?i)(no setup|early watch|oversold convergence|provisional reversal|confirmed reversal|failed/renewed pressure)", candidate):
                state = candidate
                break
    if not state:
        state = "State not explicitly identified — review report"
    score_text = re.sub(r"[`*_]", "", content)
    score_match = re.search(r"(?i)\braw\s+confidence(?:\s+score)?\s*:\s*(\d{1,3})\s*/\s*100", score_text)
    if not score_match:
        score_match = re.search(r"(?i)\braw\s+confidence\s+is\s+(\d{1,3})\s*/\s*100", score_text)
    if not score_match:
        score_match = re.search(r"(?im)^\|\s*(?:raw confidence(?: score)?|raw score|total)\s*\|(?:\s*\|)?\s*(\d{1,3})\s*/\s*100", score_text)
    if not score_match:
        score_match = re.search(r"(?i)\braw\s+score\s+(\d{1,3})\s*/\s*100", score_text)
    if not score_match:
        score_match = re.search(r"(?im)^###\s+(?:raw score|raw confidence score)\s*\n\s*(\d{1,3})\s*/\s*100", score_text)
    if not score_match:
        score_match = re.search(r"(?i)\bconfidence\s+score\s*:\s*(\d{1,3})\s*/\s*100", score_text)
    score = int(score_match[1]) if score_match else None
    # Keep the report's own explanation and evidence wording, including caveats.
    description = block.replace(" � ", " — ")
    if len(description) > 8000:
        description = description[:8000] + "\n[Read the full report for the remaining detail.]"
    if score is not None and not re.search(r"\b\d{1,3}/100\b", description):
        description += f"\n\nRaw confidence score: {score}/100 (report scorecard)"
    if not re.search("Evidence completeness", description, re.I):
        line = re.search(r"(?im)^.*Evidence completeness[^\n]*$", content)
        if line:
            description += "\n\n" + line[0].strip()
    return {"state": state, "description": description, "score": score}


def target_sessions(as_at: datetime) -> dict[int, date]:
    # D1 is the *next* session after the as-at calendar date even for premarket.
    first = CALENDAR.next_session(as_at.astimezone(ET).date())
    return {horizon: CALENDAR.session_offset(first, horizon - 1) for horizon in HORIZONS}


def _bars_by_symbol(rows: Sequence[Mapping[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = {"SPY": [], "QQQ": []}
    for row in rows:
        symbol = str(row.get("ASXCode") or "").upper().removesuffix(".US")
        frame = str(row.get("TimeFrame") or "").upper()
        if symbol not in result or frame not in {"5M", "5MIN", "30M"}:
            continue
        stamp = row.get("TimeIntervalStart")
        if isinstance(stamp, str):
            try:
                stamp = datetime.fromisoformat(stamp)
            except ValueError:
                continue
        if not isinstance(stamp, datetime):
            continue
        stamp = stamp.replace(tzinfo=ET) if stamp.tzinfo is None else stamp.astimezone(ET)
        try:
            close = float(row.get("Close"))
        except (ValueError, TypeError):
            continue
        if not math.isfinite(close) or close <= 0:
            continue
        duration = timedelta(minutes=30 if frame == "30M" else 5)
        result[symbol].append({"end": stamp + duration, "start": stamp, "price": close, "timeframe": "30M" if frame == "30M" else "5M"})
    for bars in result.values():
        bars.sort(key=lambda bar: (bar["end"], bar["timeframe"] == "5M"))
    return result


def _snapshot(bar: Mapping[str, Any] | None) -> dict[str, Any] | None:
    if bar is None:
        return None
    return {"price": bar["price"], "timeframe": bar["timeframe"], "bar_end_et": bar["end"].isoformat()}


def calculate_returns(as_at: datetime, rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    sessions = target_sessions(as_at)
    bars_by_symbol = _bars_by_symbol(rows)
    result: dict[str, Any] = {}
    for symbol, bars in bars_by_symbol.items():
        ends = [bar["end"] for bar in bars]
        index = bisect_right(ends, as_at.astimezone(ET)) - 1
        base_bar = bars[index] if index >= 0 else None
        base = _snapshot(base_bar)
        changes = {}
        for horizon, target_date in sessions.items():
            close_et = CALENDAR.cash_close(target_date)
            # Require a candle ending exactly at the exchange close; do not
            # shift a missing Dn price to an adjacent session or earlier bar.
            session_bar = next((bar for bar in reversed(bars)
                if bar["end"] == close_et and bar["start"].date() == target_date
                and bar["start"].time() >= time(9, 30)), None)
            snapshot = _snapshot(session_bar)
            pct = round((session_bar["price"] / base_bar["price"] - 1) * 100, 2) if session_bar and base_bar else None
            changes[str(horizon)] = {"date": target_date.isoformat(), "close": snapshot, "percent": pct}
        result[symbol] = {"base": base, "returns": changes}
    return result


def load_price_rows(as_of_values: Sequence[datetime]) -> list[dict[str, Any]]:
    if not as_of_values:
        return []
    start = min(as_of_values).astimezone(ET) - timedelta(days=10)
    last_target = max(target_sessions(value)[10] for value in as_of_values)
    end = datetime.combine(last_target + timedelta(days=1), datetime.min.time())
    model = _open_saved_price_levels_model()
    try:
        return _execute_saved_price_levels_query(model, """
            SELECT ASXCode, TimeFrame, TimeIntervalStart, [Close]
            FROM StockDB_US.StockData.PriceHistoryTimeFrame WITH (NOLOCK)
            WHERE TimeFrame IN (CONVERT(varchar(10), ?), CONVERT(varchar(10), ?), CONVERT(varchar(10), ?))
              AND ASXCode IN (CONVERT(varchar(10), ?), CONVERT(varchar(10), ?))
              AND TimeIntervalStart >= ? AND TimeIntervalStart < ?
            ORDER BY TimeIntervalStart ASC
        """, ("5M", "5min", "30M", "SPY.US", "QQQ.US", start.replace(tzinfo=None), end))
    finally:
        _close_saved_price_levels_model(model)
