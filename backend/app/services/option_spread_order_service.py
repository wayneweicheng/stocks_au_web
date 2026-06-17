from __future__ import annotations

from dataclasses import dataclass
import math
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


def _finite_float(value: Any, field_name: str) -> float:
    try:
        numeric_value = float(value)
    except (TypeError, ValueError):
        raise ValueError(f"{field_name} must be a number")

    if not math.isfinite(numeric_value):
        raise ValueError(f"{field_name} must be finite")
    return numeric_value


def _normalize_quantity(quantity: Any) -> int:
    numeric_quantity = _finite_float(quantity, "Quantity")
    if numeric_quantity <= 0:
        raise ValueError("Quantity must be greater than zero")
    if not numeric_quantity.is_integer():
        raise ValueError("Quantity must be a whole number")
    return int(numeric_quantity)


def normalize_leg(leg: OptionLeg, leg_label: str = "Leg") -> OptionLeg:
    return OptionLeg(
        option_symbol=(leg.option_symbol or "").strip().upper().replace(" ", ""),
        action=(leg.action or "").strip().upper(),
        put_call=(leg.put_call or "").strip().upper(),
        expiry=(leg.expiry or "").strip().replace("-", ""),
        strike=_finite_float(leg.strike, f"{leg_label} strike"),
    )


def _validate_option_symbol_matches_leg(leg: OptionLeg, underlying: str, leg_label: str) -> None:
    parsed = parse_occ_option_symbol(leg.option_symbol)
    if parsed["underlying"] != underlying:
        raise ValueError(f"{leg_label} option symbol underlying must match spread underlying")
    if parsed["put_call"] != leg.put_call:
        raise ValueError(f"{leg_label} option symbol put_call must match explicit put_call")
    if parsed["expiry"] != leg.expiry:
        raise ValueError(f"{leg_label} option symbol expiry must match explicit expiry")
    if abs(parsed["strike"] - leg.strike) > 0.0001:
        raise ValueError(f"{leg_label} option symbol strike must match explicit strike")


def validate_sell_put_spread(spread: SellPutSpread) -> SellPutSpread:
    underlying = (spread.underlying or "").strip().upper()
    short_leg = normalize_leg(spread.short_leg, "Short leg")
    long_leg = normalize_leg(spread.long_leg, "Long leg")
    quantity = _normalize_quantity(spread.quantity)
    net_credit = _finite_float(spread.net_credit, "Net credit")
    profit_exit_percent = _finite_float(spread.profit_exit_percent, "Profit exit percent")

    if not underlying:
        raise ValueError("Underlying is required")
    if net_credit <= 0:
        raise ValueError("Net credit must be greater than zero")
    if short_leg.action != "SELL":
        raise ValueError("Short leg action must be SELL")
    if long_leg.action != "BUY":
        raise ValueError("Long leg action must be BUY")

    _validate_option_symbol_matches_leg(short_leg, underlying, "Short leg")
    _validate_option_symbol_matches_leg(long_leg, underlying, "Long leg")

    if short_leg.put_call != "P" or long_leg.put_call != "P":
        raise ValueError("Both spread legs must be puts")
    if short_leg.expiry != long_leg.expiry:
        raise ValueError("Spread legs must use the same expiry")
    if short_leg.strike <= long_leg.strike:
        raise ValueError("Short put strike must be greater than long put strike")

    width = short_leg.strike - long_leg.strike
    if net_credit >= width:
        raise ValueError("Net credit must be less than spread width")

    exit_debit = calculate_profit_exit_debit(net_credit, profit_exit_percent)
    if exit_debit <= 0 or exit_debit >= net_credit:
        raise ValueError("Profit exit debit must be positive and less than entry credit")

    return SellPutSpread(
        underlying=underlying,
        quantity=quantity,
        short_leg=short_leg,
        long_leg=long_leg,
        net_credit=net_credit,
        profit_exit_percent=profit_exit_percent,
    )


def calculate_profit_exit_debit(net_credit: float, profit_exit_percent: float = 30.0) -> float:
    credit = _finite_float(net_credit, "Net credit")
    exit_percent = _finite_float(profit_exit_percent, "Profit exit percent")
    remaining_percent = 1.0 - (exit_percent / 100.0)
    return round(credit * remaining_percent, 4)


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
