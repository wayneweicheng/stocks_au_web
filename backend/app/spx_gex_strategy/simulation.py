from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Iterable, Sequence

from .models import Direction, MarketBar


@dataclass
class FirstTouchResult:
    exit_time: datetime | None
    exit_price: float | None
    exit_reason: str | None
    mfe_pct: float
    mae_pct: float
    bars_held: int
    ambiguous: bool = False


def _bars_from(bars: Iterable[MarketBar], start: datetime, end: datetime | None = None) -> list[MarketBar]:
    return [
        bar
        for bar in sorted(bars, key=lambda item: item.timestamp)
        if bar.timestamp >= start and (end is None or bar.timestamp <= end)
    ]


def first_touch(
    entry: float,
    side: Direction,
    tp: float | None,
    sl: float | None,
    bars: Sequence[MarketBar],
    time_exit: datetime | None = None,
) -> FirstTouchResult:
    """Simulate first touch with gap-aware fills and conservative ambiguity."""
    if entry <= 0:
        raise ValueError("entry must be positive")
    if side == Direction.SHORT:
        favorable = lambda bar: (entry - bar.low) / entry
        adverse = lambda bar: (bar.high - entry) / entry
    else:
        favorable = lambda bar: (bar.high - entry) / entry
        adverse = lambda bar: (entry - bar.low) / entry

    max_favorable = 0.0
    max_adverse = 0.0
    for index, bar in enumerate(bars):
        max_favorable = max(max_favorable, favorable(bar))
        max_adverse = max(max_adverse, adverse(bar))
        if side == Direction.SHORT:
            gap_tp = tp is not None and bar.open <= tp
            gap_sl = sl is not None and bar.open >= sl
            hit_tp = tp is not None and bar.low <= tp
            hit_sl = sl is not None and bar.high >= sl
        else:
            gap_tp = tp is not None and bar.open >= tp
            gap_sl = sl is not None and bar.open <= sl
            hit_tp = tp is not None and bar.high >= tp
            hit_sl = sl is not None and bar.low <= sl

        if gap_sl or gap_tp:
            if gap_sl:
                return FirstTouchResult(bar.timestamp, bar.open, "SL_HIT", max_favorable, max_adverse, index + 1)
            return FirstTouchResult(bar.timestamp, bar.open, "TP_HIT", max_favorable, max_adverse, index + 1)
        if hit_sl and hit_tp:
            # The PRD explicitly chooses the conservative stop-first fill.
            return FirstTouchResult(
                bar.timestamp, sl, "SL_HIT", max_favorable, max_adverse, index + 1, ambiguous=True
            )
        if hit_sl:
            return FirstTouchResult(bar.timestamp, sl, "SL_HIT", max_favorable, max_adverse, index + 1)
        if hit_tp:
            return FirstTouchResult(bar.timestamp, tp, "TP_HIT", max_favorable, max_adverse, index + 1)

    if time_exit is not None and bars:
        exit_date = time_exit.astimezone(time_exit.tzinfo).date()
        eligible = [
            bar
            for bar in bars
            if bar.timestamp < time_exit
            and bar.timestamp.astimezone(time_exit.tzinfo).date() == exit_date
        ]
        if eligible:
            bar = eligible[-1]
            return FirstTouchResult(
                bar.timestamp,
                bar.close,
                "TIME_EXIT",
                max_favorable,
                max_adverse,
                len(eligible),
            )
    return FirstTouchResult(None, None, None, max_favorable, max_adverse, len(bars))


def _bar_exact(bars: Sequence[MarketBar], timestamp: datetime) -> MarketBar | None:
    return next((bar for bar in sorted(bars, key=lambda item: item.timestamp) if bar.timestamp == timestamp), None)


def _cash_close_bar(bars: Sequence[MarketBar], cash_close: datetime) -> MarketBar | None:
    # A 30-minute bar timestamp identifies the interval start.  The bar
    # beginning at 16:00 ends after the cash close, so the last bar ending at
    # the close begins strictly before it.  Restricting to the cash-close
    # session also prevents an incomplete D5 from silently using an earlier
    # day's bar.
    close_date = cash_close.astimezone(cash_close.tzinfo).date()
    eligible = [
        bar
        for bar in bars
        if bar.timestamp.astimezone(cash_close.tzinfo).date() == close_date
        and bar.timestamp < cash_close
    ]
    return sorted(eligible, key=lambda item: item.timestamp)[-1] if eligible else None


def simulate_reversal_green(
    reference_time: datetime,
    reference_price: float,
    dip_pct: float,
    dip_expiry: datetime,
    fallback_time: datetime,
    cash_close: datetime,
    bars: Sequence[MarketBar],
) -> dict:
    if reference_price <= 0:
        raise ValueError("reference_price must be positive")
    dip_price = reference_price * (1.0 - dip_pct)
    window = [
        bar
        for bar in _bars_from(bars, reference_time, dip_expiry)
        if bar.timestamp < dip_expiry
    ]
    fill_price = None
    fill_time = None
    for bar in window:
        if bar.open <= dip_price:
            fill_price, fill_time = bar.open, bar.timestamp
            break
        if bar.low <= dip_price:
            fill_price, fill_time = dip_price, bar.timestamp
            break

    entry_type = "DIP_LIMIT"
    if fill_price is None:
        fallback_bar = _bar_exact(bars, fallback_time)
        if fallback_bar is None:
            return {"status": "DATA_ERROR", "reason": "MISSING_D3_FALLBACK_BAR"}
        fill_price, fill_time, entry_type = fallback_bar.open, fallback_bar.timestamp, "D3_FALLBACK"

    exit_bar = _cash_close_bar(bars, cash_close)
    if exit_bar is None or exit_bar.timestamp < fill_time:
        return {"status": "DATA_ERROR", "reason": "MISSING_D5_CASH_CLOSE_BAR"}
    return {
        "status": "CLOSED",
        "entry_price": fill_price,
        "entry_time": fill_time,
        "entry_type": entry_type,
        "exit_price": exit_bar.close,
        "exit_time": exit_bar.timestamp,
        "exit_reason": "TIME_EXIT",
        "return_pct": exit_bar.close / fill_price - 1.0,
        "bars_held": len(_bars_from(bars, fill_time, exit_bar.timestamp)),
        "ambiguous": False,
    }


def simulate_normal_green(
    entry_time: datetime,
    entry_price: float,
    tp_pct: float,
    cash_close: datetime,
    bars: Sequence[MarketBar],
) -> dict:
    eligible = [
        bar
        for bar in _bars_from(bars, entry_time, cash_close)
        if bar.timestamp < cash_close
    ]
    result = first_touch(
        entry=entry_price,
        side=Direction.LONG,
        tp=entry_price * (1.0 + tp_pct),
        sl=None,
        bars=eligible,
        time_exit=cash_close,
    )
    if result.exit_price is None:
        return {"status": "DATA_ERROR", "reason": "MISSING_NORMAL_GREEN_EXIT"}
    return {
        "status": "CLOSED",
        "entry_price": entry_price,
        "entry_time": entry_time,
        "entry_type": "D3_MARKET",
        "exit_price": result.exit_price,
        "exit_time": result.exit_time,
        "exit_reason": result.exit_reason,
        "return_pct": result.exit_price / entry_price - 1.0,
        "mfe_pct": result.mfe_pct,
        "mae_pct": result.mae_pct,
        "bars_held": result.bars_held,
        "ambiguous": result.ambiguous,
    }
