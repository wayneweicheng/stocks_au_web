from __future__ import annotations

from collections import Counter
from datetime import date, datetime
from typing import Any, Dict, Iterable, Mapping, Sequence

from app.core.db import get_sql_model
from app.services.option_orders_service import get_option_chain, get_option_expirations


DEFAULT_ETFS = frozenset({"SPY", "QQQ", "IWM"})
MAX_SYMBOLS = 50


def normalize_symbols(value: str | Sequence[str]) -> list[str]:
    raw_values: Iterable[str]
    if isinstance(value, str):
        raw_values = value.replace(";", ",").split(",")
    else:
        raw_values = value
    symbols: list[str] = []
    for raw in raw_values:
        symbol = str(raw).strip().upper()
        if symbol.endswith(".US"):
            symbol = symbol[:-3]
        if not symbol or not symbol.replace("-", "").replace(".", "").isalnum():
            continue
        if symbol not in symbols:
            symbols.append(symbol)
    if not symbols:
        raise ValueError("At least one valid US symbol is required")
    if len(symbols) > MAX_SYMBOLS:
        raise ValueError(f"At most {MAX_SYMBOLS} symbols may be scanned at once")
    return symbols


def _safe_number(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if number == number else None


def _event_context(symbol: str, expiry_values: Sequence[str]) -> tuple[str, list[str], list[dict[str, Any]]]:
    if symbol in DEFAULT_ETFS:
        return "clear", [], []
    try:
        start_date = datetime.now().date().isoformat()
        end_date = max(str(value).replace("-", "")[:8] for value in expiry_values)
        end_date = f"{end_date[:4]}-{end_date[4:6]}-{end_date[6:]}"
        rows = get_sql_model().execute_read_query(
            """
            SELECT EventType, EventDate, EventEndDate, Status, Source, Notes
            FROM [Analysis].[VolatilitySelectiveEvent] WITH (NOLOCK)
            WHERE Symbol = ? AND EventDate >= ? AND EventDate <= ?
              AND Status <> 'CANCELLED'
            ORDER BY EventDate
            """,
            (symbol, start_date, end_date),
        ) or []
    except Exception:
        return "unknown", [], []
    events: list[dict[str, Any]] = []
    dates: list[str] = []
    for row in rows:
        event_date = row.get("EventDate")
        event_text = event_date.isoformat() if hasattr(event_date, "isoformat") else str(event_date or "")[:10]
        if not event_text:
            continue
        dates.append(event_text)
        events.append({
            "event_type": row.get("EventType"),
            "event_date": event_text,
            "event_end_date": row.get("EventEndDate").isoformat() if hasattr(row.get("EventEndDate"), "isoformat") else row.get("EventEndDate"),
            "status": row.get("Status"),
            "source": row.get("Source"),
            "notes": row.get("Notes"),
        })
    if any(str(item.get("status") or "").upper() == "UNKNOWN" for item in events):
        return "unknown", dates, events
    return ("blocked" if events else "unknown"), dates, events


def _history(symbol: str, limit: int = 140) -> list[dict[str, Any]]:
    rows = get_sql_model().execute_read_query(
        f"""
        SELECT TOP {int(limit)}
            ObservationDate, [Open], High, Low, [Close], Volume
        FROM StockDB_US.StockData.v_PriceHistory WITH (NOLOCK)
        WHERE ASXCode = convert(varchar(16), ?)
        ORDER BY ObservationDate DESC
        """,
        (f"{symbol}.US",),
    ) or []
    normalized: list[dict[str, Any]] = []
    for row in reversed(rows):
        observed = row.get("ObservationDate")
        if isinstance(observed, (date, datetime)):
            observed_text = observed.date().isoformat() if isinstance(observed, datetime) else observed.isoformat()
        else:
            observed_text = str(observed or "")[:10]
        close = _safe_number(row.get("Close"))
        if not observed_text or close is None or close <= 0:
            continue
        item: dict[str, Any] = {"date": observed_text, "close": close}
        for output_key, source_key in (("open", "Open"), ("high", "High"), ("low", "Low"), ("volume", "Volume")):
            number = _safe_number(row.get(source_key))
            if number is not None:
                item[output_key] = number
        normalized.append(item)
    return normalized


def select_expirations(payload: Mapping[str, Any], dte_min: int, dte_max: int, maximum: int = 4) -> list[str]:
    expirations = payload.get("expirations") if isinstance(payload, Mapping) else None
    if not isinstance(expirations, list):
        return []
    selected: list[tuple[int, str]] = []
    for item in expirations:
        if not isinstance(item, Mapping):
            continue
        expiry = str(item.get("expiry") or "").strip()
        try:
            dte = int(item.get("dte"))
        except (TypeError, ValueError):
            continue
        if dte_min <= dte <= dte_max and expiry:
            selected.append((dte, expiry))
    # Retain a spread across the requested window instead of taking only the nearest week.
    selected.sort()
    if len(selected) <= maximum:
        return [expiry for _, expiry in selected]
    indexes = sorted({round(index * (len(selected) - 1) / (maximum - 1)) for index in range(maximum)})
    return [selected[index][1] for index in indexes]


def _option_rows(chain: Mapping[str, Any]) -> list[dict[str, Any]]:
    normalized: list[dict[str, Any]] = []
    for row in chain.get("rows") or []:
        if not isinstance(row, Mapping):
            continue
        quote = row.get("quote") if isinstance(row.get("quote"), Mapping) else {}
        bid = _safe_number(quote.get("bid"))
        ask = _safe_number(quote.get("ask"))
        iv = _safe_number(quote.get("iv"))
        if bid is None or ask is None or iv is None:
            continue
        normalized.append(
            {
                "option_symbol": row.get("local_symbol") or row.get("option_symbol"),
                "expiry": row.get("expiry_date") or row.get("expiry"),
                "strike": row.get("strike"),
                "right": row.get("right", "P"),
                "bid": bid,
                "ask": ask,
                "iv": iv,
                "delta": quote.get("delta"),
                "gamma": quote.get("gamma"),
                "theta": quote.get("theta"),
                "vega": quote.get("vega"),
                "volume": quote.get("volume"),
                "open_interest": quote.get("open_interest"),
                "multiplier": 100,
                "quote_source": quote.get("source"),
                "observation_date": quote.get("observation_date"),
            }
        )
    return normalized


def build_underlying_snapshot(
    symbol: str,
    dte_min: int,
    dte_max: int,
    event_clear_symbols: set[str],
) -> dict[str, Any]:
    clear_symbols = set(event_clear_symbols or set())
    expirations_payload = get_option_expirations(symbol)
    expiry_values = select_expirations(expirations_payload, dte_min, dte_max)
    if not expiry_values:
        raise ValueError(f"{symbol}: no expirations in the requested DTE range")
    underlying_payload = expirations_payload.get("underlying") or {}
    spot = _safe_number(underlying_payload.get("reference_price"))
    options: list[dict[str, Any]] = []
    chain_sources: set[str] = set()
    for expiry in expiry_values:
        chain = get_option_chain(
            symbol=symbol,
            right="P",
            max_expiries=1,
            strike_window_pct=0.40,
            expiry=expiry,
        )
        if spot is None:
            spot = _safe_number((chain.get("underlying") or {}).get("reference_price"))
        options.extend(_option_rows(chain))
        if chain.get("chain_source"):
            chain_sources.add(str(chain["chain_source"]))
    history = _history(symbol)
    quote_dates = [
        str(row.get("observation_date") or "")[:10]
        for row in options
        if str(row.get("observation_date") or "")[:10]
    ]
    has_live_quotes = any(str(row.get("quote_source") or "").lower() == "live" for row in options)
    evidence_cutoff: str | None = None
    if quote_dates and not has_live_quotes:
        counts = Counter(quote_dates)
        evidence_cutoff = max(counts, key=lambda value: (counts[value], value))
        options = [row for row in options if str(row.get("observation_date") or "")[:10] == evidence_cutoff]
        history = [row for row in history if str(row.get("date") or "")[:10] <= evidence_cutoff]
        if history:
            # A delayed option snapshot must use its matching completed underlying close,
            # never the later IB spot observed while assembling the report.
            spot = _safe_number(history[-1].get("close"))
    if spot is None and history:
        spot = _safe_number(history[-1].get("close"))
    if spot is None:
        raise ValueError(f"{symbol}: underlying reference price is unavailable")
    if len(history) < 20:
        raise ValueError(f"{symbol}: fewer than 20 completed daily bars are available")
    if not options:
        raise ValueError(f"{symbol}: no valid put quotes are available")
    asset_type = "ETF" if symbol in DEFAULT_ETFS else "STOCK"
    event_status, event_dates, event_records = _event_context(symbol, expiry_values)
    if symbol in clear_symbols:
        event_status = "clear"
    return {
        "symbol": symbol,
        "asset_type": asset_type,
        "sector": "index_etf" if asset_type == "ETF" else "unclassified",
        "spot": spot,
        "event_status": event_status,
        "event_dates": event_dates,
        "price_history": history,
        "options": options,
        "source": {
            "price_history": "StockDB_US.StockData.v_PriceHistory",
            "option_chain": ",".join(sorted(chain_sources)) or "IBKR/database",
            "expirations": expiry_values,
            "event_records": event_records,
            "market_checked_at": (expirations_payload.get("market_status") or {}).get("checked_at"),
            "evidence_cutoff": evidence_cutoff,
        },
    }


def _discover_symbols(model: Any | None = None) -> list[str]:
    db = model or get_sql_model()
    rows = db.execute_read_query(
        """
        SELECT DISTINCT TOP 50 ASXCode
        FROM StockDB_US.StockData.v_OptionDelayedQuote_V2 WITH (NOLOCK)
        WHERE ObservationDate = (
            SELECT MAX(ObservationDate) FROM StockDB_US.StockData.v_OptionDelayedQuote_V2 WITH (NOLOCK)
        )
          AND PorC = 'P'
        ORDER BY ASXCode
        """,
        (),
    ) or []
    discovered: list[str] = []
    for row in rows:
        symbol = str(row.get("ASXCode") or "").strip().upper().removesuffix(".US")
        if not symbol or symbol.startswith("_") or symbol in {"SPX", "NDX", "RUT"}:
            continue
        if symbol not in discovered:
            discovered.append(symbol)
    if not discovered:
        raise ValueError("AUTO universe discovery returned no fresh optionable symbols")
    return discovered


def build_scan_snapshot(
    *,
    symbols: str | Sequence[str],
    account_equity: float,
    assignment_exposure: float,
    event_clear_symbols: str | Sequence[str],
    top_n: int,
    dte_min: int,
    dte_max: int,
    min_vol_edge: float,
    risk_budget_pct: float,
    max_assignment_exposure_pct: float,
) -> dict[str, Any]:
    if isinstance(symbols, str) and symbols.strip().upper() in {"AUTO", "ALL"}:
        normalized_symbols = _discover_symbols()
    else:
        normalized_symbols = normalize_symbols(symbols)
    has_event_clear_values = (
        bool(event_clear_symbols.strip())
        if isinstance(event_clear_symbols, str)
        else bool(event_clear_symbols)
    )
    clear_symbols = set(normalize_symbols(event_clear_symbols)) if has_event_clear_values else set()
    clear_symbols.update(symbol for symbol in normalized_symbols if symbol in DEFAULT_ETFS)
    underlyings = [
        build_underlying_snapshot(symbol, dte_min, dte_max, clear_symbols)
        for symbol in normalized_symbols
    ]
    evidence_dates = [
        str(item.get("source", {}).get("evidence_cutoff"))
        for item in underlyings
        if item.get("source", {}).get("evidence_cutoff")
    ]
    if evidence_dates and len(evidence_dates) != len(underlyings):
        raise ValueError("The scan returned mixed live and delayed option snapshots; retry with one consistent evidence cutoff")
    unique_evidence_dates = set(evidence_dates)
    if len(unique_evidence_dates) > 1:
        raise ValueError("Symbols do not share one option snapshot date; a point-in-time scan cannot mix evidence dates")
    market_checked_at = (
        evidence_dates[0]
        if evidence_dates
        else next(
            (
                str(item.get("source", {}).get("market_checked_at"))
                for item in underlyings
                if item.get("source", {}).get("market_checked_at")
            ),
            datetime.now().astimezone().isoformat(),
        )
    )
    return {
        "as_at": market_checked_at,
        "account_equity": float(account_equity),
        "portfolio": {"assignment_exposure": float(assignment_exposure)},
        "config": {
            "top_n": int(top_n),
            "dte_min": int(dte_min),
            "dte_max": int(dte_max),
            "min_vol_edge": float(min_vol_edge),
            "risk_budget_pct": float(risk_budget_pct),
            "max_assignment_exposure_pct": float(max_assignment_exposure_pct),
        },
        "underlyings": underlyings,
    }
