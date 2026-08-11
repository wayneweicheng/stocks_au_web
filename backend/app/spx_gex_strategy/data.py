from __future__ import annotations

import csv
import logging
import math
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo

from .calendar import USCashCalendar
from .models import DailyGexObservation, MarketBar, RawGexRow

logger = logging.getLogger("app.spx_gex_strategy.data")


class DataValidationError(ValueError):
    """Raised when source data is incomplete or structurally invalid."""


def _float(value: Any, field: str, required: bool = False) -> float | None:
    if value is None or str(value).strip() in {"", "NULL", "None", "nan", "NaN"}:
        if required:
            raise DataValidationError(f"Missing required numeric field: {field}")
        return None
    try:
        result = float(value)
    except (TypeError, ValueError) as exc:
        raise DataValidationError(f"Invalid numeric field {field}: {value!r}") from exc
    if not math.isfinite(result):
        raise DataValidationError(f"Non-finite numeric field {field}: {value!r}")
    return result


def _date(value: Any) -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    text = str(value or "").strip()
    if not text:
        raise DataValidationError("Missing observation date")
    try:
        return date.fromisoformat(text[:10])
    except ValueError as exc:
        raise DataValidationError(f"Invalid observation date: {value!r}") from exc


def _optional_float(row: Mapping[str, Any], *names: str) -> float | None:
    for name in names:
        if name in row:
            return _float(row.get(name), name)
    return None


def _value(row: Mapping[str, Any], *names: str) -> Any:
    for name in names:
        if name in row:
            return row[name]
    return None


def read_delimited(path: str | Path) -> list[dict[str, str]]:
    source = Path(path)
    with source.open("r", encoding="utf-8-sig", newline="") as handle:
        sample = handle.read(4096)
        handle.seek(0)
        delimiter = "\t" if "\t" in sample.splitlines()[0] else ","
        return list(csv.DictReader(handle, delimiter=delimiter))


def parse_raw_gex_rows(rows: Iterable[Mapping[str, Any]]) -> list[RawGexRow]:
    parsed: list[RawGexRow] = []
    for row in rows:
        capital_type = str(_value(row, "CapitalType", "capital_type") or "").strip().upper()
        if capital_type not in {"BC", "BP", "SC", "SP"}:
            continue
        parsed.append(
            RawGexRow(
                observation_date=_date(_value(row, "ObservationDate", "observation_date")),
                capital_type=capital_type,
                gex_delta=_float(_value(row, "GEXDelta", "gex_delta"), "GEXDelta", required=True) or 0.0,
                close=_optional_float(row, "Close", "close"),
                vwap=_optional_float(row, "VWAP", "vwap"),
                gex=_optional_float(row, "GEX", "gex"),
                ticker=str(_value(row, "Ticker", "ASXCode") or "SPXW"),
                signal=(str(_value(row, "Signal", "signal") or "").strip().upper() or None),
            )
        )
    return sorted(parsed, key=lambda row: (row.observation_date, row.capital_type))


def _summary_row(row: Mapping[str, Any]) -> DailyGexObservation:
    bc = _optional_float(row, "DailyBCAbsGEXDelta", "BCAbsGEXDelta", "BC_GEXDelta")
    bp = _optional_float(row, "DailyBPAbsGEXDelta", "BPAbsGEXDelta", "BP_GEXDelta")
    sc = _optional_float(row, "DailySCAbsGEXDelta", "SCAbsGEXDelta", "SC_GEXDelta")
    sp = _optional_float(row, "DailySPAbsGEXDelta", "SPAbsGEXDelta", "SP_GEXDelta")
    total = _optional_float(row, "TotalAbsGEXDelta", "total_abs_gex_delta")
    values = {"BC": bc, "BP": bp, "SC": sc, "SP": sp}
    if any(value is None for value in values.values()):
        raise DataValidationError(
            f"Summary row {_value(row, 'ObservationDate')} is missing one of BC/BP/SC/SP totals"
        )
    total = total if total is not None else sum(abs(value or 0.0) for value in values.values())
    if total <= 0:
        raise DataValidationError(f"TotalAbsGEXDelta must be positive on {_value(row, 'ObservationDate')}")
    levels = {
        "BC": _optional_float(row, "DailyBCGEX", "BCGEX", "BC_GEX"),
        "BP": _optional_float(row, "DailyBPGEX", "BPGEX", "BP_GEX"),
        "SC": _optional_float(row, "DailySCGEX", "SCGEX", "SC_GEX"),
        "SP": _optional_float(row, "DailySPGEX", "SPGEX", "SP_GEX"),
    }
    return DailyGexObservation(
        observation_date=_date(_value(row, "ObservationDate", "observation_date")),
        bc_gex_delta=bc or 0.0,
        bp_gex_delta=bp or 0.0,
        sc_gex_delta=sc or 0.0,
        sp_gex_delta=sp or 0.0,
        total_abs_gex_delta=total,
        close=_optional_float(row, "Close", "close"),
        vwap=_optional_float(row, "VWAP", "vwap"),
        put_call_ratio=_optional_float(row, "PutCallRatio", "put_call_ratio"),
        close_change_pct=_optional_float(row, "CloseChangePct", "close_change_pct"),
        pcr_change_pct=_optional_float(row, "PCRChangePct", "pcr_change_pct"),
        signal_raw=(str(_value(row, "Signal", "signal") or "").strip().upper() or None),
        bc_gex=levels["BC"],
        bp_gex=levels["BP"],
        sc_gex=levels["SC"],
        sp_gex=levels["SP"],
        source_rows=4,
    )


def aggregate_daily_gex(rows: Iterable[Mapping[str, Any] | RawGexRow]) -> list[DailyGexObservation]:
    """Validate and aggregate exactly four raw capital rows per date."""
    rows = list(rows)
    if rows and isinstance(rows[0], Mapping) and "CapitalType" not in rows[0] and (
        "DailyBCAbsGEXDelta" in rows[0] or "TotalAbsGEXDelta" in rows[0]
    ):
        return sorted([_summary_row(row) for row in rows if isinstance(row, Mapping)], key=lambda row: row.observation_date)

    parsed: list[RawGexRow] = []
    for row in rows:
        if isinstance(row, RawGexRow):
            parsed.append(row)
        else:
            parsed.extend(parse_raw_gex_rows([row]))
    grouped: dict[date, list[RawGexRow]] = {}
    for row in parsed:
        grouped.setdefault(row.observation_date, []).append(row)

    observations: list[DailyGexObservation] = []
    for observation_date in sorted(grouped):
        date_rows = grouped[observation_date]
        by_type: dict[str, list[RawGexRow]] = {}
        for row in date_rows:
            by_type.setdefault(row.capital_type, []).append(row)
        missing = {capital for capital in ("BC", "BP", "SC", "SP") if capital not in by_type}
        duplicates = {capital for capital, items in by_type.items() if len(items) != 1}
        if missing or duplicates:
            raise DataValidationError(
                f"GEX date {observation_date} must contain exactly one BC/BP/SC/SP row; "
                f"missing={sorted(missing)} duplicates={sorted(duplicates)}"
            )
        selected = {capital: by_type[capital][0] for capital in ("BC", "BP", "SC", "SP")}
        values = {capital: selected[capital].gex_delta for capital in selected}
        levels = {capital: selected[capital].gex for capital in selected}
        total = sum(abs(value) for value in values.values())
        if total <= 0:
            raise DataValidationError(f"TotalAbsGEXDelta must be positive on {observation_date}")
        close = next((row.close for row in selected.values() if row.close is not None), None)
        vwap = next((row.vwap for row in selected.values() if row.vwap is not None), None)
        signal = next((row.signal for row in selected.values() if row.signal), None)
        observations.append(
            DailyGexObservation(
                observation_date=observation_date,
                bc_gex_delta=values["BC"],
                bp_gex_delta=values["BP"],
                sc_gex_delta=values["SC"],
                sp_gex_delta=values["SP"],
                total_abs_gex_delta=total,
                close=close,
                vwap=vwap,
                put_call_ratio=(abs(values["BP"]) / abs(values["BC"]) if values["BC"] else None),
                close_change_pct=None,
                pcr_change_pct=None,
                signal_raw=signal,
                bc_gex=levels["BC"],
                bp_gex=levels["BP"],
                sc_gex=levels["SC"],
                sp_gex=levels["SP"],
                source_rows=4,
            )
        )

    # The SQL export supplied with this project derives these fields from the
    # previous row. Reproduce it here so CSV and SQL modes are identical.
    previous_close: float | None = None
    previous_pcr: float | None = None
    for observation in observations:
        if observation.close is not None and previous_close not in (None, 0):
            observation.close_change_pct = (observation.close / previous_close - 1.0) * 100.0
        if observation.put_call_ratio is not None and previous_pcr is not None:
            observation.pcr_change_pct = (
                0.0 if previous_pcr == 0 else (observation.put_call_ratio / previous_pcr - 1.0) * 100.0
            )
        if not observation.signal_raw and observation.close is not None and previous_close is not None:
            close_change = observation.close_change_pct
            pcr_change = observation.pcr_change_pct
            if close_change is not None and pcr_change is not None:
                if observation.close > previous_close and pcr_change > 5:
                    observation.signal_raw = "BEARISH"
                elif observation.close < previous_close and pcr_change < -5:
                    observation.signal_raw = "BULLISH"
                elif abs(close_change) < 0.1 and pcr_change > 20:
                    observation.signal_raw = "BEARISH"
                elif abs(close_change) < 0.1 and pcr_change < -20:
                    observation.signal_raw = "BULLISH"
        previous_close = observation.close or previous_close
        previous_pcr = observation.put_call_ratio or previous_pcr
    return observations


def parse_market_bars(
    rows: Iterable[Mapping[str, Any]], timezone: str = "America/New_York", symbol: str = "NQMAIN"
) -> list[MarketBar]:
    zone = ZoneInfo(timezone)
    bars: list[MarketBar] = []
    for row in rows:
        raw_timestamp = _value(row, "TimeIntervalStart", "timestamp", "DateTime")
        if raw_timestamp is None:
            raise DataValidationError("Market bar is missing TimeIntervalStart")
        if isinstance(raw_timestamp, datetime):
            timestamp = raw_timestamp
        else:
            timestamp = datetime.fromisoformat(str(raw_timestamp).replace("Z", "+00:00"))
        timestamp = timestamp.replace(tzinfo=zone) if timestamp.tzinfo is None else timestamp.astimezone(zone)
        bars.append(
            MarketBar(
                timestamp=timestamp,
                open=_float(_value(row, "Open", "open"), "Open", required=True) or 0.0,
                high=_float(_value(row, "High", "high"), "High", required=True) or 0.0,
                low=_float(_value(row, "Low", "low"), "Low", required=True) or 0.0,
                close=_float(_value(row, "Close", "close"), "Close", required=True) or 0.0,
                symbol=symbol,
            )
        )
    return sorted(bars, key=lambda bar: bar.timestamp)


class FileMarketDataRepository:
    def __init__(self, gex_path: str | Path, nq_path: str | Path, timezone: str = "America/New_York") -> None:
        self.gex_path = Path(gex_path)
        self.nq_path = Path(nq_path)
        self.timezone = timezone

    def gex_observations(self) -> list[DailyGexObservation]:
        observations = aggregate_daily_gex(read_delimited(self.gex_path))
        if any(
            level is None
            for observation in observations
            for level in (observation.bc_gex, observation.bp_gex, observation.sc_gex, observation.sp_gex)
        ):
            raise DataValidationError(
                "Summary file is missing BC/BP/SC/SP GEX levels; "
                "the corrected Yellow classifier requires raw per-capital GEX data"
            )
        return observations

    def nq_bars(self) -> list[MarketBar]:
        return parse_market_bars(read_delimited(self.nq_path, ), timezone=self.timezone)


class SqlServerMarketDataRepository:
    """Production adapter for the raw SPXW table and NQMAIN 30-minute bars."""

    def __init__(self, source_database: str = "StockDB_US", nq_symbol: str = "NQMAIN.US") -> None:
        self.source_database = source_database
        self.nq_symbol = nq_symbol

    @staticmethod
    def _close_shared_model(model) -> None:
        connection = getattr(model, "cnxn", None)
        if connection is not None:
            connection.close()

    def raw_gex_rows(self, start: date, end: date) -> list[RawGexRow]:
        # Keep this aligned with trading_orders.py. That route uses the shared
        # SQLServerModel (ODBC 17 and its existing environment configuration),
        # while the timed adapter uses a separate ODBC 18/encryption path.
        from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

        model = SQLServerModel(database=self.source_database)
        sql = f"""
        SELECT TOP (100000) *
        FROM [{self.source_database}].[Transform].[OptionGEXChangeCapitalType] WITH (NOLOCK)
        WHERE ASXCode = ?
          AND ObservationDate >= CONVERT(date, ?)
          AND ObservationDate < DATEADD(day, 1, CONVERT(date, ?))
          AND CapitalType IN ('BC', 'BP', 'SC', 'SP')
        ORDER BY ObservationDate ASC, CapitalType ASC
        """
        try:
            rows = model.execute_read_query(sql, ("SPXW.US", start.isoformat(), end.isoformat())) or []
            return parse_raw_gex_rows(rows)
        finally:
            self._close_shared_model(model)

    def gex_observations(self, start: date, end: date) -> list[DailyGexObservation]:
        return aggregate_daily_gex(self.raw_gex_rows(start, end))

    def nq_bars(self, start: date, end: date, timezone: str = "America/New_York") -> list[MarketBar]:
        from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

        model = SQLServerModel(database=self.source_database)
        sql = f"""
        SELECT TimeIntervalStart, [Open], [High], [Low], [Close]
        FROM [{self.source_database}].[StockData].[PriceHistoryTimeFrame] WITH (NOLOCK)
        WHERE ASXCode = ?
          AND TimeFrame = '30M'
          AND TimeIntervalStart >= CONVERT(datetime, ?)
          AND TimeIntervalStart < DATEADD(day, 1, CONVERT(datetime, ?))
        ORDER BY TimeIntervalStart ASC
        """
        try:
            rows = model.execute_read_query(sql, (self.nq_symbol, start.isoformat(), end.isoformat())) or []
            return parse_market_bars(rows, timezone=timezone, symbol=self.nq_symbol)
        finally:
            self._close_shared_model(model)
