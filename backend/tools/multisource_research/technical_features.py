"""Causal daily technical features for completed US equity/ETF OHLCV bars.

Input rows are one completed regular-session daily bar per symbol/date. Every
rolling level used as a prior support/resistance reference is lagged one day.
Current D0 close-derived indicators are available to the D1 premarket decision.
"""
from __future__ import annotations
import numpy as np
import pandas as pd

KEYS = ("ASXCode", "ObservationDate")


def _slope(values: np.ndarray) -> float:
    if len(values) < 2 or not np.isfinite(values).all():
        return np.nan
    x = np.arange(len(values), dtype=float)
    return float(np.polyfit(x, values.astype(float), 1)[0])


def _prior_rank(series: pd.Series, window: int = 60, minimum: int = 20) -> pd.Series:
    values = pd.to_numeric(series, errors="coerce").to_numpy(dtype=float)
    result = np.full(len(values), np.nan)
    for index, current in enumerate(values):
        if not np.isfinite(current):
            continue
        prior = values[max(0, index - window):index]
        prior = prior[np.isfinite(prior)]
        if len(prior) >= minimum:
            result[index] = float((prior <= current).mean())
    return pd.Series(result, index=series.index)


def _wilder(values: pd.Series, period: int) -> pd.Series:
    return values.ewm(alpha=1.0 / period, adjust=False, min_periods=period).mean()


def _rsi(close: pd.Series, period: int = 14) -> pd.Series:
    change = close.diff()
    gain = change.clip(lower=0.0)
    loss = -change.clip(upper=0.0)
    avg_gain = _wilder(gain, period)
    avg_loss = _wilder(loss, period)
    rs = avg_gain / avg_loss.replace(0.0, np.nan)
    result = 100.0 - 100.0 / (1.0 + rs)
    result = result.mask((avg_loss == 0) & (avg_gain > 0), 100.0)
    result = result.mask((avg_loss == 0) & (avg_gain == 0), 50.0)
    return result


def build_symbol_features(frame: pd.DataFrame) -> pd.DataFrame:
    required = {"ObservationDate", "Open", "High", "Low", "Close", "Volume"}
    missing = sorted(required - set(frame.columns))
    if missing:
        raise ValueError(f"missing daily price fields: {missing}")
    p = frame.sort_values("ObservationDate").copy().reset_index(drop=True)
    if p["ObservationDate"].duplicated().any():
        raise ValueError("daily price input has duplicate ObservationDate rows")
    for field in ("Open", "High", "Low", "Close", "Volume"):
        p[field] = pd.to_numeric(p[field], errors="coerce")
    close, high, low, open_, volume = p.Close, p.High, p.Low, p.Open, p.Volume
    prev_close = close.shift(1)

    p["Return1Pct"] = close.pct_change(fill_method=None) * 100.0
    for horizon in (3, 5, 10, 20):
        p[f"Return{horizon}Pct"] = close.pct_change(horizon, fill_method=None) * 100.0
    for period in (10, 20, 50):
        ma = close.rolling(period, min_periods=period).mean()
        p[f"SMA{period}"] = ma
        p[f"PriceDistSMA{period}Pct"] = 100.0 * (close / ma - 1.0)
        p[f"PriceDistSMA{period}ATR"] = (close - ma) / p.get("ATR14", np.nan)
        p[f"SMA{period}Slope5Pct"] = 100.0 * (ma / ma.shift(5) - 1.0)
    for period in (10, 20, 50):
        p[f"EMA{period}"] = close.ewm(span=period, adjust=False, min_periods=period).mean()
    p["MA20Above50"] = (p.SMA20 > p.SMA50).astype(float)
    p["CloseAboveSMA50"] = (close > p.SMA50).astype(float)

    p["RSI7"] = _rsi(close, 7)
    p["RSI14"] = _rsi(close, 14)
    p["RSI21"] = _rsi(close, 21)
    p["RSI14Change5"] = p.RSI14 - p.RSI14.shift(5)

    ema12 = close.ewm(span=12, adjust=False, min_periods=12).mean()
    ema26 = close.ewm(span=26, adjust=False, min_periods=26).mean()
    p["MACDLine"] = ema12 - ema26
    p["MACDSignal9"] = p.MACDLine.ewm(span=9, adjust=False, min_periods=9).mean()
    p["MACDHistogram"] = p.MACDLine - p.MACDSignal9
    p["MACDHistogramChange3"] = p.MACDHistogram - p.MACDHistogram.shift(3)

    tr = pd.concat([(high - low), (high - prev_close).abs(), (low - prev_close).abs()], axis=1).max(axis=1, skipna=False)
    p["TrueRange"] = tr
    p["ATR14"] = _wilder(tr, 14)
    p["ATR14Pct"] = 100.0 * p.ATR14 / close
    for period in (10, 20, 50):
        p[f"PriceDistSMA{period}ATR"] = (close - p[f"SMA{period}"]) / p.ATR14
    p["RealizedVol20Pct"] = p.Return1Pct.rolling(20, min_periods=20).std(ddof=1) * np.sqrt(252.0)
    p["RealizedVol60Pct"] = p.Return1Pct.rolling(60, min_periods=40).std(ddof=1) * np.sqrt(252.0)
    p["VolatilityRatio20_60"] = p.RealizedVol20Pct / p.RealizedVol60Pct.replace(0, np.nan)

    mid = close.rolling(20, min_periods=20).mean()
    std = close.rolling(20, min_periods=20).std(ddof=0)
    upper, lower = mid + 2.0 * std, mid - 2.0 * std
    width = upper - lower
    p["BB20Middle"] = mid
    p["BB20Upper"] = upper
    p["BB20Lower"] = lower
    p["BB20PercentB"] = (close - lower) / width.replace(0, np.nan)
    p["BB20Bandwidth"] = width / mid.replace(0, np.nan)
    p["BB20LowerDistanceATR"] = (close - lower) / p.ATR14
    p["BB20UpperDistanceATR"] = (upper - close) / p.ATR14
    p["BB20BandwidthRank60"] = _prior_rank(p.BB20Bandwidth)

    # Prior-only levels: today’s H/L never enter today’s support/resistance.
    for window in (10, 20, 60):
        prior_high = high.shift(1).rolling(window, min_periods=window).max()
        prior_low = low.shift(1).rolling(window, min_periods=window).min()
        p[f"PriorHigh{window}"] = prior_high
        p[f"PriorLow{window}"] = prior_low
        p[f"DistPriorHigh{window}ATR"] = (prior_high - close) / p.ATR14
        p[f"DistPriorLow{window}ATR"] = (close - prior_low) / p.ATR14
        p[f"BreakPriorHigh{window}"] = (close > prior_high).astype(float)
        p[f"BreakPriorLow{window}"] = (close < prior_low).astype(float)

    # Previous completed session's classic pivot levels.
    pp = (high.shift(1) + low.shift(1) + close.shift(1)) / 3.0
    p["PriorDayPivot"] = pp
    p["PriorDayR1"] = 2.0 * pp - low.shift(1)
    p["PriorDayS1"] = 2.0 * pp - high.shift(1)
    p["DistPriorDayPivotATR"] = (close - pp) / p.ATR14
    p["DistPriorDayR1ATR"] = (p.PriorDayR1 - close) / p.ATR14
    p["DistPriorDayS1ATR"] = (close - p.PriorDayS1) / p.ATR14

    # Completed-week and completed-month classic pivots, shifted before joining.
    dates = pd.to_datetime(p.ObservationDate)
    for label, period in (("Week", "W-FRI"), ("Month", "M")):
        tmp = p.assign(_period=dates.dt.to_period(period)).groupby("_period").agg(High=("High", "max"), Low=("Low", "min"), Close=("Close", "last"))
        tmp["Pivot"] = (tmp.High + tmp.Low + tmp.Close) / 3.0
        tmp["R1"] = 2.0 * tmp.Pivot - tmp.Low
        tmp["S1"] = 2.0 * tmp.Pivot - tmp.High
        tmp = tmp.shift(1)
        aligned = dates.dt.to_period(period).map(tmp.Pivot)
        p[f"Prior{label}Pivot"] = aligned.to_numpy(dtype=float)
        p[f"DistPrior{label}PivotATR"] = (close - p[f"Prior{label}Pivot"]) / p.ATR14
        r1 = dates.dt.to_period(period).map(tmp.R1).to_numpy(dtype=float)
        s1 = dates.dt.to_period(period).map(tmp.S1).to_numpy(dtype=float)
        p[f"DistPrior{label}R1ATR"] = (r1 - close.to_numpy()) / p.ATR14.to_numpy()
        p[f"DistPrior{label}S1ATR"] = (close.to_numpy() - s1) / p.ATR14.to_numpy()

    p["GapFromPrevClosePct"] = 100.0 * (open_ / prev_close - 1.0)
    p["CloseLocationValue"] = ((close - low) - (high - close)) / (high - low).replace(0, np.nan)
    p["DollarVolume"] = close * volume
    median_volume = volume.shift(1).rolling(20, min_periods=15).median()
    p["RelativeVolume20"] = volume / median_volume.replace(0, np.nan)
    p["VWAPDistancePct"] = 100.0 * (close / pd.to_numeric(p.get("VWAP"), errors="coerce") - 1.0) if "VWAP" in p else np.nan

    # Deterministic trailing linear slope and price/RSI slope disagreement.
    p["CloseSlope20PctPerDay"] = close.rolling(20, min_periods=20).apply(_slope, raw=True) / close * 100.0
    p["RSISlope20PerDay"] = p.RSI14.rolling(20, min_periods=20).apply(_slope, raw=True)
    p["PriceRSISlopeDivergence"] = np.sign(p.CloseSlope20PctPerDay) != np.sign(p.RSISlope20PerDay)
    p["PriceRSISlopeDivergence"] = p.PriceRSISlopeDivergence.astype(float).where(p.CloseSlope20PctPerDay.notna() & p.RSISlope20PerDay.notna())

    # Three-left/three-right pivots are timestamped at confirmation (today),
    # never backdated to the center bar that needed future bars to confirm.
    pivot_high = high.shift(3)
    pivot_low = low.shift(3)
    left_high = high.shift(4).rolling(3, min_periods=3).max()
    right_high = high.rolling(3, min_periods=3).max()
    left_low = low.shift(4).rolling(3, min_periods=3).min()
    right_low = low.rolling(3, min_periods=3).min()
    confirmed_high = pivot_high.where((pivot_high > left_high) & (pivot_high >= right_high))
    confirmed_low = pivot_low.where((pivot_low < left_low) & (pivot_low <= right_low))
    p["ConfirmedPivotHigh"] = confirmed_high
    p["ConfirmedPivotLow"] = confirmed_low
    p["LastConfirmedPivotHigh"] = confirmed_high.ffill()
    p["LastConfirmedPivotLow"] = confirmed_low.ffill()
    p["LastPivotHighDistanceATR"] = (close - p.LastConfirmedPivotHigh) / p.ATR14
    p["LastPivotLowDistanceATR"] = (close - p.LastConfirmedPivotLow) / p.ATR14

    p["OBV"] = (np.sign(p.Return1Pct.fillna(0.0)) * volume.fillna(0.0)).cumsum()
    p["OBVSlope20"] = p.OBV.rolling(20, min_periods=20).apply(_slope, raw=True)
    return p


def build_features(frame: pd.DataFrame) -> pd.DataFrame:
    if "ASXCode" not in frame:
        raise ValueError("daily bars require ASXCode")
    parts = [build_symbol_features(part) for _, part in frame.groupby("ASXCode", sort=False)]
    return pd.concat(parts, ignore_index=True) if parts else pd.DataFrame()
