from __future__ import annotations

import argparse
import json
import logging
import math
import os
import random
import sys
from datetime import date, datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

from dotenv import load_dotenv
from ib_insync import IB, Index, Stock

SCRIPT_DIR = Path(__file__).resolve().parent
LEGACY_ROOT = SCRIPT_DIR if (SCRIPT_DIR / "GetPriceHistory_US.py").exists() else Path(
    r"C:\Development\Repo\pythonexamples\IBAPIStrategies"
)
sys.path.append(str(LEGACY_ROOT.parent / "Common"))

from SQLServerHelper.SQLServerHelper import SQLServerModel

load_dotenv(LEGACY_ROOT / ".env")

IB_SERVER = os.getenv("IB_SERVER", "127.0.0.1")
IB_PORT = int(os.getenv("PORT_NUMBER", "7497"))
MARKET_DATA_TYPE = int(os.getenv("MARKET_DATA_TYPE", "1"))
GENERIC_TICKS = "100,101,104,105,106,165,236,258,456"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
logger = logging.getLogger("GetMarketSnapshot_US")


def finite(value: Any) -> Optional[float]:
    try:
        result = float(value)
    except (TypeError, ValueError):
        return None
    return result if math.isfinite(result) else None


def integer(value: Any) -> Optional[int]:
    result = finite(value)
    return int(result) if result is not None else None


def ratio(numerator: Any, denominator: Any) -> Optional[float]:
    top = finite(numerator)
    bottom = finite(denominator)
    return top / bottom if top is not None and bottom not in (None, 0) else None


def first_value(source: Any, *names: str) -> Optional[float]:
    for name in names:
        value = finite(getattr(source, name, None))
        if value is not None:
            return value
    return None


def object_dict(value: Any) -> Dict[str, Any]:
    if value is None:
        return {}
    raw = vars(value) if hasattr(value, "__dict__") else {}
    result: Dict[str, Any] = {}
    for key, item in raw.items():
        if isinstance(item, (date, datetime)):
            result[key] = item.isoformat()
        elif isinstance(item, (str, bool, int)) or item is None:
            result[key] = item
        else:
            number = finite(item)
            if number is not None:
                result[key] = number
    return result


def asx_code(stock_code: str) -> str:
    code = stock_code.strip().upper()
    return code if code.endswith(".US") else f"{code}.US"


def contract_for(stock_code: str):
    symbol = stock_code.strip().upper().removesuffix(".US")
    if symbol in {"_VIX", "VIX"}:
        return Index("VIX", "CBOE", "USD")
    if symbol in {"SPX", "SPXW", "_SPX"}:
        return Index("SPX", "CBOE", "USD")
    return Stock(symbol, "SMART", "USD")


class Collector:
    def __init__(self) -> None:
        self.ib = IB()
        self.db = SQLServerModel(database="StockDB_US")

    def connect(self) -> None:
        client_id = random.randint(1000, 9999)
        self.ib.connect(IB_SERVER, IB_PORT, clientId=client_id, timeout=10)
        self.ib.reqMarketDataType(MARKET_DATA_TYPE)
        logger.info("Connected to IB %s:%s with client id %s", IB_SERVER, IB_PORT, client_id)

    def universe(self, collection_type: str, limit: Optional[int]) -> List[Dict[str, Any]]:
        return self.db.execute_read_usp(
            """
            exec StockData.usp_GetDailyMarketSnapshotUniverse
                @pvchCollectionType = ?,
                @pintLimit = ?
            """,
            (collection_type, limit),
        )

    def upsert_volatility_rows(self, rows: List[Dict[str, Any]]) -> None:
        if rows:
            self.db.execute_update_usp(
                "exec StockData.usp_UpsertUnderlyingVolatilityHistoryBatch @pnvchRows = ?",
                (json.dumps(rows, allow_nan=False),),
            )

    def backfill_symbol(self, row: Dict[str, Any], include_hv: bool) -> None:
        code = str(row["ASXCode"])
        contract = contract_for(str(row["StockCode"]))
        qualified = self.ib.qualifyContracts(contract)
        if not qualified:
            raise RuntimeError("Contract could not be qualified")
        contract = qualified[0]

        collected: Dict[str, Dict[str, Any]] = {}
        requests = [("OPTION_IMPLIED_VOLATILITY", "iv")]
        if include_hv:
            requests.append(("HISTORICAL_VOLATILITY", "hv"))

        for what_to_show, prefix in requests:
            bars = self.ib.reqHistoricalData(
                contract,
                endDateTime="",
                durationStr="1 Y",
                barSizeSetting="1 day",
                whatToShow=what_to_show,
                useRTH=True,
                formatDate=1,
                timeout=60,
            )
            for bar in bars:
                observation_date = bar.date.date() if isinstance(bar.date, datetime) else bar.date
                key = observation_date.isoformat()
                target = collected.setdefault(
                    key,
                    {
                        "asx_code": code,
                        "observation_date": key,
                        "source": "IBKR_HISTORICAL",
                    },
                )
                target[f"{prefix}_open"] = finite(bar.open)
                target[f"{prefix}_high"] = finite(bar.high)
                target[f"{prefix}_low"] = finite(bar.low)
                target[f"{prefix}_close"] = finite(bar.close)
            self.ib.sleep(0.25)

        self.upsert_volatility_rows(list(collected.values()))
        logger.info("Backfilled %s with %s daily volatility rows", code, len(collected))

    def run_backfill(self, limit: Optional[int], include_hv: bool) -> None:
        collection_type = "BACKFILL_IV_HV" if include_hv else "BACKFILL"
        rows = self.universe(collection_type, limit)
        logger.info("Volatility backfill has %s pending symbols", len(rows))
        for index, row in enumerate(rows, 1):
            try:
                self.backfill_symbol(row, include_hv)
            except Exception:
                logger.exception("Backfill failed for %s", row.get("ASXCode"))
            if index % 25 == 0:
                logger.info("Backfill progress %s/%s", index, len(rows))

    def ticker_payload(self, code: str, ticker: Any, observation_date: date) -> Dict[str, Any]:
        fundamentals = getattr(ticker, "fundamentalRatios", None)
        dividends = getattr(ticker, "dividends", None)
        fundamental_json = object_dict(fundamentals)
        dividend_json = object_dict(dividends)

        last_price = first_value(ticker, "last", "close")
        trailing_pe = first_value(fundamentals, "PEEXCLXOR", "APENORM")
        forward_eps = first_value(fundamentals, "AFEEPSNTM")
        ratio_price = first_value(fundamentals, "NPRICE") or last_price
        forward_pe = ratio(ratio_price, forward_eps)

        past_dividend = first_value(dividends, "past12Months")
        next_dividend = first_value(dividends, "next12Months")
        next_amount = first_value(dividends, "nextAmount")
        next_date = getattr(dividends, "nextDate", None)
        if isinstance(next_date, datetime):
            next_date = next_date.date()
        if next_date is not None and not isinstance(next_date, date):
            try:
                next_date = date.fromisoformat(str(next_date)[:10])
            except ValueError:
                next_date = None

        implied_volatility = first_value(ticker, "impliedVolatility")
        historical_volatility = first_value(ticker, "histVolatility")
        call_volume = integer(getattr(ticker, "callVolume", None))
        put_volume = integer(getattr(ticker, "putVolume", None))
        call_oi = integer(getattr(ticker, "callOpenInterest", None))
        put_oi = integer(getattr(ticker, "putOpenInterest", None))

        snapshot = {
            "asx_code": code,
            "observation_date": observation_date,
            "capture_time": datetime.now(),
            "market_data_type": integer(getattr(ticker, "marketDataType", None)),
            "last_price": last_price,
            "iv": implied_volatility,
            "hv": historical_volatility,
            "low13": first_value(ticker, "low13week"),
            "high13": first_value(ticker, "high13week"),
            "low26": first_value(ticker, "low26week"),
            "high26": first_value(ticker, "high26week"),
            "low52": first_value(ticker, "low52week"),
            "high52": first_value(ticker, "high52week"),
            "average_volume": integer(getattr(ticker, "avVolume", None)),
            "shortable_shares": integer(getattr(ticker, "shortableShares", None)),
            "past_dividend": past_dividend,
            "next_dividend": next_dividend,
            "next_dividend_date": next_date,
            "next_dividend_amount": next_amount,
            "dividend_yield": (
                next_dividend / last_price * 100
                if next_dividend is not None and last_price not in (None, 0)
                else None
            ),
            "call_volume": call_volume,
            "put_volume": put_volume,
            "call_oi": call_oi,
            "put_oi": put_oi,
            "average_option_volume": integer(getattr(ticker, "avOptionVolume", None)),
            "put_call_volume_ratio": ratio(put_volume, call_volume),
            "put_call_oi_ratio": ratio(put_oi, call_oi),
            "trailing_pe": trailing_pe,
            "forward_eps": forward_eps,
            "forward_pe": forward_pe,
            "market_cap": first_value(fundamentals, "MKTCAP"),
            "beta": first_value(fundamentals, "BETA"),
            "price_to_book": first_value(fundamentals, "PRICE2BK"),
            "payout_ratio": first_value(fundamentals, "TTMPAYRAT"),
            "roe": first_value(fundamentals, "TTMROEPCT", "ROEPCT"),
            "roa": first_value(fundamentals, "TTMROAPCT", "ROAPCT"),
            "roi": first_value(fundamentals, "TTMROIPCT", "ROIPCT"),
            "debt_to_equity": first_value(fundamentals, "QTOTD2EQ"),
            "revenue_growth": first_value(fundamentals, "TTMREVCHG", "REVCHNGYR"),
            "eps_growth": first_value(fundamentals, "TTMEPSCHG", "EPSCHNGYR"),
            "free_cash_flow": first_value(fundamentals, "TTMFCF"),
            "fundamental_json": json.dumps(fundamental_json, allow_nan=False) if fundamental_json else None,
            "dividend_json": json.dumps(dividend_json, allow_nan=False) if dividend_json else None,
        }
        snapshot["status"] = "COMPLETE" if any(
            snapshot[key] is not None
            for key in ("iv", "hv", "last_price", "low52", "average_volume", "market_cap")
        ) else "NO_DATA"
        return snapshot

    def upsert_snapshot(self, value: Dict[str, Any]) -> None:
        sql = """
        exec StockData.usp_UpsertDailyMarketSnapshot
            @pvchASXCode=?, @pdtObservationDate=?, @pdtCaptureDateTime=?,
            @ptintMarketDataType=?, @pdecLastPrice=?,
            @pdecImpliedVolatility=?, @pdecHistoricalVolatility=?,
            @pdecLow13Week=?, @pdecHigh13Week=?, @pdecLow26Week=?, @pdecHigh26Week=?,
            @pdecLow52Week=?, @pdecHigh52Week=?, @pbintAverageVolume90Day=?,
            @pbintShortableShares=?, @pdecDividendPast12Months=?,
            @pdecDividendNext12Months=?, @pdtNextDividendDate=?,
            @pdecNextDividendAmount=?, @pdecDividendYieldPercent=?,
            @pbintCallVolume=?, @pbintPutVolume=?, @pbintCallOpenInterest=?,
            @pbintPutOpenInterest=?, @pbintAverageOptionVolume=?,
            @pdecPutCallVolumeRatio=?, @pdecPutCallOpenInterestRatio=?,
            @pdecTrailingPE=?, @pdecForwardEPS=?, @pdecForwardPE=?,
            @pdecMarketCap=?, @pdecBeta=?, @pdecPriceToBook=?, @pdecPayoutRatio=?,
            @pdecReturnOnEquity=?, @pdecReturnOnAssets=?, @pdecReturnOnInvestment=?,
            @pdecDebtToEquity=?, @pdecRevenueGrowth=?, @pdecEPSGrowth=?,
            @pdecFreeCashFlow=?, @pnvchFundamentalRatiosJson=?, @pnvchDividendJson=?,
            @pvchCollectionStatus=?, @pnvchErrorMessage=?
        """
        keys = (
            "asx_code", "observation_date", "capture_time", "market_data_type", "last_price",
            "iv", "hv", "low13", "high13", "low26", "high26", "low52", "high52",
            "average_volume", "shortable_shares", "past_dividend", "next_dividend",
            "next_dividend_date", "next_dividend_amount", "dividend_yield",
            "call_volume", "put_volume", "call_oi", "put_oi", "average_option_volume",
            "put_call_volume_ratio", "put_call_oi_ratio", "trailing_pe", "forward_eps",
            "forward_pe", "market_cap", "beta", "price_to_book", "payout_ratio", "roe",
            "roa", "roi", "debt_to_equity", "revenue_growth", "eps_growth",
            "free_cash_flow", "fundamental_json", "dividend_json", "status", "error",
        )
        self.db.execute_update_usp(sql, tuple(value.get(key) for key in keys))

    def run_daily(self, limit: Optional[int], batch_size: int, wait_seconds: float) -> None:
        rows = self.universe("DAILY", limit)
        logger.info("Daily snapshot has %s pending symbols", len(rows))
        for offset in range(0, len(rows), batch_size):
            batch = rows[offset : offset + batch_size]
            contracts = [contract_for(str(row["StockCode"])) for row in batch]
            qualified = self.ib.qualifyContracts(*contracts)
            qualified_by_symbol = {
                str(contract.symbol).upper(): contract for contract in qualified
            }
            active: List[Any] = []
            try:
                tickers: Dict[str, Any] = {}
                for row in batch:
                    requested = contract_for(str(row["StockCode"]))
                    symbol = str(requested.symbol).upper()
                    contract = qualified_by_symbol.get(symbol)
                    if contract is None:
                        continue
                    ticker = self.ib.reqMktData(contract, GENERIC_TICKS, False, False)
                    active.append(contract)
                    tickers[str(row["ASXCode"])] = ticker

                self.ib.sleep(wait_seconds)
                for row in batch:
                    code = str(row["ASXCode"])
                    ticker = tickers.get(code)
                    if ticker is None:
                        logger.warning("No qualified contract for %s", code)
                        continue
                    try:
                        payload = self.ticker_payload(code, ticker, row["ObservationDate"])
                        current_volatility = [{
                            "asx_code": code,
                            "observation_date": row["ObservationDate"].isoformat(),
                            "iv_close": payload["iv"],
                            "hv_close": payload["hv"],
                            "source": "IBKR_SNAPSHOT",
                        }]
                        self.upsert_volatility_rows(current_volatility)
                        self.upsert_snapshot(payload)
                    except Exception as exc:
                        logger.exception("Snapshot failed for %s", code)
                        self.upsert_snapshot({
                            "asx_code": code,
                            "observation_date": row["ObservationDate"],
                            "capture_time": datetime.now(),
                            "status": "ERROR",
                            "error": str(exc)[:1000],
                        })
            finally:
                for contract in active:
                    self.ib.cancelMktData(contract)
            logger.info(
                "Daily snapshot progress %s/%s",
                min(offset + batch_size, len(rows)),
                len(rows),
            )

    def close(self) -> None:
        if self.ib.isConnected():
            self.ib.disconnect()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Collect IBKR volatility and market snapshots.")
    parser.add_argument("--mode", choices=("daily", "backfill", "all"), default="daily")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--batch-size", type=int, default=50)
    parser.add_argument("--wait-seconds", type=float, default=8.0)
    parser.add_argument(
        "--include-historical-hv",
        action="store_true",
        help="Backfill historical volatility as well as implied volatility.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    collector = Collector()
    try:
        collector.connect()
        if args.mode in ("backfill", "all"):
            collector.run_backfill(args.limit, args.include_historical_hv)
        if args.mode in ("daily", "all"):
            collector.run_daily(args.limit, args.batch_size, args.wait_seconds)
    finally:
        collector.close()


if __name__ == "__main__":
    main()
