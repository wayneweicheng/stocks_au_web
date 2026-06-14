from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Any, Dict


OCC_SYMBOL_RE = re.compile(r"^([A-Z]+)(\d{6})([CP])(\d{8})$")


@dataclass(frozen=True)
class OptionLeg:
    option_symbol: str
    action: str
    put_call: str
    expiry: str
    strike: float


@dataclass(frozen=True)
class SellPutSpread:
    underlying: str
    quantity: int
    short_leg: OptionLeg
    long_leg: OptionLeg
    net_credit: float
    profit_exit_percent: float = 30.0


def parse_occ_option_symbol(option_symbol: str) -> Dict[str, Any]:
    symbol = (option_symbol or "").strip().upper().replace(" ", "")
    match = OCC_SYMBOL_RE.match(symbol)
    if not match:
        raise ValueError("Option symbol must use OCC format such as QQQ260116P00480000")

    underlying, yymmdd, put_call, strike_raw = match.groups()
    expiry = f"20{yymmdd}"
    strike = int(strike_raw) / 1000.0
    return {
        "underlying": underlying,
        "expiry": expiry,
        "put_call": put_call,
        "strike": strike,
    }


def normalize_leg(leg: OptionLeg) -> OptionLeg:
    return OptionLeg(
        option_symbol=(leg.option_symbol or "").strip().upper().replace(" ", ""),
        action=(leg.action or "").strip().upper(),
        put_call=(leg.put_call or "").strip().upper(),
        expiry=(leg.expiry or "").strip().replace("-", ""),
        strike=float(leg.strike),
    )


def validate_sell_put_spread(spread: SellPutSpread) -> SellPutSpread:
    underlying = (spread.underlying or "").strip().upper()
    short_leg = normalize_leg(spread.short_leg)
    long_leg = normalize_leg(spread.long_leg)

    if not underlying:
        raise ValueError("Underlying is required")
    if int(spread.quantity) <= 0:
        raise ValueError("Quantity must be greater than zero")
    if float(spread.net_credit) <= 0:
        raise ValueError("Net credit must be greater than zero")
    if short_leg.action != "SELL":
        raise ValueError("Short leg action must be SELL")
    if long_leg.action != "BUY":
        raise ValueError("Long leg action must be BUY")
    if short_leg.put_call != "P" or long_leg.put_call != "P":
        raise ValueError("Both spread legs must be puts")
    if short_leg.expiry != long_leg.expiry:
        raise ValueError("Spread legs must use the same expiry")
    if short_leg.strike <= long_leg.strike:
        raise ValueError("Short put strike must be greater than long put strike")

    exit_debit = calculate_profit_exit_debit(float(spread.net_credit), float(spread.profit_exit_percent))
    if exit_debit <= 0 or exit_debit >= float(spread.net_credit):
        raise ValueError("Profit exit debit must be positive and less than entry credit")

    return SellPutSpread(
        underlying=underlying,
        quantity=int(spread.quantity),
        short_leg=short_leg,
        long_leg=long_leg,
        net_credit=float(spread.net_credit),
        profit_exit_percent=float(spread.profit_exit_percent),
    )


def calculate_profit_exit_debit(net_credit: float, profit_exit_percent: float = 30.0) -> float:
    remaining_percent = 1.0 - (float(profit_exit_percent) / 100.0)
    return round(float(net_credit) * remaining_percent, 4)


def calculate_sell_put_spread_preview(spread: SellPutSpread) -> Dict[str, float]:
    validated = validate_sell_put_spread(spread)
    width = round(validated.short_leg.strike - validated.long_leg.strike, 4)
    multiplier = 100
    quantity = validated.quantity
    max_profit = round(validated.net_credit * multiplier * quantity, 2)
    max_loss = round((width - validated.net_credit) * multiplier * quantity, 2)
    breakeven = round(validated.short_leg.strike - validated.net_credit, 4)
    profit_exit_debit = calculate_profit_exit_debit(validated.net_credit, validated.profit_exit_percent)

    return {
        "width": width,
        "max_profit": max_profit,
        "max_loss": max_loss,
        "breakeven": breakeven,
        "profit_exit_debit": profit_exit_debit,
    }
