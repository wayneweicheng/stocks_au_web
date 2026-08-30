"""Populate Analysis.OptionTradeSideInference from SQL Server quotes.

The SQL OUTER APPLY implementation is intentionally retained as a database
reference, but this batch implementation is the preferred backfill path. It
loads one observation date at a time and performs quote matching in memory,
avoiding a large repeated nested-loop join against OptionBidAsk.
"""
from __future__ import annotations

import argparse
import bisect
import os
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

import pyodbc


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / "backend" / ".env"
QUOTE_CHUNK_SIZE = 300
INSERT_BATCH_SIZE = 2000


def load_env() -> None:
    if not ENV_PATH.exists():
        return
    for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key.strip(), value)


def connection() -> pyodbc.Connection:
    driver = os.getenv("sqlserver_odbc_driver", os.getenv("SQLSERVER_ODBC_DRIVER", "ODBC Driver 18 for SQL Server"))
    host = os.getenv("SQL_SERVER_HOST", os.getenv("sqlserver_server"))
    port = os.getenv("SQL_SERVER_PORT", os.getenv("sqlserver_port", "1433"))
    user = os.getenv("SQL_SERVER_USER", os.getenv("sqlserver_username"))
    password = os.getenv("SQL_SERVER_PASSWORD", os.getenv("sqlserver_password"))
    if not all((host, user, password)):
        raise RuntimeError("SQL Server connection settings are incomplete")
    cs = (
        f"DRIVER={{{driver}}};SERVER={host},{port};DATABASE=StockDB_US;"
        f"UID={user};PWD={password};Encrypt=yes;TrustServerCertificate=yes;"
    )
    cn = pyodbc.connect(cs, timeout=20)
    cn.timeout = 300
    return cn


def parse_date(value: str) -> date:
    return date.fromisoformat(value)


def daterange(start: date, end: date) -> Iterable[date]:
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


def fetch_trades(cur: pyodbc.Cursor, asx_code: str, observation_date: date, minimum_value: float) -> List[Dict[str, Any]]:
    cur.execute(
        """
        SELECT OptionTradeID, ASXCode, ObservationDateLocal, ExpiryDate,
               OptionSymbol, SaleTime, Strike, PorC, Price, Size,
               BuySellIndicator
        FROM StockData.OptionTrade
        WHERE ASXCode = ?
          AND ObservationDateLocal = ?
          AND ExpiryDate >= ObservationDateLocal
          AND ExpiryDate <= DATEADD(day, 180, ObservationDateLocal)
          AND CONVERT(float, ISNULL(Price, 0)) * CONVERT(float, ISNULL(Size, 0)) * 100.0 >= ?
        """,
        asx_code,
        observation_date,
        minimum_value,
    )
    columns = [column[0] for column in cur.description]
    return [dict(zip(columns, row)) for row in cur.fetchall()]


def fetch_quotes(
    cur: pyodbc.Cursor,
    asx_code: str,
    observation_date: date,
    symbols: Sequence[str],
) -> Dict[str, List[Tuple[datetime, int, Optional[float], Optional[float]]]]:
    quotes: Dict[str, List[Tuple[datetime, int, Optional[float], Optional[float]]]] = defaultdict(list)
    for offset in range(0, len(symbols), QUOTE_CHUNK_SIZE):
        chunk = list(symbols[offset : offset + QUOTE_CHUNK_SIZE])
        placeholders = ",".join("?" for _ in chunk)
        cur.execute(
            f"""
            SELECT OptionSymbol, ObservationTime, OptionBidAskID, PriceBid, PriceAsk
            FROM StockData.OptionBidAsk
            WHERE ASXCode = ?
              AND ObservationDateLocal = ?
              AND OptionSymbol IN ({placeholders})
              AND ObservationTime IS NOT NULL
            ORDER BY OptionSymbol, ObservationTime, OptionBidAskID
            """,
            asx_code,
            observation_date,
            *chunk,
        )
        for symbol, quote_time, quote_id, bid, ask in cur.fetchall():
            quotes[str(symbol)].append(
                (quote_time, int(quote_id), float(bid) if bid is not None else None, float(ask) if ask is not None else None)
            )
    return quotes


def nearest_quote(
    quotes: List[Tuple[datetime, int, Optional[float], Optional[float]]],
    sale_time: Optional[datetime],
    max_age_seconds: int,
) -> Optional[Tuple[datetime, float, float, int]]:
    if not quotes or sale_time is None:
        return None
    times = [item[0] for item in quotes]
    position = bisect.bisect_left(times, sale_time)
    candidates = []
    if position < len(quotes):
        candidates.append(quotes[position])
    if position > 0:
        candidates.append(quotes[position - 1])
    if not candidates:
        return None
    selected = min(candidates, key=lambda item: (abs((item[0] - sale_time).total_seconds()), -item[1]))
    quote_time, _, bid, ask = selected
    age = int(abs((quote_time - sale_time).total_seconds()))
    if age > max_age_seconds or bid is None or ask is None or ask <= bid:
        return None
    return quote_time, bid, ask, age


def classify(
    trade: Dict[str, Any],
    quote: Optional[Tuple[datetime, float, float, int]],
) -> Tuple[Optional[str], str, float, Optional[float], Optional[datetime], Optional[float], Optional[float], Optional[int], str]:
    source = str(trade.get("BuySellIndicator") or "").upper()
    if source not in {"B", "S"}:
        source = ""
    price = float(trade["Price"]) if trade.get("Price") is not None else None

    if quote is None:
        return (source or None, "source_indicator" if source else "no_quote", 0.9 if source else 0.0, None, None, None, None, None, "missing")

    quote_time, bid, ask, age = quote
    position = None if price is None else (price - bid) * 100.0 / (ask - bid)
    if source:
        return source, "source_indicator", 0.9, position, quote_time, bid, ask, age, "source"
    if price is None:
        return None, "quote_mid_unknown", 0.0, position, quote_time, bid, ask, age, "mid"
    if price >= ask:
        return "B", "quote_touch", 0.95, position, quote_time, bid, ask, age, "touch"
    if price <= bid:
        return "S", "quote_touch", 0.95, position, quote_time, bid, ask, age, "touch"
    if position is not None and position >= 75.0:
        return "B", "quote_edge", 0.75, position, quote_time, bid, ask, age, "edge"
    if position is not None and position <= 25.0:
        return "S", "quote_edge", 0.75, position, quote_time, bid, ask, age, "edge"
    return None, "quote_mid_unknown", 0.25, position, quote_time, bid, ask, age, "mid"


def make_rows(
    stock_code: str,
    trades: Sequence[Dict[str, Any]],
    quotes: Dict[str, List[Tuple[datetime, int, Optional[float], Optional[float]]]],
    minimum_value: float,
    max_age_seconds: int,
) -> Tuple[List[Tuple[Any, ...]], Dict[str, int]]:
    rows: List[Tuple[Any, ...]] = []
    stats = defaultdict(int)
    for trade in trades:
        inferred, method, confidence, position, quote_time, bid, ask, age, quality = classify(
            trade, nearest_quote(quotes.get(str(trade["OptionSymbol"]), []), trade.get("SaleTime"), max_age_seconds)
        )
        stats[method] += 1
        rows.append(
            (
                trade["OptionTradeID"], stock_code, trade["ASXCode"], trade["ObservationDateLocal"],
                trade["ExpiryDate"], trade["OptionSymbol"], trade["SaleTime"], trade["Strike"],
                trade["PorC"], trade["Price"], trade["Size"],
                (float(trade["Price"]) if trade.get("Price") is not None else 0.0)
                * (float(trade["Size"]) if trade.get("Size") is not None else 0.0) * 100.0,
                trade.get("BuySellIndicator"), inferred, method, confidence,
                quote_time, bid, ask, age, position, quality, minimum_value,
            )
        )
    return rows, dict(stats)


def insert_rows(cur: pyodbc.Cursor, rows: Sequence[Tuple[Any, ...]]) -> None:
    sql = """
    INSERT INTO Analysis.OptionTradeSideInference
    (
        OptionTradeID, StockCode, ASXCode, ObservationDate, ExpiryDate,
        OptionSymbol, SaleTime, Strike, PorC, TradePrice, TradeSize, TradeValue,
        SourceBuySellIndicator, InferredBuySellIndicator, ClassificationMethod,
        InferenceConfidence, QuoteTime, QuoteBid, QuoteAsk, QuoteAgeSeconds,
        QuotePositionPct, QuoteQuality, MinimumTradeValue
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """
    for offset in range(0, len(rows), INSERT_BATCH_SIZE):
        cur.executemany(sql, rows[offset : offset + INSERT_BATCH_SIZE])


def process(args: argparse.Namespace) -> None:
    stock_code = args.stock_code.upper().removesuffix(".US")
    asx_code = (args.asx_code or f"{stock_code}.US").upper()
    cn = connection()
    cur = cn.cursor()
    totals = defaultdict(int)
    try:
        for observation_date in daterange(args.start_date, args.end_date):
            trades = fetch_trades(cur, asx_code, observation_date, args.minimum_trade_value)
            if not trades:
                print(f"{observation_date}: no eligible trades")
                continue
            symbols = sorted({str(trade["OptionSymbol"]) for trade in trades})
            quotes = fetch_quotes(cur, asx_code, observation_date, symbols)
            rows, stats = make_rows(stock_code, trades, quotes, args.minimum_trade_value, args.max_quote_age_seconds)
            cur.execute(
                "DELETE FROM Analysis.OptionTradeSideInference WHERE StockCode = ? AND ObservationDate = ?",
                stock_code,
                observation_date,
            )
            insert_rows(cur, rows)
            cn.commit()
            for key, value in stats.items():
                totals[key] += value
            print(f"{observation_date}: trades={len(trades)} symbols={len(symbols)} quotes={sum(map(len, quotes.values()))} classified={sum(v for k,v in stats.items() if k != 'no_quote' and k != 'quote_mid_unknown')} methods={stats}")
    finally:
        cur.close()
        cn.close()
    print(f"TOTAL: {dict(totals)}")


def main() -> None:
    load_env()
    parser = argparse.ArgumentParser()
    parser.add_argument("--stock-code", default="QQQ")
    parser.add_argument("--asx-code")
    parser.add_argument("--start-date", type=parse_date, required=True)
    parser.add_argument("--end-date", type=parse_date, required=True)
    parser.add_argument("--minimum-trade-value", type=float, default=20000.0)
    parser.add_argument("--max-quote-age-seconds", type=int, default=10)
    args = parser.parse_args()
    process(args)


if __name__ == "__main__":
    main()
